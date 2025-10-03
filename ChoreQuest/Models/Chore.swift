import Foundation

// MARK: - Core Model
struct Chore: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var assignedTo: [String]
    var dueDate: Date
    var rewardCoins: Int
    var punishmentCoins: Int
    var frequency: Frequency
    var paused: Bool
    var icon: String

    init(
        id: UUID = UUID(),
        name: String,
        assignedTo: [String],
        dueDate: Date,
        rewardCoins: Int,
        punishmentCoins: Int,
        frequency: Frequency,
        paused: Bool = false,
        icon: String = "🧹"
    ) {
        self.id = id
        self.name = name
        self.assignedTo = assignedTo
        self.dueDate = dueDate
        self.rewardCoins = rewardCoins
        self.punishmentCoins = punishmentCoins
        self.frequency = frequency
        self.paused = paused
        self.icon = icon
    }

    enum Frequency: String, CaseIterable, Identifiable, Codable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case once = "Once"

        var id: String { rawValue }
        var displayName: String { rawValue }
    }
}

#if DEBUG
// MARK: - Preview Helpers
extension Chore {
    static let preview = Chore(
        name: "Make Bed",
        assignedTo: ["Akam"],
        dueDate: .now.addingTimeInterval(86400),
        rewardCoins: 10,
        punishmentCoins: 5,
        frequency: .daily,
        paused: false,
        icon: "🛏️"
    )

    static let previewList: [Chore] = [
        .preview,
        Chore(
            name: "Take out Trash",
            assignedTo: ["Ashley"],
            dueDate: .now.addingTimeInterval(172800),
            rewardCoins: 8,
            punishmentCoins: 5,
            frequency: .weekly,
            paused: false,
            icon: "🗑️"
        ),
        Chore(
            name: "Do Homework",
            assignedTo: ["Sunny"],
            dueDate: .now.addingTimeInterval(259200),
            rewardCoins: 12,
            punishmentCoins: 6,
            frequency: .daily,
            paused: false,
            icon: "📚"
        )
    ]
}
#endif
