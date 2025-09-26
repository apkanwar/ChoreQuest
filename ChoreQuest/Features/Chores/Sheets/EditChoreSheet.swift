import SwiftUI

struct EditChoreSheet: View {
    @ObservedObject var viewModel: ChoresViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Chore
    @FocusState private var emojiFieldFocused: Bool

    private let icons = ["🧹","🛏️","🗑️","📚","🧺","🍽️","🧼","🧽"]

    init(chore: Chore, viewModel: ChoresViewModel) {
        _draft = State(initialValue: chore)
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                assigneesSection
                rewardSection
                deleteSection
            }
            .navigationTitle("Edit Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private extension EditChoreSheet {
    var detailsSection: some View {
        Section("Details") {
            TextField("Chore name", text: $draft.name)
            DatePicker("Due date", selection: $draft.dueDate, displayedComponents: .date)
            Picker("Frequency", selection: $draft.frequency) {
                ForEach(Chore.Frequency.allCases) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            iconPicker
        }
    }

    var assigneesSection: some View {
        Section("Assign To") {
            if draft.assignedTo.isEmpty {
                Text("Currently unassigned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(draft.assignedTo.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.availableKids, id: \.self) { kid in
                Toggle(kid, isOn: toggleBinding(for: kid))
            }

            if !draft.assignedTo.isEmpty {
                Button("Clear Selection") {
                    draft.assignedTo.removeAll()
                }
                .tint(.red)
            }
        }
    }

    var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Icon")
                Spacer()
                TextField("Emoji", text: $draft.icon)
                    .focused($emojiFieldFocused)
                    .disableAutocorrection(true)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button {
                        emojiFieldFocused = true
                    } label: {
                        Image(systemName: "face.smiling")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Choose any emoji")
                    ForEach(icons, id: \.self) { emoji in
                        Button(emoji) { draft.icon = emoji }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .onChange(of: draft.icon) { _, newValue in
            if let first = newValue.first { draft.icon = String(first) } else { draft.icon = "" }
        }
    }

    func toggleBinding(for kid: String) -> Binding<Bool> {
        Binding(
            get: { draft.assignedTo.contains(kid) },
            set: { isSelected in
                if isSelected {
                    var updated = Set(draft.assignedTo)
                    updated.insert(kid)
                    draft.assignedTo = viewModel.availableKids.filter { updated.contains($0) }
                } else {
                    var updated = Set(draft.assignedTo)
                    updated.remove(kid)
                    draft.assignedTo = viewModel.availableKids.filter { updated.contains($0) }
                }
            }
        )
    }

    var rewardSection: some View {
        Section("Rewards & Consequences") {
            Stepper(value: $draft.rewardCoins, in: 0...500) {
                LabeledContent("Reward") {
                    Text("+\(draft.rewardCoins) coins")
                        .foregroundStyle(.secondary)
                }
            }
            Stepper(value: $draft.punishmentCoins, in: 0...500) {
                LabeledContent("Punishment") {
                    Text("-\(draft.punishmentCoins) coins")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.remove(draft)
                dismiss()
            } label: {
                Label("Delete Chore", systemImage: "trash")
            }
        }
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                viewModel.update(draft)
                dismiss()
            }
        }
    }
}

#if DEBUG
#Preview("Edit Chore") {
    EditChoreSheet(chore: .preview, viewModel: ChoresViewModel())
}
#endif
