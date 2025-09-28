import Foundation

struct FamilyInvite: Identifiable, Codable, Equatable {
    let id: String
    let familyId: String
    let code: String
    let role: UserRole
    let createdBy: String
    var createdAt: Date?
    var expiresAt: Date?
    var maxUses: Int?
    var usedCount: Int
    var revoked: Bool

    init(
        id: String,
        familyId: String,
        code: String,
        role: UserRole,
        createdBy: String,
        createdAt: Date? = nil,
        expiresAt: Date? = nil,
        maxUses: Int? = nil,
        usedCount: Int = 0,
        revoked: Bool = false
    ) {
        self.id = id
        self.familyId = familyId
        self.code = code
        self.role = role
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.maxUses = maxUses
        self.usedCount = usedCount
        self.revoked = revoked
    }
}
