import SwiftUI

struct KidRewardsView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var rewardsVM: RewardsViewModel
    @EnvironmentObject private var familyVM: FamilyViewModel

    @State private var isRedeeming = false
    @State private var errorMessage: String?
    @State private var selectedReward: Reward?

    @State private var pendingRewards: [Submission] = []
    @State private var isLoadingPending = false

    @State private var pendingToCancel: Submission?
    @State private var showCancelAlert = false

    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            if rewardsVM.rewards.isEmpty {
                emptyStateCard
            } else {
                rewardsCard
            }
        }
        .overlay(alignment: .bottom) {
            if isRedeeming {
                ProgressView("Processing...")
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert("Cancel reward request?", isPresented: $showCancelAlert) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) {
                if let sub = pendingToCancel {
                    Task {
                        await session.cancelPendingReward(sub)
                        await reloadPending()
                        await MainActor.run {
                            toastMessage = "Cancelled \(sub.rewardName ?? "reward") request"
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showToast = true }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            withAnimation(.easeInOut(duration: 0.25)) { showToast = false }
                        }
                    }
                }
            }
        } message: {
            Text("This will remove your pending request so you can choose a different reward.")
        }
        .overlay(alignment: .top) {
            if showToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding()
            }
        }
        .sheet(item: $selectedReward) { reward in
            rewardDetail(for: reward)
        }
        .task { await reloadPending() }
    }
}

private extension KidRewardsView {
    var emptyStateCard: some View {
        ContentUnavailableView(
            "No rewards available",
            systemImage: "gift",
            description: Text("Your parent hasn't added rewards yet.")
        )
        .frame(maxWidth: .infinity)
        .appCardStyle()
    }

    var rewardsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            AppSectionHeader(title: "Rewards")
            if !pendingRewards.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Requests")
                        .font(.subheadline).bold()
                    ForEach(pendingRewards) { sub in
                        HStack {
                            Text(sub.rewardName ?? "Reward")
                            Spacer()
                            Button(role: .destructive) {
                                pendingToCancel = sub
                                showCancelAlert = true
                            } label: {
                                Label("Cancel", systemImage: "xmark.circle")
                            }
                        }
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            ForEach(rewardsVM.rewards) { reward in
                KidRewardTile(
                    reward: reward,
                    canRedeem: canAfford(reward),
                    isProcessing: isRedeeming,
                    onRedeem: { redeem(reward) }
                )
            }
        }
        .appCardStyle()
    }

    func rewardDetail(for reward: Reward) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                HStack(spacing: 12) {
                    Text(reward.icon.isEmpty ? "🎁" : reward.icon)
                        .font(.system(size: 48))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reward.name)
                            .font(.title3.bold())
                        Text("Cost: \(reward.cost) stars")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if !reward.details.isEmpty {
                    Text(reward.details)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    redeem(reward)
                } label: {
                    Label("Redeem for \(reward.cost) stars", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRedeeming || !canAfford(reward))
            }
            .padding(AppSpacing.screenPadding)
            .navigationTitle("Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { selectedReward = nil }
                }
            }
        }
    }

    var kidName: String { session.profile?.displayName ?? "" }

    var currentCoins: Int {
        familyVM.kids.first(where: { $0.name == kidName })?.coins ?? 0
    }

    func canAfford(_ reward: Reward) -> Bool { currentCoins >= reward.cost }

    func redeem(_ reward: Reward) {
        guard canAfford(reward) else {
            errorMessage = "You don't have enough stars."
            return
        }
        Task {
            await MainActor.run { isRedeeming = true }
            await session.redeemRewardAsCurrentKid(reward)
            await MainActor.run { isRedeeming = false }
        }
    }

    func reloadPending() async {
        guard let uid = session.profile?.id else { return }
        await MainActor.run { isLoadingPending = true }
        let all = await session.fetchSubmissions()
        let mine = all.filter { $0.type == .reward && $0.kidUid == uid && $0.status == .pending }
        await MainActor.run {
            pendingRewards = mine
            isLoadingPending = false
        }
    }

    var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(toastMessage)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 4)
    }
}

private struct KidRewardTile: View {
    let reward: Reward
    let canRedeem: Bool
    let isProcessing: Bool
    let onRedeem: () -> Void

    private var accentColor: Color {
        let palette: [Color] = [.pink, .yellow, .green, .orange, .purple, .teal, .blue]
        let seed = reward.icon.isEmpty ? reward.name : reward.icon
        var hash = 0
        for scalar in seed.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(reward.icon.isEmpty ? "🎯" : reward.icon)
                            .font(.title2)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(reward.name)
                        .font(.headline)

                    if !reward.details.isEmpty {
                        Text(reward.details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Label("Cost: \(reward.cost) stars", systemImage: "star.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.yellow.opacity(0.3)))
                }

                Spacer()
            }

            Button(action: onRedeem) {
                Label("Redeem for \(reward.cost) stars", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .padding(.top)
            .padding(.horizontal)
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing || !canRedeem)
        }
        .appRowBackground(color: Color.orange.opacity(0.12))
        .opacity(canRedeem ? 1 : 0.6)
        .accessibilityAction(named: Text("Redeem"), onRedeem)
        .accessibilityHint(canRedeem ? "Redeem this reward" : "Not enough stars yet")
    }
}

#if DEBUG
#Preview("Kid Rewards") {
    let session = AppSessionViewModel.previewKidSession()
    let rewardsVM = RewardsViewModel(rewards: Reward.previewList)
    let familyVM = FamilyViewModel(kids: [Kid(name: "Kenny Kid", coins: 60)])
    return NavigationStack { KidRewardsView() }
        .environmentObject(session)
        .environmentObject(rewardsVM)
        .environmentObject(familyVM)
}
#endif

