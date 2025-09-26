import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AddChoreSheet: View {
    @ObservedObject var viewModel: ChoresViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedAssignees: Set<String> = []
    @State private var dueDate: Date = .now
    @State private var rewardCoins: Int = 10
    @State private var punishmentCoins: Int = 5
    @State private var frequency: Chore.Frequency = .daily
    @State private var icon: String = "🧹"
    @FocusState private var emojiFieldFocused: Bool

    private let icons = ["🧹","🛏️","🗑️","📚","🧺","🍽️","🧼","🧽"]

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                assigneesSection
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
            DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
            Picker("Frequency", selection: $frequency) {
                ForEach(Chore.Frequency.allCases) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            iconPicker
        }
    }

    var assigneesSection: some View {
        Section("Assign To") {
            if selectedAssignees.isEmpty {
                Text("Currently unassigned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(sortedAssignees(from: selectedAssignees).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.availableKids, id: \.self) { kid in
                Toggle(kid, isOn: binding(for: kid))
            }

            if !selectedAssignees.isEmpty {
                Button("Clear Selection") {
                    selectedAssignees.removeAll()
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

    func binding(for kid: String) -> Binding<Bool> {
        Binding(
            get: { selectedAssignees.contains(kid) },
            set: { isSelected in
                if isSelected {
                    selectedAssignees.insert(kid)
                } else {
                    selectedAssignees.remove(kid)
                }
            }
        )
    }

    func sortedAssignees(from selections: Set<String>) -> [String] {
        viewModel.availableKids.filter { selections.contains($0) }
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
        let assignees = sortedAssignees(from: selectedAssignees)
        let newChore = Chore(
            name: trimmedName,
            assignedTo: assignees,
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
