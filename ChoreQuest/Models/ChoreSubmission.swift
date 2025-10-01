import Foundation

enum SubmissionStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case approved
    case rejected

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct ChoreSubmission: Identifiable, Hashable, Codable {
    let id: UUID
    let choreId: UUID
    let choreName: String
    let kidName: String
    let photoURL: String
    let submittedAt: Date
    let rewardCoins: Int

    var status: SubmissionStatus
    var reviewedAt: Date?
    var reviewer: String?
    var rejectionReason: String?

    init(
        id: UUID = UUID(),
        choreId: UUID,
        choreName: String,
        kidName: String,
        photoURL: String,
        submittedAt: Date = Date(),
        rewardCoins: Int,
        status: SubmissionStatus = .pending,
        reviewedAt: Date? = nil,
        reviewer: String? = nil,
        rejectionReason: String? = nil
    ) {
        self.id = id
        self.choreId = choreId
        self.choreName = choreName
        self.kidName = kidName
        self.photoURL = photoURL
        self.submittedAt = submittedAt
        self.rewardCoins = rewardCoins
        self.status = status
        self.reviewedAt = reviewedAt
        self.reviewer = reviewer
        self.rejectionReason = rejectionReason
    }
}

#if DEBUG
extension ChoreSubmission {
    static let preview = ChoreSubmission(
        choreId: UUID(),
        choreName: "Make Bed",
        kidName: "Kenny Kid",
        photoURL: "https://example.com/photo.jpg",
        rewardCoins: 10,
        status: .pending
    )
}
#endif
