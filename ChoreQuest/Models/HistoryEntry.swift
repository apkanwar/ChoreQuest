import Foundation

enum HistoryType: String, Codable, CaseIterable, Identifiable {
    case choreCompleted
    case choreMissed
    case penaltyReversed
    case rewardRedeemed

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .choreCompleted: return "Chore Completed"
        case .choreMissed: return "Chore Missed"
        case .penaltyReversed: return "Penalty Reversed"
        case .rewardRedeemed: return "Reward Redeemed"
        }
    }
}

struct HistoryEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let type: HistoryType
    var kidId: String?
    let kidName: String
    let title: String
    let amount: Int // positive for coins added, negative for coins spent
    let timestamp: Date

    // Deep-linking to related content
    var submissionId: UUID?
    var photoURL: String?
    var result: SubmissionStatus?
    var decidedByUid: String?
    var decidedByName: String?
    var note: String?
    let reversedAt: Date?
    let reversedByUid: String?
    let reversedByName: String?

    init(
        id: UUID = UUID(),
        type: HistoryType,
        kidName: String,
        title: String,
        amount: Int,
        timestamp: Date = Date(),
        submissionId: UUID? = nil,
        photoURL: String? = nil,
        result: SubmissionStatus? = nil,
        decidedByUid: String? = nil,
        decidedByName: String? = nil,
        note: String? = nil,
        reversedAt: Date? = nil,
        reversedByUid: String? = nil,
        reversedByName: String? = nil,
        kidId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.kidName = kidName
        self.title = title
        self.amount = amount
        self.timestamp = timestamp
        self.submissionId = submissionId
        self.photoURL = photoURL
        self.result = result
        self.decidedByUid = decidedByUid
        self.decidedByName = decidedByName
        self.note = note
        self.reversedAt = reversedAt
        self.reversedByUid = reversedByUid
        self.reversedByName = reversedByName
        self.kidId = kidId
    }

    var isReversed: Bool { reversedAt != nil }
}

#if DEBUG
extension HistoryEntry {
    static let previewList: [HistoryEntry] = [
        HistoryEntry(type: .choreCompleted, kidName: "Kenny Kid", title: "Make Bed", amount: 10, submissionId: UUID(), photoURL: "https://example.com/photo.jpg", result: .approved, decidedByName: "Paula Parent"),
        HistoryEntry(type: .rewardRedeemed, kidName: "Kenny Kid", title: "Movie Night", amount: 0, result: .rejected, decidedByName: "Paula Parent", note: "Already watched a movie")
    ]
}
#endif
