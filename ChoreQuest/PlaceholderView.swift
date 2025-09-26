import SwiftUI

struct PlaceholderView: View {
    let title: String
    private let headerHeight: CGFloat = 320
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                headerView

                ScrollView {
                    VStack(spacing: 20) {
                        Color.clear
                            .frame(height: headerHeight + 16)
                        VStack(spacing: 12) {
                            Image(systemName: "hammer")
                                .font(.system(size: 42))
                                .foregroundStyle(.secondary)
                            Text("\(title) coming soon")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            )
        }
    }
}

private extension PlaceholderView {
    var headerView: some View {
        HeaderCard()
            .ignoresSafeArea(edges: .top)
            .frame(height: headerHeight)
            .zIndex(1)
    }
}

#if DEBUG
#Preview("Family Rewards") {
    PlaceholderView(title: "Rewards")
}
#endif
