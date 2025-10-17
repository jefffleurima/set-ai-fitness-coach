import Foundation
import HealthKit

// MARK: - Health Data Bridge
class HealthData: ObservableObject {
    static let shared = HealthData()
    
    @Published var todayCalories: Int = 0
    @Published var todaySteps: Int = 0
    @Published var todayDistance: Double = 0.0 // in miles
    @Published var todayHeartRate: Double = 0.0 // average BPM
    @Published var moveGoal: Int = 0 // calories - will be set from HealthKit or user preference
    @Published var exerciseGoal: Int = 30 // minutes
    @Published var standGoal: Int = 12 // hours
    
    // Activity Rings Progress (0.0 to 1.0)
    @Published var moveRingProgress: Double = 0.0
    @Published var exerciseRingProgress: Double = 0.0
    @Published var standRingProgress: Double = 0.0
    
    // Weekly Data
    @Published var weeklyCalories: [Int] = Array(repeating: 0, count: 7)
    @Published var weeklySteps: [Int] = Array(repeating: 0, count: 7)
    @Published var weeklyWorkouts: [Int] = Array(repeating: 0, count: 7)
    
    // Recent Workout Sessions
    @Published var recentWorkouts: [HealthWorkoutSession] = []
    
    // Health Metrics
    @Published var currentWeight: Double = 0.0
    @Published var currentHeight: Double = 0.0
    @Published var restingHeartRate: Double = 0.0
    @Published var vo2Max: Double = 0.0
    
    private let healthKitManager = HealthKitManager.shared
    private var updateTimer: Timer?
    
    private init() {
        setupHealthKitObserver()
        startPeriodicUpdates()
        
        // Initial data load
        loadTodayData()
        loadWeeklyData()
        loadRecentWorkouts()
        loadHealthMetrics()
    }
    
    // MARK: - HealthKit Integration
    
    private func setupHealthKitObserver() {
        // Listen for HealthKit authorization changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(healthKitAuthorizationChanged),
            name: NSNotification.Name("HealthKitAuthorizationChanged"),
            object: nil
        )
        
        // Listen for HealthKitManager data updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(healthKitDataUpdated),
            name: NSNotification.Name("HealthKitDataUpdated"),
            object: nil
        )
    }
    
    @objc private func healthKitAuthorizationChanged() {
        DispatchQueue.main.async {
            self.loadTodayData()
            self.loadWeeklyData()
            self.loadRecentWorkouts()
            self.loadHealthMetrics()
        }
    }
    
    @objc private func healthKitDataUpdated() {
        DispatchQueue.main.async {
            print("📊 HealthData: Received HealthKit data update notification")
            self.loadTodayData()
        }
    }
    
    private func startPeriodicUpdates() {
        // Update data every 5 minutes
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.loadTodayData()
        }
    }
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Data Loading
    
    func loadTodayData() {
        todayCalories = healthKitManager.getTodayCalories()
        todaySteps = healthKitManager.getTodayStepCount()
        todayDistance = healthKitManager.getTodayStepDistance()
        
        // Set move goal from UserDefaults or use a reasonable default
        if moveGoal == 0 {
            let savedGoal = UserDefaults.standard.integer(forKey: "moveGoal")
            moveGoal = savedGoal > 0 ? savedGoal : 600 // Default to 600 calories if not set
        }
        
        updateActivityRings()
        
        print("📊 HealthData: Today's data loaded - \(todayCalories) cal, \(todaySteps) steps, goal: \(moveGoal) cal")
        
        // Save activity data to Supabase
        saveActivityDataToSupabase()
        
        // Debug HealthKit authorization status
        if todayCalories == 0 && todaySteps == 0 {
            print("⚠️ HealthData: No activity data found. Checking HealthKit authorization...")
            print("   - HealthKit authorized: \(healthKitManager.isAuthorized)")
            if let error = healthKitManager.errorMessage {
                print("   - HealthKit error: \(error)")
            }
        }
    }
    
    func loadWeeklyData() {
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                weeklyCalories[6-dayOffset] = healthKitManager.getCaloriesForDate(date)
                weeklySteps[6-dayOffset] = getStepsForDate(date)
            }
        }
        
        print("📊 HealthData: Weekly data loaded")
    }
    
    func loadRecentWorkouts() {
        recentWorkouts = healthKitManager.workoutSessions.prefix(10).map { session in
            HealthWorkoutSession(
                id: UUID(),
                exerciseName: session.exercise.name,
                date: session.date,
                duration: 0, // Will be populated from HealthKit
                reps: session.reps,
                sets: session.sets,
                formScore: session.formScore,
                aiTips: session.aiTips,
                calories: 0, // Will be populated from HealthKit
                notes: ""
            )
        }
        
        print("📊 HealthData: Recent workouts loaded - \(recentWorkouts.count) sessions")
    }
    
    func loadHealthMetrics() {
        // These would be loaded from HealthKit in a full implementation
        // For now, using placeholder values
        currentWeight = 70.0 // kg
        currentHeight = 170.0 // cm
        restingHeartRate = 65.0 // BPM
        vo2Max = 45.0 // ml/kg/min
        
        print("📊 HealthData: Health metrics loaded")
    }
    
    // MARK: - Activity Rings Calculation
    
    private func updateActivityRings() {
        // Move Ring (Calories) - prevent division by zero
        moveRingProgress = moveGoal > 0 ? min(Double(todayCalories) / Double(moveGoal), 1.0) : 0.0
        
        // Exercise Ring (Minutes) - estimated from steps and workouts
        let estimatedExerciseMinutes = Double(todaySteps) / 100.0 + Double(recentWorkouts.count) * 30.0
        exerciseRingProgress = exerciseGoal > 0 ? min(estimatedExerciseMinutes / Double(exerciseGoal), 1.0) : 0.0
        
        // Stand Ring (Hours) - estimated from steps
        let estimatedStandHours = min(Double(todaySteps) / 1000.0, 12.0)
        standRingProgress = standGoal > 0 ? min(estimatedStandHours / Double(standGoal), 1.0) : 0.0
        
        print("📊 HealthData: Activity rings updated - Move: \(Int(moveRingProgress * 100))%, Exercise: \(Int(exerciseRingProgress * 100))%, Stand: \(Int(standRingProgress * 100))%")
    }
    
    // MARK: - Helper Methods
    
    private func getStepsForDate(_ date: Date) -> Int {
        // This would query HealthKit for historical step data
        // For now, return a placeholder
        return Int.random(in: 5000...15000)
    }
    
    func getActivityRingSummary() -> String {
        let movePercent = Int(moveRingProgress * 100)
        let exercisePercent = Int(exerciseRingProgress * 100)
        let standPercent = Int(standRingProgress * 100)
        
        return "Activity Rings: Move \(movePercent)% (\(todayCalories)/\(moveGoal) cal), Exercise \(exercisePercent)%, Stand \(standPercent)%"
    }
    
    func getTodaySummary() -> String {
        return "Today: \(todayCalories) calories burned, \(todaySteps) steps taken, \(String(format: "%.1f", todayDistance)) miles walked"
    }
    
    func getWeeklySummary() -> String {
        let avgCalories = weeklyCalories.reduce(0, +) / 7
        let avgSteps = weeklySteps.reduce(0, +) / 7
        
        return "This week: Average \(avgCalories) calories/day, \(avgSteps) steps/day"
    }
    
    func getWorkoutSummary() -> String {
        guard !recentWorkouts.isEmpty else {
            return "No recent workouts"
        }
        
        let lastWorkout = recentWorkouts.first!
        let avgFormScore = recentWorkouts.map { $0.formScore }.reduce(0, +) / recentWorkouts.count
        
        return "Last workout: \(lastWorkout.exerciseName) with \(avgFormScore)% average form score"
    }
    
    // MARK: - Health Insights
    
    func getHealthInsights() -> [String] {
        var insights: [String] = []
        
        // Move Ring Insights
        if moveRingProgress >= 1.0 {
            insights.append("🎉 You've closed your Move ring today! Great job staying active.")
        } else if moveRingProgress >= 0.8 {
            insights.append("💪 You're close to closing your Move ring - just \(moveGoal - todayCalories) more calories!")
        } else if moveRingProgress < 0.3 {
            insights.append("📈 Let's get moving! You're at \(Int(moveRingProgress * 100))% of your Move goal.")
        }
        
        // Step Insights
        if todaySteps >= 10000 {
            insights.append("🚶‍♂️ Excellent step count today! You've hit the 10,000 step milestone.")
        } else if todaySteps >= 7500 {
            insights.append("👟 Good progress on steps - you're on track for 10,000 today.")
        } else if todaySteps < 3000 {
            insights.append("🏃‍♂️ Time to get those steps up! Try taking a walk or doing some light activity.")
        }
        
        // Workout Insights
        if recentWorkouts.isEmpty {
            insights.append("💪 Ready for a workout? I can help you plan an effective session.")
        } else {
            let lastWorkout = recentWorkouts.first!
            let daysSince = Calendar.current.dateComponents([.day], from: lastWorkout.date, to: Date()).day ?? 0
            
            if daysSince == 0 {
                insights.append("🔥 Great job working out today! How are you feeling?")
            } else if daysSince == 1 {
                insights.append("💪 Yesterday's workout was solid! Ready for today's session?")
            } else if daysSince > 3 {
                insights.append("🎯 It's been a few days since your last workout. Let's get back on track!")
            }
        }
        
        // Form Score Insights
        if !recentWorkouts.isEmpty {
            let avgFormScore = recentWorkouts.map { $0.formScore }.reduce(0, +) / recentWorkouts.count
            if avgFormScore >= 90 {
                insights.append("🏆 Outstanding form scores! Your technique is really improving.")
            } else if avgFormScore >= 80 {
                insights.append("👍 Good form scores! Keep focusing on technique.")
            } else if avgFormScore < 70 {
                insights.append("🎯 Let's work on form - I can give you some specific tips during your next workout.")
            }
        }
        
        return insights
    }
    
    // MARK: - Goal Tracking
    
    func isGoalAchieved(_ goal: HealthGoal) -> Bool {
        switch goal {
        case .moveRing:
            return moveRingProgress >= 1.0
        case .exerciseRing:
            return exerciseRingProgress >= 1.0
        case .standRing:
            return standRingProgress >= 1.0
        case .steps(let target):
            return todaySteps >= target
        case .calories(let target):
            return todayCalories >= target
        case .workouts(let target):
            return recentWorkouts.count >= target
        }
    }
    
    func getGoalProgress(_ goal: HealthGoal) -> Double {
        switch goal {
        case .moveRing:
            return moveRingProgress
        case .exerciseRing:
            return exerciseRingProgress
        case .standRing:
            return standRingProgress
        case .steps(let target):
            return target > 0 ? min(Double(todaySteps) / Double(target), 1.0) : 0.0
        case .calories(let target):
            return target > 0 ? min(Double(todayCalories) / Double(target), 1.0) : 0.0
        case .workouts(let target):
            return target > 0 ? min(Double(recentWorkouts.count) / Double(target), 1.0) : 0.0
        }
    }
    
    // MARK: - Goal Management
    
    func updateMoveGoal(_ newGoal: Int) {
        moveGoal = newGoal
        UserDefaults.standard.set(newGoal, forKey: "moveGoal")
        updateActivityRings()
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("📊 HealthData: Move goal updated to \(newGoal) calories")
        
        // Save updated goal to Supabase (in user_profiles table)
        Task {
            do {
                // Get current profile data
                if let currentProfile = try? await SupabaseManager.shared.loadUserProfile() {
                    // Update with new move goal
                    let updatedProfile = SupabaseUserProfile(
                        name: currentProfile.name,
                        email: currentProfile.email,
                        height: currentProfile.height,
                        weight: currentProfile.weight,
                        age: currentProfile.age,
                        unitSystem: currentProfile.unitSystem,
                        fitnessLevel: currentProfile.fitnessLevel,
                        primaryGoal: currentProfile.primaryGoal,
                        experience: currentProfile.experience,
                        workoutFrequency: currentProfile.workoutFrequency,
                        notificationsEnabled: currentProfile.notificationsEnabled,
                        dataSharingEnabled: currentProfile.dataSharingEnabled,
                        moveGoal: newGoal,
                        createdAt: currentProfile.createdAt
                    )
                    
                    try await SupabaseManager.shared.saveUserProfile(updatedProfile)
                    print("✅ Move goal saved to Supabase")
                }
            } catch {
                print("❌ Failed to save move goal to Supabase: \(error)")
            }
        }
    }
    
    // MARK: - Supabase Sync
    
    /// Save current health metrics to Supabase for AI access and cloud sync
    private func saveActivityDataToSupabase() {
        Task {
            do {
                // Calculate exercise minutes from activity
                let exerciseMinutes = Int(exerciseRingProgress * Double(exerciseGoal))
                
                // Calculate stand hours from activity
                let standHours = Int(standRingProgress * Double(standGoal))
                
                try await SupabaseManager.shared.saveDailyHealthMetrics(
                    date: Date(),
                    calories: todayCalories,
                    steps: todaySteps,
                    distance: todayDistance,
                    exerciseMinutes: exerciseMinutes,
                    standHours: standHours,
                    heartRate: todayHeartRate,
                    moveGoal: moveGoal,
                    exerciseGoal: exerciseGoal,
                    standGoal: standGoal,
                    moveRingProgress: moveRingProgress,
                    exerciseRingProgress: exerciseRingProgress,
                    standRingProgress: standRingProgress
                )
            } catch {
                print("❌ HealthData: Failed to save health metrics to Supabase: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

enum HealthGoal {
    case moveRing
    case exerciseRing
    case standRing
    case steps(Int)
    case calories(Int)
    case workouts(Int)
}

// MARK: - Workout Session Data (For Health Integration)
struct HealthWorkoutSession {
    let id: UUID
    let exerciseName: String
    let date: Date
    let duration: TimeInterval // seconds
    let reps: Int
    let sets: Int
    let formScore: Int
    let aiTips: [String]
    let calories: Int
    let notes: String
}
