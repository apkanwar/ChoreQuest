import SwiftUI

struct KidRewardsView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var rewardsVM: RewardsViewModel
    @EnvironmentObject private var familyVM: FamilyViewModel

    @State private var isRedeeming = false
    @State private var errorMessage: String?
    @State private var selectedReward: Reward?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

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
        .sheet(item: $selectedReward) { reward in
            rewardDetail(for: reward)
        }
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
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
            LazyVGrid(columns: columns, spacing: AppSpacing.section) {
                ForEach(rewardsVM.rewards) { reward in
                    KidRewardTile(
                        reward: reward,
                        canRedeem: canAfford(reward),
                        isProcessing: isRedeeming,
                        onRedeem: { redeem(reward) }
                    )
                    .onTapGesture { selectedReward = reward }
                }
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
}

private struct KidRewardTile: View {
    let reward: Reward
    let canRedeem: Bool
    let isProcessing: Bool
    let onRedeem: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(reward.icon.isEmpty ? "🎁" : reward.icon)
                .font(.system(size: 36))
                .frame(height: 44)
            Text(reward.name)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Button(action: onRedeem) {
                Text("Redeem")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isProcessing || !canRedeem)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .appRowBackground(color: AppColors.rowAccent)
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
