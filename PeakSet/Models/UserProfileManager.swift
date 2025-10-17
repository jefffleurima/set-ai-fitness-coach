import Foundation

// MARK: - Comprehensive User Profile
struct ComprehensiveUserProfile: Codable {
    var personalInfo: PersonalInfo
    var fitnessProfile: FitnessProfile
    var nutritionProfile: NutritionProfile
    var preferences: UserPreferences
    var goals: UserGoals
    var progress: UserProgress
    var lastUpdated: Date
    
    init() {
        self.personalInfo = PersonalInfo()
        self.fitnessProfile = FitnessProfile()
        self.nutritionProfile = NutritionProfile()
        self.preferences = UserPreferences()
        self.goals = UserGoals()
        self.progress = UserProgress()
        self.lastUpdated = Date()
    }
}

// MARK: - Personal Information
struct PersonalInfo: Codable {
    var name: String = ""
    var age: Int = 25
    var height: Double = 170.0 // cm
    var weight: Double = 70.0 // kg
    var gender: Gender = .preferNotToSay
    var timezone: String = TimeZone.current.identifier
    var joinDate: Date = Date()
    
    enum Gender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"
        case nonBinary = "non_binary"
        case preferNotToSay = "prefer_not_to_say"
    }
    
    var bmi: Double {
        guard height > 0 else { return 0 }
        return weight / ((height / 100) * (height / 100))
    }
    
    var bmiCategory: String {
        switch bmi {
        case 0..<18.5:
            return "underweight"
        case 18.5..<25:
            return "normal"
        case 25..<30:
            return "overweight"
        default:
            return "obese"
        }
    }
}

// MARK: - Fitness Profile
struct FitnessProfile: Codable {
    var fitnessLevel: FitnessLevel = .beginner
    var experience: Experience = .beginner
    var workoutFrequency: WorkoutFrequency = .moderate
    var primaryGoal: PrimaryGoal = .generalFitness
    var secondaryGoals: [SecondaryGoal] = []
    var preferredWorkoutTypes: [WorkoutType] = []
    var injuries: [Injury] = []
    var equipment: [Equipment] = []
    var availableTime: Int = 45 // minutes per session
    
    enum FitnessLevel: String, Codable, CaseIterable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
        case elite = "elite"
    }
    
    enum Experience: String, Codable, CaseIterable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
    }
    
    enum WorkoutFrequency: String, Codable, CaseIterable {
        case light = "light" // 1-2 times per week
        case moderate = "moderate" // 3-4 times per week
        case intense = "intense" // 5-6 times per week
        case elite = "elite" // 7+ times per week
    }
    
    enum PrimaryGoal: String, Codable, CaseIterable {
        case weightLoss = "weight_loss"
        case muscleGain = "muscle_gain"
        case strength = "strength"
        case endurance = "endurance"
        case flexibility = "flexibility"
        case generalFitness = "general_fitness"
        case sportsPerformance = "sports_performance"
        case rehabilitation = "rehabilitation"
    }
    
    enum SecondaryGoal: String, Codable, CaseIterable {
        case coreStrength = "core_strength"
        case balance = "balance"
        case coordination = "coordination"
        case speed = "speed"
        case power = "power"
        case mobility = "mobility"
    }
    
    enum WorkoutType: String, Codable, CaseIterable {
        case strengthTraining = "strength_training"
        case cardio = "cardio"
        case hiit = "hiit"
        case yoga = "yoga"
        case pilates = "pilates"
        case running = "running"
        case cycling = "cycling"
        case swimming = "swimming"
        case martialArts = "martial_arts"
        case sports = "sports"
    }
    
    enum Equipment: String, Codable, CaseIterable {
        case bodyweight = "bodyweight"
        case dumbbells = "dumbbells"
        case barbell = "barbell"
        case kettlebells = "kettlebells"
        case resistanceBands = "resistance_bands"
        case gymAccess = "gym_access"
        case homeGym = "home_gym"
        case cardioEquipment = "cardio_equipment"
    }
}

// MARK: - Injury Information
struct Injury: Codable {
    var bodyPart: String
    var severity: Severity
    var dateOccurred: Date
    var isRecovered: Bool
    var notes: String
    
    enum Severity: String, Codable {
        case minor = "minor"
        case moderate = "moderate"
        case severe = "severe"
        case chronic = "chronic"
    }
}

// MARK: - Nutrition Profile
struct NutritionProfile: Codable {
    var dietaryRestrictions: [DietaryRestriction] = []
    var allergies: [Allergy] = []
    var preferences: [FoodPreference] = []
    var supplements: [Supplement] = []
    var mealFrequency: MealFrequency = .threeMeals
    var cookingSkill: CookingSkill = .intermediate
    var budget: Budget = .moderate
    
    enum DietaryRestriction: String, Codable, CaseIterable {
        case vegan = "vegan"
        case vegetarian = "vegetarian"
        case pescatarian = "pescatarian"
        case glutenFree = "gluten_free"
        case dairyFree = "dairy_free"
        case nutFree = "nut_free"
        case lowCarb = "low_carb"
        case ketogenic = "ketogenic"
        case paleo = "paleo"
        case mediterranean = "mediterranean"
        case lowFODMAP = "low_fodmap"
    }
    
    enum Allergy: String, Codable, CaseIterable {
        case nuts = "nuts"
        case dairy = "dairy"
        case gluten = "gluten"
        case shellfish = "shellfish"
        case eggs = "eggs"
        case soy = "soy"
        case sesame = "sesame"
    }
    
    enum FoodPreference: String, Codable, CaseIterable {
        case spicy = "spicy"
        case mild = "mild"
        case organic = "organic"
        case local = "local"
        case quickMeals = "quick_meals"
        case mealPrep = "meal_prep"
    }
    
    enum MealFrequency: String, Codable, CaseIterable {
        case twoMeals = "two_meals"
        case threeMeals = "three_meals"
        case fourMeals = "four_meals"
        case fiveMeals = "five_meals"
        case intermittentFasting = "intermittent_fasting"
    }
    
    enum CookingSkill: String, Codable, CaseIterable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
        case expert = "expert"
    }
    
    enum Budget: String, Codable, CaseIterable {
        case tight = "tight"
        case moderate = "moderate"
        case generous = "generous"
        case premium = "premium"
    }
}

// MARK: - Supplement Information
struct Supplement: Codable {
    var name: String
    var type: SupplementType
    var dosage: String
    var frequency: String
    var purpose: String
    var isActive: Bool
    
    enum SupplementType: String, Codable, CaseIterable {
        case protein = "protein"
        case creatine = "creatine"
        case multivitamin = "multivitamin"
        case omega3 = "omega_3"
        case vitaminD = "vitamin_d"
        case bcaa = "bcaa"
        case preWorkout = "pre_workout"
        case postWorkout = "post_workout"
        case sleep = "sleep"
        case digestive = "digestive"
    }
}

// MARK: - User Goals
struct UserGoals: Codable {
    var shortTermGoals: [Goal] = []
    var longTermGoals: [Goal] = []
    var currentFocus: String = ""
    var targetWeight: Double?
    var targetBodyFat: Double?
    var targetMuscleMass: Double?
    var targetDate: Date?
    
    struct Goal: Codable {
        var id: UUID = UUID()
        var title: String
        var description: String
        var targetDate: Date
        var isCompleted: Bool = false
        var progress: Double = 0.0 // 0.0 to 1.0
        var category: GoalCategory
        
        enum GoalCategory: String, Codable, CaseIterable {
            case fitness = "fitness"
            case nutrition = "nutrition"
            case wellness = "wellness"
            case lifestyle = "lifestyle"
            case performance = "performance"
        }
    }
}

// MARK: - User Progress
struct UserProgress: Codable {
    var workoutStreak: Int = 0
    var longestStreak: Int = 0
    var totalWorkouts: Int = 0
    var totalCaloriesBurned: Int = 0
    var totalSteps: Int = 0
    var averageFormScore: Double = 0.0
    var improvementAreas: [String] = []
    var achievements: [Achievement] = []
    var weeklyProgress: [WeeklyProgress] = []
    
    struct Achievement: Codable {
        var id: UUID = UUID()
        var title: String
        var description: String
        var dateEarned: Date
        var category: AchievementCategory
        
        enum AchievementCategory: String, Codable {
            case consistency = "consistency"
            case improvement = "improvement"
            case milestone = "milestone"
            case challenge = "challenge"
        }
    }
    
    struct WeeklyProgress: Codable {
        var weekStart: Date
        var workoutsCompleted: Int
        var totalCalories: Int
        var averageFormScore: Double
        var notes: String
    }
}

// MARK: - User Profile Manager
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var profile: ComprehensiveUserProfile
    private let userDefaults = UserDefaults.standard
    private let profileKey = "ComprehensiveUserProfile"
    
    private init() {
        self.profile = Self.loadProfile()
        print("👤 UserProfileManager: Loaded profile for \(profile.personalInfo.name.isEmpty ? "New User" : profile.personalInfo.name)")
    }
    
    // MARK: - Profile Management
    
    func saveProfile() {
        profile.lastUpdated = Date()
        
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: profileKey)
            print("💾 UserProfileManager: Profile saved successfully")
        } catch {
            print("❌ UserProfileManager: Failed to save profile: \(error)")
        }
    }
    
    private static func loadProfile() -> ComprehensiveUserProfile {
        guard let data = UserDefaults.standard.data(forKey: "ComprehensiveUserProfile") else {
            print("👤 UserProfileManager: No saved profile found, creating new profile")
            return ComprehensiveUserProfile()
        }
        
        do {
            let profile = try JSONDecoder().decode(ComprehensiveUserProfile.self, from: data)
            print("👤 UserProfileManager: Loaded existing profile")
            return profile
        } catch {
            print("❌ UserProfileManager: Failed to load profile, creating new: \(error)")
            return ComprehensiveUserProfile()
        }
    }
    
    // MARK: - Profile Updates
    
    func updatePersonalInfo(_ personalInfo: PersonalInfo) {
        profile.personalInfo = personalInfo
        saveProfile()
        print("👤 UserProfileManager: Personal info updated")
    }
    
    func updateUserName(_ name: String) {
        profile.personalInfo.name = name
        saveProfile()
        print("👤 UserProfileManager: User name updated to '\(name)'")
    }
    
    func updateFitnessProfile(_ fitnessProfile: FitnessProfile) {
        profile.fitnessProfile = fitnessProfile
        saveProfile()
        print("👤 UserProfileManager: Fitness profile updated")
    }
    
    func updateNutritionProfile(_ nutritionProfile: NutritionProfile) {
        profile.nutritionProfile = nutritionProfile
        saveProfile()
        print("👤 UserProfileManager: Nutrition profile updated")
    }
    
    func addGoal(_ goal: UserGoals.Goal) {
        if goal.targetDate.timeIntervalSinceNow > 0 {
            profile.goals.shortTermGoals.append(goal)
        } else {
            profile.goals.longTermGoals.append(goal)
        }
        saveProfile()
        print("🎯 UserProfileManager: Goal added: \(goal.title)")
    }
    
    func updateGoalProgress(goalId: UUID, progress: Double) {
        if let index = profile.goals.shortTermGoals.firstIndex(where: { $0.id == goalId }) {
            profile.goals.shortTermGoals[index].progress = progress
            if progress >= 1.0 {
                profile.goals.shortTermGoals[index].isCompleted = true
            }
        } else if let index = profile.goals.longTermGoals.firstIndex(where: { $0.id == goalId }) {
            profile.goals.longTermGoals[index].progress = progress
            if progress >= 1.0 {
                profile.goals.longTermGoals[index].isCompleted = true
            }
        }
        saveProfile()
        print("🎯 UserProfileManager: Goal progress updated")
    }
    
    func addAchievement(_ achievement: UserProgress.Achievement) {
        profile.progress.achievements.append(achievement)
        saveProfile()
        print("🏆 UserProfileManager: Achievement added: \(achievement.title)")
    }
    
    func updateWorkoutStreak(_ newStreak: Int) {
        profile.progress.workoutStreak = newStreak
        if newStreak > profile.progress.longestStreak {
            profile.progress.longestStreak = newStreak
        }
        saveProfile()
        print("🔥 UserProfileManager: Workout streak updated to \(newStreak)")
    }
    
    // MARK: - Analytics
    
    func getProfileSummary() -> String {
        var summary = "User Profile Summary:\n"
        
        // Personal Info
        if !profile.personalInfo.name.isEmpty {
            summary += "Name: \(profile.personalInfo.name)\n"
        }
        summary += "Age: \(profile.personalInfo.age)\n"
        summary += "Height: \(Int(profile.personalInfo.height))cm\n"
        summary += "Weight: \(Int(profile.personalInfo.weight))kg\n"
        summary += "BMI: \(String(format: "%.1f", profile.personalInfo.bmi)) (\(profile.personalInfo.bmiCategory))\n\n"
        
        // Fitness Profile
        summary += "Fitness Level: \(profile.fitnessProfile.fitnessLevel.rawValue)\n"
        summary += "Primary Goal: \(profile.fitnessProfile.primaryGoal.rawValue)\n"
        summary += "Workout Frequency: \(profile.fitnessProfile.workoutFrequency.rawValue)\n"
        summary += "Available Time: \(profile.fitnessProfile.availableTime) minutes\n\n"
        
        // Progress
        summary += "Workout Streak: \(profile.progress.workoutStreak) days\n"
        summary += "Total Workouts: \(profile.progress.totalWorkouts)\n"
        summary += "Average Form Score: \(String(format: "%.1f", profile.progress.averageFormScore))%\n\n"
        
        // Goals
        if !profile.goals.shortTermGoals.isEmpty {
            summary += "Short-term Goals:\n"
            for goal in profile.goals.shortTermGoals.prefix(3) {
                summary += "- \(goal.title) (\(Int(goal.progress * 100))% complete)\n"
            }
        }
        
        return summary
    }
    
    func getPersonalizedGreeting() -> String {
        let name = profile.personalInfo.name.isEmpty ? "there" : profile.personalInfo.name
        let timeOfDay = getTimeOfDayGreeting()
        
        var greeting = "\(timeOfDay), \(name)! "
        
        // Add personalized context
        if profile.progress.workoutStreak > 0 {
            greeting += "Great job on your \(profile.progress.workoutStreak)-day streak! "
        }
        
        if let lastGoal = profile.goals.shortTermGoals.first(where: { !$0.isCompleted }) {
            greeting += "How's your progress on \(lastGoal.title)? "
        }
        
        greeting += "What can I help you with today?"
        
        return greeting
    }
    
    private func getTimeOfDayGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good evening"
        }
    }
    
}
