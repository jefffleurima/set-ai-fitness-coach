import Foundation
import Vision
import UIKit

class FormAnalyzer {
    
    enum ExerciseType: String {
        case squats = "squats"
        case deadlifts = "deadlifts"
        case pushups = "push-ups"
        case lunges = "lunges"
        case plank = "plank"
        case general = "general"
    }
    
    struct FormAnalysis {
        let score: Float
        let feedback: String
        let repCount: Int
        let isGoodRep: Bool
    }
    
    enum ExercisePhase {
        case preparation
        case eccentric
        case concentric
        case rest
    }
    
    private var currentExercise: Exercise?
    private var repCount = 0
    private var lastRepTime: Date?
    private var repHistory: [FormAnalysis] = []
    
    func setExercise(_ exercise: Exercise) {
        self.currentExercise = exercise
        self.repCount = 0
        self.repHistory.removeAll()
    }
    
    func analyzeForm(_ observation: VNHumanBodyPose3DObservation) -> FormAnalysis {
        guard let exercise = currentExercise else {
            return FormAnalysis(score: 0, feedback: "No exercise selected", repCount: 0, isGoodRep: false)
        }
        
        let formScore = calculateFormScore(observation, exercise: exercise)
        let feedback = generateFeedback(observation, exercise: exercise, score: formScore)
        let (repCount, isGoodRep) = trackReps(observation, exercise: exercise, score: formScore)
        
        let analysis = FormAnalysis(
            score: formScore,
            feedback: feedback,
            repCount: repCount,
            isGoodRep: isGoodRep
        )
        
        repHistory.append(analysis)
        if repHistory.count > 10 {
            repHistory.removeFirst()
        }
        
        return analysis
    }
    
    private func calculateFormScore(_ observation: VNHumanBodyPose3DObservation, exercise: Exercise) -> Float {
        var totalScore: Float = 0
        var validChecks = 0
        
        // Analyze different aspects based on exercise type
        switch exercise.name.lowercased() {
        case "squat":
            totalScore += analyzeSquatForm(observation)
            validChecks += 1
        case "pushup":
            totalScore += analyzePushupForm(observation)
            validChecks += 1
        case "plank":
            totalScore += analyzePlankForm(observation)
            validChecks += 1
        case "lunge":
            totalScore += analyzeLungeForm(observation)
            validChecks += 1
        default:
            // General analysis for unknown exercises
            totalScore += analyzeGeneralForm(observation)
            validChecks += 1
        }
        
        // Add general posture analysis
        totalScore += analyzePosture(observation)
        validChecks += 1
        
        return validChecks > 0 ? totalScore / Float(validChecks) : 0
    }
    
    private func analyzeSquatForm(_ observation: VNHumanBodyPose3DObservation) -> Float {
        var score: Float = 0
        
        do {
            // Get 3D joint positions
            let leftHip = try observation.recognizedPoint(.leftHip)
            let leftKnee = try observation.recognizedPoint(.leftKnee)
            let leftAnkle = try observation.recognizedPoint(.leftAnkle)
            let _ = try observation.recognizedPoint(.rightHip)
            let _ = try observation.recognizedPoint(.rightKnee)
            let _ = try observation.recognizedPoint(.rightAnkle)
            let spine = try observation.recognizedPoint(.spine)
            let _ = try observation.recognizedPoint(.root)
            
            // Calculate 3D angles for more accurate analysis
            let kneeAngle = calculate3DAngle(leftHip.position, leftKnee.position, leftAnkle.position)
            let hipAngle = calculate3DAngle(spine.position, leftHip.position, leftKnee.position)
            
            // Score based on proper squat angles
            if kneeAngle > 80 && kneeAngle < 120 {
                score += 30 // Good knee angle
            } else if kneeAngle > 60 && kneeAngle < 140 {
                score += 20 // Acceptable knee angle
            }
            
            if hipAngle > 70 && hipAngle < 110 {
                score += 30 // Good hip angle
            } else if hipAngle > 50 && hipAngle < 130 {
                score += 20 // Acceptable hip angle
            }
            
            // Check for proper depth
            let hipHeight = leftHip.position[3][1]
            let kneeHeight = leftKnee.position[3][1]
            let depthRatio = (hipHeight - kneeHeight) / 0.5 // Normalize to typical body height
            
            if depthRatio > 0.1 {
                score += 20 // Good depth
            } else if depthRatio > 0.05 {
                score += 10 // Acceptable depth
            }
            
            // Check for knee alignment
            let kneeAlignment = checkKneeAlignment(leftKnee.position, leftAnkle.position)
            if kneeAlignment {
                score += 20 // Good knee alignment
            }
            
        } catch {
            print("❌ Could not analyze squat form: \(error)")
        }
        
        return min(100, score)
    }
    
    private func analyzePushupForm(_ observation: VNHumanBodyPose3DObservation) -> Float {
        var score: Float = 0
        
        do {
            let leftShoulder = try observation.recognizedPoint(.leftShoulder)
            let leftElbow = try observation.recognizedPoint(.leftElbow)
            let leftWrist = try observation.recognizedPoint(.leftWrist)
            let rightShoulder = try observation.recognizedPoint(.rightShoulder)
            let rightElbow = try observation.recognizedPoint(.rightElbow)
            let rightWrist = try observation.recognizedPoint(.rightWrist)
            let spine = try observation.recognizedPoint(.spine)
            
            // Calculate arm angles
            let leftArmAngle = calculate3DAngle(leftShoulder.position, leftElbow.position, leftWrist.position)
            let rightArmAngle = calculate3DAngle(rightShoulder.position, rightElbow.position, rightWrist.position)
            
            // Score based on proper pushup form
            if leftArmAngle > 80 && leftArmAngle < 100 {
                score += 40 // Good arm angle
            } else if leftArmAngle > 70 && leftArmAngle < 110 {
                score += 30 // Acceptable arm angle
            }
            
            if rightArmAngle > 80 && rightArmAngle < 100 {
                score += 40 // Good arm angle
            } else if rightArmAngle > 70 && rightArmAngle < 110 {
                score += 30 // Acceptable arm angle
            }
            
            // Check for straight body line
            let bodyAlignment = checkBodyAlignment(spine.position, leftShoulder.position, leftWrist.position)
            if bodyAlignment {
                score += 20 // Good body alignment
            }
            
        } catch {
            print("❌ Could not analyze pushup form: \(error)")
        }
        
        return min(100, score)
    }
    
    private func analyzePlankForm(_ observation: VNHumanBodyPose3DObservation) -> Float {
        var score: Float = 0
        
        do {
            let leftShoulder = try observation.recognizedPoint(.leftShoulder)
            let leftElbow = try observation.recognizedPoint(.leftElbow)
            let leftHip = try observation.recognizedPoint(.leftHip)
            let leftKnee = try observation.recognizedPoint(.leftKnee)
            let spine = try observation.recognizedPoint(.spine)
            
            // Check for straight body line
            let bodyAlignment = checkBodyAlignment(spine.position, leftShoulder.position, leftHip.position)
            if bodyAlignment {
                score += 50 // Good body alignment
            } else {
                score += 30 // Acceptable alignment
            }
            
            // Check for proper elbow angle
            let elbowAngle = calculate3DAngle(leftShoulder.position, leftElbow.position, leftHip.position)
            if elbowAngle > 85 && elbowAngle < 95 {
                score += 30 // Good elbow angle
            } else if elbowAngle > 80 && elbowAngle < 100 {
                score += 20 // Acceptable elbow angle
            }
            
            // Check for hip stability
            let hipStability = checkHipStability(leftHip.position, leftKnee.position)
            if hipStability {
                score += 20 // Good hip stability
            }
            
        } catch {
            print("❌ Could not analyze plank form: \(error)")
        }
        
        return min(100, score)
    }
    
    private func analyzeLungeForm(_ observation: VNHumanBodyPose3DObservation) -> Float {
        var score: Float = 0
        
        do {
            let leftHip = try observation.recognizedPoint(.leftHip)
            let leftKnee = try observation.recognizedPoint(.leftKnee)
            let leftAnkle = try observation.recognizedPoint(.leftAnkle)
            let rightHip = try observation.recognizedPoint(.rightHip)
            let rightKnee = try observation.recognizedPoint(.rightKnee)
            let rightAnkle = try observation.recognizedPoint(.rightAnkle)
            
            // Calculate knee angles
            let leftKneeAngle = calculate3DAngle(leftHip.position, leftKnee.position, leftAnkle.position)
            let rightKneeAngle = calculate3DAngle(rightHip.position, rightKnee.position, rightAnkle.position)
            
            // Score based on proper lunge form
            if leftKneeAngle > 85 && leftKneeAngle < 95 {
                score += 40 // Good front knee angle
            } else if leftKneeAngle > 80 && leftKneeAngle < 100 {
                score += 30 // Acceptable front knee angle
            }
            
            if rightKneeAngle > 85 && rightKneeAngle < 95 {
                score += 40 // Good back knee angle
            } else if rightKneeAngle > 80 && rightKneeAngle < 100 {
                score += 30 // Acceptable back knee angle
            }
            
            // Check for proper depth
            let depth = calculateLungeDepth(leftKnee.position, rightKnee.position)
            if depth > 0.3 {
                score += 20 // Good depth
            } else if depth > 0.2 {
                score += 10 // Acceptable depth
            }
            
        } catch {
            print("❌ Could not analyze lunge form: \(error)")
        }
        
        return min(100, score)
    }
    
    private func analyzePosture(_ observation: VNHumanBodyPose3DObservation) -> Float {
        var score: Float = 0
        
        do {
            let spine = try observation.recognizedPoint(.spine)
            let root = try observation.recognizedPoint(.root)
            let leftShoulder = try observation.recognizedPoint(.leftShoulder)
            let rightShoulder = try observation.recognizedPoint(.rightShoulder)
            
            // Check for straight spine alignment
            let spineAlignment = checkSpineAlignment(leftShoulder.position, spine.position, root.position)
            if spineAlignment {
                score += 50 // Good spine alignment
            } else {
                score += 30 // Acceptable alignment
            }
            
            // Check for shoulder position
            let shoulderPosition = checkShoulderPosition(leftShoulder.position, rightShoulder.position, spine.position)
            if shoulderPosition {
                score += 30 // Good shoulder position
            } else {
                score += 20 // Acceptable shoulder position
            }
            
        } catch {
            print("❌ Could not analyze posture: \(error)")
        }
        
        return min(100, score)
    }
    
    private func analyzeGeneralForm(_ observation: VNHumanBodyPose3DObservation) -> Float {
        var score: Float = 0
        
        do {
            let spine = try observation.recognizedPoint(.spine)
            let leftShoulder = try observation.recognizedPoint(.leftShoulder)
            let rightShoulder = try observation.recognizedPoint(.rightShoulder)
            let leftHip = try observation.recognizedPoint(.leftHip)
            let rightHip = try observation.recognizedPoint(.rightHip)
            
            // Check for general posture
            let spineAlignment = checkSpineAlignment(leftShoulder.position, spine.position, leftHip.position)
            if spineAlignment {
                score += 50 // Good spine alignment
            } else {
                score += 30 // Acceptable alignment
            }
            
            // Check for shoulder balance
            let shoulderBalance = checkShoulderPosition(leftShoulder.position, rightShoulder.position, spine.position)
            if shoulderBalance {
                score += 30 // Good shoulder balance
            } else {
                score += 20 // Acceptable shoulder balance
            }
            
            // Check for hip balance
            let hipBalance = checkHipBalance(leftHip.position, rightHip.position)
            if hipBalance {
                score += 20 // Good hip balance
            }
            
        } catch {
            print("❌ Could not analyze general form: \(error)")
        }
        
        return min(100, score)
    }
    
    // Helper functions for 3D calculations
    private func calculate3DAngle(_ point1: simd_float4x4, _ point2: simd_float4x4, _ point3: simd_float4x4) -> Float {
        let v1 = simd_float3(point1[3][0] - point2[3][0], point1[3][1] - point2[3][1], point1[3][2] - point2[3][2])
        let v2 = simd_float3(point3[3][0] - point2[3][0], point3[3][1] - point2[3][1], point3[3][2] - point2[3][2])
        
        let dot = simd_dot(v1, v2)
        let mag1 = simd_length(v1)
        let mag2 = simd_length(v2)
        
        let cosAngle = dot / (mag1 * mag2)
        let angle = acos(cosAngle) * 180 / Float.pi
        
        return angle
    }
    
    private func checkKneeAlignment(_ kneePos: simd_float4x4, _ anklePos: simd_float4x4) -> Bool {
        let kneeX = kneePos[3][0]
        let ankleX = anklePos[3][0]
        let alignment = abs(kneeX - ankleX) < 0.1 // 10cm tolerance
        return alignment
    }
    
    private func checkBodyAlignment(_ spinePos: simd_float4x4, _ shoulderPos: simd_float4x4, _ wristPos: simd_float4x4) -> Bool {
        let spineY = spinePos[3][1]
        let shoulderY = shoulderPos[3][1]
        let wristY = wristPos[3][1]
        
        let alignment = abs(spineY - shoulderY) < 0.05 && abs(shoulderY - wristY) < 0.05
        return alignment
    }
    
    private func checkHipStability(_ hipPos: simd_float4x4, _ kneePos: simd_float4x4) -> Bool {
        let hipY = hipPos[3][1]
        let kneeY = kneePos[3][1]
        let stability = abs(hipY - kneeY) < 0.1
        return stability
    }
    
    private func checkSpineAlignment(_ headPos: simd_float4x4, _ spinePos: simd_float4x4, _ rootPos: simd_float4x4) -> Bool {
        let headX = headPos[3][0]
        let spineX = spinePos[3][0]
        let rootX = rootPos[3][0]
        
        let alignment = abs(headX - spineX) < 0.05 && abs(spineX - rootX) < 0.05
        return alignment
    }
    
    private func checkShoulderPosition(_ leftShoulderPos: simd_float4x4, _ rightShoulderPos: simd_float4x4, _ spinePos: simd_float4x4) -> Bool {
        let leftShoulderY = leftShoulderPos[3][1]
        let rightShoulderY = rightShoulderPos[3][1]
        let spineY = spinePos[3][1]
        
        let position = abs(leftShoulderY - rightShoulderY) < 0.1 && abs(leftShoulderY - spineY) < 0.1
        return position
    }
    
    private func checkHipBalance(_ leftHipPos: simd_float4x4, _ rightHipPos: simd_float4x4) -> Bool {
        let leftHipY = leftHipPos[3][1]
        let rightHipY = rightHipPos[3][1]
        let balance = abs(leftHipY - rightHipY) < 0.1
        return balance
    }
    
    private func calculateLungeDepth(_ frontKneePos: simd_float4x4, _ backKneePos: simd_float4x4) -> Float {
        let frontX = frontKneePos[3][0]
        let backX = backKneePos[3][0]
        return abs(frontX - backX)
    }
    
    private func generateFeedback(_ observation: VNHumanBodyPose3DObservation, exercise: Exercise, score: Float) -> String {
        if score >= 85 {
            return "Excellent form! Keep it up!"
        } else if score >= 70 {
            return "Good form, minor adjustments needed"
        } else if score >= 50 {
            return "Form needs improvement, focus on technique"
        } else {
            return "Please check your form and try again"
        }
    }
    
    private func trackReps(_ observation: VNHumanBodyPose3DObservation, exercise: Exercise, score: Float) -> (Int, Bool) {
        let now = Date()
        let isGoodRep = score >= 70
        
        // Simple rep counting logic
        if isGoodRep && (lastRepTime == nil || now.timeIntervalSince(lastRepTime!) > 1.0) {
            repCount += 1
            lastRepTime = now
        }
        
        return (repCount, isGoodRep)
    }
} 