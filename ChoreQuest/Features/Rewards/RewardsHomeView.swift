import SwiftUI

struct RewardsHomeView: View {
    @EnvironmentObject private var viewModel: RewardsViewModel

    @State private var selectedReward: Reward?
    @State private var isSelectingForDeletion = false
    @State private var selectedRewardIDs = Set<UUID>()
    @State private var showDeleteConfirmation = false
    @State private var isPresentingAddReward = false
    @State private var isPresentingSettings = false
    @State private var isPresentingNotifications = false

    var body: some View {
        NavigationStack {
            AppScreen {
                RewardsCard(
                    rewards: viewModel.rewards,
                    onEdit: { selectedReward = $0 },
                    isSelectingForDeletion: isSelectingForDeletion,
                    selectedRewardIDs: selectedRewardIDs,
                    onToggleSelection: { toggleSelection(for: $0) }
                )
            }
            .overlay(alignment: .top) {
                addRewardHeaderOverlay
            }
            .sheet(item: $selectedReward) { reward in
                EditRewardSheet(reward: reward, viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingAddReward) {
                AddRewardSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView()
            }
            .alert("Delete selected rewards?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { deleteSelectedRewards() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove \(selectedRewardIDs.count) reward\(selectedRewardIDs.count == 1 ? "" : "s").")
            }
            .toolbar { toolbar }
        }
    }
}

private extension RewardsHomeView {
    var addRewardHeaderOverlay: some View {
        HStack {
            Spacer()
            Button { isPresentingAddReward = true } label: {
                let base = Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)

                if #available(iOS 18.0, macOS 15.0, *) {
                    if #available(iOS 26.0, *) {
                        base.glassEffect(.regular.interactive(), in: .circle)
                    } else {
                        // Fallback on earlier versions
                    }
                } else {
                    base
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                        )
                }
            }
            .accessibilityLabel("Add Reward")
            #if os(iOS)
            .hoverEffect(.lift)
            #endif
        }
        .frame(maxWidth: AppLayout.maxContentWidth)
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, 100)
        .frame(maxWidth: .infinity, alignment: .center)
    }

        @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                if isSelectingForDeletion {
                    exitSelectionMode()
                } else {
                    beginSelectionMode()
                }
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
            Button { isPresentingNotifications = true } label: {
                Image(systemName: "bell")
            }
            .accessibilityLabel("Notifications")

            Button { isPresentingSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
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
    let familyVM = FamilyViewModel()
    let choresVM = ChoresViewModel()
    let rewardsVM = RewardsViewModel()
    let session = AppSessionViewModel(
        authService: MockAuthService(),
        firestoreService: MockFirestoreService.shared,
        storageService: MockStorageService(),
        familyViewModel: familyVM,
        choresViewModel: choresVM,
        rewardsViewModel: rewardsVM
    )
    return RewardsHomeView()
        .environmentObject(session)
        .environmentObject(rewardsVM)
}
#endif
