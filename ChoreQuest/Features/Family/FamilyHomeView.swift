import SwiftUI

struct FamilyHomeView: View {
    @EnvironmentObject private var viewModel: FamilyViewModel
    @EnvironmentObject private var session: AppSessionViewModel

    @State private var selectedKid: Kid?
    @State private var isPresentingSettings = false
    @State private var isPresentingNotifications = false

    var body: some View {
        NavigationStack {
            AppScreen(headerTopOffset: 40) {
                KidsCard(kids: viewModel.kids) { kid in
                    selectedKid = kid
                }
            }
            .refreshable { await refreshFamily() }
            .sheet(item: $selectedKid) { kid in
                EditKidSheet(kid: kid, viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingSettings) {
                FamilySettingsView()
                    .environmentObject(session)
            }
            .sheet(isPresented: $isPresentingNotifications) {
                NotificationsView()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { isPresentingNotifications = true } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Notifications")

                    Button { isPresentingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .onAppear { session.loadFamilyIfNeeded() }
        }
    }
}

private extension FamilyHomeView {
    func refreshFamily() async {
        session.loadFamilyIfNeeded()
    }
}

#if DEBUG
#Preview("Family Home") {
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
    return FamilyHomeView()
        .environmentObject(session)
        .environmentObject(familyVM)
        .environmentObject(choresVM)
        .environmentObject(rewardsVM)
}
#endif
