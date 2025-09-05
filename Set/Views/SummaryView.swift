import SwiftUI
import HealthKit
import Foundation
import Vision

// MARK: - Data Models

struct WorkoutSession: Identifiable {
    let id = UUID()
    let date: Date
    let exercise: Exercise
    let reps: Int
    let sets: Int
    let formScore: Int
    let aiTips: [String]
    
    static let sampleData: [WorkoutSession] = [
        WorkoutSession(
            date: Date(),
            exercise: createSampleSquatExercise(),
            reps: 12,
            sets: 3,
            formScore: 85,
            aiTips: ["Great depth on squats!", "Keep core tight"]
        ),
        WorkoutSession(
            date: Date().addingTimeInterval(-86400),
            exercise: createSampleDeadliftExercise(),
            reps: 15,
            sets: 3,
            formScore: 90,
            aiTips: ["Perfect form!", "Try to go a bit deeper"]
        )
    ]
    
    // Sample exercise creation methods
    private static func createSampleSquatExercise() -> Exercise {
        return Exercise(
            name: "squats",
            category: .legs,
            description: "A fundamental lower body exercise that targets the quadriceps, hamstrings, and glutes.",
            imageName: "figure.strengthtraining.traditional",
            formRequirements: [
                "bottom": [
                    "kneeAngle": 85.0...110.0,
                    "hipAngle": 45.0...65.0,
                    "torsoAngle": 30.0...50.0,
                    "ankleAngle": 60.0...85.0
                ],
                "top": [
                    "kneeAngle": 160.0...180.0,
                    "hipAngle": 160.0...180.0,
                    "torsoAngle": 170.0...180.0,
                    "ankleAngle": 80.0...100.0
                ]
            ],
            keyJoints: [
                [.leftHip, .leftKnee, .leftAnkle],
                [.rightHip, .rightKnee, .rightAnkle]
            ],
            squatVariation: .balanced
        )
    }
    
    private static func createSampleDeadliftExercise() -> Exercise {
        return Exercise(
            name: "deadlifts",
            category: .legs,
            description: "A compound exercise that works the entire posterior chain, including the back, glutes, and hamstrings.",
            imageName: "figure.strengthtraining.functional",
            formRequirements: [
                "bottom": [
                    "hipHingeAngle": 20.0...50.0,
                    "backAngle": 165.0...195.0,
                    "kneeAngle": 100.0...140.0
                ],
                "top": [
                    "hipHingeAngle": 170.0...190.0,
                    "backAngle": 170.0...190.0,
                    "kneeAngle": 170.0...190.0
                ]
            ],
            keyJoints: [
                [.leftShoulder, .leftHip, .leftKnee],
                [.rightShoulder, .rightHip, .rightKnee]
            ],
            squatVariation: nil
        )
    }
}

struct SummaryView: View {
    @State private var workouts: [WorkoutSession] = WorkoutSession.sampleData
    @State private var healthData = HealthData()
    @State private var showingHealthKitPermission = false
    @State private var showingActivityDetail = false
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
                requestHealthKitPermissions()
            }
            .sheet(isPresented: $showingActivityDetail) {
                ActivityDetailView(healthData: healthData)
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
                            .trim(from: 0, to: animateRings ? CGFloat(healthData.moveProgress) : 0)
                            .stroke(AppTheme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.2).delay(0.2), value: animateRings)
                        
                        // Center content
                        VStack(spacing: 1) {
                            Text("\(healthData.calories)")
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
                            
                            Text("\(healthData.calories) of \(healthData.moveGoal) calories")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        
                        // Progress indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 6, height: 6)
                            
                            Text("\(Int(healthData.moveProgress * 100))% complete")
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
                    StatRow(value: "\(healthData.duration)", unit: "min", color: AppTheme.primary)
                    StatRow(value: "\(todayWorkouts)", unit: "Workouts today", color: .green)
                    StatRow(value: "\(strengthImprovement)%", unit: "Strength improvement", color: AppTheme.primary)
                }
                
                Spacer()
            }
            
            // Exercise breakdown
            if !workouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Exercise")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.text)
                    
                    HStack {
                        Text(workouts.first?.exercise.name ?? "No exercises")
                            .font(.body)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("\(workouts.first?.formScore ?? 0)% form")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(workouts.first?.formScore ?? 0 >= 80 ? .green : .orange)
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
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeedbackRow(icon: "checkmark.circle.fill", title: "What's working well", color: .green)
                FeedbackRow(icon: "target", title: "Areas to focus on", color: .orange)
                FeedbackRow(icon: "lightbulb.fill", title: "Next session recommendations", color: AppTheme.primary)
            }
        }
        .padding(20)
        .background(AppTheme.surface)
        .cornerRadius(16)
    }
    
    // MARK: - Quick Stats Grid
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            QuickStatCard(title: "Step Count", value: "\(healthData.steps)", subtitle: "Today", color: .purple)
            QuickStatCard(title: "Active Energy", value: "\(healthData.activeEnergy)", subtitle: "CAL", color: .red)
            QuickStatCard(title: "Sessions", value: "\(todayWorkouts)", subtitle: "Workout App", color: .green)
            QuickStatCard(title: "Step Distance", value: "\(healthData.stepDistance)", subtitle: "km", color: .purple)
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
                ForEach(workouts.prefix(3)) { workout in
                    WorkoutHistoryCard(workout: workout)
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
        guard !workouts.isEmpty else { return 0 }
        return workouts.map { Double($0.formScore) }.reduce(0, +) / Double(workouts.count)
    }
    
    private var workoutsThisWeek: Int {
        // TODO: Calculate actual workouts this week
        return 6
    }
    
    private var strengthImprovement: Int {
        // TODO: Calculate actual strength improvement
        return 23
    }
    
    private var todayWorkouts: Int {
        // TODO: Calculate today's workouts
        return 1
    }
    
    // MARK: - HealthKit Integration
    private func requestHealthKitPermissions() {
        // TODO: Implement HealthKit permission request
        print("🏥 Requesting HealthKit permissions...")
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

struct HealthData {
    var calories: Int = 356
    var duration: Int = 45
    var steps: Int = 8247
    var activeEnergy: Int = 420
    var stepDistance: Double = 6.2
    
    // Activity Ring Data
    var moveGoal: Int = 500
    var exerciseGoal: Int = 30
    var standGoal: Int = 12
    
    var exerciseMinutes: Int = 22
    var standHours: Int = 8
    
    var moveProgress: Double {
        return min(Double(calories) / Double(moveGoal), 1.0)
    }
    
    var exerciseProgress: Double {
        return min(Double(exerciseMinutes) / Double(exerciseGoal), 1.0)
    }
    
    var standProgress: Double {
        return min(Double(standHours) / Double(standGoal), 1.0)
    }
    
    // TODO: Replace with actual HealthKit data
}

// MARK: - Activity Detail View

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let healthData: HealthData
    @State private var animateRings = false
    @State private var showingGoalMenu = false
    
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
                            activityStatsFullScreen
                            
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
                            .trim(from: 0, to: day == "F" ? CGFloat(healthData.moveProgress) : Double.random(in: 0.3...1.0))
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
                    .trim(from: 0, to: animateRings ? CGFloat(healthData.moveProgress) : 0)
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
                    Text("\(healthData.calories)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                    
                    Text("/\(healthData.moveGoal)")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    
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
    private var activityStatsFullScreen: some View {
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
                
                Text("\(healthData.steps)")
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
                    Text("\(String(format: "%.2f", healthData.stepDistance))")
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
                        .frame(height: CGFloat.random(in: 6...32))
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
                Text("1,243 CAL")
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
    private var activityStatsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Steps")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(healthData.steps)")
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
                    Text("\(String(format: "%.2f", healthData.stepDistance)) MI")
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

// MARK: - Activity History View

struct ActivityHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Selected date stats
                        selectedDateStatsCard
                        
                        // Calendar grid
                        calendarGrid
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle(dateFormatter.string(from: selectedDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                }
            }
        }
    }
    
    private var selectedDateStatsCard: some View {
        VStack(spacing: 16) {
            Text(DateFormatter.dayFormatter.string(from: selectedDate))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.text)
            
            HStack(spacing: 40) {
                // Activity ring for selected date
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7) // Sample data
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("Move: 420/500 CAL")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.text)
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.surface)
        .cornerRadius(16)
    }
    
    private var calendarGrid: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppTheme.primary)
                        .font(.title2)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.text)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.primary)
                        .font(.title2)
                }
            }
            
            // Days of week header
            HStack {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendarDays, id: \.self) { date in
                    CalendarDayView(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate)) {
                        withAnimation(.spring()) {
                            selectedDate = date
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.surface)
        .cornerRadius(16)
    }
    
    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else {
            return []
        }
        
        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end
        
        // Get the first day of the week for the month
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysFromPreviousMonth = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [Date] = []
        
        // Add days from previous month
        for i in (1...daysFromPreviousMonth).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: monthStart) {
                days.append(date)
            }
        }
        
        // Add days from current month
        var currentDate = monthStart
        while currentDate < monthEnd {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Add days from next month to fill the grid
        let remainingDays = 42 - days.count // 6 weeks * 7 days
        for i in 0..<remainingDays {
            if let date = calendar.date(byAdding: .day, value: i, to: monthEnd) {
                days.append(date)
            }
        }
        
        return days
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