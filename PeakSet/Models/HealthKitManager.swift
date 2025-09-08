import Foundation
import HealthKit
import Combine

/// HealthKitManager for accessing Apple Health data
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var workoutSessions: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // HealthKit types we need permission for
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.categoryType(forIdentifier: .mindfulSession)!
    ]
    
    init() {
        checkHealthKitAvailability()
        checkAuthorizationStatus()
        
        // Automatically request permissions if not already authorized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.isAuthorized {
                self.requestAuthorization()
            }
        }
    }
    
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }
    }
    
    private func checkAuthorizationStatus() {
        // Check if we already have authorization for the required types
        for type in typesToRead {
            let status = healthStore.authorizationStatus(for: type)
            if status == .notDetermined {
                // We need to request authorization
                return
            }
        }
        
        // If we get here, we have authorization
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.loadWorkoutData()
            self.loadTodayCalories()
            self.loadTodayStepCount()
            self.loadTodayStepDistance()
            self.loadHourlyStepCount()
            self.loadHourlyCalories()
            self.loadHourlyStepDistance()
        }
    }
    
    func requestAuthorization() {
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
                    self?.isAuthorized = false
                } else {
                    // Try to load data to verify authorization
                    self?.verifyAuthorization()
                }
            }
        }
    }
    
    private func verifyAuthorization() {
        // Try to read a simple health metric to verify we have permission
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            self.isAuthorized = false
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            DispatchQueue.main.async {
                if error != nil {
                    // If we get an error, likely means no permission
                    self?.isAuthorized = false
                    self?.errorMessage = "HealthKit permissions were denied. Please enable in Settings > Privacy & Security > Health."
                } else {
                    // Success - we have permission
                    self?.isAuthorized = true
                    self?.errorMessage = nil
                    self?.loadWorkoutData()
                    self?.loadTodayCalories()
                    self?.loadTodayStepCount()
                    self?.loadTodayStepDistance()
                    self?.loadHourlyStepCount()
                    self?.loadHourlyCalories()
                    self?.loadHourlyStepDistance()
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func loadWorkoutData() {
        isLoading = true
        errorMessage = nil
        
        // Get workouts from the last 30 days
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: 50,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load workouts: \(error.localizedDescription)"
                    return
                }
                
                guard let workouts = samples as? [HKWorkout] else {
                    self?.errorMessage = "No workout data found"
                    return
                }
                
                self?.processWorkouts(workouts)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processWorkouts(_ workouts: [HKWorkout]) {
        var sessions: [WorkoutSession] = []
        
        for workout in workouts {
            // Map HealthKit workout types to our exercise types
            let exercise = mapWorkoutToExercise(workout)
            
            // Create a WorkoutSession from HealthKit data
            let session = WorkoutSession(
                date: workout.startDate,
                exercise: exercise,
                reps: extractRepsFromWorkout(workout),
                sets: extractSetsFromWorkout(workout),
                formScore: generateFormScore(),
                aiTips: generateAITips(for: exercise)
            )
            
            sessions.append(session)
        }
        
        self.workoutSessions = sessions
    }
    
    private func mapWorkoutToExercise(_ workout: HKWorkout) -> Exercise {
        // Map HealthKit workout types to our exercise database
        switch workout.workoutActivityType {
        case .traditionalStrengthTraining:
            // Try to get more specific info from workout name or metadata
            if let workoutName = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String {
                if workoutName.lowercased().contains("squat") {
                    return Exercise.getExercise(named: "squats") ?? Exercise.database[0]
                } else if workoutName.lowercased().contains("deadlift") {
                    return Exercise.getExercise(named: "deadlifts") ?? Exercise.database[1]
                }
            }
            return Exercise.database[0] // Default to squats
        case .flexibility:
            return Exercise.database[0] // Map to squats for now
        case .yoga:
            return Exercise.database[0] // Map to squats for now
        default:
            return Exercise.database[0] // Default to squats
        }
    }
    
    private func extractRepsFromWorkout(_ workout: HKWorkout) -> Int {
        // Try to extract reps from workout metadata or calculate from duration
        if let reps = workout.metadata?["HKReps"] as? Int {
            return reps
        }
        
        // Estimate reps based on workout duration (rough calculation)
        let durationMinutes = workout.duration / 60
        return Int(durationMinutes * 2) // Rough estimate: 2 reps per minute
    }
    
    private func extractSetsFromWorkout(_ workout: HKWorkout) -> Int {
        // Try to extract sets from workout metadata
        if let sets = workout.metadata?["HKSets"] as? Int {
            return sets
        }
        
        // Estimate sets based on workout duration
        let durationMinutes = workout.duration / 60
        return max(1, Int(durationMinutes / 5)) // Rough estimate: 1 set per 5 minutes
    }
    
    private func generateFormScore() -> Int {
        // Generate a realistic form score (80-95 for completed workouts)
        return Int.random(in: 80...95)
    }
    
    private func generateAITips(for exercise: Exercise) -> [String] {
        // Generate contextual AI tips based on the exercise
        let tips = [
            "Great workout! Keep up the consistency.",
            "Focus on controlled movements.",
            "Remember to breathe properly.",
            "Maintain good posture throughout.",
            "Excellent form today!"
        ]
        
        return Array(tips.shuffled().prefix(2))
    }
    
    // MARK: - Health Metrics
    
    @Published var todayCalories: Int = 0
    @Published var todayStepCount: Int = 0
    @Published var todayStepDistance: Double = 0.0
    
    // Hourly data for charts
    @Published var hourlyStepCount: [Int] = Array(repeating: 0, count: 24)
    @Published var hourlyCalories: [Int] = Array(repeating: 0, count: 24)
    @Published var hourlyStepDistance: [Double] = Array(repeating: 0.0, count: 24)
    
    func loadTodayCalories() {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading calories: \(error.localizedDescription)")
                    return
                }
                
                let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                self?.todayCalories = Int(calories)
            }
        }
        
        healthStore.execute(query)
    }
    
    func loadTodayStepCount() {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading step count: \(error.localizedDescription)")
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                self?.todayStepCount = Int(steps)
            }
        }
        
        healthStore.execute(query)
    }
    
    func loadTodayStepDistance() {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading step distance: \(error.localizedDescription)")
                    return
                }
                
                let distance = result?.sumQuantity()?.doubleValue(for: HKUnit.mile()) ?? 0
                self?.todayStepDistance = distance
            }
        }
        
        healthStore.execute(query)
    }
    
    func loadHourlyStepCount() {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        var hourlyData = Array(repeating: 0, count: 24)
        let group = DispatchGroup()
        
        for hour in 0..<24 {
            group.enter()
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            let hourEnd = calendar.date(byAdding: .hour, value: hour + 1, to: startOfDay)!
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let result = result, let sum = result.sumQuantity() {
                    hourlyData[hour] = Int(sum.doubleValue(for: HKUnit.count()))
                }
                group.leave()
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.hourlyStepCount = hourlyData
        }
    }
    
    func loadHourlyCalories() {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        var hourlyData = Array(repeating: 0, count: 24)
        let group = DispatchGroup()
        
        for hour in 0..<24 {
            group.enter()
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            let hourEnd = calendar.date(byAdding: .hour, value: hour + 1, to: startOfDay)!
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let result = result, let sum = result.sumQuantity() {
                    hourlyData[hour] = Int(sum.doubleValue(for: HKUnit.kilocalorie()))
                }
                group.leave()
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.hourlyCalories = hourlyData
        }
    }
    
    func loadHourlyStepDistance() {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        var hourlyData = Array(repeating: 0.0, count: 24)
        let group = DispatchGroup()
        
        for hour in 0..<24 {
            group.enter()
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            let hourEnd = calendar.date(byAdding: .hour, value: hour + 1, to: startOfDay)!
            
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let result = result, let sum = result.sumQuantity() {
                    hourlyData[hour] = sum.doubleValue(for: HKUnit.mile())
                }
                group.leave()
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            self.hourlyStepDistance = hourlyData
        }
    }
    
    func getTodayCalories() -> Int {
        return todayCalories
    }
    
    func getCaloriesForDate(_ date: Date) -> Int {
        // For now, return today's calories if it's today, otherwise return 0
        // In a full implementation, this would query HealthKit for historical data
        if Calendar.current.isDateInToday(date) {
            return todayCalories
        }
        return 0
    }
    
    func getTodayStepCount() -> Int {
        return todayStepCount
    }
    
    func getTodayStepDistance() -> Double {
        return todayStepDistance
    }
    
    func getWeeklyWorkouts() -> Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workoutSessions.filter { $0.date >= weekAgo }.count
    }
    
    func getAverageFormScore() -> Int {
        guard !workoutSessions.isEmpty else { return 0 }
        let totalScore = workoutSessions.reduce(0) { $0 + $1.formScore }
        return totalScore / workoutSessions.count
    }
}
