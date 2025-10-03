import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AppSessionViewModel: ObservableObject {
    enum FlowState: Equatable {
        case loading
        case unauthenticated
        case profileSetup(AuthenticatedUser)
        case choosingRole(UserProfile)
        case parent(UserProfile)
        case kid(UserProfile)
    }

    @Published private(set) var state: FlowState = .loading
    @Published private(set) var isProcessing = false
    @Published private(set) var profile: UserProfile?
    @Published private(set) var currentFamily: Family?
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var deepLink: DeepLink?
    @Published var recentNotification: String?

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let storageService: StorageService
    private let familyViewModel: FamilyViewModel
    private let choresViewModel: ChoresViewModel
    private let rewardsViewModel: RewardsViewModel

    private var cancellables = Set<AnyCancellable>()
    private var isSyncSuspended = false
    private var isProcessingOverdue = false

    convenience init(
        familyViewModel: FamilyViewModel,
        choresViewModel: ChoresViewModel,
        rewardsViewModel: RewardsViewModel
    ) {
        self.init(
            authService: AuthServiceFactory.make(),
            firestoreService: FirestoreServiceFactory.make(),
            storageService: StorageServiceFactory.make(),
            familyViewModel: familyViewModel,
            choresViewModel: choresViewModel,
            rewardsViewModel: rewardsViewModel
        )
    }

    init(
        authService: AuthService,
        firestoreService: FirestoreService,
        storageService: StorageService,
        familyViewModel: FamilyViewModel,
        choresViewModel: ChoresViewModel,
        rewardsViewModel: RewardsViewModel
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.storageService = storageService
        self.familyViewModel = familyViewModel
        self.choresViewModel = choresViewModel
        self.rewardsViewModel = rewardsViewModel
        Task { await bootstrap() }
        setUpSync()
    }

    func bootstrap() async {
        state = .loading
        clearFamilyData()
        if let user = authService.currentUser {
            await loadSession(for: user)
        } else {
            state = .unauthenticated
        }
    }

    func signInWithApple() {
        Task {
            await authenticate(using: { try await self.authService.signInWithApple() })
        }
    }

    func signInWithGoogle() {
        Task {
            #if canImport(UIKit)
            let controller = Self.presentingController()
            #else
            let controller: UIViewController? = nil
            #endif
            await authenticate(using: { try await self.authService.signInWithGoogle(presentingController: controller) })
        }
    }

    func completeProfileSetup(displayName: String) {
        guard case let .profileSetup(user) = state else { return }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            await setProcessing(true)
            do {
                let profile = UserProfile(id: user.id, displayName: trimmed)
                try await firestoreService.saveUserProfile(profile)
                self.profile = profile
                state = .choosingRole(profile)
            } catch {
                handle(error)
            }
            await setProcessing(false)
        }
    }

    func createFamily(named name: String) {
        guard let profile else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            await setProcessing(true)
            do {
                let family = try await firestoreService.createFamily(named: trimmed, owner: profile)
                var updatedProfile = profile
                updatedProfile.familyId = family.id
                updatedProfile.role = .parent
                try await firestoreService.saveUserProfile(updatedProfile)
                self.profile = updatedProfile
                await loadFamilyData(familyId: family.id)
                state = .parent(updatedProfile)
            } catch {
                handle(error)
            }
            await setProcessing(false)
        }
    }

    func joinFamily(withCode code: String) {
        guard let profile else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            await setProcessing(true)
            do {
                let result = try await firestoreService.joinFamily(withInviteCode: trimmed, user: profile)
                var updatedProfile = profile
                updatedProfile.familyId = result.family.id
                updatedProfile.role = result.role
                try await firestoreService.saveUserProfile(updatedProfile)
                self.profile = updatedProfile
                await loadFamilyData(familyId: result.family.id)
                switch result.role {
                case .parent:
                    state = .parent(updatedProfile)
                case .kid:
                    state = .kid(updatedProfile)
                }
            } catch {
                handle(error)
            }
            await setProcessing(false)
        }
    }

    func loadFamilyIfNeeded() {
        guard let profile, let familyId = profile.familyId else { return }
        Task { await loadFamilyData(familyId: familyId) }
    }

    func signOut() {
        do {
            try authService.signOut()
            clearFamilyData()
            profile = nil
            currentFamily = nil
            state = .unauthenticated
        } catch {
            handle(error)
        }
    }

    var userEmail: String? {
        authService.currentUser?.email
    }

    func updateDisplayName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var profile = self.profile else { return }
        Task {
            await setProcessing(true)
            do {
                profile.displayName = trimmed
                try await firestoreService.saveUserProfile(profile)
                await MainActor.run { self.profile = profile }
            } catch {
                handle(error)
            }
            await setProcessing(false)
        }
    }

    func updateFamilyName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let profile = self.profile, profile.role == .parent, let familyId = profile.familyId else { return }
        Task {
            await setProcessing(true)
            do {
                try await firestoreService.updateFamilyName(familyId: familyId, name: trimmed)
                await MainActor.run {
                    if var family = self.currentFamily {
                        family.name = trimmed
                        self.currentFamily = family
                    }
                }
            } catch {
                handle(error)
            }
            await setProcessing(false)
        }
    }

    func submitChoreEvidence(chore: Chore, photoData: Data) async {
        guard let profile = self.profile, let familyId = profile.familyId else { return }
        await setProcessing(true)
        do {
            let submissionId = UUID()
            let fileName = "evidence-\(submissionId.uuidString).jpg"
            let storagePath = "families/\(familyId)/submissions/\(submissionId.uuidString)/\(fileName)"
            let downloadURL = try await storageService.upload(data: photoData, to: storagePath, contentType: "image/jpeg")

            let submission = Submission(
                id: submissionId,
                type: .chore,
                kidUid: profile.id,
                kidName: profile.displayName,
                choreId: chore.id,
                choreName: chore.name,
                rewardCoins: chore.rewardCoins,
                storagePath: storagePath,
                photoURL: downloadURL.absoluteString
            )
            try await firestoreService.createSubmission(submission, familyId: familyId)

            await MainActor.run {
                self.infoMessage = "Submitted \(chore.name) for approval"
            }
        } catch {
            handle(error)
        }
        await setProcessing(false)
    }

    func fetchHistory() async -> [HistoryEntry] {
        guard let familyId = self.profile?.familyId else { return [] }
        do { return try await firestoreService.fetchHistory(familyId: familyId) } catch { handle(error); return [] }
    }

    func redeemReward(_ reward: Reward, forKidNamed kidName: String, kidUid: String? = nil) async {
        guard let profile = self.profile, let familyId = profile.familyId else { return }
        guard let resolvedKidUid = kidUid ?? (profile.role == .kid ? profile.id : nil) else {
            await MainActor.run {
                self.errorMessage = "Unable to identify the kid account for this reward redemption."
            }
            return
        }
        await setProcessing(true)
        do {
            let submission = Submission(
                type: .reward,
                kidUid: resolvedKidUid,
                kidName: kidName,
                rewardId: reward.id,
                rewardName: reward.name,
                rewardCost: reward.cost
            )

            try await firestoreService.createSubmission(submission, familyId: familyId)

            await MainActor.run {
                self.infoMessage = "Requested \(reward.name) – waiting for parent approval"
            }
        } catch {
            handle(error)
        }
        await setProcessing(false)
    }

    func redeemRewardAsCurrentKid(_ reward: Reward) async {
        guard let profile = self.profile else { return }
        await redeemReward(reward, forKidNamed: profile.displayName, kidUid: profile.id)
    }

    func reverseHistoryEntry(_ entry: HistoryEntry) async -> Bool {
        guard let profile = self.profile, let familyId = profile.familyId else { return false }
        await setProcessing(true)
        let delta = -entry.amount
        var success = false
        do {
            try await firestoreService.reverseHistoryEntry(
                familyId: familyId,
                entryId: entry.id,
                kidId: entry.kidId,
                kidName: entry.kidName,
                delta: delta,
                reversedByUid: profile.id,
                reversedByName: profile.displayName
            )
            success = true
            await MainActor.run {
                if delta > 0 {
                    self.infoMessage = "Returned \(delta) stars to \(entry.kidName)"
                } else if delta < 0 {
                    self.infoMessage = "Removed \(abs(delta)) stars from \(entry.kidName)"
                } else {
                    self.infoMessage = "Reversed entry for \(entry.kidName)"
                }
            }
        } catch {
            handle(error)
        }
        await setProcessing(false)
        return success
    }

    func leaveCurrentFamily() {
        guard var profile = self.profile, profile.familyId != nil else { return }
        Task {
            await setProcessing(true)
            do {
                try await firestoreService.leaveFamilyAndDeleteIfLastParent(user: profile)
                // Clear local state and update profile
                profile.familyId = nil
                profile.role = nil
                try await firestoreService.saveUserProfile(profile)
                await MainActor.run {
                    self.profile = profile
                    self.currentFamily = nil
                    self.clearFamilyData()
                    self.state = .choosingRole(profile)
                }
            } catch {
                handle(error)
            }
            await setProcessing(false)
        }
    }

    // New methods for managing chore submissions

    func fetchSubmissions() async -> [Submission] {
        guard let familyId = self.profile?.familyId else { return [] }
        do { return try await firestoreService.fetchSubmissions(familyId: familyId) } catch { handle(error); return [] }
    }

    func approveSubmission(_ sub: Submission) async {
        guard let familyId = self.profile?.familyId else { return }
        await setProcessing(true)
        do {
            try await firestoreService.updateSubmissionStatus(familyId: familyId, submissionId: sub.id, status: .approved, reviewer: profile?.displayName, rejectionReason: nil)
            handleApprovedChoreSubmission(sub)
        } catch {
            handle(error)
        }
        await setProcessing(false)
    }

    func rejectSubmission(_ sub: Submission, reason: String? = "Not sufficient evidence") async {
        guard let familyId = self.profile?.familyId else { return }
        await setProcessing(true)
        do {
            try await firestoreService.updateSubmissionStatus(familyId: familyId, submissionId: sub.id, status: .rejected, reviewer: profile?.displayName, rejectionReason: reason)
            if let path = sub.storagePath, !path.isEmpty {
                do {
                    try await storageService.delete(path: path)
                } catch {
                    handle(error)
                }
            }
        } catch {
            handle(error)
        }
        await setProcessing(false)
    }
    
    func cancelPendingReward(_ submission: Submission) async {
        guard let familyId = self.profile?.familyId, let uid = self.profile?.id else { return }
        guard submission.type == .reward, submission.status == .pending, submission.kidUid == uid else { return }
        await setProcessing(true)
        do {
            try await firestoreService.cancelPendingSubmission(familyId: familyId, submissionId: submission.id, requesterUid: uid)
            await MainActor.run { self.infoMessage = "Cancelled reward request" }
        } catch { handle(error) }
        await setProcessing(false)
    }
    
    var allChoresPaused: Bool {
        let list = choresViewModel.chores
        return !list.isEmpty && list.allSatisfy { $0.paused }
    }

    func setAllChoresPaused(_ paused: Bool) {
        guard profile?.role == .parent else { return }
        var updated = choresViewModel.chores
        for i in updated.indices { updated[i].paused = paused }
        choresViewModel.replace(chores: updated)
    }
}

private extension AppSessionViewModel {
    func setUpSync() {
        // Kids sync
        familyViewModel.$kids
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] kids in
                guard let self else { return }
                guard !self.isSyncSuspended else { return }
                guard let profile = self.profile, profile.role == .parent, let familyId = profile.familyId else { return }
                Task { [kids] in
                    do { try await self.firestoreService.saveKids(kids, familyId: familyId) } catch { self.handle(error) }
                }
            }
            .store(in: &cancellables)

        // Chores sync
        choresViewModel.$chores
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] chores in
                guard let self else { return }
                guard !self.isSyncSuspended else { return }
                guard let profile = self.profile, profile.role == .parent, let familyId = profile.familyId else { return }
                Task { [chores] in
                    do { try await self.firestoreService.saveChores(chores, familyId: familyId) } catch { self.handle(error) }
                }
            }
            .store(in: &cancellables)

        // Rewards sync
        rewardsViewModel.$rewards
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] rewards in
                guard let self else { return }
                guard !self.isSyncSuspended else { return }
                guard let profile = self.profile, profile.role == .parent, let familyId = profile.familyId else { return }
                Task { [rewards] in
                    do { try await self.firestoreService.saveRewards(rewards, familyId: familyId) } catch { self.handle(error) }
                }
            }
            .store(in: &cancellables)

        // Lightweight polling for new submissions to surface in-app notifications (parents only)
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard let profile = self.profile, profile.role == .parent, let familyId = profile.familyId else { return }
                Task {
                    do {
                        let submissions = try await self.firestoreService.fetchSubmissions(familyId: familyId)
                        if let latest = submissions.first, latest.createdAt > Date().addingTimeInterval(-35) {
                            await MainActor.run {
                                self.recentNotification = "New submission from \(latest.kidName): \(latest.displayTitle)"
                                if let urlString = latest.photoURL, let url = URL(string: urlString) {
                                    self.deepLink = .submissionPhoto(submissionId: latest.id, photoURL: url)
                                }
                            }
                        }
                    } catch { /* ignore polling errors */ }
                }
            }
            .store(in: &cancellables)
    }

    func authenticate(using operation: @escaping () async throws -> AuthenticatedUser) async {
        await setProcessing(true)
        do {
            let user = try await operation()
            clearError()
            await loadSession(for: user)
        } catch {
            handle(error)
            state = .unauthenticated
        }
        await setProcessing(false)
    }

    func loadSession(for user: AuthenticatedUser) async {
        do {
            if let existingProfile = try await firestoreService.fetchUserProfile(uid: user.id) {
                if existingProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state = .profileSetup(user)
                    return
                }
                profile = existingProfile

                if let familyId = existingProfile.familyId {
                    // Verify membership still exists before proceeding
                    do {
                        let roleOnServer = try await firestoreService.fetchUserRoleInFamily(familyId: familyId, userId: existingProfile.id)
                        if roleOnServer == nil {
                            // Not a member anymore: clear local/server profile fields and route to setup
                            var fixedProfile = existingProfile
                            fixedProfile.familyId = nil
                            fixedProfile.role = nil
                            try await firestoreService.saveUserProfile(fixedProfile)
                            await MainActor.run {
                                self.profile = fixedProfile
                                self.clearFamilyData()
                                self.currentFamily = nil
                                self.state = .choosingRole(fixedProfile)
                            }
                            return
                        }
                    } catch {
                        // If we can't verify membership or load family, fall back to setup
                        var fixedProfile = existingProfile
                        fixedProfile.familyId = nil
                        fixedProfile.role = nil
                        try? await firestoreService.saveUserProfile(fixedProfile)
                        await MainActor.run {
                            self.profile = fixedProfile
                            self.clearFamilyData()
                            self.currentFamily = nil
                            self.state = .choosingRole(fixedProfile)
                        }
                        return
                    }

                    // Membership verified; proceed to load data
                    await loadFamilyData(familyId: familyId)

                    // If loading failed and no current family is set, route to setup defensively
                    if self.currentFamily == nil {
                        var fixedProfile = existingProfile
                        fixedProfile.familyId = nil
                        fixedProfile.role = nil
                        try? await firestoreService.saveUserProfile(fixedProfile)
                        await MainActor.run {
                            self.profile = fixedProfile
                            self.clearFamilyData()
                            self.state = .choosingRole(fixedProfile)
                        }
                        return
                    }

                    switch existingProfile.role {
                    case .parent:
                        state = .parent(existingProfile)
                    case .kid:
                        state = .kid(existingProfile)
                    case .none:
                        state = .choosingRole(existingProfile)
                    }
                } else {
                    clearFamilyData()
                    state = .choosingRole(existingProfile)
                }
            } else {
                state = .profileSetup(user)
            }
        } catch {
            handle(error)
            state = .unauthenticated
        }
    }

    func loadFamilyData(familyId: String) async {
        self.isSyncSuspended = true
        do {
            let snapshot = try await firestoreService.fetchFamilySnapshot(familyId: familyId)
            await MainActor.run {
                self.currentFamily = snapshot.family
                self.familyViewModel.replaceKids(snapshot.kids)
                self.choresViewModel.replace(chores: snapshot.chores)
                self.choresViewModel.replaceAvailableKids(with: snapshot.kids.map(\.name))
                self.rewardsViewModel.replace(rewards: snapshot.rewards)
                self.isSyncSuspended = false
                Task { await self.processOverdueChores() }
            }
        } catch {
            handle(error)
            await MainActor.run {
                self.currentFamily = nil
                self.clearFamilyData()
                // Keep sync suspended after a failed load to avoid pushing empty arrays and deleting server data.
                self.isSyncSuspended = true
            }
        }
    }

    func clearFamilyData() {
        isSyncSuspended = true
        familyViewModel.replaceKids([])
        choresViewModel.replace(chores: [])
        choresViewModel.replaceAvailableKids(with: [])
        rewardsViewModel.replace(rewards: [])
    }

    func handle(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    func clearError() {
        errorMessage = nil
    }

    func setProcessing(_ value: Bool) async {
        await MainActor.run { self.isProcessing = value }
    }

    private func handleApprovedChoreSubmission(_ submission: Submission) {
        guard submission.type == .chore, let choreId = submission.choreId else { return }
        guard let chore = choresViewModel.chores.first(where: { $0.id == choreId }) else { return }

        switch chore.frequency {
        case .once:
            choresViewModel.remove(chore)
        case .daily, .weekly, .monthly:
            var updated = chore
            updated.dueDate = nextDueDate(for: chore.frequency, from: chore.dueDate)
            choresViewModel.update(updated)
        }
    }

    private func nextDueDate(for frequency: Chore.Frequency, from current: Date) -> Date {
        guard frequency != .once else { return current }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var candidate = current

        repeat {
            let nextValue: Date?
            switch frequency {
            case .daily:
                nextValue = calendar.date(byAdding: .day, value: 1, to: candidate)
            case .weekly:
                nextValue = calendar.date(byAdding: .day, value: 7, to: candidate)
            case .monthly:
                nextValue = calendar.date(byAdding: .month, value: 1, to: candidate)
            case .once:
                nextValue = candidate
            }

            guard let advanced = nextValue, advanced != candidate else { return candidate }
            candidate = advanced
        } while calendar.startOfDay(for: candidate) <= today

        return candidate
    }

    func processOverdueChores() async {
        // Only parents should process overdue chores to avoid double-processing from kid devices.
        guard let profile = self.profile, profile.role == .parent, let familyId = profile.familyId else { return }
        if isProcessingOverdue { return }
        isProcessingOverdue = true
        defer { isProcessingOverdue = false }

        // Work with a snapshot to avoid mutating while iterating
        let chores = self.choresViewModel.chores
        let today = Calendar.current.startOfDay(for: Date())

        for chore in chores {
            if chore.paused { continue }
            // Consider overdue if due date is strictly before today (end of due day has passed)
            if Calendar.current.startOfDay(for: chore.dueDate) < today {
                // Apply penalty to each assigned kid and write history entries
                for kidName in chore.assignedTo {
                    let kidId = familyViewModel.kids.first(where: { $0.name == kidName })?.id
                    // Deduct punishment coins
                    do { try await self.firestoreService.updateKidCoins(kidId: kidId, kidName: kidName, delta: -chore.punishmentCoins, familyId: familyId) } catch { /* non-fatal */ }

                    // Add history entry for missed chore
                    let dueText = DateFormatter.localizedString(from: chore.dueDate, dateStyle: .medium, timeStyle: .none)
                   let entry = HistoryEntry(
                       type: .choreMissed,
                        kidName: kidName,
                        title: chore.name,
                        amount: -chore.punishmentCoins,
                        note: "Missed due on \(dueText)",
                        kidId: kidId
                    )
                    do { try await self.firestoreService.addHistoryEntry(entry, familyId: familyId) } catch { /* non-fatal */ }
                }

                // Reschedule or delete the chore
                switch chore.frequency {
                case .once:
                    await MainActor.run { self.choresViewModel.remove(chore) }
                case .daily, .weekly, .monthly:
                    var nextDate = chore.dueDate
                    let cal = Calendar.current
                    // Advance until not overdue anymore
                    while cal.startOfDay(for: nextDate) < today {
                        switch chore.frequency {
                        case .daily:
                            nextDate = cal.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
                        case .weekly:
                            nextDate = cal.date(byAdding: .day, value: 7, to: nextDate) ?? nextDate
                        case .monthly:
                            nextDate = cal.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
                        case .once:
                            break // handled above
                        }
                    }
                    var updated = chore
                    updated.dueDate = nextDate
                    await MainActor.run { self.choresViewModel.update(updated) }
                }
            }
        }
    }

    static func presentingController() -> UIViewController? {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?.topPresentedController()
        #else
        return nil
        #endif
    }
}

#if canImport(UIKit)
private extension UIViewController {
    func topPresentedController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topPresentedController()
        }
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topPresentedController() ?? navigation
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topPresentedController() ?? tab
        }
        return self
    }
}
#endif


#if DEBUG
extension AppSessionViewModel {
    static func previewParentSession(familyName: String = "Williams") -> AppSessionViewModel {
        let familyVM = FamilyViewModel()
        let choresVM = ChoresViewModel()
        let rewardsVM = RewardsViewModel()
        let user = AuthenticatedUser(id: "parent-preview", displayName: "Pat Parent", email: "parent@example.com")
        let auth = PreviewAuthService(currentUser: user)
        let session = AppSessionViewModel(
            authService: auth,
            firestoreService: MockFirestoreService.shared,
            storageService: MockStorageService(),
            familyViewModel: familyVM,
            choresViewModel: choresVM,
            rewardsViewModel: rewardsVM
        )
        let family = Family(id: "fam-preview", name: familyName, ownerId: user.id, inviteCode: "PREVIEW", createdAt: Date())
        let profile = UserProfile(id: user.id, displayName: user.displayName ?? "Parent", role: .parent, familyId: family.id, createdAt: Date())
        // Ensure our preview state wins over bootstrap's unauthenticated setup.
        Task { @MainActor in
            session.currentFamily = family
            session.profile = profile
            session.state = .parent(profile)
        }
        return session
    }

    static func previewKidSession(familyName: String = "Williams") -> AppSessionViewModel {
        let familyVM = FamilyViewModel()
        let choresVM = ChoresViewModel()
        let rewardsVM = RewardsViewModel()
        let user = AuthenticatedUser(id: "kid-preview", displayName: "Kenny Kid", email: "kid@example.com")
        let auth = PreviewAuthService(currentUser: user)
        let session = AppSessionViewModel(
            authService: auth,
            firestoreService: MockFirestoreService.shared,
            storageService: MockStorageService(),
            familyViewModel: familyVM,
            choresViewModel: choresVM,
            rewardsViewModel: rewardsVM
        )
        // For kid preview, reuse the same family id to mirror a shared family.
        let family = Family(id: "fam-preview", name: familyName, ownerId: "parent-preview", inviteCode: "PREVIEW", createdAt: Date())
        let profile = UserProfile(id: user.id, displayName: user.displayName ?? "Kid", role: .kid, familyId: family.id, createdAt: Date())
        Task { @MainActor in
            session.currentFamily = family
            session.profile = profile
            session.state = .kid(profile)
        }
        return session
    }
}

final class PreviewAuthService: AuthService {
    let currentUser: AuthenticatedUser?

    init(currentUser: AuthenticatedUser?) {
        self.currentUser = currentUser
    }

    func signInWithApple() async throws -> AuthenticatedUser { throw AuthError.notConfigured }
    func signInWithGoogle(presentingController: UIViewController?) async throws -> AuthenticatedUser { throw AuthError.notConfigured }
    func signOut() throws {}
}
#endif
