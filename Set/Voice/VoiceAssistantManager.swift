import Foundation
import Porcupine
import Speech
import AVFoundation

// MARK: - Premium Voice AI System
enum CoachingContext {
    case exerciseSetup
    case activeForm
    case restPeriod
    case sessionComplete
    case generalChat
}

enum CoachingStyle {
    case motivational    // "Let's go! That's what I'm talking about!"
    case technical      // "Focus on hip hinge movement pattern"
    case supportive     // "Good form, you're getting stronger"
    case professional   // "Maintain neutral spine position"
}

struct CoachingPersonality {
    var style: CoachingStyle
    let name: String
    var voiceCharacteristics: LegacyVoiceCharacteristics
}

struct LegacyVoiceCharacteristics {
    let rate: Float
    let pitch: Float
    let volume: Float
    let voiceIdentifier: String
}

class VoiceAssistantManager: NSObject, ObservableObject {
    static let shared = VoiceAssistantManager()
    
    // Published properties for UI
    @Published var isListening = false
    @Published var aiResponse: String? = nil
    @Published var feedbackMessage: String? = nil
    @Published var isWakeWordActive = false
    @Published var isWorkoutMode = false
    @Published var currentExercise: String? = nil
    
    private var porcupineManager: PorcupineManager?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var speechTimeoutTimer: Timer?
    private let speechPauseTimeout: TimeInterval = 0.8 // Increased from 0.4 to reduce timeout warnings
    private var conversationTimeoutTimer: Timer?
    private let conversationTimeout: TimeInterval = 8.0
    private let postWakeWordDelay: TimeInterval = 3.0  // Wait 3 seconds after "Hey Rex"
    private let postResponseListeningTime: TimeInterval = 3.0  // Listen for 3 seconds after response // Shorter timeout for faster responses
    private var isInConversation = false
    private var lastFormFeedbackTime: Date = Date()
    private let formFeedbackCooldown: TimeInterval = 2.0 // Prevent spam
    private var workoutContext: [String: Any] = [:]
    private var isProcessingSpeech = false // Prevent multiple simultaneous processing
    
    // MARK: - Premium Voice AI Properties
    private var currentContext: CoachingContext = .generalChat
    private var currentPersonality: CoachingPersonality
    private var coachingPhrases: [String: [String]] = [:]
    
    // Premium voice characteristics - Humanized for natural conversation
    private let premiumVoices: [CoachingStyle: LegacyVoiceCharacteristics] = [
        .motivational: LegacyVoiceCharacteristics(rate: 0.50, pitch: 1.15, volume: 1.0, voiceIdentifier: "com.apple.ttsbundle.siri_male_en-US_compact"),
        .technical: LegacyVoiceCharacteristics(rate: 0.55, pitch: 1.0, volume: 1.0, voiceIdentifier: "com.apple.ttsbundle.siri_male_en-US_compact"),
        .supportive: LegacyVoiceCharacteristics(rate: 0.52, pitch: 1.08, volume: 1.0, voiceIdentifier: "com.apple.ttsbundle.siri_male_en-US_compact"),
        .professional: LegacyVoiceCharacteristics(rate: 0.58, pitch: 0.98, volume: 1.0, voiceIdentifier: "com.apple.ttsbundle.siri_male_en-US_compact")
    ]
    
    // Fast response cache for common form corrections
    private let formCorrections: [String: String] = [
        // General
        "good_form": "Perfect! Keep it up",
        "almost_there": "Almost there! Small adjustment",
        "rep_count": "Great rep! Keep going",

        // Squats
        "squats_hipAngle_bad": "Hinge more at your hips. Sit back like you're sitting in a chair.",
        "squats_kneeAngle_bad": "Get deeper. Your thighs should be parallel to the ground.",
        "squats_torsoAngle_bad": "Keep your chest up but lean forward slightly for balance.",
        "squats_ankleAngle_bad": "Keep your weight in your heels. Don't let your knees go too far forward.",

        // Deadlifts
        "deadlifts_hipHingeAngle_bad": "Hinge more at your hips.",
        "deadlifts_backAngle_bad": "Keep your back flat! Don't round it.",
        "deadlifts_kneeAngle_bad": "Control your knee bend.",

        


        
        
    ]
    
    // Conversation history removed - now handled by individual processWithOpenAI calls
    
    override init() {
        // Initialize with supportive personality by default
        let defaultVoice = LegacyVoiceCharacteristics(rate: 0.52, pitch: 1.08, volume: 1.0, voiceIdentifier: "com.apple.ttsbundle.siri_male_en-US_compact")
        currentPersonality = CoachingPersonality(style: .supportive, name: "Hey Rex Coach", voiceCharacteristics: defaultVoice)
        
        super.init()
        setupSpeechRecognition()
        synthesizer.delegate = self
        setupCoachingPhrases()
    }
    
    // MARK: - Public Interface
    func setCoachingStyle(_ style: CoachingStyle) {
        currentPersonality.style = style
        let voiceChar = premiumVoices[style] ?? currentPersonality.voiceCharacteristics
        currentPersonality.voiceCharacteristics = voiceChar
        print("[Premium Voice] Switched to \(style) coaching style")
    }
    
    func toggleListening() {
        if isInConversation {
            endConversation()
        } else {
            startConversation()
        }
    }
    
    // MARK: - Workout Mode
    func startWorkoutMode(exercise: String) {
        isWorkoutMode = true
        currentExercise = exercise
        workoutContext["exercise"] = exercise
        workoutContext["startTime"] = Date()
        workoutContext["repCount"] = 0
        
        // Ensure wake word detection is always active
        if !isWakeWordActive {
            startWakeWordDetection()
        }
        
        // Speak workout start with premium coaching
        speakWithPersonality("Starting \(exercise). I'm your coach today. Just say 'Hey Rex' anytime you need form help or have questions.", style: .motivational)
    }
    
    func stopWorkoutMode() {
        isWorkoutMode = false
        currentExercise = nil
        workoutContext.removeAll()
        // Don't stop wake word detection - keep it active for seamless experience
    }
    
    // MARK: - Immediate Form Feedback
    func provideFormFeedback(type: String, severity: String = "normal") {
        let now = Date()
        guard now.timeIntervalSince(lastFormFeedbackTime) >= formFeedbackCooldown else { return }
        
        lastFormFeedbackTime = now
        
        var message = formCorrections[type] ?? "Adjust your form"
        
        // Add urgency for bad form
        if severity == "bad" {
            message = "⚠️ " + message
        } else if severity == "good" {
            message = "✅ " + message
        }
        
        speakWithPersonality(message, style: .technical)
    }
    
    func speakRepCount(_ count: Int) {
        // Update workout context
        workoutContext["repCount"] = count
        
        let message = "Great rep \(count)! Keep that form up!"
        speakWithPersonality(message, style: .technical)
    }
    
    func speakWorkoutComplete() {
        let repCount = workoutContext["repCount"] as? Int ?? 0
        let message = "Amazing workout! You completed \(repCount) perfect reps. You crushed it today!"
        speakWithPersonality(message, style: .technical)
    }
    

    
    // MARK: - Premium Speech Synthesis
    func speakWithPersonality(_ text: String, style: CoachingStyle? = nil) {
        let targetStyle = style ?? currentPersonality.style
        let voiceChar = premiumVoices[targetStyle] ?? currentPersonality.voiceCharacteristics
        
        print("[Premium Speech] Speaking with \(targetStyle) style: \(text)")
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("[Premium Speech] Stopped current speech")
        }
        
        // Configure audio session for premium playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voicePrompt, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[Premium Speech] Audio session configured with speaker priority")
        } catch {
            print("[Premium Speech] ❌ Audio session error: \(error.localizedDescription)")
            // Fallback: Try simpler configuration
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try audioSession.setActive(true)
                print("[Premium Speech] ✅ Fallback audio session configured")
            } catch {
                print("[Premium Speech] ❌ Fallback audio session also failed: \(error.localizedDescription)")
            }
        }
        
        // Create premium utterance with humanized settings
        let utterance = AVSpeechUtterance(string: text)
        
        // Apply humanized voice characteristics
        utterance.rate = voiceChar.rate
        utterance.volume = voiceChar.volume
        utterance.pitchMultiplier = voiceChar.pitch
        
        // Add natural pauses for human-like speech
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        
        // Use premium voice if available, with fallback to best quality
        if let voice = AVSpeechSynthesisVoice(identifier: voiceChar.voiceIdentifier) {
            utterance.voice = voice
            print("[Premium Speech] Using premium voice: \(voice.name)")
        } else {
            // Fallback to highest quality available voice
            let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
            utterance.voice = voices.first { $0.quality == .enhanced } ?? 
                             voices.first { $0.quality == .default } ??
                             AVSpeechSynthesisVoice(language: "en-US")
            print("[Premium Speech] Using fallback voice: \(utterance.voice?.name ?? "default")")
        }
        
        // Set delegate for callbacks
        synthesizer.delegate = self
        
        // Start premium speech
        print("[Premium Speech] Starting premium speech synthesis...")
        synthesizer.speak(utterance)
        print("[Premium Speech] ✅ Premium speech initiated for: '\(text)'")
    }
    
    // MARK: - Legacy Speech Method (Compatibility)
    private func speakImmediately(_ text: String) {
        // Redirect to premium speech system for consistency
        speakWithPersonality(text, style: .supportive)
    }
    
    // MARK: - Premium Coaching Phrases Setup
    private func setupCoachingPhrases() {
        coachingPhrases = [
            "motivational": [
                "Yesss! That's exactly what I want to see!",
                "Holy moly, you're absolutely crushing this!",
                "Beast mode activated! Let's keep this energy going!",
                "Now THAT'S what I call proper effort!",
                "You're making this look way too easy!",
                "Fire! Absolute fire! Keep that intensity!",
                "This is how champions are made, right here!",
                "You just leveled up! I can see the difference!"
            ],
            "technical": [
                "Think about driving through your heels here",
                "Keep that chest up and core tight",
                "Really focus on that hip hinge pattern",
                "Control the way down, power on the way up",
                "Your knees should track right over your toes",
                "Take a deep breath and brace that core",
                "Feel that stretch in your glutes at the bottom",
                "Mind-muscle connection is everything here"
            ],
            "supportive": [
                "Really nice form, you're getting the hang of this",
                "Great depth on that one, well done",
                "That's your best rep yet, I can tell",
                "You're making solid progress, keep it up",
                "Perfect technique right there",
                "You're building real functional strength",
                "That's exactly how it should feel",
                "You're definitely getting stronger each session"
            ],
            "professional": [
                "Maintain neutral spine position",
                "Execute the movement with proper form",
                "Focus on controlled eccentric phase",
                "Maintain proper breathing pattern",
                "Ensure full range of motion",
                "Keep your core engaged throughout",
                "Maintain proper joint alignment",
                "Execute with precision and control"
            ]
        ]
    }
    
    // MARK: - Context-Aware Response Generation
    private func generateContextualResponse(context: CoachingContext, formAnalysis: [String: Any]? = nil) -> String {
        switch context {
        case .exerciseSetup:
            return getRandomPhrase(for: .supportive) + " Ready to crush this workout?"
        case .activeForm:
            if let analysis = formAnalysis {
                return generateFormFeedback(analysis: analysis)
            }
            return getRandomPhrase(for: .motivational)
        case .restPeriod:
            return getRandomPhrase(for: .supportive) + " Take a breath, you're doing great."
        case .sessionComplete:
            return "Incredible work today! You're building something special."
        case .generalChat:
            return getRandomPhrase(for: .supportive)
        }
    }
    
    private func getRandomPhrase(for style: CoachingStyle) -> String {
        let styleKey = String(describing: style)
        let phrases = coachingPhrases[styleKey] ?? ["Great work!"]
        return phrases.randomElement() ?? "Keep it up!"
    }
    
    private func generateFormFeedback(analysis: [String: Any]) -> String {
        // This will be enhanced with actual form analysis
        return getRandomPhrase(for: .technical)
    }
    
    // MARK: - Enhanced OpenAI Integration
    private func processWithOpenAI(_ userInput: String) {
        print("[OpenAI] Processing: \(userInput)")
        
        // Use the unified OpenAI client
        OpenAIClient.shared.sendMessage(prompt: userInput) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("[OpenAI] ✅ Response: \(response)")
                    
                    // Update UI
                    self?.feedbackMessage = response
                    
                    // Speak the response using premium voice
                    self?.speakWithPersonality(response, style: .supportive)
                    
                    // Clear message after speaking
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        if self?.feedbackMessage == response {
                            self?.feedbackMessage = nil
                        }
                    }
                    
                case .failure(let error):
                    print("[OpenAI] ❌ Error: \(error)")
                    self?.speakWithPersonality("I'm having trouble processing your request right now. Please try again.", style: .supportive)
                }
            }
        }
    }
    
    // MARK: - Wake Word
    func startWakeWordDetection() {
        guard let keywordPath = Bundle.main.path(forResource: "Hey-Rex_en_ios_v3_0_0", ofType: "ppn") else {
            print("[Wake Word] ❌ Hey Rex wake word model not found")
            return
        }
        
        print("[Wake Word] ✅ Found Hey Rex wake word model at: \(keywordPath)")
        do {
            porcupineManager = try PorcupineManager(
                accessKey: "93LqowKUjtFKhB/AUeeGI529BXWBKCA5tgs8E3pGEsB92reoD6lO2A==",
                keywordPath: keywordPath,
                onDetection: { [weak self] _ in
                    print("[Wake Word] 🎯 Hey Rex detected!")
                    DispatchQueue.main.async {
                        print("[Wake Word] Processing wake word detection...")
                        // Wait 3 seconds after "Hey Rex" before responding
                        if self?.isInConversation == false {
                            print("[Wake Word] Starting new conversation with 3-second delay...")
                            self?.feedbackMessage = "Hey Rex heard... (waiting 3 seconds)"
                            self?.isListening = true
                            
                            // Wait 3 seconds before responding (in case user is still speaking)
                            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.postWakeWordDelay ?? 3.0)) {
                                print("[Wake Word] 3-second delay complete, now responding...")
                                self?.speakWithPersonality("I'm here to coach you. What's your focus today?", style: .supportive)
                                self?.feedbackMessage = "Coach is listening..."
                                
                                // Start listening after speech completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    print("[Wake Word] Starting speech recognition...")
                            self?.startConversation()
                                }
                            }
                        } else {
                            print("[Wake Word] Already in conversation, resetting timeout...")
                            self?.resetConversationTimeout()
                        }
                    }
                }
            )
            if let manager = porcupineManager {
                try manager.start()
                isWakeWordActive = true
                print("[Wake Word] ✅ Wake word detection started successfully!")
            } else {
                print("[Wake Word] ❌ PorcupineManager is nil!")
            }
        } catch {
            print("Failed to start wake word detection: \(error)")
        }
    }
    
    func stopWakeWordDetection() {
        do {
            try porcupineManager?.stop()
            isWakeWordActive = false
            print("Wake word detection stopped (global)")
        } catch {
            print("Failed to stop wake word detection: \(error)")
        }
    }
    
    // MARK: - Conversation
    private func startConversation() {
        isInConversation = true
        resetConversationTimeout()
        startSpeechRecognition()
    }
    
    private func resetConversationTimeout() {
        conversationTimeoutTimer?.invalidate()
        conversationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: conversationTimeout, repeats: false) { [weak self] _ in
            self?.endConversation()
        }
    }
    
    private func endConversation() {
        isInConversation = false
        stopSpeechRecognition()
        conversationTimeoutTimer?.invalidate()
        conversationTimeoutTimer = nil
    }
    
    // MARK: - Speech Recognition
    private func setupSpeechRecognition() {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            SFSpeechRecognizer.requestAuthorization { status in
                // Handle status if needed
            }
            return
        }
        initializeSpeechRecognizer()
    }
    
    private func initializeSpeechRecognizer() {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else { return }
        recognizer.defaultTaskHint = .dictation
        self.speechRecognizer = recognizer
    }
    
    private func startSpeechRecognition() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            feedbackMessage = "Speech recognition is not available"
            return
        }
        
        // Prevent multiple simultaneous recognition sessions
        if isProcessingSpeech {
            return
        }
        
        stopSpeechRecognition()
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // First, deactivate the current session
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Configure for both recording and playback
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            
            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("[Speech] Audio session configured successfully for speech recognition")
        } catch {
            feedbackMessage = "Failed to set up audio session"
            print("[Speech] Audio session setup failed: \(error)")
            isProcessingSpeech = false
            stopSpeechRecognition()
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            feedbackMessage = "Unable to create recognition request"
            print("[Speech] Unable to create recognition request")
            isProcessingSpeech = false
            stopSpeechRecognition()
            return
        }
        
        // Disable on-device recognition to avoid errors
        recognitionRequest.requiresOnDeviceRecognition = false
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        var lastTranscription = ""
        var hasReceivedPartialResult = false
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                // Only log non-common errors
                if !error.localizedDescription.contains("No speech detected") && 
                   !error.localizedDescription.contains("kAFAssistantErrorDomain") {
                    print("[Speech] Recognition error: \(error.localizedDescription)")
                }
                
                DispatchQueue.main.async {
                    self.isListening = false
                    self.isProcessingSpeech = false
                    self.stopSpeechRecognition()
                    
                    // Only show error message for significant errors
                    if !error.localizedDescription.contains("No speech detected") {
                        self.feedbackMessage = "Try again"
                    }
                }
                return
            }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                if !text.isEmpty {
                    lastTranscription = text
                    hasReceivedPartialResult = true
                    
                    // Cancel conversation timeout since user is speaking
                    self.conversationTimeoutTimer?.invalidate()
                    print("[Conversation] User started speaking, conversation timeout cancelled")
                }
                
                if result.isFinal {
                    self.speechTimeoutTimer?.invalidate()
                    DispatchQueue.main.async {
                        self.isListening = false
                        self.isProcessingSpeech = false
                        self.stopSpeechRecognition()
                        
                        if !text.isEmpty {
                            self.feedbackMessage = "Processing..."
                            self.processWithOpenAI(text)
                        } else if hasReceivedPartialResult {
                            // Use partial result if final is empty
                            self.feedbackMessage = "Processing..."
                            self.processWithOpenAI(lastTranscription)
                        } else {
                            self.feedbackMessage = "Didn't catch that. Try again."
                        }
                    }
                    return
                }
                
                // Reset timeout timer for partial results
                self.speechTimeoutTimer?.invalidate()
                self.speechTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.speechPauseTimeout, repeats: false) { _ in
                    DispatchQueue.main.async {
                        self.isListening = false
                        self.isProcessingSpeech = false
                        self.stopSpeechRecognition()
                        
                        if !lastTranscription.isEmpty {
                            self.feedbackMessage = "Processing..."
                            self.processWithOpenAI(lastTranscription)
                        } else {
                            self.feedbackMessage = "Didn't catch that. Try again."
                        }
                    }
                }
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
                self.isProcessingSpeech = true
                self.feedbackMessage = "Listening..."
                print("[Speech] Speech recognition started, audio engine running.")
            }
        } catch {
            feedbackMessage = "Failed to start audio engine"
            print("[Speech] Failed to start audio engine: \(error)")
            isProcessingSpeech = false
            stopSpeechRecognition()
        }
    }
    
    private func stopSpeechRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        speechTimeoutTimer?.invalidate()
        speechTimeoutTimer = nil
        
        // Don't deactivate the audio session here - let the playback methods handle it
        DispatchQueue.main.async {
            self.isListening = false
            self.isProcessingSpeech = false
        }
    }
    
    // MARK: - Removed Duplicate Methods
    // All speech and OpenAI handling now goes through the premium system above
    

}

// Add AVSpeechSynthesizerDelegate to auto-resume listening after speaking
extension VoiceAssistantManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("[Audio] Started speaking: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("[Audio] Finished speaking: \(utterance.speechString)")
        print("[Conversation] Starting 3-second listening window for follow-up...")
        
        // After speaking, start listening immediately for follow-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.aiResponse = nil
            if self.isInConversation {
                self.feedbackMessage = "Listening for 3 seconds..."
                self.startSpeechRecognition()
                
                // Set timer to end conversation after 3 seconds of silence
                self.resetConversationTimeout()
                self.conversationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.postResponseListeningTime, repeats: false) { _ in
                    print("[Conversation] 3-second listening window expired, ending conversation")
                    self.endConversation()
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("[Audio] Cancelled speaking: \(utterance.speechString)")
    }
} 