import SwiftUI

struct KidMainView: View {
    var body: some View {
        TabView {
            PlaceholderView(title: "My Chores")
                .tabItem {
                    Label("Chores", systemImage: "checklist")
                }

            PlaceholderView(title: "Rewards")
                .tabItem {
                    Label("Rewards", systemImage: "gift")
                }

            PlaceholderView(title: "Profile")
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}

#if DEBUG
#Preview("Kid Main View") {
    KidMainView()
}
#endif
