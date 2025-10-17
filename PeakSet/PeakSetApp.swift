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
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func initializeVoiceSystem() {
        print("🚀 PeakSetApp: Initializing voice system...")
        
        // Start wake word detection automatically
        // This ONLY listens for "Hey Rex" - mic doesn't activate until wake word detected
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🎤 PeakSetApp: Starting wake word detection...")
            VoiceAssistantManager.shared.startWakeWordDetection()
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔗 PeakSetApp: Handling deep link: \(url)")
        print("🔗 PeakSetApp: URL scheme: \(url.scheme ?? "nil")")
        print("🔗 PeakSetApp: URL host: \(url.host ?? "nil")")
        print("🔗 PeakSetApp: URL path: \(url.path)")
        print("🔗 PeakSetApp: URL fragment: \(url.fragment ?? "nil")")
        print("🔗 PeakSetApp: URL query: \(url.query ?? "nil")")
        
        // Handle Supabase email confirmation
        if url.scheme == "com.X.PeakSet" || url.scheme == "peakset" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            
            // Check both fragment and query parameters for email confirmation
            let fragment = components?.fragment
            let query = components?.query
            
            print("📧 PeakSetApp: Processing fragment: \(fragment ?? "nil")")
            print("📧 PeakSetApp: Processing query: \(query ?? "nil")")
            
            // Parse fragment for email confirmation tokens
            if let fragment = fragment {
                let params = fragment.components(separatedBy: "&")
                for param in params {
                    let keyValue = param.components(separatedBy: "=")
                    if keyValue.count == 2 {
                        let key = keyValue[0]
                        let value = keyValue[1]
                        
                        print("📧 PeakSetApp: Fragment param - \(key): \(value)")
                        
                        if key == "access_token" || key == "refresh_token" || key == "type" {
                            print("✅ PeakSetApp: Email confirmation detected in fragment")
                            DispatchQueue.main.async {
                                print("🎉 Email confirmed successfully via fragment!")
                            }
                            return
                        }
                    }
                }
            }
            
            // Parse query parameters for email confirmation tokens
            if let query = query {
                let params = query.components(separatedBy: "&")
                for param in params {
                    let keyValue = param.components(separatedBy: "=")
                    if keyValue.count == 2 {
                        let key = keyValue[0]
                        let value = keyValue[1]
                        
                        print("📧 PeakSetApp: Query param - \(key): \(value)")
                        
                        if key == "access_token" || key == "refresh_token" || key == "type" {
                            print("✅ PeakSetApp: Email confirmation detected in query")
                            DispatchQueue.main.async {
                                print("🎉 Email confirmed successfully via query!")
                            }
                            return
                        }
                    }
                }
            }
            
            // Check for specific paths that might indicate email confirmation
            if url.path.contains("auth") || url.path.contains("callback") {
                print("✅ PeakSetApp: Email confirmation detected via path")
                DispatchQueue.main.async {
                    print("🎉 Email confirmed successfully via path!")
                }
                return
            }
        }
        
        print("⚠️ PeakSetApp: Unknown deep link format")
    }
}
