import Foundation
import AVFoundation

/// Protocol for speech generation with priority support
protocol SpeechGeneratorProtocol: AnyObject {
    /// Current speech state
    var isSpeaking: Bool { get }
    var currentPriority: SpeechPriority? { get }
    var isVoiceOverRunning: Bool { get }
    
    /// Delegate for speech events
    var delegate: SpeechGeneratorDelegate? { get set }
    
    /// Core speech functions
    func speak(_ request: SpeechRequest)
    func speak(_ text: String, priority: SpeechPriority, completion: ((Bool) -> Void)?)
    func stopSpeech(priority: SpeechPriority?)
    func stopAllSpeech()
    func pauseSpeech()
    func resumeSpeech()
    
    /// Queue management
    func clearQueue(priority: SpeechPriority?)
    func getQueuedRequests() -> [SpeechRequest]
    
    /// Voice configuration
    func setVoiceCharacteristics(_ characteristics: VoiceCharacteristics)
    func setVoiceOverCompatibility(_ enabled: Bool)
}

/// Delegate for speech generation events
protocol SpeechGeneratorDelegate: AnyObject {
    func speechGenerator(_ generator: SpeechGeneratorProtocol, didStartSpeaking request: SpeechRequest)
    func speechGenerator(_ generator: SpeechGeneratorProtocol, didFinishSpeaking request: SpeechRequest, successfully: Bool)
    func speechGenerator(_ generator: SpeechGeneratorProtocol, didInterruptSpeaking request: SpeechRequest)
    func speechGenerator(_ generator: SpeechGeneratorProtocol, didFailWithError error: Error)
}

/// Voice characteristics for speech synthesis
struct VoiceCharacteristics {
    let rate: Float
    let pitch: Float
    let volume: Float
    let voiceIdentifier: String?
    
    init(rate: Float = 0.5, pitch: Float = 1.0, volume: Float = 1.0, voiceIdentifier: String? = nil) {
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
        self.voiceIdentifier = voiceIdentifier
    }
    
    /// Pre-configured voice characteristics for different coaching contexts
    static let coaching = VoiceCharacteristics(rate: 0.5, pitch: 0.95, volume: 1.0)
    static let urgent = VoiceCharacteristics(rate: 0.6, pitch: 1.1, volume: 1.0)
    static let encouragement = VoiceCharacteristics(rate: 0.45, pitch: 1.05, volume: 0.8)
    static let instruction = VoiceCharacteristics(rate: 0.4, pitch: 1.0, volume: 0.9)
}
