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
    private let speechPauseTimeout: TimeInterval = 0.5 // Reduced for more responsive listening
    private var conversationTimeoutTimer: Timer?
    private let conversationTimeout: TimeInterval = 4.0  // Increased to give users more time to speak
    private let postWakeWordDelay: TimeInterval = 2.0  // Wait 2 seconds after "Hey Rex"
    private let postResponseListeningTime: TimeInterval = 4.0  // Listen for 4 seconds after response to allow natural conversation
    private var isInConversation = false
    private var isInCheckInPhase = false // Track if we're in the check-in phase

    private var workoutContext: [String: Any] = [:]
    private var isProcessingSpeech = false // Prevent multiple simultaneous processing
    private var isProcessingWakeWord = false // Prevent duplicate wake word processing
    
    // MARK: - Premium Voice AI Properties
    private var currentContext: CoachingContext = .generalChat
    private var currentPersonality: CoachingPersonality
    
    // Premium voice characteristics - Humanized female voices to match Rex
    private let premiumVoices: [CoachingStyle: LegacyVoiceCharacteristics] = [
        .motivational: LegacyVoiceCharacteristics(rate: 0.50, pitch: 1.15, volume: 1.0, voiceIdentifier: "com.apple.ttsbundle.Samantha-compact"),
        .technical: LegacyVoiceCharacteristics(rate: 0.55, pitch: 1.0, volume: 1.0, voiceIdentifier: "com.apple.voice.compact.en-US.Zoe"),
        .supportive: LegacyVoiceCharacteristics(rate: 0.52, pitch: 1.08, volume: 1.0, voiceIdentifier: "com.apple.ttsbundle.Samantha-compact"),
        .professional: LegacyVoiceCharacteristics(rate: 0.58, pitch: 0.98, volume: 1.0, voiceIdentifier: "com.apple.voice.compact.en-US.Allison")
    ]
    

    
    // Conversation history removed - now handled by individual processWithOpenAI calls
    
    override init() {
        // Initialize with supportive personality by default - using female voice to match Rex
        let defaultVoice = LegacyVoiceCharacteristics(rate: 0.52, pitch: 1.08, volume: 1.0, voiceIdentifier: "com.apple.ttsbundle.Samantha-compact")
        currentPersonality = CoachingPersonality(style: .supportive, name: "Hey Rex Coach", voiceCharacteristics: defaultVoice)
        
        super.init()
        setupSpeechRecognition()
        synthesizer.delegate = self
        // startWakeWordDetection() - moved to SetApp.swift to prevent duplicate calls
        
        // Listen for ElevenLabs speech completion to start conversation flow
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleElevenLabsSpeechFinished),
            name: .elevenLabsSpeechFinished,
            object: nil
        )
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
    

    

    
    // MARK: - Professional Speech Synthesis with ElevenLabs
    func speakWithPersonality(_ text: String, style: CoachingStyle? = nil) {
        let targetStyle = style ?? currentPersonality.style
        
        print("🎤 [PRIORITY] ElevenLabs Rex voice (PREMIUM) speaking with \(targetStyle) style: \(text)")
        
        // PRIORITY: ElevenLabs is PREMIUM - must exhaust ALL possibilities before Apple TTS
        ElevenLabsVoiceManager.shared.speak(text, style: targetStyle) { [weak self] success in
            if success {
                print("✅ [PREMIUM SUCCESS] ElevenLabs Rex voice delivered perfectly: '\(text)'")
            } else {
                // ElevenLabs failed after ALL its internal retries - this is serious
                print("💔 [PREMIUM FAILED] ElevenLabs exhausted ALL attempts - network/API critical failure")
                print("🔄 [LAST RESORT] Attempting final ElevenLabs recovery before fallback...")
                
                // Give ElevenLabs one final chance with longer delay for network recovery
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ElevenLabsVoiceManager.shared.speak(text, style: targetStyle) { [weak self] finalSuccess in
                        if finalSuccess {
                            print("🎉 [MIRACLE RECOVERY] ElevenLabs final attempt successful - Rex voice saved!")
                        } else {
                            // ONLY NOW fallback to Apple TTS - ElevenLabs truly unavailable
                            print("😞 [EMERGENCY FALLBACK] ElevenLabs completely unavailable - switching to backup voice")
                            self?.fallbackToAppleTTSWithMessage(text, style: targetStyle)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Fallback to Apple TTS
    
    /// Enhanced fallback with seamless transition messaging
    private func fallbackToAppleTTSWithMessage(_ text: String, style: CoachingStyle) {
        print("🔄 [EMERGENCY TRANSITION] Preparing seamless switch to backup voice system...")
        
        // First, provide seamless transition with a brief message if it's a long text
        let isLongMessage = text.count > 50
        if isLongMessage {
            // For longer messages, give a brief transition
            let transitionMessage = "One moment..."
            fallbackToAppleTTS(transitionMessage, style: style)
            
            // Then deliver the actual message after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.fallbackToAppleTTS(text, style: style)
            }
        } else {
            // For short messages, just deliver directly
            fallbackToAppleTTS(text, style: style)
        }
    }
    
    private func fallbackToAppleTTS(_ text: String, style: CoachingStyle) {
        let voiceChar = premiumVoices[style] ?? currentPersonality.voiceCharacteristics
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("[Fallback TTS] Stopped current speech")
        }
        
        // Configure audio session
        do {
            try AudioSessionManager.shared.configureForPlayback()
        } catch {
            print("[Fallback TTS] ❌ Audio session error: \(error.localizedDescription)")
        }
        
        // Create utterance with Apple TTS
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = voiceChar.rate
        utterance.volume = 1.0  // Force maximum volume for better audibility
        utterance.pitchMultiplier = voiceChar.pitch
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        
        // Try preferred voice first
        if let voice = AVSpeechSynthesisVoice(identifier: voiceChar.voiceIdentifier) {
            utterance.voice = voice
            print("[Fallback TTS] 🎤 Using preferred Rex-like voice: \(voice.name)")
        } else {
            // Fallback to best available female voice to match Rex
            let preferredFemaleVoices = [
                "com.apple.ttsbundle.Samantha-compact",      // Samantha (warm, friendly)
                "com.apple.voice.compact.en-US.Zoe",         // Zoe (clear, professional)
                "com.apple.ttsbundle.siri_female_en-US_compact", // Siri Female
                "com.apple.voice.compact.en-US.Allison",     // Allison (natural)
                "com.apple.ttsbundle.Ava-compact"            // Ava (expressive)
            ]
            
            var fallbackVoice: AVSpeechSynthesisVoice? = nil
            for identifier in preferredFemaleVoices {
                if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                    fallbackVoice = voice
                    print("[Fallback TTS] 🎤 Using fallback Rex-like voice: \(voice.name)")
                    break
                }
            }
            
            // Final fallback to any female voice available
            if fallbackVoice == nil {
                let allVoices = AVSpeechSynthesisVoice.speechVoices()
                fallbackVoice = allVoices.first { voice in
                    voice.language.contains("en") && 
                    (voice.name.lowercased().contains("female") || 
                     voice.name.lowercased().contains("woman") ||
                     voice.identifier.lowercased().contains("female"))
                }
                
                if let voice = fallbackVoice {
                    print("[Fallback TTS] 🎤 Using generic female voice: \(voice.name)")
                }
            }
            
            utterance.voice = fallbackVoice ?? AVSpeechSynthesisVoice(language: "en-US")
            if fallbackVoice == nil {
                print("[Fallback TTS] ⚠️ Using default voice - couldn't find female voice to match Rex")
            }
        }
        
        synthesizer.delegate = self
        synthesizer.speak(utterance)
        print("[Fallback TTS] Using Apple TTS for: '\(text)'")
    }
    

    

    
    // MARK: - Enhanced OpenAI Integration
    private func processWithOpenAI(_ userInput: String) {
        print("[OpenAI] Processing: \(userInput)")
        
        // Determine coaching style based on user input and context
        let coachingStyle = determineCoachingStyle(for: userInput)
        print("[Context] Using \(coachingStyle) style for: \(userInput)")
        
        // Use the unified OpenAI client
        OpenAIClient.shared.sendMessage(prompt: userInput) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("[OpenAI] ✅ Response: \(response)")
                    
                    // Update UI
                    self?.feedbackMessage = response
                    
                    // Speak the response using the determined coaching style
                    self?.speakWithPersonality(response, style: coachingStyle)
                    
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
    
    // MARK: - Smart Context Detection
    private func determineCoachingStyle(for userInput: String) -> CoachingStyle {
        let input = userInput.lowercased()
        
        // Check for form-related questions
        if input.contains("form") || input.contains("technique") || input.contains("how to") || input.contains("proper") {
            return .technical
        }
        
        // Check for motivational requests
        if input.contains("motivate") || input.contains("pump") || input.contains("energy") || input.contains("fire") {
            return .motivational
        }
        
        // Check for workout planning or professional advice
        if input.contains("program") || input.contains("routine") || input.contains("plan") || input.contains("schedule") {
            return .professional
        }
        
        // Check if user is struggling or needs support
        if input.contains("tired") || input.contains("hard") || input.contains("difficult") || input.contains("help") {
            return .supportive
        }
        
        // Check current workout context
        if isWorkoutMode {
            if currentExercise?.lowercased().contains("squat") == true || currentExercise?.lowercased().contains("deadlift") == true {
                return .technical // More technical for complex lifts
            } else {
                return .motivational // More motivational for general workouts
            }
        }
        
        // Default to supportive for general conversation
        return .supportive
    }
    
    // MARK: - Contextual Greetings
    private func getContextualGreeting() -> String {
        if isWorkoutMode {
            if let exercise = currentExercise {
                return "Ready to crush those \(exercise)? I'm here to coach you through every rep!"
            } else {
                return "Workout mode activated! What are we working on today?"
            }
        }
        
        // Check time of day for personalized greeting
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning! I'm here to help with whatever fitness or health questions you have. What's on your mind?"
        } else if hour < 17 {
            return "Good afternoon! Whether it's workout advice, nutrition tips, or health questions, I'm here to help. What do you need?"
        } else {
            return "Good evening! Ready to tackle any fitness or health questions you have. What can I help you with?"
        }
    }
    
    // MARK: - Wake Word
    func startWakeWordDetection() {
        // Prevent multiple wake word detection sessions
        if porcupineManager != nil && isWakeWordActive {
            print("[Wake Word] ⚠️ Wake word detection already active, skipping...")
            return
        }
        
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
                    // Prevent duplicate wake word processing
                    guard let self = self, !self.isProcessingWakeWord else {
                        print("[Wake Word] ⚠️ Wake word already being processed, ignoring...")
                        return
                    }
                    
                    self.isProcessingWakeWord = true
                    print("[Wake Word] 🎯 Hey Rex detected!")
                    
                    DispatchQueue.main.async {
                        print("[Wake Word] Processing wake word detection...")
                        // Wait 2 seconds after "Hey Rex" before responding
                        if self.isInConversation == false {
                            print("[Wake Word] Starting new conversation with 2-second delay...")
                            self.feedbackMessage = "Hey Rex heard... (waiting 2 seconds)"
                            self.isListening = true
                            
                            // Wait 2 seconds before responding (in case user is still speaking)
                            DispatchQueue.main.asyncAfter(deadline: .now() + (self.postWakeWordDelay)) {
                                print("[Wake Word] 2-second delay complete, now responding...")
                                
                                // Choose greeting based on context
                                let greeting = self.getContextualGreeting()
                                self.speakWithPersonality(greeting, style: .supportive)
                                self.feedbackMessage = "Coach is listening..."
                                
                                // Mark that we're in a conversation - listening will start automatically after speech
                                self.isInConversation = true
                                
                                // Reset wake word processing flag
                                self.isProcessingWakeWord = false
                            }
                        } else {
                            print("[Wake Word] Already in conversation, resetting timeout...")
                            self.resetConversationTimeout()
                            self.isProcessingWakeWord = false
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
        isInCheckInPhase = false
        stopSpeechRecognition()
        conversationTimeoutTimer?.invalidate()
        conversationTimeoutTimer = nil
        
        // Deactivate audio session to clean up
        AudioSessionManager.shared.deactivate()
    }
    
    private func checkInWithUser() {
        print("[Conversation] Checking in with user...")
        
        // Stop current listening
        stopSpeechRecognition()
        
        // Mark that we're in check-in phase
        isInCheckInPhase = true
        
        // Ask if there's anything else
        let checkInMessage = "Is there anything else I can help you with?"
        self.feedbackMessage = "Checking in..."
        
        // Speak the check-in message
        speakWithPersonality(checkInMessage, style: .supportive)
        
        // After speaking, wait longer before starting final listening window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.feedbackMessage = "Listening for final response..."
            self.startSpeechRecognition()
            
            // Set timer to end conversation after 4 seconds (more generous)
            self.conversationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.postResponseListeningTime, repeats: false) { _ in
                print("[Conversation] Final 4-second window expired, ending conversation")
                self.endConversation()
            }
        }
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
            print("[Speech] Already processing speech, skipping...")
            return
        }
        
        print("[Speech] Starting speech recognition...")
        stopSpeechRecognition()
        
        // Add longer delay to ensure audio session is ready after ElevenLabs playback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            do {
                // Use centralized audio session manager with retry
                try AudioSessionManager.shared.configureForRecording()
                
                print("[Speech] Audio session configured successfully for speech recognition")
                
                // Continue with speech recognition setup
                self.setupSpeechRecognitionImplementation()
                
            } catch {
                print("[Speech] Audio session setup failed: \(error), attempting recovery...")
                
                // Try to recover audio session with multiple attempts
                self.attemptAudioSessionRecovery(attempt: 1)
            }
        }
    }
    
    private func attemptAudioSessionRecovery(attempt: Int) {
        let maxAttempts = 3
        
        guard attempt <= maxAttempts else {
            print("[Speech] Audio session recovery exhausted all attempts")
            self.feedbackMessage = "Failed to set up audio session after multiple attempts"
            self.isProcessingSpeech = false
            self.stopSpeechRecognition()
            return
        }
        
        print("[Speech] Audio session recovery attempt \(attempt)/\(maxAttempts)")
        
        // Force reset audio session
        AudioSessionManager.shared.forceReset()
        
        // Wait progressively longer between attempts
        let delay = TimeInterval(attempt) * 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            do {
                try AudioSessionManager.shared.configureForRecording()
                print("[Speech] Audio session recovery successful on attempt \(attempt)")
                self.setupSpeechRecognitionImplementation()
            } catch {
                print("[Speech] Audio session recovery failed on attempt \(attempt): \(error)")
                self.attemptAudioSessionRecovery(attempt: attempt + 1)
            }
        }
    }
        
    private func setupSpeechRecognitionImplementation() {
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
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
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
                            // If we're in check-in phase and user responds, continue conversation
                            if self.isInCheckInPhase {
                                self.isInCheckInPhase = false
                                print("[Conversation] User responded during check-in, continuing conversation...")
                            }
                            self.processWithOpenAI(text)
                        } else if hasReceivedPartialResult {
                            // Use partial result if final is empty
                            self.feedbackMessage = "Processing..."
                            // If we're in check-in phase and user responds, continue conversation
                            if self.isInCheckInPhase {
                                self.isInCheckInPhase = false
                                print("[Conversation] User responded during check-in, continuing conversation...")
                            }
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
        
        // Set up audio engine for recording with better error handling
        let inputNode = audioEngine.inputNode
        
        // Get the actual hardware format from the input node
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        print("[Speech] Hardware format - Sample Rate: \(hardwareFormat.sampleRate), Channels: \(hardwareFormat.channelCount), Format: \(hardwareFormat)")
        
        // For iOS Simulator or invalid hardware, we need to use a completely different approach
        var recordingFormat: AVAudioFormat
        
        if hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 {
            // Real device with valid hardware format
            recordingFormat = hardwareFormat
            print("[Speech] ✅ Using hardware format: \(recordingFormat)")
        } else {
            // iOS Simulator or invalid hardware - use a format that actually works
            print("[Speech] 🎭 iOS Simulator detected - using compatible format")
            
            // Try multiple formats that work with the simulator
            let compatibleFormats = [
                AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
                AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1),
                AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)
            ]
            
            var foundFormat: AVAudioFormat? = nil
            for format in compatibleFormats {
                if let fmt = format {
                    foundFormat = fmt
                    print("[Speech] ✅ Using compatible format: \(fmt)")
                    break
                }
            }
            
            guard let safeFormat = foundFormat else {
                print("[Speech] ❌ Could not create any compatible audio format")
                feedbackMessage = "Audio system not ready"
                isProcessingSpeech = false
                stopSpeechRecognition()
                return
            }
            
            recordingFormat = safeFormat
        }
        
        // Ensure the audio engine is in a clean state
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        
        // Wait for audio engine to be ready
        Thread.sleep(forTimeInterval: 0.2)
        
        // Remove any existing taps
        inputNode.removeTap(onBus: 0)
        
        // Create a proper format for speech recognition (16kHz mono)
        let speechFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)
        guard let validSpeechFormat = speechFormat else {
            print("[Speech] ❌ Could not create valid speech format")
            feedbackMessage = "Audio format creation failed"
            isProcessingSpeech = false
            stopSpeechRecognition()
            return
        }
        
                    // Install tap with simplified format handling
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self, let recognitionRequest = self.recognitionRequest else { return }
                
                // For iOS Simulator, we need to handle the case where the buffer might be empty or invalid
                if buffer.frameLength == 0 {
                    print("[Speech] ⚠️ Empty buffer received, skipping")
                    return
                }
                
                // Try to convert to speech format, but fallback gracefully
                if recordingFormat.sampleRate != 16000 || recordingFormat.channelCount != 1 {
                    // Create converter
                    guard let converter = AVAudioConverter(from: recordingFormat, to: validSpeechFormat) else {
                        print("[Speech] ⚠️ Converter creation failed, using original buffer")
                        recognitionRequest.append(buffer)
                        return
                    }
                    
                    // Calculate frame capacity
                    let ratio = validSpeechFormat.sampleRate / recordingFormat.sampleRate
                    let convertedFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                    
                    // Create converted buffer
                    guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: validSpeechFormat, frameCapacity: convertedFrameCapacity) else {
                        print("[Speech] ⚠️ Converted buffer creation failed, using original buffer")
                        recognitionRequest.append(buffer)
                        return
                    }
                    
                    // Convert with proper error handling
                    var error: NSError?
                    let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                        outStatus.pointee = .haveData
                        return buffer
                    }
                    
                    converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                    
                    if error == nil {
                        recognitionRequest.append(convertedBuffer)
                        print("[Speech] ✅ Buffer converted successfully")
                    } else {
                        print("[Speech] ⚠️ Conversion failed: \(error?.localizedDescription ?? "unknown"), using original buffer")
                        recognitionRequest.append(buffer)
                    }
                } else {
                    // Format matches, use directly
                    recognitionRequest.append(buffer)
                    print("[Speech] ✅ Buffer appended directly (format matches)")
                }
            }
        
        do {
            // Prepare and start the audio engine
            audioEngine.prepare()
            
            try audioEngine.start()
            
            // Verify audio engine is running
            guard audioEngine.isRunning else {
                print("[Speech] ❌ Audio engine failed to start")
                feedbackMessage = "Audio system not ready"
                isProcessingSpeech = false
                stopSpeechRecognition()
                return
            }
            
            DispatchQueue.main.async {
                self.isListening = true
                self.isProcessingSpeech = true
                self.feedbackMessage = "Listening..."
                print("[Speech] ✅ Speech recognition started successfully, audio engine running.")
            }
                
        } catch {
            print("[Speech] ❌ Failed to start audio engine: \(error)")
            
            // Try alternative approach for iOS Simulator
            if recordingFormat.sampleRate == 44100 || recordingFormat.sampleRate == 48000 || recordingFormat.sampleRate == 16000 {
                print("[Speech] 🔄 Attempting alternative audio setup for simulator...")
                
                // Reset and try with a different approach
                audioEngine.reset()
                
                // Try to use a simpler format
                if let simpleFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1) {
                    print("[Speech] 🔄 Retrying with simple format: \(simpleFormat)")
                    
                    // Remove existing tap and try again
                    inputNode.removeTap(onBus: 0)
                    
                    // Install tap with simple format
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: simpleFormat) { [weak self] buffer, _ in
                        guard let self = self, let recognitionRequest = self.recognitionRequest else { return }
                        recognitionRequest.append(buffer)
                    }
                    
                    do {
                        audioEngine.prepare()
                        try audioEngine.start()
                        
                        if audioEngine.isRunning {
                            DispatchQueue.main.async {
                                self.isListening = true
                                self.isProcessingSpeech = true
                                self.feedbackMessage = "Listening (simulator mode)..."
                                print("[Speech] ✅ Alternative setup successful for simulator")
                            }
                            return
                        }
                    } catch {
                        print("[Speech] ❌ Alternative setup also failed: \(error)")
                    }
                }
            }
            
            // If all else fails
            feedbackMessage = "Failed to start audio engine"
            isProcessingSpeech = false
            stopSpeechRecognition()
        }
    }
    
    private func stopSpeechRecognition() {
        print("[Speech] Stopping speech recognition...")
        
        // Stop timers first
        speechTimeoutTimer?.invalidate()
        speechTimeoutTimer = nil
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Safely stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            print("[Speech] Audio engine stopped")
        }
        
        // Remove tap safely
        audioEngine.inputNode.removeTap(onBus: 0)
        print("[Speech] Input node tap removed")
        
        // Reset audio engine to clean state
        audioEngine.reset()
        
        // Update UI state
        DispatchQueue.main.async {
            self.isListening = false
            self.isProcessingSpeech = false
        }
        
        print("[Speech] ✅ Speech recognition stopped successfully")
    }
    
    // MARK: - Removed Duplicate Methods
// All speech and OpenAI handling now goes through the premium system above
    

}

// MARK: - Notification Names

extension Notification.Name {
    static let elevenLabsSpeechFinished = Notification.Name("elevenLabsSpeechFinished")
}

// MARK: - Notification Handlers

extension VoiceAssistantManager {
    @objc private func handleElevenLabsSpeechFinished() {
        print("[Conversation] ElevenLabs speech finished, starting conversation flow...")
        
        // Start the conversation flow just like Apple TTS does
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.aiResponse = nil
            if self.isInConversation {
                self.feedbackMessage = "Listening for 2 seconds..."
                self.startSpeechRecognition()
                
                // Set timer to check in after 2 seconds of silence
                self.conversationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.postResponseListeningTime, repeats: false) { _ in
                    print("[Conversation] 2-second listening window expired, checking in with user...")
                    self.checkInWithUser()
                }
            }
        }
    }
}

// Add AVSpeechSynthesizerDelegate to auto-resume listening after speaking
extension VoiceAssistantManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("[Audio] Started speaking: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("[Audio] Finished speaking: \(utterance.speechString)")
        print("[Conversation] Starting 2-second listening window for follow-up...")
        
        // After speaking, start listening immediately for follow-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Reduced delay for faster response
            self.aiResponse = nil
            if self.isInConversation {
                self.feedbackMessage = "Listening for 2 seconds..."
                self.startSpeechRecognition()
                
                // Set timer to check in after 2 seconds of silence
                self.conversationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.postResponseListeningTime, repeats: false) { _ in
                    print("[Conversation] 2-second listening window expired, checking in with user...")
                    self.checkInWithUser()
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("[Audio] Cancelled speaking: \(utterance.speechString)")
    }
} 