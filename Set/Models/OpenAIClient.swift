import Foundation

class OpenAIClient {
    static let shared = OpenAIClient()
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // User profile and preferences
    private var userProfile: UserProfile
    private var conversationHistory: [Message] = []
    
    private init() {
        self.apiKey = AppConfig.apiKey
        print("✅ API Key loaded successfully: \(String(apiKey.prefix(8)))...")
        // Initialize with default user profile
        self.userProfile = UserProfile()
    }
    
    // MARK: - Message Structures
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct RequestBody: Codable {
        let model: String
        let messages: [Message]
        let max_tokens: Int?
        let temperature: Double?
    }
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct ResponseBody: Codable {
        let choices: [Choice]
    }
    
    // MARK: - User Profile
    struct UserProfile: Codable {
        var fitnessLevel: FitnessLevel = .beginner
        var goals: [FitnessGoal] = []
        var preferences: UserPreferences = UserPreferences()
        var workoutHistory: [WorkoutSession] = []
        var lastInteraction: Date = Date()
        
        enum FitnessLevel: String, Codable {
            case beginner, intermediate, advanced, elite
        }
        
        enum FitnessGoal: String, Codable {
            case weightLoss = "Weight Loss"
            case muscleGain = "Muscle Gain"
            case strength = "Strength"
            case endurance = "Endurance"
            case flexibility = "Flexibility"
            case generalFitness = "General Fitness"
            case coreStrength = "Core Strength"
            case injuryPrevention = "Injury Prevention"
            case sportsPerformance = "Sports Performance"
            case rehabilitation = "Rehabilitation"
            case nutritionOptimization = "Nutrition Optimization"
            case sleepOptimization = "Sleep Optimization"
            case stressManagement = "Stress Management"
        }
    }
    
    struct UserPreferences: Codable {
        var coachStyle: CoachStyle = .motivational
        var humorLevel: Int = 3 // 1-5
        var technicalDetail: Int = 3 // 1-5
        var preferredWorkoutDuration: Int = 45 // minutes
        var nutritionFocus: NutritionFocus = .balanced
        var dietaryRestrictions: [DietaryRestriction] = []
        var supplementPreferences: [SupplementType] = []
        
        enum CoachStyle: String, Codable {
            case strict = "Strict"
            case motivational = "Motivational"
            case friendly = "Friendly"
            case technical = "Technical"
            case holistic = "Holistic"
        }
        
        enum NutritionFocus: String, Codable {
            case balanced = "Balanced"
            case highProtein = "High Protein"
            case lowCarb = "Low Carb"
            case ketogenic = "Ketogenic"
            case plantBased = "Plant Based"
            case performance = "Performance"
            case weightLoss = "Weight Loss"
        }
        
        enum DietaryRestriction: String, Codable {
            case vegan = "Vegan"
            case vegetarian = "Vegetarian"
            case glutenFree = "Gluten Free"
            case dairyFree = "Dairy Free"
            case nutFree = "Nut Free"
            case lowFODMAP = "Low FODMAP"
        }
        
        enum SupplementType: String, Codable {
            case protein = "Protein"
            case creatine = "Creatine"
            case bcaa = "BCAA"
            case preWorkout = "Pre-Workout"
            case multivitamin = "Multivitamin"
            case omega3 = "Omega-3"
            case vitaminD = "Vitamin D"
            case none = "None"
        }
    }
    
    // MARK: - Coaching Methods
    func sendMessage(prompt: String, context: WorkoutContext? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        let messages = buildMessageHistory(prompt: prompt, context: context)
        
        // Determine if this is a complex request that needs more tokens
        let isComplexRequest = prompt.lowercased().contains("year") || 
                              prompt.lowercased().contains("meal plan") ||
                              prompt.lowercased().contains("comprehensive") ||
                              prompt.lowercased().contains("detailed") ||
                              prompt.lowercased().contains("complete") ||
                              prompt.lowercased().contains("protein") ||
                              prompt.lowercased().contains("supplement") ||
                              prompt.lowercased().contains("nutrition") ||
                              prompt.lowercased().contains("diet")
        
        let body = RequestBody(
            model: "gpt-4o-mini", // Use fastest model
            messages: messages,
            max_tokens: isComplexRequest ? 4000 : 2000, // Much higher limits for complex requests
            temperature: 0.8 // More creative and flexible
        )
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Increased timeout for complex responses
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            print("❌ Failed to encode request body: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ HTTP error: \(httpResponse.statusCode)")
                if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📝 Error details: \(errorJson)")
                }
                completion(.failure(NSError(domain: "OpenAIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
                if let reply = decoded.choices.first?.message.content {
                    print("✅ Received response from API")
                    self?.updateUserProfile(from: prompt, response: reply)
                    completion(.success(reply))
                } else {
                    print("❌ No response content in API response")
                    completion(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response content"])))
                }
            } catch {
                print("❌ Failed to decode response: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📝 Raw response: \(responseString)")
                }
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    // MARK: - Private Helper Methods
    private func buildMessageHistory(prompt: String, context: WorkoutContext?) -> [Message] {
        // Enhanced system message with full fitness and nutrition capabilities
        let systemPrompt = """
        You are PeakSet, an elite AI fitness coach and nutritionist with expertise in:
        
        🏋️ FITNESS & TRAINING:
        - Workout plans (daily, weekly, monthly, yearly)
        - Exercise form and technique
        - Strength training, cardio, HIIT, yoga, pilates
        - Sports-specific training
        - Injury prevention and rehabilitation
        - Progressive overload and periodization
        - Equipment recommendations (gym, home, outdoor)
        
        🥗 NUTRITION & DIET:
        - Meal planning (daily, weekly, monthly, yearly)
        - Macro and micronutrient calculations
        - Supplement recommendations and safety
        - Dietary restrictions and allergies
        - Pre/post workout nutrition
        - Weight loss, muscle gain, maintenance strategies
        - Recipe creation and meal prep
        - Food alternatives and substitutions
        
        💪 HEALTH & WELLNESS:
        - Sleep optimization
        - Stress management and recovery
        - Mental health and motivation
        - Injury prevention
        - Mobility and flexibility
        - Posture correction
        - Lifestyle optimization
        
        🎯 RESPONSE STYLE:
        - Be comprehensive and detailed when needed
        - Provide actionable, specific advice
        - Use scientific backing when relevant
        - Be motivational and supportive
        - Adapt to user's experience level and goals
        - Include safety warnings when necessary
        - Provide progression strategies and alternatives
        
        User Profile:
        - Level: \(userProfile.fitnessLevel.rawValue)
        - Goals: \(userProfile.goals.map { $0.rawValue }.joined(separator: ", "))
        - Coach Style: \(userProfile.preferences.coachStyle.rawValue)
        - Context: \(context?.description ?? "General fitness consultation")

        IMPORTANT: You have FULL CAPABILITIES. Don't limit yourself to short responses. Provide comprehensive, detailed answers when the user asks for complex plans, detailed explanations, or comprehensive guidance. Be as thorough as needed to fully address their request.
        """
        
        let systemMessage = Message(role: "system", content: systemPrompt)
        let historyMessages = conversationHistory.isEmpty ? [] : Array(conversationHistory.suffix(8)) // Keep more history for better context
        let userMessage = Message(role: "user", content: prompt)
        
        return [systemMessage] + historyMessages + [userMessage]
    }
    
    private func updateUserProfile(from prompt: String, response: String) {
        // Update last interaction time
        userProfile.lastInteraction = Date()
        
        // Add to conversation history
        conversationHistory.append(Message(role: "user", content: prompt))
        conversationHistory.append(Message(role: "assistant", content: response))
        
        // Keep conversation history manageable for speed
        if conversationHistory.count > 6 {
            conversationHistory.removeFirst(2)
        }
        
        // TODO: Implement more sophisticated user profile updates based on conversation analysis
    }
    
    // MARK: - Test Methods
    func testConnection(completion: @escaping (Result<String, Error>) -> Void) {
        let testPrompt = "Hello! Can you confirm you're working by responding with a short greeting?"
        sendMessage(prompt: testPrompt) { result in
            switch result {
            case .success(let response):
                print("✅ API Test Successful!")
                print("📝 Response: \(response)")
                completion(.success(response))
            case .failure(let error):
                print("❌ API Test Failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Supporting Types
struct WorkoutContext {
    let exercise: String?
    let currentSet: Int?
    let totalSets: Int?
    let currentRep: Int?
    let formScore: Int?
    let userQuestion: String?
    
    var description: String {
        var context = "Workout Context: "
        if let exercise = exercise {
            context += "Performing \(exercise). "
        }
        if let set = currentSet, let total = totalSets {
            context += "Set \(set) of \(total). "
        }
        if let rep = currentRep {
            context += "Current rep: \(rep). "
        }
        if let score = formScore {
            context += "Form score: \(score)/100. "
        }
        if let question = userQuestion {
            context += "User question: \(question)"
        }
        return context
    }
}

// MARK: - Workout Session
extension OpenAIClient {
    struct WorkoutSession: Codable {
        let date: Date
        let exercises: [String]
        let duration: TimeInterval
        let intensity: Int // 1-10
        let notes: String
    }
} 
