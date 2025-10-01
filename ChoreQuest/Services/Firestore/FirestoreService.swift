import Foundation

protocol FirestoreService {
    func fetchUserProfile(uid: String) async throws -> UserProfile?
    func saveUserProfile(_ profile: UserProfile) async throws
    func createFamily(named name: String, owner profile: UserProfile) async throws -> Family
    func createInvite(familyId: String, role: UserRole, maxUses: Int?, expiresAt: Date?) async throws -> FamilyInvite
    func joinFamily(withInviteCode code: String, user profile: UserProfile) async throws -> (family: Family, role: UserRole)
    func fetchFamilySnapshot(familyId: String) async throws -> FamilyDataSnapshot
    func fetchLatestInvite(familyId: String, role: UserRole) async throws -> FamilyInvite?
    func fetchUserRoleInFamily(familyId: String, userId: String) async throws -> UserRole?

    func updateFamilyName(familyId: String, name: String) async throws

    func saveKids(_ kids: [Kid], familyId: String) async throws
    func saveChores(_ chores: [Chore], familyId: String) async throws
    func saveRewards(_ rewards: [Reward], familyId: String) async throws

    func leaveFamilyAndDeleteIfLastParent(user profile: UserProfile) async throws

    func addChoreSubmission(_ submission: ChoreSubmission, familyId: String) async throws
    func addHistoryEntry(_ entry: HistoryEntry, familyId: String) async throws
    func fetchHistory(familyId: String) async throws -> [HistoryEntry]
    func updateKidCoins(kidName: String, delta: Int, familyId: String) async throws

    func fetchSubmissions(familyId: String) async throws -> [ChoreSubmission]
    func updateSubmissionStatus(familyId: String, submissionId: UUID, status: SubmissionStatus, reviewer: String?, rejectionReason: String?) async throws
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
        static let invites = "invites"
        static let submissions = "submissions"
        static let history = "history"
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

        // Ensure server fields are cleared when the local profile has nil values
        if let role = profile.role {
            data["role"] = role.rawValue
        } else {
            data["role"] = FieldValue.delete()
        }

        if let familyId = profile.familyId {
            data["familyId"] = familyId
        } else {
            data["familyId"] = FieldValue.delete()
        }

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

    func createInvite(familyId: String, role: UserRole, maxUses: Int?, expiresAt: Date?) async throws -> FamilyInvite {
        let familyRef = db.collection(Collection.families).document(familyId)
        let invitesRef = familyRef.collection(Collection.invites)
        // Purge expired invites first so they don't count toward the cap
        let nowTs = Timestamp(date: Date())
        let expiredSnap = try await invitesRef.whereField("expiresAt", isLessThan: nowTs).getDocuments()
        for doc in expiredSnap.documents {
            try await doc.reference.delete()
        }
        // Enforce a maximum of 4 invites per family by deleting the oldest if needed
        let existingInvites = try await invitesRef.order(by: "createdAt", descending: false).getDocuments()
        if existingInvites.documents.count >= 4 {
            if let oldest = existingInvites.documents.first {
                try await oldest.reference.delete()
            }
        }
        let inviteRef = invitesRef.document()
        let code = generateInviteCode(length: 8)
        // Determine current user id if available; fallback to empty string
        let createdBy = ""
        var data: [String: Any] = [
            "code": code,
            "role": role.rawValue,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "usedCount": 0,
            "revoked": false
        ]
        if let maxUses { data["maxUses"] = maxUses }
        if let expiresAt { data["expiresAt"] = Timestamp(date: expiresAt) }
        try await inviteRef.setData(data)
        return FamilyInvite(
            id: inviteRef.documentID,
            familyId: familyId,
            code: code,
            role: role,
            createdBy: createdBy,
            createdAt: Date(),
            expiresAt: expiresAt,
            maxUses: maxUses,
            usedCount: 0,
            revoked: false
        )
    }

    func joinFamily(withInviteCode code: String, user profile: UserProfile) async throws -> (family: Family, role: UserRole) {
        // Query the invites collection group by code
        let inviteQuery = try await db.collectionGroup(Collection.invites)
            .whereField("code", isEqualTo: code.uppercased())
            .limit(to: 1)
            .getDocuments()
        guard let inviteDoc = inviteQuery.documents.first else {
            throw NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invite code not found."])
        }
        let inviteData = inviteDoc.data()
        let roleRaw = inviteData["role"] as? String
        let role = roleRaw.flatMap(UserRole.init(rawValue:)) ?? .kid
        let revoked = inviteData["revoked"] as? Bool ?? false
        let usedCount = inviteData["usedCount"] as? Int ?? 0
        let maxUses = inviteData["maxUses"] as? Int
        let expiresAt = (inviteData["expiresAt"] as? Timestamp)?.dateValue()
        if revoked { throw NSError(domain: "FirestoreService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invite revoked."]) }
        if let expiresAt, expiresAt < Date() {
            // Delete expired invite proactively
            try? await inviteDoc.reference.delete()
            throw NSError(domain: "FirestoreService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invite expired."])
        }
        if let maxUses, usedCount >= maxUses {
            throw NSError(domain: "FirestoreService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invite already used."])
        }
        guard let familyRef = inviteDoc.reference.parent.parent else {
            throw NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family not found for invite."])
        }
        let familySnap = try await familyRef.getDocument()
        guard let familyData = familySnap.data() else {
            throw NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family not found."])
        }
        let family = try decodeFamily(id: familyRef.documentID, data: familyData)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ (txn, errorPointer) -> Any? in
                // Read the invite document fresh inside the transaction
                let freshInvite: DocumentSnapshot
                do {
                    freshInvite = try txn.getDocument(inviteDoc.reference)
                } catch let err as NSError {
                    errorPointer?.pointee = err
                    return nil
                }
                let freshData = freshInvite.data() ?? [:]
                let freshUsed = freshData["usedCount"] as? Int ?? 0
                let freshMax = freshData["maxUses"] as? Int
                let freshRevoked = freshData["revoked"] as? Bool ?? false

                if freshRevoked {
                    errorPointer?.pointee = NSError(domain: "FirestoreService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invite revoked."])
                    return nil
                }
                if let freshMax, freshUsed >= freshMax {
                    errorPointer?.pointee = NSError(domain: "FirestoreService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invite already used."])
                    return nil
                }

                // Prepare references
                let memberRef = familyRef.collection(Collection.members).document(profile.id)
                let isKid = (role == .kid)

                // IMPORTANT: If the role is kid, read the kid document BEFORE any writes
                var kidSnap: DocumentSnapshot? = nil
                var kidRef: DocumentReference? = nil
                if isKid {
                    kidRef = familyRef.collection(Collection.kids).document(profile.id)
                    do {
                        kidSnap = try txn.getDocument(kidRef!)
                    } catch let err as NSError {
                        errorPointer?.pointee = err
                        return nil
                    }
                }

                // Now perform writes (all reads are completed above)
                txn.setData([
                    "role": role.rawValue,
                    "joinedAt": FieldValue.serverTimestamp()
                ], forDocument: memberRef, merge: true)

                txn.updateData(["usedCount": freshUsed + 1], forDocument: inviteDoc.reference)

                if isKid, let kidRef = kidRef {
                    if let kidSnap, !kidSnap.exists {
                        txn.setData([
                            "name": profile.displayName,
                            "colorHex": Kid.defaultColorHex,
                            "coins": 0,
                            "userId": profile.id,
                            "createdAt": FieldValue.serverTimestamp(),
                            "updatedAt": FieldValue.serverTimestamp()
                        ], forDocument: kidRef, merge: false)
                    } else {
                        // Keep the kid's name in sync with the profile's display name
                        txn.setData([
                            "name": profile.displayName,
                            "updatedAt": FieldValue.serverTimestamp()
                        ], forDocument: kidRef, merge: true)
                    }
                }

                return nil
            }, completion: { (_, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }

        return (family, role)
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

    func fetchLatestInvite(familyId: String, role: UserRole) async throws -> FamilyInvite? {
        let invitesRef = db.collection(Collection.families).document(familyId).collection(Collection.invites)
        // Query latest by createdAt desc and filter for role/revoked in client to avoid index issues
        let snap = try await invitesRef.order(by: "createdAt", descending: true).limit(to: 10).getDocuments()
        let now = Date()
        for doc in snap.documents {
            let data = doc.data()
            let roleRaw = data["role"] as? String
            let revoked = data["revoked"] as? Bool ?? false
            let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue()
            guard roleRaw == role.rawValue, !revoked else { continue }
            if let expiresAt, expiresAt < now { continue }
            // Build FamilyInvite from snapshot
            let code = data["code"] as? String ?? ""
            let createdBy = data["createdBy"] as? String ?? ""
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            let maxUses = data["maxUses"] as? Int
            let usedCount = data["usedCount"] as? Int ?? 0
            let invite = FamilyInvite(
                id: doc.documentID,
                familyId: familyId,
                code: code,
                role: role,
                createdBy: createdBy,
                createdAt: createdAt,
                expiresAt: expiresAt,
                maxUses: maxUses,
                usedCount: usedCount,
                revoked: revoked
            )
            return invite
        }
        return nil
    }

    func fetchUserRoleInFamily(familyId: String, userId: String) async throws -> UserRole? {
        let familyRef = db.collection(Collection.families).document(familyId)
        let memberDoc = try await familyRef.collection(Collection.members).document(userId).getDocument()
        guard let data = memberDoc.data(), let roleRaw = data["role"] as? String else { return nil }
        return UserRole(rawValue: roleRaw)
    }

    func leaveFamilyAndDeleteIfLastParent(user profile: UserProfile) async throws {
        guard let familyId = profile.familyId else { return }
        let familyRef = db.collection(Collection.families).document(familyId)
        let membersRef = familyRef.collection(Collection.members)

        // Determine the leaving user's role (prefer profile.role, fallback to member doc)
        var leavingRole: UserRole? = profile.role
        if leavingRole == nil {
            let memberDoc = try await membersRef.document(profile.id).getDocument()
            if let data = memberDoc.data(), let roleRaw = data["role"] as? String {
                leavingRole = UserRole(rawValue: roleRaw)
            }
        }

        // Count current parents
        let parentsSnap = try await membersRef
            .whereField("role", isEqualTo: UserRole.parent.rawValue)
            .getDocuments()
        let parentCount = parentsSnap.documents.count

        // If a kid leaves, remove only their membership and kid document
        if leavingRole == .kid {
            // Remove membership
            try await membersRef.document(profile.id).delete()
            // Remove kid document if it exists (kids created via join use userId as doc id)
            try? await familyRef.collection(Collection.kids).document(profile.id).delete()
            return
        }

        // If a parent leaves and they are the last parent, delete the entire family
        if leavingRole == .parent && parentCount <= 1 {
            try await deleteCollection(membersRef)
            try await deleteCollection(familyRef.collection(Collection.kids))
            try await deleteCollection(familyRef.collection(Collection.chores))
            try await deleteCollection(familyRef.collection(Collection.rewards))
            try await deleteCollection(familyRef.collection(Collection.invites))
            try await familyRef.delete()
        } else {
            // Otherwise, remove only this member
            try await membersRef.document(profile.id).delete()
        }
    }

    func updateFamilyName(familyId: String, name: String) async throws {
        try await db.collection(Collection.families).document(familyId).setData([
            "name": name,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func saveKids(_ kids: [Kid], familyId: String) async throws {
        let familyRef = db.collection(Collection.families).document(familyId)
        let kidsRef = familyRef.collection(Collection.kids)
        let existingDocs = try await kidsRef.getDocuments().documents
        let existingIds = Set(existingDocs.map { $0.documentID })
        let newIds = Set(kids.map { $0.id })
        let toDelete = existingIds.subtracting(newIds)

        let batch = db.batch()
        // Delete removed kids
        for id in toDelete {
            batch.deleteDocument(kidsRef.document(id))
        }
        // Upsert current kids
        for kid in kids {
            let ref = kidsRef.document(kid.id)
            let data: [String: Any] = [
                "name": kid.name,
                "colorHex": kid.colorHex,
                "coins": kid.coins,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            batch.setData(data, forDocument: ref, merge: true)
        }
        try await batch.commit()
    }

    func saveChores(_ chores: [Chore], familyId: String) async throws {
        let familyRef = db.collection(Collection.families).document(familyId)
        let choresRef = familyRef.collection(Collection.chores)
        let existingDocs = try await choresRef.getDocuments().documents
        let existingIds = Set(existingDocs.map { $0.documentID })
        let newIds = Set(chores.map { $0.id.uuidString })
        let toDelete = existingIds.subtracting(newIds)

        let batch = db.batch()
        for id in toDelete {
            batch.deleteDocument(choresRef.document(id))
        }
        for chore in chores {
            let ref = choresRef.document(chore.id.uuidString)
            let data: [String: Any] = [
                "name": chore.name,
                "assignedTo": chore.assignedTo,
                "dueDate": Timestamp(date: chore.dueDate),
                "rewardCoins": chore.rewardCoins,
                "punishmentCoins": chore.punishmentCoins,
                "frequency": chore.frequency.rawValue,
                "icon": chore.icon,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            batch.setData(data, forDocument: ref, merge: true)
        }
        try await batch.commit()
    }

    func saveRewards(_ rewards: [Reward], familyId: String) async throws {
        let familyRef = db.collection(Collection.families).document(familyId)
        let rewardsRef = familyRef.collection(Collection.rewards)
        let existingDocs = try await rewardsRef.getDocuments().documents
        let existingIds = Set(existingDocs.map { $0.documentID })
        let newIds = Set(rewards.map { $0.id.uuidString })
        let toDelete = existingIds.subtracting(newIds)

        let batch = db.batch()
        for id in toDelete {
            batch.deleteDocument(rewardsRef.document(id))
        }
        for reward in rewards {
            let ref = rewardsRef.document(reward.id.uuidString)
            let data: [String: Any] = [
                "name": reward.name,
                "cost": reward.cost,
                "details": reward.details,
                "icon": reward.icon,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            batch.setData(data, forDocument: ref, merge: true)
        }
        try await batch.commit()
    }

    func addChoreSubmission(_ submission: ChoreSubmission, familyId: String) async throws {
        let familyRef = db.collection(Collection.families).document(familyId)
        let ref = familyRef.collection(Collection.submissions).document(submission.id.uuidString)
        let data: [String: Any] = [
            "choreId": submission.choreId.uuidString,
            "choreName": submission.choreName,
            "kidName": submission.kidName,
            "photoURL": submission.photoURL,
            "submittedAt": Timestamp(date: submission.submittedAt),
            "rewardCoins": submission.rewardCoins,
            "status": submission.status.rawValue,
            "reviewedAt": submission.reviewedAt.map { Timestamp(date: $0) } as Any,
            "reviewer": submission.reviewer as Any,
            "rejectionReason": submission.rejectionReason as Any
        ].compactMapValues { $0 }
        try await ref.setData(data, merge: true)
    }

    func addHistoryEntry(_ entry: HistoryEntry, familyId: String) async throws {
        let familyRef = db.collection(Collection.families).document(familyId)
        let ref = familyRef.collection(Collection.history).document(entry.id.uuidString)
        let data: [String: Any] = [
            "type": entry.type.rawValue,
            "kidName": entry.kidName,
            "title": entry.title,
            "details": entry.details,
            "amount": entry.amount,
            "timestamp": Timestamp(date: entry.timestamp),
            "submissionId": entry.submissionId?.uuidString as Any,
            "photoURL": entry.photoURL as Any
        ].compactMapValues { $0 }
        try await ref.setData(data, merge: true)
    }

    func fetchHistory(familyId: String) async throws -> [HistoryEntry] {
        let familyRef = db.collection(Collection.families).document(familyId)
        let snap = try await familyRef.collection(Collection.history).order(by: "timestamp", descending: true).getDocuments()
        return snap.documents.compactMap { doc in
            let data = doc.data()
            guard let typeRaw = data["type"] as? String,
                  let type = HistoryType(rawValue: typeRaw) else { return nil }
            let kidName = data["kidName"] as? String ?? ""
            let title = data["title"] as? String ?? ""
            let details = data["details"] as? String ?? ""
            let amount = data["amount"] as? Int ?? 0
            let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            return HistoryEntry(
                id: UUID(uuidString: doc.documentID) ?? UUID(),
                type: type,
                kidName: kidName,
                title: title,
                details: details,
                amount: amount,
                timestamp: ts,
                submissionId: (data["submissionId"] as? String).flatMap(UUID.init(uuidString:)),
                photoURL: data["photoURL"] as? String
            )
        }
    }

    func fetchSubmissions(familyId: String) async throws -> [ChoreSubmission] {
        let familyRef = db.collection(Collection.families).document(familyId)
        let snap = try await familyRef.collection(Collection.submissions).order(by: "submittedAt", descending: true).getDocuments()
        return snap.documents.compactMap { doc in
            let data = doc.data()
            let choreId = UUID(uuidString: data["choreId"] as? String ?? "") ?? UUID()
            let choreName = data["choreName"] as? String ?? ""
            let kidName = data["kidName"] as? String ?? ""
            let photoURL = data["photoURL"] as? String ?? ""
            let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue() ?? Date()
            let rewardCoins = data["rewardCoins"] as? Int ?? 0
            let statusRaw = data["status"] as? String ?? SubmissionStatus.pending.rawValue
            let status = SubmissionStatus(rawValue: statusRaw) ?? .pending
            let reviewedAt = (data["reviewedAt"] as? Timestamp)?.dateValue()
            let reviewer = data["reviewer"] as? String
            let rejectionReason = data["rejectionReason"] as? String
            return ChoreSubmission(
                id: UUID(uuidString: doc.documentID) ?? UUID(),
                choreId: choreId,
                choreName: choreName,
                kidName: kidName,
                photoURL: photoURL,
                submittedAt: submittedAt,
                rewardCoins: rewardCoins,
                status: status,
                reviewedAt: reviewedAt,
                reviewer: reviewer,
                rejectionReason: rejectionReason
            )
        }
    }

    func updateSubmissionStatus(familyId: String, submissionId: UUID, status: SubmissionStatus, reviewer: String?, rejectionReason: String?) async throws {
        let familyRef = db.collection(Collection.families).document(familyId)
        let ref = familyRef.collection(Collection.submissions).document(submissionId.uuidString)
        var data: [String: Any] = [
            "status": status.rawValue,
            "reviewedAt": FieldValue.serverTimestamp()
        ]
        if let reviewer { data["reviewer"] = reviewer }
        if let rejectionReason { data["rejectionReason"] = rejectionReason }
        try await ref.setData(data, merge: true)
    }

    func updateKidCoins(kidName: String, delta: Int, familyId: String) async throws {
        let familyRef = db.collection(Collection.families).document(familyId)
        let kidsRef = familyRef.collection(Collection.kids)
        // Fetch kids and update first match by name
        let snap = try await kidsRef.whereField("name", isEqualTo: kidName).limit(to: 1).getDocuments()
        if let doc = snap.documents.first {
            let currentCoins = doc.data()["coins"] as? Int ?? 0
            try await kidsRef.document(doc.documentID).setData([
                "coins": currentCoins + delta,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }
}

private extension FirebaseFirestoreService {
    func deleteCollection(_ collection: CollectionReference, batchSize: Int = 50) async throws {
        let docs = try await collection.limit(to: batchSize).getDocuments().documents
        if docs.isEmpty { return }
        let batch = db.batch()
        for doc in docs {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        if docs.count >= batchSize {
            // Continue deleting if more documents remain
            try await deleteCollection(collection, batchSize: batchSize)
        }
    }

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

    func generateInviteCode(length: Int = 6) -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).compactMap { _ in characters.randomElement() })
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
    private var storedInvitesByCode: [String: FamilyInvite] = [:]
    private var storedMembersByFamily: [String: [String: UserRole]] = [:]

    private var storedSubmissionsByFamily: [String: [ChoreSubmission]] = [:]
    private var storedHistoryByFamily: [String: [HistoryEntry]] = [:]

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
        storedMembersByFamily[id] = [profile.id: .parent]
        return family
    }

    func createInvite(familyId: String, role: UserRole, maxUses: Int?, expiresAt: Date?) async throws -> FamilyInvite {
        guard storedFamilies[familyId] != nil else {
            throw NSError(domain: "MockFirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family not found."])
        }
        // Purge expired invites for this family
        let now = Date()
        for (codeKey, invite) in storedInvitesByCode where invite.familyId == familyId {
            if let exp = invite.expiresAt, exp < now {
                storedInvitesByCode.removeValue(forKey: codeKey)
            }
        }
        // Enforce a maximum of 4 invites per family by deleting the oldest if needed
        let invitesForFamily = storedInvitesByCode.values.filter { $0.familyId == familyId }
        if invitesForFamily.count >= 4 {
            if let oldest = invitesForFamily.sorted(by: { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }).first {
                // Remove the oldest from the dictionary
                if let keyToRemove = storedInvitesByCode.first(where: { $0.value.id == oldest.id })?.key {
                    storedInvitesByCode.removeValue(forKey: keyToRemove)
                }
            }
        }
        let id = UUID().uuidString
        let code = generateInviteCode(length: 8)
        let invite = FamilyInvite(
            id: id,
            familyId: familyId,
            code: code,
            role: role,
            createdBy: "mock",
            createdAt: Date(),
            expiresAt: expiresAt,
            maxUses: maxUses,
            usedCount: 0,
            revoked: false
        )
        storedInvitesByCode[code] = invite
        return invite
    }

    func joinFamily(withInviteCode code: String, user profile: UserProfile) async throws -> (family: Family, role: UserRole) {
        guard var invite = storedInvitesByCode[code.uppercased()] else {
            throw NSError(domain: "MockFirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invite code not found."])
        }
        if invite.revoked { throw NSError(domain: "MockFirestoreService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invite revoked."]) }
        if let exp = invite.expiresAt, exp < Date() {
            // Delete expired invite proactively
            storedInvitesByCode.removeValue(forKey: invite.code)
            throw NSError(domain: "MockFirestoreService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invite expired."])
        }
        if let max = invite.maxUses, invite.usedCount >= max { throw NSError(domain: "MockFirestoreService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invite already used."]) }
        guard let family = storedFamilies[invite.familyId] else {
            throw NSError(domain: "MockFirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family not found."])
        }
        invite.usedCount += 1
        storedInvitesByCode[invite.code] = invite

        var members = storedMembersByFamily[family.id] ?? [:]
        members[profile.id] = invite.role
        storedMembersByFamily[family.id] = members

        return (family, invite.role)
    }

    func leaveFamilyAndDeleteIfLastParent(user profile: UserProfile) async throws {
        guard let familyId = profile.familyId else { return }
        var members = storedMembersByFamily[familyId] ?? [:]
        let parentCount = members.values.filter { $0 == .parent }.count
        let leavingRole = members[profile.id] ?? profile.role

        // If a kid leaves, remove only their membership and any kid entry in the snapshot
        if leavingRole == .kid {
            members.removeValue(forKey: profile.id)
            storedMembersByFamily[familyId] = members
            if var snapshot = storedFamilyData[familyId] {
                snapshot.kids.removeAll { $0.id == profile.id }
                storedFamilyData[familyId] = snapshot
            }
            return
        }

        // If a parent leaves and they are the last parent, delete the entire family
        if leavingRole == .parent && parentCount <= 1 {
            storedFamilies.removeValue(forKey: familyId)
            storedFamilyData.removeValue(forKey: familyId)
            storedMembersByFamily.removeValue(forKey: familyId)
            // Remove invites for that family
            storedInvitesByCode = storedInvitesByCode.filter { $0.value.familyId != familyId }
        } else {
            // Otherwise, remove only this member
            members.removeValue(forKey: profile.id)
            storedMembersByFamily[familyId] = members
        }
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

    func fetchLatestInvite(familyId: String, role: UserRole) async throws -> FamilyInvite? {
        let now = Date()
        let candidates = storedInvitesByCode.values
            .filter { $0.familyId == familyId && $0.role == role && !$0.revoked }
            .filter { invite in
                if let exp = invite.expiresAt { return exp >= now } else { return true }
            }
            .sorted { (a, b) in
                (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
            }
        return candidates.first
    }

    func fetchUserRoleInFamily(familyId: String, userId: String) async throws -> UserRole? {
        return storedMembersByFamily[familyId]?[userId]
    }

    func updateFamilyName(familyId: String, name: String) async throws {
        if var family = storedFamilies[familyId] {
            family.name = name
            storedFamilies[familyId] = family
            if var snapshot = storedFamilyData[familyId] {
                snapshot.family = family
                storedFamilyData[familyId] = snapshot
            }
        } else {
            throw NSError(domain: "MockFirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Family not found."])
        }
    }

    func saveKids(_ kids: [Kid], familyId: String) async throws {
        if var snapshot = storedFamilyData[familyId] {
            snapshot.kids = kids
            storedFamilyData[familyId] = snapshot
        } else if let family = storedFamilies[familyId] {
            storedFamilyData[familyId] = FamilyDataSnapshot(family: family, kids: kids, chores: [], rewards: [])
        }
    }

    func saveChores(_ chores: [Chore], familyId: String) async throws {
        if var snapshot = storedFamilyData[familyId] {
            snapshot.chores = chores
            storedFamilyData[familyId] = snapshot
        } else if let family = storedFamilies[familyId] {
            storedFamilyData[familyId] = FamilyDataSnapshot(family: family, kids: [], chores: chores, rewards: [])
        }
    }

    func saveRewards(_ rewards: [Reward], familyId: String) async throws {
        if var snapshot = storedFamilyData[familyId] {
            snapshot.rewards = rewards
            storedFamilyData[familyId] = snapshot
        } else if let family = storedFamilies[familyId] {
            storedFamilyData[familyId] = FamilyDataSnapshot(family: family, kids: [], chores: [], rewards: rewards)
        }
    }

    func addChoreSubmission(_ submission: ChoreSubmission, familyId: String) async throws {
        var list = storedSubmissionsByFamily[familyId] ?? []
        list.append(submission)
        storedSubmissionsByFamily[familyId] = list
    }

    func addHistoryEntry(_ entry: HistoryEntry, familyId: String) async throws {
        var list = storedHistoryByFamily[familyId] ?? []
        list.append(entry)
        storedHistoryByFamily[familyId] = list
    }

    func fetchHistory(familyId: String) async throws -> [HistoryEntry] {
        return (storedHistoryByFamily[familyId] ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    func fetchSubmissions(familyId: String) async throws -> [ChoreSubmission] {
        return (storedSubmissionsByFamily[familyId] ?? []).sorted { $0.submittedAt > $1.submittedAt }
    }

    func updateSubmissionStatus(familyId: String, submissionId: UUID, status: SubmissionStatus, reviewer: String?, rejectionReason: String?) async throws {
        var list = storedSubmissionsByFamily[familyId] ?? []
        if let idx = list.firstIndex(where: { $0.id == submissionId }) {
            var item = list[idx]
            item.status = status
            item.reviewedAt = Date()
            item.reviewer = reviewer
            item.rejectionReason = rejectionReason
            list[idx] = item
            storedSubmissionsByFamily[familyId] = list
        }
    }

    func updateKidCoins(kidName: String, delta: Int, familyId: String) async throws {
        guard var snapshot = storedFamilyData[familyId] else { return }
        if let idx = snapshot.kids.firstIndex(where: { $0.name == kidName }) {
            var kid = snapshot.kids[idx]
            kid.coins += delta
            snapshot.kids[idx] = kid
            storedFamilyData[familyId] = snapshot
        }
    }

    private func generateInviteCode(length: Int = 6) -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}
