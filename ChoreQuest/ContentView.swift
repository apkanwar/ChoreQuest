import SwiftUI

struct ContentView: View {
    @StateObject private var choresViewModel = ChoresViewModel()
    var body: some View {
        MainTabView()
            .environmentObject(choresViewModel)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            FamilyHomeView()
                .tabItem {
                    Label("Family", systemImage: "person.3")
                }

            ChoresHomeView()
                .tabItem {
                    Label("Chores", systemImage: "star")
                }

            PlaceholderView(title: "Rewards")
                .tabItem {
                    Label("Rewards", systemImage: "gift")
                }
        }
    }
}

#Preview {
    ContentView()
}

