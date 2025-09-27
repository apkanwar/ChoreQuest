//
//  ChoreQuestApp.swift
//  ChoreQuest
//
//  Created by Atinderpaul Kanwar on 2025-09-25.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct ChoreQuestApp: App {
    init() {
        configureFirebase()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

private extension ChoreQuestApp {
    func configureFirebase() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #else
        // Firebase dependencies not installed in this build configuration.
        #endif
    }
}
