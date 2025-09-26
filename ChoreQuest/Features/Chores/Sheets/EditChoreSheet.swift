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
            Picker(
                "Assigned to",
                selection: Binding(
                    get: { draft.assignedTo.first ?? "" },
                    set: { newValue in
                        draft.assignedTo = newValue.isEmpty ? [] : [newValue]
                    }
                )
            ) {
                Text("Unassigned").tag("")
                ForEach(viewModel.availableKids, id: \.self) { kid in
                    Text(kid).tag(kid)
                }
            }
            DatePicker("Due date", selection: $draft.dueDate, displayedComponents: .date)
            Picker("Frequency", selection: $draft.frequency) {
                ForEach(Chore.Frequency.allCases) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            iconPicker
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
        .onChange(of: draft.icon) { newValue in
            if let first = newValue.first { draft.icon = String(first) } else { draft.icon = "" }
        }
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
