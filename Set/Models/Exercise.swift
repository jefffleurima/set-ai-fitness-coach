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

enum SquatVariation: String, CaseIterable {
    case glutes = "Glutes"
    case quads = "Quads"
    case balanced = "Balanced"
    
    var formRequirements: [String: ClosedRange<Double>] {
        switch self {
        case .glutes:
            return [
                "hipAngle": 75...95,    // Deeper hip angle for glute activation (research shows 80-90° optimal)
                "kneeAngle": 80...100,  // Knees stay more vertical (allows for hip hinge)
                "ankleAngle": 55...75,  // More ankle dorsiflexion (research shows 60-70° optimal)
                "torsoAngle": 35...50   // More forward lean (research shows 40-45° optimal)
            ]
        case .quads:
            return [
                "hipAngle": 80...100,   // Less hip flexion (research shows 85-95° optimal)
                "kneeAngle": 75...95,   // More knee flexion (research shows 80-90° optimal)
                "ankleAngle": 65...85,  // Less ankle dorsiflexion (research shows 70-80° optimal)
                "torsoAngle": 15...35   // More upright torso (research shows 20-30° optimal)
            ]
        case .balanced:
            return [
                "hipAngle": 80...95,    // Moderate hip flexion (research shows 85-90° optimal)
                "kneeAngle": 80...95,   // Moderate knee flexion (research shows 85-90° optimal)
                "ankleAngle": 60...80,  // Moderate ankle dorsiflexion (research shows 65-75° optimal)
                "torsoAngle": 25...40   // Moderate torso angle (research shows 30-35° optimal)
            ]
        }
    }
    
    var formTips: [String] {
        switch self {
        case .glutes:
            return [
                "Sit back into your heels",
                "Keep shins more vertical",
                "Lean forward slightly",
                "Feel the stretch in your glutes",
                "Keep chest up but lean forward from hips"
            ]
        case .quads:
            return [
                "Let knees travel forward",
                "Keep torso more upright",
                "Drive through mid-foot",
                "Focus on quad contraction",
                "Keep chest up throughout movement"
            ]
        case .balanced:
            return [
                "Keep weight centered",
                "Maintain neutral spine",
                "Drive through mid-foot",
                "Equal focus on quads and glutes",
                "Keep chest up and core engaged"
            ]
        }
    }
}

struct Exercise: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: ExerciseCategory
    let description: String
    let imageName: String
    
    // New properties for detailed form tracking
    let formRequirements: [String: [String: ClosedRange<Double>]]
    let keyJoints: [[VNHumanBodyPose3DObservation.JointName]]
    
    // Squat specific properties (can be deprecated or integrated into formRequirements)
    let squatVariation: SquatVariation?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Example Data
extension Exercise {
    static let examples: [Exercise] = [
        // Squats
        Exercise(
            name: "squats",
            category: .legs,
            description: "A fundamental lower body exercise that targets the quadriceps, hamstrings, and glutes.",
            imageName: "squat_image",
            formRequirements: [
                "bottom": [
                    "kneeAngle": 85.0...110.0,   // Knee flexion at bottom (thighs parallel to ground)
                    "hipAngle": 45.0...65.0,     // Hip flexion angle (proper hip hinge)
                    "torsoAngle": 30.0...50.0,   // Torso forward lean (maintains balance)
                    "ankleAngle": 60.0...85.0    // Ankle dorsiflexion (proper range)
                ],
                "top": [
                    "kneeAngle": 160.0...180.0,  // Near full knee extension
                    "hipAngle": 160.0...180.0,   // Near full hip extension
                    "torsoAngle": 170.0...180.0, // Upright torso
                    "ankleAngle": 80.0...100.0   // Neutral ankle position
                ]
            ],
            keyJoints: [
                [.leftHip, .leftKnee, .leftAnkle],
                [.rightHip, .rightKnee, .rightAnkle],
                [.leftShoulder, .leftHip, .leftKnee],
                [.rightShoulder, .rightHip, .rightKnee]
            ],
            squatVariation: .balanced
        ),
        // Deadlifts
        Exercise(
            name: "deadlifts",
            category: .legs,
            description: "A compound exercise that works the entire posterior chain, including the back, glutes, and hamstrings.",
            imageName: "deadlift_image",
            formRequirements: [
                "bottom": [
                    "hipHingeAngle": 20.0...50.0,   // Angle of shoulder-hip-knee (hip hinge)
                    "backAngle": 165.0...195.0, // Maintain a flat back
                    "kneeAngle": 100.0...140.0
                ],
                "top": [
                    "hipHingeAngle": 170.0...190.0, // Full hip extension
                    "backAngle": 170.0...190.0,
                    "kneeAngle": 170.0...190.0
                ]
            ],
            keyJoints: [
                [.leftShoulder, .leftHip, .leftKnee],
                [.rightShoulder, .rightHip, .rightKnee],
                [.leftHip, .leftKnee, .leftAnkle],
                [.rightHip, .rightKnee, .rightAnkle]
            ],
            squatVariation: nil
        ),

    ]
} 