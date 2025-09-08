import Foundation
import HealthKit

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
    
    enum ImprovementTrend {
        case improving
        case stable
        case declining
        case newUser
    }
    
    // MARK: - Main Analysis Function
    
    func generateFeedback(from workoutSessions: [WorkoutSession]) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let feedback = self?.analyzeWorkoutData(workoutSessions) ?? self?.getDefaultFeedback()
            
            DispatchQueue.main.async {
                self?.feedback = feedback
                self?.isLoading = false
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
