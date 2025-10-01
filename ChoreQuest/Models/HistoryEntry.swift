import Foundation

enum HistoryType: String, Codable, CaseIterable, Identifiable {
    case choreCompleted
    case rewardRedeemed

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .choreCompleted: return "Chore Completed"
        case .rewardRedeemed: return "Reward Redeemed"
        }
    }
}

struct HistoryEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let type: HistoryType
    let kidName: String
    let title: String
    let details: String
    let amount: Int // positive for coins added, negative for coins spent
    let timestamp: Date

    // Deep-linking to related content
    var submissionId: UUID?
    var photoURL: String?

    init(
        id: UUID = UUID(),
        type: HistoryType,
        kidName: String,
        title: String,
        details: String,
        amount: Int,
        timestamp: Date = Date(),
        submissionId: UUID? = nil,
        photoURL: String? = nil
    ) {
        self.id = id
        self.type = type
        self.kidName = kidName
        self.title = title
        self.details = details
        self.amount = amount
        self.timestamp = timestamp
        self.submissionId = submissionId
        self.photoURL = photoURL
    }
}

#if DEBUG
extension HistoryEntry {
    static let previewList: [HistoryEntry] = [
        HistoryEntry(type: .choreCompleted, kidName: "Kenny Kid", title: "Make Bed", details: "Approved by Parent", amount: 10, submissionId: UUID(), photoURL: "https://example.com/photo.jpg"),
        HistoryEntry(type: .rewardRedeemed, kidName: "Kenny Kid", title: "Movie Night", details: "Redeemed", amount: -50)
    ]
}
#endif
