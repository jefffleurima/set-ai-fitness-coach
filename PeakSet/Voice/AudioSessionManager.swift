import AVFoundation
import Foundation

/// Centralized audio session manager to prevent conflicts between ElevenLabs and speech recognition
class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private var currentMode: AudioMode = .inactive
    private let audioSession = AVAudioSession.sharedInstance()
    
    enum AudioMode {
        case inactive
        case playback
        case recording
    }
    
    private init() {}
    
    /// Configure audio session for speech playback
    func configureForPlayback() throws {
        guard currentMode != .playback else { return }
        
        print("[AudioSession] Configuring for playback...")
        
        // Always deactivate first to ensure clean state
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("[AudioSession] Deactivated previous session")
        } catch {
            print("[AudioSession] Warning: Previous deactivation failed: \(error)")
        }
        
        // Wait a bit longer for clean transition
        Thread.sleep(forTimeInterval: 0.2)
        
        // Configure for playback with more aggressive options
        try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Note: Volume is controlled by the audio player, not the audio session
        
        currentMode = .playback
        print("[AudioSession] ✅ Configured for playback")
    }
    
    /// Configure audio session for speech recognition
    func configureForRecording() throws {
        guard currentMode != .recording else { return }
        
        print("[AudioSession] Configuring for recording...")
        
        // Always deactivate first to ensure clean state
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("[AudioSession] Deactivated previous session")
        } catch {
            print("[AudioSession] Warning: Previous deactivation failed: \(error)")
        }
        
        // Wait longer for clean transition and system recovery
        Thread.sleep(forTimeInterval: 0.5)
        
        // Try multiple approaches for recording configuration
        var success = false
        var lastError: Error?
        
        // Approach 1: Standard configuration
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voicePrompt, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            success = true
            print("[AudioSession] ✅ Configured for recording (standard)")
        } catch {
            lastError = error
            print("[AudioSession] ⚠️ Standard recording config failed: \(error)")
        }
        
        // Approach 2: Simplified configuration if standard fails
        if !success {
            Thread.sleep(forTimeInterval: 0.3)
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                success = true
                print("[AudioSession] ✅ Configured for recording (simplified)")
            } catch {
                lastError = error
                print("[AudioSession] ⚠️ Simplified recording config failed: \(error)")
            }
        }
        
        // Approach 3: Basic configuration as last resort
        if !success {
            Thread.sleep(forTimeInterval: 0.3)
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                success = true
                print("[AudioSession] ✅ Configured for recording (basic)")
            } catch {
                lastError = error
                print("[AudioSession] ❌ All recording config attempts failed")
                throw lastError ?? error
            }
        }
        
        currentMode = .recording
    }
    
    /// Deactivate audio session
    func deactivate() {
        guard currentMode != .inactive else { return }
        
        print("[AudioSession] Deactivating...")
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            currentMode = .inactive
            print("[AudioSession] ✅ Deactivated")
        } catch {
            print("[AudioSession] ❌ Deactivation failed: \(error)")
            // Force reset to inactive state even if deactivation fails
            currentMode = .inactive
        }
    }
    
    /// Get current audio session mode
    var isRecording: Bool {
        return currentMode == .recording
    }
    
    var isPlayback: Bool {
        return currentMode == .playback
    }
    
    /// Force reset audio session (emergency cleanup)
    func forceReset() {
        print("[AudioSession] Force resetting audio session...")
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            currentMode = .inactive
            print("[AudioSession] ✅ Force reset completed")
        } catch {
            print("[AudioSession] ❌ Force reset failed: \(error)")
            // Force state reset anyway
            currentMode = .inactive
        }
        
        // Wait for clean state
        Thread.sleep(forTimeInterval: 0.3)
    }
}
