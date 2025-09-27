import Foundation

struct Family: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var ownerId: String
    var inviteCode: String
    var createdAt: Date?

    init(
        id: String,
        name: String,
        ownerId: String,
        inviteCode: String,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.ownerId = ownerId
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }
}
