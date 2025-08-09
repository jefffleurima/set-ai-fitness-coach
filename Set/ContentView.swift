//
//  ContentView.swift
//  Set
//
//  Created by Jeff Fleurima on 6/12/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            TabView {
                ExerciseView()
                    .tabItem {
                        Label("Exercise", systemImage: "figure.run")
                    }
                MessagesView()
                    .tabItem {
                        Label("Chat", systemImage: "message")
                    }
                SummaryView()
                    .tabItem {
                        Label("Summary", systemImage: "chart.bar")
                    }
            }
            .tint(AppTheme.primary)
            .background(AppTheme.surface)
        }
    }
}

#Preview {
    ContentView()
}
