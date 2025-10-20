import Foundation

// MARK: - Coaching Context

struct CoachingContext {
    let formIssue: FormIssue?
    let severity: Double  // 0.0 (perfect) to 1.0 (critical)
    let repNumber: Int
    let consecutiveGoodReps: Int
    let phase: FormAnalyzer.ExercisePhase  // Use FormAnalyzer's enum to avoid duplication
    let exerciseName: String
    let previousCues: [String]  // Recently used cues
    let userFatigueLevel: Double  // 0.0 (fresh) to 1.0 (exhausted)
}

enum FormIssue: String {
    case kneeValgus = "knee_valgus"
    case kneeAlignment = "knee_alignment"
    case depth = "depth"
    case backAlignment = "back_alignment"
    case spinalFlexion = "spinal_flexion"
    case stability = "stability"
    case speed = "speed"
    case hipPosition = "hip_position"
    case shoulderPosition = "shoulder_position"
    case ankleStability = "ankle_stability"
}

// Note: ExercisePhase is defined in FormAnalyzer.swift to avoid duplication

// MARK: - Contextual Template Coach

class WorkoutCoachingTemplates {
    static let shared = WorkoutCoachingTemplates()
    
    private var recentlyUsedCues: [String] = []
    private let maxRecentCues = 10
    
    // MARK: - Conversational Responses (for user questions during workout)
    
    /// Get response to user questions/comments during workout
    func getConversationalResponse(userInput: String, context: CoachingContext) -> String? {
        let input = userInput.lowercased()
        
        // Progress check questions
        if input.contains("how am i doing") || input.contains("how's my form") || input.contains("am i doing good") {
            return getProgressCheckResponse(context: context)
        }
        
        // Form validation questions
        if input.contains("is this right") || input.contains("am i doing this right") || input.contains("correct") {
            return getFormValidationResponse(context: context)
        }
        
        // Fatigue/tiredness
        if input.contains("tired") || input.contains("exhausted") || input.contains("can't") {
            return getFatigueResponse(context: context)
        }
        
        // Pain/discomfort
        if input.contains("hurts") || input.contains("pain") || input.contains("sore") {
            return getPainResponse(context: context)
        }
        
        // Encouragement requests
        if input.contains("motivate") || input.contains("encourage") || input.contains("keep going") {
            return getMotivationResponse(context: context)
        }
        
        // Rep count questions
        if input.contains("how many") || input.contains("rep count") || input.contains("what rep") {
            return "You're on rep \(context.repNumber). Keep that form tight!"
        }
        
        // Break/rest requests
        if input.contains("break") || input.contains("rest") || input.contains("pause") {
            return "Take your time! Rest when you need it. I'll be here when you're ready to continue."
        }
        
        return nil  // No match - let AI handle it
    }
    
    private func getProgressCheckResponse(context: CoachingContext) -> String {
        if context.consecutiveGoodReps >= 3 {
            return "You're crushing it! Form is looking solid. Keep this energy going!"
        } else if context.severity < 0.3 {
            return "Looking good! Your form is on point. Just maintain that technique."
        } else if context.severity < 0.6 {
            return "You're doing alright, but I'm seeing some form issues. Focus on \(context.formIssue?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "your technique")."
        } else {
            return "Let's work on your form. I'm noticing \(context.formIssue?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "some issues"). Take it slow and focus on technique over speed."
        }
    }
    
    private func getFormValidationResponse(context: CoachingContext) -> String {
        if context.severity < 0.3 {
            return "Yes! That's exactly right. Your form is looking great. Keep it up!"
        } else if context.severity < 0.6 {
            return "You're on the right track, but let's dial in your \(context.formIssue?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "form") a bit more."
        } else {
            return "Not quite. Let's fix your \(context.formIssue?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "technique"). Focus on proper form first, then we'll add reps."
        }
    }
    
    private func getFatigueResponse(context: CoachingContext) -> String {
        if context.repNumber < 5 {
            return "I hear you. Take a breath, reset your form, and let's do a few more quality reps."
        } else if context.repNumber < 10 {
            return "You're doing great! Fatigue is normal. Take a quick break if you need it, then finish strong."
        } else {
            return "That's a solid set! You've earned a rest. Take your time, hydrate, and we'll go again when you're ready."
        }
    }
    
    private func getPainResponse(context: CoachingContext) -> String {
        return "Hold up. If something hurts, stop immediately. Pain is your body's warning signal. Let's check your form or take a break. Your safety comes first."
    }
    
    private func getMotivationResponse(context: CoachingContext) -> String {
        let motivationalPhrases = [
            "You've got this! Every rep is making you stronger!",
            "Let's go! Show me that power! You're built for this!",
            "Beast mode activated! Keep that intensity up!",
            "This is your moment! Push through, you're stronger than you think!",
            "Feeling it? That's growth happening! Let's get it!"
        ]
        return motivationalPhrases.randomElement() ?? "You've got this! Keep pushing!"
    }
    
    // MARK: - Exercise Setup Instructions (for greeting)
    
    /// Get personalized greeting with exercise-specific instructions
    /// Called after user is detected as stable and ready to start
    func getExerciseSetupInstructions(exercise: String, userName: String?) -> String {
        // Get user name with fallback strategy
        let displayName = getUserNameForGreeting(providedName: userName)
        let greeting = displayName.map { "Hey \($0)!" } ?? "Hey!"
        let instructions = getExerciseTips(exercise: exercise)
        
        // If exercise has detailed instructions (squats, deadlifts), give full briefing
        if !instructions.isEmpty {
            return "\(greeting) Before we start, here's what I want you to do and what I'm looking for. \(instructions) Alright, let's get started!"
        } else {
            // For other exercises, just greet and start
            return "\(greeting) Get ready - start when you're ready!"
        }
    }
    
    /// Get user name with fallback strategy for greetings
    /// Returns nil if no name is available (so we just say "Hey!" instead of "Hey there!")
    private func getUserNameForGreeting(providedName: String?) -> String? {
        // Priority 1: Use provided name if available
        if let name = providedName, !name.isEmpty, name != "there" {
            return name
        }
        
        // Priority 2: Check UserDefaults for saved name (from conversation extraction)
        if let savedName = UserDefaults.standard.string(forKey: "userName"), !savedName.isEmpty {
            return savedName
        }
        
        // Priority 3: Check UserProfileManager for name
        let profileName = UserProfileManager.shared.profile.personalInfo.name
        if !profileName.isEmpty {
            return profileName
        }
        
        // No name available - return nil to use generic greeting
        return nil
    }
    
    /// Get detailed form instructions for each exercise type
    /// Based on Starting Strength, NSCA, and ACE certified methodologies
    private func getExerciseTips(exercise: String) -> String {
        switch exercise.lowercased() {
        case "squats", "squat":
            return """
            To start, you want to make sure you stand with your feet shoulder-width apart, toes slightly pointed out. \
            Take a big breath and brace your core like someone's about to punch you in the stomach. Keep your chest up and eyes forward. \
            Lower down by pushing your hips back first, then bending your knees. Think of sitting back into a chair. \
            Keep your weight on your heels and mid-foot, never on your toes. Your knees should track over your toes, not caving in. \
            Go down until your hip crease is below your knee, then drive through your heels to stand back up. \
            Think about spreading the floor apart with your feet on the way up. \
            I'll be watching for proper depth, knee alignment, back angle, and keeping your chest up throughout the movement.
            """
            
        case "deadlifts", "deadlift":
            return """
            Stand with your feet hip-width apart, barbell over your mid-foot. The bar should be about an inch from your shins. \
            Bend at your hips first, then bend your knees to grip the bar just outside your legs. \
            Before you pull, make sure your back is flat, not rounded. Your chest should be up and shoulders should be over or slightly in front of the bar. \
            Take a big breath, brace your core, and pull the slack out of the bar. \
            Drive through your heels and think about pushing the floor away with your legs, not pulling with your back. \
            Keep the bar close to your body, dragging it up your shins and thighs. Your hips and shoulders should rise together. \
            At the top, stand tall and squeeze your glutes, but don't hyperextend your back. \
            Lower with control by pushing your hips back first, then bending your knees. \
            I'll be watching your back position, hip hinge pattern, bar path, and lockout position.
            """
            
        default:
            // For other exercises, no detailed pre-instructions, just start
            return ""
        }
    }
    
    // MARK: - Professional Coaching Cue Libraries
    // Based on Starting Strength, NSCA Guidelines, and ACE Standards
    
    /// Comprehensive squat coaching cues organized by phase and issue
    private let squatCoachingLibrary: [String: [String: [String]]] = [
        "setup": [
            "stance": [
                "Feet shoulder-width apart",
                "Point your toes out slightly, about 30 degrees",
                "Find a stable stance, you should feel balanced",
                "Imagine screwing your feet into the ground"
            ],
            "breathing": [
                "Take a big breath into your belly",
                "Brace your core tight",
                "Hold that breath for the rep",
                "Core tight like you're about to get punched"
            ],
            "posture": [
                "Chest up, eyes forward",
                "Shoulders back and down",
                "Neutral spine, no rounding",
                "Think proud chest throughout"
            ]
        ],
        "descent": [
            "hip_initiation": [
                "Hips back first",
                "Think sitting back into a chair",
                "Push your butt back",
                "Hip hinge first, then knees bend"
            ],
            "knee_tracking": [
                "Knees track over your toes",
                "Push your knees out to the sides",
                "Think knees out, not in",
                "Spread the floor with your feet"
            ],
            "depth": [
                "Go down until hip crease breaks parallel to knee",
                "Full depth, no half reps",
                "Get that depth",
                "Below parallel"
            ],
            "balance": [
                "Weight on your heels and mid-foot",
                "Keep your heels planted",
                "Don't let your heels come up",
                "Press through your whole foot"
            ],
            "speed": [
                "Control the descent",
                "Don't drop too fast",
                "Smooth and controlled",
                "Take your time going down"
            ]
        ],
        "bottom": [
            "position": [
                "Stay tight in the hole",
                "Keep your chest up at the bottom",
                "Don't collapse at the bottom",
                "Maintain tension"
            ],
            "rebound": [
                "Bounce out of the bottom",
                "Use the stretch reflex",
                "Powerful reversal",
                "Don't pause too long"
            ]
        ],
        "ascent": [
            "drive": [
                "Drive through your heels",
                "Push the floor away",
                "Hips and chest rise together",
                "Explode up"
            ],
            "knee_position": [
                "Keep those knees out",
                "Push knees to the sides",
                "Don't let knees cave in",
                "Knees stay wide"
            ],
            "finish": [
                "Stand all the way up",
                "Full lockout",
                "Squeeze your glutes at the top",
                "Complete the rep"
            ]
        ]
    ]
    
    /// Comprehensive deadlift coaching cues
    private let deadliftCoachingLibrary: [String: [String: [String]]] = [
        "setup": [
            "bar_position": [
                "Bar over mid-foot",
                "Bar should be about an inch from your shins",
                "Bar directly over the middle of your foot",
                "Don't start with bar too far forward"
            ],
            "stance": [
                "Feet hip-width apart",
                "Toes pointed forward or slightly out",
                "Find your pulling stance",
                "Narrow stance for conventional"
            ],
            "grip": [
                "Grip just outside your legs",
                "Hands shoulder-width apart",
                "Double overhand or mixed grip",
                "Grip tight, squeeze the bar"
            ],
            "back_position": [
                "Flat back, no rounding",
                "Chest up before you pull",
                "Shoulders over or slightly in front of bar",
                "Neutral spine, look down slightly"
            ],
            "breathing": [
                "Big breath into your belly",
                "Brace your core hard",
                "Hold your breath for the rep",
                "Create intra-abdominal pressure"
            ]
        ],
        "pull": [
            "initiation": [
                "Pull the slack out of the bar first",
                "Create tension before you pull",
                "Feel the weight in your hands",
                "Tight body before moving"
            ],
            "leg_drive": [
                "Push the floor away with your legs",
                "Think leg press, not back pull",
                "Legs drive first",
                "Use your legs to break the floor"
            ],
            "bar_path": [
                "Keep bar close to your body",
                "Drag it up your shins",
                "Bar should touch your legs",
                "Straight vertical path"
            ],
            "hip_shoulder_sync": [
                "Hips and shoulders rise together",
                "Don't let hips shoot up first",
                "Maintain your back angle",
                "Stay over the bar"
            ]
        ],
        "lockout": [
            "finish": [
                "Stand tall at the top",
                "Squeeze your glutes",
                "Shoulders back",
                "Full hip extension"
            ],
            "avoid": [
                "Don't hyperextend your back",
                "Don't lean back too far",
                "Just stand straight",
                "Neutral position at top"
            ]
        ],
        "descent": [
            "control": [
                "Control the weight down",
                "Hips back first on the way down",
                "Keep bar close",
                "Don't just drop it"
            ],
            "reset": [
                "Reset your position at the bottom",
                "Full stop between reps",
                "Re-grip if needed",
                "Each rep starts from the floor"
            ]
        ]
    ]
    
    /// Safety-critical coaching cues (immediate intervention)
    /// Based on injury prevention research and professional standards
    private let safetyCueLibrary: [FormIssue: [String]] = [
        .kneeValgus: [
            "STOP! Knees out to protect them!",
            "Knees are caving - push them out now!",
            "Critical: Drive knees out to avoid injury!",
            "Knees out! This is important for joint safety!"
        ],
        .spinalFlexion: [
            "STOP! Keep your back flat!",
            "Back is rounding - straighten it now!",
            "Critical: Neutral spine to protect your back!",
            "Flat back! Don't round your spine!"
        ],
        .backAlignment: [
            "Watch your back position!",
            "Keep your back neutral!",
            "Straighten your back!",
            "Chest up, back flat!"
        ],
        .ankleStability: [
            "Stabilize your ankles!",
            "Keep your feet planted!",
            "Don't roll your ankles!",
            "Stay balanced on your feet!"
        ],
        .shoulderPosition: [
            "Shoulders back and tight!",
            "Keep shoulders in position!",
            "Don't let shoulders round forward!",
            "Shoulder position - stay tight!"
        ],
        .speed: [
            "Slow down for control!",
            "Too fast - control the weight!",
            "Take your time, safety first!",
            "Reduce speed, focus on form!"
        ]
    ]
    
    /// Progressive coaching sequences for beginners
    /// Teaches proper movement patterns step-by-step
    private let beginnerProgressionCues: [String: [String]] = [
        "squat_sequence": [
            "First, practice just the hip hinge - push your hips back",
            "Good! Now add the knee bend while keeping hips back",
            "Perfect! Now let's work on depth - go lower",
            "Great! Now focus on keeping those knees out",
            "Excellent! Now let's work on the drive up through your heels"
        ],
        "deadlift_sequence": [
            "First, practice finding the bar position over mid-foot",
            "Good! Now practice the hip hinge - hips back, chest up",
            "Perfect! Now grip the bar and create tension",
            "Great! Now practice the leg drive - push floor away",
            "Excellent! Now let's work on keeping the bar close to your body"
        ]
    ]
    
    /// Advanced coaching cues for experienced lifters
    /// Focuses on optimization and performance
    private let advancedCoachingCues: [String: [String]] = [
        "squat_optimization": [
            "Think about creating torque by screwing your feet into the floor",
            "Maximize stretch reflex at the bottom - don't pause too long",
            "Aggressive hip drive out of the hole",
            "Maintain thoracic extension throughout the lift",
            "Use the valsalva maneuver for maximum core stability"
        ],
        "deadlift_optimization": [
            "Think about rowing the bar into your body",
            "Maximize lat engagement - pull shoulders back and down",
            "Generate maximum tension before breaking the floor",
            "Think about pushing the floor away, not lifting the bar",
            "Maintain constant bar velocity through the lift"
        ]
    ]
    
    // MARK: - Main Coaching Method
    
    func generateCoachingCue(context: CoachingContext) -> String? {
        // Priority 1: Safety issues (immediate)
        if let formIssue = context.formIssue, context.severity > 0.7 {
            return selectSafetyCue(issue: formIssue, severity: context.severity, context: context)
        }
        
        // Priority 2: Form corrections (throttled)
        if let formIssue = context.formIssue, context.severity > 0.3 {
            return selectFormCorrectionCue(issue: formIssue, severity: context.severity, context: context)
        }
        
        // Priority 3: Encouragement (after good reps)
        if context.consecutiveGoodReps >= 3 {
            return selectEncouragementCue(context: context)
        }
        
        return nil
    }
    
    /// Get professional coaching cue from curated library (new method)
    /// Uses verified cues from Starting Strength, NSCA, and ACE methodologies
    func getProfessionalCue(exercise: String, phase: FormAnalyzer.ExercisePhase, issue: String? = nil) -> String? {
        let exerciseLower = exercise.lowercased()
        
        // Map phase to library key
        let phaseKey: String
        switch phase {
        case .rest:
            return nil // No cue during rest
        case .starting:
            phaseKey = "setup"
        case .descent:
            phaseKey = "descent"
        case .bottom:
            phaseKey = "bottom"
        case .ascent:
            phaseKey = "ascent"
        }
        
        // Select appropriate library
        let library: [String: [String: [String]]]?
        if exerciseLower.contains("squat") {
            library = squatCoachingLibrary
        } else if exerciseLower.contains("deadlift") {
            library = deadliftCoachingLibrary
        } else {
            return nil
        }
        
        guard let phaseLib = library?[phaseKey] else { return nil }
        
        // If specific issue provided, get targeted cue
        if let issue = issue, let issueCues = phaseLib[issue] {
            return issueCues.randomElement()
        }
        
        // Otherwise, get general cue for this phase
        let allCues = phaseLib.values.flatMap { $0 }
        return allCues.randomElement()
    }
    
    func generateRepCountCue(repNumber: Int, formScore: Double, context: CoachingContext) -> String {
        let templates = getRepCountTemplates(repNumber: repNumber, formScore: formScore, context: context)
        return selectUnusedTemplate(from: templates)
    }
    
    // MARK: - Template Libraries (100+ variations)
    
    // MARK: Rep Count Templates (50+ variations)
    
    private func getRepCountTemplates(repNumber: Int, formScore: Double, context: CoachingContext) -> [String] {
        var templates: [String] = []
        
        // Basic counts (1-20)
        if repNumber == 1 {
            templates += [
                "One!",
                "That's one!",
                "First rep!",
                "One down!",
                "Here we go, one!"
            ]
        } else if repNumber <= 5 {
            templates += [
                "\(repNumber)!",
                "That's \(repNumber)!",
                "\(repNumber) reps!",
                "\(repNumber) down!",
                "Nice, \(repNumber)!"
            ]
        } else if repNumber <= 10 {
            templates += [
                "\(repNumber)!",
                "That's \(repNumber)!",
                "\(repNumber), keep going!",
                "\(repNumber), strong!",
                "\(repNumber), you got this!"
            ]
        } else if repNumber <= 15 {
            templates += [
                "\(repNumber)!",
                "\(repNumber), excellent!",
                "\(repNumber), keep pushing!",
                "\(repNumber), almost there!",
                "\(repNumber), stay focused!"
            ]
        } else {
            templates += [
                "\(repNumber)!",
                "\(repNumber), beast mode!",
                "\(repNumber), incredible!",
                "\(repNumber), don't stop!",
                "\(repNumber), finish strong!"
            ]
        }
        
        // Add form quality modifiers
        if formScore >= 0.9 {
            templates += [
                "\(repNumber)! Perfect form!",
                "\(repNumber)! Textbook!",
                "\(repNumber)! Flawless!",
                "\(repNumber)! Beautiful!",
                "\(repNumber)! That's how it's done!"
            ]
        } else if formScore >= 0.7 {
            templates += [
                "\(repNumber)! Good form!",
                "\(repNumber)! Solid!",
                "\(repNumber)! Clean!",
                "\(repNumber)! Nice control!",
                "\(repNumber)! Keep that form!"
            ]
        }
        
        // Milestone celebrations
        if repNumber == 5 {
            templates += [
                "Five! Halfway!",
                "Five! Keep it up!",
                "Five down, five to go!",
                "Five! You're crushing it!"
            ]
        } else if repNumber == 10 {
            templates += [
                "Ten! Strong!",
                "Ten! Great set!",
                "Ten! You're a beast!",
                "Ten! Finish strong!",
                "Ten! Almost there!"
            ]
        } else if repNumber == 15 {
            templates += [
                "Fifteen! Incredible!",
                "Fifteen! Last few!",
                "Fifteen! Finish it!",
                "Fifteen! You got this!"
            ]
        } else if repNumber == 20 {
            templates += [
                "Twenty! Amazing!",
                "Twenty! That's a set!",
                "Twenty! Unbelievable!",
                "Twenty! You crushed it!"
            ]
        }
        
        // Fatigue-aware cues
        if context.userFatigueLevel > 0.7 && repNumber > 8 {
            templates += [
                "\(repNumber)! Stay focused!",
                "\(repNumber)! Don't give up!",
                "\(repNumber)! Push through!",
                "\(repNumber)! You can do this!"
            ]
        }
        
        return templates
    }
    
    // MARK: Knee Valgus Templates (30+ variations)
    
    private func getKneeValgusTemplates(severity: Double, phase: FormAnalyzer.ExercisePhase) -> [String] {
        var templates: [String] = []
        
        if severity > 0.8 {
            // Severe - urgent but supportive WITH instructions
            templates += [
                "Hey, push those knees out wide!",
                "Let's drive those knees apart!",
                "Push knees out to the sides!",
                "Knees need to track wider!",
                "Drive knees outward!",
                "Spread those knees apart!",
                "Push knees out - protect them!",
                "Think knees out, not in!"
            ]
        } else if severity > 0.5 {
            // Moderate - firm but smooth correction
            templates += [
                "Push knees out - track over toes!",
                "Knees wider! Track over toes!",
                "Drive knees apart as you squat!",
                "Spread knees - keep them out!",
                "Knees to the sides!",
                "Push knees apart!",
                "Think knees out!",
                "Knees track over your toes!",
                "Spread the floor with your feet!",
                "Push knees outward!"
            ]
        } else {
            // Mild - gentle reminder
            templates += [
                "Knees slightly wider",
                "Track knees over toes",
                "Keep knees out",
                "Push knees out a bit",
                "Maintain knee position",
                "Knees in line with toes",
                "Keep knees stable",
                "Nice - just watch knee tracking"
            ]
        }
        
        // Phase-specific additions
        if phase == .descent {
            templates += [
                "Knees out as you go down!",
                "Push knees out on the way down!",
                "Track knees during descent!"
            ]
        } else if phase == .bottom {
            templates += [
                "Knees out at the bottom!",
                "Push knees out in the hole!",
                "Keep knees wide down here!"
            ]
        } else if phase == .ascent {
            templates += [
                "Drive knees out as you rise!",
                "Keep knees out coming up!",
                "Push knees out on the way up!"
            ]
        }
        
        return templates
    }
    
    // MARK: Depth Templates (25+ variations)
    
    private func getDepthTemplates(severity: Double, phase: FormAnalyzer.ExercisePhase) -> [String] {
        var templates: [String] = []
        
        if phase == .descent {
            templates += [
                "Lower! Hips to knee level!",
                "Go deeper! Aim for 90 degrees!",
                "Keep going down! Not there yet!",
                "More depth! Drop those hips!",
                "Don't stop! Lower your hips!",
                "Deeper! Hips need to drop more!",
                "All the way down! Full depth!",
                "Lower! Sit back into it!",
                "Get lower! Hips down!",
                "Drop it down! More depth!"
            ]
        } else if phase == .bottom {
            templates += [
                "Lower! Hips to knees!",
                "Drop lower! Need parallel!",
                "Deeper! Aim for 90 degrees!",
                "More depth! Hips down!",
                "All the way! Sit into it!",
                "Full range! Drop hips!",
                "Bottom out! Hips to knees!",
                "Sink lower! Not deep enough!",
                "Deeper! Break parallel!",
                "Full depth! Drop those hips!"
            ]
        }
        
        // Severity-based WITH instructions
        if severity > 0.6 {
            templates += [
                "Way deeper! Hips to knee level!",
                "Much lower! Aim for parallel!",
                "You can go lower! Drop hips!",
                "More depth! Sit back and down!",
                "Get way down! Break 90 degrees!",
                "Lower! Imagine sitting in a chair!",
                "Deeper! Hips need to drop!"
            ]
        }
        
        return templates
    }
    
    // MARK: Back Alignment Templates (25+ variations)
    
    private func getBackAlignmentTemplates(severity: Double, phase: FormAnalyzer.ExercisePhase) -> [String] {
        var templates: [String] = []
        
        if severity > 0.8 {
            // Severe - urgent but supportive
            templates += [
                "Hey, back is rounding - straighten it!",
                "Let's keep that spine neutral!",
                "Check your back position!",
                "Straighten that back out!",
                "Back needs to stay flat!",
                "Keep your spine neutral!",
                "Flatten that back!",
                "Spine position - keep it straight!"
            ]
        } else if severity > 0.5 {
            // Moderate - firm but smooth
            templates += [
                "Chest up!",
                "Keep chest up!",
                "Back straight!",
                "Straighten your back!",
                "Neutral spine!",
                "Chest proud!",
                "Shoulders back!",
                "Lift that chest!",
                "Spine neutral!",
                "Back position!"
            ]
        } else {
            // Mild - gentle reminder
            templates += [
                "Chest up a bit",
                "Watch your back",
                "Keep back straight",
                "Mind your posture",
                "Back alignment",
                "Chest position",
                "Spine check",
                "Posture check"
            ]
        }
        
        // Phase-specific
        if phase == .descent {
            templates += [
                "Chest up as you descend!",
                "Keep back straight going down!",
                "Maintain posture on the way down!"
            ]
        } else if phase == .ascent {
            templates += [
                "Chest up as you rise!",
                "Keep back straight coming up!",
                "Don't round on the way up!"
            ]
        }
        
        return templates
    }
    
    // MARK: Stability Templates (20+ variations)
    
    private func getStabilityTemplates(severity: Double, phase: FormAnalyzer.ExercisePhase) -> [String] {
        var templates: [String] = []
        
        templates += [
            "Control it!",
            "Steady!",
            "Slow down!",
            "More control!",
            "Stay stable!",
            "Balance!",
            "Control the movement!",
            "Smooth it out!",
            "Easy there!",
            "Take your time!",
            "Controlled movement!",
            "Don't rush!",
            "Steady pace!",
            "Control the descent!",
            "Control the ascent!",
            "Stay balanced!",
            "Find your balance!",
            "Stabilize!",
            "Core tight!",
            "Engage your core!"
        ]
        
        return templates
    }
    
    // MARK: Encouragement Templates (40+ variations)
    
    private func getEncouragementTemplates(context: CoachingContext) -> [String] {
        var templates: [String] = []
        
        // General encouragement
        templates += [
            "Good!",
            "Nice!",
            "Strong!",
            "Excellent!",
            "Beautiful!",
            "Perfect!",
            "Solid!",
            "Clean!",
            "Smooth!",
            "Great form!",
            "Keep it up!",
            "You got this!",
            "Looking good!",
            "That's it!",
            "Right there!",
            "Exactly!",
            "Yes!",
            "Love it!",
            "Crushing it!",
            "Beast mode!"
        ]
        
        // Fatigue-aware encouragement
        if context.userFatigueLevel > 0.7 {
            templates += [
                "Push through!",
                "Don't quit!",
                "You're stronger than you think!",
                "Dig deep!",
                "Almost there!",
                "Finish strong!",
                "You can do this!",
                "Keep pushing!",
                "Don't stop now!",
                "One more!"
            ]
        }
        
        // Rep-based encouragement
        if context.repNumber >= 10 {
            templates += [
                "Great endurance!",
                "Your stamina is impressive!",
                "Strong finish!",
                "You're on fire!",
                "Unstoppable!"
            ]
        }
        
        // Consecutive good reps
        if context.consecutiveGoodReps >= 5 {
            templates += [
                "Consistent form!",
                "Locked in!",
                "Dialed in!",
                "Perfect rhythm!",
                "You're in the zone!"
            ]
        }
        
        return templates
    }
    
    // MARK: Spinal Flexion Templates (20+ variations)
    
    private func getSpinalFlexionTemplates(severity: Double, exerciseName: String) -> [String] {
        var templates: [String] = []
        
        if severity > 0.8 {
            // Critical - urgent but supportive WITH instructions
            templates += [
                "Hey, look up! Keep that chest up!",
                "Eyes up! Let's keep chest proud!",
                "Head up! Straighten that back!",
                "Look forward! Chest needs to stay up!",
                "Gaze up! Keeps your spine safe!",
                "Look at the wall! Chest high!",
                "Eyes forward! Chest proud!",
                "Head position! Look up here!"
            ]
        } else if severity > 0.5 {
            templates += [
                "Chest up! Look forward!",
                "Eyes up! Keep chest proud!",
                "Look up! Prevents leaning!",
                "Head up! Chest stays up!",
                "Gaze forward! Chest high!",
                "Look ahead! Spine aligned!",
                "Eyes level! Chest up!",
                "Head position! Look up!",
                "Chest proud! Eyes forward!",
                "Keep that chest up! Look ahead!"
            ]
        } else {
            templates += [
                "Chest up",
                "Look forward",
                "Eyes up slightly",
                "Head position good",
                "Keep chest proud",
                "Nice - maintain posture",
                "Spine looks good"
            ]
        }
        
        // Exercise-specific
        if exerciseName.lowercased().contains("deadlift") {
            templates += [
                "Hinge at the hips!",
                "Keep back locked!",
                "Chest up, back flat!",
                "Neutral spine on deadlift!"
            ]
        }
        
        return templates
    }
    
    // MARK: Hip Position Templates (15+ variations)
    
    private func getHipPositionTemplates(severity: Double, phase: FormAnalyzer.ExercisePhase) -> [String] {
        var templates: [String] = []
        
        // Hip hinge specific (hips back FIRST)
        if phase == .descent || phase == .starting {
            templates += [
                "Hips back first! Not knees!",
                "Push butt back before bending knees!",
                "Sit back into it! Hips first!",
                "Hip hinge! Push butt back!",
                "Start with hips! Push back!",
                "Butt back! Then bend knees!",
                "Hips backward! Protect your knees!",
                "Think hips back first!",
                "Sit back! Don't just drop down!",
                "Push hips behind you!"
            ]
        }
        
        // General hip position
        templates += [
            "Hips back!",
            "Push hips back!",
            "Sit back!",
            "Load your hips!",
            "Drive through hips!",
            "Hips down and back!",
            "Drop your hips!",
            "Engage your glutes!",
            "Squeeze your glutes!",
            "Hip drive!",
            "Power from hips!",
            "Push with hips and quads!"
        ]
        
        return templates
    }
    
    // MARK: Speed/Control Templates (15+ variations)
    
    private func getSpeedTemplates(severity: Double) -> [String] {
        var templates: [String] = []
        
        if severity > 0.6 {
            templates += [
                "Slow down!",
                "Too fast!",
                "Control it!",
                "Easy there!",
                "Take your time!",
                "Don't rush!",
                "Slower tempo!",
                "Control the speed!"
            ]
        } else {
            templates += [
                "Steady pace",
                "Control the movement",
                "Smooth tempo",
                "Consistent speed",
                "Controlled descent",
                "Controlled ascent",
                "Smooth and steady"
            ]
        }
        
        return templates
    }
    
    // MARK: Ankle Stability Templates (10+ variations)
    
    private func getAnkleStabilityTemplates(severity: Double) -> [String] {
        return [
            "Plant your feet!",
            "Feet flat!",
            "Ground yourself!",
            "Stable base!",
            "Root down!",
            "Press through whole foot!",
            "Tripod foot!",
            "Heel down!",
            "Full foot contact!",
            "Anchor your feet!"
        ]
    }
    
    // MARK: Shoulder Position Templates (15+ variations)
    
    private func getShoulderPositionTemplates(severity: Double, exerciseName: String) -> [String] {
        var templates: [String] = []
        
        templates += [
            "Shoulders back!",
            "Retract shoulders!",
            "Pull shoulders back!",
            "Shoulder blades together!",
            "Pack your shoulders!",
            "Shoulders down!",
            "Relax shoulders!",
            "Shoulder position!",
            "Set your shoulders!",
            "Shoulders tight!",
            "Lock shoulders!",
            "Shoulder alignment!",
            "Upper back tight!",
            "Scapular retraction!",
            "Shoulders engaged!"
        ]
        
        return templates
    }
    
    // MARK: - Contextual Selection Logic
    
    private func selectSafetyCue(issue: FormIssue, severity: Double, context: CoachingContext) -> String {
        // Use professional safety cue library first for critical issues
        if severity > 0.8, let safetyCues = safetyCueLibrary[issue] {
            return selectUnusedTemplate(from: safetyCues)
        }
        
        // Fall back to existing templates for less severe issues
        let templates: [String]
        
        switch issue {
        case .kneeValgus, .kneeAlignment:
            templates = getKneeValgusTemplates(severity: severity, phase: context.phase)
        case .spinalFlexion, .backAlignment:
            templates = getSpinalFlexionTemplates(severity: severity, exerciseName: context.exerciseName)
        case .stability:
            templates = getStabilityTemplates(severity: severity, phase: context.phase)
        case .ankleStability:
            templates = getAnkleStabilityTemplates(severity: severity)
        default:
            templates = ["Watch your form!"]
        }
        
        return selectUnusedTemplate(from: templates)
    }
    
    private func selectFormCorrectionCue(issue: FormIssue, severity: Double, context: CoachingContext) -> String {
        let templates: [String]
        
        switch issue {
        case .kneeValgus, .kneeAlignment:
            templates = getKneeValgusTemplates(severity: severity, phase: context.phase)
        case .depth:
            templates = getDepthTemplates(severity: severity, phase: context.phase)
        case .backAlignment:
            templates = getBackAlignmentTemplates(severity: severity, phase: context.phase)
        case .spinalFlexion:
            templates = getSpinalFlexionTemplates(severity: severity, exerciseName: context.exerciseName)
        case .stability, .speed:
            templates = getStabilityTemplates(severity: severity, phase: context.phase)
        case .hipPosition:
            templates = getHipPositionTemplates(severity: severity, phase: context.phase)
        case .shoulderPosition:
            templates = getShoulderPositionTemplates(severity: severity, exerciseName: context.exerciseName)
        case .ankleStability:
            templates = getAnkleStabilityTemplates(severity: severity)
        }
        
        return selectUnusedTemplate(from: templates)
    }
    
    private func selectEncouragementCue(context: CoachingContext) -> String {
        let templates = getEncouragementTemplates(context: context)
        return selectUnusedTemplate(from: templates)
    }
    
    // MARK: - Template Selection Algorithm
    
    private func selectUnusedTemplate(from templates: [String]) -> String {
        // Filter out recently used cues
        let availableTemplates = templates.filter { !recentlyUsedCues.contains($0) }
        
        // If all templates were recently used, reset and use any
        let finalTemplates = availableTemplates.isEmpty ? templates : availableTemplates
        
        // Select random template from available ones
        guard let selectedTemplate = finalTemplates.randomElement() else {
            return "Keep going!"
        }
        
        // Track usage
        recentlyUsedCues.append(selectedTemplate)
        if recentlyUsedCues.count > maxRecentCues {
            recentlyUsedCues.removeFirst()
        }
        
        return selectedTemplate
    }
    
    // MARK: - Contextual Customization
    
    func customizeTemplate(_ template: String, context: CoachingContext) -> String {
        var response = template
        
        // Add contextual prefixes based on fatigue
        if context.userFatigueLevel > 0.8 && context.repNumber > 10 {
            let prefixes = ["Stay focused. ", "Dig deep. ", "Push through. ", "You got this. "]
            if let prefix = prefixes.randomElement() {
                response = prefix + response
            }
        }
        
        // Add contextual suffixes based on progress
        if context.repNumber == 1 {
            let suffixes = [" - let's nail this set", " - strong start", " - here we go"]
            if let suffix = suffixes.randomElement(), !response.contains("!") {
                response = response + suffix
            }
        }
        
        return response
    }
}

