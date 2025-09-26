import SwiftUI

struct FamilyHomeView: View {
    @EnvironmentObject private var viewModel: FamilyViewModel

    @State private var selectedKid: Kid?
    @State private var isPresentingAddKid = false

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
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
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
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // TODO: Show notifications
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Notifications")

                    Button {
                        // TODO: Open settings
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
    FamilyHomeView()
        .environmentObject(FamilyViewModel())
        .environmentObject(ChoresViewModel())
}
#endif
