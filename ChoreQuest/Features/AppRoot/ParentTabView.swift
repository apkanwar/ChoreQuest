import SwiftUI

struct ParentTabView: View {
    var body: some View {
        TabView {
            FamilyHomeView()
                .tabItem {
                    Label("Family", systemImage: "person.3")
                }

            ChoresHomeView()
                .tabItem {
                    Label("Chores", systemImage: "star")
                }

            RewardsHomeView()
                .tabItem {
                    Label("Rewards", systemImage: "gift")
                }
        }
    }
}

#if DEBUG
#Preview("Parent Tab View") {
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
    return ParentTabView()
        .environmentObject(session)
        .environmentObject(familyVM)
        .environmentObject(choresVM)
        .environmentObject(rewardsVM)
}
#endif
