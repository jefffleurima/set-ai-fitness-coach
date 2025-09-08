import Foundation
import Vision

enum ExerciseCategory: String, CaseIterable {
    case legs = "Legs"
    case core = "Core"
    case fullBody = "Full Body"
    
    var icon: String {
        switch self {
        case .legs: return "figure.walk"
        case .core: return "figure.core.training"
        case .fullBody: return "flame.fill"
        }
    }
}

enum FormQuality: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case acceptable = "Acceptable"
    case poor = "Poor"
    case dangerous = "Dangerous"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "lightgreen"
        case .acceptable: return "yellow"
        case .poor: return "orange"
        case .dangerous: return "red"
        }
    }
    
    var score: Int {
        switch self {
        case .excellent: return 95
        case .good: return 85
        case .acceptable: return 70
        case .poor: return 50
        case .dangerous: return 20
        }
    }
}

struct FormCriteria {
    let name: String
    let minValue: Double
    let maxValue: Double
    let importance: Double // 0.0 to 1.0 (how critical this is for safety)
    let description: String
}

struct ExercisePhase {
    let name: String
    let criteria: [FormCriteria]
    let tips: [String]
    let warnings: [String]
}

struct Exercise: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: ExerciseCategory
    let description: String
    let imageName: String
    let phases: [ExercisePhase]
    let keyJoints: [[VNHumanBodyPose3DObservation.JointName]]
    let safetyNotes: [String]
    let bodyTypeConsiderations: [String]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Exercise Database
extension Exercise {
    static let database: [Exercise] = [
        // SQUATS - Comprehensive form analysis
        Exercise(
            name: "squats",
            category: .legs,
            description: "A fundamental lower body exercise targeting quadriceps, hamstrings, and glutes. Focus on proper depth and knee tracking.",
            imageName: "squat_image",
            phases: [
                // Starting Position
                ExercisePhase(
                    name: "starting_position",
                    criteria: [
                        FormCriteria(name: "kneeAlignment", minValue: -5.0, maxValue: 5.0, importance: 0.9, description: "Knees aligned with toes"),
                        FormCriteria(name: "hipWidth", minValue: 0.15, maxValue: 0.25, importance: 0.7, description: "Feet shoulder-width apart"),
                        FormCriteria(name: "torsoUpright", minValue: 170.0, maxValue: 180.0, importance: 0.8, description: "Chest up, shoulders back")
                    ],
                    tips: [
                        "Stand with feet shoulder-width apart",
                        "Keep chest up and shoulders back",
                        "Engage your core before starting"
                    ],
                    warnings: [
                        "Avoid letting knees cave inward",
                        "Don't start with weight on toes"
                    ]
                ),
                // Descent Phase
                ExercisePhase(
                    name: "descent",
                    criteria: [
                        FormCriteria(name: "kneeTracking", minValue: -10.0, maxValue: 10.0, importance: 0.95, description: "Knees track over toes"),
                        FormCriteria(name: "hipHinge", minValue: 20.0, maxValue: 40.0, importance: 0.9, description: "Proper hip hinge motion"),
                        FormCriteria(name: "backAngle", minValue: 30.0, maxValue: 50.0, importance: 0.85, description: "Maintain neutral spine"),
                        FormCriteria(name: "weightDistribution", minValue: 0.4, maxValue: 0.6, importance: 0.8, description: "Weight on mid-foot to heels")
                    ],
                    tips: [
                        "Sit back into your hips first",
                        "Keep knees tracking over toes",
                        "Maintain neutral spine throughout",
                        "Control the descent speed"
                    ],
                    warnings: [
                        "DANGER: Don't let knees cave inward - can cause injury",
                        "Avoid excessive forward lean",
                        "Don't rush the descent"
                    ]
                ),
                // Bottom Position
                ExercisePhase(
                    name: "bottom",
                    criteria: [
                        FormCriteria(name: "depth", minValue: 80.0, maxValue: 110.0, importance: 0.7, description: "Thighs parallel or below"),
                        FormCriteria(name: "kneeStability", minValue: -5.0, maxValue: 5.0, importance: 0.95, description: "Knees stable, not caving"),
                        FormCriteria(name: "backNeutral", minValue: 25.0, maxValue: 45.0, importance: 0.9, description: "Maintain neutral spine"),
                        FormCriteria(name: "heelContact", minValue: 0.8, maxValue: 1.0, importance: 0.8, description: "Heels stay on ground")
                    ],
                    tips: [
                        "Go to at least parallel depth",
                        "Keep knees tracking over toes",
                        "Maintain chest up position",
                        "Feel the stretch in your glutes"
                    ],
                    warnings: [
                        "DANGER: Knee valgus (caving) can cause serious injury",
                        "Don't bounce at the bottom",
                        "Avoid excessive forward lean"
                    ]
                ),
                // Ascent Phase
                ExercisePhase(
                    name: "ascent",
                    criteria: [
                        FormCriteria(name: "kneeTracking", minValue: -10.0, maxValue: 10.0, importance: 0.95, description: "Knees track over toes"),
                        FormCriteria(name: "hipDrive", minValue: 0.0, maxValue: 20.0, importance: 0.8, description: "Drive hips forward"),
                        FormCriteria(name: "backAngle", minValue: 30.0, maxValue: 50.0, importance: 0.85, description: "Maintain neutral spine"),
                        FormCriteria(name: "smoothMotion", minValue: 0.0, maxValue: 0.3, importance: 0.7, description: "Smooth, controlled movement")
                    ],
                    tips: [
                        "Drive through your heels",
                        "Keep knees tracking over toes",
                        "Maintain chest up throughout",
                        "Squeeze glutes at the top"
                    ],
                    warnings: [
                        "DANGER: Knee valgus during ascent is dangerous",
                        "Don't let knees cave inward",
                        "Avoid excessive forward lean"
                    ]
                )
            ],
            keyJoints: [
                [.leftHip, .leftKnee, .leftAnkle],
                [.rightHip, .rightKnee, .rightAnkle],
                [.leftShoulder, .leftHip, .leftKnee],
                [.rightShoulder, .rightHip, .rightKnee],
                [.spine, .leftHip, .rightHip]
            ],
            safetyNotes: [
                "Knee valgus (caving inward) is the #1 cause of squat injuries",
                "Maintain neutral spine throughout the movement",
                "Start with bodyweight squats to master form",
                "If you feel pain, stop immediately"
            ],
            bodyTypeConsiderations: [
                "Long femurs: May need wider stance and more forward lean",
                "Short femurs: Can use narrower stance and more upright torso",
                "Limited ankle mobility: Use heel elevation or wider stance",
                "Tall individuals: May need to focus more on hip hinge"
            ]
        ),
        
        // DEADLIFTS - Comprehensive form analysis
        Exercise(
            name: "deadlifts",
            category: .fullBody,
            description: "A compound exercise targeting the entire posterior chain. Focus on hip hinge pattern and maintaining neutral spine.",
            imageName: "deadlift_image",
            phases: [
                // Starting Position
                ExercisePhase(
                    name: "starting_position",
                    criteria: [
                        FormCriteria(name: "footPosition", minValue: 0.15, maxValue: 0.25, importance: 0.8, description: "Feet hip-width apart"),
                        FormCriteria(name: "barPosition", minValue: 0.0, maxValue: 0.05, importance: 0.9, description: "Bar over mid-foot"),
                        FormCriteria(name: "backNeutral", minValue: 170.0, maxValue: 180.0, importance: 0.95, description: "Neutral spine, chest up"),
                        FormCriteria(name: "shoulderPosition", minValue: -5.0, maxValue: 5.0, importance: 0.8, description: "Shoulders over or slightly in front of bar")
                    ],
                    tips: [
                        "Stand with feet hip-width apart",
                        "Bar should be over mid-foot",
                        "Keep chest up and shoulders back",
                        "Engage your core and lats"
                    ],
                    warnings: [
                        "DANGER: Rounded back can cause serious injury",
                        "Don't start with bar too far from body",
                        "Avoid hyperextending the spine"
                    ]
                ),
                // Descent Phase
                ExercisePhase(
                    name: "descent",
                    criteria: [
                        FormCriteria(name: "hipHinge", minValue: 20.0, maxValue: 50.0, importance: 0.9, description: "Hip hinge motion, not squat"),
                        FormCriteria(name: "backAngle", minValue: 15.0, maxValue: 35.0, importance: 0.95, description: "Maintain neutral spine"),
                        FormCriteria(name: "barPath", minValue: -0.02, maxValue: 0.02, importance: 0.8, description: "Bar stays close to body"),
                        FormCriteria(name: "kneeAngle", minValue: 100.0, maxValue: 140.0, importance: 0.7, description: "Moderate knee bend")
                    ],
                    tips: [
                        "Hinge at the hips, not squat down",
                        "Keep bar close to your body",
                        "Maintain neutral spine throughout",
                        "Control the descent"
                    ],
                    warnings: [
                        "DANGER: Rounded back during descent is extremely dangerous",
                        "Don't let bar drift away from body",
                        "Avoid excessive knee bend"
                    ]
                ),
                // Bottom Position
                ExercisePhase(
                    name: "bottom",
                    criteria: [
                        FormCriteria(name: "backNeutral", minValue: 15.0, maxValue: 35.0, importance: 0.95, description: "Maintain neutral spine"),
                        FormCriteria(name: "barPosition", minValue: -0.02, maxValue: 0.02, importance: 0.9, description: "Bar over mid-foot"),
                        FormCriteria(name: "shoulderPosition", minValue: -5.0, maxValue: 5.0, importance: 0.8, description: "Shoulders over or slightly in front of bar"),
                        FormCriteria(name: "hipHeight", minValue: 0.3, maxValue: 0.5, importance: 0.7, description: "Hips higher than knees")
                    ],
                    tips: [
                        "Maintain neutral spine",
                        "Keep bar over mid-foot",
                        "Feel tension in hamstrings",
                        "Don't bounce at the bottom"
                    ],
                    warnings: [
                        "DANGER: Rounded back at bottom can cause disc injury",
                        "Don't let bar drift forward",
                        "Avoid bouncing or jerking"
                    ]
                ),
                // Ascent Phase
                ExercisePhase(
                    name: "ascent",
                    criteria: [
                        FormCriteria(name: "hipDrive", minValue: 0.0, maxValue: 20.0, importance: 0.9, description: "Drive hips forward"),
                        FormCriteria(name: "backAngle", minValue: 15.0, maxValue: 35.0, importance: 0.95, description: "Maintain neutral spine"),
                        FormCriteria(name: "barPath", minValue: -0.02, maxValue: 0.02, importance: 0.9, description: "Bar stays close to body"),
                        FormCriteria(name: "smoothMotion", minValue: 0.0, maxValue: 0.3, importance: 0.7, description: "Smooth, controlled movement")
                    ],
                    tips: [
                        "Drive hips forward to start",
                        "Keep bar close to your body",
                        "Maintain neutral spine throughout",
                        "Finish with hips fully extended"
                    ],
                    warnings: [
                        "DANGER: Rounded back during ascent can cause serious injury",
                        "Don't let bar drift away from body",
                        "Avoid jerky or uncontrolled movement"
                    ]
                )
            ],
            keyJoints: [
                [.leftShoulder, .leftHip, .leftKnee],
                [.rightShoulder, .rightHip, .rightKnee],
                [.leftHip, .leftKnee, .leftAnkle],
                [.rightHip, .rightKnee, .rightAnkle],
                [.spine, .leftHip, .rightHip]
            ],
            safetyNotes: [
                "Rounded back is the #1 cause of deadlift injuries",
                "Always maintain neutral spine throughout the movement",
                "Start with light weight to master the hip hinge pattern",
                "If you feel back pain, stop immediately"
            ],
            bodyTypeConsiderations: [
                "Long torso: May need to focus more on hip hinge",
                "Short torso: Can use more upright starting position",
                "Long arms: Advantage for deadlifts, can use narrower stance",
                "Short arms: May need wider stance or elevated starting position"
            ]
        )
    ]
    
    // Helper method to get exercise by name
    static func getExercise(named name: String) -> Exercise? {
        return database.first { $0.name.lowercased() == name.lowercased() }
    }
}

// MARK: - Form Analysis Result
struct FormAnalysisResult {
    let overallQuality: FormQuality
    let phaseResults: [String: FormQuality] // phase name -> quality
    let feedback: [String]
    let warnings: [String]
    let repCount: Int
    let isGoodRep: Bool
    
    var score: Int {
        return overallQuality.score
    }
}