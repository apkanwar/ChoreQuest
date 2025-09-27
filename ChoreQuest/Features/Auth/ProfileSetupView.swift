import SwiftUI

struct ProfileSetupView: View {
    let user: AuthenticatedUser
    @EnvironmentObject private var session: AppSessionViewModel
    @State private var displayName: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text("Welcome!")
                    .font(.largeTitle.bold())
                Text("Let’s get to know you. What should we call you?")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            TextField("Your name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                session.completeProfileSetup(displayName: displayName)
            } label: {
                Text("Continue")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding()
        .onAppear {
            if displayName.isEmpty, let existingName = user.displayName, !existingName.isEmpty {
                displayName = existingName
            }
        }
    }
}

#if DEBUG
#Preview("Profile Setup") {
    ProfileSetupView(user: AuthenticatedUser(id: "123", displayName: nil, email: "preview@example.com"))
        .environmentObject(
            AppSessionViewModel(
                familyViewModel: FamilyViewModel(),
                choresViewModel: ChoresViewModel(),
                rewardsViewModel: RewardsViewModel()
            )
        )
}
#endif

