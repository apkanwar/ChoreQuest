import SwiftUI

struct RewardsHomeView: View {
    @EnvironmentObject private var viewModel: RewardsViewModel

    @State private var selectedReward: Reward?
    @State private var isSelectingForDeletion = false
    @State private var selectedRewardIDs = Set<UUID>()
    @State private var showDeleteConfirmation = false
    @State private var isPresentingAddReward = false

    private let headerHeight: CGFloat = 200
    private var maxContentWidth: CGFloat { 640 }
    private let headerTopContentOffset: CGFloat = 40

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                headerView

                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear
                            .frame(height: headerHeight - headerTopContentOffset)

                        RewardsCard(
                            rewards: viewModel.rewards,
                            onEdit: { selectedReward = $0 },
                            isSelectingForDeletion: isSelectingForDeletion,
                            selectedRewardIDs: selectedRewardIDs,
                            onToggleSelection: { toggleSelection(for: $0) }
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .overlay(alignment: .top) {
                GlassEffectContainer(spacing: 20) {
                    HStack(spacing: 12) {
                        Spacer()
                        Button {
                            isPresentingAddReward = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .accessibilityLabel("Add Reward")
                        #if os(iOS)
                        .hoverEffect(.lift)
                        #endif
                    }
                }
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal)
                .padding(.vertical, 100)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .sheet(item: $selectedReward) { reward in
                EditRewardSheet(reward: reward, viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingAddReward) {
                AddRewardSheet(viewModel: viewModel)
            }
            .alert("Delete selected rewards?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelectedRewards()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove \(selectedRewardIDs.count) reward\(selectedRewardIDs.count == 1 ? "" : "s").")
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        if isSelectingForDeletion { exitSelectionMode() } else { beginSelectionMode() }
                    } label: {
                        if isSelectingForDeletion {
                            Image(systemName: "xmark")
                        } else {
                            Text("Select")
                        }
                    }
                    .accessibilityLabel(isSelectingForDeletion ? "Cancel" : "Select")

                    if isSelectingForDeletion {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                let selectionCount = selectedRewardIDs.count
                                let title = selectionCount == 0 ? "Delete Selected" : "Delete Selected (\(selectionCount))"
                                Label(title, systemImage: "trash")
                            }
                            .disabled(selectedRewardIDs.isEmpty)

                            Divider()

                            Button("Select All") {
                                selectedRewardIDs = Set(viewModel.rewards.map(\.id))
                            }

                            Button("Deselect All") {
                                selectedRewardIDs.removeAll()
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                        .accessibilityLabel("Actions")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // TODO: Show notifications
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Notifications")

                    Button {
                        // TODO: Open settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }
}

private extension RewardsHomeView {
    var headerView: some View {
        HeaderCard()
            .ignoresSafeArea(edges: .top)
            .frame(height: headerHeight)
            .zIndex(1000)
    }

    func beginSelectionMode() {
        selectedRewardIDs.removeAll()
        selectedReward = nil
        showDeleteConfirmation = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectingForDeletion = true
        }
    }

    func exitSelectionMode() {
        selectedRewardIDs.removeAll()
        showDeleteConfirmation = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectingForDeletion = false
        }
    }

    func toggleSelection(for reward: Reward) {
        if selectedRewardIDs.contains(reward.id) {
            selectedRewardIDs.remove(reward.id)
        } else {
            selectedRewardIDs.insert(reward.id)
        }
    }

    func deleteSelectedRewards() {
        let idsToDelete = selectedRewardIDs
        for reward in viewModel.rewards where idsToDelete.contains(reward.id) {
            viewModel.remove(reward)
        }
        exitSelectionMode()
    }
}

#if DEBUG
#Preview("Rewards Home") {
    RewardsHomeView()
        .environmentObject(RewardsViewModel())
}
#endif
