import SwiftUI

struct AddChoreSheet: View {
    @ObservedObject var viewModel: ChoresViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var assignedTo: String = ""
    @State private var dueDate: Date = .now
    @State private var rewardCoins: Int = 10
    @State private var punishmentCoins: Int = 5
    @State private var frequency: Chore.Frequency = .daily
    @State private var icon: String = "🧹"

    private let icons = ["🧹","🛏️","🗑️","📚","🧺","🍽️","🧼","🧽"]

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                rewardSection
            }
            .navigationTitle("Add Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private extension AddChoreSheet {
    var detailsSection: some View {
        Section("Details") {
            TextField("Chore name", text: $name)
            Picker("Assigned to", selection: $assignedTo) {
                Text("Unassigned").tag("")
                ForEach(viewModel.availableKids, id: \.self) { kid in
                    Text(kid).tag(kid)
                }
            }
            DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
            Picker("Frequency", selection: $frequency) {
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
                TextField("Emoji", text: $icon)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(icons, id: \.self) { emoji in
                        Button(emoji) { icon = emoji }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    var rewardSection: some View {
        Section("Rewards & Consequences") {
            Stepper(value: $rewardCoins, in: 0...500) {
                LabeledContent("Reward") {
                    Text("+\(rewardCoins) coins")
                        .foregroundStyle(.secondary)
                }
            }
            Stepper(value: $punishmentCoins, in: 0...500) {
                LabeledContent("Punishment") {
                    Text("-\(punishmentCoins) coins")
                        .foregroundStyle(.secondary)
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

    func save() {
        guard !trimmedName.isEmpty else { return }
        let newChore = Chore(
            name: trimmedName,
            assignedTo: assignedTo,
            dueDate: dueDate,
            rewardCoins: rewardCoins,
            punishmentCoins: punishmentCoins,
            frequency: frequency,
            icon: icon
        )
        viewModel.add(newChore)
        dismiss()
    }
}

#if DEBUG
#Preview("Add Chore") {
    AddChoreSheet(viewModel: ChoresViewModel())
}
#endif
