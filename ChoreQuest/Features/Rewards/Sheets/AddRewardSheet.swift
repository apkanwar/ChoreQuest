import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AddRewardSheet: View {
    @ObservedObject var viewModel: RewardsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var cost: Int = 50
    @State private var details: String = ""
    @State private var icon: String = "🎁"
    @FocusState private var emojiFieldFocused: Bool

    private let icons = ["🎁","🎮","🍦","🎟️","📺","📚","🎧","🍿"]

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                costSection
            }
            .navigationTitle("Add Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private extension AddRewardSheet {
    var detailsSection: some View {
        Section("Details") {
            TextField("Reward name", text: $name)
            TextField("Describe the reward", text: $details, axis: .vertical)
                .lineLimit(2...5)
            iconPicker
        }
    }

    var costSection: some View {
        Section("Cost") {
            Stepper(value: $cost, in: 0...500) {
                LabeledContent("Cost") {
                    Text("\(cost) coins")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Icon")
                Spacer()
                TextField("Emoji", text: Binding(
                    get: { icon },
                    set: { newValue in
                        if let first = newValue.first { icon = String(first) } else { icon = "" }
                    }
                ))
                .focused($emojiFieldFocused)
                .disableAutocorrection(true)
                .keyboardType(.default)
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
                        #if os(macOS)
                        NSApp.orderFrontCharacterPalette(nil)
                        #endif
                    } label: {
                        Image(systemName: "face.smiling")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Choose any emoji")
                    ForEach(icons, id: \.self) { emoji in
                        Button(emoji) { icon = emoji }
                            .buttonStyle(.bordered)
                    }
                }
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
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDetails: String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() {
        guard !trimmedName.isEmpty else { return }
        let reward = Reward(
            name: trimmedName,
            cost: cost,
            details: trimmedDetails,
            icon: icon
        )
        viewModel.add(reward)
        dismiss()
    }
}

#if DEBUG
#Preview("Add Reward") {
    AddRewardSheet(viewModel: RewardsViewModel())
}
#endif
