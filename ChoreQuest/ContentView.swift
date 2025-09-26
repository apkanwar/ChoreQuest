import SwiftUI

struct ContentView: View {
    @StateObject private var familyViewModel = FamilyViewModel()
    @StateObject private var choresViewModel = ChoresViewModel()
    @StateObject private var rewardsViewModel = RewardsViewModel()
    var body: some View {
        MainTabView()
            .environmentObject(familyViewModel)
            .environmentObject(choresViewModel)
            .environmentObject(rewardsViewModel)
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

            RewardsHomeView()
                .tabItem {
                    Label("Rewards", systemImage: "gift")
                }
        }
    }
}

#Preview {
    ContentView()
}
