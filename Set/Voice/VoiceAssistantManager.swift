import Foundation
import Combine
import Porcupine
import Speech
import AVFoundation
import SwiftUI

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
    private let conversationTimeout: TimeInterval = 20.0 // Shorter timeout
    private var isInConversation = false
    private var lastFormFeedbackTime: Date = Date()
    private let formFeedbackCooldown: TimeInterval = 2.0 // Prevent spam
    private var workoutContext: [String: Any] = [:]
    private var isProcessingSpeech = false // Prevent multiple simultaneous processing
    
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

        // Push-ups
        "pushups_elbowAngle_bad": "Aim for 90 degrees at your elbows.",
        "pushups_bodyAlignmentAngle_bad": "Keep your body in a straight line.",

        // Lunges
        "lunges_frontKneeAngle_bad": "Your front knee should be at a 90-degree angle.",
        "lunges_backKneeAngle_bad": "Lower your back knee closer to the ground.",
        
        // Plank
        "plank_bodyAlignmentAngle_bad": "Keep your hips level with your shoulders. Don't sag!"
    ]
    
    private(set) var conversationHistory: [[String: String]] = [
        ["role": "system", "content": "You are PeakSet, an elite AI fitness coach. Be FAST, DIRECT, and EFFICIENT. Keep responses under 2 sentences unless absolutely necessary. Be brutally honest but supportive. Use gym slang and be relatable. Create instant connections through shared fitness passion. No fluff, no generic advice. Be the coach everyone wants - knowledgeable, real, and motivating. If someone's form sucks, tell them straight. If they're crushing it, hype them up. Always actionable advice. Remember: speed and authenticity over perfection."]
    ]
    
    override init() {
        super.init()
        setupSpeechRecognition()
        synthesizer.delegate = self
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
        
        // Speak workout start with clear instructions
        speakImmediately("Starting \(exercise). I'm listening for 'Hey Coach' - just say it anytime you need help with form or have questions.")
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
        
        speakImmediately(message)
    }
    
    func speakRepCount(_ count: Int) {
        // Update workout context
        workoutContext["repCount"] = count
        
        let message = "Great rep \(count)! Keep that form up!"
        speakImmediately(message)
    }
    
    func speakWorkoutComplete() {
        let repCount = workoutContext["repCount"] as? Int ?? 0
        let message = "Amazing workout! You completed \(repCount) perfect reps. You crushed it today!"
        speakImmediately(message)
    }
    
    // MARK: - Test Audio
    func testAudio() {
        print("[Audio] Testing audio synthesis...")
        
        // Ensure synthesizer is properly configured
        synthesizer.delegate = self
        
        // Test with a simple message
        let utterance = AVSpeechUtterance(string: "Audio test. Can you hear me?")
        utterance.rate = 0.5
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[Audio] Audio session configured for playback")
        } catch {
            print("[Audio] Failed to configure audio session: \(error)")
        }
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - Fast Speech Synthesis
    private func speakImmediately(_ text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Configure audio session for playback with better error handling
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // First, deactivate the current session
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Set category for playback with proper options
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            
            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("[Audio] Audio session configured successfully for playback")
        } catch {
            print("[Speech] Failed to configure audio session for playback: \(error)")
            // Continue anyway - the synthesizer might still work
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Optimize for speed and clarity
        utterance.rate = 0.6 // Even faster
        utterance.pitchMultiplier = 1.1 // Slightly higher pitch for clarity
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.01 // Minimal delay
        utterance.postUtteranceDelay = 0.02 // Minimal delay
        
        // Use enhanced voice if available
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let preferredVoice = voices.first {
            $0.identifier.contains("com.apple.ttsbundle.Siri") && $0.language == "en-US"
        } ?? voices.first {
            $0.quality == .enhanced && $0.language == "en-US"
        } ?? AVSpeechSynthesisVoice(language: "en-US")
        
        utterance.voice = preferredVoice
        
        synthesizer.speak(utterance)
        
        // Update UI
        DispatchQueue.main.async {
            self.feedbackMessage = text
            self.aiResponse = text
        }
    }
    
    // MARK: - Wake Word
    func startWakeWordDetection() {
        guard let keywordPath = Bundle.main.path(forResource: "Hey-Coach_en_ios_v3_0_0", ofType: "ppn") else {
            print("Wake word model not found")
            return
        }
        do {
            porcupineManager = try PorcupineManager(
                accessKey: "93LqowKUjtFKhB/AUeeGI529BXWBKCA5tgs8E3pGEsB92reoD6lO2A==",
                keywordPath: keywordPath,
                onDetection: { [weak self] _ in
                    print("Wake word detected!")
                    DispatchQueue.main.async {
                        if self?.isInConversation == false {
                            self?.startConversation()
                        } else {
                            self?.resetConversationTimeout()
                        }
                    }
                }
            )
            if let manager = porcupineManager {
                try manager.start()
                isWakeWordActive = true
                print("Wake word detection started (global)")
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
                }
                
                if result.isFinal {
                    self.speechTimeoutTimer?.invalidate()
                    DispatchQueue.main.async {
                        self.isListening = false
                        self.isProcessingSpeech = false
                        self.stopSpeechRecognition()
                        
                        if !text.isEmpty {
                            self.feedbackMessage = "Processing..."
                            self.handleRecognizedText(text)
                        } else if hasReceivedPartialResult {
                            // Use partial result if final is empty
                            self.feedbackMessage = "Processing..."
                            self.handleRecognizedText(lastTranscription)
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
                            self.handleRecognizedText(lastTranscription)
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
    
    private func handleRecognizedText(_ text: String) {
        self.feedbackMessage = "Processing..."
        let userMessage = text
        
        // Add workout context if in workout mode
        var enhancedMessage = userMessage
        if isWorkoutMode, let exercise = currentExercise {
            enhancedMessage = "I'm doing \(exercise). \(userMessage)"
        }
        
        conversationHistory.append(["role": "user", "content": enhancedMessage])
        sendToOpenAI(conversation: conversationHistory) { response in
            DispatchQueue.main.async {
                self.conversationHistory.append(["role": "assistant", "content": response])
                self.aiResponse = response
                self.feedbackMessage = response
                self.speak(response)
                self.resetConversationTimeout()
            }
        }
    }
    
    private func sendToOpenAI(conversation: [[String: String]], completion: @escaping (String) -> Void) {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.feedbackMessage = "Please add your OpenAI API key in Info.plist"
                completion("API key not found. Please add OPENAI_API_KEY to Info.plist")
            }
            return
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Optimize for faster responses
        let body: [String: Any] = [
            "model": "gpt-4o-mini", // Use faster model
            "messages": conversation,
            "temperature": 0.8, // Slightly higher for more personality
            "max_tokens": 40, // Even shorter for speed
            "presence_penalty": 0.0, // Remove penalties for faster responses
            "frequency_penalty": 0.0,
            "top_p": 0.9 // Focus on most likely responses
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            DispatchQueue.main.async {
                self.feedbackMessage = "Error preparing request"
                completion("Failed to prepare request")
            }
            return
        }
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.feedbackMessage = "Network error"
                    completion("Network error: \(error.localizedDescription)")
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.feedbackMessage = "No response received"
                    completion("No data received from server")
                }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async {
                        completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } else {
                    throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                }
            } catch {
                DispatchQueue.main.async {
                    self.feedbackMessage = "Error processing response"
                    completion("Failed to process response: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
    
    private func speak(_ text: String) {
        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[Speech] Failed to configure audio session for playback: \(error)")
        }
        
        // Use Siri/enhanced voice, slow rate, etc. (see previous logic)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let preferredVoice = voices.first {
            $0.identifier.contains("com.apple.ttsbundle.Siri") && $0.language == "en-US"
        } ?? voices.first {
            $0.quality == .enhanced && $0.language == "en-US"
        } ?? AVSpeechSynthesisVoice(language: "en-US")
        if let voice = preferredVoice {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = 0.6 // Even faster speech
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            utterance.preUtteranceDelay = 0.02 // Minimal delay
            utterance.postUtteranceDelay = 0.05 // Minimal delay
            synthesizer.speak(utterance)
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
        // After speaking, auto-resume listening for follow-up (unless view is gone)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Reduced delay
            self.aiResponse = nil
            if self.isInConversation {
                self.startSpeechRecognition()
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("[Audio] Cancelled speaking: \(utterance.speechString)")
    }
} 