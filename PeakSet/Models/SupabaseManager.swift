import Foundation
import Supabase
import Vision

// Type alias to avoid conflict with app's User model
typealias SupabaseUser = Supabase.User

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    private let supabase: SupabaseClient
    @Published var currentUser: SupabaseUser?
    @Published var isSignedIn = false
    @Published var sessionCheckComplete = false
    
    private init() {
        print("🚀 SupabaseManager: Initializing...")
        
        // Initialize Supabase client (session persistence is enabled by default)
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: AppConfig.supabaseURL)!,
            supabaseKey: AppConfig.supabaseAnonKey
        )
        
        print("✅ SupabaseManager: Client initialized")
        
        // Check for existing session on startup
        Task {
            await restoreSession()
        }
    }
    
    // MARK: - Authentication Methods
    
    func restoreSession() async {
        print("🔄 SupabaseManager: Attempting to restore session...")
        do {
            // Try to get the current session
            let session = try await supabase.auth.session
            
            print("✅ SupabaseManager: Session found!")
            print("   User ID: \(session.user.id)")
            print("   User Email: \(session.user.email ?? "no email")")
            print("   Access Token: \(session.accessToken.prefix(20))...")
            
            await MainActor.run {
                self.currentUser = session.user
                self.isSignedIn = true
                self.sessionCheckComplete = true
            }
            print("✅ SupabaseManager: Session restored successfully for user: \(session.user.email ?? "unknown")")
        } catch {
            print("❌ SupabaseManager: Failed to restore session")
            print("   Error: \(error)")
            print("   Error description: \(error.localizedDescription)")
            
            await MainActor.run {
                self.currentUser = nil
                self.isSignedIn = false
                self.sessionCheckComplete = true
            }
        }
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        let response = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        
        await MainActor.run {
            self.currentUser = response.user
            self.isSignedIn = true
        }
    }
    
    func signUpWithEmail(email: String, password: String, fullName: String) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
        
        await MainActor.run {
            self.currentUser = response.user
            self.isSignedIn = true
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        let response = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        await MainActor.run {
            self.currentUser = response.user
            self.isSignedIn = true
        }
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        
        await MainActor.run {
            self.currentUser = nil
            self.isSignedIn = false
        }
    }
    
    
    func getCurrentUser() -> SupabaseUser? {
        return currentUser
    }
    
    // MARK: - Profile Management
    
    func saveUserProfile(_ profile: SupabaseUserProfile) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }
        
        let profileData = UserProfileData(
            id: userId.uuidString,
            email: profile.email,
            name: profile.name,
            height: profile.height,
            weight: profile.weight,
            age: profile.age,
            unitSystem: profile.unitSystem.rawValue,
            fitnessLevel: profile.fitnessLevel.rawValue,
            primaryGoal: profile.primaryGoal.rawValue,
            experience: profile.experience.rawValue,
            workoutFrequency: profile.workoutFrequency.rawValue,
            notificationsEnabled: profile.notificationsEnabled,
            dataSharingEnabled: profile.dataSharingEnabled,
            moveGoal: profile.moveGoal,
            createdAt: profile.createdAt.ISO8601Format()
        )
        
        try await supabase
            .from("user_profiles")
            .upsert(profileData)
            .execute()
    }
    
    func loadUserProfile() async throws -> SupabaseUserProfile? {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }
        
        let response: [UserProfileData] = try await supabase
            .from("user_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        
        guard let profileData = response.first else {
            return nil
        }
        
        return SupabaseUserProfile(
            name: profileData.name ?? "",
            email: profileData.email ?? "",
            height: profileData.height ?? 170.0,
            weight: profileData.weight ?? 70.0,
            age: profileData.age ?? 25,
            unitSystem: UnitSystem(rawValue: profileData.unitSystem ?? "Metric") ?? .metric,
            fitnessLevel: FitnessLevel(rawValue: profileData.fitnessLevel ?? "Intermediate") ?? .intermediate,
            primaryGoal: FitnessGoal(rawValue: profileData.primaryGoal ?? "Strength") ?? .strength,
            experience: ExperienceLevel(rawValue: profileData.experience ?? "Intermediate") ?? .intermediate,
            workoutFrequency: WorkoutFrequency(rawValue: profileData.workoutFrequency ?? "3x per week") ?? .threeTimesPerWeek,
            notificationsEnabled: profileData.notificationsEnabled ?? true,
            dataSharingEnabled: profileData.dataSharingEnabled ?? true,
            moveGoal: profileData.moveGoal,
            createdAt: profileData.createdAt?.toDate() ?? Date()
        )
    }
    
    // MARK: - Workout Data Collection
    
    func saveWorkoutSession(
        exercise: Exercise,
        startTime: Date,
        endTime: Date,
        totalReps: Int,
        goodReps: Int,
        averageFormScore: Float,
        repAnalysis: [FormAnalyzer.RepAnalysis],
        safetyIssues: [FormAnalyzer.SafetyIssue],
        formImprovements: [FormAnalyzer.FormImprovement],
        aiCoachingHistory: [String],
        overallAssessment: String
    ) async throws {
        
        guard let userId = currentUser?.id else {
            print("❌ SupabaseManager: Cannot save workout - user not authenticated")
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("💾 SupabaseManager: Saving workout session...")
        print("   - Exercise: \(exercise.name)")
        print("   - Reps: \(totalReps) total, \(goodReps) good")
        print("   - Avg Form: \(Int(averageFormScore * 100))%")
        
        // Match ACTUAL Supabase schema columns
        struct WorkoutSessionInsert: Encodable {
            let user_id: String
            let exercise: String
            let exercise_type: String
            let start_time: String
            let end_time: String
            let duration: Int              // Base schema
            let duration_seconds: Int       // Added column
            let total_reps: Int
            let good_reps: Int
            let average_form_score: Double
            let notes: String?              // For detailed JSON data
            let ai_feedback: String?        // Base schema column
        }
        
        // Encode complex data as JSON strings
        let repAnalysisJSON = try String(data: JSONEncoder().encode(repAnalysis), encoding: .utf8) ?? "[]"
        let safetyIssuesJSON = try String(data: JSONEncoder().encode(safetyIssues), encoding: .utf8) ?? "[]"
        let formImprovementsJSON = try String(data: JSONEncoder().encode(formImprovements), encoding: .utf8) ?? "[]"
        
        // Combine detailed data into notes field
        let notesData: [String: Any] = [
            "rep_analysis": repAnalysisJSON,
            "safety_issues": safetyIssuesJSON,
            "form_improvements": formImprovementsJSON,
            "coaching_history": aiCoachingHistory
        ]
        let notesJSON = try String(data: JSONSerialization.data(withJSONObject: notesData), encoding: .utf8)
        
        let session = WorkoutSessionInsert(
            user_id: userId.uuidString,
            exercise: exercise.name,
            exercise_type: exercise.name,
            start_time: startTime.ISO8601Format(),
            end_time: endTime.ISO8601Format(),
            duration: Int(endTime.timeIntervalSince(startTime)),
            duration_seconds: Int(endTime.timeIntervalSince(startTime)),
            total_reps: totalReps,
            good_reps: goodReps,
            average_form_score: Double(averageFormScore),
            notes: notesJSON,
            ai_feedback: overallAssessment  // Overall assessment as AI feedback
        )
        
        do {
            try await supabase
                .from("workout_sessions")
                .insert(session)
                .execute()
            
            print("✅ SupabaseManager: Workout session saved to database!")
        } catch {
            print("❌ SupabaseManager: Failed to save workout session: \(error)")
            throw error
        }
    }
    
    // MARK: - Conversation History Management
    
    /// Save a conversation message to the database
    func saveConversationMessage(
        messageText: String,
        isUserMessage: Bool,
        messageType: String = "response",
        sessionId: UUID? = nil
    ) async throws {
        
        guard let userId = currentUser?.id else {
            print("❌ SupabaseManager: Cannot save conversation - user not authenticated")
            return
        }
        
        print("💾 SupabaseManager: Saving conversation message...")
        print("   - User: \(isUserMessage ? "User" : "AI")")
        print("   - Type: \(messageType)")
        print("   - Text: \(messageText.prefix(50))...")
        
        struct ConversationInsert: Encodable {
            let user_id: String
            let message_text: String
            let is_user_message: Bool
            let message_type: String
            let session_id: String?
        }
        
        let conversation = ConversationInsert(
            user_id: userId.uuidString,
            message_text: messageText,
            is_user_message: isUserMessage,
            message_type: messageType,
            session_id: sessionId?.uuidString
        )
        
        do {
            try await supabase
                .from("conversation_history")
                .insert(conversation)
                .execute()
            
            print("✅ SupabaseManager: Conversation message saved!")
        } catch {
            print("❌ SupabaseManager: Failed to save conversation: \(error)")
            throw error
        }
    }
    
    /// Get conversation history for the current user
    func getConversationHistory(limit: Int = 50) async throws -> [[String: Any]] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }
        
        let result = try await supabase
            .from("conversation_history")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .order("timestamp", ascending: false)
            .limit(limit)
            .execute()
        
        // Convert Data to [[String: Any]]
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: result.data)
            return jsonObject as? [[String: Any]] ?? []
        } catch {
            print("❌ SupabaseManager: Failed to parse conversation history: \(error)")
            return []
        }
    }
    
    // MARK: - AI Coaching Feedback Management
    
    /// Save AI coaching feedback to the database
    func saveAICoachingFeedback(
        feedback: AICoachFeedback.CoachFeedback,
        workoutSessionId: String? = nil
    ) async throws {
        
        guard let userId = currentUser?.id else {
            print("❌ SupabaseManager: Cannot save AI coaching feedback - user not authenticated")
            return
        }
        
        print("💾 SupabaseManager: Saving AI coaching feedback...")
        print("   - Overall Score: \(feedback.overallScore)%")
        print("   - Trend: \(feedback.improvementTrend)")
        
        // Match ACTUAL Supabase schema for ai_coaching_feedback
        // Required: feedback_text (NOT NULL)
        // Optional: All our custom fields
        struct AICoachingFeedbackInsert: Encodable {
            let user_id: String
            let session_id: String?
            let feedback_type: String
            let feedback_text: String  // REQUIRED by schema
            let feedback_category: String
            let workout_session_id: String?
            let overall_score: Int
            let improvement_trend: String
            let whats_working_well: String
            let areas_to_focus_on: String
            let recommendations: String
            let feedback_date: String
        }
        
        // Create comprehensive feedback text from all insights
        let feedbackText = """
        Overall Score: \(feedback.overallScore)%
        Trend: \(feedback.improvementTrend.rawValue)
        
        What's Working Well:
        \(feedback.whatsWorkingWell.joined(separator: "\n- "))
        
        Areas to Focus On:
        \(feedback.areasToFocusOn.joined(separator: "\n- "))
        
        Recommendations:
        \(feedback.nextSessionRecommendations.joined(separator: "\n- "))
        """
        
        let coachingFeedback = AICoachingFeedbackInsert(
            user_id: userId.uuidString,
            session_id: workoutSessionId,
            feedback_type: "workout_summary",
            feedback_text: feedbackText,
            feedback_category: "form_analysis",
            workout_session_id: workoutSessionId,
            overall_score: feedback.overallScore,
            improvement_trend: feedback.improvementTrend.rawValue,
            whats_working_well: feedback.whatsWorkingWell.joined(separator: "|"),
            areas_to_focus_on: feedback.areasToFocusOn.joined(separator: "|"),
            recommendations: feedback.nextSessionRecommendations.joined(separator: "|"),
            feedback_date: feedback.lastUpdated.ISO8601Format()
        )
        
        do {
            try await supabase
                .from("ai_coaching_feedback")
                .insert(coachingFeedback)
                .execute()
            
            print("✅ SupabaseManager: AI coaching feedback saved!")
        } catch {
            print("❌ SupabaseManager: Failed to save AI coaching feedback: \(error)")
            throw error
        }
    }
    
    // MARK: - Exercise Reps Management
    
    /// Save individual rep analysis to the database
    func saveExerciseReps(
        reps: [FormAnalyzer.RepAnalysis],
        workoutSessionId: String
    ) async throws {
        
        guard let userId = currentUser?.id else {
            print("❌ SupabaseManager: Cannot save exercise reps - user not authenticated")
            return
        }
        
        print("💾 SupabaseManager: Saving \(reps.count) exercise reps...")
        
        struct ExerciseRepInsert: Encodable {
            let user_id: String
            let workout_session_id: String
            let rep_number: Int
            let set_number: Int
            let form_score: Double
            let phase: String
            let issues: String
            let duration_seconds: Double
            let keypoints_data: String?
            let rep_timestamp: String
        }
        
        let repInserts = reps.map { rep in
            ExerciseRepInsert(
                user_id: userId.uuidString,
                workout_session_id: workoutSessionId,
                rep_number: rep.repNumber,
                set_number: 1, // Default to set 1 for now
                form_score: Double(rep.score),
                phase: rep.phase.rawValue,
                issues: rep.issues.joined(separator: "|"),
                duration_seconds: rep.duration,
                keypoints_data: rep.keypointsData,
                rep_timestamp: rep.timestamp.ISO8601Format()
            )
        }
        
        do {
            try await supabase
                .from("exercise_reps")
                .insert(repInserts)
                .execute()
            
            print("✅ SupabaseManager: Exercise reps saved!")
        } catch {
            print("❌ SupabaseManager: Failed to save exercise reps: \(error)")
            throw error
        }
    }
    
    // MARK: - Health Metrics Management
    
    /// Save daily health metrics (calories, steps, heart rate, etc.)
    func saveDailyHealthMetrics(
        date: Date,
        calories: Int,
        steps: Int,
        distance: Double,
        exerciseMinutes: Int,
        standHours: Int,
        heartRate: Double,
        moveGoal: Int,
        exerciseGoal: Int,
        standGoal: Int,
        moveRingProgress: Double,
        exerciseRingProgress: Double,
        standRingProgress: Double
    ) async throws {
        
        guard let userId = currentUser?.id else {
            print("❌ SupabaseManager: Cannot save health metrics - user not authenticated")
            return
        }
        
        print("💾 SupabaseManager: Saving daily health metrics...")
        print("   - Date: \(date)")
        print("   - Calories: \(calories), Steps: \(steps), Distance: \(String(format: "%.2f", distance))km")
        print("   - Exercise: \(exerciseMinutes)min, Stand: \(standHours)hrs")
        
        struct DailyHealthMetricsInsert: Encodable {
            let user_id: String
            let date: String
            let calories_burned: Int
            let steps_count: Int
            let distance_km: Double
            let exercise_minutes: Int
            let stand_hours: Int
            let heart_rate_avg: Double
            let move_goal: Int
            let exercise_goal: Int
            let stand_goal: Int
            let move_ring_progress: Double
            let exercise_ring_progress: Double
            let stand_ring_progress: Double
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let metricsData = DailyHealthMetricsInsert(
            user_id: userId.uuidString,
            date: dateString,
            calories_burned: calories,
            steps_count: steps,
            distance_km: distance,
            exercise_minutes: exerciseMinutes,
            stand_hours: standHours,
            heart_rate_avg: heartRate,
            move_goal: moveGoal,
            exercise_goal: exerciseGoal,
            stand_goal: standGoal,
            move_ring_progress: moveRingProgress,
            exercise_ring_progress: exerciseRingProgress,
            stand_ring_progress: standRingProgress
        )
        
        do {
            // Check if entry exists for today
            let existing = try await supabase
                .from("daily_health_metrics")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("date", value: dateString)
                .execute()
            
            let existingData = try? JSONSerialization.jsonObject(with: existing.data) as? [[String: Any]]
            
            if existingData?.isEmpty == false {
                // Update existing entry
                try await supabase
                    .from("daily_health_metrics")
                    .update(metricsData)
                    .eq("user_id", value: userId.uuidString)
                    .eq("date", value: dateString)
                    .execute()
                print("✅ SupabaseManager: Daily health metrics updated!")
            } else {
                // Insert new entry
                try await supabase
                    .from("daily_health_metrics")
                    .insert(metricsData)
                    .execute()
                print("✅ SupabaseManager: Daily health metrics saved!")
            }
        } catch {
            print("❌ SupabaseManager: Failed to save health metrics: \(error)")
            throw error
        }
    }
    
    // MARK: - User Progress Management
    
    /// Update user progress tracking for a specific exercise
    func updateUserProgress(
        exerciseType: String,
        sessionCompleted: Bool,
        reps: Int,
        formScore: Double,
        targetSessionsPerWeek: Int = 3,
        targetFormScore: Double = 0.80
    ) async throws {
        
        guard let userId = currentUser?.id else {
            print("❌ SupabaseManager: Cannot update progress - user not authenticated")
            return
        }
        
        print("💾 SupabaseManager: Updating user progress for \(exerciseType)...")
        
        // First, try to get existing progress
        let existingProgress = try await supabase
            .from("user_progress")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .eq("exercise_type", value: exerciseType)
            .execute()
        
        let progressData = try? JSONSerialization.jsonObject(with: existingProgress.data) as? [[String: Any]]
        let existing = progressData?.first
        
        // Calculate new values
        let totalSessions = (existing?["total_sessions"] as? Int ?? 0) + (sessionCompleted ? 1 : 0)
        let totalReps = (existing?["total_reps"] as? Int ?? 0) + reps
        let oldAvgScore = existing?["average_form_score"] as? Double ?? 0.0
        let newAvgScore = oldAvgScore > 0 ? (oldAvgScore + formScore) / 2.0 : formScore
        let bestScore = max(existing?["best_form_score"] as? Double ?? 0.0, formScore)
        
        // Calculate improvement rate (compared to average)
        let improvementRate = oldAvgScore > 0 ? ((formScore - oldAvgScore) / oldAvgScore) * 100 : 0.0
        
        // Calculate streak
        let lastWorkoutDateStr = existing?["last_workout_date"] as? String
        let currentStreak = calculateWorkoutStreak(lastWorkoutDate: lastWorkoutDateStr)
        let longestStreak = max(existing?["longest_streak_days"] as? Int ?? 0, currentStreak)
        
        // Check if goal achieved
        let goalAchieved = newAvgScore >= targetFormScore
        
        struct UserProgressUpsert: Encodable {
            let user_id: String
            let exercise_type: String
            let total_sessions: Int
            let total_reps: Int
            let average_form_score: Double
            let best_form_score: Double
            let improvement_rate: Double
            let current_streak_days: Int
            let longest_streak_days: Int
            let last_workout_date: String
            let target_sessions_per_week: Int
            let target_form_score: Double
            let goal_achieved: Bool
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        let progressUpdate = UserProgressUpsert(
            user_id: userId.uuidString,
            exercise_type: exerciseType,
            total_sessions: totalSessions,
            total_reps: totalReps,
            average_form_score: newAvgScore,
            best_form_score: bestScore,
            improvement_rate: improvementRate,
            current_streak_days: currentStreak,
            longest_streak_days: longestStreak,
            last_workout_date: todayString,
            target_sessions_per_week: targetSessionsPerWeek,
            target_form_score: targetFormScore,
            goal_achieved: goalAchieved
        )
        
        do {
            // Check if progress entry exists for this exercise
            if existing != nil {
                // Update existing entry
                try await supabase
                    .from("user_progress")
                    .update(progressUpdate)
                    .eq("user_id", value: userId.uuidString)
                    .eq("exercise_type", value: exerciseType)
                    .execute()
            } else {
                // Insert new entry
                try await supabase
                    .from("user_progress")
                    .insert(progressUpdate)
                    .execute()
            }
            
            print("✅ SupabaseManager: User progress updated!")
            print("   - Total Sessions: \(totalSessions), Total Reps: \(totalReps)")
            print("   - Avg Score: \(Int(newAvgScore * 100))%, Best: \(Int(bestScore * 100))%")
            print("   - Streak: \(currentStreak) days, Improvement: \(String(format: "%.1f", improvementRate))%")
        } catch {
            print("❌ SupabaseManager: Failed to update user progress: \(error)")
            throw error
        }
    }
    
    /// Calculate workout streak based on last workout date
    private func calculateWorkoutStreak(lastWorkoutDate: String?) -> Int {
        guard let lastDateStr = lastWorkoutDate,
              let lastDate = ISO8601DateFormatter().date(from: lastDateStr + "T00:00:00Z") else {
            return 1 // First workout
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastWorkout = calendar.startOfDay(for: lastDate)
        
        let daysBetween = calendar.dateComponents([.day], from: lastWorkout, to: today).day ?? 0
        
        if daysBetween == 0 {
            // Same day workout
            return 1
        } else if daysBetween == 1 {
            // Consecutive day - streak continues
            return 1 // Will be incremented by caller
        } else {
            // Streak broken
            return 1
        }
    }
    
    func uploadTrainingData(
        exercise: Exercise,
        keypoints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        formScore: Float,
        safetyIssues: [FormAnalyzer.SafetyIssue],
        userDemographics: [String: Any]
    ) async throws {
        
        guard let userId = currentUser?.id else {
            print("❌ SupabaseManager: Cannot upload training data - user not authenticated")
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("💾 SupabaseManager: Uploading training data for \(exercise.name)...")
        
        // Codable structure for keypoint data
        struct KeypointData: Codable {
            let joint: String
            let x: Double
            let y: Double
            let confidence: Double
        }
        
        // Create Codable structure for training data
        struct TrainingDataInsert: Encodable {
            let user_id: String
            let exercise_type: String
            let keypoints_json: String
            let form_score: Double
            let safety_issues_json: String
            let user_age: Int?
            let user_height_cm: Double?
            let user_weight_kg: Double?
            let user_fitness_level: String?
            let expert_validated: Bool
            let is_synthetic: Bool
        }
        
        // Encode keypoints as JSON string
        let keypointsArray = keypoints.map { joint, point in
            KeypointData(
                joint: String(describing: joint),
                x: Double(point.x),
                y: Double(point.y),
                confidence: 0.9
            )
        }
        let keypointsJSON = try String(data: JSONEncoder().encode(keypointsArray), encoding: .utf8) ?? "[]"
        let safetyIssuesJSON = try String(data: JSONEncoder().encode(safetyIssues), encoding: .utf8) ?? "[]"
        
        let trainingData = TrainingDataInsert(
            user_id: userId.uuidString,
            exercise_type: exercise.name,
            keypoints_json: keypointsJSON,
            form_score: Double(formScore),
            safety_issues_json: safetyIssuesJSON,
            user_age: userDemographics["age"] as? Int,
            user_height_cm: userDemographics["height"] as? Double,
            user_weight_kg: userDemographics["weight"] as? Double,
            user_fitness_level: userDemographics["fitness_level"] as? String,
            expert_validated: false,
            is_synthetic: false
        )
        
        do {
            try await supabase
                .from("training_data")
                .insert(trainingData)
                .execute()
            
            print("✅ SupabaseManager: Training data uploaded to database!")
        } catch {
            print("❌ SupabaseManager: Failed to upload training data: \(error)")
            throw error
        }
    }
}

// MARK: - Supporting Types

struct SupabaseUserProfile: Codable {
    let name: String
    let email: String
    let height: Double
    let weight: Double
    let age: Int
    let unitSystem: UnitSystem
    let fitnessLevel: FitnessLevel
    let primaryGoal: FitnessGoal
    let experience: ExperienceLevel
    let workoutFrequency: WorkoutFrequency
    let notificationsEnabled: Bool
    let dataSharingEnabled: Bool
    let moveGoal: Int?
    let createdAt: Date
}

struct UserProfileData: Codable {
    let id: String?
    let email: String?
    let name: String?
    let height: Double?
    let weight: Double?
    let age: Int?
    let unitSystem: String?
    let fitnessLevel: String?
    let primaryGoal: String?
    let experience: String?
    let workoutFrequency: String?
    let notificationsEnabled: Bool?
    let dataSharingEnabled: Bool?
    let moveGoal: Int?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, height, weight, age
        case unitSystem = "unit_system"
        case fitnessLevel = "fitness_level"
        case primaryGoal = "primary_goal"
        case experience, workoutFrequency = "workout_frequency"
        case notificationsEnabled = "notifications_enabled"
        case dataSharingEnabled = "data_sharing_enabled"
        case moveGoal = "move_goal"
        case createdAt = "created_at"
    }
}

extension String {
    func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)
    }
}

// SupabaseError is defined in Config.swift
