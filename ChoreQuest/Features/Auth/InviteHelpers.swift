import Foundation

@MainActor
func sessionCreateInviteProxy(familyId: String, role: UserRole) async throws -> FamilyInvite {
    let service = FirestoreServiceFactory.make()
    let expiry = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    return try await service.createInvite(familyId: familyId, role: role, maxUses: 1, expiresAt: expiry)
}
