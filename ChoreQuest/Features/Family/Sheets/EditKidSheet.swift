import SwiftUI

struct EditKidSheet: View {
    let kid: Kid
    @ObservedObject var viewModel: FamilyViewModel
    @EnvironmentObject private var choresViewModel: ChoresViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Kid
    @State private var selectedChoreIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    init(kid: Kid, viewModel: FamilyViewModel) {
        self.kid = kid
        self.viewModel = viewModel
        _draft = State(initialValue: kid)
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                choresSection
                savingsSection
                deleteSection
            }
            .navigationTitle("Edit Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .onAppear(perform: loadAssignments)
            .confirmationDialog("Delete \(kid.name)?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: deleteKid)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the child and their local data from this device.")
            }
        }
    }
}

private extension EditKidSheet {
    var detailsSection: some View {
        Section("Details") {
            TextField("Kid's name", text: $draft.name)
            #if os(iOS)
            .textInputAutocapitalization(.words)
            #endif

            ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
        }
    }

    var choresSection: some View {
        Section("Chores") {
            if choresViewModel.chores.isEmpty {
                Text("No chores available yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(choresViewModel.chores) { chore in
                    Toggle(isOn: assignmentBinding(for: chore)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(chore.icon) \(chore.name)")
                            if !chore.assignedTo.isEmpty {
                                Text("Assigned: \(chore.assignedTo.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    var savingsSection: some View {
        Section("Savings") {
            LabeledContent("Coins") {
                Text("\(kid.coins) coins")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .disabled(trimmedName.isEmpty)
        }
    }

    var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var colorBinding: Binding<Color> {
        Binding(
            get: { draft.color },
            set: { newColor in
                draft = draft.updatingColor(newColor)
            }
        )
    }

    func assignmentBinding(for chore: Chore) -> Binding<Bool> {
        Binding(
            get: { selectedChoreIDs.contains(chore.id) },
            set: { isSelected in
                if isSelected {
                    selectedChoreIDs.insert(chore.id)
                } else {
                    selectedChoreIDs.remove(chore.id)
                }
            }
        )
    }

    func loadAssignments() {
        let assigned = choresViewModel.chores
            .filter { $0.assignedTo.contains(kid.name) }
            .map(\.id)
        selectedChoreIDs = Set(assigned)
    }

    func save() {
        guard !trimmedName.isEmpty else { return }
        var sanitized = draft
        sanitized.name = trimmedName
        viewModel.updateKid(
            sanitized,
            originalKid: kid,
            choresViewModel: choresViewModel,
            assignedChoreIDs: selectedChoreIDs
        )
        dismiss()
    }

    func deleteKid() {
        viewModel.removeKid(kid, choresViewModel: choresViewModel)
        dismiss()
    }

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Kid", systemImage: "trash")
            }
        }
    }
}

#if DEBUG
#Preview("Edit Kid") {
    EditKidSheet(kid: Kid.previewList.first!, viewModel: FamilyViewModel())
        .environmentObject(ChoresViewModel())
}
#endif

