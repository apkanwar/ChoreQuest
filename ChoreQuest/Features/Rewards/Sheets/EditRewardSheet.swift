import SwiftUI

struct EditRewardSheet: View {
    @ObservedObject var viewModel: RewardsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Reward
    @FocusState private var emojiFieldFocused: Bool

    private let icons = ["🎁","🎮","🍦","🎟️","📺","📚","🎧","🍿"]

    init(reward: Reward, viewModel: RewardsViewModel) {
        _draft = State(initialValue: reward)
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                costSection
                deleteSection
            }
            .navigationTitle("Edit Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private extension EditRewardSheet {
    var detailsSection: some View {
        Section("Details") {
            TextField("Reward name", text: $draft.name)
            TextField("Describe the reward", text: $draft.details, axis: .vertical)
                .lineLimit(2...5)
            iconPicker
        }
    }

    var costSection: some View {
        Section("Cost") {
            Stepper(value: $draft.cost, in: 0...500) {
                LabeledContent("Cost") {
                    Text("\(draft.cost) coins")
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
                Label("Delete Reward", systemImage: "trash")
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
        .onChange(of: draft.icon) {
            if let first = draft.icon.first { draft.icon = String(first) } else { draft.icon = "" }
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
            .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#if DEBUG
#Preview("Edit Reward") {
    EditRewardSheet(reward: .preview, viewModel: RewardsViewModel())
}
#endif
