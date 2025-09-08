import Foundation
import AVFoundation

/// Professional voice manager using ElevenLabs for human-like speech synthesis
class ElevenLabsVoiceManager: NSObject, ObservableObject {
    static let shared = ElevenLabsVoiceManager()
    
    // MARK: - Properties
    private let apiKey: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletion: ((Bool) -> Void)?
    
    // MARK: - Voice IDs for different coaching styles
    private let voiceIds: [CoachingStyle: String] = [
        .motivational: "fPPaDY0hdGB9BZHjuhwb", // Rex - Your custom female fitness coach voice
        .technical: "fPPaDY0hdGB9BZHjuhwb",    // Rex - Your custom female fitness coach voice
        .supportive: "fPPaDY0hdGB9BZHjuhwb",   // Rex - Your custom female fitness coach voice
        .professional: "fPPaDY0hdGB9BZHjuhwb"  // Rex - Your custom female fitness coach voice
    ]
    
    // MARK: - Voice Settings
    private let voiceSettings: [CoachingStyle: [String: Any]] = [
        .motivational: [
            "stability": 0.3,
            "similarity_boost": 0.8,
            "style": 0.7,
            "use_speaker_boost": true
        ],
        .technical: [
            "stability": 0.8,
            "similarity_boost": 0.9,
            "style": 0.3,
            "use_speaker_boost": true
        ],
        .supportive: [
            "stability": 0.6,
            "similarity_boost": 0.7,
            "style": 0.5,
            "use_speaker_boost": true
        ],
        .professional: [
            "stability": 0.9,
            "similarity_boost": 0.8,
            "style": 0.2,
            "use_speaker_boost": true
        ]
    ]
    
    // MARK: - Initialization
    override init() {
        // Get API key from AppConfig
        self.apiKey = AppConfig.elevenLabsApiKey
        super.init()
        
        if apiKey.isEmpty {
            print("⚠️ ElevenLabsVoiceManager: No ElevenLabs API key found. Please add ELEVENLABS_API_KEY to Info.plist")
        } else {
            print("✅ ElevenLabsVoiceManager: API key loaded successfully")
        }
    }
    
    // MARK: - Public Methods
    
    /// Generate and play human-like speech with coaching personality
    /// PRIORITY: ElevenLabs is premium - try aggressively before any fallback
    func speak(_ text: String, style: CoachingStyle, completion: @escaping (Bool) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ ElevenLabsVoiceManager: No API key available")
            completion(false)
            return
        }
        
        print("🎤 [PREMIUM] ElevenLabs Rex voice generating: '\(text)' with \(style) style")
        print("🔑 ElevenLabsVoiceManager: Using API key: \(String(apiKey.prefix(10)))...")
        
        // Try with fewer retries for better reliability
        attemptSpeechWithRetry(text: text, style: style, attempt: 1, maxAttempts: 2, completion: completion)
    }
    
    /// Aggressive retry logic for ElevenLabs premium voice - last resort before Apple TTS
    private func attemptSpeechWithRetry(text: String, style: CoachingStyle, attempt: Int, maxAttempts: Int, completion: @escaping (Bool) -> Void) {
        let delayInterval = TimeInterval(attempt - 1) * 0.5 // Exponential backoff: 0s, 0.5s, 1s, 1.5s
        
        print("🔄 [PREMIUM] ElevenLabs attempt \(attempt)/\(maxAttempts) (delay: \(delayInterval)s)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delayInterval) {
            // Check network connectivity for API calls
            if attempt > 1 {
                print("🌐 [PREMIUM] Checking network for ElevenLabs API attempt \(attempt)")
            }
            
            Task {
                do {
                    let audioData = try await self.generateSpeechWithRetry(text: text, style: style, attempt: attempt)
                    print("✅ [PREMIUM] ElevenLabs generated audio (\(audioData.count) bytes) on attempt \(attempt)")
                    
                    await MainActor.run {
                        // Try playback with retry
                        self.playAudioWithRetry(audioData, attempt: attempt, completion: completion)
                    }
                } catch {
                    print("❌ [PREMIUM] ElevenLabs generation failed attempt \(attempt): \(error)")
                    
                    if attempt < maxAttempts {
                        print("🔄 [PREMIUM] Retrying ElevenLabs in \(delayInterval + 0.5)s...")
                        await MainActor.run {
                            self.attemptSpeechWithRetry(text: text, style: style, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                        }
                    } else {
                        print("💔 [PREMIUM] ElevenLabs exhausted all \(maxAttempts) attempts - API/network issues")
                        await MainActor.run {
                            completion(false)
                        }
                    }
                }
            }
        }
    }
    
    /// Stop current speech playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: - Private Methods
    
    /// Enhanced speech generation with network error handling
    private func generateSpeechWithRetry(text: String, style: CoachingStyle, attempt: Int) async throws -> Data {
        do {
            return try await generateSpeech(text: text, style: style)
        } catch {
            if attempt > 1 {
                print("⚠️ [PREMIUM] Network/API error on attempt \(attempt): \(error.localizedDescription)")
                // Add small delay for network recovery
                try await Task.sleep(nanoseconds: 250_000_000) // 0.25s
            }
            throw error
        }
    }
    
    private func generateSpeech(text: String, style: CoachingStyle) async throws -> Data {
        guard let voiceId = voiceIds[style] else {
            throw VoiceError.invalidVoiceStyle
        }
        
        let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        // Prepare request body with voice settings
        let requestBody: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": voiceSettings[style] ?? [:]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ ElevenLabsVoiceManager: API error \(httpResponse.statusCode): \(errorMessage)")
            throw VoiceError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        return data
    }
    
    /// Enhanced playback with multiple audio session recovery attempts
    private func playAudioWithRetry(_ audioData: Data, attempt: Int, completion: @escaping (Bool) -> Void) {
        print("🔊 [PREMIUM] ElevenLabs playback attempt \(attempt)")
        
        do {
            try AudioSessionManager.shared.configureForPlayback()
            
            self.audioPlayer = try AVAudioPlayer(data: audioData)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.volume = 1.0
            self.audioPlayer?.prepareToPlay()
            
            self.playbackCompletion = completion
            
            let success = self.audioPlayer?.play() ?? false
            if success {
                print("🎤 [PREMIUM] ElevenLabs Rex voice playing successfully on attempt \(attempt)")
                return
            } else {
                print("❌ [PREMIUM] ElevenLabs playback failed to start on attempt \(attempt)")
                // Try audio session recovery
                attemptAudioSessionRecovery(audioData, attempt: attempt, completion: completion)
            }
            
        } catch {
            print("❌ [PREMIUM] ElevenLabs audio session error on attempt \(attempt): \(error)")
            // Try audio session recovery
            attemptAudioSessionRecovery(audioData, attempt: attempt, completion: completion)
        }
    }
    
    /// Audio session recovery for ElevenLabs voice
    private func attemptAudioSessionRecovery(_ audioData: Data, attempt: Int, completion: @escaping (Bool) -> Void) {
        if attempt < 2 {  // Try up to 2 times with escalating recovery
            let recoveryDelay = TimeInterval(attempt) * 0.3 // 0.3s, 0.6s, 0.9s
            print("🔧 [PREMIUM] Audio session recovery attempt \(attempt + 1) in \(recoveryDelay)s...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + recoveryDelay) {
                // Escalating recovery methods
                if attempt == 1 {
                    AudioSessionManager.shared.forceReset()
                } else if attempt == 2 {
                    // More aggressive reset
                    AudioSessionManager.shared.forceReset()
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                self.playAudioWithRetry(audioData, attempt: attempt + 1, completion: completion)
            }
        } else {
            print("💔 [PREMIUM] ElevenLabs audio playback exhausted all recovery attempts")
            completion(false)
        }
    }
    
    private func playAudio(_ audioData: Data, completion: @escaping (Bool) -> Void) {
        do {
            // Use centralized audio session manager
            try AudioSessionManager.shared.configureForPlayback()
            
            // Create audio player
            self.audioPlayer = try AVAudioPlayer(data: audioData)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.volume = 1.0
            self.audioPlayer?.prepareToPlay()
            
            // Add completion handler
            self.playbackCompletion = completion
            
            // Play audio
            let success = self.audioPlayer?.play() ?? false
            if success {
                print("🎤 ElevenLabsVoiceManager: Playing human-like speech with volume: \(self.audioPlayer?.volume ?? 0)")
            } else {
                print("❌ ElevenLabsVoiceManager: Failed to start playback")
                completion(false)
            }
            
        } catch {
            print("❌ ElevenLabsVoiceManager: Audio session configuration failed: \(error)")
            
            // PRIORITY: ElevenLabs must work - try multiple recovery attempts
            print("🔄 ElevenLabsVoiceManager: Attempting aggressive recovery for premium voice...")
            
            // Attempt 1: Force reset and retry
            AudioSessionManager.shared.forceReset()
            
            do {
                try AudioSessionManager.shared.configureForPlayback()
                print("✅ ElevenLabsVoiceManager: First retry successful after force reset")
                
                // Continue with audio playback
                self.audioPlayer = try AVAudioPlayer(data: audioData)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.volume = 1.0
                self.audioPlayer?.prepareToPlay()
                
                self.playbackCompletion = completion
                
                let success = self.audioPlayer?.play() ?? false
                if success {
                    print("🎤 ElevenLabsVoiceManager: Playing premium Rex voice with volume: \(self.audioPlayer?.volume ?? 0)")
                    return
                } else {
                    print("❌ ElevenLabsVoiceManager: First retry failed to start playback")
                }
                
            } catch {
                print("❌ ElevenLabsVoiceManager: First retry failed: \(error)")
            }
            
            // Attempt 2: Wait longer and try again
            print("🔄 ElevenLabsVoiceManager: Second attempt with longer delay...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                do {
                    AudioSessionManager.shared.forceReset()
                    try AudioSessionManager.shared.configureForPlayback()
                    print("✅ ElevenLabsVoiceManager: Second retry successful")
                    
                    // Continue with audio playback
                    self.audioPlayer = try AVAudioPlayer(data: audioData)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.volume = 1.0
                    self.audioPlayer?.prepareToPlay()
                    
                    self.playbackCompletion = completion
                    
                    let success = self.audioPlayer?.play() ?? false
                    if success {
                        print("🎤 ElevenLabsVoiceManager: Playing premium Rex voice (second attempt) with volume: \(self.audioPlayer?.volume ?? 0)")
                        return
                    } else {
                        print("❌ ElevenLabsVoiceManager: Second retry failed to start playback")
                        completion(false)
                    }
                    
                } catch {
                    print("❌ ElevenLabsVoiceManager: Second retry failed: \(error)")
                    completion(false)
                }
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension ElevenLabsVoiceManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ ElevenLabsVoiceManager: Speech playback completed successfully")
        playbackCompletion?(flag)
        playbackCompletion = nil
        audioPlayer = nil
        
        // Notify VoiceAssistantManager that ElevenLabs speech finished to start listening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .elevenLabsSpeechFinished, object: nil)
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ ElevenLabsVoiceManager: Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        playbackCompletion?(false)
        playbackCompletion = nil
        audioPlayer = nil
    }
}

// MARK: - Error Types

enum VoiceError: Error, LocalizedError {
    case invalidVoiceStyle
    case invalidResponse
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidVoiceStyle:
            return "Invalid voice style selected"
        case .invalidResponse:
            return "Invalid response from voice service"
        case .apiError(let code, let message):
            return "API error \(code): \(message)"
        }
    }
}



// MARK: - Coaching Style Extension

extension CoachingStyle {
    var displayName: String {
        switch self {
        case .motivational: return "Motivational"
        case .technical: return "Technical"
        case .supportive: return "Supportive"
        case .professional: return "Professional"
        }
    }
}
