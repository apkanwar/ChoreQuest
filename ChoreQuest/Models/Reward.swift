import Foundation

struct Reward: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var cost: Int
    var details: String
    var icon: String

    init(
        id: UUID = UUID(),
        name: String,
        cost: Int,
        details: String,
        icon: String = "🎁"
    ) {
        self.id = id
        self.name = name
        self.cost = cost
        self.details = details
        self.icon = icon
    }
}

#if DEBUG
extension Reward {
    static let preview = Reward(
        name: "Movie Night",
        cost: 50,
        details: "Pick the family movie and snacks",
        icon: "🎬"
    )

    static let previewList: [Reward] = [
        .preview,
        Reward(
            name: "Extra Screen Time",
            cost: 40,
            details: "30 more minutes after dinner",
            icon: "🕹️"
        ),
        Reward(
            name: "Ice Cream Trip",
            cost: 75,
            details: "Weekend ice cream outing",
            icon: "🍦"
        )
    ]
}
#endif
