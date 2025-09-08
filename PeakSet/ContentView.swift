//
//  ContentView.swift
//  PeakSet
//
//  Created by Jeff Fleurima on 9/7/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        SplashScreenView()
    }
}

// MARK: - Main App View
struct MainAppView: View {
    @StateObject private var aiCoachViewModel = AICoachViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Exercise View (Main Camera/Workout)
            ExerciseView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Exercise")
                }
                .tag(0)
            
            // Messages/Coaching History
            MessagesView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Coaching")
                }
                .tag(1)
            
            // Summary/Progress
            SummaryView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Progress")
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
