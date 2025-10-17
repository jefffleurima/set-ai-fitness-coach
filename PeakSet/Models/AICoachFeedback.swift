import Foundation
import HealthKit
import UserNotifications

/// AI Coach Feedback system that analyzes workout performance and provides insights
class AICoachFeedback: ObservableObject {
    @Published var feedback: CoachFeedback?
    @Published var isLoading = false
    
    struct CoachFeedback {
        let whatsWorkingWell: [String]
        let areasToFocusOn: [String]
        let nextSessionRecommendations: [String]
        let overallScore: Int
        let improvementTrend: ImprovementTrend
        let lastUpdated: Date
    }
    
    enum ImprovementTrend: String {
        case improving = "improving"
        case stable = "stable"
        case declining = "declining"
        case newUser = "newUser"
    }
    
    // MARK: - Main Analysis Function
    
    func generateFeedback(from workoutSessions: [WorkoutSession]) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let feedback = self?.analyzeWorkoutData(workoutSessions) ?? self?.getDefaultFeedback()
            
            DispatchQueue.main.async {
                self?.feedback = feedback
                self?.isLoading = false
                
                // Send notification when feedback is ready
                self?.sendWorkoutFeedbackNotification()
            }
        }
    }
    
    // MARK: - Vision-Based Workout Analysis
    
    func generateFeedbackFromVisionData(_ sessionData: FormAnalyzer.WorkoutSessionData, previousSessions: [WorkoutSession] = []) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let feedback = self?.analyzeVisionWorkoutData(sessionData, previousSessions: previousSessions) ?? self?.getDefaultFeedback()
            
            DispatchQueue.main.async {
                self?.feedback = feedback
                self?.isLoading = false
                
                // Send notification when feedback is ready
                self?.sendFormAnalysisNotification()
            }
        }
    }
    
    // MARK: - Data Analysis
    
    private func analyzeWorkoutData(_ sessions: [WorkoutSession]) -> CoachFeedback {
        guard !sessions.isEmpty else {
            return getDefaultFeedback()
        }
        
        // Analyze recent sessions (last 7 days)
        let recentSessions = sessions.filter { 
            Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.contains($0.date) == true 
        }
        
        // Calculate key metrics
        let formScores = sessions.map { $0.formScore }
        let averageFormScore = formScores.reduce(0, +) / formScores.count
        let totalReps = sessions.reduce(0) { $0 + $1.reps }
        let _ = sessions.reduce(0) { $0 + $1.sets } // Total sets calculated but not used in current analysis
        let perfectFormReps = sessions.filter { $0.formScore >= 95 }.reduce(0) { $0 + $1.reps }
        
        // Analyze trends
        let improvementTrend = analyzeImprovementTrend(sessions)
        
        // Generate insights
        let whatsWorkingWell = generateWhatsWorkingWell(
            averageFormScore: averageFormScore,
            totalReps: totalReps,
            perfectFormReps: perfectFormReps,
            sessions: recentSessions
        )
        
        let areasToFocusOn = generateAreasToFocusOn(
            averageFormScore: averageFormScore,
            totalReps: totalReps,
            perfectFormReps: perfectFormReps,
            sessions: recentSessions
        )
        
        let nextSessionRecommendations = generateNextSessionRecommendations(
            averageFormScore: averageFormScore,
            improvementTrend: improvementTrend,
            sessions: recentSessions
        )
        
        return CoachFeedback(
            whatsWorkingWell: whatsWorkingWell,
            areasToFocusOn: areasToFocusOn,
            nextSessionRecommendations: nextSessionRecommendations,
            overallScore: averageFormScore,
            improvementTrend: improvementTrend,
            lastUpdated: Date()
        )
    }
    
    private func analyzeVisionWorkoutData(_ sessionData: FormAnalyzer.WorkoutSessionData, previousSessions: [WorkoutSession]) -> CoachFeedback {
        // Use the comprehensive vision data for detailed analysis
        
        // Calculate key metrics from vision data
        let averageFormScore = Int(sessionData.averageFormScore * 100)
        let goodRepPercentage = sessionData.totalReps > 0 ? Float(sessionData.goodReps) / Float(sessionData.totalReps) : 0.0
        let perfectFormReps = sessionData.repAnalysis.filter { $0.score >= 0.95 }.count
        
        // Analyze trends from previous sessions
        let improvementTrend = analyzeImprovementTrendFromVision(sessionData, previousSessions: previousSessions)
        
        // Generate comprehensive insights using vision data
        let whatsWorkingWell = generateVisionBasedWhatsWorkingWell(
            sessionData: sessionData,
            averageFormScore: averageFormScore,
            goodRepPercentage: goodRepPercentage,
            perfectFormReps: perfectFormReps
        )
        
        let areasToFocusOn = generateVisionBasedAreasToFocusOn(
            sessionData: sessionData,
            averageFormScore: averageFormScore,
            goodRepPercentage: goodRepPercentage,
            perfectFormReps: perfectFormReps
        )
        
        let nextSessionRecommendations = generateVisionBasedNextSessionRecommendations(
            sessionData: sessionData,
            averageFormScore: averageFormScore,
            improvementTrend: improvementTrend,
            previousSessions: previousSessions
        )
        
        return CoachFeedback(
            whatsWorkingWell: whatsWorkingWell,
            areasToFocusOn: areasToFocusOn,
            nextSessionRecommendations: nextSessionRecommendations,
            overallScore: averageFormScore,
            improvementTrend: improvementTrend,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Insight Generation
    
    private func generateWhatsWorkingWell(
        averageFormScore: Int,
        totalReps: Int,
        perfectFormReps: Int,
        sessions: [WorkoutSession]
    ) -> [String] {
        var insights: [String] = []
        
        // Consistency analysis
        if sessions.count >= 3 {
            insights.append("Great consistency! You've completed \(sessions.count) workouts this week.")
        }
        
        // Form score analysis
        if averageFormScore >= 85 {
            insights.append("Excellent form quality with \(averageFormScore)% average score.")
        } else if averageFormScore >= 75 {
            insights.append("Good form consistency with \(averageFormScore)% average score.")
        }
        
        // Perfect form analysis
        let perfectFormPercentage = totalReps > 0 ? (perfectFormReps * 100) / totalReps : 0
        if perfectFormPercentage >= 30 {
            insights.append("\(perfectFormPercentage)% of your reps achieved perfect form!")
        }
        
        // Volume analysis
        if totalReps >= 50 {
            insights.append("Impressive volume with \(totalReps) total reps this week.")
        }
        
        // Exercise variety
        let uniqueExercises = Set(sessions.map { $0.exercise.name }).count
        if uniqueExercises >= 2 {
            insights.append("Good exercise variety with \(uniqueExercises) different exercises.")
        }
        
        return insights.isEmpty ? ["Keep up the great work!"] : insights
    }
    
    private func generateAreasToFocusOn(
        averageFormScore: Int,
        totalReps: Int,
        perfectFormReps: Int,
        sessions: [WorkoutSession]
    ) -> [String] {
        var insights: [String] = []
        
        // Form score analysis
        if averageFormScore < 75 {
            insights.append("Focus on form quality - current average is \(averageFormScore)%")
        } else if averageFormScore < 85 {
            insights.append("Form is good but can be improved from \(averageFormScore)% to 90%+")
        }
        
        // Perfect form analysis
        let perfectFormPercentage = totalReps > 0 ? (perfectFormReps * 100) / totalReps : 0
        if perfectFormPercentage < 20 {
            insights.append("Only \(perfectFormPercentage)% of reps achieved perfect form - focus on control")
        }
        
        // Consistency analysis
        if sessions.count < 2 {
            insights.append("Increase workout frequency - aim for 3+ sessions per week")
        }
        
        // Volume analysis
        if totalReps < 30 {
            insights.append("Consider increasing workout volume for better results")
        }
        
        // Exercise variety
        let uniqueExercises = Set(sessions.map { $0.exercise.name }).count
        if uniqueExercises < 2 {
            insights.append("Add more exercise variety to your routine")
        }
        
        return insights.isEmpty ? ["Continue focusing on consistency"] : insights
    }
    
    private func generateNextSessionRecommendations(
        averageFormScore: Int,
        improvementTrend: ImprovementTrend,
        sessions: [WorkoutSession]
    ) -> [String] {
        var recommendations: [String] = []
        
        // Form-based recommendations
        if averageFormScore < 80 {
            recommendations.append("Start with lighter weights to focus on perfect form")
            recommendations.append("Practice the movement pattern slowly before adding speed")
        } else if averageFormScore >= 85 {
            recommendations.append("Consider increasing weight or reps for progression")
        }
        
        // Trend-based recommendations
        switch improvementTrend {
        case .improving:
            recommendations.append("Great progress! Continue with your current approach")
        case .stable:
            recommendations.append("Try adding new exercises or increasing intensity")
        case .declining:
            recommendations.append("Focus on recovery and form fundamentals")
        case .newUser:
            recommendations.append("Start with bodyweight exercises to build foundation")
        }
        
        // Frequency recommendations
        if sessions.count < 3 {
            recommendations.append("Aim for 3 workouts this week for optimal results")
        }
        
        // Exercise-specific recommendations
        let lastExercise = sessions.first?.exercise.name.lowercased() ?? ""
        if lastExercise.contains("squat") {
            recommendations.append("Try adding deadlifts or lunges for lower body variety")
        } else if lastExercise.contains("deadlift") {
            recommendations.append("Consider adding squats or hip thrusts for comprehensive training")
        }
        
        return recommendations.isEmpty ? ["Keep up the consistent effort!"] : recommendations
    }
    
    // MARK: - Trend Analysis
    
    private func analyzeImprovementTrend(_ sessions: [WorkoutSession]) -> ImprovementTrend {
        guard sessions.count >= 3 else { return .newUser }
        
        // Sort sessions by date
        let sortedSessions = sessions.sorted { $0.date < $1.date }
        
        // Take first half and second half for comparison
        let midPoint = sortedSessions.count / 2
        let firstHalf = Array(sortedSessions.prefix(midPoint))
        let secondHalf = Array(sortedSessions.suffix(midPoint))
        
        let firstHalfAvg = firstHalf.map { $0.formScore }.reduce(0, +) / firstHalf.count
        let secondHalfAvg = secondHalf.map { $0.formScore }.reduce(0, +) / secondHalf.count
        
        let difference = secondHalfAvg - firstHalfAvg
        
        if difference > 5 {
            return .improving
        } else if difference < -5 {
            return .declining
        } else {
            return .stable
        }
    }
    
    // MARK: - Default Feedback
    
    private func getDefaultFeedback() -> CoachFeedback {
        return CoachFeedback(
            whatsWorkingWell: [
                "Welcome to your fitness journey!",
                "You're taking the first step towards better health"
            ],
            areasToFocusOn: [
                "Start with basic exercises to build foundation",
                "Focus on learning proper form first"
            ],
            nextSessionRecommendations: [
                "Begin with bodyweight squats",
                "Practice the movement pattern slowly",
                "Aim for 3 workouts this week"
            ],
            overallScore: 0,
            improvementTrend: .newUser,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Vision-Based Analysis Methods
    
    private func analyzeImprovementTrendFromVision(_ sessionData: FormAnalyzer.WorkoutSessionData, previousSessions: [WorkoutSession]) -> ImprovementTrend {
        guard !previousSessions.isEmpty else { return .newUser }
        
        // Compare current session with previous sessions
        let recentSessions = previousSessions.suffix(3)
        let recentAverage = recentSessions.map { $0.formScore }.reduce(0, +) / recentSessions.count
        let currentScore = Int(sessionData.averageFormScore * 100)
        
        let difference = currentScore - recentAverage
        
        if difference > 5 {
            return .improving
        } else if difference < -5 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func generateVisionBasedWhatsWorkingWell(
        sessionData: FormAnalyzer.WorkoutSessionData,
        averageFormScore: Int,
        goodRepPercentage: Float,
        perfectFormReps: Int
    ) -> [String] {
        var insights: [String] = []
        
        // Duration analysis
        let durationMinutes = Int(sessionData.duration / 60)
        if durationMinutes >= 10 {
            insights.append("Great workout duration with \(durationMinutes) minutes of focused training")
        }
        
        // Form consistency analysis
        if averageFormScore >= 85 {
            insights.append("Excellent form consistency with \(averageFormScore)% average score")
        } else if averageFormScore >= 75 {
            insights.append("Good form consistency with \(averageFormScore)% average score")
        }
        
        // Good rep analysis
        let goodRepPercentageInt = Int(goodRepPercentage * 100)
        if goodRepPercentageInt >= 80 {
            insights.append("Outstanding rep quality with \(goodRepPercentageInt)% of reps meeting form standards")
        } else if goodRepPercentageInt >= 60 {
            insights.append("Solid rep quality with \(goodRepPercentageInt)% of reps meeting form standards")
        }
        
        // Perfect form analysis
        if perfectFormReps > 0 {
            let perfectPercentage = Int(Float(perfectFormReps) / Float(sessionData.totalReps) * 100)
            insights.append("\(perfectPercentage)% of your reps achieved perfect form - excellent control!")
        }
        
        // Volume analysis
        if sessionData.totalReps >= 20 {
            insights.append("Impressive volume with \(sessionData.totalReps) total reps")
        }
        
        // Safety analysis
        let highSeverityIssues = sessionData.safetyIssues.filter { $0.severity == .high }.count
        if highSeverityIssues == 0 {
            insights.append("Great job maintaining safe form throughout the workout")
        }
        
        // Improvement analysis
        let improvingReps = sessionData.repAnalysis.filter { rep in
            guard rep.repNumber > 1 else { return false }
            let previousRep = sessionData.repAnalysis.first { $0.repNumber == rep.repNumber - 1 }
            let previousScore = previousRep?.score ?? 0
            return rep.score > previousScore
        }.count
        
        if improvingReps > sessionData.totalReps / 2 {
            insights.append("Form improved throughout the session - great learning and adaptation")
        }
        
        return insights.isEmpty ? ["Keep up the consistent effort!"] : insights
    }
    
    private func generateVisionBasedAreasToFocusOn(
        sessionData: FormAnalyzer.WorkoutSessionData,
        averageFormScore: Int,
        goodRepPercentage: Float,
        perfectFormReps: Int
    ) -> [String] {
        var insights: [String] = []
        
        // Form score analysis
        if averageFormScore < 75 {
            insights.append("Focus on form quality - current average is \(averageFormScore)%")
        } else if averageFormScore < 85 {
            insights.append("Form is good but can be improved from \(averageFormScore)% to 90%+")
        }
        
        // Good rep analysis
        let goodRepPercentageInt = Int(goodRepPercentage * 100)
        if goodRepPercentageInt < 60 {
            insights.append("Only \(goodRepPercentageInt)% of reps met quality standards - focus on control and technique")
        }
        
        // Perfect form analysis
        let perfectPercentage = sessionData.totalReps > 0 ? Int(Float(perfectFormReps) / Float(sessionData.totalReps) * 100) : 0
        if perfectPercentage < 20 {
            insights.append("Only \(perfectPercentage)% of reps achieved perfect form - focus on slow, controlled movements")
        }
        
        // Safety issues analysis
        let highSeverityIssues = sessionData.safetyIssues.filter { $0.severity == .high }
        if !highSeverityIssues.isEmpty {
            let issueTypes = Set(highSeverityIssues.map { $0.type })
            for issueType in issueTypes {
                switch issueType {
                case .kneeValgus:
                    insights.append("Address knee valgus - focus on keeping knees over toes")
                case .spinalFlexion:
                    insights.append("Maintain neutral spine - avoid rounding the back")
                case .poorStability:
                    insights.append("Improve stability and control throughout the movement")
                case .excessiveSpeed:
                    insights.append("Slow down the movement for better control")
                case .incompleteRange:
                    insights.append("Focus on full range of motion")
                }
            }
        }
        
        // Consistency analysis
        if sessionData.repAnalysis.count >= 3 {
            let scoreVariation = sessionData.repAnalysis.map { $0.score }
            let minScore = scoreVariation.min() ?? 0
            let maxScore = scoreVariation.max() ?? 0
            let variation = maxScore - minScore
            
            if variation > 0.3 {
                insights.append("Work on consistency - form scores varied from \(Int(minScore * 100))% to \(Int(maxScore * 100))%")
            }
        }
        
        return insights.isEmpty ? ["Continue focusing on consistency"] : insights
    }
    
    private func generateVisionBasedNextSessionRecommendations(
        sessionData: FormAnalyzer.WorkoutSessionData,
        averageFormScore: Int,
        improvementTrend: ImprovementTrend,
        previousSessions: [WorkoutSession]
    ) -> [String] {
        var recommendations: [String] = []
        
        // Form-based recommendations
        if averageFormScore < 80 {
            recommendations.append("Start with lighter weights or bodyweight to focus on perfect form")
            recommendations.append("Practice the movement pattern slowly before adding speed")
        } else if averageFormScore >= 85 {
            recommendations.append("Consider increasing weight or reps for progression")
        }
        
        // Safety-based recommendations
        let highSeverityIssues = sessionData.safetyIssues.filter { $0.severity == .high }
        if !highSeverityIssues.isEmpty {
            recommendations.append("Focus on the safety issues identified in this session")
            recommendations.append("Consider working with a lighter load to perfect form")
        }
        
        // Trend-based recommendations
        switch improvementTrend {
        case .improving:
            recommendations.append("Great progress! Continue with your current approach")
        case .stable:
            recommendations.append("Try adding new exercises or increasing intensity gradually")
        case .declining:
            recommendations.append("Focus on recovery and form fundamentals")
        case .newUser:
            recommendations.append("Start with bodyweight exercises to build foundation")
        }
        
        // Exercise-specific recommendations
        let exerciseName = sessionData.exercise.name.lowercased()
        if exerciseName.contains("squat") {
            recommendations.append("Try adding deadlifts or lunges for lower body variety")
        } else if exerciseName.contains("deadlift") {
            recommendations.append("Consider adding squats or hip thrusts for comprehensive training")
        }
        
        // Volume recommendations
        if sessionData.totalReps < 15 {
            recommendations.append("Aim for 15-20 reps next session for better volume")
        } else if sessionData.totalReps > 30 {
            recommendations.append("Consider reducing reps and focusing on quality")
        }
        
        return recommendations.isEmpty ? ["Keep up the consistent effort!"] : recommendations
    }
    
    // MARK: - Notification Functions
    
    private func sendWorkoutFeedbackNotification() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎯 Workout Analysis Complete"
        content.body = "Rex has analyzed your workout form. Check your feedback!"
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "workout_feedback_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send workout feedback notification: \(error)")
            } else {
                print("✅ Workout feedback notification sent")
            }
        }
    }
    
    private func sendFormAnalysisNotification() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🏋️ Form Analysis Complete"
        content.body = "Your exercise form has been analyzed. Great work!"
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "form_analysis_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send form analysis notification: \(error)")
            } else {
                print("✅ Form analysis notification sent")
            }
        }
    }
}

// MARK: - WorkoutSession Extension for Analysis

extension WorkoutSession {
    var isHighQuality: Bool {
        return formScore >= 90
    }
    
    var isGoodQuality: Bool {
        return formScore >= 80
    }
    
    var needsImprovement: Bool {
        return formScore < 75
    }
}
