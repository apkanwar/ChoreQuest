import SwiftUI

struct KidMainView: View {
    var body: some View {
        TabView {
            NavigationStack {
                KidChoresView()
            }
            .tabItem {
                Label("Chores", systemImage: "checklist")
            }

            NavigationStack {
                KidRewardsScreen()
            }
            .tabItem {
                Label("Rewards", systemImage: "gift")
            }

            NavigationStack {
                LeaderboardScreen()
            }
            .tabItem {
                Label("Leaderboard", systemImage: "trophy")
            }
        }
    }
}

#if DEBUG
#Preview("Kid Main View") {
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
    return KidMainView()
        .environmentObject(session)
        .environmentObject(familyVM)
        .environmentObject(choresVM)
        .environmentObject(rewardsVM)
}
#endif
