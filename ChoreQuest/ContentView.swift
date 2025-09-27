import SwiftUI

struct ContentView: View {
    @StateObject private var familyViewModel: FamilyViewModel
    @StateObject private var choresViewModel: ChoresViewModel
    @StateObject private var rewardsViewModel: RewardsViewModel
    @StateObject private var appSession: AppSessionViewModel

    init() {
        let familyVM = FamilyViewModel()
        let choresVM = ChoresViewModel()
        let rewardsVM = RewardsViewModel()
        _familyViewModel = StateObject(wrappedValue: familyVM)
        _choresViewModel = StateObject(wrappedValue: choresVM)
        _rewardsViewModel = StateObject(wrappedValue: rewardsVM)
        _appSession = StateObject(
            wrappedValue: AppSessionViewModel(
                familyViewModel: familyVM,
                choresViewModel: choresVM,
                rewardsViewModel: rewardsVM
            )
        )
    }

    var body: some View {
        AppRootView()
            .environmentObject(appSession)
            .environmentObject(familyViewModel)
            .environmentObject(choresViewModel)
            .environmentObject(rewardsViewModel)
    }
}

#Preview {
    ContentView()
}
