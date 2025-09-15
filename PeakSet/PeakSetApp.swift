//
//  PeaksetApp.swift
//  Peakset
//
//  Created by Jeff Fleurima on 9/7/25.
//

import SwiftUI

@main
struct PeaksetApp: App {
    @StateObject private var voiceAssistant = VoiceAssistantManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(voiceAssistant)
                .onAppear {
                    // Initialize voice system on app launch
                    initializeVoiceSystem()
                }
        }
    }
    
    private func initializeVoiceSystem() {
        print("🚀 PeakSetApp: Initializing voice system...")
        
        // Start wake word detection automatically
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🎤 PeakSetApp: Starting wake word detection...")
            VoiceAssistantManager.shared.startWakeWordDetection()
        }
    }
}
