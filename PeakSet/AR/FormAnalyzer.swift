import Foundation
import Vision
import UIKit

/// FormAnalyzer for real-time exercise form analysis using 3D pose detection
/// Uses comprehensive exercise database with verified form criteria for safety
class FormAnalyzer {
    
    struct FormAnalysis {
        let score: Float
        let feedback: String
        let repCount: Int
        let isGoodRep: Bool
        let quality: FormQuality
        let warnings: [String]
        let tips: [String]
    }
    
    enum ExercisePhase {
        case starting
        case descent
        case bottom
        case ascent
        case rest
    }
    
    private var currentExercise: Exercise?
    private var repCount = 0
    private var lastPhase: ExercisePhase = .rest
    private var phaseHistory: [ExercisePhase] = []
    private var goodRepCount = 0
    
    func setExercise(_ exercise: Exercise) {
        self.currentExercise = exercise
        self.repCount = 0
        self.goodRepCount = 0
        self.phaseHistory = []
        print("✅ FormAnalyzer: Exercise set to \(exercise.name)")
    }
    
    func analyzeForm(observation: VNHumanBodyPose3DObservation, exercise: Exercise) -> FormAnalysis {
        let jointPositions = get3DJointPositions(from: observation)
        
        // Determine current phase
        let currentPhase = determineCurrentPhase(jointPositions: jointPositions, exercise: exercise)
        
        // Analyze form for current phase
        let phaseAnalysis = analyzePhaseForm(jointPositions: jointPositions, phase: currentPhase, exercise: exercise)
        
        // Update rep count and phase history
        updateRepCount(currentPhase: currentPhase, phaseAnalysis: phaseAnalysis)
        
        // Generate comprehensive feedback
        let (feedback, warnings, tips) = generateComprehensiveFeedback(
            phaseAnalysis: phaseAnalysis,
            currentPhase: currentPhase,
            exercise: exercise
        )
        
        // Calculate overall score
        let overallScore = calculateOverallScore(phaseAnalysis: phaseAnalysis)
        let quality = determineFormQuality(score: overallScore)
        
        return FormAnalysis(
            score: overallScore,
            feedback: feedback,
            repCount: goodRepCount,
            isGoodRep: phaseAnalysis.isGoodRep,
            quality: quality,
            warnings: warnings,
            tips: tips
        )
    }
    
    // MARK: - 3D Joint Position Extraction
    
    private func get3DJointPositions(from observation: VNHumanBodyPose3DObservation) -> [VNHumanBodyPose3DObservation.JointName: simd_float3] {
        var jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3] = [:]
        
        do {
            let recognizedPoints = try observation.recognizedPoints(.all)
            
            for (jointName, point) in recognizedPoints {
                let positionMatrix = point.position
                let x: Float = positionMatrix.columns.3.x
                let y: Float = positionMatrix.columns.3.y
                let z: Float = positionMatrix.columns.3.z
                jointPositions[jointName] = simd_float3(x, y, z)
            }
        } catch {
            print("❌ FormAnalyzer: Error getting joint positions: \(error)")
        }
        
        return jointPositions
    }
    
    // MARK: - Phase Detection
    
    private func determineCurrentPhase(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], exercise: Exercise) -> ExercisePhase {
        guard let leftHip = jointPositions[.leftHip],
              let rightHip = jointPositions[.rightHip],
              let leftKnee = jointPositions[.leftKnee],
              let rightKnee = jointPositions[.rightKnee] else {
            return .rest
        }
        
        // Calculate average hip and knee positions
        let avgHipY = (leftHip.y + rightHip.y) / 2
        let _ = (leftKnee.y + rightKnee.y) / 2 // avgKneeY - currently unused but kept for future use
        
        // Calculate hip-knee angle to determine depth
        let leftHipKneeAngle = calculateAngle(
            point1: leftHip,
            point2: leftKnee,
            point3: simd_float3(leftKnee.x, leftKnee.y - 0.1, leftKnee.z) // Reference point below knee
        )
        let rightHipKneeAngle = calculateAngle(
            point1: rightHip,
            point2: rightKnee,
            point3: simd_float3(rightKnee.x, rightKnee.y - 0.1, rightKnee.z)
        )
        let avgHipKneeAngle = (leftHipKneeAngle + rightHipKneeAngle) / 2
        
        // Phase detection logic based on exercise type
        switch exercise.name.lowercased() {
        case "squats":
            return determineSquatPhase(hipKneeAngle: avgHipKneeAngle, hipY: avgHipY)
        case "deadlifts":
            return determineDeadliftPhase(hipKneeAngle: avgHipKneeAngle, hipY: avgHipY)
        default:
            return .rest
        }
    }
    
    private func determineSquatPhase(hipKneeAngle: Float, hipY: Float) -> ExercisePhase {
        // Squat phase detection based on hip-knee angle and hip height
        if hipKneeAngle > 120 {
            return .starting
        } else if hipKneeAngle > 90 && lastPhase == .starting {
            return .descent
        } else if hipKneeAngle <= 90 {
            return .bottom
        } else if hipKneeAngle > 90 && lastPhase == .bottom {
            return .ascent
        } else {
            return .rest
        }
    }
    
    private func determineDeadliftPhase(hipKneeAngle: Float, hipY: Float) -> ExercisePhase {
        // Deadlift phase detection (different from squat)
        if hipKneeAngle > 140 {
            return .starting
        } else if hipKneeAngle > 110 && lastPhase == .starting {
            return .descent
        } else if hipKneeAngle <= 110 {
            return .bottom
        } else if hipKneeAngle > 110 && lastPhase == .bottom {
            return .ascent
        } else {
            return .rest
        }
    }
    
    // MARK: - Form Analysis
    
    private func analyzePhaseForm(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], phase: ExercisePhase, exercise: Exercise) -> (score: Float, isGoodRep: Bool, criteria: [String: Float]) {
        
        guard let exercisePhase = exercise.phases.first(where: { $0.name == phaseName(phase) }) else {
            return (score: 0.0, isGoodRep: false, criteria: [:])
        }
        
        var criteriaScores: [String: Float] = [:]
        var totalScore: Float = 0.0
        var criticalFailures = 0
        
        for criteria in exercisePhase.criteria {
            let score = evaluateCriteria(criteria: criteria, jointPositions: jointPositions, phase: phase, exercise: exercise)
            criteriaScores[criteria.name] = score
            totalScore += score * Float(criteria.importance)
            
            // Check for critical failures (safety issues)
            if criteria.importance >= 0.9 && score < 0.3 {
                criticalFailures += 1
            }
        }
        
        let averageScore = totalScore / Float(exercisePhase.criteria.count)
        let isGoodRep = averageScore >= 0.7 && criticalFailures == 0
        
        return (score: averageScore, isGoodRep: isGoodRep, criteria: criteriaScores)
    }
    
    private func evaluateCriteria(criteria: FormCriteria, jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], phase: ExercisePhase, exercise: Exercise) -> Float {
        
        switch criteria.name {
        case "kneeAlignment", "kneeTracking":
            return evaluateKneeAlignment(jointPositions: jointPositions)
        case "hipHinge":
            return evaluateHipHinge(jointPositions: jointPositions, exercise: exercise)
        case "backAngle", "backNeutral", "torsoAngle":
            return evaluateBackAngle(jointPositions: jointPositions, exercise: exercise)
        case "depth":
            return evaluateDepth(jointPositions: jointPositions, exercise: exercise)
        case "kneeStability":
            return evaluateKneeStability(jointPositions: jointPositions)
        case "barPath", "barPosition":
            return evaluateBarPath(jointPositions: jointPositions, exercise: exercise)
        case "shoulderPosition":
            return evaluateShoulderPosition(jointPositions: jointPositions, exercise: exercise)
        case "hipDrive":
            return evaluateHipDrive(jointPositions: jointPositions, exercise: exercise)
        case "smoothMotion":
            return evaluateSmoothMotion(jointPositions: jointPositions)
        default:
            return 0.5 // Default score for unknown criteria
        }
    }
    
    // MARK: - Specific Form Evaluations
    
    private func evaluateKneeAlignment(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3]) -> Float {
        guard let _ = jointPositions[.leftHip],
              let _ = jointPositions[.rightHip],
              let leftKnee = jointPositions[.leftKnee],
              let rightKnee = jointPositions[.rightKnee],
              let leftAnkle = jointPositions[.leftAnkle],
              let rightAnkle = jointPositions[.rightAnkle] else {
            return 0.0
        }
        
        // Calculate knee alignment relative to ankle
        let leftKneeAlignment = abs(leftKnee.x - leftAnkle.x)
        let rightKneeAlignment = abs(rightKnee.x - rightAnkle.x)
        let avgAlignment = (leftKneeAlignment + rightKneeAlignment) / 2
        
        // Score based on alignment (lower is better)
        if avgAlignment < 0.05 {
            return 1.0 // Excellent alignment
        } else if avgAlignment < 0.1 {
            return 0.8 // Good alignment
        } else if avgAlignment < 0.15 {
            return 0.6 // Acceptable alignment
        } else {
            return 0.2 // Poor alignment (knee valgus risk)
        }
    }
    
    private func evaluateHipHinge(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], exercise: Exercise) -> Float {
        guard let leftShoulder = jointPositions[.leftShoulder],
              let rightShoulder = jointPositions[.rightShoulder],
              let leftHip = jointPositions[.leftHip],
              let rightHip = jointPositions[.rightHip],
              let leftKnee = jointPositions[.leftKnee],
              let rightKnee = jointPositions[.rightKnee] else {
            return 0.0
        }
        
        let avgShoulder = (leftShoulder + rightShoulder) / 2
        let avgHip = (leftHip + rightHip) / 2
        let avgKnee = (leftKnee + rightKnee) / 2
        
        let hipHingeAngle = calculateAngle(point1: avgShoulder, point2: avgHip, point3: avgKnee)
        
        // Score based on exercise type
        switch exercise.name.lowercased() {
        case "squats":
            if hipHingeAngle >= 20 && hipHingeAngle <= 40 {
                return 1.0
            } else if hipHingeAngle >= 15 && hipHingeAngle <= 45 {
                return 0.8
            } else {
                return 0.4
            }
        case "deadlifts":
            if hipHingeAngle >= 20 && hipHingeAngle <= 50 {
                return 1.0
            } else if hipHingeAngle >= 15 && hipHingeAngle <= 55 {
                return 0.8
            } else {
                return 0.4
            }
        default:
            return 0.5
        }
    }
    
    private func evaluateBackAngle(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], exercise: Exercise) -> Float {
        guard let leftShoulder = jointPositions[.leftShoulder],
              let rightShoulder = jointPositions[.rightShoulder],
              let leftHip = jointPositions[.leftHip],
              let rightHip = jointPositions[.rightHip] else {
            return 0.0
        }
        
        let avgShoulder = (leftShoulder + rightShoulder) / 2
        let avgHip = (leftHip + rightHip) / 2
        
        // Calculate back angle (shoulder-hip line relative to vertical)
        let backAngle = atan2(avgShoulder.x - avgHip.x, avgShoulder.y - avgHip.y) * 180 / Float.pi
        
        // Score based on exercise type and phase
        switch exercise.name.lowercased() {
        case "squats":
            if backAngle >= 30 && backAngle <= 50 {
                return 1.0
            } else if backAngle >= 25 && backAngle <= 55 {
                return 0.8
            } else if backAngle >= 20 && backAngle <= 60 {
                return 0.6
            } else {
                return 0.3 // Too much or too little forward lean
            }
        case "deadlifts":
            if backAngle >= 15 && backAngle <= 35 {
                return 1.0
            } else if backAngle >= 10 && backAngle <= 40 {
                return 0.8
            } else if backAngle >= 5 && backAngle <= 45 {
                return 0.6
            } else {
                return 0.2 // Dangerous back position
            }
        default:
            return 0.5
        }
    }
    
    private func evaluateDepth(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], exercise: Exercise) -> Float {
        guard let leftHip = jointPositions[.leftHip],
              let rightHip = jointPositions[.rightHip],
              let leftKnee = jointPositions[.leftKnee],
              let rightKnee = jointPositions[.rightKnee] else {
            return 0.0
        }
        
        let avgHip = (leftHip + rightHip) / 2
        let avgKnee = (leftKnee + rightKnee) / 2
        
        let hipKneeAngle = calculateAngle(
            point1: avgHip,
            point2: avgKnee,
            point3: simd_float3(avgKnee.x, avgKnee.y - 0.1, avgKnee.z)
        )
        
        // Score based on exercise type
        switch exercise.name.lowercased() {
        case "squats":
            if hipKneeAngle <= 90 {
                return 1.0 // Parallel or below
            } else if hipKneeAngle <= 100 {
                return 0.8 // Close to parallel
            } else if hipKneeAngle <= 110 {
                return 0.6 // Above parallel
            } else {
                return 0.3 // Too shallow
            }
        case "deadlifts":
            if hipKneeAngle <= 110 {
                return 1.0 // Good depth for deadlift
            } else if hipKneeAngle <= 120 {
                return 0.8
            } else if hipKneeAngle <= 130 {
                return 0.6
            } else {
                return 0.4 // Too shallow
            }
        default:
            return 0.5
        }
    }
    
    private func evaluateKneeStability(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3]) -> Float {
        // This is a simplified version - in a real implementation, you'd track knee movement over time
        return evaluateKneeAlignment(jointPositions: jointPositions)
    }
    
    private func evaluateBarPath(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], exercise: Exercise) -> Float {
        // Simplified bar path evaluation - in reality, you'd track the bar position over time
        guard let leftShoulder = jointPositions[.leftShoulder],
              let rightShoulder = jointPositions[.rightShoulder] else {
            return 0.5
        }
        
        let avgShoulder = (leftShoulder + rightShoulder) / 2
        
        // For deadlifts, bar should be close to body
        if exercise.name.lowercased() == "deadlifts" {
            if abs(avgShoulder.x) < 0.1 {
                return 1.0
            } else if abs(avgShoulder.x) < 0.15 {
                return 0.8
            } else {
                return 0.4
            }
        }
        
        return 0.8 // Default good score for squats
    }
    
    private func evaluateShoulderPosition(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], exercise: Exercise) -> Float {
        guard let leftShoulder = jointPositions[.leftShoulder],
              let rightShoulder = jointPositions[.rightShoulder] else {
            return 0.5
        }
        
        let avgShoulder = (leftShoulder + rightShoulder) / 2
        
        // Check if shoulders are properly positioned
        if abs(avgShoulder.x) < 0.1 {
            return 1.0
        } else if abs(avgShoulder.x) < 0.15 {
            return 0.8
        } else {
            return 0.6
        }
    }
    
    private func evaluateHipDrive(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3], exercise: Exercise) -> Float {
        // Simplified hip drive evaluation
        return 0.8 // Default good score
    }
    
    private func evaluateSmoothMotion(jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3]) -> Float {
        // Simplified smooth motion evaluation
        return 0.8 // Default good score
    }
    
    // MARK: - Utility Functions
    
    private func calculateAngle(point1: simd_float3, point2: simd_float3, point3: simd_float3) -> Float {
        let vector1 = point1 - point2
        let vector2 = point3 - point2
        
        let dot = simd_dot(vector1, vector2)
        let mag1 = length(vector1)
        let mag2 = length(vector2)
        
        if mag1 == 0 || mag2 == 0 {
            return 0
        }
        
        let cosAngle = dot / (mag1 * mag2)
        let clampedCosAngle = max(-1, min(1, cosAngle))
        return acos(clampedCosAngle) * 180 / Float.pi
    }
    
    private func length(_ vector: simd_float3) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
    
    private func phaseName(_ phase: ExercisePhase) -> String {
        switch phase {
        case .starting: return "starting_position"
        case .descent: return "descent"
        case .bottom: return "bottom"
        case .ascent: return "ascent"
        case .rest: return "rest"
        }
    }
    
    // MARK: - Rep Counting and Feedback
    
    private func updateRepCount(currentPhase: ExercisePhase, phaseAnalysis: (score: Float, isGoodRep: Bool, criteria: [String: Float])) {
        // Update phase history
        if currentPhase != lastPhase {
            phaseHistory.append(currentPhase)
            lastPhase = currentPhase
            
            // Keep only recent history
            if phaseHistory.count > 10 {
                phaseHistory.removeFirst()
            }
        }
        
        // Detect rep completion (ascent phase with good form)
        if currentPhase == .ascent && phaseAnalysis.isGoodRep {
            // Check if we completed a full rep cycle
            if phaseHistory.count >= 4 {
                let recentPhases = Array(phaseHistory.suffix(4))
                if recentPhases == [.starting, .descent, .bottom, .ascent] {
                    goodRepCount += 1
                    print("✅ FormAnalyzer: Good rep completed! Total: \(goodRepCount)")
                    phaseHistory.removeAll() // Reset for next rep
                }
            }
        }
    }
    
    private func calculateOverallScore(phaseAnalysis: (score: Float, isGoodRep: Bool, criteria: [String: Float])) -> Float {
        return phaseAnalysis.score
    }
    
    private func determineFormQuality(score: Float) -> FormQuality {
        switch score {
        case 0.9...1.0:
            return .excellent
        case 0.8..<0.9:
            return .good
        case 0.7..<0.8:
            return .acceptable
        case 0.5..<0.7:
            return .poor
        default:
            return .dangerous
        }
    }
    
    private func generateComprehensiveFeedback(phaseAnalysis: (score: Float, isGoodRep: Bool, criteria: [String: Float]), currentPhase: ExercisePhase, exercise: Exercise) -> (String, [String], [String]) {
        
        guard let exercisePhase = exercise.phases.first(where: { $0.name == phaseName(currentPhase) }) else {
            return ("Keep practicing!", [], [])
        }
        
        var feedback = ""
        var warnings: [String] = []
        var tips: [String] = []
        
        // Generate phase-specific feedback
        switch currentPhase {
        case .starting:
            feedback = "Get ready! Focus on proper starting position."
        case .descent:
            feedback = "Control the descent. Keep form tight."
        case .bottom:
            feedback = "Hold position. Maintain control."
        case .ascent:
            feedback = "Drive up with good form!"
        case .rest:
            feedback = "Rest and prepare for next rep."
        }
        
        // Add quality-specific feedback
        let quality = determineFormQuality(score: phaseAnalysis.score)
        switch quality {
        case .excellent:
            feedback += " Excellent form!"
        case .good:
            feedback += " Good form, keep it up!"
        case .acceptable:
            feedback += " Form is okay, focus on improvements."
        case .poor:
            feedback += " Form needs work. Focus on technique."
            warnings.append("Form quality is poor. Consider reducing weight.")
        case .dangerous:
            feedback += " DANGER: Stop and check your form!"
            warnings.append("⚠️ DANGEROUS FORM DETECTED! Stop immediately and check your technique.")
        }
        
        // Add specific warnings for critical failures
        for (criteriaName, score) in phaseAnalysis.criteria {
            if score < 0.3 {
                if let criteria = exercisePhase.criteria.first(where: { $0.name == criteriaName }) {
                    if criteria.importance >= 0.9 {
                        warnings.append("⚠️ \(criteria.description) - This is critical for safety!")
                    }
                }
            }
        }
        
        // Add tips from exercise phase
        tips.append(contentsOf: exercisePhase.tips)
        
        return (feedback, warnings, tips)
    }
    
}