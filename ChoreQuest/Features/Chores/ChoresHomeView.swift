import SwiftUI

struct ChoresHomeView: View {
    @EnvironmentObject private var viewModel: ChoresViewModel

    @State private var selectedChore: Chore?
    @State private var isSelectingForDeletion = false
    @State private var selectedChoreIDs = Set<UUID>()
    @State private var showDeleteConfirmation = false
    @State private var isPresentingAddChore = false

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

                        ChoresCard(
                            chores: viewModel.chores,
                            onEdit: { selectedChore = $0 },
                            isSelectingForDeletion: isSelectingForDeletion,
                            selectedChoreIDs: selectedChoreIDs,
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
                        // Add button on right with Liquid Glass effect
                        Button {
                            isPresentingAddChore = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .accessibilityLabel("Add Chore")
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
            .sheet(item: $selectedChore) { chore in
                EditChoreSheet(chore: chore, viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingAddChore) {
                AddChoreSheet(viewModel: viewModel)
            }
            .alert("Delete selected chores?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelectedChores()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove \(selectedChoreIDs.count) chore\(selectedChoreIDs.count == 1 ? "" : "s").")
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

private extension ChoresHomeView {
    var headerView: some View {
        HeaderCard()
            .ignoresSafeArea(edges: .top)
            .frame(height: headerHeight)
            .zIndex(1000)
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
    ChoresHomeView()
        .environmentObject(ChoresViewModel())
}
#endif
