import Foundation
import AVFoundation

/// Professional voice manager using ElevenLabs for human-like speech synthesis
class ElevenLabsVoiceManager: NSObject, ObservableObject {
    static let shared = ElevenLabsVoiceManager()
    
    // MARK: - Properties
    private let apiKey: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    private var audioPlayer: AVAudioPlayer?
    
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
    func speak(_ text: String, style: CoachingStyle, completion: @escaping (Bool) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ ElevenLabsVoiceManager: No API key available")
            completion(false)
            return
        }
        
        Task {
            do {
                let audioData = try await generateSpeech(text: text, style: style)
                await MainActor.run {
                    self.playAudio(audioData, completion: completion)
                }
            } catch {
                print("❌ ElevenLabsVoiceManager: Speech generation failed: \(error)")
                await MainActor.run {
                    completion(false)
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
    
    private func playAudio(_ audioData: Data, completion: @escaping (Bool) -> Void) {
        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            // Create audio player
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            
            print("🎤 ElevenLabsVoiceManager: Playing human-like speech")
            
        } catch {
            print("❌ ElevenLabsVoiceManager: Audio playback failed: \(error)")
            completion(false)
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension ElevenLabsVoiceManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ ElevenLabsVoiceManager: Speech playback completed")
        audioPlayer = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ ElevenLabsVoiceManager: Audio decode error: \(error?.localizedDescription ?? "Unknown")")
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
