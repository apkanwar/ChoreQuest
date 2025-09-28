import SwiftUI

struct FamilyHomeView: View {
    @EnvironmentObject private var viewModel: FamilyViewModel
    @EnvironmentObject private var session: AppSessionViewModel

    @State private var selectedKid: Kid?
    @State private var isPresentingAddKid = false
    @State private var isPresentingSettings = false

    private let headerHeight: CGFloat = 200
    private var maxContentWidth: CGFloat { 640 }
    private let headerTopContentOffset: CGFloat = 32

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                headerView

                ScrollView(.vertical) {
                    Color.clear
                        .frame(height: headerHeight - headerTopContentOffset)

                    VStack(spacing: 20) {
                        KidsCard(kids: viewModel.kids) { kid in
                            selectedKid = kid
                        }
                        .frame(maxWidth: maxContentWidth)
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
                }
            }
            .overlay(alignment: .top) {
                HStack {
                    Spacer()
                    Button {
                        isPresentingAddKid = true
                    } label: {
                        let base = Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)

                        if #available(iOS 18.0, macOS 15.0, *) {
                            base.glassEffect(.regular.interactive(), in: .circle)
                        } else {
                            base
                                .background(
                                    Circle()
                                        .fill(Color(.systemBackground))
                                )
                        }
                    }
                    .accessibilityLabel("Add Kid")
                    #if os(iOS)
                    .hoverEffect(.lift)
                    #endif
                }
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal)
                .padding(.vertical, 100)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .sheet(item: $selectedKid) { kid in
                EditKidSheet(kid: kid, viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingAddKid) {
                AddKidSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $isPresentingSettings) {
                FamilySettingsView()
                    .environmentObject(session)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // TODO: Show notifications
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Notifications")

                    Button {
                        isPresentingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }
}

private extension FamilyHomeView {
    var headerView: some View {
        HeaderCard()
            .ignoresSafeArea(edges: .top)
            .frame(height: headerHeight)
            .zIndex(1000)
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
