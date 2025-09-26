import SwiftUI

struct PlaceholderView: View {
    let title: String
    private let headerHeight: CGFloat = 200
    @State private var isSelecting: Bool = false
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSelecting ? "Cancel" : "Select") {
                        isSelecting.toggle()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: Add plus action
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: Show notifications
                    } label: {
                        Image(systemName: "bell")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Notifications")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: Open settings
                    } label: {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Settings")
                }
            }
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
