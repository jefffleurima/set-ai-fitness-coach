import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfileManager()
    @State private var currentStep = 0
    @State private var tempProfile = UserProfile.default
    @State private var moveGoal = 140
    @State private var isAnimating = false
    @State private var showContent = false
    
    let userEmail: String?
    
    init(userEmail: String? = nil) {
        self.userEmail = userEmail
        // Load saved move goal or default to 140
        let savedGoal = UserDefaults.standard.integer(forKey: "moveGoal")
        self._moveGoal = State(initialValue: savedGoal != 0 ? savedGoal : 140)
    }
    
    private let totalSteps = 5
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Bar
                    progressBar
                    
                    // Content
                    TabView(selection: $currentStep) {
                        // Step 1: Welcome
                        welcomeStep
                            .tag(0)
                        
                        // Step 2: Height & Weight
                        heightWeightStep
                            .tag(1)
                        
                        // Step 3: Age & Fitness Level
                        ageFitnessStep
                            .tag(2)
                        
                        // Step 4: Goals & Experience
                        goalsExperienceStep
                            .tag(3)
                        
                        // Step 5: Workout Frequency & Move Goal
                        frequencyMoveGoalStep
                            .tag(4)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)
                    .padding(.top, 20) // Increased spacing to prevent content from being hidden
                    
                    // Navigation Buttons
                    navigationButtons
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Set up your profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.text)
                Spacer()
                Text("\(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.surface)
                    )
            }
            .padding(.horizontal)
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : -20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showContent)
            
            // Custom Progress Dots
            HStack(spacing: 12) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? AppTheme.primary : AppTheme.surface.opacity(0.3))
                        .frame(width: step <= currentStep ? 12 : 8, height: step <= currentStep ? 12 : 8)
                        .scaleEffect(step <= currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: currentStep)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 5)
    }
    
    // MARK: - Welcome Step
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 24) {
                // Animated App Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.primary)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : -30)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
                
                VStack(spacing: 20) {
                    Text("Let's personalize your experience")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: showContent)
                    
                    Text("We'll ask you a few quick questions to customize your AI coach and workout recommendations")
                        .font(.body)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
                    
                    // Feature Highlights
                    VStack(spacing: 12) {
                        FeatureHighlight(icon: "brain.head.profile", text: "AI-powered form analysis")
                        FeatureHighlight(icon: "person.2.fill", text: "Personalized coaching")
                        FeatureHighlight(icon: "chart.line.uptrend.xyaxis", text: "Progress tracking")
                    }
                    .padding(.top, 16)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: showContent)
                }
                
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation {
                isAnimating = true
                showContent = true
            }
        }
    }
    
    // MARK: - Height & Weight Step
    private var heightWeightStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 24) {
                Image(systemName: "ruler")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.primary)
                
                VStack(spacing: 16) {
                    Text("Height & Weight")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.text)
                    
                    Text("This helps us calculate your BMI and provide personalized recommendations")
                        .font(.body)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            VStack(spacing: 20) {
                // Unit System Toggle
                HStack {
                    Text("Units")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                    Spacer()
                    Picker("Units", selection: $tempProfile.unitSystem) {
                        Text("Metric").tag(UnitSystem.metric)
                        Text("Imperial").tag(UnitSystem.imperial)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 150)
                }
                
                // Height and Weight Fields
                HStack(spacing: 16) {
                    UnitToggleableField(
                        title: "Height",
                        unitSystem: $tempProfile.unitSystem,
                        storedValue: $tempProfile.height,
                        placeholder: tempProfile.unitSystem == .metric ? "170" : "5'8"
                    )
                    
                    UnitToggleableField(
                        title: "Weight",
                        unitSystem: $tempProfile.unitSystem,
                        storedValue: $tempProfile.weight,
                        placeholder: tempProfile.unitSystem == .metric ? "70" : "154"
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Age & Fitness Level Step
    private var ageFitnessStep: some View {
        VStack(spacing: 20) {
            // Header Section - Reduced spacing
            VStack(spacing: 16) {
                // Animated Icon - Smaller
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image(systemName: "person.badge.clock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.primary)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : -20)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
                
                VStack(spacing: 8) {
                    Text("Age & Fitness Level")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: showContent)
                    
                    Text("Help us understand your experience level to provide personalized recommendations")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
                }
            }
            
            // Added ScrollView for proper scrolling
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Age Input Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Your Age")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                            Spacer()
                        }
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: showContent)
                        
                        HStack(spacing: 16) {
                            // Age Display
                            ZStack {
                                Circle()
                                    .fill(AppTheme.surface)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.primary, lineWidth: 2)
                                    )
                                
                                VStack(spacing: 2) {
                                    Text("\(tempProfile.age)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.primary)
                                    Text("years")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            
                            VStack(spacing: 12) {
                                // Age Controls
                                Button(action: {
                                    if tempProfile.age < 100 {
                                        tempProfile.age += 1
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppTheme.primary)
                                }
                                .disabled(tempProfile.age >= 100)
                                
                                Button(action: {
                                    if tempProfile.age > 13 {
                                        tempProfile.age -= 1
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppTheme.primary)
                                }
                                .disabled(tempProfile.age <= 13)
                            }
                        }
                    }
                    
                    // Fitness Level Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Fitness Experience")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                            Spacer()
                        }
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.0), value: showContent)
                        
                        VStack(spacing: 12) {
                            ForEach(FitnessLevel.allCases, id: \.self) { level in
                                FitnessLevelCard(
                                    level: level,
                                    isSelected: tempProfile.fitnessLevel == level,
                                    action: { tempProfile.fitnessLevel = level }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20) // Add bottom padding for scroll
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 5)
        .onAppear {
            withAnimation {
                isAnimating = true
                showContent = true
            }
        }
    }
    
    // MARK: - Goals & Experience Step
    private var goalsExperienceStep: some View {
        VStack(spacing: 20) {
            // Header Section - Reduced spacing
            VStack(spacing: 16) {
                // Animated Icon - Smaller
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image(systemName: "target")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.primary)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : -20)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
                
                VStack(spacing: 8) {
                    Text("Goals & Experience")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.text)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: showContent)
                    
                    Text("What do you want to achieve and how much experience do you have?")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
                }
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Fitness Goals Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Primary Goal")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                            Spacer()
                        }
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: showContent)
                        
                        // Modern Goal Cards
                        VStack(spacing: 8) {
                            ForEach(FitnessGoal.allCases, id: \.self) { goal in
                                ModernGoalCard(
                                    goal: goal,
                                    isSelected: tempProfile.primaryGoal == goal,
                                    action: { tempProfile.primaryGoal = goal }
                                )
                                .opacity(showContent ? 1.0 : 0.0)
                                .offset(x: showContent ? 0 : -30)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.9 + Double(FitnessGoal.allCases.firstIndex(of: goal) ?? 0) * 0.1), value: showContent)
                            }
                        }
                    }
                    
                    // Experience Level Section - Fixed layout
                    VStack(spacing: 16) {
                        HStack {
                            Text("Experience Level")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                            Spacer()
                        }
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.2), value: showContent)
                        
                        // Modern Experience Cards - Changed to VStack to prevent cutoff
                        VStack(spacing: 12) {
                            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                                ModernExperienceCard(
                                    level: level,
                                    isSelected: tempProfile.experience == level,
                                    action: { tempProfile.experience = level }
                                )
                                .opacity(showContent ? 1.0 : 0.0)
                                .offset(y: showContent ? 0 : 30)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.3 + Double(ExperienceLevel.allCases.firstIndex(of: level) ?? 0) * 0.1), value: showContent)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20) // Add bottom padding for scroll
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 5)
        .onAppear {
            withAnimation {
                isAnimating = true
                showContent = true
            }
        }
    }
    
    // MARK: - Frequency & Move Goal Step
    private var frequencyMoveGoalStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 24) {
                Image(systemName: "figure.walk.circle")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.primary)
                
                VStack(spacing: 16) {
                    Text("Activity Level")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.text)
                    
                    Text("How often do you work out and what's your daily move goal?")
                        .font(.body)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            VStack(spacing: 24) {
                // Workout Frequency
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workout Frequency")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(WorkoutFrequency.allCases, id: \.self) { frequency in
                            Button(action: { tempProfile.workoutFrequency = frequency }) {
                                VStack(spacing: 8) {
                                    Text(frequency.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(tempProfile.workoutFrequency == frequency ? .white : AppTheme.text)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(tempProfile.workoutFrequency == frequency ? AppTheme.primary : AppTheme.surface)
                                        .stroke(tempProfile.workoutFrequency == frequency ? AppTheme.primary : AppTheme.primary.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                
                // Move Goal
                VStack(alignment: .leading, spacing: 16) {
                    Text("Daily Move Goal")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                    
                    Text("Set your daily calorie goal based on your activity level")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.bottom, 8)
                    
                    // Interactive Move Goal Selector
                    VStack(spacing: 20) {
                        HStack(spacing: 30) {
                            // Decrease Button
                            Button(action: {
                                if moveGoal > 50 {
                                    moveGoal -= 10
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(AppTheme.primary)
                            }
                            .disabled(moveGoal <= 50)
                            .opacity(moveGoal <= 50 ? 0.5 : 1.0)
                            
                            // Current Goal Display
                            VStack(spacing: 8) {
                                Text("\(moveGoal)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.text)
                                
                                Text("CALORIES/DAY")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            // Increase Button
                            Button(action: {
                                if moveGoal < 1000 {
                                    moveGoal += 10
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(AppTheme.primary)
                            }
                            .disabled(moveGoal >= 1000)
                            .opacity(moveGoal >= 1000 ? 0.5 : 1.0)
                        }
                        
                        // Goal Range Info
                        Text("Range: 50 - 1000 calories")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.surface)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .foregroundColor(AppTheme.textSecondary)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(AppTheme.surface)
                )
            }
            
            Spacer()
            
            Button(currentStep == totalSteps - 1 ? "Complete" : "Next") {
                if currentStep == totalSteps - 1 {
                    completeOnboarding()
                } else {
                    withAnimation {
                        currentStep += 1
                    }
                }
            }
            .foregroundColor(.white)
            .fontWeight(.semibold)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(AppTheme.primary)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    // MARK: - Helper Methods
    private func completeOnboarding() {
        // Save profile with user's email
        tempProfile.email = userEmail ?? "user@example.com"
        tempProfile.createdAt = Date()
        
        // Update the profile manager's profile
        profileManager.profile = tempProfile
        
        // Save profile locally
        profileManager.saveProfile()
        
        // Save to Supabase
        Task {
            do {
                // Convert UserProfile to SupabaseUserProfile
                let supabaseProfile = SupabaseUserProfile(
                    name: tempProfile.name,
                    email: tempProfile.email,
                    height: tempProfile.height,
                    weight: tempProfile.weight,
                    age: tempProfile.age,
                    unitSystem: tempProfile.unitSystem,
                    fitnessLevel: tempProfile.fitnessLevel,
                    primaryGoal: tempProfile.primaryGoal,
                    experience: tempProfile.experience,
                    workoutFrequency: tempProfile.workoutFrequency,
                    notificationsEnabled: true,
                    dataSharingEnabled: true,
                    moveGoal: moveGoal,
                    createdAt: tempProfile.createdAt
                )
                
                try await SupabaseManager.shared.saveUserProfile(supabaseProfile)
                print("✅ Profile saved to Supabase")
            } catch {
                print("❌ Failed to save profile to Supabase: \(error)")
            }
        }
        
        // Save move goal to both UserDefaults and ProfileManager
        UserDefaults.standard.set(moveGoal, forKey: "userMoveGoal")
        UserDefaults.standard.set(moveGoal, forKey: "moveGoal") // Also save to ProfileManager's key
        
        // Dismiss onboarding
        dismiss()
    }
}

// MARK: - Supporting Views

struct FeatureHighlight: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.primary)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct FitnessLevelCard: View {
    let level: FitnessLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? AppTheme.primary : AppTheme.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: level.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .white : AppTheme.primary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : AppTheme.text)
                    
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppTheme.primary : AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.primary.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Card Components

struct ModernGoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? .white : AppTheme.primary.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: goal.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? AppTheme.primary : AppTheme.primary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : AppTheme.text)
                    
                    Text(goal.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppTheme.primary : AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.primary.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: isSelected ? AppTheme.primary.opacity(0.3) : Color.clear,
                        radius: isSelected ? 8 : 0,
                        x: 0,
                        y: isSelected ? 4 : 0
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernExperienceCard: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? .white : AppTheme.primary.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: level.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(isSelected ? AppTheme.primary : AppTheme.primary)
                }
                
                // Content
                VStack(spacing: 4) {
                    Text(level.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : AppTheme.text)
                        .multilineTextAlignment(.center)
                    
                    Text(level.description)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppTheme.primary : AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.primary.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: isSelected ? AppTheme.primary.opacity(0.3) : Color.clear,
                        radius: isSelected ? 8 : 0,
                        x: 0,
                        y: isSelected ? 4 : 0
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Note: GoalSelectionCard, ExperienceSelectionCard, and ChangeMoveGoalView are defined in ProfileView.swift

#Preview {
    OnboardingView()
}
