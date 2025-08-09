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
        }
    }
    
    struct UserPreferences: Codable {
        var coachStyle: CoachStyle = .motivational
        var humorLevel: Int = 3 // 1-5
        var technicalDetail: Int = 3 // 1-5
        var preferredWorkoutDuration: Int = 45 // minutes
        
        enum CoachStyle: String, Codable {
            case strict = "Strict"
            case motivational = "Motivational"
            case friendly = "Friendly"
            case technical = "Technical"
        }
    }
    
    // MARK: - Coaching Methods
    func sendMessage(prompt: String, context: WorkoutContext? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        let messages = buildMessageHistory(prompt: prompt, context: context)
        
        let body = RequestBody(
            model: "gpt-4o-mini", // Use fastest model
            messages: messages,
            max_tokens: 60, // Even shorter for speed
            temperature: 0.8 // More personality
        )
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10 // Even faster timeout
        
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
        // System message with coach personality and context
        let systemPrompt = """
        You are PeakSet, an elite AI fitness coach. Be FAST, DIRECT, and EFFICIENT. Keep responses under 2 sentences unless absolutely necessary. Be brutally honest but supportive. Use gym slang and be relatable. Create instant connections through shared fitness passion. No fluff, no generic advice. Be the coach everyone wants - knowledgeable, real, and motivating. If someone's form sucks, tell them straight. If they're crushing it, hype them up. Always actionable advice. Remember: speed and authenticity over perfection.
        
        User level: \(userProfile.fitnessLevel.rawValue)
        Goals: \(userProfile.goals.map { $0.rawValue }.joined(separator: ", "))
        Style: \(userProfile.preferences.coachStyle.rawValue)
        Context: \(context?.description ?? "General fitness consultation")
        """
        
        let systemMessage = Message(role: "system", content: systemPrompt)
        let historyMessages = conversationHistory.isEmpty ? [] : Array(conversationHistory.suffix(3)) // Keep less history for speed
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
