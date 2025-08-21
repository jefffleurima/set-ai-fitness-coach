import Foundation

/// Gym-specific speech coordinator that maps fitness events to appropriate speech priorities
class GymSpeechCoordinator {
    
    // MARK: - Properties
    
    private let speechGenerator: SpeechGeneratorProtocol
    private var isInWorkout = false
    private var lastFormCorrectionTime: Date?
    
    // MARK: - Configuration
    
    /// Minimum time between form corrections to avoid overwhelming user
    private let formCorrectionCooldown: TimeInterval = 3.0
    
    /// Maximum duration for urgent announcements before timeout
    private let urgentSpeechTimeout: TimeInterval = 10.0
    
    // MARK: - Initialization
    
    init(speechGenerator: SpeechGeneratorProtocol) {
        self.speechGenerator = speechGenerator
        
        // Configure voice characteristics for gym environment
        speechGenerator.setVoiceCharacteristics(.coaching)
        speechGenerator.setVoiceOverCompatibility(true)
    }
    
    // MARK: - Workout State Management
    
    func startWorkout() {
        isInWorkout = true
        speak("Workout started. I'm here to help with your form and coaching.", priority: .normal)
        print("🏋️ [GymCoach] Workout started")
    }
    
    func endWorkout() {
        isInWorkout = false
        speechGenerator.clearQueue(priority: .low) // Clear low-priority encouragements
        speak("Great workout! Well done.", priority: .normal)
        print("🏋️ [GymCoach] Workout ended")
    }
    
    func pauseWorkout() {
        speechGenerator.clearQueue(priority: .low)
        speechGenerator.pauseSpeech()
        print("🏋️ [GymCoach] Workout paused")
    }
    
    func resumeWorkout() {
        speechGenerator.resumeSpeech()
        print("🏋️ [GymCoach] Workout resumed")
    }
    
    // MARK: - Form Correction (Highest Priority)
    
    func handleCriticalFormIssue(_ message: String) {
        // Critical safety issues always interrupt
        speechGenerator.speak(
            message,
            priority: .immediateInterrupt,
            completion: { success in
                print("🚨 [GymCoach] Critical form correction delivered: \(success)")
            }
        )
        
        lastFormCorrectionTime = Date()
        print("🚨 [GymCoach] Critical form issue: \(message)")
    }
    
    func handleFormCorrection(_ message: String) {
        // Check cooldown to avoid overwhelming user
        if let lastTime = lastFormCorrectionTime,
           Date().timeIntervalSince(lastTime) < formCorrectionCooldown {
            print("🏋️ [GymCoach] Form correction skipped (cooldown)")
            return
        }
        
        speechGenerator.speak(
            message,
            priority: .immediateBlocking,
            completion: { success in
                print("🏋️ [GymCoach] Form correction delivered: \(success)")
            }
        )
        
        lastFormCorrectionTime = Date()
        print("🏋️ [GymCoach] Form correction: \(message)")
    }
    
    // MARK: - Set and Rest Management
    
    func handleSetCompletion(_ setNumber: Int, _ exerciseName: String) {
        let message = "Set \(setNumber) of \(exerciseName) complete. Nice work!"
        
        speechGenerator.speak(
            message,
            priority: .immediateBlocking,
            completion: { success in
                print("✅ [GymCoach] Set completion announced: \(success)")
            }
        )
    }
    
    func handleRestTimer(_ timeRemaining: Int) {
        let message: String
        
        switch timeRemaining {
        case 10:
            message = "10 seconds left"
        case 5:
            message = "5 seconds"
        case 3:
            message = "3"
        case 2:
            message = "2" 
        case 1:
            message = "1"
        case 0:
            message = "Time's up! Ready for your next set?"
        default:
            return // Don't announce other times
        }
        
        let priority: SpeechPriority = timeRemaining <= 3 ? .immediateBlocking : .normal
        
        speechGenerator.speak(
            message,
            priority: priority,
            completion: nil
        )
    }
    
    // MARK: - Coaching and Encouragement
    
    func handleCoachingTip(_ message: String) {
        speechGenerator.speak(
            message,
            priority: .normal,
            completion: { success in
                print("💡 [GymCoach] Coaching tip delivered: \(success)")
            }
        )
    }
    
    func handleEncouragement(_ message: String) {
        // Only provide encouragement during workout
        guard isInWorkout else { return }
        
        speechGenerator.speak(
            message,
            priority: .low,
            completion: { success in
                print("💪 [GymCoach] Encouragement delivered: \(success)")
            }
        )
    }
    
    func handleMotivation(_ message: String) {
        speechGenerator.speak(
            message,
            priority: .low,
            completion: { success in
                print("🔥 [GymCoach] Motivation delivered: \(success)")
            }
        )
    }
    
    // MARK: - Exercise Transitions
    
    func handleExerciseChange(_ newExercise: String) {
        // Clear low-priority speech when changing exercises
        speechGenerator.clearQueue(priority: .low)
        
        let message = "Switching to \(newExercise). Let me help you with your form."
        
        speechGenerator.speak(
            message,
            priority: .immediateBlocking,
            completion: { success in
                print("🔄 [GymCoach] Exercise change announced: \(success)")
            }
        )
    }
    
    // MARK: - Emergency/Safety
    
    func handleEmergencyStop() {
        speechGenerator.stopAllSpeech()
        speechGenerator.speak(
            "Stop! Check your form.",
            priority: .immediateInterrupt,
            completion: nil
        )
        print("🆘 [GymCoach] Emergency stop initiated")
    }
    
    // MARK: - AI Responses (Hey Rex)
    
    func handleAIResponse(_ message: String, isUrgent: Bool = false) {
        let priority: SpeechPriority = isUrgent ? .immediateBlocking : .normal
        
        speechGenerator.speak(
            message,
            priority: priority,
            completion: { success in
                print("🤖 [GymCoach] AI response delivered: \(success)")
            }
        )
    }
    
    // MARK: - Mode Changes
    
    func handleModeSwitch(_ newMode: String) {
        // Stop current speech when user switches modes
        speechGenerator.stopSpeech(priority: .normal)
        speechGenerator.clearQueue(priority: .low)
        
        let message = "Switched to \(newMode) mode"
        
        speechGenerator.speak(
            message,
            priority: .immediateBlocking,
            completion: { success in
                print("🔄 [GymCoach] Mode switch announced: \(success)")
            }
        )
    }
    
    // MARK: - Private Helpers
    
    private func speak(_ text: String, priority: SpeechPriority, timeout: TimeInterval? = nil) {
        let request = SpeechRequest(
            text: text,
            priority: priority,
            timeout: timeout
        )
        speechGenerator.speak(request)
    }
}

// MARK: - Pre-configured Messages

extension GymSpeechCoordinator {
    
    /// Common form correction messages
    enum FormMessages {
        static let squatDepth = "Go deeper on your squat"
        static let kneeTracking = "Keep your knees tracking over your toes"
        static let backStraight = "Keep your back straight"
        static let coreEngaged = "Engage your core"
        static let controlledMovement = "Control the movement, don't rush"
        static let fullRange = "Use your full range of motion"
    }
    
    /// Encouragement messages
    enum EncouragementMessages {
        static let goodForm = "Great form!"
        static let keepGoing = "Keep it up!"
        static let almostThere = "You're almost there!"
        static let strongRep = "That's a strong rep!"
        static let perfectTechnique = "Perfect technique!"
    }
    
    /// Coaching tips
    enum CoachingMessages {
        static let breathe = "Remember to breathe with each rep"
        static let focus = "Stay focused on your form"
        static let mindMuscle = "Feel the mind-muscle connection"
        static let controlled = "Controlled movement is key"
    }
}
