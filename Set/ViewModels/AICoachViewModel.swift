import Foundation
import SwiftUI
import Combine

// Minimal WorkoutContext so this file can compile standalone.
// Replace or remove if you have a canonical WorkoutContext elsewhere.
struct WorkoutContext: Codable, Equatable {
    let exercise: String?
    let currentSet: Int?
    let totalSets: Int?
    let currentRep: Int?
    let formScore: Int?
    let userQuestion: String?

    var description: String {
        return exercise ?? "general"
    }
}

// NOTE: Keep your real OpenAIClient in your project. userProfile is optional here
// to avoid forcing a concrete OpenAIClient implementation in this file.
class AICoachViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var userProfile: OpenAIClient.UserProfile?     // made optional for safety
    @Published var currentWorkoutContext: WorkoutContext?

    private let openAIClient = OpenAIClient.shared
    private var cancellables: Set<AnyCancellable> = []

    // Enhanced memory system
    private var conversationMemory: [String: Any] = [:]
    private var userPreferences: [String: Any] = [:]
    private var workoutHistory: [[String: Any]] = []

    init() {
        // If OpenAIClient.UserProfile has a default initializer in your project,
        // you can set it here. Otherwise keep it nil until updateUserProfile is called.
        self.userProfile = (try? OpenAIClient.UserProfile()) ?? nil
        setupInitialGreeting()
        loadUserMemory()
    }

    private func setupInitialGreeting() {
        let greeting = ChatMessage(
            id: UUID(),
            text: "👋 What's up? Ready to crush some goals?",
            isUser: false,
            type: .greeting,
            timestamp: Date()
        )
        messages.append(greeting)
    }

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let messageTime = Date()

        // Add user message
        let userMessage = ChatMessage(id: UUID(), text: text, isUser: true, timestamp: messageTime)
        messages.append(userMessage)

        // Show typing indicator
        let typingMessage = ChatMessage(id: UUID(), text: "...", isUser: false, type: .typing, timestamp: messageTime)
        messages.append(typingMessage)

        isProcessing = true

        // Update memory with user input
        updateMemory(with: text)

        // Send to OpenAI with enhanced context
        let enhancedContext = buildEnhancedContext()
        openAIClient.sendMessage(prompt: text, context: enhancedContext) { [weak self] result in
            DispatchQueue.main.async {
                // Remove typing indicator
                if let index = self?.messages.firstIndex(where: { $0.type == .typing }) {
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
                        timestamp: responseTime
                    )
                    self?.messages.append(coachMessage)

                    // Update memory with AI response
                    self?.updateMemory(with: response, isAI: true)

                case .failure(_):
                    let errorMessage = ChatMessage(
                        id: UUID(),
                        text: "My bad, something went wrong. Try again?",
                        isUser: false,
                        type: .error,
                        timestamp: responseTime
                    )
                    self?.messages.append(errorMessage)
                }

                self?.isProcessing = false
            }
        }
    }

    // MARK: - Enhanced Memory System
    private func updateMemory(with text: String, isAI: Bool = false) {
        let timestamp = Date()
        let memoryEntry: [String: Any] = [
            "text": text,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "isAI": isAI,
            "context": currentWorkoutContext?.description ?? "general"
        ]

        conversationMemory[timestamp.timeIntervalSince1970.description] = memoryEntry

        // Extract user preferences from conversation
        if !isAI {
            extractUserPreferences(from: text)
        }

        // Keep memory manageable but larger
        if conversationMemory.count > 50 {
            let sortedKeys = conversationMemory.keys.sorted()
            let keysToRemove = sortedKeys.prefix(10)
            for key in keysToRemove {
                conversationMemory.removeValue(forKey: key)
            }
        }

        saveUserMemory()
    }

    private func extractUserPreferences(from text: String) {
        let lowercased = text.lowercased()

        // Extract fitness goals
        if lowercased.contains("lose weight") || lowercased.contains("weight loss") {
            userPreferences["primaryGoal"] = "weightLoss"
        } else if lowercased.contains("build muscle") || lowercased.contains("muscle gain") {
            userPreferences["primaryGoal"] = "muscleGain"
        } else if lowercased.contains("strength") {
            userPreferences["primaryGoal"] = "strength"
        }

        // Extract experience level
        if lowercased.contains("beginner") || lowercased.contains("new") || lowercased.contains("just starting") {
            userPreferences["experienceLevel"] = "beginner"
        } else if lowercased.contains("advanced") || lowercased.contains("experienced") {
            userPreferences["experienceLevel"] = "advanced"
        }

        // Extract workout preferences
        if lowercased.contains("home workout") || lowercased.contains("no equipment") {
            userPreferences["workoutType"] = "home"
        } else if lowercased.contains("gym") || lowercased.contains("equipment") {
            userPreferences["workoutType"] = "gym"
        }

        // Extract time preferences
        if lowercased.contains("quick") || lowercased.contains("short") || lowercased.contains("30 min") {
            userPreferences["workoutDuration"] = "short"
        } else if lowercased.contains("long") || lowercased.contains("intense") {
            userPreferences["workoutDuration"] = "long"
        }
    }

    private func buildEnhancedContext() -> WorkoutContext? {
        // Build enhanced context from memory
        var enhancedContext = currentWorkoutContext

        // Add memory-based context
        let recentMemories = Array(conversationMemory.values.suffix(5))
        let memoryContext = recentMemories.compactMap { $0 as? [String: Any] }
            .map { "\($0["text"] ?? "")" }
            .joined(separator: " | ")

        // Add user preferences context
        let preferencesContext = userPreferences.map { "\($0.key): \($0.value)" }.joined(separator: ", ")

        // Create enhanced context if we had an existing context or memory/preferences to add
        if enhancedContext != nil || !memoryContext.isEmpty || !preferencesContext.isEmpty {
            enhancedContext = WorkoutContext(
                exercise: enhancedContext?.exercise,
                currentSet: enhancedContext?.currentSet,
                totalSets: enhancedContext?.totalSets,
                currentRep: enhancedContext?.currentRep,
                formScore: enhancedContext?.formScore,
                userQuestion: "Memory: \(memoryContext) | Preferences: \(preferencesContext)"
            )
        }

        return enhancedContext
    }

    private func loadUserMemory() {
        // Load from UserDefaults or other storage
        if let data = UserDefaults.standard.data(forKey: "userMemory"),
           let memory = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            conversationMemory = memory
        }

        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let preferences = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            userPreferences = preferences
        }

        // Note: Timestamps are stored as ISO8601 strings and can be converted back to Date if needed.
    }

    private func saveUserMemory() {
        // Save to UserDefaults
        if JSONSerialization.isValidJSONObject(conversationMemory),
           let data = try? JSONSerialization.data(withJSONObject: conversationMemory, options: []) {
            UserDefaults.standard.set(data, forKey: "userMemory")
        }

        if JSONSerialization.isValidJSONObject(userPreferences),
           let data = try? JSONSerialization.data(withJSONObject: userPreferences, options: []) {
            UserDefaults.standard.set(data, forKey: "userPreferences")
        }
    }

    func updateWorkoutContext(exercise: String? = nil, currentSet: Int? = nil, totalSets: Int? = nil, currentRep: Int? = nil, formScore: Int? = nil) {
        currentWorkoutContext = WorkoutContext(
            exercise: exercise,
            currentSet: currentSet,
            totalSets: totalSets,
            currentRep: currentRep,
            formScore: formScore,
            userQuestion: nil
        )

        // Add to workout history
        if let exercise = exercise {
            let workoutEntry: [String: Any] = [
                "exercise": exercise,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "sets": totalSets ?? 0,
                "formScore": formScore ?? 0
            ]
            workoutHistory.append(workoutEntry)

            // Keep workout history manageable
            if workoutHistory.count > 100 {
                workoutHistory.removeFirst(20)
            }
        }
    }

    func updateUserProfile(fitnessLevel: OpenAIClient.UserProfile.FitnessLevel? = nil,
                          goals: [OpenAIClient.UserProfile.FitnessGoal]? = nil,
                          coachStyle: OpenAIClient.UserPreferences.CoachStyle? = nil,
                          humorLevel: Int? = nil,
                          technicalDetail: Int? = nil) {
        // Ensure userProfile exists or create a default if the type supports it
        if userProfile == nil {
            userProfile = (try? OpenAIClient.UserProfile()) ?? nil
        }

        if let level = fitnessLevel {
            userProfile?.fitnessLevel = level
        }
        if let newGoals = goals {
            userProfile?.goals = newGoals
        }
        if let style = coachStyle {
            userProfile?.preferences.coachStyle = style
        }
        if let humor = humorLevel {
            userProfile?.preferences.humorLevel = min(max(humor, 1), 5)
        }
        if let detail = technicalDetail {
            userProfile?.preferences.technicalDetail = min(max(detail, 1), 5)
        }

        // Update preferences in memory when available
        if let up = userProfile {
            userPreferences["fitnessLevel"] = up.fitnessLevel.rawValue
            userPreferences["goals"] = up.goals.map { $0.rawValue }
            userPreferences["coachStyle"] = up.preferences.coachStyle.rawValue
            saveUserMemory()
        }
    }

    // MARK: - Memory Management
    func clearMemory() {
        conversationMemory.removeAll()
        userPreferences.removeAll()
        workoutHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "userMemory")
        UserDefaults.standard.removeObject(forKey: "userPreferences")
    }

    func getMemoryStats() -> [String: Int] {
        return [
            "conversations": conversationMemory.count,
            "preferences": userPreferences.count,
            "workouts": workoutHistory.count
        ]
    }
}

// MARK: - Supporting Types
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let type: MessageType
    let timestamp: Date

    enum MessageType: Equatable {
        case normal
        case greeting
        case typing
        case response
        case error
    }

    init(id: UUID = UUID(), text: String, isUser: Bool, type: MessageType = .normal, timestamp: Date) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.type = type
        self.timestamp = timestamp
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.isUser == rhs.isUser &&
        lhs.type == rhs.type &&
        lhs.timestamp == rhs.timestamp
    }
}
