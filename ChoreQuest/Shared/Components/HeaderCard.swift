import SwiftUI

struct HeaderCard: View {
    @EnvironmentObject private var session: AppSessionViewModel

    let displayNameOverride: String?
    let familyNameOverride: String?

    init(displayNameOverride: String? = nil, familyNameOverride: String? = nil) {
        self.displayNameOverride = displayNameOverride
        self.familyNameOverride = familyNameOverride
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 238)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
                .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome Back, \(displayNameOverride ?? session.profile?.displayName ?? "Sam")")
                    .font(.system(.largeTitle, design: .rounded)).bold()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .allowsTightening(true)

                HStack(spacing: 0) {
                    Text("Part of the ")
                    Text(familyNameOverride ?? session.currentFamily?.name ?? "Family")
                        .fontWeight(.semibold)
                    Text(" Family")
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 110)
            .safeAreaPadding(.top)
        }
    }
}

#if DEBUG
#Preview("Header - Parent") {
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
    return HeaderCard(displayNameOverride: "Sam", familyNameOverride: "Williams")
        .environmentObject(session)
}

#Preview("Header - Kid") {
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
    return HeaderCard(displayNameOverride: "Alex", familyNameOverride: "Williams")
        .environmentObject(session)
}
#endif


