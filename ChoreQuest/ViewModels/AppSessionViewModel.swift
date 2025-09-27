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

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let storageService: StorageService
    private let familyViewModel: FamilyViewModel
    private let choresViewModel: ChoresViewModel
    private let rewardsViewModel: RewardsViewModel

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
                let family = try await firestoreService.joinFamily(withCode: trimmed, user: profile, role: .kid)
                var updatedProfile = profile
                updatedProfile.familyId = family.id
                updatedProfile.role = .kid
                try await firestoreService.saveUserProfile(updatedProfile)
                self.profile = updatedProfile
                await loadFamilyData(familyId: family.id)
                state = .kid(updatedProfile)
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
}

private extension AppSessionViewModel {
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
            if var existingProfile = try await firestoreService.fetchUserProfile(uid: user.id) {
                if existingProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state = .profileSetup(user)
                    return
                }
                profile = existingProfile
                if let familyId = existingProfile.familyId {
                    await loadFamilyData(familyId: familyId)
                } else {
                    clearFamilyData()
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
                state = .profileSetup(user)
            }
        } catch {
            handle(error)
            state = .unauthenticated
        }
    }

    func loadFamilyData(familyId: String) async {
        do {
            let snapshot = try await firestoreService.fetchFamilySnapshot(familyId: familyId)
            await MainActor.run {
                self.currentFamily = snapshot.family
                self.familyViewModel.replaceKids(snapshot.kids)
                self.choresViewModel.replace(chores: snapshot.chores)
                self.choresViewModel.replaceAvailableKids(with: snapshot.kids.map(\.name))
                self.rewardsViewModel.replace(rewards: snapshot.rewards)
            }
        } catch {
            handle(error)
            await MainActor.run {
                self.currentFamily = nil
                self.clearFamilyData()
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
