import Foundation
import AVFoundation
import UIKit

/// Professional speech generator with priority queue management
class PrioritySpeechGenerator: NSObject, SpeechGeneratorProtocol {
    
    // MARK: - Properties
    
    weak var delegate: SpeechGeneratorDelegate?
    
    private let synthesizer = AVSpeechSynthesizer()
    private var speechQueue: [SpeechRequest] = []
    private var currentRequest: SpeechRequest?
    private var voiceCharacteristics = VoiceCharacteristics.coaching
    private var voiceOverCompatible = false
    
    private let queueLock = NSLock()
    private var timeoutTimer: Timer?
    
    // MARK: - Protocol Properties
    
    var isSpeaking: Bool {
        return synthesizer.isSpeaking || currentRequest != nil
    }
    
    var currentPriority: SpeechPriority? {
        return currentRequest?.priority
    }
    
    var isVoiceOverRunning: Bool {
        return UIAccessibility.isVoiceOverRunning
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        
        // Listen for VoiceOver changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAllSpeech()
    }
    
    // MARK: - Public Interface
    
    func speak(_ request: SpeechRequest) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        print("🎤 [SpeechGen] New request: \"\(request.text)\" (\(request.priority.description))")
        
        // Handle VoiceOver compatibility
        if voiceOverCompatible && isVoiceOverRunning {
            handleVoiceOverSpeech(request)
            return
        }
        
        // Check if we should interrupt current speech
        if shouldInterruptCurrentSpeech(for: request.priority) {
            interruptCurrentSpeech()
        }
        
        // Add to queue or speak immediately
        if isSpeaking && !request.priority.shouldInterrupt {
            addToQueue(request)
        } else {
            speakImmediately(request)
        }
    }
    
    func speak(_ text: String, priority: SpeechPriority, completion: ((Bool) -> Void)? = nil) {
        let request = SpeechRequest(text: text, priority: priority, completion: completion)
        speak(request)
    }
    
    func stopSpeech(priority: SpeechPriority? = nil) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        if let priority = priority {
            // Stop only speech of this priority or lower
            removeFromQueue { $0.priority >= priority }
            
            if let currentPriority = currentRequest?.priority, currentPriority >= priority {
                synthesizer.stopSpeaking(at: .immediate)
            }
        } else {
            // Stop current speech
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        print("🎤 [SpeechGen] Stopped speech (priority: \(priority?.description ?? "all"))")
    }
    
    func stopAllSpeech() {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        synthesizer.stopSpeaking(at: .immediate)
        speechQueue.removeAll()
        cancelTimeout()
        
        print("🎤 [SpeechGen] Stopped all speech")
    }
    
    func pauseSpeech() {
        synthesizer.pauseSpeaking(at: .word)
        print("🎤 [SpeechGen] Paused speech")
    }
    
    func resumeSpeech() {
        synthesizer.continueSpeaking()
        print("🎤 [SpeechGen] Resumed speech")
    }
    
    func clearQueue(priority: SpeechPriority? = nil) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        if let priority = priority {
            removeFromQueue { $0.priority >= priority }
        } else {
            speechQueue.removeAll()
        }
        
        print("🎤 [SpeechGen] Cleared queue (priority: \(priority?.description ?? "all"))")
    }
    
    func getQueuedRequests() -> [SpeechRequest] {
        queueLock.lock()
        defer { queueLock.unlock() }
        return speechQueue
    }
    
    func setVoiceCharacteristics(_ characteristics: VoiceCharacteristics) {
        self.voiceCharacteristics = characteristics
        print("🎤 [SpeechGen] Updated voice characteristics")
    }
    
    func setVoiceOverCompatibility(_ enabled: Bool) {
        self.voiceOverCompatible = enabled
        print("🎤 [SpeechGen] VoiceOver compatibility: \(enabled)")
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voicePrompt, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            print("✅ [SpeechGen] Audio session configured")
        } catch {
            print("❌ [SpeechGen] Audio session error: \(error)")
            delegate?.speechGenerator(self, didFailWithError: error)
        }
    }
    
    private func shouldInterruptCurrentSpeech(for priority: SpeechPriority) -> Bool {
        guard let currentPriority = currentRequest?.priority else { return false }
        return priority.shouldInterrupt && priority < currentPriority
    }
    
    private func interruptCurrentSpeech() {
        if let current = currentRequest {
            synthesizer.stopSpeaking(at: .immediate)
            delegate?.speechGenerator(self, didInterruptSpeaking: current)
            print("🎤 [SpeechGen] Interrupted speech: \"\(current.text)\"")
        }
    }
    
    private func addToQueue(_ request: SpeechRequest) {
        // Insert based on priority (higher priority first)
        let insertIndex = speechQueue.firstIndex { $0.priority > request.priority } ?? speechQueue.count
        speechQueue.insert(request, at: insertIndex)
        
        print("🎤 [SpeechGen] Queued: \"\(request.text)\" (position: \(insertIndex))")
    }
    
    private func speakImmediately(_ request: SpeechRequest) {
        currentRequest = request
        
        let utterance = createUtterance(from: request)
        synthesizer.speak(utterance)
        
        // Set timeout if specified
        if let timeout = request.timeout {
            setupTimeout(for: request, duration: timeout)
        }
        
        delegate?.speechGenerator(self, didStartSpeaking: request)
        print("🎤 [SpeechGen] Speaking: \"\(request.text)\"")
    }
    
    private func createUtterance(from request: SpeechRequest) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: request.text)
        
        // Apply voice characteristics based on priority
        let characteristics = getCharacteristics(for: request.priority)
        utterance.rate = characteristics.rate
        utterance.pitchMultiplier = characteristics.pitch
        utterance.volume = characteristics.volume
        
        if let voiceIdentifier = characteristics.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        return utterance
    }
    
    private func getCharacteristics(for priority: SpeechPriority) -> VoiceCharacteristics {
        switch priority {
        case .immediateInterrupt:
            return .urgent
        case .immediateBlocking:
            return .coaching
        case .normal:
            return .instruction
        case .low:
            return .encouragement
        }
    }
    
    private func processQueue() {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard !speechQueue.isEmpty, !isSpeaking else { return }
        
        let nextRequest = speechQueue.removeFirst()
        speakImmediately(nextRequest)
    }
    
    private func removeFromQueue(where predicate: (SpeechRequest) -> Bool) {
        speechQueue.removeAll(where: predicate)
    }
    
    private func setupTimeout(for request: SpeechRequest, duration: TimeInterval) {
        cancelTimeout()
        
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if self.currentRequest?.id == request.id {
                print("⏰ [SpeechGen] Speech timeout for: \"\(request.text)\"")
                self.synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }
    
    private func cancelTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
    
    private func handleVoiceOverSpeech(_ request: SpeechRequest) {
        // For VoiceOver compatibility, we can post announcements
        UIAccessibility.post(notification: .announcement, argument: request.text)
        
        // Simulate completion after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.delegate?.speechGenerator(self, didFinishSpeaking: request, successfully: true)
            request.completion?(true)
        }
        
        print("🎤 [SpeechGen] VoiceOver announcement: \"\(request.text)\"")
    }
    
    @objc private func voiceOverStatusChanged() {
        print("🎤 [SpeechGen] VoiceOver status changed: \(isVoiceOverRunning)")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension PrioritySpeechGenerator: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // Already handled in speakImmediately
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        handleSpeechCompletion(successfully: true)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        handleSpeechCompletion(successfully: false)
    }
    
    private func handleSpeechCompletion(successfully: Bool) {
        queueLock.lock()
        
        if let request = currentRequest {
            currentRequest = nil
            cancelTimeout()
            
            queueLock.unlock()
            
            delegate?.speechGenerator(self, didFinishSpeaking: request, successfully: successfully)
            request.completion?(successfully)
            
            print("🎤 [SpeechGen] Finished: \"\(request.text)\" (success: \(successfully))")
            
            // Process next in queue
            DispatchQueue.main.async {
                self.processQueue()
            }
        } else {
            queueLock.unlock()
        }
    }
}
