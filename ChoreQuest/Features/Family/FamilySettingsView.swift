import SwiftUI

struct FamilySettingsView: View {
    var body: some View {
        SettingsView()
    }
}

#if DEBUG
#Preview("Family Settings") {
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
    return FamilySettingsView()
        .environmentObject(session)
        .environmentObject(familyVM)
        .environmentObject(choresVM)
        .environmentObject(rewardsVM)
}
#endif
