import SwiftUI

struct ChoresHomeView: View {
    @StateObject private var viewModel = ChoresViewModel()

    @State private var showingAddChore = false
    @State private var selectedChore: Chore?
    @State private var isSelectingForDeletion = false
    @State private var selectedChoreIDs = Set<UUID>()
    @State private var showDeleteConfirmation = false

    private let headerHeight: CGFloat = 320

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                headerView

                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear
                            .frame(height: headerHeight - 59)

                        selectionControls
                            .padding(.horizontal, 16)

                        ChoresCard(
                            chores: viewModel.chores,
                            onAdd: { showingAddChore = true },
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
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $showingAddChore) {
                AddChoreSheet(viewModel: viewModel)
            }
            .sheet(item: $selectedChore) { chore in
                EditChoreSheet(chore: chore, viewModel: viewModel)
            }
            .alert("Delete selected chores?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelectedChores()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove \(selectedChoreIDs.count) chore\(selectedChoreIDs.count == 1 ? "" : "s").")
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

    @ViewBuilder
    var selectionControls: some View {
        if isSelectingForDeletion {
            HStack(spacing: 12) {
                Button("Cancel") {
                    exitSelectionMode()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()

                Button {
                    showDeleteConfirmation = true
                } label: {
                    let selectionCount = selectedChoreIDs.count
                    let title = selectionCount == 0 ? "Delete Selected" : "Delete Selected (\(selectionCount))"
                    Label(title, systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .disabled(selectedChoreIDs.isEmpty)
            }
        } else {
            HStack {
                Spacer()
                Button(action: beginSelectionMode) {
                    Label("Select", systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.blue)
            }
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
    ChoresHomeView()
}
#endif

