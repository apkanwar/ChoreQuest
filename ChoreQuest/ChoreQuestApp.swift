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
#if canImport(UIKit)
import UIKit
#endif

@main
struct ChoreQuestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        configureFirebase()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
            #if os(iOS)
                .onAppear {
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                    AppDelegate.orientationLock = .portrait
                }
            #endif
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

#if canImport(UIKit)
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
#endif
