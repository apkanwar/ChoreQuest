import SwiftUI

struct LeaderboardScreen: View {
    @EnvironmentObject private var familyVM: FamilyViewModel
    @EnvironmentObject private var session: AppSessionViewModel

    @State private var isPresentingNotifications = false
    @State private var isPresentingSettings = false

    private var leaderboardItems: [LeaderboardItem] {
        familyVM.kids.map { kid in
            LeaderboardItem(
                name: kid.name,
                current: kid.coins,
                lifetime: kid.coins,
                color: kid.color
            )
        }
    }

    private var currentKidStars: Int {
        guard let name = session.profile?.displayName else { return 0 }
        return familyVM.kids.first(where: { $0.name == name })?.coins ?? 0
    }

    var body: some View {
        AppScreen {
            if leaderboardItems.isEmpty {
                ContentUnavailableView(
                    "No kids yet",
                    systemImage: "trophy",
                    description: Text("Ask your parent to add family members.")
                )
                .frame(maxWidth: .infinity)
                .appCardStyle()
            } else {
                LeaderboardSection(items: leaderboardItems)
            }
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
                }
                .accessibilityLabel("Notifications")

                Button { isPresentingSettings = true } label: {
                    Image(systemName: "gearshape")
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
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct LeaderboardSection: View {
    let items: [LeaderboardItem]

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            LeaderboardCard(items: items)
                .appCardStyle()
        }
    }
}

#if DEBUG
struct LeaderboardScreen_Previews: PreviewProvider {
    static var previews: some View {
        let familyVM = FamilyViewModel()
        familyVM.replaceKids([
            Kid(name: "Alice", colorHex: "#FF5733", coins: 150),
            Kid(name: "Bob", colorHex: "#3380FF", coins: 230)
        ])
        let session = AppSessionViewModel.previewParentSession()

        return NavigationStack {
            LeaderboardScreen()
                .environmentObject(familyVM)
                .environmentObject(session)
        }
    }
}
#endif

