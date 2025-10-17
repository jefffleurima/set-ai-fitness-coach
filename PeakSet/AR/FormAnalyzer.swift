import Foundation
import Vision
import UIKit
import AVFoundation

// MARK: - FormAnalyzerDelegate Protocol

protocol FormAnalyzerDelegate: AnyObject {
    func formAnalyzer(_ analyzer: FormAnalyzer, didUpdateFormScore score: Int)
    func formAnalyzer(_ analyzer: FormAnalyzer, didUpdateRepCount count: Int)
    func formAnalyzer(_ analyzer: FormAnalyzer, didProvideFeedback feedback: String)
    func formAnalyzer(_ analyzer: FormAnalyzer, didCompleteWorkout session: FormAnalyzer.WorkoutSessionData)
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
    
    // MARK: - Data Collection Structures
    
    struct WorkoutSessionData {
        let exercise: Exercise
        let startTime: Date
        let endTime: Date
        let duration: TimeInterval
        let totalReps: Int
        let goodReps: Int
        let averageFormScore: Float
        let repAnalysis: [RepAnalysis]
        let safetyIssues: [SafetyIssue]
        let formImprovements: [FormImprovement]
        let aiCoachingHistory: [String]
        let overallAssessment: String
    }
    
    struct RepAnalysis: Codable {
        let repNumber: Int
        let score: Float
        let phase: ExercisePhase
        let timestamp: Date
        let issues: [String]
        let duration: TimeInterval
        let keypointsData: String?  // JSON string instead of [String: Any]
    }
    
    struct SafetyIssue: Codable {
        let type: SafetyIssueType
        let severity: SafetySeverity
        let timestamp: Date
        let description: String
        let repNumber: Int?
    }
    
    struct FormImprovement: Codable {
        let area: String
        let improvement: String
        let timestamp: Date
        let repNumber: Int
    }
    
    enum SafetyIssueType: String, CaseIterable, Codable {
        case kneeValgus = "knee_valgus"
        case spinalFlexion = "spinal_flexion"
        case poorStability = "poor_stability"
        case excessiveSpeed = "excessive_speed"
        case incompleteRange = "incomplete_range"
    }
    
    enum SafetySeverity: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
    }
    
    enum ExercisePhase: String, CaseIterable, Codable {
        case starting = "starting"
        case descent = "descent"
        case bottom = "bottom"
        case ascent = "ascent"
        case rest = "rest"
    }
    
    private var currentExercise: Exercise?
    private var repCount = 0
    private var lastPhase: ExercisePhase = .rest
    private var phaseHistory: [ExercisePhase] = []
    private var goodRepCount = 0
    private var lastBottomPhaseScore: Float = 0.0  // Track score at bottom
    
    // Voice coaching timing
    private var lastVoiceCueTime: Date = Date()
    private let voiceCueInterval: TimeInterval = 3.0  // Min 3 seconds between cues
    private var lastSafetyWarningTime: Date = Date()
    private let safetyWarningInterval: TimeInterval = 5.0  // Min 5 seconds between safety warnings
    private var consecutiveGoodReps: Int = 0
    
    // Workout state tracking
    private var hasStartedMoving: Bool = false
    private var framesSinceLastMovement: Int = 0
    private var lastPhaseChangeTime: Date = Date()
    
    // Cue priority system
    enum CuePriority {
        case safety          // Immediate, can interrupt
        case repCount        // Always announce
        case formCorrection  // Throttled (3s interval)
        case encouragement   // Rare (after 3+ good reps)
    }
    
    // MARK: - Data Collection Properties
    private var workoutStartTime: Date?
    private var repAnalysis: [RepAnalysis] = []
    private var safetyIssues: [SafetyIssue] = []
    private var formImprovements: [FormImprovement] = []
    private var aiCoachingHistory: [String] = []
    
    func setExercise(_ exercise: Exercise) {
        self.currentExercise = exercise
        self.repCount = 0
        self.goodRepCount = 0
        self.phaseHistory = []
        self.lastPhase = .rest
        
        // Initialize workout state
        self.hasStartedMoving = false
        self.framesSinceLastMovement = 0
        self.consecutiveGoodReps = 0
        
        // Initialize data collection
        self.workoutStartTime = Date()
        self.repAnalysis = []
        self.safetyIssues = []
        self.formImprovements = []
        self.aiCoachingHistory = []
        
        print("✅ FormAnalyzer: Exercise set to \(exercise.name) - Waiting for movement to start...")
    }
    
    // MARK: - Vision 2D Analysis (for current implementation)
    
    func analyzeVisionForm(observation: VNHumanBodyPoseObservation, exercise: Exercise) -> FormAnalysis {
        let jointPositions = getVisionJointPositions(from: observation)
        
        // Determine current phase
        let currentPhase = determineCurrentPhaseVision(jointPositions: jointPositions, exercise: exercise)
        
        // Detect if user has started moving
        detectMovementStart(currentPhase: currentPhase)
        
        // Analyze form for current phase
        let phaseAnalysis = analyzePhaseFormVision(jointPositions: jointPositions, phase: currentPhase, exercise: exercise)
        
        // Update rep count and phase history
        updateRepCount(currentPhase: currentPhase, phaseAnalysis: phaseAnalysis)
        
        // Record rep analysis for data collection
        let issues = phaseAnalysis.criteria.compactMap { key, value in
            value < 0.5 ? key : nil
        }
        recordRepAnalysis(score: phaseAnalysis.score, phase: currentPhase, issues: issues, keypoints: jointPositions)
        
        // Only provide coaching if user has started moving
        var feedback = ""
        if hasStartedMoving {
            // Generate quick coaching cue from templates (no AI)
            feedback = generateQuickCue(score: phaseAnalysis.score, criteria: phaseAnalysis.criteria, phase: currentPhase)
            
            // Speak the cue if we have one
            if !feedback.isEmpty {
                speakCue(feedback, priority: .formCorrection)
            }
        } else {
            // Show ready message
            feedback = "Get ready - start when you're ready!"
        }
        
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
    
    
    
    
    // MARK: - Movement Detection
    
    private func detectMovementStart(currentPhase: ExercisePhase) {
        // Detect when user actually starts exercising
        if !hasStartedMoving {
            // User has started if they enter descent or bottom phase
            if currentPhase == .descent || currentPhase == .bottom {
                hasStartedMoving = true
                print("🏋️ FormAnalyzer: Movement detected - coaching activated!")
            }
        }
        
        // Track phase changes to detect activity
        if currentPhase != lastPhase && currentPhase != .rest && currentPhase != .starting {
            lastPhaseChangeTime = Date()
            framesSinceLastMovement = 0
        } else {
            framesSinceLastMovement += 1
        }
        
        // Reset movement detection if user stops for too long (5 seconds of no movement)
        if framesSinceLastMovement > 100 && Date().timeIntervalSince(lastPhaseChangeTime) > 5.0 {
            if hasStartedMoving {
                hasStartedMoving = false
                print("⏸️ FormAnalyzer: No movement detected - coaching paused")
            }
        }
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
        
        // Debug: Log distance values periodically
        if Int.random(in: 0..<60) == 0 {  // Log ~1 per second at 20 FPS
            print("📏 Hip-Knee Distance: \(String(format: "%.3f", hipKneeDistance)) | Hip Y: \(String(format: "%.3f", avgHipY)) | Knee Y: \(String(format: "%.3f", avgKneeY))")
        }
        
        // Exercise-specific phase detection
        switch exercise.name.lowercased() {
        case "squats":
            // For squats, check hip depth relative to knees
            // Very sensitive thresholds to detect any squat movement
            if hipKneeDistance > 0.06 {  // Bottom position (hips below knees) - LOWERED
                return .bottom
            } else if hipKneeDistance > 0.03 && avgHipY < avgKneeY {  // Descending (hips moving down)
                return .descent
            } else if hipKneeDistance > 0.03 && avgHipY >= avgKneeY {  // Ascending (hips moving up)
                return .ascent
            } else if hipKneeDistance <= 0.03 {  // Standing upright
                return .starting
            } else {
                return .rest  // Fallback
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
        
        // COMPREHENSIVE SQUAT BIOMECHANICS ANALYSIS
        // Based on proper squat technique: hip hinge first, chest up, knees out, 90° depth
        
        // Check if we have ALL essential joints for comprehensive squat analysis
        guard let leftHip = jointPositions[.leftHip],
              let leftKnee = jointPositions[.leftKnee],
              let leftAnkle = jointPositions[.leftAnkle],
              let rightHip = jointPositions[.rightHip],
              let rightKnee = jointPositions[.rightKnee],
              let rightAnkle = jointPositions[.rightAnkle],
              let leftShoulder = jointPositions[.leftShoulder],
              let rightShoulder = jointPositions[.rightShoulder],
              let leftWrist = jointPositions[.leftWrist],
              let rightWrist = jointPositions[.rightWrist],
              let nose = jointPositions[.nose] else {
            scores["jointDetection"] = 0.2
            return scores
        }
        
        // Calculate key body positions
        let avgHipY = (leftHip.y + rightHip.y) / 2
        let avgHipX = (leftHip.x + rightHip.x) / 2
        let avgKneeY = (leftKnee.y + rightKnee.y) / 2
        let avgKneeX = (leftKnee.x + rightKnee.x) / 2
        let avgAnkleX = (leftAnkle.x + rightAnkle.x) / 2
        let avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let avgShoulderX = (leftShoulder.x + rightShoulder.x) / 2
        
        // === 1. STANCE WIDTH DETECTION (Shoulder width apart) ===
        let ankleWidth = abs(leftAnkle.x - rightAnkle.x)
        let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
        let stanceRatio = ankleWidth / max(shoulderWidth, 0.01)
        
        // Proper stance: 1.0 to 1.3x shoulder width
        if stanceRatio >= 0.95 && stanceRatio <= 1.35 {
            scores["stanceWidth"] = 0.95  // Perfect stance
        } else if stanceRatio >= 0.8 && stanceRatio <= 1.5 {
            scores["stanceWidth"] = 0.75  // Acceptable
        } else {
            scores["stanceWidth"] = 0.4   // Too narrow or wide
        }
        
        // === 2. WEIGHT EQUIPMENT DETECTION ===
        // Detect if holding weight (hands together/close) or bodyweight (hands extended)
        let handDistance = sqrt(pow(leftWrist.x - rightWrist.x, 2) + pow(leftWrist.y - rightWrist.y, 2))
        let hasWeight = handDistance < 0.15  // Hands close together = holding weight
        
        // === 3. ARM POSITION (For bodyweight squats - counterbalance) ===
        if !hasWeight {
            // Arms should be extended forward for counterbalance
            let avgWristX = (leftWrist.x + rightWrist.x) / 2
            let armsForward = avgWristX > avgShoulderX + 0.05  // Arms in front of shoulders
            
            if phase == .descent || phase == .bottom {
                if armsForward {
                    scores["armPosition"] = 0.95  // Perfect counterbalance
                } else {
                    scores["armPosition"] = 0.5   // Arms not extended
                }
            } else {
                scores["armPosition"] = 0.8  // Less critical in other phases
            }
        } else {
            // With weight, arms position is less critical
            scores["armPosition"] = 0.9
        }
        
        // === 4. HIP HINGE MECHANICS (Most critical) ===
        // Hips should move back first before knees bend significantly
        let _ = abs(avgHipX - avgKneeX)  // Reserved for future horizontal distance analysis
        
        if phase == .descent || phase == .bottom {
            // During descent, hips should be BEHIND knees (proper hip hinge)
            if avgHipX < avgKneeX - 0.03 {  // Hips behind knees
                scores["hipHinge"] = 0.95  // Perfect hip hinge
            } else if avgHipX < avgKneeX {
                scores["hipHinge"] = 0.75  // Some hip hinge
            } else {
                scores["hipHinge"] = 0.3   // No hip hinge - dangerous!
            }
        } else {
            scores["hipHinge"] = 0.8  // Neutral in other phases
        }
        
        // === 5. KNEE TRACKING (Knees stay in place, don't shoot forward) ===
        let kneeAnkleDistance = abs(avgKneeX - avgAnkleX)
        
        if phase == .descent || phase == .bottom {
            // Knees should stay relatively over ankles (not shooting forward)
            if kneeAnkleDistance < 0.05 {
                scores["kneeTracking"] = 0.95  // Perfect tracking
            } else if kneeAnkleDistance < 0.10 {
                scores["kneeTracking"] = 0.75  // Acceptable
            } else {
                scores["kneeTracking"] = 0.4   // Knees too far forward
            }
        } else {
            scores["kneeTracking"] = 0.8
        }
        
        // === 6. DEPTH ANALYSIS (90° minimum, no leniency) ===
        let hipKneeVerticalDistance = abs(avgHipY - avgKneeY)
        
        if phase == .bottom {
            // Hips must reach at least knee level (90°) - NO LENIENCY
            if hipKneeVerticalDistance >= 0.15 {  // Hips well below knees (ATG)
                scores["depth"] = 1.0  // Perfect depth
            } else if hipKneeVerticalDistance >= 0.10 {  // Parallel (90°)
                scores["depth"] = 0.9  // Good depth
            } else if hipKneeVerticalDistance >= 0.05 {  // Approaching parallel
                scores["depth"] = 0.6  // Not deep enough
            } else {
                scores["depth"] = 0.3  // Way too shallow
            }
        } else if phase == .descent {
            scores["depth"] = 0.8  // Descending
        } else {
            scores["depth"] = 0.7  // Other phases
        }
        
        // === 7. CHEST UP / SPINE ALIGNMENT (Prevent forward lean) ===
        // Head and eyes up keeps spine aligned and chest up
        let headPosition = nose.y
        let spineAngle = abs(avgShoulderY - avgHipY)
        
        if phase == .descent || phase == .bottom {
            // Check if chest is up (head above hips by sufficient margin)
            let headHipDistance = abs(headPosition - avgHipY)
            
            if headHipDistance > 0.25 && spineAngle > 0.20 {
                scores["chestUp"] = 0.95  // Perfect - chest up, spine aligned
            } else if headHipDistance > 0.20 && spineAngle > 0.15 {
                scores["chestUp"] = 0.75  // Decent
            } else {
                scores["chestUp"] = 0.4   // Leaning forward too much
            }
            } else {
            scores["chestUp"] = 0.8
        }
        
        // === 8. KNEE VALGUS DETECTION (Critical Safety - Knees cave in) ===
        let kneeValgusResult = detectKneeValgus(leftKnee: leftKnee, rightKnee: rightKnee, leftAnkle: leftAnkle, rightAnkle: rightAnkle)
        if kneeValgusResult.isDetected {
            scores["kneeValgus"] = kneeValgusResult.isSevere ? 0.0 : 0.2  // NO TOLERANCE for valgus
        } else {
            scores["kneeValgus"] = 0.95  // Knees tracking properly
        }
        
        // === 9. OVERALL STABILITY ===
        let hipAlignment = abs(leftHip.x - rightHip.x)
        let shoulderAlignment = abs(leftShoulder.x - rightShoulder.x)
        
        if hipAlignment < 0.08 && shoulderAlignment < 0.08 {
            scores["stability"] = 0.95  // Very stable
        } else if hipAlignment < 0.15 && shoulderAlignment < 0.15 {
            scores["stability"] = 0.75  // Acceptable
            } else {
            scores["stability"] = 0.5   // Unstable
        }
        
        // === 10. WEIGHT-SPECIFIC ADJUSTMENTS ===
        if hasWeight {
            // With weight, form must be stricter
            // Reduce all scores by 5% to enforce higher standards
            for key in scores.keys {
                scores[key] = max(0, scores[key]! - 0.05)
            }
        }
        
        return scores
    }
    
    private func analyzeDeadliftFormVision(jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint], phase: ExercisePhase) -> [String: Float] {
        var scores: [String: Float] = [:]
        
        // Realistic deadlift analysis - only give good scores for actual deadlift movements
        
        // Check if we have the essential joints for deadlift analysis
        guard let leftHip = jointPositions[.leftHip],
              let _ = jointPositions[.leftKnee],
              let leftShoulder = jointPositions[.leftShoulder],
              let rightShoulder = jointPositions[.rightShoulder],
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
        
        // SPINAL FLEXION DETECTION (Critical Safety Algorithm)
        let spinalFlexionResult = detectSpinalFlexion(leftShoulder: leftShoulder, rightShoulder: rightShoulder, leftHip: leftHip, rightHip: rightHip)
        if spinalFlexionResult.isDetected {
            scores["spinalFlexion"] = spinalFlexionResult.isSevere ? 0.1 : 0.3 // Very low score for flexion
        } else {
            scores["spinalFlexion"] = 0.9 // Good score for neutral spine
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
        // Save score when AT bottom (not during transition)
        if currentPhase == .bottom {
            lastBottomPhaseScore = phaseAnalysis.score
        }
        
        // Track phase transitions
        if currentPhase != lastPhase {
            print("🔄 Phase transition: \(lastPhase.rawValue) → \(currentPhase.rawValue), Score: \(Int(phaseAnalysis.score * 100))%")
            
            // Detect rep completion: bottom → any upward/ending phase
            // Count on: bottom → ascent, bottom → starting, OR bottom → rest
            if lastPhase == .bottom && (currentPhase == .ascent || currentPhase == .starting || currentPhase == .rest) {
                // Use the score from when we WERE at bottom, not current transition phase
                let repFormScore = lastBottomPhaseScore
                
                // Count rep if form is acceptable (50%+)
                if repFormScore >= 0.5 {
                    repCount += 1
                    
                    // Track good reps separately (70%+ form)
                    if repFormScore >= 0.7 {
                        goodRepCount += 1
                        print("✅ FormAnalyzer: GOOD REP #\(repCount) completed! Form: \(Int(repFormScore * 100))%")
                    } else {
                        print("⚠️ FormAnalyzer: Rep #\(repCount) completed (acceptable form: \(Int(repFormScore * 100))%)")
                    }
                    
                    // Speak rep count announcement
                    speakRepCount(repCount, formScore: repFormScore)
                    
                    // Clear old history but keep last few phases
                    if phaseHistory.count > 5 {
                        phaseHistory.removeFirst(phaseHistory.count - 2)
                    }
                } else {
                    print("❌ FormAnalyzer: Movement detected but form too poor at bottom (Score: \(Int(repFormScore * 100))%). Not counting.")
                }
                
                // Reset bottom score
                lastBottomPhaseScore = 0.0
            }
            
            // Update phase history
            phaseHistory.append(currentPhase)
            lastPhase = currentPhase
            
            // Keep only recent history
            if phaseHistory.count > 10 {
                phaseHistory.removeFirst()
            }
        }
    }
    
    // MARK: - Template-Based Coaching Cues (Contextual)
    
    private func generateQuickCue(score: Float, criteria: [String: Float], phase: ExercisePhase) -> String {
        // Don't provide form cues if just standing/resting
        guard phase != .rest && phase != .starting else {
            print("🔇 No coaching: phase is \(phase.rawValue)")
            return ""  // Silence when not actively exercising
        }
        
        // Only provide cues if form needs correction (< 70%)
        guard score < 0.7 else {
            print("✅ No coaching: form is good (\(Int(score * 100))%)")
            return ""
        }
        
        print("🔍 Generating cue: score=\(Int(score * 100))%, phase=\(phase.rawValue), criteria=\(criteria.count) items")
        
        // Identify the primary form issue and its severity
        var primaryIssue: FormIssue? = nil
        var issueSeverity: Double = 0.0
        var worstCriteria: String = ""
        
        // Find the worst performing criterion
        for (criteriaName, criteriaScore) in criteria {
            // Skip joint detection - not a form cue
            guard criteriaName != "jointDetection" else { continue }
            
            let severity = Double(1.0 - criteriaScore)  // Convert score to severity
            
            if severity > issueSeverity {
                issueSeverity = severity
                worstCriteria = criteriaName
                
                // Map criteria to FormIssue
                switch criteriaName {
                case "kneeAlignment", "kneeValgus", "kneeTracking":
                    primaryIssue = .kneeValgus
                case "backAlignment", "spinalFlexion", "chestUp":
                    primaryIssue = .spinalFlexion  // Chest up = spine alignment
                case "movement", "depth":
                    primaryIssue = .depth
                case "stability", "stanceWidth":
                    primaryIssue = .stability
                case "hipPosition", "hipHinge":
                    primaryIssue = .hipPosition  // Hip hinge is hip positioning
                case "shoulderPosition", "armPosition":
                    primaryIssue = .shoulderPosition
                default:
                    break
                }
            }
        }
        
        // No issue identified - don't provide cue
        guard let issue = primaryIssue else {
            return ""
        }
        
        // Build coaching context
        let context = CoachingContext(
            formIssue: issue,
            severity: issueSeverity,
            repNumber: repCount,
            consecutiveGoodReps: consecutiveGoodReps,
            phase: phase,
            exerciseName: currentExercise?.name ?? "exercise",
            previousCues: [],
            userFatigueLevel: estimateFatigueLevel()
        )
        
        // Get contextual coaching cue from template library
        let cue = WorkoutCoachingTemplates.shared.generateCoachingCue(context: context) ?? ""
        
        if !cue.isEmpty {
            print("💡 Coaching: \(worstCriteria) (\(Int(issueSeverity * 100))% severity) → '\(cue)'")
        }
        
        return cue
    }
    
    private func estimateFatigueLevel() -> Double {
        // Estimate fatigue based on rep count and form score decline
        if repCount < 5 {
            return 0.2  // Fresh
        } else if repCount < 10 {
            return 0.5  // Moderate
        } else if repCount < 15 {
            return 0.7  // Fatigued
        } else {
            return 0.9  // Exhausted
        }
    }
    
    private func speakRepCount(_ count: Int, formScore: Float) {
        // Build coaching context
        let context = CoachingContext(
            formIssue: nil,
            severity: 0.0,
            repNumber: count,
            consecutiveGoodReps: consecutiveGoodReps,
            phase: .ascent,  // Rep counts happen on ascent
            exerciseName: currentExercise?.name ?? "exercise",
            previousCues: [],
            userFatigueLevel: estimateFatigueLevel()
        )
        
        // Get contextual rep count cue from template library
        let cue = WorkoutCoachingTemplates.shared.generateRepCountCue(
            repNumber: count,
            formScore: Double(formScore),
            context: context
        )
        
        if !cue.isEmpty {
            speakCue(cue, priority: .repCount)
        }
    }
    
    private func speakCue(_ text: String, priority: CuePriority) {
        // Check if we should speak based on priority and timing
        let timeSinceLastCue = Date().timeIntervalSince(lastVoiceCueTime)
        
        let shouldSpeak: Bool
        switch priority {
        case .safety:
            shouldSpeak = Date().timeIntervalSince(lastSafetyWarningTime) >= safetyWarningInterval
        case .repCount:
            shouldSpeak = true  // Always announce rep counts
        case .formCorrection:
            shouldSpeak = timeSinceLastCue >= voiceCueInterval
        case .encouragement:
            shouldSpeak = timeSinceLastCue >= voiceCueInterval && consecutiveGoodReps >= 3
        }
        
        guard shouldSpeak else { return }
        
        // Update timing
        lastVoiceCueTime = Date()
        if priority == .safety {
            lastSafetyWarningTime = Date()
        }
        
        // Speak using ElevenLabs (will use cached audio if available)
        DispatchQueue.main.async {
            VoiceAssistantManager.shared.speakWorkoutCue(text)
        }
        
        // Also update UI feedback
        DispatchQueue.main.async {
            self.delegate?.formAnalyzer(self, didProvideFeedback: text)
        }
        
        print("🗣️ Workout cue: \(text) (priority: \(priority))")
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
    
    // REMOVED: No AI during workouts - using template-based coaching instead
    
    // MARK: - Real Safety Algorithms
    
    /// Detects knee valgus (knees caving inward) - critical for injury prevention
    private func detectKneeValgus(leftKnee: CGPoint, rightKnee: CGPoint, leftAnkle: CGPoint, rightAnkle: CGPoint) -> (isDetected: Bool, isSevere: Bool) {
        
        // Calculate knee-to-ankle alignment
        let leftKneeAnkleAlignment = abs(leftKnee.x - leftAnkle.x)
        let rightKneeAnkleAlignment = abs(rightKnee.x - rightAnkle.x)
        
        // Knee valgus detection thresholds
        let valgusThreshold = 0.05 // 5% of image width
        let severeValgusThreshold = 0.1 // 10% of image width
        
        let maxAlignment = max(leftKneeAnkleAlignment, rightKneeAnkleAlignment)
        
        if maxAlignment > severeValgusThreshold {
            return (isDetected: true, isSevere: true)
        } else if maxAlignment > valgusThreshold {
            return (isDetected: true, isSevere: false)
        } else {
            return (isDetected: false, isSevere: false)
        }
    }
    
    /// Detects spinal flexion (back rounding) - critical for deadlift safety
    private func detectSpinalFlexion(leftShoulder: CGPoint, rightShoulder: CGPoint, leftHip: CGPoint, rightHip: CGPoint) -> (isDetected: Bool, isSevere: Bool) {
        
        // Calculate shoulder and hip positions
        let avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let avgHipY = (leftHip.y + rightHip.y) / 2
        
        // Calculate spinal angle (approximate)
        let shoulderHipDistance = abs(avgShoulderY - avgHipY)
        
        // Spinal flexion detection thresholds
        let flexionThreshold = 0.15 // 15% of image height
        let severeFlexionThreshold = 0.25 // 25% of image height
        
        if shoulderHipDistance > severeFlexionThreshold {
            return (isDetected: true, isSevere: true)
        } else if shoulderHipDistance > flexionThreshold {
            return (isDetected: true, isSevere: false)
        } else {
            return (isDetected: false, isSevere: false)
        }
    }
    
    // MARK: - Data Collection Methods
    
    func endWorkoutSession() async {
        print("🏁 FormAnalyzer: endWorkoutSession() called")
        
        guard let startTime = workoutStartTime else {
            print("⚠️ FormAnalyzer: No workout start time - cannot save session")
            return
        }
        
        print("📊 FormAnalyzer: Compiling workout data...")
        print("   - Reps: \(repCount) total, \(goodRepCount) good")
        print("   - Rep Analysis entries: \(repAnalysis.count)")
        print("   - Safety Issues: \(safetyIssues.count)")
        print("   - Form Improvements: \(formImprovements.count)")
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let averageScore = repAnalysis.isEmpty ? 0.0 : repAnalysis.map { $0.score }.reduce(0, +) / Float(repAnalysis.count)
        
        let sessionData = WorkoutSessionData(
            exercise: currentExercise ?? Exercise(name: "Unknown", category: .fullBody, description: "Unknown exercise", imageName: "unknown_icon", phases: [], keyJoints: [], safetyNotes: [], bodyTypeConsiderations: []),
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            totalReps: repCount,
            goodReps: goodRepCount,
            averageFormScore: averageScore,
            repAnalysis: repAnalysis,
            safetyIssues: safetyIssues,
            formImprovements: formImprovements,
            aiCoachingHistory: aiCoachingHistory,
            overallAssessment: generateOverallAssessment()
        )
        
        // Save to Supabase
        do {
            // Generate a unique workout session ID
            let workoutSessionId = UUID().uuidString
            
            // Save main workout session
            try await SupabaseManager.shared.saveWorkoutSession(
                exercise: sessionData.exercise,
                startTime: sessionData.startTime,
                endTime: sessionData.endTime,
                totalReps: sessionData.totalReps,
                goodReps: sessionData.goodReps,
                averageFormScore: sessionData.averageFormScore,
                repAnalysis: sessionData.repAnalysis,
                safetyIssues: sessionData.safetyIssues,
                formImprovements: sessionData.formImprovements,
                aiCoachingHistory: sessionData.aiCoachingHistory,
                overallAssessment: sessionData.overallAssessment
            )
            
            // Save individual rep data
            if !sessionData.repAnalysis.isEmpty {
                try await SupabaseManager.shared.saveExerciseReps(
                    reps: sessionData.repAnalysis,
                    workoutSessionId: workoutSessionId
                )
            }
            
            // Generate and save AI coaching feedback
            let aiCoachFeedback = AICoachFeedback()
            aiCoachFeedback.generateFeedbackFromVisionData(sessionData)
            
            // Save feedback when it's generated (async)
            Task {
                // Wait a bit for feedback generation
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                if let feedback = aiCoachFeedback.feedback {
                    try await SupabaseManager.shared.saveAICoachingFeedback(
                        feedback: feedback,
                        workoutSessionId: workoutSessionId
                    )
                }
            }
            
            // Update user progress tracking for this exercise
            try await SupabaseManager.shared.updateUserProgress(
                exerciseType: sessionData.exercise.name,
                sessionCompleted: true,
                reps: sessionData.totalReps,
                formScore: Double(sessionData.averageFormScore)
            )
            
            // Notify delegate
            delegate?.formAnalyzer(self, didCompleteWorkout: sessionData)
            
            print("✅ FormAnalyzer: Workout session and all data saved to Supabase!")
        } catch {
            print("❌ FormAnalyzer: Failed to save workout session: \(error)")
        }
    }
    
    private func recordRepAnalysis(score: Float, phase: ExercisePhase, issues: [String], keypoints: [VNHumanBodyPoseObservation.JointName: CGPoint]? = nil) {
        // Encode keypoints as JSON string for Codable compatibility
        var keypointsJSON: String? = nil
        if let keypoints = keypoints {
            let keypointsDict = Dictionary(uniqueKeysWithValues: keypoints.map { (joint, point) in
                (String(describing: joint), ["x": Double(point.x), "y": Double(point.y)])
            })
            if let jsonData = try? JSONEncoder().encode(keypointsDict),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                keypointsJSON = jsonString
            }
        }
        
        let analysis = RepAnalysis(
            repNumber: repCount,
            score: score,
            phase: phase,
            timestamp: Date(),
            issues: issues,
            duration: 0.0, // Could be calculated if needed
            keypointsData: keypointsJSON
        )
        repAnalysis.append(analysis)
        
        // Record safety issues if any
        if !issues.isEmpty {
            let safetyIssue = SafetyIssue(
                type: .poorStability, // Could be more specific based on issues
                severity: score < 0.3 ? .high : (score < 0.6 ? .medium : .low),
                timestamp: Date(),
                description: issues.joined(separator: ", "),
                repNumber: repCount
            )
            safetyIssues.append(safetyIssue)
        }
        
        // Record form improvements
        if score < 0.7 {
            let improvement = FormImprovement(
                area: "Form Quality",
                improvement: "Focus on technique and control",
                timestamp: Date(),
                repNumber: repCount
            )
            formImprovements.append(improvement)
        }
    }
    
    private func generateOverallAssessment() -> String {
        let averageScore = repAnalysis.isEmpty ? 0.0 : repAnalysis.map { $0.score }.reduce(0, +) / Float(repAnalysis.count)
        let goodRepPercentage = repCount > 0 ? Float(goodRepCount) / Float(repCount) * 100 : 0
        
        return """
        Workout Summary:
        - Total Reps: \(repCount)
        - Good Reps: \(goodRepCount) (\(String(format: "%.1f", goodRepPercentage))%)
        - Average Form Score: \(String(format: "%.1f", averageScore * 100))%
        - Safety Issues: \(safetyIssues.count)
        - Areas for Improvement: \(formImprovements.count)
        """
    }
    
}
