import Foundation
import Porcupine
import Speech
import AVFoundation

// MARK: - Premium Voice AI System
enum ConversationContext {
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
    private let speechPauseTimeout: TimeInterval = 2.0 // Wait 2 seconds after speech stops before processing
    private var conversationTimeoutTimer: Timer?
    private let conversationTimeout: TimeInterval = 15.0  // Give users more time to speak
    private let postWakeWordDelay: TimeInterval = 0.2  // Faster wake word response
    private let postResponseListeningTime: TimeInterval = 10.0  // Still generous listening time
    private var isInConversation = false
    private var isInCheckInPhase = false // Track if we're in the check-in phase

    private var workoutContext: [String: Any] = [:]
    private var isProcessingSpeech = false // Prevent multiple simultaneous processing
    private var isProcessingWakeWord = false // Prevent duplicate wake word processing
    private var hasLoggedSpeaking = false // Prevent excessive timeout cancellation logs
    private var isAboutToRespond = false // Track if AI is about to respond (can be interrupted)
    
    // MARK: - Premium Voice AI Properties
    private var currentContext: ConversationContext = .generalChat
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
        
        // Notify MirrorViewController to prepare live caption if text is long
        if text.count > 80 {
            NotificationCenter.default.post(
                name: NSNotification.Name("DisplayLiveCaptionNotification"),
                object: nil,
                userInfo: ["text": text]
            )
        }
        
        // Try ElevenLabs first, but fallback quickly if it fails
        ElevenLabsVoiceManager.shared.speak(text, style: targetStyle) { [weak self] success in
            if success {
                print("✅ [PREMIUM SUCCESS] ElevenLabs Rex voice delivered: '\(text)'")
            } else {
                print("⚠️ [FALLBACK] ElevenLabs failed, using Apple TTS for: '\(text)'")
                // Quick fallback to Apple TTS for better reliability
                self?.fallbackToAppleTTS(text, style: targetStyle)
            }
        }
    }
    
    // MARK: - Workout Coaching (Short Cues)
    
    /// Specialized method for workout cues - optimized for short, quick feedback
    func speakWorkoutCue(_ cue: String) {
        // For short cues (< 20 chars), use direct ElevenLabs call with optimized settings
        print("🏋️ [WORKOUT CUE] Speaking: '\(cue)'")
        
        // Use ElevenLabs with workout-optimized settings
        ElevenLabsVoiceManager.shared.speakWorkoutCue(cue) { [weak self] success in
            if !success {
                // Quick fallback to Apple TTS for reliability
                print("⚠️ [FALLBACK] Using Apple TTS for workout cue: '\(cue)'")
                self?.speakWorkoutCueFallback(cue)
            }
        }
    }
    
    private func speakWorkoutCueFallback(_ cue: String) {
        // Ultra-fast Apple TTS for workout cues
        let utterance = AVSpeechUtterance(string: cue)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.6  // Faster for quick cues
        utterance.pitchMultiplier = 1.2  // Higher pitch for energy
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0  // No delay
        utterance.postUtteranceDelay = 0  // No delay
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - Fallback to Apple TTS
    
    /// Simple fallback to Apple TTS
    private func fallbackToAppleTTSWithMessage(_ text: String, style: CoachingStyle) {
        fallbackToAppleTTS(text, style: style)
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
        
        // Add user message to conversation memory
        let userMessage = ChatMessage(
            id: UUID(),
            text: userInput,
            isUser: true,
            type: .response,
            timestamp: Date(),
            context: nil
        )
        ConversationMemory.shared.addMessage(userMessage)
        
        // Check if user is telling us their name
        updateUserProfileFromConversation(userInput: userInput, aiResponse: "")
        
        // Determine coaching style based on user input and context
        let coachingStyle = determineCoachingStyle(for: userInput)
        print("[Context] Using \(coachingStyle) style for: \(userInput)")
        
        // Create user data context with real data
        let userData = createUserDataContext()
        
        // Use the unified OpenAI client with real user data
        OpenAIClient.shared.sendMessage(prompt: userInput, context: nil, userData: userData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("[OpenAI] ✅ Response: \(response)")
                    
                    // Add AI response to conversation memory
                    let aiMessage = ChatMessage(
                        id: UUID(),
                        text: response,
                        isUser: false,
                        type: .response,
                        timestamp: Date(),
                        context: nil
                    )
                    ConversationMemory.shared.addMessage(aiMessage)
                    
                    // Update user profile based on conversation
                    self?.updateUserProfileFromConversation(userInput: userInput, aiResponse: response)
                    
                    // Update UI
                    self?.feedbackMessage = response
                    
                    // Speak the response using the determined coaching style
                    // speakWithPersonality will automatically send live caption notification if needed
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
    
    // MARK: - User Data Context Creation
    private func createUserDataContext() -> UserDataContext {
        // Get comprehensive user profile from UserDefaults (same as UI)
        let userProfileManager = UserProfileManager.shared
        var comprehensiveProfile = userProfileManager.profile
        
        // Override with actual user data from UserDefaults (same as ProfileView)
        comprehensiveProfile.personalInfo.name = UserDefaults.standard.string(forKey: "userName") ?? ""
        comprehensiveProfile.personalInfo.age = UserDefaults.standard.integer(forKey: "userAge") == 0 ? 25 : UserDefaults.standard.integer(forKey: "userAge")
        comprehensiveProfile.personalInfo.height = UserDefaults.standard.double(forKey: "userHeight") == 0 ? 170.0 : UserDefaults.standard.double(forKey: "userHeight")
        comprehensiveProfile.personalInfo.weight = UserDefaults.standard.double(forKey: "userWeight") == 0 ? 70.0 : UserDefaults.standard.double(forKey: "userWeight")
        
        // Get fitness level from UserDefaults
        let fitnessLevelString = UserDefaults.standard.string(forKey: "fitnessLevel") ?? "Intermediate"
        comprehensiveProfile.fitnessProfile.fitnessLevel = FitnessProfile.FitnessLevel(rawValue: fitnessLevelString.lowercased()) ?? .beginner
        
        // Get primary goal from UserDefaults and map to correct enum value
        let primaryGoalString = UserDefaults.standard.string(forKey: "primaryGoal") ?? "Strength"
        switch primaryGoalString {
        case "Strength":
            comprehensiveProfile.fitnessProfile.primaryGoal = .strength
        case "Muscle Building":
            comprehensiveProfile.fitnessProfile.primaryGoal = .muscleGain
        case "Endurance":
            comprehensiveProfile.fitnessProfile.primaryGoal = .endurance
        case "Weight Loss":
            comprehensiveProfile.fitnessProfile.primaryGoal = .weightLoss
        default:
            comprehensiveProfile.fitnessProfile.primaryGoal = .strength
        }
        
        // Get experience level from UserDefaults
        let experienceString = UserDefaults.standard.string(forKey: "experience") ?? "Intermediate"
        comprehensiveProfile.fitnessProfile.experience = FitnessProfile.Experience(rawValue: experienceString.lowercased()) ?? .beginner
        
        // Get workout frequency from UserDefaults
        let frequencyString = UserDefaults.standard.string(forKey: "workoutFrequency") ?? "3x per week"
        switch frequencyString {
        case "1x per week", "2x per week":
            comprehensiveProfile.fitnessProfile.workoutFrequency = .light
        case "3x per week", "4x per week":
            comprehensiveProfile.fitnessProfile.workoutFrequency = .moderate
        case "5x per week", "6x per week":
            comprehensiveProfile.fitnessProfile.workoutFrequency = .intense
        case "7x per week":
            comprehensiveProfile.fitnessProfile.workoutFrequency = .elite
        default:
            comprehensiveProfile.fitnessProfile.workoutFrequency = .moderate
        }
        
        // Get health data from HealthData bridge
        let healthData = HealthData.shared
        
        // Get conversation history with context
        let conversationHistory = ConversationMemory.shared.getRecentMessages(limit: 20)
        
        // Get recent workout sessions
        let recentWorkouts = healthData.recentWorkouts.map { session in
            OpenAIClient.WorkoutSession(
                date: session.date,
                exercises: [session.exerciseName],
                duration: session.duration,
                intensity: session.formScore / 10, // Convert form score to intensity 1-10
                notes: session.notes.isEmpty ? "Form score: \(session.formScore)%" : session.notes
            )
        }
        
        // Get additional HealthKit data
        let healthKitManager = HealthKitManager.shared
        
        // Get AI coach feedback if available
        let aiCoachFeedback = AICoachFeedback()
        
        // Create enhanced UserDataContext with comprehensive data
        let userDataContext = UserDataContext(
            profile: comprehensiveProfile,
            healthData: healthData,
            workoutSessions: recentWorkouts,
            todayCalories: healthKitManager.getTodayCalories(), // Use direct HealthKit data
            todaySteps: healthKitManager.getTodayStepCount(), // Use direct HealthKit data
            todayDistance: healthKitManager.getTodayStepDistance(), // Add distance data
            moveGoal: healthData.moveGoal,
            averageFormScore: healthKitManager.getAverageFormScore(), // Add form score data
            aiCoachFeedback: aiCoachFeedback.feedback, // Add AI coach insights
            conversationHistory: conversationHistory
        )
        
        // Debug: Print the actual data being sent to AI
        print("🤖 AI DATA CONTEXT:")
        print("   - Today's Calories: \(userDataContext.todayCalories)")
        print("   - Today's Steps: \(userDataContext.todaySteps)")
        print("   - Today's Distance: \(userDataContext.todayDistance)")
        print("   - Move Goal: \(userDataContext.moveGoal)")
        print("   - Average Form Score: \(userDataContext.averageFormScore)")
        print("   - Health Data Available: \(userDataContext.healthData != nil)")
        print("   - Workout Sessions: \(userDataContext.workoutSessions.count)")
        
        return userDataContext
    }
    
    // MARK: - Profile Updates from Conversations
    
    private func updateUserProfileFromConversation(userInput: String, aiResponse: String) {
        let userProfileManager = UserProfileManager.shared
        let input = userInput.lowercased()
        
        // Check if user is telling us their name
        if input.contains("my name is") || input.contains("i'm ") || input.contains("i am ") || input.contains("call me") {
            let namePatterns = [
                "my name is (\\w+)",
                "i'm (\\w+)",
                "i am (\\w+)",
                "call me (\\w+)"
            ]
            
            for pattern in namePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(location: 0, length: userInput.utf16.count)
                    if let match = regex.firstMatch(in: userInput, options: [], range: range) {
                        if let nameRange = Range(match.range(at: 1), in: userInput) {
                            let name = String(userInput[nameRange]).capitalized
                            
                            // Update local profile
                            userProfileManager.updateUserName(name)
                            print("👤 VoiceAssistantManager: Detected and updated user name to '\(name)'")
                            
                            // Save to Supabase immediately
                            Task {
                                do {
                                    let profile = userProfileManager.profile.personalInfo
                                    let fitnessProfile = userProfileManager.profile.fitnessProfile
                                    
                                    // Convert types to match Supabase UserProfile
                                    let unitSystem: UnitSystem = .metric // Default to metric
                                    let fitnessLevel: FitnessLevel = {
                                        switch fitnessProfile.experience {
                                        case .beginner: return .beginner
                                        case .intermediate: return .intermediate
                                        case .advanced: return .advanced
                                        }
                                    }()
                                    
                                    let primaryGoal: FitnessGoal = {
                                        switch fitnessProfile.primaryGoal {
                                        case .weightLoss: return .weightLoss
                                        case .muscleGain: return .muscle
                                        case .strength: return .strength
                                        case .endurance: return .endurance
                                        case .flexibility: return .general
                                        case .generalFitness: return .general
                                        case .sportsPerformance: return .general
                                        case .rehabilitation: return .general
                                        }
                                    }()
                                    
                                    let experience: ExperienceLevel = {
                                        switch fitnessProfile.experience {
                                        case .beginner: return .beginner
                                        case .intermediate: return .intermediate
                                        case .advanced: return .advanced
                                        }
                                    }()
                                    
                                    let workoutFrequency: WorkoutFrequency = {
                                        switch fitnessProfile.workoutFrequency {
                                        case .light: return .twoTimesPerWeek
                                        case .moderate: return .threeTimesPerWeek
                                        case .intense: return .fivePlusTimesPerWeek
                                        case .elite: return .fivePlusTimesPerWeek
                                        }
                                    }()
                                    
                                    let userProfile = SupabaseUserProfile(
                                        name: name,
                                        email: "", // No email from Sign in with Apple
                                        height: profile.height,
                                        weight: profile.weight,
                                        age: profile.age,
                                        unitSystem: unitSystem,
                                        fitnessLevel: fitnessLevel,
                                        primaryGoal: primaryGoal,
                                        experience: experience,
                                        workoutFrequency: workoutFrequency,
                                        notificationsEnabled: true,
                                        dataSharingEnabled: true,
                                        moveGoal: HealthData.shared.moveGoal,
                                        createdAt: Date()
                                    )
                                    
                                    try await SupabaseManager.shared.saveUserProfile(userProfile)
                                    print("✅ VoiceAssistantManager: User name '\(name)' saved to Supabase!")
                                } catch {
                                    print("❌ VoiceAssistantManager: Failed to save name to Supabase: \(error)")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Learn user preferences from conversation
        if input.contains("motivate") || input.contains("pump") || input.contains("energy") {
            var preferences = userProfileManager.profile.preferences
            preferences.coachStyle = .motivational
            userProfileManager.profile.preferences = preferences
            userProfileManager.saveProfile()
            print("🧠 VoiceAssistantManager: Learned user prefers motivational coaching")
        }
        
        if input.contains("technical") || input.contains("form") || input.contains("technique") {
            var preferences = userProfileManager.profile.preferences
            preferences.coachStyle = .technical
            userProfileManager.profile.preferences = preferences
            userProfileManager.saveProfile()
            print("🧠 VoiceAssistantManager: Learned user prefers technical coaching")
        }
        
        // Learn user goals
        if input.contains("lose weight") || input.contains("weight loss") {
            var fitnessProfile = userProfileManager.profile.fitnessProfile
            fitnessProfile.primaryGoal = .weightLoss
            userProfileManager.profile.fitnessProfile = fitnessProfile
            userProfileManager.saveProfile()
            print("🧠 VoiceAssistantManager: Learned user goal: weight loss")
        }
        
        if input.contains("gain muscle") || input.contains("muscle gain") {
            var fitnessProfile = userProfileManager.profile.fitnessProfile
            fitnessProfile.primaryGoal = .muscleGain
            userProfileManager.profile.fitnessProfile = fitnessProfile
            userProfileManager.saveProfile()
            print("🧠 VoiceAssistantManager: Learned user goal: muscle gain")
        }
        
        // Learn user interests
        if input.contains("nutrition") || input.contains("food") || input.contains("meal") {
            var preferences = userProfileManager.profile.preferences
            preferences.primaryInterest = .nutrition
            userProfileManager.profile.preferences = preferences
            userProfileManager.saveProfile()
            print("🧠 VoiceAssistantManager: Learned user interest: nutrition")
        }
        
        // Update last interaction
        userProfileManager.profile.lastUpdated = Date()
        userProfileManager.saveProfile()
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
                return "Hey! Ready to crush those \(exercise)? I'm here to help with form, motivation, or any questions you have!"
            } else {
                return "Workout mode is on! What are we working on today?"
            }
        }
        
        // Use personalized greeting from UserProfileManager
        let userProfileManager = UserProfileManager.shared
        return userProfileManager.getPersonalizedGreeting()
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
                        
                        if self.isInConversation == false {
                            print("[Wake Word] Starting new conversation with 0.2-second delay...")
                            self.feedbackMessage = "Hey Rex heard... (waiting 0.2 second)"
                            
                            // Wait briefly before responding (in case user is still speaking)
                            DispatchQueue.main.asyncAfter(deadline: .now() + (self.postWakeWordDelay)) {
                                print("[Wake Word] 0.2-second delay complete, now responding...")
                                
                                // Mark that we're in a conversation FIRST
                                self.isInConversation = true
                                
                                // Choose greeting based on context
                                let greeting = self.getContextualGreeting()
                                self.speakWithPersonality(greeting, style: .supportive)
                                self.feedbackMessage = "Coach is listening..."
                                
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
        hasLoggedSpeaking = false // Reset logging flag for new conversation
        isAboutToRespond = false // Reset interruption flag
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
        
        // Ask if there's anything else with a more natural approach
        let checkInMessage = "Anything else I can help you with today?"
        self.feedbackMessage = "Checking in..."
        
        // Speak the check-in message
        speakWithPersonality(checkInMessage, style: .supportive)
        
        // After speaking, wait before starting final listening window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.feedbackMessage = "Listening for your response..."
            self.startSpeechRecognition()
            
            // Set a shorter timer to end conversation after check-in
            self.conversationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                print("[Conversation] Check-in period expired, ending conversation")
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
        recognizer.defaultTaskHint = .search // Better for conversational speech
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
        
        // Shorter delay for faster response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            do {
                // Use centralized audio session manager
                try AudioSessionManager.shared.configureForRecording()
                
                print("[Speech] Audio session configured successfully for speech recognition")
                
                // Continue with speech recognition setup
                self.setupSpeechRecognitionImplementation()
                
            } catch {
                print("[Speech] Audio session setup failed: \(error), attempting recovery...")
                
                // Try to recover audio session with one retry
                self.attemptAudioSessionRecovery(attempt: 1)
            }
        }
    }
    
    private func attemptAudioSessionRecovery(attempt: Int) {
        let maxAttempts = 2
        
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
        
        // Enable on-device recognition for better performance
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .search // Better for conversational speech
        
        var lastTranscription = ""
        var hasReceivedPartialResult = false
        var consecutiveEmptyResults = 0
        var lastNonEmptyResult = ""
        
        // Add a fallback timeout in case no results are received at all
        // This handles cases where audio is being captured but not transcribed
        let fallbackTimeout = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("[Speech] ⚠️ Fallback timeout triggered - no transcription results received")
            DispatchQueue.main.async {
                self.isListening = false
                self.isProcessingSpeech = false
                self.stopSpeechRecognition()
                
                if !lastNonEmptyResult.isEmpty {
                    print("[Speech] Using last captured text: '\(lastNonEmptyResult)'")
                    self.feedbackMessage = "Processing..."
                    self.processWithOpenAI(lastNonEmptyResult)
                } else {
                    print("[Speech] No speech captured, ending conversation")
                    self.feedbackMessage = "I didn't hear anything. Say 'Hey Rex' to try again."
                    self.endConversation()
                }
            }
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else {
                fallbackTimeout.invalidate()
                return
            }
            
            if let error = error {
                print("[Speech] Recognition error: \(error.localizedDescription)")
                fallbackTimeout.invalidate()  // Cancel fallback timeout on error
                
                DispatchQueue.main.async {
                    self.isListening = false
                    self.isProcessingSpeech = false
                    self.stopSpeechRecognition()
                    
                    // Provide more helpful feedback based on error type
                    if error.localizedDescription.contains("No speech detected") {
                        // Don't show error for "No speech detected" - it's normal when user stops talking
                        print("[Speech] No speech detected - normal end of speech")
                    } else if error.localizedDescription.contains("kAFAssistantErrorDomain") {
                        self.feedbackMessage = "Audio issue. Try again in a moment."
                    } else {
                        self.feedbackMessage = "Speech recognition error. Try again."
                    }
                }
                return
            }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                if !text.isEmpty {
                    lastTranscription = text
                    lastNonEmptyResult = text
                    hasReceivedPartialResult = true
                    consecutiveEmptyResults = 0 // Reset empty results counter
                    fallbackTimeout.invalidate()  // Cancel fallback timeout when we get speech
                    print("[Speech] 📝 Transcription: '\(text)' (partial: \(!result.isFinal))")
                    
                    // If AI is about to respond and user starts speaking again, cancel the response
                    if self.isAboutToRespond {
                        self.isAboutToRespond = false
                        self.speechTimeoutTimer?.invalidate()
                        print("[Conversation] User interrupted AI response - continuing to listen")
                    }
                    
                    // Cancel conversation timeout since user is speaking (but only log once per session)
                    if !self.hasLoggedSpeaking {
                        self.conversationTimeoutTimer?.invalidate()
                        print("[Conversation] User started speaking, conversation timeout cancelled")
                        self.hasLoggedSpeaking = true
                    }
                    
                    // Set/reset speech timeout whenever we get new speech
                    // This handles cases where we never get a final result
                    self.speechTimeoutTimer?.invalidate()
                    self.speechTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.speechPauseTimeout, repeats: false) { _ in
                        DispatchQueue.main.async {
                            print("[Speech] Speech pause timeout - processing last transcription")
                            self.isListening = false
                            self.isProcessingSpeech = false
                            self.stopSpeechRecognition()
                            fallbackTimeout.invalidate()  // Cancel fallback timeout
                            
                            // Use the last non-empty result we captured
                            if !lastNonEmptyResult.isEmpty {
                                self.feedbackMessage = "Processing..."
                                self.processWithOpenAI(lastNonEmptyResult)
                            } else {
                                self.feedbackMessage = "I didn't catch that. Could you repeat?"
                            }
                        }
                    }
                } else {
                    // Track consecutive empty results to detect actual speech completion
                    consecutiveEmptyResults += 1
                }
                
                if result.isFinal {
                    self.speechTimeoutTimer?.invalidate()
                    fallbackTimeout.invalidate()  // Cancel fallback timeout
                    DispatchQueue.main.async {
                        self.isListening = false
                        self.isProcessingSpeech = false
                        self.stopSpeechRecognition()
                        
                        print("[Speech] Final result received: '\(text)'")
                        
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
                            self.feedbackMessage = "I didn't catch that. Could you repeat?"
                        }
                    }
                    return
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
            
            // For iOS Simulator, we need to use the actual hardware format that the simulator provides
            // The simulator often returns 48kHz even when we query it as 0Hz initially
            if let simulatorFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1) {
                recordingFormat = simulatorFormat
                print("[Speech] ✅ Using simulator format: \(simulatorFormat)")
            } else {
                // Fallback to 44.1kHz if 48kHz fails
                if let fallbackFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                    recordingFormat = fallbackFormat
                    print("[Speech] ✅ Using fallback format: \(fallbackFormat)")
                } else {
                    print("[Speech] ❌ Could not create any compatible audio format")
                    feedbackMessage = "Audio system not ready"
                    isProcessingSpeech = false
                    stopSpeechRecognition()
                    return
                }
            }
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
                
                // For iOS Simulator, we need to match the actual hardware format (48kHz)
                if let simulatorFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1) {
                    print("[Speech] 🔄 Retrying with simulator format: \(simulatorFormat)")
                    
                    // Remove existing tap and try again
                    inputNode.removeTap(onBus: 0)
                    
                    // Install tap with simulator format
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: simulatorFormat) { [weak self] buffer, _ in
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
        
        // Start the conversation flow with minimal delay for faster response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.aiResponse = nil
            if self.isInConversation {
                self.feedbackMessage = "Listening for your response..."
                self.startSpeechRecognition()
                
                // Set timer to check in after the full listening period
                self.conversationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.postResponseListeningTime, repeats: false) { _ in
                    print("[Conversation] \(self.postResponseListeningTime)-second listening window expired, checking in with user...")
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
        print("[Conversation] Starting \(postResponseListeningTime)-second listening window for follow-up...")
        
        // After speaking, start listening with minimal delay for faster response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.aiResponse = nil
            if self.isInConversation {
                self.feedbackMessage = "Listening for your response..."
                self.startSpeechRecognition()
                
                // Set timer to check in after the full listening period
                self.conversationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.postResponseListeningTime, repeats: false) { _ in
                    print("[Conversation] \(self.postResponseListeningTime)-second listening window expired, checking in with user...")
                    self.checkInWithUser()
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("[Audio] Cancelled speaking: \(utterance.speechString)")
    }
} 