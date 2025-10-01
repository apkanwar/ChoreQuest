import SwiftUI

struct KidRewardsScreen: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var familyVM: FamilyViewModel

    @State private var isPresentingNotifications = false
    @State private var isPresentingSettings = false

    var body: some View {
        AppScreen {
            KidRewardsView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    // TODO: Show stars wallet
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .imageScale(.large)
                        Text("\(currentKidStars)")
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.yellow)
                }
                .accessibilityLabel("Stars \(currentKidStars)")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { isPresentingNotifications = true } label: {
                    Image(systemName: "bell")
                        .imageScale(.large)
                }
                .accessibilityLabel("Notifications")

                Button { isPresentingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $isPresentingNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView()
        }
    }
}

private extension KidRewardsScreen {
    var currentKidStars: Int {
        guard let displayName = session.profile?.displayName else { return 0 }
        return familyVM.kids.first(where: { $0.name == displayName })?.coins ?? 0
    }
}

#if DEBUG
#Preview("Kid Rewards Screen") {
    NavigationStack {
        KidRewardsScreen()
            .environmentObject(AppSessionViewModel.previewKidSession())
            .environmentObject(RewardsViewModel(rewards: Reward.previewList))
            .environmentObject(FamilyViewModel(kids: [Kid(name: "Kenny Kid", coins: 60)]))
    }
}
#endif
