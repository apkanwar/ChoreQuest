import Foundation

struct AuthenticatedUser: Identifiable, Equatable {
    let id: String
    var displayName: String?
    var email: String?
}
