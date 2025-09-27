import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var session: AppSessionViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Text("Welcome to ChoreQuest")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Sign in to manage chores and rewards with your family.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                Button(action: session.signInWithApple) {
                    Label("Continue with Apple", systemImage: "apple.logo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledRoundedButtonStyle(background: .black, foreground: .white))

                Button(action: session.signInWithGoogle) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.headline)
                        Spacer()
                        Text("Continue with Google")
                            .font(.headline)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledRoundedButtonStyle(background: .white, foreground: .black, borderColor: Color.gray.opacity(0.3)))
                .disabled(session.isProcessing)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct FilledRoundedButtonStyle: ButtonStyle {
    var background: Color
    var foreground: Color
    var borderColor: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.8 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor ?? .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview("Authentication") {
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
