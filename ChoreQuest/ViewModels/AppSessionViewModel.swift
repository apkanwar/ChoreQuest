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
            // Upload photo
            let path = "families/\(familyId)/submissions/\(chore.id.uuidString)/\(UUID().uuidString).jpg"
            let url = try await storageService.upload(data: photoData, to: path, contentType: "image/jpeg")

            // Create submission
            let submission = ChoreSubmission(
                choreId: chore.id,
                choreName: chore.name,
                kidName: profile.displayName,
                photoURL: url.absoluteString,
                rewardCoins: chore.rewardCoins
            )
            try await firestoreService.addChoreSubmission(submission, familyId: familyId)
            // Do not credit coins here; wait for parent approval.
            let entry = HistoryEntry(
                type: .choreCompleted,
                kidName: profile.displayName,
                title: chore.name,
                details: "Submitted for approval",
                amount: 0,
                submissionId: submission.id,
                photoURL: url.absoluteString
            )
            try await firestoreService.addHistoryEntry(entry, familyId: familyId)

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

    func redeemReward(_ reward: Reward, forKidNamed kidName: String) async {
        guard let familyId = self.profile?.familyId else { return }
        await setProcessing(true)
        do {
            // Deduct coins on server
            try await firestoreService.updateKidCoins(kidName: kidName, delta: -reward.cost, familyId: familyId)
            // Log history entry
            let entry = HistoryEntry(
                type: .rewardRedeemed,
                kidName: kidName,
                title: reward.name,
                details: reward.details,
                amount: -reward.cost
            )
            try await firestoreService.addHistoryEntry(entry, familyId: familyId)
            // Update local model so UI reflects immediately
            await MainActor.run {
                self.familyViewModel.addCoins(toKidNamed: kidName, delta: -reward.cost)
                self.infoMessage = "Redeemed \(reward.name)"
            }
        } catch {
            handle(error)
        }
        await setProcessing(false)
    }

    func redeemRewardAsCurrentKid(_ reward: Reward) async {
        guard let name = self.profile?.displayName else { return }
        await redeemReward(reward, forKidNamed: name)
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

    func fetchSubmissions() async -> [ChoreSubmission] {
        guard let familyId = self.profile?.familyId else { return [] }
        do { return try await firestoreService.fetchSubmissions(familyId: familyId) } catch { handle(error); return [] }
    }

    func approveSubmission(_ sub: ChoreSubmission) async {
        guard let familyId = self.profile?.familyId else { return }
        do {
            try await firestoreService.updateSubmissionStatus(familyId: familyId, submissionId: sub.id, status: .approved, reviewer: profile?.displayName, rejectionReason: nil)
            try await firestoreService.updateKidCoins(kidName: sub.kidName, delta: sub.rewardCoins, familyId: familyId)
            let entry = HistoryEntry(type: .choreCompleted, kidName: sub.kidName, title: sub.choreName, details: "Approved by Parent", amount: sub.rewardCoins, submissionId: sub.id, photoURL: sub.photoURL)
            try await firestoreService.addHistoryEntry(entry, familyId: familyId)
        } catch { handle(error) }
    }

    func rejectSubmission(_ sub: ChoreSubmission, reason: String? = "Not sufficient evidence") async {
        guard let familyId = self.profile?.familyId else { return }
        do {
            try await firestoreService.updateSubmissionStatus(familyId: familyId, submissionId: sub.id, status: .rejected, reviewer: profile?.displayName, rejectionReason: reason)
        } catch { handle(error) }
    }
}

private extension AppSessionViewModel {
    func setUpSync() {
        // Kids sync
        familyViewModel.$kids
            .receive(on: DispatchQueue.main)
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
                        if let latest = submissions.first, latest.submittedAt > Date().addingTimeInterval(-35) {
                            await MainActor.run {
                                self.recentNotification = "New submission from \(latest.kidName): \(latest.choreName)"
                                if let url = URL(string: latest.photoURL) {
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
            }
        } catch {
            handle(error)
            await MainActor.run {
                self.currentFamily = nil
                self.clearFamilyData()
                self.isSyncSuspended = false
            }
        }
    }

    func clearFamilyData() {
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

