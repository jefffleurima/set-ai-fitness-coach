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
                "hipAngle": 75...95,
                "kneeAngle": 80...100,
                "ankleAngle": 55...75,
                "torsoAngle": 35...50
            ]
        case .quads:
            return [
                "hipAngle": 80...100,
                "kneeAngle": 75...95,
                "ankleAngle": 65...85,
                "torsoAngle": 15...35
            ]
        case .balanced:
            return [
                "hipAngle": 80...95,
                "kneeAngle": 80...95,
                "ankleAngle": 60...80,
                "torsoAngle": 25...40
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
    let formRequirements: [String: [String: ClosedRange<Double>]]
    let keyJoints: [[VNHumanBodyPose3DObservation.JointName]]
    let squatVariation: SquatVariation?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        lhs.id == rhs.id
    }
}

extension Exercise {
    static let examples: [Exercise] = [
        Exercise(
            name: "Squats",
            category: .legs,
            description: "A fundamental lower body exercise that targets the quadriceps, hamstrings, and glutes.",
            imageName: "squat_image",
            formRequirements: [
                "bottom": [
                    "kneeAngle": 85...110,
                    "hipAngle": 45...65,
                    "torsoAngle": 30...50,
                    "ankleAngle": 60...85
                ],
                "top": [
                    "kneeAngle": 160...180,
                    "hipAngle": 160...180,
                    "torsoAngle": 170...180,
                    "ankleAngle": 80...100
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
        Exercise(
            name: "Deadlifts",
            category: .legs,
            description: "A compound exercise that works the entire posterior chain, including the back, glutes, and hamstrings.",
            imageName: "deadlift_image",
            formRequirements: [
                "bottom": [
                    "hipHingeAngle": 20...50,
                    "backAngle": 165...195,
                    "kneeAngle": 100...140
                ],
                "top": [
                    "hipHingeAngle": 170...190,
                    "backAngle": 170...190,
                    "kneeAngle": 170...190
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
        Exercise(
            name: "Lunges",
            category: .legs,
            description: "An effective exercise for targeting each leg individually, improving balance and strength.",
            imageName: "lunge_image",
            formRequirements: [
                "bottom": [
                    "frontKneeAngle": 80...100,
                    "backKneeAngle": 80...110,
                    "torsoAngle": 80...100
                ],
                "top": [
                    "frontKneeAngle": 160...190,
                    "backKneeAngle": 160...190,
                    "torsoAngle": 85...95
                ]
            ],
            keyJoints: [
                [.leftHip, .leftKnee, .leftAnkle],
                [.rightHip, .rightKnee, .rightAnkle]
            ],
            squatVariation: nil
        )
    ]
}
