import Foundation
import Vision
import simd

class FormAnalyzer {
    
    // MARK: - Data Structures
    
    struct FormAnalysis {
        let score: Float
        let jointScores: [VNHumanBodyPoseObservation.JointName: Float]
        let feedback: [String]
        let repCount: Int
        let isGoodRep: Bool
        let currentPhase: ExercisePhase
    }
    
    enum ExercisePhase: String {
        case preparation
        case eccentric
        case concentric
        case hold
        case rest
    }
    
    // MARK: - Configuration
    
    private struct ExerciseConfig {
        let keyJoints: [VNHumanBodyPoseObservation.JointName]
        let idealAngles: [AngleCheck]
        let alignmentChecks: [AlignmentCheck]
        let phaseThresholds: [ExercisePhase: Float]
    }
    
    private struct AngleCheck {
        let joint1: VNHumanBodyPoseObservation.JointName
        let joint2: VNHumanBodyPoseObservation.JointName
        let joint3: VNHumanBodyPoseObservation.JointName
        let idealRange: ClosedRange<Float>
        let weight: Float
    }
    
    private struct AlignmentCheck {
        let joints: [VNHumanBodyPoseObservation.JointName]
        let axis: Axis
        let tolerance: Float
        let weight: Float
    }
    
    private enum Axis {
        case x, y, z
    }
    
    // MARK: - Properties
    
    private var currentExercise: ExerciseType?
    private var exerciseConfigs: [ExerciseType: ExerciseConfig]
    private var repCount = 0
    private var lastRepTime: Date?
    private var phaseStartTime: Date?
    private var currentPhase: ExercisePhase = .preparation
    private var previousScores: [Float] = []
    
    // MARK: - Initialization
    
    init() {
        self.exerciseConfigs = [
            .squat: FormAnalyzer.createSquatConfig(),
            .pushup: FormAnalyzer.createPushupConfig(),
            .plank: FormAnalyzer.createPlankConfig(),
            .lunge: FormAnalyzer.createLungeConfig()
        ]
    }
    
    // MARK: - Public Interface
    
    func setExercise(_ exercise: ExerciseType) {
        self.currentExercise = exercise
        self.repCount = 0
        self.currentPhase = .preparation
        self.previousScores = []
    }
    
    func analyzeForm(_ observation: VNHumanBodyPoseObservation) -> FormAnalysis {
        guard let exercise = currentExercise, 
              let config = exerciseConfigs[exercise] else {
            return FormAnalysis(
                score: 0,
                jointScores: [:],
                feedback: ["No exercise selected"],
                repCount: 0,
                isGoodRep: false,
                currentPhase: .preparation
            )
        }
        
        // Calculate all joint positions first
        guard let jointPositions = extractJointPositions(observation) else {
            return FormAnalysis(
                score: 0,
                jointScores: [:],
                feedback: ["Could not detect body pose"],
                repCount: repCount,
                isGoodRep: false,
                currentPhase: currentPhase
            )
        }
        
        // Phase detection
        let newPhase = detectExercisePhase(config: config, jointPositions: jointPositions)
        if newPhase != currentPhase {
            phaseStartTime = Date()
            currentPhase = newPhase
        }
        
        // Calculate scores
        let angleScores = calculateAngleScores(config: config, jointPositions: jointPositions)
        let alignmentScores = calculateAlignmentScores(config: config, jointPositions: jointPositions)
        
        // Combine scores with weights
        let (totalScore, jointScores) = combineScores(
            angleScores: angleScores,
            alignmentScores: alignmentScores,
            config: config
        )
        
        // Track reps
        let isGoodRep = trackRepetition(totalScore: totalScore)
        
        // Generate feedback
        let feedback = generateFeedback(
            totalScore: totalScore,
            angleScores: angleScores,
            alignmentScores: alignmentScores,
            config: config
        )
        
        // Store previous scores for smoothing
        previousScores.append(totalScore)
        if previousScores.count > 5 {
            previousScores.removeFirst()
        }
        
        return FormAnalysis(
            score: previousScores.average,
            jointScores: jointScores,
            feedback: feedback,
            repCount: repCount,
            isGoodRep: isGoodRep,
            currentPhase: currentPhase
        )
    }
    
    // MARK: - Configuration Helpers
    
    private static func createSquatConfig() -> ExerciseConfig {
        let keyJoints: [VNHumanBodyPoseObservation.JointName] = [
            .leftHip, .rightHip, 
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .root, .spine
        ]
        
        let angleChecks = [
            AngleCheck(
                joint1: .leftHip, joint2: .leftKnee, joint3: .leftAnkle,
                idealRange: 80...120, weight: 0.4
            ),
            AngleCheck(
                joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle,
                idealRange: 80...120, weight: 0.4
            ),
            AngleCheck(
                joint1: .spine, joint2: .leftHip, joint3: .leftKnee,
                idealRange: 70...110, weight: 0.2
            )
        ]
        
        let alignmentChecks = [
            AlignmentCheck(
                joints: [.leftKnee, .leftAnkle],
                axis: .x, tolerance: 0.1, weight: 0.3
            ),
            AlignmentCheck(
                joints: [.rightKnee, .rightAnkle],
                axis: .x, tolerance: 0.1, weight: 0.3
            ),
            AlignmentCheck(
                joints: [.leftShoulder, .spine, .root],
                axis: .y, tolerance: 0.15, weight: 0.4
            )
        ]
        
        let phaseThresholds: [ExercisePhase: Float] = [
            .eccentric: 0.3,
            .concentric: 0.7,
            .hold: 0.9
        ]
        
        return ExerciseConfig(
            keyJoints: keyJoints,
            idealAngles: angleChecks,
            alignmentChecks: alignmentChecks,
            phaseThresholds: phaseThresholds
        )
    }
    
    // Similar createXConfig() methods for other exercises...
    
    // MARK: - Core Analysis
    
    private func extractJointPositions(_ observation: VNHumanBodyPoseObservation) -> [VNHumanBodyPoseObservation.JointName: simd_float3]? {
        var positions: [VNHumanBodyPoseObservation.JointName: simd_float3] = [:]
        
        do {
            for joint in VNHumanBodyPoseObservation.JointName.allCases {
                let point = try observation.recognizedPoint(joint)
                positions[joint] = simd_float3(point.x, point.y, 0)
            }
            return positions
        } catch {
            print("Error extracting joint positions: \(error)")
            return nil
        }
    }
    
    private func calculateAngleScores(config: ExerciseConfig, jointPositions: [VNHumanBodyPoseObservation.JointName: simd_float3]) -> [AngleCheck: Float] {
        var scores: [AngleCheck: Float] = [:]
        
        for check in config.idealAngles {
            guard let p1 = jointPositions[check.joint1],
                  let p2 = jointPositions[check.joint2],
                  let p3 = jointPositions[check.joint3] else { continue }
            
            let angle = calculateAngle(a: p1, b: p2, c: p3)
            let normalizedScore = check.idealRange.contains(angle) ? 1.0 : 
                max(0, 1.0 - min(abs(angle - check.idealRange.lowerBound), 
                                 abs(angle - check.idealRange.upperBound)) / 45.0)
            
            scores[check] = normalizedScore * 100
        }
        
        return scores
    }
    
    private func calculateAlignmentScores(config: ExerciseConfig, jointPositions: [VNHumanBodyPoseObservation.JointName: simd_float3]) -> [AlignmentCheck: Float] {
        var scores: [AlignmentCheck: Float] = [:]
        
        for check in config.alignmentChecks {
            guard check.joints.count >= 2 else { continue }
            
            let firstJoint = check.joints[0]
            guard let firstPos = jointPositions[firstJoint] else { continue }
            
            var aligned = true
            for joint in check.joints.dropFirst() {
                guard let pos = jointPositions[joint] else {
                    aligned = false
                    break
                }
                
                let diff: Float
                switch check.axis {
                case .x: diff = abs(firstPos.x - pos.x)
                case .y: diff = abs(firstPos.y - pos.y)
                case .z: diff = abs(firstPos.z - pos.z)
                }
                
                if diff > check.tolerance {
                    aligned = false
                    break
                }
            }
            
            scores[check] = aligned ? 100 : 0
        }
        
        return scores
    }
    
    private func combineScores(
        angleScores: [AngleCheck: Float],
        alignmentScores: [AlignmentCheck: Float],
        config: ExerciseConfig
    ) -> (total: Float, joints: [VNHumanBodyPoseObservation.JointName: Float]) {
        var totalScore: Float = 0
        var totalWeight: Float = 0
        var jointScores: [VNHumanBodyPoseObservation.JointName: Float] = [:]
        
        // Process angle scores
        for (check, score) in angleScores {
            totalScore += score * check.weight
            totalWeight += check.weight
            
            // Distribute score to involved joints
            let jointScore = score / 3.0
            jointScores[check.joint1, default: 0] += jointScore
            jointScores[check.joint2, default: 0] += jointScore
            jointScores[check.joint3, default: 0] += jointScore
        }
        
        // Process alignment scores
        for (check, score) in alignmentScores {
            totalScore += score * check.weight
            totalWeight += check.weight
            
            // Distribute score evenly to all joints in check
            let jointScore = score / Float(check.joints.count)
            for joint in check.joints {
                jointScores[joint, default: 0] += jointScore
            }
        }
        
        // Normalize joint scores
        for (joint, score) in jointScores {
            jointScores[joint] = min(100, score)
        }
        
        return (totalWeight > 0 ? totalScore / totalWeight : 0, jointScores)
    }
    
    // MARK: - Phase Detection
    
    private func detectExercisePhase(config: ExerciseConfig, jointPositions: [VNHumanBodyPoseObservation.JointName: simd_float3]) -> ExercisePhase {
        // Simplified phase detection - would be enhanced with exercise-specific logic
        let currentTime = Date()
        
        switch currentPhase {
        case .preparation:
            // Check if we've entered the exercise
            if phaseStartTime == nil || currentTime.timeIntervalSince(phaseStartTime!) > 2.0 {
                return .eccentric
            }
        case .eccentric:
            if let start = phaseStartTime, currentTime.timeIntervalSince(start) > 1.5 {
                return .concentric
            }
        case .concentric:
            if let start = phaseStartTime, currentTime.timeIntervalSince(start) > 1.0 {
                return .hold
            }
        case .hold:
            if let start = phaseStartTime, currentTime.timeIntervalSince(start) > 0.5 {
                return .rest
            }
        case .rest:
            if let start = phaseStartTime, currentTime.timeIntervalSince(start) > 1.0 {
                return .preparation
            }
        }
        
        return currentPhase
    }
    
    // MARK: - Repetition Tracking
    
    private func trackRepetition(totalScore: Float) -> Bool {
        let now = Date()
        let isGoodRep = totalScore >= 70
        
        // Simple rep counting logic
        if isGoodRep && currentPhase == .concentric && 
           (lastRepTime == nil || now.timeIntervalSince(lastRepTime!) > 1.0) {
            repCount += 1
            lastRepTime = now
            return true
        }
        
        return false
    }
    
    // MARK: - Feedback Generation
    
    private func generateFeedback(
        totalScore: Float,
        angleScores: [AngleCheck: Float],
        alignmentScores: [AlignmentCheck: Float],
        config: ExerciseConfig
    ) -> [String] {
        var feedback: [String] = []
        
        // General feedback based on total score
        if totalScore >= 85 {
            feedback.append("Excellent form! Keep it up!")
        } else if totalScore >= 70 {
            feedback.append("Good form, minor adjustments needed")
        } else if totalScore >= 50 {
            feedback.append("Form needs improvement")
        } else {
            feedback.append("Please check your form")
        }
        
        // Specific feedback for worst performing angles
        let worstAngles = angleScores.filter { $0.value < 70 }.sorted { $0.value < $1.value }
        if let worst = worstAngles.first {
            feedback.append("Adjust angle between \(worst.key.joint1), \(worst.key.joint2), \(worst.key.joint3)")
        }
        
        // Specific feedback for alignment issues
        let badAlignments = alignmentScores.filter { $0.value < 80 }
        if let worst = badAlignments.first {
            feedback.append("Keep \(worst.key.joints.map { $0.rawValue }.joined(separator: " and ")) aligned")
        }
        
        // Phase-specific feedback
        switch currentPhase {
        case .eccentric:
            feedback.append("Control the downward movement")
        case .concentric:
            feedback.append("Power through the upward movement")
        case .hold:
            feedback.append("Maintain position")
        default:
            break
        }
        
        return feedback
    }
    
    // MARK: - Math Utilities
    
    private func calculateAngle(a: simd_float3, b: simd_float3, c: simd_float3) -> Float {
        let ba = a - b
        let bc = c - b
        let dotProduct = simd_dot(ba, bc)
        let magnitude = simd_length(ba) * simd_length(bc)
        let angle = acos(dotProduct / magnitude) * 180 / .pi
        return angle.isNaN ? 0 : angle
    }
}

// MARK: - Extensions

extension Array where Element == Float {
    var average: Float {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Float(count)
    }
}

extension VNHumanBodyPoseObservation.JointName {
    static var allCases: [VNHumanBodyPoseObservation.JointName] {
        return [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
            .root, .neck, .spine
        ]
    }
}