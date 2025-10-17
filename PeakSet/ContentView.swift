//
//  ContentView.swift
//  PeakSet
//
//  Created by Jeff Fleurima on 9/7/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        WelcomeScreenView()
    }
}

// MARK: - Main App View
struct MainAppView: View {
    @StateObject private var aiCoachViewModel = AICoachViewModel()
    @State private var selectedTab = 0
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Summary/Progress (Main tab for data collection app)
            SummaryView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Summary")
                }
                .tag(0)
            
            // Exercise View (Camera/Workout)
            ExerciseView()
                .tabItem {
                    Image(systemName: "figure.run.circle.fill")
                    Text("Exercise")
                }
                .tag(1)
            
            // Messages/Coaching History
            MessagesView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Coaching")
                }
                .tag(2)
        }
        .environmentObject(aiCoachViewModel)
        .accentColor(AppTheme.accent)
    }
}

#Preview {
    ContentView()
}
