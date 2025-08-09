
//  SetApp.swift
//  Set
//
//  Created by Jeff Fleurima on 6/12/25.
//

import SwiftUI

@main
struct SetApp: App {
    @StateObject private var voiceAssistant = VoiceAssistantManager.shared
    
    init() {
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.surface)
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppTheme.text)
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.primary)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.text)]
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.primary)]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        
        // Start wake word detection asynchronously to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) {
            DispatchQueue.main.async {
                VoiceAssistantManager.shared.startWakeWordDetection()
            }
        }
    }
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(voiceAssistant)
        }
    }
}
