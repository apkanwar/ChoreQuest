import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: AppSessionViewModel

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView("Loading...")
                    .progressViewStyle(.circular)
            case .unauthenticated:
                AuthenticationView()
            case let .profileSetup(user):
                ProfileSetupView(user: user)
            case let .choosingRole(profile):
                FamilySetupView(profile: profile)
            case .parent:
                ParentTabView()
            case .kid:
                KidMainView()
            }
        }
        .animation(.easeInOut, value: session.state)
        .disabled(session.isProcessing)
        .overlay {
            if session.isProcessing {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Processing...")
                        .progressViewStyle(.circular)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.thinMaterial)
                        )
                }
            }
        }
        .alert(isPresented: Binding(get: { session.errorMessage != nil }, set: { _ in session.errorMessage = nil })) {
            Alert(
                title: Text("Authentication Error"),
                message: Text(session.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#if DEBUG
#Preview("App Root - Unauthenticated") {
    let familyVM = FamilyViewModel()
    let choresVM = ChoresViewModel()
    let rewardsVM = RewardsViewModel()
    let session = AppSessionViewModel(
        authService: MockAuthService(),
        firestoreService: MockFirestoreService.shared,
        storageService: MockStorageService(),
        familyViewModel: familyVM,
        choresViewModel: choresVM,
        rewardsViewModel: rewardsVM
    )
    return AuthenticationView()
        .environmentObject(session)
        .environmentObject(familyVM)
        .environmentObject(choresVM)
        .environmentObject(rewardsVM)
}
#endif
