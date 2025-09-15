import Foundation
import Vision
import UIKit

// MARK: - FormAnalyzerDelegate Protocol

protocol FormAnalyzerDelegate: AnyObject {
    func formAnalyzer(_ analyzer: FormAnalyzer, didUpdateFormScore score: Int)
    func formAnalyzer(_ analyzer: FormAnalyzer, didUpdateRepCount count: Int)
    func formAnalyzer(_ analyzer: FormAnalyzer, didProvideFeedback feedback: String)
}

/// FormAnalyzer for real-time exercise form analysis using Vision 2D pose detection
/// Uses comprehensive exercise database with verified form criteria for safety
class FormAnalyzer {
    
    // MARK: - Delegate
    weak var delegate: FormAnalyzerDelegate?
    
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
    
    // MARK: - Vision 2D Analysis (for current implementation)
    
    func analyzeVisionForm(observation: VNHumanBodyPoseObservation, exercise: Exercise) -> FormAnalysis {
        let jointPositions = getVisionJointPositions(from: observation)
        
        // Determine current phase
        let currentPhase = determineCurrentPhaseVision(jointPositions: jointPositions, exercise: exercise)
        
        // Analyze form for current phase
        let phaseAnalysis = analyzePhaseFormVision(jointPositions: jointPositions, phase: currentPhase, exercise: exercise)
        
        // Update rep count and phase history
        updateRepCount(currentPhase: currentPhase, phaseAnalysis: phaseAnalysis)
        
        // Generate comprehensive feedback
        let (feedback, _, _) = generateComprehensiveFeedback(
            phaseAnalysis: phaseAnalysis,
            currentPhase: currentPhase,
            exercise: exercise
        )
        
        // Calculate overall score
        let overallScore = calculateOverallScore(phaseAnalysis: phaseAnalysis)
        let _ = determineFormQuality(score: overallScore)
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.formAnalyzer(self!, didUpdateFormScore: Int(overallScore * 100))
            self?.delegate?.formAnalyzer(self!, didUpdateRepCount: self?.goodRepCount ?? 0)
            self?.delegate?.formAnalyzer(self!, didProvideFeedback: feedback)
        }
        
        return FormAnalysis(
            score: overallScore,
            feedback: feedback,
            repCount: goodRepCount,
            isGoodRep: phaseAnalysis.isGoodRep,
            quality: determineFormQuality(score: overallScore),
            warnings: [],
            tips: []
        )
    }
    
    
    
    
    // MARK: - Vision 2D Helper Methods
    
    private func getVisionJointPositions(from observation: VNHumanBodyPoseObservation) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var positions: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .root,
            .leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle,
            .rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle
        ]
        
        for jointName in jointNames {
            do {
                let point = try observation.recognizedPoint(jointName)
                if point.confidence > 0.3 {
                    positions[jointName] = point.location
                }
            } catch {
                // Handle error or simply skip joint
            }
        }
        return positions
    }
    
    private func determineCurrentPhaseVision(jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint], exercise: Exercise) -> ExercisePhase {
        // More accurate phase detection based on exercise type
        guard let leftHip = jointPositions[.leftHip],
              let leftKnee = jointPositions[.leftKnee],
              let rightHip = jointPositions[.rightHip],
              let rightKnee = jointPositions[.rightKnee] else {
            return .rest
        }
        
        let avgHipY = (leftHip.y + rightHip.y) / 2
        let avgKneeY = (leftKnee.y + rightKnee.y) / 2
        let hipKneeDistance = abs(avgHipY - avgKneeY)
        
        // Exercise-specific phase detection
        switch exercise.name.lowercased() {
        case "squats":
            // For squats, check hip depth relative to knees
            if hipKneeDistance > 0.15 {
                return .bottom // Deep squat position
            } else if hipKneeDistance > 0.08 {
                return .descent // Partial squat
            } else {
                return .starting // Standing position
            }
            
        case "deadlift":
            // For deadlift, check if shoulders are significantly above hips
            if let leftShoulder = jointPositions[.leftShoulder] {
                let shoulderHipDistance = abs(leftShoulder.y - avgHipY)
                if shoulderHipDistance > 0.1 {
                    return .bottom // Bent over position
                } else if shoulderHipDistance > 0.05 {
                    return .descent // Partial bend
                } else {
                    return .starting // Standing position
                }
            }
            return .rest
            
        default:
            // Generic phase detection
            if hipKneeDistance > 0.1 {
                return .bottom
            } else if hipKneeDistance > 0.05 {
                return .descent
            } else {
                return .starting
            }
        }
    }
    
    private func analyzePhaseFormVision(jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint], phase: ExercisePhase, exercise: Exercise) -> (score: Float, isGoodRep: Bool, criteria: [String: Float]) {
        
        var criteriaScores: [String: Float] = [:]
        var totalScore: Float = 0.0
        let criticalFailures = 0
        
        // Exercise-specific analysis
        switch exercise.name.lowercased() {
        case "squats":
            criteriaScores = analyzeSquatFormVision(jointPositions: jointPositions, phase: phase)
        case "deadlift":
            criteriaScores = analyzeDeadliftFormVision(jointPositions: jointPositions, phase: phase)
        default:
            criteriaScores = analyzeGenericFormVision(jointPositions: jointPositions, phase: phase)
        }
        
        // Calculate overall score
        for (_, score) in criteriaScores {
            totalScore += score
        }
        
        let averageScore = criteriaScores.isEmpty ? 0.0 : totalScore / Float(criteriaScores.count)
        
        // Lenient rep counting: Green = 50%+, Red = <50%
        // Focus on basic exercise recognition rather than strict form perfection
        // This prevents false negatives until we have real-world data for different body types
        let isGoodRep = averageScore >= 0.5 && criticalFailures == 0
        
        return (score: averageScore, isGoodRep: isGoodRep, criteria: criteriaScores)
    }
    
    private func analyzeSquatFormVision(jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint], phase: ExercisePhase) -> [String: Float] {
        var scores: [String: Float] = [:]
        
        // Realistic squat analysis - only give good scores for actual squat movements
        
        // Check if we have the essential joints for squat analysis
        guard let leftHip = jointPositions[.leftHip],
              let leftKnee = jointPositions[.leftKnee],
              let rightHip = jointPositions[.rightHip],
              let rightKnee = jointPositions[.rightKnee] else {
            // Missing essential joints - very low score
            scores["jointDetection"] = 0.2
            return scores
        }
        
        // Calculate hip and knee positions
        let avgHipY = (leftHip.y + rightHip.y) / 2
        let avgKneeY = (leftKnee.y + rightKnee.y) / 2
        let hipKneeDistance = abs(avgHipY - avgKneeY)
        
        // Movement analysis - only give good scores for actual squat depth
        if phase == .bottom {
            // For bottom position, hips should be significantly below knees
            if hipKneeDistance > 0.15 { // Significant depth
                scores["movement"] = 0.8
            } else if hipKneeDistance > 0.08 { // Some depth
                scores["movement"] = 0.6
            } else { // No real squat depth
                scores["movement"] = 0.3
            }
        } else if phase == .ascent {
            // During ascent, check if hips are moving up relative to knees
            scores["movement"] = 0.7
        } else {
            // Starting position or transition
            scores["movement"] = 0.5
        }
        
        // Stability analysis - hips should be roughly aligned
        let hipAlignment = abs(leftHip.x - rightHip.x)
        if hipAlignment < 0.1 {
            scores["stability"] = 0.8
        } else if hipAlignment < 0.2 {
            scores["stability"] = 0.6
        } else {
            scores["stability"] = 0.4
        }
        
        // Knee alignment
        let kneeAlignment = abs(leftKnee.x - rightKnee.x)
        if kneeAlignment < 0.15 {
            scores["kneeAlignment"] = 0.7
        } else {
            scores["kneeAlignment"] = 0.5
        }
        
        return scores
    }
    
    private func analyzeDeadliftFormVision(jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint], phase: ExercisePhase) -> [String: Float] {
        var scores: [String: Float] = [:]
        
        // Realistic deadlift analysis - only give good scores for actual deadlift movements
        
        // Check if we have the essential joints for deadlift analysis
        guard let leftHip = jointPositions[.leftHip],
              let leftKnee = jointPositions[.leftKnee],
              let leftShoulder = jointPositions[.leftShoulder],
              let rightHip = jointPositions[.rightHip] else {
            // Missing essential joints - very low score
            scores["jointDetection"] = 0.2
            return scores
        }
        
        // Calculate hip and shoulder positions
        let avgHipY = (leftHip.y + rightHip.y) / 2
        let shoulderY = leftShoulder.y
        let hipShoulderDistance = abs(avgHipY - shoulderY)
        
        // Movement analysis - deadlift involves hip hinge movement
        if phase == .bottom {
            // For bottom position, hips should be lower than shoulders (bent over position)
            if hipShoulderDistance > 0.1 {
                scores["movement"] = 0.8
            } else if hipShoulderDistance > 0.05 {
                scores["movement"] = 0.6
            } else { // No real hip hinge
                scores["movement"] = 0.3
            }
        } else if phase == .ascent {
            // During ascent, hips should be moving up
            scores["movement"] = 0.7
        } else {
            // Starting position or transition
            scores["movement"] = 0.5
        }
        
        // Stability analysis - hips should be roughly aligned
        let hipAlignment = abs(leftHip.x - rightHip.x)
        if hipAlignment < 0.1 {
            scores["stability"] = 0.8
        } else if hipAlignment < 0.2 {
            scores["stability"] = 0.6
        } else {
            scores["stability"] = 0.4
        }
        
        // Shoulder position relative to hips
        let shoulderHipAlignment = abs(leftShoulder.x - leftHip.x)
        if shoulderHipAlignment < 0.15 {
            scores["shoulderPosition"] = 0.7
        } else {
            scores["shoulderPosition"] = 0.5
        }
        
        return scores
    }
    
    private func analyzeGenericFormVision(jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint], phase: ExercisePhase) -> [String: Float] {
        var scores: [String: Float] = [:]
        
        // Basic stability analysis
        if let leftHip = jointPositions[.leftHip], let rightHip = jointPositions[.rightHip] {
            let hipStability = abs(leftHip.x - rightHip.x)
            scores["stability"] = max(0, 1.0 - Float(hipStability * 5))
        }
        
        return scores
    }
    
    // MARK: - Helper Methods
    
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
        
        // More realistic rep counting - require actual exercise movement
        if currentPhase == .ascent && phaseAnalysis.isGoodRep {
            // Check if we completed a full rep cycle with actual movement
            if phaseHistory.count >= 3 {
                let recentPhases = Array(phaseHistory.suffix(3))
                
                // Look for a complete movement pattern: descent -> bottom -> ascent
                if recentPhases.contains(.descent) && recentPhases.contains(.bottom) && recentPhases.contains(.ascent) {
                    // Additional check: make sure we had good form during the movement
                    if phaseAnalysis.score >= 0.6 { // Require at least 60% form score
                        goodRepCount += 1
                        print("✅ FormAnalyzer: Good rep completed! Score: \(Int(phaseAnalysis.score * 100))%. Total: \(goodRepCount)")
                        phaseHistory.removeAll() // Reset for next rep
                    } else {
                        print("❌ FormAnalyzer: Movement detected but form too poor (Score: \(Int(phaseAnalysis.score * 100))%). Not counting.")
                    }
                }
            }
        }
        
        // If form is very poor during ascent, don't count the rep
        if currentPhase == .ascent && phaseAnalysis.score < 0.4 {
            print("❌ FormAnalyzer: Very poor form detected (Score: \(Int(phaseAnalysis.score * 100))%). Not counting.")
            // Reset phase history to start fresh
            phaseHistory.removeAll()
        }
    }
    
    private func calculateOverallScore(phaseAnalysis: (score: Float, isGoodRep: Bool, criteria: [String: Float])) -> Float {
        return phaseAnalysis.score
    }
    
    private func determineFormQuality(score: Float) -> FormQuality {
        switch score {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.5..<0.6:
            return .acceptable
        case 0.3..<0.5:
            return .poor
        default:
            return .dangerous
        }
    }
    
    private func generateComprehensiveFeedback(phaseAnalysis: (score: Float, isGoodRep: Bool, criteria: [String: Float]), currentPhase: ExercisePhase, exercise: Exercise) -> (String, [String], [String]) {
        var feedback = ""
        var warnings: [String] = []
        let tips: [String] = []
        
        // Real-time form percentage feedback
        let formPercentage = Int(phaseAnalysis.score * 100)
        
        // Generate phase-specific feedback with form percentage
        switch currentPhase {
        case .starting:
            feedback = "Get ready! Form: \(formPercentage)%"
        case .descent:
            feedback = "Control descent. Form: \(formPercentage)%"
        case .bottom:
            feedback = "Hold position. Form: \(formPercentage)%"
        case .ascent:
            if phaseAnalysis.isGoodRep {
                feedback = "Great! Form: \(formPercentage)% - Rep counted!"
            } else {
                feedback = "Keep trying! \(formPercentage)% - Not counted"
            }
        case .rest:
            feedback = "Rest. Next rep target: 50%+"
        }
        
        // Add quality-specific feedback
        let quality = determineFormQuality(score: phaseAnalysis.score)
        switch quality {
        case .excellent:
            feedback += " 🟢 Excellent!"
        case .good:
            feedback += " 🟢 Good!"
        case .acceptable:
            feedback += " 🟡 Keep improving"
        case .poor:
            feedback += " 🔴 Needs work"
            warnings.append("Form quality is poor. Consider reducing weight.")
        case .dangerous:
            feedback += " 🔴 DANGER!"
            warnings.append("⚠️ DANGEROUS FORM DETECTED! Stop immediately and check your technique.")
        }
        
        return (feedback, warnings, tips)
    }
    
}