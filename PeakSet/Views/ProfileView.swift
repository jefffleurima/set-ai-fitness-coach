import SwiftUI
import UserNotifications

// MARK: - User Profile Data Models
enum UnitSystem: String, CaseIterable, Codable {
    case metric = "Metric"
    case imperial = "Imperial"
    
    // Conversion functions
    func heightToDisplay(_ cm: Double) -> Double {
        switch self {
        case .metric:
            return cm
        case .imperial:
            return cm / 2.54 // cm to inches
        }
    }
    
    func weightToDisplay(_ kg: Double) -> Double {
        switch self {
        case .metric:
            return kg
        case .imperial:
            return kg * 2.20462 // kg to lbs
        }
    }
    
    func heightFromDisplay(_ value: Double) -> Double {
        switch self {
        case .metric:
            return value
        case .imperial:
            return value * 2.54 // inches to cm
        }
    }
    
    func weightFromDisplay(_ value: Double) -> Double {
        switch self {
        case .metric:
            return value
        case .imperial:
            return value / 2.20462 // lbs to kg
        }
    }
    
    var heightUnit: String {
        switch self {
        case .metric:
            return "cm"
        case .imperial:
            return "ft"
        }
    }
    
    var weightUnit: String {
        switch self {
        case .metric:
            return "kg"
        case .imperial:
            return "lbs"
        }
    }
    
    // Format functions for display
    func formatHeight(_ cm: Double) -> String {
        switch self {
        case .metric:
            return "\(Int(cm)) cm"
        case .imperial:
            let totalInches = cm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        }
    }
    
    func formatWeight(_ kg: Double) -> String {
        switch self {
        case .metric:
            return "\(Int(kg)) kg"
        case .imperial:
            let lbs = kg * 2.20462
            return "\(Int(lbs)) lbs"
        }
    }
}

struct UserProfile {
    var name: String
    var email: String
    var height: Double // stored in cm
    var weight: Double // stored in kg
    var age: Int
    var unitSystem: UnitSystem
    var fitnessLevel: FitnessLevel
    var primaryGoal: FitnessGoal
    var experience: ExperienceLevel
    var workoutFrequency: WorkoutFrequency
    var notificationsEnabled: Bool
    var dataSharingEnabled: Bool
    var createdAt: Date
    
    static let `default` = UserProfile(
        name: "",
        email: "",
        height: 170.0,
        weight: 70.0,
        age: 25,
        unitSystem: .metric,
        fitnessLevel: .intermediate,
        primaryGoal: .strength,
        experience: .intermediate,
        workoutFrequency: .threeTimesPerWeek,
        notificationsEnabled: false,
        dataSharingEnabled: true,
        createdAt: Date()
    )
}

enum FitnessLevel: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    
    var description: String {
        switch self {
        case .beginner: return "New to strength training"
        case .intermediate: return "Some experience with weights"
        case .advanced: return "Regular strength training"
        case .expert: return "Years of experience"
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.strengthtraining.traditional"
        case .advanced: return "figure.strengthtraining.functional"
        case .expert: return "crown.fill"
        }
    }
}

enum FitnessGoal: String, CaseIterable, Codable {
    case strength = "Strength"
    case muscle = "Muscle Building"
    case endurance = "Endurance"
    case weightLoss = "Weight Loss"
    case general = "General Fitness"
    
    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .muscle: return "figure.strengthtraining.traditional"
        case .endurance: return "figure.run"
        case .weightLoss: return "scalemass.fill"
        case .general: return "heart.fill"
        }
    }
    
    var description: String {
        switch self {
        case .strength: return "Build strength and power"
        case .muscle: return "Increase muscle mass"
        case .endurance: return "Improve cardiovascular fitness"
        case .weightLoss: return "Burn calories and lose weight"
        case .general: return "Overall health and wellness"
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    var description: String {
        switch self {
        case .beginner: return "0-6 months"
        case .intermediate: return "6 months - 2 years"
        case .advanced: return "2+ years"
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.strengthtraining.traditional"
        case .advanced: return "crown.fill"
        }
    }
}

enum WorkoutFrequency: String, CaseIterable, Codable {
    case oneTimePerWeek = "1x per week"
    case twoTimesPerWeek = "2x per week"
    case threeTimesPerWeek = "3x per week"
    case fourTimesPerWeek = "4x per week"
    case fivePlusTimesPerWeek = "5+ times per week"
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfileManager()
    @ObservedObject private var healthData = HealthData.shared
    @State private var showingEditProfile = false
    @State private var showingFitnessGoals = false
    @State private var showingExperienceLevel = false
    @State private var showingChangeMoveGoal = false
    @State private var showingNotifications = false
    @State private var showingAbout = false
    @State private var showingDataCollection = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Profile Header
                        profileHeaderView
                        
                        // Profile Categories
                        VStack(spacing: 12) {
                            // Personal Information
                            ProfileSection(
                                title: "Personal Information",
                                icon: "person.circle.fill",
                                items: [
                                    ProfileItem(
                                        icon: "person.fill",
                                        title: "Profile Details",
                                        subtitle: profileManager.profile.email.isEmpty ? "Email, height, weight, age" : "\(profileManager.profile.email) • \(profileManager.profile.unitSystem.formatHeight(profileManager.profile.height)) • \(profileManager.profile.unitSystem.formatWeight(profileManager.profile.weight))",
                                        action: { showingEditProfile = true }
                                    ),
                                    ProfileItem(
                                        icon: "target",
                                        title: "Fitness Goals",
                                        subtitle: profileManager.profile.primaryGoal.rawValue,
                                        action: { showingFitnessGoals = true }
                                    ),
                                    ProfileItem(
                                        icon: "chart.bar.fill",
                                        title: "Experience Level",
                                        subtitle: profileManager.profile.experience.rawValue,
                                        action: { showingExperienceLevel = true }
                                    ),
                                    
                                    ProfileItem(
                                        icon: "figure.walk.circle.fill",
                                        title: "Change Move Goal",
                                        subtitle: "\(healthData.moveGoal) calories/day",
                                        action: { showingChangeMoveGoal = true }
                                    )
                                ]
                            )
                            
                            // App Settings
                            ProfileSection(
                                title: "App Settings",
                                icon: "gearshape.fill",
                                items: [
                                    ProfileItem(
                                        icon: "bell.fill",
                                        title: "Notifications",
                                        subtitle: NotificationManager.shared.permissionStatus == .authorized ? "Enabled" : "Disabled",
                                        action: { showingNotifications = true }
                                    ),
                                   
                                ]
                            )
                            
                            // Data & Privacy
                            ProfileSection(
                                title: "Data & Privacy",
                                icon: "shield.fill",
                                items: [
                                    ProfileItem(
                                        icon: "chart.line.uptrend.xyaxis",
                                        title: "Data Collection",
                                        subtitle: profileManager.profile.dataSharingEnabled ? "Participating" : "Opted out",
                                        action: { showingDataCollection = true }
                                    ),
                                    ProfileItem(
                                        icon: "info.circle.fill",
                                        title: "About",
                                        subtitle: "App info and research details",
                                        action: { showingAbout = true }
                                    )
                                ]
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(profileManager: profileManager)
            }
            .sheet(isPresented: $showingFitnessGoals) {
                FitnessGoalsView(profileManager: profileManager)
            }
            .sheet(isPresented: $showingExperienceLevel) {
                ExperienceLevelView(profileManager: profileManager)
            }
            .sheet(isPresented: $showingChangeMoveGoal) {
                ChangeMoveGoalView()
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationSettingsView(profileManager: profileManager)
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingDataCollection) {
                DataCollectionView(profileManager: profileManager)
            }
        }
    }
    
    private var profileHeaderView: some View {
        VStack(spacing: 8) {
            // Empty header - title is in navigation bar
        }
        .padding(.top, 8)
    }
    
}

// MARK: - Change Move Goal View
struct ChangeMoveGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var healthData = HealthData.shared
    @State private var currentGoal: Int
    @State private var isAnimating = false
    
    init() {
        let savedGoal = HealthData.shared.moveGoal
        self._currentGoal = State(initialValue: savedGoal)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Text("Daily Move Goal")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.text)
                        
                        Text("Set a goal based on how active you are, or how active you'd like to be, each day.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Goal Adjustment Section
                    VStack(spacing: 24) {
                        // Current Goal Display with Side Buttons
                        HStack(spacing: 30) {
                            // Decrease Button
                            Button(action: {
                                if currentGoal > 50 {
                                    currentGoal -= 10
                                    triggerAnimation()
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(AppTheme.primary)
                            }
                            .disabled(currentGoal <= 50)
                            .opacity(currentGoal <= 50 ? 0.5 : 1.0)
                            
                            // Current Goal Display
                            VStack(spacing: 8) {
                                Text("\(currentGoal)")
                                    .font(.system(size: 72, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.text)
                                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                                
                                Text("CALORIES/DAY")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            // Increase Button
                            Button(action: {
                                if currentGoal < 1000 {
                                    currentGoal += 10
                                    triggerAnimation()
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(AppTheme.primary)
                            }
                            .disabled(currentGoal >= 1000)
                            .opacity(currentGoal >= 1000 ? 0.5 : 1.0)
                        }
                    }
                    
                    Spacer()
                    
                    // Change Goal Button
                    Button(action: {
                        healthData.updateMoveGoal(currentGoal)
                        dismiss()
                    }) {
                        Text("Change Move Goal")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Move Goal")
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
    
    private func triggerAnimation() {
        isAnimating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isAnimating = false
        }
    }
}

// MARK: - Profile Manager
class ProfileManager: ObservableObject {
    @Published var profile: UserProfile = UserProfile.default
    
    // Mock data for now - in real app, this would come from HealthKit or user input
    var sessionCount: Int { 12 }
    var totalReps: Int { 456 }
    var averageScore: Int { 78 }
    
    init() {
        loadProfile()
    }
    
    func saveProfile() {
        // In real app, save to UserDefaults or Core Data
        UserDefaults.standard.set(profile.email, forKey: "userEmail")
        UserDefaults.standard.set(profile.name, forKey: "userName")
        UserDefaults.standard.set(profile.height, forKey: "userHeight")
        UserDefaults.standard.set(profile.weight, forKey: "userWeight")
        UserDefaults.standard.set(profile.age, forKey: "userAge")
        UserDefaults.standard.set(profile.unitSystem.rawValue, forKey: "unitSystem")
        UserDefaults.standard.set(profile.fitnessLevel.rawValue, forKey: "fitnessLevel")
        UserDefaults.standard.set(profile.primaryGoal.rawValue, forKey: "primaryGoal")
        UserDefaults.standard.set(profile.experience.rawValue, forKey: "experience")
        UserDefaults.standard.set(profile.workoutFrequency.rawValue, forKey: "workoutFrequency")
        UserDefaults.standard.set(profile.notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(profile.dataSharingEnabled, forKey: "dataSharingEnabled")
    }
    
    private func loadProfile() {
        profile.email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        profile.name = UserDefaults.standard.string(forKey: "userName") ?? ""
        profile.height = UserDefaults.standard.double(forKey: "userHeight") == 0 ? 170.0 : UserDefaults.standard.double(forKey: "userHeight")
        profile.weight = UserDefaults.standard.double(forKey: "userWeight") == 0 ? 70.0 : UserDefaults.standard.double(forKey: "userWeight")
        profile.age = UserDefaults.standard.integer(forKey: "userAge") == 0 ? 25 : UserDefaults.standard.integer(forKey: "userAge")
        profile.unitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: "unitSystem") ?? "Metric") ?? .metric
        profile.fitnessLevel = FitnessLevel(rawValue: UserDefaults.standard.string(forKey: "fitnessLevel") ?? "Intermediate") ?? .intermediate
        profile.primaryGoal = FitnessGoal(rawValue: UserDefaults.standard.string(forKey: "primaryGoal") ?? "Strength") ?? .strength
        profile.experience = ExperienceLevel(rawValue: UserDefaults.standard.string(forKey: "experience") ?? "Intermediate") ?? .intermediate
        profile.workoutFrequency = WorkoutFrequency(rawValue: UserDefaults.standard.string(forKey: "workoutFrequency") ?? "3x per week") ?? .threeTimesPerWeek
        // Don't default to true - check actual permission status
        profile.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? false
        profile.dataSharingEnabled = UserDefaults.standard.object(forKey: "dataSharingEnabled") as? Bool ?? true
    }
}

// MARK: - Supporting Views

struct ProfileSection: View {
    let title: String
    let icon: String
    let items: [ProfileItem]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.primary)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.text)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    ProfileItemView(item: item)
                }
            }
        }
    }
}

struct ProfileItem {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
}

struct ProfileItemView: View {
    let item: ProfileItem
    
    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.text)
                    
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.surface)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.text)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: ProfileManager
    @State private var tempProfile: UserProfile
    
    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
        self._tempProfile = State(initialValue: profileManager.profile)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with Avatar
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primary.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(AppTheme.primary)
                            }
                            
                            Text("Update your personal information")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Profile Form
                        VStack(spacing: 20) {
                            // Email Section
                            ProfileFormSection(
                                icon: "envelope.fill",
                                title: "Email",
                                content: {
                                    CustomTextField(
                                        text: $tempProfile.email,
                                        placeholder: "Enter your email",
                                        keyboardType: .emailAddress
                                    )
                                }
                            )
                            
                            // Physical Stats Section
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "ruler")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(AppTheme.primary)
                                        .frame(width: 24)
                                    
                                    Text("Physical Stats")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.text)
                                    
                                    Spacer()
                                }
                                
                                HStack(spacing: 16) {
                                    UnitToggleableField(
                                        title: "Height",
                                        unitSystem: $tempProfile.unitSystem,
                                        storedValue: $tempProfile.height,
                                        placeholder: "170"
                                    )
                                    
                                    UnitToggleableField(
                                        title: "Weight",
                                        unitSystem: $tempProfile.unitSystem,
                                        storedValue: $tempProfile.weight,
                                        placeholder: "70"
                                    )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.surface)
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            )
                            
                            // Age Section
                            ProfileFormSection(
                                icon: "calendar",
                                title: "Age",
                                content: {
                                    CustomTextField(
                                        text: Binding(
                                            get: { String(tempProfile.age) },
                                            set: { tempProfile.age = Int($0) ?? 0 }
                                        ),
                                        placeholder: "25",
                                        keyboardType: .numberPad
                                    )
                                }
                            )
                        }
                        
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Profile Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save locally
                        profileManager.profile = tempProfile
                        profileManager.saveProfile()
                        
                        // Save to Supabase
                        Task {
                            do {
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
                                    notificationsEnabled: tempProfile.notificationsEnabled,
                                    dataSharingEnabled: tempProfile.dataSharingEnabled,
                                    moveGoal: HealthData.shared.moveGoal,
                                    createdAt: tempProfile.createdAt
                                )
                                
                                try await SupabaseManager.shared.saveUserProfile(supabaseProfile)
                                print("✅ Profile updates saved to Supabase")
                            } catch {
                                print("❌ Failed to save profile to Supabase: \(error)")
                            }
                        }
                        
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ProfileField<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.text)
            
            content
        }
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: ProfileManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showSettingsAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Notification Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.text)
                        .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        // Toggle for notifications
                        Toggle("Enable Notifications", isOn: Binding(
                            get: { 
                                notificationManager.permissionStatus == .authorized
                            },
                            set: { isEnabled in
                                if isEnabled {
                                    // Request permission
                                    notificationManager.requestPermission()
                                    
                                    // Check status after delay to update UI
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        notificationManager.checkPermissionStatus()
                                    }
                                } else {
                                    // User trying to disable - show alert to go to Settings
                                    showSettingsAlert = true
                                }
                            }
                        ))
                        .foregroundColor(AppTheme.text)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.surface)
                        )
                        
                        // Status message - only show when needed
                        if notificationManager.permissionStatus == .denied {
                            Text("Go to Settings → PeakSet → Notifications to enable")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else if notificationManager.permissionStatus == .notDetermined {
                            Text("Turn on the toggle above to enable AI workout notifications")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        // No message when authorized - toggle state is self-explanatory
                        
                        if notificationManager.permissionStatus == .authorized {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("You'll receive:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.text)
                                
                                VStack(spacing: 8) {
                                    NotificationOption(
                                        title: "AI Workout Feedback", 
                                        subtitle: "Get notified when Rex analyzes your workout form"
                                    )
                                    NotificationOption(
                                        title: "Form Analysis Complete", 
                                        subtitle: "Receive feedback after each exercise session"
                                    )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.surface.opacity(0.5))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        profileManager.saveProfile()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Refresh permission status when view appears
                print("🔔 NotificationSettingsView: Checking permission status on appear")
                notificationManager.checkPermissionStatus()
            }
            .alert("Open iOS Settings", isPresented: $showSettingsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            } message: {
                Text("To change notification permissions, go to:\n\nSettings → PeakSet → Notifications")
            }
        }
    }
}

struct NotificationOption: View {
    let title: String
    let subtitle: String
    @State private var isEnabled = true
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.text)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // App Icon and Info
                        VStack(spacing: 16) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(AppTheme.primary)
                            
                            Text("PeakSet")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.text)
                            
                            Text("Version 1.0.0 Beta")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // About Section
                        VStack(spacing: 16) {
                            AboutSection(
                                title: "About PeakSet",
                                content: "PeakSet is a research application focused on improving fitness form through AI-powered computer vision analysis. We're collecting anonymized data to advance fitness technology."
                            )
                            
                            AboutSection(
                                title: "Research Purpose",
                                content: "Your participation helps us understand movement patterns, improve form analysis algorithms, and develop better fitness coaching tools for everyone."
                            )
                            
                            AboutSection(
                                title: "Data Privacy",
                                content: "All data is anonymized and encrypted. No personal information is shared with third parties. You can opt out of data collection at any time in settings."
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct AboutSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.text)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
        )
    }
}

// MARK: - App Settings View
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: ProfileManager
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        // Icon
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.primary)
                        
                        VStack(spacing: 12) {
                            Text("App Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.text)
                            
                            Text("All settings are now organized in dedicated sections")
                                .font(.body)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Go to Profile")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct SettingsSection: View {
    let title: String
    let items: [SettingsItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.text)
            
            VStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    SettingsItemView(item: item)
                }
            }
        }
    }
}

struct SettingsItem {
    let title: String
    let subtitle: String
    let action: () -> Void
}

struct SettingsItemView: View {
    let item: SettingsItem
    
    var body: some View {
        Button(action: item.action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.text)
                    
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.surface)
            )
        }
    }
}

// MARK: - Data Collection View
struct DataCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: ProfileManager
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.primary)
                            
                            Text("Data Collection")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.text)
                        }
                        .padding(.top, 20)
                        
                        // Data Collection Status
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: profileManager.profile.dataSharingEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(profileManager.profile.dataSharingEnabled ? .green : .red)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Data Collection")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.text)
                                    
                                    Text(profileManager.profile.dataSharingEnabled ? "Currently participating" : "Opted out")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $profileManager.profile.dataSharingEnabled)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.surface)
                            )
                        }
                        
                        // Data Types
                        if profileManager.profile.dataSharingEnabled {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("What We Collect")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.text)
                                
                                VStack(spacing: 12) {
                                    DataTypeItem(
                                        icon: "figure.strengthtraining.traditional",
                                        title: "Movement Patterns",
                                        description: "Joint positions and movement trajectories during exercises"
                                    )
                                    
                                    DataTypeItem(
                                        icon: "chart.bar.fill",
                                        title: "Form Scores",
                                        description: "AI-generated form analysis and improvement suggestions"
                                    )
                                    
                                    DataTypeItem(
                                        icon: "clock.fill",
                                        title: "Workout Duration",
                                        description: "Time spent exercising and rest periods"
                                    )
                                    
                                    DataTypeItem(
                                        icon: "repeat.circle.fill",
                                        title: "Rep Counts",
                                        description: "Number of repetitions performed and success rates"
                                    )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.surface.opacity(0.5))
                            )
                        }
                        
                        // Privacy Notice
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Privacy & Security")
                                .font(.headline)
                                .foregroundColor(AppTheme.text)
                            
                            Text("• All data is anonymized and cannot be traced back to you\n• No personal information is collected or shared\n• Data is encrypted and stored securely\n• You can opt out at any time")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.surface)
                        )
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Data Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        profileManager.saveProfile()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct DataTypeItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.primary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.text)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - Fitness Goals View
struct FitnessGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: ProfileManager
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "target")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.primary)
                            
                            Text("Fitness Goals")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.text)
                            
                            Text("Select your primary fitness goal to personalize your workout experience")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // Goals Selection
                        VStack(spacing: 12) {
                            ForEach(FitnessGoal.allCases, id: \.self) { goal in
                                GoalSelectionCard(
                                    goal: goal,
                                    isSelected: profileManager.profile.primaryGoal == goal,
                                    action: {
                                        profileManager.profile.primaryGoal = goal
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Fitness Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        profileManager.saveProfile()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct GoalSelectionCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: goal.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : AppTheme.primary)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : AppTheme.text)
                    
                    Text(goalDescription(for: goal))
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppTheme.primary : AppTheme.surface)
                    .shadow(color: Color.black.opacity(0.1), radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 4 : 1)
            )
        }
    }
    
    private func goalDescription(for goal: FitnessGoal) -> String {
        switch goal {
        case .strength:
            return "Build maximum strength and power"
        case .muscle:
            return "Increase muscle size and mass"
        case .endurance:
            return "Improve cardiovascular fitness"
        case .weightLoss:
            return "Burn calories and lose weight"
        case .general:
            return "Overall health and wellness"
        }
    }
}

// MARK: - Experience Level View
struct ExperienceLevelView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: ProfileManager
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.primary)
                            
                            Text("Experience Level")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.text)
                            
                            Text("Select your experience level to customize workout recommendations")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // Experience Levels
                        VStack(spacing: 12) {
                            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                                ExperienceSelectionCard(
                                    level: level,
                                    isSelected: profileManager.profile.experience == level,
                                    action: {
                                        profileManager.profile.experience = level
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Experience Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        profileManager.saveProfile()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ExperienceSelectionCard: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Experience Level Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? .white : AppTheme.primary.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(experienceIcon(for: level))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isSelected ? AppTheme.primary : AppTheme.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : AppTheme.text)
                    
                    Text(level.description)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppTheme.primary : AppTheme.surface)
                    .shadow(color: Color.black.opacity(0.1), radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 4 : 1)
            )
        }
    }
    
    private func experienceIcon(for level: ExperienceLevel) -> String {
        switch level {
        case .beginner: return "1"
        case .intermediate: return "2"
        case .advanced: return "3"
        }
    }
}

// MARK: - Custom Form Components
struct ProfileFormSection<Content: View>: View {
    let icon: String
    let title: String
    let content: Content
    
    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.text)
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct ProfileFormField: View {
    let title: String
    let unit: String
    @Binding var value: Double
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.textSecondary)
            
            HStack {
                TextField(placeholder, value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.text)
                
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.textSecondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

struct UnitToggleableField: View {
    let title: String
    @Binding var unitSystem: UnitSystem
    @Binding var storedValue: Double // Always stored in metric (cm/kg)
    let placeholder: String
    
    @State private var inputText: String = ""
    
    private var isHeight: Bool {
        title.lowercased().contains("height")
    }
    
    private var formattedDisplay: String {
        if isHeight {
            return unitSystem.formatHeight(storedValue)
        } else {
            return unitSystem.formatWeight(storedValue)
        }
    }
    
    private var currentUnit: String {
        if isHeight {
            return unitSystem.heightUnit
        } else {
            return unitSystem.weightUnit
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.textSecondary)
            
            HStack {
                TextField(placeholder, text: $inputText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.text)
                    .onAppear {
                        updateInputFromStored()
                    }
                    .onChange(of: storedValue) {
                        updateInputFromStored()
                    }
                    .onChange(of: unitSystem) {
                        updateInputFromStored()
                    }
                    .onSubmit {
                        parseInputAndUpdateStored()
                    }
                    .onChange(of: inputText) {
                        // Auto-parse as user types
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if inputText != formattedDisplay {
                                parseInputAndUpdateStored()
                            }
                        }
                    }
                
                // Clickable unit label
                Button(action: {
                    toggleUnitSystem()
                }) {
                    Text(currentUnit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.primary)
                        .underline()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.textSecondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    private func updateInputFromStored() {
        inputText = formattedDisplay
    }
    
    private func toggleUnitSystem() {
        // Convert current stored value to new unit system
        if isHeight {
            // For height: convert stored cm to new display format
            unitSystem = unitSystem == .metric ? .imperial : .metric
            inputText = unitSystem.formatHeight(storedValue)
        } else {
            // For weight: convert stored kg to new display format
            unitSystem = unitSystem == .metric ? .imperial : .metric
            inputText = unitSystem.formatWeight(storedValue)
        }
    }
    
    private func parseInputAndUpdateStored() {
        if isHeight {
            parseHeightInput()
        } else {
            parseWeightInput()
        }
    }
    
    private func parseHeightInput() {
        if unitSystem == .metric {
            // Expecting format like "170 cm" or just "170"
            let numberString = inputText.replacingOccurrences(of: " cm", with: "")
            if let value = Double(numberString) {
                storedValue = value
            }
        } else {
            // Expecting format like "5'8\"" or "5 8" or "68"
            let cleanInput = inputText.replacingOccurrences(of: "\"", with: "")
            if cleanInput.contains("'") {
                // Format: 5'8
                let parts = cleanInput.components(separatedBy: "'")
                if parts.count == 2,
                   let feet = Double(parts[0]),
                   let inches = Double(parts[1]) {
                    let totalInches = feet * 12 + inches
                    storedValue = totalInches * 2.54 // inches to cm
                }
            } else if cleanInput.contains(" ") {
                // Format: 5 8
                let parts = cleanInput.components(separatedBy: " ")
                if parts.count == 2,
                   let feet = Double(parts[0]),
                   let inches = Double(parts[1]) {
                    let totalInches = feet * 12 + inches
                    storedValue = totalInches * 2.54 // inches to cm
                }
            } else {
                // Format: 68 (total inches)
                if let totalInches = Double(cleanInput) {
                    storedValue = totalInches * 2.54 // inches to cm
                }
            }
        }
    }
    
    private func parseWeightInput() {
        if unitSystem == .metric {
            // Expecting format like "70 kg" or just "70"
            let numberString = inputText.replacingOccurrences(of: " kg", with: "")
            if let value = Double(numberString) {
                storedValue = value
            }
        } else {
            // Expecting format like "154 lbs" or just "154"
            let numberString = inputText.replacingOccurrences(of: " lbs", with: "")
            if let value = Double(numberString) {
                storedValue = value / 2.20462 // lbs to kg
            }
        }
    }
}

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AppTheme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.textSecondary.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Notification Manager

#Preview {
    ProfileView()
}
