import SwiftUI

struct AddKidSheet: View {
    @ObservedObject var viewModel: FamilyViewModel
    @EnvironmentObject private var choresViewModel: ChoresViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColor: Color
    @State private var selectedChoreIDs: Set<UUID> = []

    private let palette: [Color] = [.pink, .yellow, .green, .orange, .purple, .teal, .blue]

    init(viewModel: FamilyViewModel) {
        self.viewModel = viewModel
        _selectedColor = State(initialValue: palette.randomElement() ?? .blue)
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                assignChoresSection
            }
            .navigationTitle("Add Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private extension AddKidSheet {
    var detailsSection: some View {
        Section("Details") {
            TextField("Kid's name", text: $name)
            #if os(iOS)
            .textInputAutocapitalization(.words)
            #endif

            ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
        }
    }

    var assignChoresSection: some View {
        Section("Assign Chores") {
            if choresViewModel.chores.isEmpty {
                Text("No chores available yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(choresViewModel.chores) { chore in
                    Toggle(isOn: choreBinding(for: chore)) {
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

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func choreBinding(for chore: Chore) -> Binding<Bool> {
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

    func save() {
        guard !trimmedName.isEmpty else { return }
        viewModel.addKid(
            name: trimmedName,
            color: selectedColor,
            choresViewModel: choresViewModel,
            assignedChoreIDs: selectedChoreIDs
        )
        dismiss()
    }
}

#if DEBUG
#Preview("Add Kid") {
    AddKidSheet(viewModel: FamilyViewModel())
        .environmentObject(ChoresViewModel())
}
#endif
