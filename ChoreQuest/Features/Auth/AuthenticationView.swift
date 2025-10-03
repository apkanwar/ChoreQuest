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
                .disabled(true)

                Button(action: session.signInWithGoogle) {
                    Label {
                        Text("Continue with Google")
                    } icon: {
                        Image("google")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledRoundedButtonStyle(
                    background: .white,
                    foreground: .black,
                    borderStyle: AnyShapeStyle(
                        AngularGradient(
                            colors: [
                                Color(red: 66/255, green: 133/255, blue: 244/255), // Google Blue
                                Color(red: 52/255, green: 168/255, blue: 83/255),  // Google Green
                                Color(red: 251/255, green: 188/255, blue: 5/255),  // Google Yellow
                                Color(red: 234/255, green: 67/255, blue: 53/255),  // Google Red
                                Color(red: 66/255, green: 133/255, blue: 244/255)  // Close the loop
                            ],
                            center: .center
                        )
                    ),
                    borderWidth: 3
                ))
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
    var borderStyle: AnyShapeStyle? = nil
    var borderWidth: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.8 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderStyle ?? AnyShapeStyle(.clear), lineWidth: borderWidth)
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

