import Foundation

protocol FirestoreService {
    func fetchUserProfile(uid: String) async throws -> UserProfile?
    func saveUserProfile(_ profile: UserProfile) async throws
    func createFamily(named name: String, owner profile: UserProfile) async throws -> Family
    func joinFamily(withCode code: String, user profile: UserProfile, role: UserRole) async throws -> Family
    func fetchFamilySnapshot(familyId: String) async throws -> FamilyDataSnapshot
}

struct FirestoreServiceFactory {
    static func make() -> FirestoreService {
        #if canImport(FirebaseFirestore)
        return FirebaseFirestoreService()
        #else
        return MockFirestoreService.shared
        #endif
    }
}

#if canImport(FirebaseFirestore)
import FirebaseFirestore

final class FirebaseFirestoreService: FirestoreService {
    private enum Collection {
        static let users = "users"
        static let families = "families"
        static let members = "members"
        static let kids = "kids"
        static let chores = "chores"
        static let rewards = "rewards"
    }

    private let db = Firestore.firestore()

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await db.collection(Collection.users).document(uid).getDocument()
        guard let data = snapshot.data() else { return nil }
        return try decodeUserProfile(id: snapshot.documentID, data: data)
    }

    func saveUserProfile(_ profile: UserProfile) async throws {
        var data: [String: Any] = [
            "displayName": profile.displayName,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let role = profile.role { data["role"] = role.rawValue }
        if let familyId = profile.familyId { data["familyId"] = familyId }
        if profile.createdAt == nil {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        try await db.collection(Collection.users).document(profile.id).setData(data, merge: true)
    }

    func createFamily(named name: String, owner profile: UserProfile) async throws -> Family {
        let familyRef = db.collection(Collection.families).document()
        let inviteCode = generateInviteCode()
        let familyData: [String: Any] = [
            "name": name,
            "ownerId": profile.id,
            "inviteCode": inviteCode,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await familyRef.setData(familyData)

        let memberData: [String: Any] = [
            "role": UserRole.parent.rawValue,
            "joinedAt": FieldValue.serverTimestamp()
        ]
        try await familyRef.collection(Collection.members).document(profile.id).setData(memberData)

        let family = Family(
            id: familyRef.documentID,
            name: name,
            ownerId: profile.id,
            inviteCode: inviteCode,
            createdAt: Date()
        )
        return family
    }

    func joinFamily(withCode code: String, user profile: UserProfile, role: UserRole) async throws -> Family {
        let families = try await db.collection(Collection.families)
            .whereField("inviteCode", isEqualTo: code.uppercased())
            .limit(to: 1)
            .getDocuments()
        guard let document = families.documents.first else {
            throw NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family code not found."])
        }
        let data = document.data()
        let family = try decodeFamily(id: document.documentID, data: data)

        let memberData: [String: Any] = [
            "role": role.rawValue,
            "joinedAt": FieldValue.serverTimestamp()
        ]
        try await document.reference.collection(Collection.members).document(profile.id).setData(memberData)
        return family
    }

    func fetchFamilySnapshot(familyId: String) async throws -> FamilyDataSnapshot {
        let familyDoc = try await db.collection(Collection.families).document(familyId).getDocument()
        guard let familyData = familyDoc.data() else {
            throw NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family not found."])
        }
        let family = try decodeFamily(id: familyDoc.documentID, data: familyData)

        async let kidsTask = fetchKids(familyId: family.id)
        async let choresTask = fetchChores(familyId: family.id)
        async let rewardsTask = fetchRewards(familyId: family.id)

        let kids = try await kidsTask
        let chores = try await choresTask
        let rewards = try await rewardsTask

        return FamilyDataSnapshot(family: family, kids: kids, chores: chores, rewards: rewards)
    }
}

private extension FirebaseFirestoreService {
    func decodeUserProfile(id: String, data: [String: Any]) throws -> UserProfile {
        let displayName = data["displayName"] as? String ?? ""
        let roleRaw = data["role"] as? String
        let familyId = data["familyId"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let role = roleRaw.flatMap(UserRole.init(rawValue:))
        return UserProfile(id: id, displayName: displayName, role: role, familyId: familyId, createdAt: createdAt)
    }

    func decodeFamily(id: String, data: [String: Any]) throws -> Family {
        let name = data["name"] as? String ?? "Family"
        let ownerId = data["ownerId"] as? String ?? ""
        let inviteCode = data["inviteCode"] as? String ?? ""
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        return Family(id: id, name: name, ownerId: ownerId, inviteCode: inviteCode, createdAt: createdAt)
    }

    func fetchKids(familyId: String) async throws -> [Kid] {
        let snapshot = try await db.collection(Collection.families).document(familyId).collection(Collection.kids).getDocuments()
        return snapshot.documents.compactMap { document in
            do {
                let data = document.data()
                return try decodeKid(id: document.documentID, data: data)
            } catch {
                return nil
            }
        }
    }

    func fetchChores(familyId: String) async throws -> [Chore] {
        let snapshot = try await db.collection(Collection.families).document(familyId).collection(Collection.chores).getDocuments()
        return snapshot.documents.compactMap { document in
            do {
                let data = document.data()
                return try decodeChore(id: document.documentID, data: data)
            } catch {
                return nil
            }
        }
    }

    func fetchRewards(familyId: String) async throws -> [Reward] {
        let snapshot = try await db.collection(Collection.families).document(familyId).collection(Collection.rewards).getDocuments()
        return snapshot.documents.compactMap { document in
            do {
                let data = document.data()
                return try decodeReward(id: document.documentID, data: data)
            } catch {
                return nil
            }
        }
    }

    func decodeKid(id: String, data: [String: Any]) throws -> Kid {
        let name = data["name"] as? String ?? ""
        let colorHex = data["colorHex"] as? String ?? Kid.defaultColorHex
        let coins = data["coins"] as? Int ?? 0
        return Kid(id: id, name: name, colorHex: colorHex, coins: coins)
    }

    func decodeChore(id: String, data: [String: Any]) throws -> Chore {
        let name = data["name"] as? String ?? ""
        let assignedTo = data["assignedTo"] as? [String] ?? []
        let dueTimestamp = data["dueDate"] as? Timestamp
        let dueDate = dueTimestamp?.dateValue() ?? Date()
        let rewardCoins = data["rewardCoins"] as? Int ?? 0
        let punishmentCoins = data["punishmentCoins"] as? Int ?? 0
        let frequencyRaw = data["frequency"] as? String ?? Chore.Frequency.once.rawValue
        let frequency = Chore.Frequency(rawValue: frequencyRaw) ?? .once
        let icon = data["icon"] as? String ?? "🧹"
        return Chore(id: UUID(uuidString: id) ?? UUID(), name: name, assignedTo: assignedTo, dueDate: dueDate, rewardCoins: rewardCoins, punishmentCoins: punishmentCoins, frequency: frequency, icon: icon)
    }

    func decodeReward(id: String, data: [String: Any]) throws -> Reward {
        let name = data["name"] as? String ?? ""
        let cost = data["cost"] as? Int ?? 0
        let details = data["details"] as? String ?? ""
        let icon = data["icon"] as? String ?? "🎁"
        return Reward(id: UUID(uuidString: id) ?? UUID(), name: name, cost: cost, details: details, icon: icon)
    }

    func generateInviteCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }
}
#endif

// Make MockFirestoreService always available so previews/tests can use it even when FirebaseFirestore is present.
final class MockFirestoreService: FirestoreService {
    static let shared = MockFirestoreService()

    private init() {}

    private var storedProfiles: [String: UserProfile] = [:]
    private var storedFamilies: [String: Family] = [:]
    private var storedFamilyData: [String: FamilyDataSnapshot] = [:]

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        storedProfiles[uid]
    }

    func saveUserProfile(_ profile: UserProfile) async throws {
        storedProfiles[profile.id] = profile
    }

    func createFamily(named name: String, owner profile: UserProfile) async throws -> Family {
        let id = UUID().uuidString
        let family = Family(id: id, name: name, ownerId: profile.id, inviteCode: generateInviteCode(), createdAt: Date())
        storedFamilies[id] = family
        storedFamilyData[id] = FamilyDataSnapshot(family: family, kids: [], chores: [], rewards: [])
        return family
    }

    func joinFamily(withCode code: String, user profile: UserProfile, role: UserRole) async throws -> Family {
        guard let family = storedFamilies.values.first(where: { $0.inviteCode == code.uppercased() }) else {
            throw NSError(domain: "MockFirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family code not found."])
        }
        return family
    }

    func fetchFamilySnapshot(familyId: String) async throws -> FamilyDataSnapshot {
        if let snapshot = storedFamilyData[familyId] {
            return snapshot
        }
        guard let family = storedFamilies[familyId] else {
            throw NSError(domain: "MockFirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family not found."])
        }
        let snapshot = FamilyDataSnapshot(family: family, kids: [], chores: [], rewards: [])
        storedFamilyData[familyId] = snapshot
        return snapshot
    }

    private func generateInviteCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }
}
