import SwiftUI

struct PlaceholderView: View {
    let title: String

    @State private var isPresentingSettings = false
    @State private var isPresentingHistory = false
    @State private var isPresentingSubmissions = false
    @State private var isPresentingNotifications = false
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var family: FamilyViewModel

    var body: some View {
        NavigationStack {
            placeholderContent
                .toolbar { toolbarContent }
                .sheet(isPresented: $isPresentingSettings) {
                    SettingsView()
                        .environmentObject(session)
                }
                .sheet(isPresented: $isPresentingNotifications) {
                    NotificationsView()
                }
                .sheet(isPresented: $isPresentingHistory) {
                    ParentHistoryView()
                        .environmentObject(session)
                        .environmentObject(family)
                }
                .sheet(isPresented: $isPresentingSubmissions) {
                    ParentSubmissionsReviewView()
                        .environmentObject(session)
                }
        }
    }
}

private extension PlaceholderView {
    @ViewBuilder
    var placeholderContent: some View {
        if shouldShowKidChores {
            KidChoresView()
        } else if shouldShowKidRewards {
            AppScreen {
                KidRewardsView()
            }
        } else {
            AppScreen {
                VStack(spacing: AppSpacing.section) {
                    AppSectionHeader(title: title)
                    VStack(spacing: 12) {
                        Image(systemName: "hammer")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("\(title) coming soon")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .appRowBackground(color: Color(.systemGray5))
                }
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
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

            if isParent {
                Button { isPresentingHistory = true } label: {
                    Image(systemName: "clock")
                        .imageScale(.large)
                }
                .accessibilityLabel("History")

                Button { isPresentingSubmissions = true } label: {
                    Image(systemName: "photo.on.rectangle")
                        .imageScale(.large)
                }
                .accessibilityLabel("Submissions")
            }

            Button { isPresentingSettings = true } label: {
                Image(systemName: "gearshape")
                    .imageScale(.large)
            }
            .accessibilityLabel("Settings")
        }
    }

    var isParent: Bool { session.profile?.role == .parent }

    var shouldShowKidChores: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (trimmed == "chores" || trimmed == "my chores") && session.profile?.role == .kid
    }

    var shouldShowKidRewards: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "rewards" && session.profile?.role == .kid
    }

    var currentKidStars: Int {
        guard let name = session.profile?.displayName else { return 0 }
        return family.kids.first(where: { $0.name == name })?.coins ?? 0
    }
}

#if DEBUG
#Preview("Kid Placeholder – Rewards") {
    let familyVM = FamilyViewModel(kids: [Kid(name: "Kenny Kid", coins: 12)])
    let session = AppSessionViewModel.previewKidSession(familyName: "Williams")
    return PlaceholderView(title: "Rewards")
        .environmentObject(session)
        .environmentObject(familyVM)
}
#endif
