import SwiftUI

// MARK: - Step Count Detail View
struct StepCountDetailView: View {
    @ObservedObject var healthKitManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTimeframe: TimeFrame = .day
    
    enum TimeFrame: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case year = "Y"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOTAL")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("\(healthKitManager.getTodayStepCount())")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                            
                            Text("Today")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Timeframe Selector
                        HStack(spacing: 12) {
                            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                                Button(action: {
                                    selectedTimeframe = timeframe
                                }) {
                                    Text(timeframe.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedTimeframe == timeframe ? .white : AppTheme.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTimeframe == timeframe ? Color.gray.opacity(0.3) : Color.clear)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Chart
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Hourly Activity")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                                .padding(.horizontal, 20)
                            
                            StepCountChart(data: healthKitManager.hourlyStepCount)
                                .frame(height: 200)
                                .padding(.horizontal, 20)
                        }
                        
                        // View All Button
                        Button(action: {
                            // TODO: Navigate to all step metrics
                        }) {
                            Text("View All Steps Metrics")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.surface)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppTheme.primary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Step Count")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                }
            }
        }
    }
}

// MARK: - Step Count Chart
struct StepCountChart: View {
    let data: [Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Y-axis labels
            HStack {
                VStack(alignment: .trailing, spacing: 40) {
                    Text("2,000")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("1,000")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("0")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(width: 40)
                
                // Chart area
                VStack(spacing: 0) {
                    // Grid lines and bars
                    ZStack {
                        // Grid lines
                        VStack(spacing: 40) {
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                        }
                        
                        // Bars
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<min(24, data.count), id: \.self) { hour in
                                let value = max(data[hour], 0) // Ensure value is non-negative
                                let maxValue = max(data.max() ?? 1, 1) // Ensure maxValue is at least 1
                                let height = max(CGFloat(value) / CGFloat(maxValue) * 120, 0) // Ensure height is non-negative
                                
                                Rectangle()
                                    .fill(.purple)
                                    .frame(width: 8, height: max(height, 2))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 120)
                    
                    // X-axis labels
                    HStack {
                        ForEach([0, 6, 12, 18], id: \.self) { hour in
                            Text(String(format: "%02d", hour))
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Active Energy Detail View
struct ActiveEnergyDetailView: View {
    @ObservedObject var healthKitManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTimeframe: TimeFrame = .day
    
    enum TimeFrame: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case year = "Y"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOTAL")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("\(healthKitManager.getTodayCalories())")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                            
                            Text("Today")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Timeframe Selector
                        HStack(spacing: 12) {
                            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                                Button(action: {
                                    selectedTimeframe = timeframe
                                }) {
                                    Text(timeframe.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedTimeframe == timeframe ? .white : AppTheme.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTimeframe == timeframe ? Color.gray.opacity(0.3) : Color.clear)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Chart
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Hourly Activity")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                                .padding(.horizontal, 20)
                            
                            ActiveEnergyChart(data: healthKitManager.hourlyCalories)
                                .frame(height: 200)
                                .padding(.horizontal, 20)
                        }
                        
                        // View All Button
                        Button(action: {
                            // TODO: Navigate to all calorie metrics
                        }) {
                            Text("View All Calories Metrics")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.surface)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppTheme.primary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Active Energy")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                }
            }
        }
    }
}

// MARK: - Active Energy Chart
struct ActiveEnergyChart: View {
    let data: [Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Y-axis labels
            HStack {
                VStack(alignment: .trailing, spacing: 40) {
                    Text("50")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("25")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("0")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(width: 40)
                
                // Chart area
                VStack(spacing: 0) {
                    // Grid lines and bars
                    ZStack {
                        // Grid lines
                        VStack(spacing: 40) {
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                        }
                        
                        // Bars
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<min(24, data.count), id: \.self) { hour in
                                let value = max(data[hour], 0) // Ensure value is non-negative
                                let maxValue = max(data.max() ?? 1, 1) // Ensure maxValue is at least 1
                                let height = max(CGFloat(value) / CGFloat(maxValue) * 120, 0) // Ensure height is non-negative
                                
                                Rectangle()
                                    .fill(.red)
                                    .frame(width: 8, height: max(height, 2))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 120)
                    
                    // X-axis labels
                    HStack {
                        ForEach([0, 6, 12, 18], id: \.self) { hour in
                            Text(String(format: "%02d", hour))
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Step Distance Detail View
struct StepDistanceDetailView: View {
    @ObservedObject var healthKitManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTimeframe: TimeFrame = .day
    
    enum TimeFrame: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case year = "Y"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOTAL")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("\(String(format: "%.2f", healthKitManager.getTodayStepDistance()))MI")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                            
                            Text("Today")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Timeframe Selector
                        HStack(spacing: 12) {
                            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                                Button(action: {
                                    selectedTimeframe = timeframe
                                }) {
                                    Text(timeframe.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedTimeframe == timeframe ? .white : AppTheme.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTimeframe == timeframe ? Color.gray.opacity(0.3) : Color.clear)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Chart
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Hourly Activity")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                                .padding(.horizontal, 20)
                            
                            StepDistanceChart(data: healthKitManager.hourlyStepDistance)
                                .frame(height: 200)
                                .padding(.horizontal, 20)
                        }
                        
                        // View All Button
                        Button(action: {
                            // TODO: Navigate to all distance metrics
                        }) {
                            Text("View All Distance Metrics")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.surface)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppTheme.primary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Step Distance")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                }
            }
        }
    }
}

// MARK: - Step Distance Chart
struct StepDistanceChart: View {
    let data: [Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Y-axis labels
            HStack {
                VStack(alignment: .trailing, spacing: 40) {
                    Text("1.00")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("0.50")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("0.00")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(width: 40)
                
                // Chart area
                VStack(spacing: 0) {
                    // Grid lines and bars
                    ZStack {
                        // Grid lines
                        VStack(spacing: 40) {
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(height: 1)
                        }
                        
                        // Bars
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<min(24, data.count), id: \.self) { hour in
                                let value = max(data[hour], 0.0) // Ensure value is non-negative
                                let maxValue = max(data.max() ?? 1.0, 1.0) // Ensure maxValue is at least 1.0
                                let height = max(CGFloat(value) / CGFloat(maxValue) * 120, 0) // Ensure height is non-negative
                                
                                Rectangle()
                                    .fill(.blue)
                                    .frame(width: 8, height: max(height, 2))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 120)
                    
                    // X-axis labels
                    HStack {
                        ForEach([0, 6, 12, 18], id: \.self) { hour in
                            Text(String(format: "%02d", hour))
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Sessions Detail View
struct SessionsDetailView: View {
    @ObservedObject var healthKitManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOTAL SESSIONS")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("\(healthKitManager.getWeeklyWorkouts())")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                            
                            Text("This Week")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Workout History
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Workouts")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                                .padding(.horizontal, 20)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(healthKitManager.workoutSessions.prefix(10)) { session in
                                    WorkoutSessionRow(session: session)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // View All Button
                        Button(action: {
                            // TODO: Navigate to all workout sessions
                        }) {
                            Text("View All Workout Sessions")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.surface)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppTheme.primary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Sessions")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                }
            }
        }
    }
}

// MARK: - Workout Session Row
struct WorkoutSessionRow: View {
    let session: WorkoutSession
    
    var body: some View {
        HStack(spacing: 16) {
            // Exercise icon
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 40, height: 40)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            
            // Exercise details
            VStack(alignment: .leading, spacing: 4) {
                Text(session.exercise.name.capitalized)
                    .font(.headline)
                    .foregroundColor(AppTheme.text)
                
                Text("\(session.sets) sets × \(session.reps) reps")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            // Form score and time
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.formScore)%")
                    .font(.headline)
                    .foregroundColor(session.formScore >= 80 ? .green : .orange)
                
                Text(formatDate(session.date))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(AppTheme.surface)
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
