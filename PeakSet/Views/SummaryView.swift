import SwiftUI
import HealthKit
import Foundation

// MARK: - Data Models

struct WorkoutSession: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let exercise: Exercise
    let reps: Int
    let sets: Int
    let formScore: Int
    let aiTips: [String]
    
    static func == (lhs: WorkoutSession, rhs: WorkoutSession) -> Bool {
        return lhs.id == rhs.id
    }
    
    static let sampleData: [WorkoutSession] = [
        WorkoutSession(
            date: Date(),
            exercise: Exercise.database[0], // squats
            reps: 20,
            sets: 3,
            formScore: 72,
            aiTips: ["Only 6 reps achieved perfect form", "Focus on knee alignment"]
        ),
        WorkoutSession(
            date: Date().addingTimeInterval(-86400), // yesterday
            exercise: Exercise.database[0], // squats
            reps: 15,
            sets: 3,
            formScore: 68,
            aiTips: ["Knees caving inward", "Work on depth"]
        ),
        WorkoutSession(
            date: Date().addingTimeInterval(-172800), // 2 days ago
            exercise: Exercise.database[1], // deadlifts
            reps: 12,
            sets: 4,
            formScore: 88,
            aiTips: ["Great hip hinge!", "Maintain neutral spine"]
        ),
        WorkoutSession(
            date: Date().addingTimeInterval(-259200), // 3 days ago
            exercise: Exercise.database[0], // squats
            reps: 18,
            sets: 3,
            formScore: 75,
            aiTips: ["Good improvement", "Keep core engaged"]
        ),
        WorkoutSession(
            date: Date().addingTimeInterval(-345600), // 4 days ago
            exercise: Exercise.database[1], // deadlifts
            reps: 10,
            sets: 3,
            formScore: 85,
            aiTips: ["Solid form", "Control the descent"]
        )
    ]
}

struct SummaryView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var aiCoachFeedback = AICoachFeedback()
    @StateObject private var healthData = HealthData()
    @State private var showingHealthKitPermission = false
    @State private var showingActivityDetail = false
    @State private var showingStepCountDetail = false
    @State private var showingActiveEnergyDetail = false
    @State private var showingSessionsDetail = false
    @State private var showingStepDistanceDetail = false
    @State private var animateRings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with date and calendar button
                        headerView
                        
                        // Activity Card (Move ring only)
                        activityCard
                        
                        // Recent Summary Card (Workout stats)
                        recentSummaryCard
                        
                        // AI Coach Feedback Card
                        aiCoachFeedbackCard
                        
                        // Quick Stats Grid
                        quickStatsGrid
                        
                        // Workout History
                        workoutHistorySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Tab bar spacing
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Generate AI feedback when workout data is available
                if !healthKitManager.workoutSessions.isEmpty {
                    aiCoachFeedback.generateFeedback(from: healthKitManager.workoutSessions)
                } else {
                    // Generate sample feedback for testing when no real data is available
                    aiCoachFeedback.generateFeedback(from: WorkoutSession.sampleData)
                }
            }
            .onChange(of: healthKitManager.workoutSessions) { _, sessions in
                // Regenerate AI feedback when workout data changes
                if !sessions.isEmpty {
                    aiCoachFeedback.generateFeedback(from: sessions)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Refresh HealthKit data when app becomes active
                if healthKitManager.isAuthorized {
                    healthKitManager.loadTodayCalories()
                    healthKitManager.loadTodayStepCount()
                    healthKitManager.loadTodayStepDistance()
                    healthKitManager.loadHourlyStepCount()
                    healthKitManager.loadHourlyCalories()
                    healthKitManager.loadHourlyStepDistance()
                    healthKitManager.loadWorkoutData()
                }
            }
            .sheet(isPresented: $showingActivityDetail) {
                ActivityDetailView(healthData: healthData, healthKitManager: healthKitManager)
            }
            .sheet(isPresented: $showingStepCountDetail) {
                StepCountDetailView(healthKitManager: healthKitManager)
            }
            .sheet(isPresented: $showingActiveEnergyDetail) {
                ActiveEnergyDetailView(healthKitManager: healthKitManager)
            }
            .sheet(isPresented: $showingSessionsDetail) {
                SessionsDetailView(healthKitManager: healthKitManager)
            }
            .sheet(isPresented: $showingStepDistanceDetail) {
                StepDistanceDetailView(healthKitManager: healthKitManager)
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(DateFormatter.dayFormatter.string(from: Date()))
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                Text("Summary")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.text)
            }
            Spacer()
        }
        .padding(.top, 10)
    }
    
    // MARK: - Activity Card (Move Ring Only)
    private var activityCard: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showingActivityDetail.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Activity")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.text)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                HStack(spacing: 24) {
                    // Move Ring with better proportions
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(AppTheme.primary.opacity(0.15), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        // Progress ring
                        Circle()
                            .trim(from: 0, to: animateRings ? CGFloat(Double(healthKitManager.getTodayCalories()) / Double(healthData.moveGoal)) : 0)
                            .stroke(AppTheme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.2).delay(0.2), value: animateRings)
                        
                        // Center content
                        VStack(spacing: 1) {
                            Text("\(healthKitManager.getTodayCalories())")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.text)
                            Text("CAL")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    
                    // Stats with better hierarchy
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Move")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.text)
                            
                            Text("\(healthKitManager.getTodayCalories()) of \(healthData.moveGoal) calories")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        
                        // Progress indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 6, height: 6)
                            
                            let progress = Double(healthKitManager.getTodayCalories()) / Double(healthData.moveGoal)
                            Text("\(Int(progress * 100))% complete")
                                .font(.caption)
                                .foregroundColor(AppTheme.primary)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(24)
            .background(AppTheme.surface)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
                animateRings = true
            }
        }
    }
    
    // MARK: - Recent Summary Card (Workout Stats)
    private var recentSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Summary")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.text)
            
            HStack(spacing: 20) {
                // Form Score Ring
                ZStack {
                    Circle()
                        .stroke(AppTheme.primary.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(averageFormScore) / 100)
                        .stroke(AppTheme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(Int(averageFormScore))%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.primary)
                        Text("Form")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                // Workout Stats
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(value: "\(calculateTotalWorkoutDuration())", unit: "min", color: AppTheme.primary)
                    StatRow(value: "\(todayWorkouts)", unit: "Workouts today", color: .green)
                    StatRow(value: "\(strengthImprovement)%", unit: "Strength improvement", color: AppTheme.primary)
                }
                
                Spacer()
            }
            
            // Exercise breakdown
            if !healthKitManager.workoutSessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Exercise")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.text)
                    
                    HStack {
                        Text(healthKitManager.workoutSessions.first?.exercise.name ?? "No exercises")
                            .font(.body)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("\(healthKitManager.workoutSessions.first?.formScore ?? 0)% form")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(healthKitManager.workoutSessions.first?.formScore ?? 0 >= 80 ? .green : .orange)
                    }
                }
            }
            
            // Mini chart placeholder
            miniProgressChart
        }
        .padding(20)
        .background(AppTheme.surface)
        .cornerRadius(16)
    }
    
    // MARK: - AI Coach Feedback Card
    private var aiCoachFeedbackCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppTheme.primary)
                    .font(.title2)
                Text("AI Coach Feedback")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.text)
                Spacer()
                
                if let feedback = aiCoachFeedback.feedback {
                    Text("\(feedback.overallScore)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(feedback.overallScore >= 85 ? .green : feedback.overallScore >= 75 ? .orange : .red)
                        .cornerRadius(8)
                }
            }
            
            if aiCoachFeedback.isLoading {
                ProgressView("Analyzing your workouts...")
                    .frame(height: 60)
            } else if let feedback = aiCoachFeedback.feedback {
                VStack(alignment: .leading, spacing: 12) {
                    FunctionalFeedbackRow(
                        icon: "checkmark.circle.fill",
                        title: "What's working well",
                        color: .green,
                        insights: feedback.whatsWorkingWell
                    )
                    
                    FunctionalFeedbackRow(
                        icon: "target",
                        title: "Areas to focus on",
                        color: .orange,
                        insights: feedback.areasToFocusOn
                    )
                    
                    FunctionalFeedbackRow(
                        icon: "lightbulb.fill",
                        title: "Next session recommendations",
                        color: AppTheme.primary,
                        insights: feedback.nextSessionRecommendations
                    )
                }
            } else {
                Text("Complete a workout to get AI feedback")
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(height: 60)
            }
        }
        .padding(20)
        .background(AppTheme.surface)
        .cornerRadius(16)
    }
    
    // MARK: - Quick Stats Grid
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            Button(action: {
                showingStepCountDetail = true
            }) {
                QuickStatCard(title: "Step Count", value: "\(healthKitManager.getTodayStepCount())", subtitle: "Today", color: .purple)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingActiveEnergyDetail = true
            }) {
                QuickStatCard(title: "Active Energy", value: "\(healthKitManager.getTodayCalories())", subtitle: "CAL", color: .red)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingSessionsDetail = true
            }) {
                QuickStatCard(title: "Sessions", value: "\(healthKitManager.getWeeklyWorkouts())", subtitle: "This Week", color: .green)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingStepDistanceDetail = true
            }) {
                QuickStatCard(title: "Step Distance", value: "\(String(format: "%.1f", healthKitManager.getTodayStepDistance()))", subtitle: "MI", color: .blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Workout History Section
    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Workout History")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.text)
                Spacer()
                Button("See All") {
                    // TODO: Navigate to full history
                }
                .foregroundColor(AppTheme.primary)
            }
            
            VStack(spacing: 12) {
                if healthKitManager.isLoading {
                    ProgressView("Loading workout data...")
                        .frame(height: 100)
                } else if healthKitManager.workoutSessions.isEmpty {
                    Text("No workout data found")
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(height: 100)
                } else {
                    ForEach(healthKitManager.workoutSessions.prefix(3)) { workout in
                        WorkoutHistoryCard(workout: workout)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private var miniProgressChart: some View {
        HStack(spacing: 4) {
            ForEach(0..<12) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.primary.opacity(Double.random(in: 0.3...1.0)))
                    .frame(width: 4, height: CGFloat.random(in: 8...24))
            }
        }
        .frame(height: 30)
    }
    
    // MARK: - Computed Properties
    private var averageFormScore: Double {
        guard !healthKitManager.workoutSessions.isEmpty else { return 0 }
        return healthKitManager.workoutSessions.map { Double($0.formScore) }.reduce(0, +) / Double(healthKitManager.workoutSessions.count)
    }
    
    private var workoutsThisWeek: Int {
        return healthKitManager.getWeeklyWorkouts()
    }
    
    private func calculateTotalWorkoutDuration() -> Int {
        // Calculate total workout duration from today's workouts
        let todayWorkouts = healthKitManager.workoutSessions.filter { Calendar.current.isDateInToday($0.date) }
        // Estimate duration based on reps and sets (rough calculation)
        return todayWorkouts.reduce(0) { total, workout in
            let estimatedDuration = (workout.reps * workout.sets) / 2 // Rough estimate: 2 reps per minute
            return total + estimatedDuration
        }
    }
    
    private var strengthImprovement: Int {
        // Calculate strength improvement based on form score trends
        guard healthKitManager.workoutSessions.count >= 2 else { return 0 }
        
        let recentSessions = healthKitManager.workoutSessions.prefix(5)
        let olderSessions = healthKitManager.workoutSessions.dropFirst(5).prefix(5)
        
        guard !recentSessions.isEmpty && !olderSessions.isEmpty else { return 0 }
        
        let recentAvg = recentSessions.map { $0.formScore }.reduce(0, +) / recentSessions.count
        let olderAvg = olderSessions.map { $0.formScore }.reduce(0, +) / olderSessions.count
        
        let improvement = ((recentAvg - olderAvg) / olderAvg) * 100
        return max(0, Int(improvement))
    }
    
    private var todayWorkouts: Int {
        let todayWorkouts = healthKitManager.workoutSessions.filter { Calendar.current.isDateInToday($0.date) }
        return todayWorkouts.count
    }
    
}

// MARK: - Supporting Views

struct StatRow: View {
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(unit)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

struct ActivityStatRow: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let progress: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // Ring indicator
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 3)
                    .frame(width: 20, height: 20)
                
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.text)
                
                HStack(spacing: 4) {
                    Text(value)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Spacer()
        }
    }
}

struct FeedbackRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16, weight: .medium))
            Text(title)
                .font(.body)
                .foregroundColor(AppTheme.text)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.textSecondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct FunctionalFeedbackRow: View {
    let icon: String
    let title: String
    let color: Color
    let insights: [String]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(title)
                        .font(.body)
                        .foregroundColor(AppTheme.text)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.textSecondary)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(color)
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            
                            Text(insight)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.leading, 28)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textSecondary)
                    .font(.caption2)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(12)
    }
}

struct WorkoutHistoryCard: View {
    let workout: WorkoutSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Exercise icon
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 18, weight: .medium))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.exercise.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.text)
                Text("\(workout.sets) sets × \(workout.reps) reps")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(workout.formScore)%")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(workout.formScore >= 80 ? .green : workout.formScore >= 60 ? .orange : .red)
                Text(DateFormatter.timeFormatter.string(from: workout.date))
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(12)
    }
}

// MARK: - Data Models

class HealthData: ObservableObject {
    @Published var calories: Int = 0
    @Published var duration: Int = 0
    @Published var steps: Int = 0
    @Published var activeEnergy: Int = 0
    @Published var stepDistance: Double = 0.0
    
    // Activity Ring Data - customizable goals
    @Published var moveGoal: Int = UserDefaults.standard.integer(forKey: "moveGoal") != 0 ? UserDefaults.standard.integer(forKey: "moveGoal") : 140
    @Published var exerciseGoal: Int = 30
    @Published var standGoal: Int = 12
    
    @Published var exerciseMinutes: Int = 0
    @Published var standHours: Int = 8
    
    var moveProgress: Double {
        return min(Double(calories) / Double(moveGoal), 1.0)
    }
    
    func updateMoveGoal(_ newGoal: Int) {
        moveGoal = newGoal
        UserDefaults.standard.set(newGoal, forKey: "moveGoal")
    }
    
    var exerciseProgress: Double {
        return min(Double(exerciseMinutes) / Double(exerciseGoal), 1.0)
    }
    
    var standProgress: Double {
        return min(Double(standHours) / Double(standGoal), 1.0)
    }
    
}

// MARK: - Activity Detail View

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let healthData: HealthData
    let healthKitManager: HealthKitManager
    @State private var animateRings = false
    @State private var showingGoalMenu = false
    
    // MARK: - Weekly Ring Progress Calculation
    private func getWeeklyRingProgress(for day: String, index: Int) -> Double {
        let calendar = Calendar.current
        let today = Date()
        
        // Calculate the date for this day of the week
        let daysFromToday = index - calendar.component(.weekday, from: today) + 1
        guard let targetDate = calendar.date(byAdding: .day, value: daysFromToday, to: today) else {
            return 0.0
        }
        
        // Get calories for this specific date
        let caloriesForDate = healthKitManager.getCaloriesForDate(targetDate)
        let progress = Double(caloriesForDate) / Double(healthData.moveGoal)
        
        // Return the progress, capped at 1.0
        return min(progress, 1.0)
    }
    
    // MARK: - Hourly Activity Height Calculation
    private func getHourlyActivityHeight(for hour: Int) -> Double {
        let maxHeight: Double = 32
        let minHeight: Double = 6
        
        // Get hourly calories data from HealthKit
        let hourlyCalories = healthKitManager.hourlyCalories
        
        // Get the calories for this specific hour (array index = hour)
        let caloriesForHour = hour < hourlyCalories.count ? hourlyCalories[hour] : 0
        
        // Calculate height based on calories for this hour
        // Use a reasonable max calories per hour (e.g., 50 calories)
        let maxCaloriesPerHour: Double = 50
        let progress = min(Double(caloriesForHour) / maxCaloriesPerHour, 1.0)
        
        return minHeight + (progress * (maxHeight - minHeight))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Weekly rings at the very top (full width)
                    weeklyRingsFullScreen
                    
                    ScrollView {
                        VStack(spacing: 32) {
                            // Large ring section
                            largeRingSection
                            
                            // Activity stats (full width)
                            activityStatsFullScreen(healthKitManager: healthKitManager)
                            
                            // Timeline chart (full width)
                            timelineChartFullScreen
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Today, \(DateFormatter.shortDateFormatter.string(from: Date()))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Summary") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
                animateRings = true
            }
        }
    }
    
    // MARK: - Weekly Rings Full Screen
    private var weeklyRingsFullScreen: some View {
        HStack(spacing: 0) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                VStack(spacing: 8) {
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    ZStack {
                        Circle()
                            .stroke(AppTheme.primary.opacity(0.15), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(getWeeklyRingProgress(for: day, index: index)))
                            .stroke(AppTheme.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0).delay(Double(index) * 0.1), value: animateRings)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Large Ring Section
    private var largeRingSection: some View {
        VStack(spacing: 24) {
            // Move label with better typography
            HStack {
                Text("Move")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.text)
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Large ring with enhanced design
            ZStack {
                // Background ring with subtle shadow
                Circle()
                    .stroke(AppTheme.primary.opacity(0.1), lineWidth: 18)
                    .frame(width: 240, height: 240)
                    .shadow(color: AppTheme.primary.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Progress ring with enhanced animation
                Circle()
                    .trim(from: 0, to: animateRings ? CGFloat(Double(healthKitManager.getTodayCalories()) / Double(healthData.moveGoal)) : 0)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.3), value: animateRings)
                
                // Enhanced center content
                VStack(spacing: 6) {
                    Text("\(healthKitManager.getTodayCalories())")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                    
                    Button(action: {
                        showingGoalMenu = true
                    }) {
                        Text("/\(healthData.moveGoal)")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("CALORIES")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .tracking(2)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Activity Stats Full Screen
    private func activityStatsFullScreen(healthKitManager: HealthKitManager) -> some View {
        HStack(spacing: 32) {
            // Steps section with enhanced design
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.primary)
                    Text("Steps")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                }
                
                Text("\(healthKitManager.getTodayStepCount())")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.text)
                    .shadow(color: AppTheme.text.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Distance section with enhanced design
            VStack(alignment: .trailing, spacing: 12) {
                HStack {
                    Text("Distance")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                    Image(systemName: "location")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.primary)
                }
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(String(format: "%.2f", healthKitManager.getTodayStepDistance()))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                        .shadow(color: AppTheme.text.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    Text("MI")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.bottom, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - Timeline Chart Full Screen
    private var timelineChartFullScreen: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Chart header with enhanced typography
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hourly Activity")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                    Text("2CAL peak")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Enhanced chart bars with gradient
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24) { hour in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: hour == 6 || hour == 12 || hour == 18 ? 
                                    [AppTheme.primary, AppTheme.primary.opacity(0.7)] :
                                    [AppTheme.primary.opacity(0.4), AppTheme.primary.opacity(0.2)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: CGFloat(getHourlyActivityHeight(for: hour)))
                        .animation(.easeInOut(duration: 0.8).delay(Double(hour) * 0.02), value: animateRings)
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 24)
            
            // Enhanced timeline labels
            HStack {
                Text("00:00")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("06:00")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("12:00")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("18:00")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, 24)
            
            // Enhanced total with better styling
            HStack {
                Text("TOTAL")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .tracking(1)
                Text("\(healthKitManager.getTodayCalories()) CAL")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Activity Stats Card (Old)
    private func activityStatsCard(healthKitManager: HealthKitManager) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Steps")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(healthKitManager.getTodayStepCount())")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.text)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Distance")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(String(format: "%.2f", healthKitManager.getTodayStepDistance())) MI")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.text)
                }
            }
            
            Divider()
                .background(AppTheme.textSecondary.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Flights Climbed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textSecondary)
                Text("0")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.text)
            }
        }
        .padding(24)
        .background(AppTheme.surface)
        .cornerRadius(20)
    }
    
    // MARK: - Activity Charts Section
    private var activityChartsSection: some View {
        VStack(spacing: 16) {
            // Mini chart with timeline
            VStack(alignment: .leading, spacing: 12) {
                Text("2CAL")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                
                // Chart bars
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24) { hour in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.red.opacity(hour == 6 || hour == 12 || hour == 18 ? 1.0 : 0.3))
                            .frame(width: 3, height: CGFloat.random(in: 4...20))
                    }
                }
                .frame(height: 30)
                
                // Timeline
                HStack {
                    Text("00:00")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text("06:00")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text("12:00")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text("18:00")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Text("TOTAL 1,243 CAL")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(20)
            .background(AppTheme.surface)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Goal Adjustment Menu
    private var goalAdjustmentMenu: some View {
        VStack(spacing: 0) {
            Button(action: {
                // Handle adjust goal for today
                showingGoalMenu = false
            }) {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Text("Adjust Goal for Today")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.8))
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Button(action: {
                // Handle change daily goal
                let newGoal = 140 // Default Apple Fitness goal
                healthData.updateMoveGoal(newGoal)
                showingGoalMenu = false
            }) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Text("Change Daily Goal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.8))
            }
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .offset(x: 60, y: -20)
    }
    
    // MARK: - Bottom Action Buttons
    private var bottomActionButtons: some View {
        HStack(spacing: 16) {
            // Change Goal Button
            Button(action: {
                // Handle change goal
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "target")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text("Change Goal")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Summary")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Fitness+ Button (placeholder)
            Button(action: {
                // Handle fitness+ action
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Text("Fitness+")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    Text("Fitness+")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Sharing Button
            Button(action: {
                // Handle sharing
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text("Pause Ring")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Sharing")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
    
}


struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .white : AppTheme.text)
                
                // Mini activity rings
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: 16, height: 16)
                    
                    Circle()
                        .trim(from: 0, to: Double.random(in: 0.2...1.0)) // Sample data
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(-90))
                    
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 12, height: 12)
                    
                    Circle()
                        .trim(from: 0, to: Double.random(in: 0.2...1.0)) // Sample data
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 12, height: 12)
                        .rotationEffect(.degrees(-90))
                    
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .trim(from: 0, to: Double.random(in: 0.2...1.0)) // Sample data
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 8, height: 8)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 40, height: 50)
            .background(isSelected ? AppTheme.primary : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

struct WorkoutSummaryCard: View {
    let workout: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(workout.exercise.name)
                .font(.headline)
                .foregroundColor(AppTheme.text)
            
            HStack {
                StatView(title: "Sets", value: "\(workout.sets)")
                StatView(title: "Reps", value: "\(workout.reps)")
                StatView(title: "Form", value: "\(workout.formScore)%")
            }
            
            if !workout.aiTips.isEmpty {
                Text("AI Tips:")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                
                ForEach(workout.aiTips, id: \.self) { tip in
                    Text("• \(tip)")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(10)
    }
}

struct WorkoutHistoryRow: View {
    let workout: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(workout.exercise.name)
                .font(.headline)
                .foregroundColor(AppTheme.text)
            
            HStack {
                Text("\(workout.sets) sets × \(workout.reps) reps")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                
                Spacer()
                
                Text("\(workout.formScore)%")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            Text(value)
                .font(.headline)
                .foregroundColor(AppTheme.text)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutDetailView: View {
    let workout: WorkoutSession
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Exercise Info
                Text(workout.exercise.name)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(AppTheme.text)
                
                // Stats
                HStack {
                    StatView(title: "Sets", value: "\(workout.sets)")
                    StatView(title: "Reps", value: "\(workout.reps)")
                    StatView(title: "Form", value: "\(workout.formScore)%")
                }
                
                // AI Tips
                if !workout.aiTips.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI Tips")
                            .font(.headline)
                            .foregroundColor(AppTheme.text)
                        
                        ForEach(workout.aiTips, id: \.self) { tip in
                            HStack(alignment: .top) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(AppTheme.accent)
                                Text(tip)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(AppTheme.background)
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.background.ignoresSafeArea())
    }
}

#Preview {
    SummaryView()
        .preferredColorScheme(.dark)
} 