import Foundation

// MARK: - User Data Context
struct UserDataContext {
    let profile: ComprehensiveUserProfile?
    let healthData: HealthData?
    let workoutSessions: [OpenAIClient.WorkoutSession]
    let todayCalories: Int
    let todaySteps: Int
    let todayDistance: Double
    let moveGoal: Int
    let averageFormScore: Int
    let aiCoachFeedback: AICoachFeedback.CoachFeedback?
    let conversationHistory: [ChatMessage]
}

class OpenAIClient {
    static let shared = OpenAIClient()
    private var apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // User profile and preferences
    private var userProfile: UserProfile
    private var conversationHistory: [Message] = []
    
    private init() {
        // Load API key from AppConfig (which reads from Info.plist)
        self.apiKey = AppConfig.apiKey
        
        if !apiKey.isEmpty {
            print("✅ OpenAIClient: API Key loaded successfully from AppConfig")
        } else {
            print("❌ OpenAIClient: Failed to load API key from AppConfig")
        }
        
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
    
    // MARK: - Helper Methods
    private func reloadAPIKey() {
        self.apiKey = AppConfig.apiKey
        if !apiKey.isEmpty {
            print("✅ OpenAIClient: API Key reloaded successfully from AppConfig")
        } else {
            print("❌ OpenAIClient: Failed to reload API key from AppConfig")
        }
    }
    
    // MARK: - Coaching Methods
    func sendMessage(prompt: String, context: WorkoutContext? = nil, userData: UserDataContext? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        // Ensure API key is loaded
        if apiKey.isEmpty {
            print("⚠️ OpenAIClient: API key is empty, attempting to reload...")
            reloadAPIKey()
        }
        
        guard !apiKey.isEmpty else {
            print("❌ OpenAIClient: No API key available for request")
            completion(.failure(NSError(domain: "OpenAIClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])))
            return
        }
        
        print("🔑 OpenAIClient: Using API key: \(String(apiKey.prefix(8)))...")
        
        let messages = buildMessageHistory(prompt: prompt, context: context, userData: userData)
        
        // Debug: Print the actual prompt being sent to OpenAI
        if let systemMessage = messages.first {
            print("🤖 OPENAI SYSTEM PROMPT:")
            print(systemMessage.content)
            print("🤖 END SYSTEM PROMPT")
        }
        
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
            max_tokens: isComplexRequest ? 3000 : 1500, // Reduced for faster responses
            temperature: 0.8 // Balanced creativity and speed
        )
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20 // Faster timeout for quicker responses
        
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
    private func buildMessageHistory(prompt: String, context: WorkoutContext?, userData: UserDataContext?) -> [Message] {
        // Enhanced system message with full fitness, nutrition, and vision-based coaching capabilities
        let systemPrompt = """
        You are Rex, an elite AI fitness coach and nutritionist. You're NOT a generic chatbot - you're a real coach who adapts to each user's unique situation.
        You also have computer vision capabilities and can SEE people working out in real-time to provide instant coaching feedback.
        
        🎯 CORE PRINCIPLE: Every response should be PERSONALIZED and CONTEXTUAL. Don't give generic answers like "What's your fitness focus today?" unless the user specifically asks for general guidance.
        
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
        
        📝 MEAL PLAN STYLE:
        - For meal plans, write in flowing paragraphs, not lists
        - Describe meals naturally: "For breakfast, I'd suggest starting with oatmeal topped with berries"
        - Use casual language: "throw in some chicken" instead of "include protein sources"
        - Make it sound like you're personally recommending these meals
        
        💪 HEALTH & WELLNESS:
        - Sleep optimization
        - Stress management and recovery
        - Mental health and motivation
        - Injury prevention
        - Mobility and flexibility
        - Posture correction
        - Lifestyle optimization
        
        👁️ VISION-BASED COACHING (Real-Time):
        - You receive real-time data about joint positions, movement phases, and form quality
        - You can detect specific issues like knee valgus, spinal flexion, poor stability
        - You see the exercise phase (starting, descent, bottom, ascent, rest)
        - You know the rep count and form scores
        - When providing vision-based coaching, speak like you're standing right behind them watching
        - Be specific about what you see: "I can see your left knee caving inward..."
        - Give immediate, actionable corrections for real-time feedback
        
        🎯 RESPONSE STYLE:
        - ANALYZE the user's question first - what are they REALLY asking?
        - If they ask about a specific topic, dive deep into that area
        - If they ask for general advice, ask clarifying questions to make it personal
        - Be motivational and supportive
        - Adapt to user's experience level and goals
        - Include safety warnings when necessary
        - Provide progression strategies and alternatives
        - NEVER give generic, one-size-fits-all responses
        - For real-time coaching: Keep responses under 2 sentences and conversational
        - Never use scary words like "DANGER" - be supportive but clear
        
        🗣️ CONVERSATION STYLE:
        - Talk like a real human coach, NOT a chatbot
        - NEVER use asterisks (*) or bullet points (-) in your responses
        - Write in flowing, natural sentences like you're talking to a friend
        - Use contractions: "I'm", "you're", "we'll", "that's"
        - Keep it conversational and warm, not robotic or formal
        - For meal plans: Give practical, simple suggestions without formatting
        - For workouts: Explain exercises naturally, like you're describing them in person
        
        🎯 SAFETY FIRST (Vision Coaching):
        - If you see dangerous form (knee valgus, spinal flexion), address it immediately
        - Use gentle language: "Let's focus on keeping your back straight" not "DANGER!"
        - Suggest modifications if needed: "Maybe try a lighter weight to perfect your form"
        
        User Profile:
        - Level: \(userProfile.fitnessLevel.rawValue)
        - Goals: \(userProfile.goals.map { $0.rawValue }.joined(separator: ", "))
        - Coach Style: \(userProfile.preferences.coachStyle.rawValue)
        - Context: \(context?.description ?? "General fitness consultation")
        
        📊 REAL-TIME USER DATA ACCESS:
        - You have access to the user's current activity data, workout history, and profile
        - When discussing progress, reference their actual workout sessions and form scores
        - Use their real calorie burn, step count, and activity rings data
        - Reference their actual height, weight, age, and fitness level from their profile
        - Remember their previous conversations and provide personalized follow-ups
        - Connect current workout data to their long-term goals and progress

        REMEMBER: You're a real coach having a real conversation. Make every response count and personal. When watching someone work out, give immediate, specific, encouraging coaching based on what you see.
        """
        
        // Add real user data to the prompt if available
        var enhancedPrompt = systemPrompt
        
        if let userData = userData {
            enhancedPrompt += "\n\n📊 CURRENT USER DATA:\n"
            
            if let profile = userData.profile {
                enhancedPrompt += "- Name: \(profile.personalInfo.name.isEmpty ? "Not set" : profile.personalInfo.name)\n"
                enhancedPrompt += "- Age: \(profile.personalInfo.age)\n"
                enhancedPrompt += "- Height: \(Int(profile.personalInfo.height))cm\n"
                enhancedPrompt += "- Weight: \(Int(profile.personalInfo.weight))kg\n"
                enhancedPrompt += "- BMI: \(String(format: "%.1f", profile.personalInfo.bmi)) (\(profile.personalInfo.bmiCategory))\n"
                enhancedPrompt += "- Fitness Level: \(profile.fitnessProfile.fitnessLevel.rawValue)\n"
                enhancedPrompt += "- Primary Goal: \(profile.fitnessProfile.primaryGoal.rawValue)\n"
                enhancedPrompt += "- Experience: \(profile.fitnessProfile.experience.rawValue)\n"
                enhancedPrompt += "- Workout Frequency: \(profile.fitnessProfile.workoutFrequency.rawValue)\n"
                enhancedPrompt += "- Available Time: \(profile.fitnessProfile.availableTime) minutes\n"
                enhancedPrompt += "- Preferred Coach Style: \(profile.preferences.coachStyle.rawValue)\n"
                enhancedPrompt += "- Primary Interest: \(profile.preferences.primaryInterest.rawValue)\n"
                
                // Add goals context
                if !profile.goals.shortTermGoals.isEmpty {
                    enhancedPrompt += "- Current Goals: \(profile.goals.shortTermGoals.prefix(3).map { $0.title }.joined(separator: ", "))\n"
                }
                
                // Add progress context
                enhancedPrompt += "- Workout Streak: \(profile.progress.workoutStreak) days\n"
                enhancedPrompt += "- Total Workouts: \(profile.progress.totalWorkouts)\n"
                enhancedPrompt += "- Average Form Score: \(String(format: "%.1f", profile.progress.averageFormScore))%\n"
                
                // Add last interaction context
                let daysSinceLastInteraction = Calendar.current.dateComponents([.day], from: profile.lastUpdated, to: Date()).day ?? 0
                if daysSinceLastInteraction == 0 {
                    enhancedPrompt += "- Last Interaction: Today\n"
                } else if daysSinceLastInteraction == 1 {
                    enhancedPrompt += "- Last Interaction: Yesterday\n"
                } else {
                    enhancedPrompt += "- Last Interaction: \(daysSinceLastInteraction) days ago\n"
                }
            }
            
            // Always add health data section (even if healthData is nil)
            enhancedPrompt += "\n📊 TODAY'S HEALTH DATA:\n"
            enhancedPrompt += "- Calories Burned: \(formatNumber(userData.todayCalories)) (direct from HealthKit)\n"
            enhancedPrompt += "- Steps Taken: \(formatNumber(userData.todaySteps)) (direct from HealthKit)\n"
            enhancedPrompt += "- Distance Walked: \(String(format: "%.2f", userData.todayDistance)) miles\n"
            enhancedPrompt += "- Move Goal: \(userData.moveGoal) calories\n"
            enhancedPrompt += "- Average Form Score: \(userData.averageFormScore)%\n"
            
            if let healthData = userData.healthData {
                enhancedPrompt += "- Activity Rings: Move \(Int(healthData.moveRingProgress * 100))%, Exercise \(Int(healthData.exerciseRingProgress * 100))%, Stand \(Int(healthData.standRingProgress * 100))%\n"
                
                // Add health insights
                let healthInsights = healthData.getHealthInsights()
                if !healthInsights.isEmpty {
                    enhancedPrompt += "- Health Insights: \(healthInsights.joined(separator: " "))\n"
                }
            }
            
            // Add specific guidance for HealthKit data access
            if userData.todayCalories == 0 && userData.todaySteps == 0 {
                enhancedPrompt += "- HEALTH DATA STATUS: ⚠️ No activity data available. This could mean:\n"
                enhancedPrompt += "  * User hasn't granted HealthKit permissions\n"
                enhancedPrompt += "  * No activity has been recorded today\n"
                enhancedPrompt += "  * HealthKit data isn't syncing properly\n"
                enhancedPrompt += "- RESPONSE GUIDANCE: If user asks about calories/steps, explain that you need HealthKit access and guide them to enable it in Settings > Privacy & Security > Health > PeakSet\n"
            } else {
                enhancedPrompt += "- HEALTH DATA STATUS: ✅ Real-time HealthKit data is available and being used\n"
                enhancedPrompt += "- IMPORTANT: You CAN and SHOULD use this EXACT data to answer questions about calories, steps, distance, etc.\n"
                enhancedPrompt += "- CRITICAL: Use the exact numbers shown above - do not estimate or guess. If user asks about steps, tell them the exact number: \(formatNumber(userData.todaySteps)) steps.\n"
            }
            
            // Add AI Coach Feedback if available
            if let feedback = userData.aiCoachFeedback {
                enhancedPrompt += "\n🤖 AI COACH ANALYSIS:\n"
                enhancedPrompt += "- Overall Score: \(feedback.overallScore)%\n"
                enhancedPrompt += "- Improvement Trend: \(feedback.improvementTrend)\n"
                
                if !feedback.whatsWorkingWell.isEmpty {
                    enhancedPrompt += "- What's Working Well: \(feedback.whatsWorkingWell.joined(separator: ", "))\n"
                }
                
                if !feedback.areasToFocusOn.isEmpty {
                    enhancedPrompt += "- Areas to Focus On: \(feedback.areasToFocusOn.joined(separator: ", "))\n"
                }
                
                if !feedback.nextSessionRecommendations.isEmpty {
                    enhancedPrompt += "- Next Session Recommendations: \(feedback.nextSessionRecommendations.joined(separator: ", "))\n"
                }
            }
            
            if !userData.workoutSessions.isEmpty {
                enhancedPrompt += "- Recent Workouts: \(userData.workoutSessions.count) sessions\n"
                let recentSessions = userData.workoutSessions.prefix(3)
                for session in recentSessions {
                    let exerciseNames = session.exercises.joined(separator: ", ")
                    enhancedPrompt += "  * \(exerciseNames): \(session.intensity)/10 intensity, \(Int(session.duration/60)) min, Notes: \(session.notes)\n"
                }
            }
            
            if !userData.conversationHistory.isEmpty {
                enhancedPrompt += "- Previous conversations: \(userData.conversationHistory.count) messages\n"
                
                // Add recent conversation context
                let recentMessages = userData.conversationHistory.suffix(6) // Last 3 exchanges
                if !recentMessages.isEmpty {
                    enhancedPrompt += "- Recent conversation topics:\n"
                    for message in recentMessages {
                        let type = message.isUser ? "User" : "Rex"
                        let preview = String(message.text.prefix(50))
                        enhancedPrompt += "  * \(type): \(preview)...\n"
                    }
                }
            }
            
            enhancedPrompt += "\nUse this real data to provide personalized, specific advice. Reference their actual progress and numbers when giving recommendations. Remember what you've discussed before and build on previous conversations."
        }
        
        let finalSystemPrompt = enhancedPrompt + """
        
        💬 RESPONSE GUIDELINES:
        - Start with what you observe: "I can see..." or "I notice..."
        - Be specific about the issue: "your left knee is drifting inward"
        - Give clear, actionable advice: "Try to 'spread the floor' with your feet"
        - Keep it encouraging: "You're doing great, just need a small adjustment"
        - Keep responses under 2 sentences for real-time coaching
        - Never use scary words like "DANGER" - be supportive but clear
        
        🎯 SAFETY FIRST:
        - If you see dangerous form (knee valgus, spinal flexion), address it immediately
        - Use gentle language: "Let's focus on keeping your back straight" not "DANGER!"
        - Suggest modifications if needed: "Maybe try a lighter weight to perfect your form"
        
        User Profile:
        - Level: \(userProfile.fitnessLevel.rawValue)
        - Goals: \(userProfile.goals.map { $0.rawValue }.joined(separator: ", "))
        - Coach Style: \(userProfile.preferences.coachStyle.rawValue)
        - Context: \(context?.description ?? "Real-time form coaching")

        REMEMBER: You're watching them work out live. Give immediate, specific, encouraging coaching based on what you see.
        """
        
        let systemMessage = Message(role: "system", content: finalSystemPrompt)
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
    
    // MARK: - Helper Functions
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
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
