import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case role
        case familyId
        case createdAt
    }

    let id: String
    var displayName: String
    var role: UserRole?
    var familyId: String?
    var createdAt: Date?

    init(
        id: String,
        displayName: String,
        role: UserRole? = nil,
        familyId: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.familyId = familyId
        self.createdAt = createdAt
    }
}
