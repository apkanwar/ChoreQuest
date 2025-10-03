import Foundation

enum SubmissionStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case approved
    case rejected

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum SubmissionKind: String, Codable, CaseIterable, Identifiable {
    case chore
    case reward

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .chore: return "Chore"
        case .reward: return "Reward"
        }
    }
}

struct Submission: Identifiable, Hashable, Codable {
    let id: UUID
    let type: SubmissionKind
    let kidUid: String
    let kidName: String
    let createdAt: Date

    var choreId: UUID?
    var choreName: String?
    var rewardId: UUID?
    var rewardName: String?

    /// Positive coins awarded when a chore submission is approved.
    var rewardCoins: Int?
    /// Positive coins that will be deducted when a reward redemption is approved.
    var rewardCost: Int?

    /// Storage path for any uploaded proof photo. Optional because reward submissions do not include media.
    var storagePath: String?
    /// Cached download URL string for convenience when rendering. This is cleared once the asset is deleted.
    var photoURL: String?

    var status: SubmissionStatus
    var reviewedAt: Date?
    var reviewerUid: String?
    var reviewerName: String?
    var decisionNote: String?

    init(
        id: UUID = UUID(),
        type: SubmissionKind,
        kidUid: String,
        kidName: String,
        createdAt: Date = Date(),
        choreId: UUID? = nil,
        choreName: String? = nil,
        rewardId: UUID? = nil,
        rewardName: String? = nil,
        rewardCoins: Int? = nil,
        rewardCost: Int? = nil,
        storagePath: String? = nil,
        photoURL: String? = nil,
        status: SubmissionStatus = .pending,
        reviewedAt: Date? = nil,
        reviewerUid: String? = nil,
        reviewerName: String? = nil,
        decisionNote: String? = nil
    ) {
        self.id = id
        self.type = type
        self.kidUid = kidUid
        self.kidName = kidName
        self.createdAt = createdAt
        self.choreId = choreId
        self.choreName = choreName
        self.rewardId = rewardId
        self.rewardName = rewardName
        self.rewardCoins = rewardCoins
        self.rewardCost = rewardCost
        self.storagePath = storagePath
        self.photoURL = photoURL
        self.status = status
        self.reviewedAt = reviewedAt
        self.reviewerUid = reviewerUid
        self.reviewerName = reviewerName
        self.decisionNote = decisionNote
    }
}

extension Submission {
    var displayTitle: String {
        switch type {
        case .chore: return choreName ?? "Chore"
        case .reward: return rewardName ?? "Reward"
        }
    }

    var hasPhoto: Bool {
        return !(photoURL?.isEmpty ?? true) || (storagePath?.isEmpty == false)
    }

    /// Signed value representing the net coin change if the submission is approved.
    var pointsDeltaOnApproval: Int? {
        if let rewardCoins { return rewardCoins }
        if let rewardCost { return -rewardCost }
        return nil
    }

    var statusBadgeColorName: String {
        switch status {
        case .pending: return "yellow"
        case .approved: return "green"
        case .rejected: return "red"
        }
    }
}

#if DEBUG
extension Submission {
    static let previewChore = Submission(
        type: .chore,
        kidUid: "kid-123",
        kidName: "Kenny Kid",
        choreId: UUID(),
        choreName: "Make Bed",
        rewardCoins: 10,
        storagePath: "families/demo/submissions/demo/chore.jpg",
        photoURL: "https://example.com/photo.jpg"
    )

    static let previewReward = Submission(
        type: .reward,
        kidUid: "kid-123",
        kidName: "Kenny Kid",
        rewardId: UUID(),
        rewardName: "Movie Night",
        rewardCost: 40
    )
}
#endif
