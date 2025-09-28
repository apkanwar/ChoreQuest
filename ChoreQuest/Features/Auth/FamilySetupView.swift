import SwiftUI

struct FamilySetupView: View {
    let profile: UserProfile
    @EnvironmentObject private var session: AppSessionViewModel
    @State private var showCreateFamilyForm = false
    @State private var showJoinFamilyForm = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text("Hi, \(profile.displayName)!")
                    .font(.largeTitle.bold())
                Text("Would you like to start a new family or join an existing one?")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }

            VStack(spacing: 16) {
                Button {
                    showCreateFamilyForm = true
                } label: {
                    VStack(spacing: 6) {
                        Text("Start a Family")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                Button {
                    showJoinFamilyForm = true
                } label: {
                    VStack(spacing: 6) {
                        Text("Join a Family")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Button("Switch Account", action: session.signOut)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showCreateFamilyForm) {
            CreateFamilySheet { name in
                session.createFamily(named: name)
            }
        }
        .sheet(isPresented: $showJoinFamilyForm) {
            JoinFamilySheet { code in
                session.joinFamily(withCode: code)
            }
        }
    }
}

#if DEBUG
#Preview("Role Selection") {
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
    return FamilySetupView(profile: UserProfile(id: "123", displayName: "Preview"))
        .environmentObject(session)
        .environmentObject(familyVM)
        .environmentObject(choresVM)
        .environmentObject(rewardsVM)
}
#endif
