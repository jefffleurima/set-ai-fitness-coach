import Foundation

// MARK: - Chat Message Model
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let type: MessageType
    let timestamp: Date
    let context: MessageContext?
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum MessageType: String, Codable {
        case greeting = "greeting"
        case question = "question"
        case response = "response"
        case feedback = "feedback"
        case workout = "workout"
        case nutrition = "nutrition"
        case motivation = "motivation"
        case technical = "technical"
    }
    
    struct MessageContext: Codable {
        let exercise: String?
        let workoutSession: String?
        let topic: String?
        let mood: String?
        let userGoal: String?
    }
}

// MARK: - Conversation Memory Manager
class ConversationMemory: ObservableObject {
    static let shared = ConversationMemory()
    
    @Published var messages: [ChatMessage] = []
    private let maxMessages = 100 // Keep last 100 messages in memory
    
    private let userDefaults = UserDefaults.standard
    private let messagesKey = "ConversationMemoryMessages"
    
    private init() {
        loadMessages()
    }
    
    // MARK: - Message Management
    
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        
        // Keep only the most recent messages
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
        
        saveMessages()
        saveToSupabase(message)
        print("💾 ConversationMemory: Added \(message.isUser ? "user" : "AI") message: \(message.text.prefix(50))...")
    }
    
    private func saveToSupabase(_ message: ChatMessage) {
        Task {
            do {
                try await SupabaseManager.shared.saveConversationMessage(
                    messageText: message.text,
                    isUserMessage: message.isUser,
                    messageType: message.type.rawValue
                )
            } catch {
                print("❌ ConversationMemory: Failed to save to Supabase: \(error)")
            }
        }
    }
    
    func addUserMessage(_ text: String, context: ChatMessage.MessageContext? = nil) {
        let message = ChatMessage(
            id: UUID(),
            text: text,
            isUser: true,
            type: determineMessageType(text),
            timestamp: Date(),
            context: context
        )
        addMessage(message)
    }
    
    func addAIMessage(_ text: String, context: ChatMessage.MessageContext? = nil) {
        let message = ChatMessage(
            id: UUID(),
            text: text,
            isUser: false,
            type: determineMessageType(text),
            timestamp: Date(),
            context: context
        )
        addMessage(message)
    }
    
    // MARK: - Workout-Specific Conversation Methods
    
    func addWorkoutGreeting(_ text: String, exercise: String) {
        let context = ChatMessage.MessageContext(
            exercise: exercise,
            workoutSession: nil,
            topic: "workout_setup",
            mood: nil,
            userGoal: nil
        )
        addAIMessage(text, context: context)
    }
    
    func addFormFeedback(_ text: String, exercise: String, repNumber: Int?, formScore: Float?) {
        let context = ChatMessage.MessageContext(
            exercise: exercise,
            workoutSession: nil,
            topic: "form_feedback",
            mood: nil,
            userGoal: nil
        )
        addAIMessage(text, context: context)
    }
    
    func addUserQuestion(_ text: String, exercise: String) {
        let context = ChatMessage.MessageContext(
            exercise: exercise,
            workoutSession: nil,
            topic: "user_question",
            mood: nil,
            userGoal: nil
        )
        addUserMessage(text, context: context)
    }
    
    // MARK: - Message Retrieval
    
    func getRecentMessages(limit: Int = 20) -> [ChatMessage] {
        return Array(messages.suffix(limit))
    }
    
    func getMessagesByType(_ type: ChatMessage.MessageType, limit: Int = 10) -> [ChatMessage] {
        return messages.filter { $0.type == type }.suffix(limit)
    }
    
    func getMessagesByTopic(_ topic: String, limit: Int = 10) -> [ChatMessage] {
        return messages.filter { message in
            message.text.lowercased().contains(topic.lowercased()) ||
            message.context?.topic?.lowercased().contains(topic.lowercased()) == true
        }.suffix(limit)
    }
    
    func getLastUserMessage() -> ChatMessage? {
        return messages.last { $0.isUser }
    }
    
    func getLastAIMessage() -> ChatMessage? {
        return messages.last { !$0.isUser }
    }
    
    // MARK: - Context Analysis
    
    func getUserPreferences() -> UserPreferences {
        var preferences = UserPreferences()
        
        // Analyze conversation history to determine user preferences
        let _ = getRecentMessages(limit: 50) // Load recent messages for analysis
        
        // Analyze coaching style preference
        let motivationalMessages = getMessagesByType(.motivation)
        let technicalMessages = getMessagesByType(.technical)
        
        if motivationalMessages.count > technicalMessages.count {
            preferences.coachStyle = .motivational
        } else if technicalMessages.count > motivationalMessages.count {
            preferences.coachStyle = .technical
        }
        
        // Analyze topics of interest
        let workoutMessages = getMessagesByType(.workout)
        let nutritionMessages = getMessagesByType(.nutrition)
        
        if workoutMessages.count > nutritionMessages.count {
            preferences.primaryInterest = .fitness
        } else if nutritionMessages.count > workoutMessages.count {
            preferences.primaryInterest = .nutrition
        }
        
        // Analyze communication style
        let longMessages = messages.filter { $0.text.count > 100 }
        let shortMessages = messages.filter { $0.text.count <= 100 }
        
        if longMessages.count > shortMessages.count {
            preferences.communicationStyle = .detailed
        } else {
            preferences.communicationStyle = .concise
        }
        
        return preferences
    }
    
    func getConversationSummary() -> String {
        let recentMessages = getRecentMessages(limit: 20)
        let topics = extractTopics(from: recentMessages)
        let userGoals = extractUserGoals(from: recentMessages)
        
        var summary = "Recent conversation topics: \(topics.joined(separator: ", "))"
        
        if !userGoals.isEmpty {
            summary += ". User goals mentioned: \(userGoals.joined(separator: ", "))"
        }
        
        return summary
    }
    
    // MARK: - Persistence
    
    private func saveMessages() {
        do {
            let data = try JSONEncoder().encode(messages)
            userDefaults.set(data, forKey: messagesKey)
            print("💾 ConversationMemory: Saved \(messages.count) messages")
        } catch {
            print("❌ ConversationMemory: Failed to save messages: \(error)")
        }
    }
    
    private func loadMessages() {
        guard let data = userDefaults.data(forKey: messagesKey) else {
            print("💾 ConversationMemory: No saved messages found")
            return
        }
        
        do {
            messages = try JSONDecoder().decode([ChatMessage].self, from: data)
            print("💾 ConversationMemory: Loaded \(messages.count) messages")
        } catch {
            print("❌ ConversationMemory: Failed to load messages: \(error)")
            messages = []
        }
    }
    
    // MARK: - Helper Methods
    
    private func determineMessageType(_ text: String) -> ChatMessage.MessageType {
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("workout") || lowercaseText.contains("exercise") || lowercaseText.contains("form") {
            return .workout
        } else if lowercaseText.contains("food") || lowercaseText.contains("meal") || lowercaseText.contains("diet") || lowercaseText.contains("nutrition") {
            return .nutrition
        } else if lowercaseText.contains("motivate") || lowercaseText.contains("encourage") || lowercaseText.contains("pump") {
            return .motivation
        } else if lowercaseText.contains("how") || lowercaseText.contains("what") || lowercaseText.contains("why") || lowercaseText.contains("explain") {
            return .technical
        } else if lowercaseText.contains("thanks") || lowercaseText.contains("thank you") || lowercaseText.contains("great") || lowercaseText.contains("awesome") {
            return .feedback
        } else if lowercaseText.contains("hello") || lowercaseText.contains("hey") || lowercaseText.contains("hi") {
            return .greeting
        } else {
            return .question
        }
    }
    
    private func extractTopics(from messages: [ChatMessage]) -> [String] {
        var topics: Set<String> = []
        
        for message in messages {
            let text = message.text.lowercased()
            
            if text.contains("squat") { topics.insert("squats") }
            if text.contains("deadlift") { topics.insert("deadlifts") }
            if text.contains("bench") { topics.insert("bench press") }
            if text.contains("protein") { topics.insert("protein") }
            if text.contains("cardio") { topics.insert("cardio") }
            if text.contains("strength") { topics.insert("strength training") }
            if text.contains("form") { topics.insert("exercise form") }
            if text.contains("weight") { topics.insert("weight management") }
            if text.contains("muscle") { topics.insert("muscle building") }
            if text.contains("fat") { topics.insert("fat loss") }
        }
        
        return Array(topics)
    }
    
    private func extractUserGoals(from messages: [ChatMessage]) -> [String] {
        var goals: Set<String> = []
        
        for message in messages {
            let text = message.text.lowercased()
            
            if text.contains("lose weight") || text.contains("weight loss") { goals.insert("weight loss") }
            if text.contains("gain muscle") || text.contains("muscle gain") { goals.insert("muscle gain") }
            if text.contains("get stronger") || text.contains("strength") { goals.insert("strength") }
            if text.contains("endurance") || text.contains("stamina") { goals.insert("endurance") }
            if text.contains("flexibility") || text.contains("mobility") { goals.insert("flexibility") }
            if text.contains("fitness") || text.contains("healthy") { goals.insert("general fitness") }
        }
        
        return Array(goals)
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    var coachStyle: CoachStyle = .motivational
    var primaryInterest: PrimaryInterest = .fitness
    var communicationStyle: CommunicationStyle = .concise
    var humorLevel: Int = 3 // 1-5
    var technicalDetail: Int = 3 // 1-5
    
    enum CoachStyle: String, Codable {
        case strict = "strict"
        case motivational = "motivational"
        case friendly = "friendly"
        case technical = "technical"
        case holistic = "holistic"
    }
    
    enum PrimaryInterest: String, Codable {
        case fitness = "fitness"
        case nutrition = "nutrition"
        case wellness = "wellness"
        case sports = "sports"
    }
    
    enum CommunicationStyle: String, Codable {
        case concise = "concise"
        case detailed = "detailed"
        case casual = "casual"
        case formal = "formal"
    }
}
