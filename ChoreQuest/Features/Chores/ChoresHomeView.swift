import SwiftUI

struct ChoresHomeView: View {
    @EnvironmentObject private var viewModel: ChoresViewModel

    @State private var selectedChore: Chore?
    @State private var isSelectingForDeletion = false
    @State private var selectedChoreIDs = Set<UUID>()
    @State private var showDeleteConfirmation = false
    @State private var isPresentingAddChore = false
    @State private var isPresentingSettings = false
    @State private var isPresentingNotifications = false

    var body: some View {
        NavigationStack {
            AppScreen {
                ChoresCard(
                    chores: viewModel.chores,
                    onEdit: { selectedChore = $0 },
                    isSelectingForDeletion: isSelectingForDeletion,
                    selectedChoreIDs: selectedChoreIDs,
                    onToggleSelection: { toggleSelection(for: $0) }
                )
            }
            .overlay(alignment: .top) {
                addChoreHeaderOverlay
            }
            .sheet(item: $selectedChore) { chore in
                EditChoreSheet(chore: chore, viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingAddChore) {
                AddChoreSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView()
            }
            .alert("Delete selected chores?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { deleteSelectedChores() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove \(selectedChoreIDs.count) chore\(selectedChoreIDs.count == 1 ? "" : "s").")
            }
            .toolbar { toolbar }
        }
    }
}

private extension ChoresHomeView {
    var addChoreHeaderOverlay: some View {
        HStack {
            Spacer()
            Button { isPresentingAddChore = true } label: {
                let base = Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)

                if #available(iOS 18.0, macOS 15.0, *) {
                    base.glassEffect(.regular.interactive(), in: .circle)
                } else {
                    base
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                        )
                }
            }
            .accessibilityLabel("Add Chore")
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
                        let selectionCount = selectedChoreIDs.count
                        let title = selectionCount == 0 ? "Delete Selected" : "Delete Selected (\(selectionCount))"
                        Label(title, systemImage: "trash")
                    }
                    .disabled(selectedChoreIDs.isEmpty)

                    Divider()

                    Button("Select All") {
                        selectedChoreIDs = Set(viewModel.chores.map(\.id))
                    }

                    Button("Deselect All") {
                        selectedChoreIDs.removeAll()
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
        selectedChoreIDs.removeAll()
        selectedChore = nil
        showDeleteConfirmation = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectingForDeletion = true
        }
    }

    func exitSelectionMode() {
        selectedChoreIDs.removeAll()
        showDeleteConfirmation = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectingForDeletion = false
        }
    }

    func toggleSelection(for chore: Chore) {
        if selectedChoreIDs.contains(chore.id) {
            selectedChoreIDs.remove(chore.id)
        } else {
            selectedChoreIDs.insert(chore.id)
        }
    }

    func deleteSelectedChores() {
        let idsToDelete = selectedChoreIDs
        for chore in viewModel.chores where idsToDelete.contains(chore.id) {
            viewModel.remove(chore)
        }
        exitSelectionMode()
    }
}

#if DEBUG
#Preview("Chores Home") {
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
    return ChoresHomeView()
        .environmentObject(session)
        .environmentObject(choresVM)
}
#endif

