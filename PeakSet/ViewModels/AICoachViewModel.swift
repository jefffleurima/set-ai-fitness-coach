import Foundation
import SwiftUI
import Combine

class AICoachViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var userProfile: OpenAIClient.UserProfile
    
    private let openAIClient = OpenAIClient.shared
    private var cancellables = Swift.Set<AnyCancellable>()
    
    init() {
        self.userProfile = OpenAIClient.UserProfile()
        setupInitialGreeting()
    }
    
    private func setupInitialGreeting() {
        let greeting = ChatMessage(
            id: UUID(),
            text: "👋 What's up? Ready to crush some goals?\n\n💡 I can help with:\n🏋️ Workout plans (daily to yearly)\n🥗 Meal planning & nutrition\n💊 Supplement recommendations\n💪 Form correction & injury prevention\n😴 Sleep & recovery optimization\n🧠 Mental health & motivation\n\nJust ask for what you need!",
            isUser: false,
            type: .greeting,
            timestamp: Date(),
            context: nil
        )
        messages.append(greeting)
    }
    
    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        let messageTime = Date()
        
        // Add user message
        let userMessage = ChatMessage(id: UUID(), text: text, isUser: true, type: .response, timestamp: messageTime, context: nil)
        messages.append(userMessage)
        
        // Show typing indicator (temporarily, will be removed when response arrives)
        let typingMessage = ChatMessage(id: UUID(), text: "...", isUser: false, type: .response, timestamp: messageTime, context: nil)
        messages.append(typingMessage)
        
        isProcessing = true
        
        // Check if user is telling us their name
        updateUserProfileFromConversation(userInput: text)
        
        // Send to OpenAI with user data context
        let userData = createUserDataContext()
        openAIClient.sendMessage(prompt: text, context: nil, userData: userData) { [weak self] result in
            DispatchQueue.main.async {
                // Remove typing indicator (find by text content since we don't have .typing type anymore)
                if let index = self?.messages.firstIndex(where: { $0.text == "..." && !$0.isUser }) {
                    self?.messages.remove(at: index)
                }
                
                let responseTime = Date()
                
                switch result {
                case .success(let response):
                    let coachMessage = ChatMessage(
                        id: UUID(),
                        text: response,
                        isUser: false,
                        type: .response,
                        timestamp: responseTime,
                        context: nil
                    )
                    self?.messages.append(coachMessage)
                    
                case .failure(_):
                    let errorMessage = ChatMessage(
                        id: UUID(),
                        text: "My bad, something went wrong. Try again?",
                        isUser: false,
                        type: .feedback,
                        timestamp: responseTime,
                        context: nil
                    )
                    self?.messages.append(errorMessage)
                }
                
                self?.isProcessing = false
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
            todayCalories: healthKitManager.getTodayCalories(),
            todaySteps: healthKitManager.getTodayStepCount(),
            todayDistance: healthKitManager.getTodayStepDistance(),
            moveGoal: healthData.moveGoal,
            averageFormScore: healthKitManager.getAverageFormScore(),
            aiCoachFeedback: aiCoachFeedback.feedback,
            conversationHistory: conversationHistory
        )
        
        // Debug: Print the actual data being sent to AI
        print("🤖 AI DATA CONTEXT (AICoachViewModel):")
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
    
    private func updateUserProfileFromConversation(userInput: String) {
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
                            UserProfileManager.shared.updateUserName(name)
                            print("👤 AICoachViewModel: Detected and updated user name to '\(name)'")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Management (for UI)
    
    func getMemoryStats() -> [String: Int] {
        // Get stats from the proper singletons
        return [
            "conversations": ConversationMemory.shared.messages.count,
            "totalMessages": ConversationMemory.shared.messages.count
        ]
    }
    
    func clearMemory() {
        // Clear conversation history
        // Note: This clears the UI messages, not the persistent ConversationMemory
        messages.removeAll()
        setupInitialGreeting()
        print("🗑️ AICoachViewModel: Chat UI cleared")
    }
}
