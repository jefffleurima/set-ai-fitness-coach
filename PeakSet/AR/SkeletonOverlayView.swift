import UIKit
import Vision

/// SkeletonOverlayView for displaying 2D skeleton overlay
/// Uses Vision framework for simple, reliable 2D body tracking
class SkeletonOverlayView: UIView {
    
    private var currentObservation: VNHumanBodyPoseObservation?
    private var currentPixelBuffer: CVPixelBuffer?
    private var formScore: Int = 60
    private var feedback: String = ""
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        isOpaque = false
    }
    
    func updateSkeleton(observation: VNHumanBodyPoseObservation, pixelBuffer: CVPixelBuffer) {
        self.currentObservation = observation
        self.currentPixelBuffer = pixelBuffer
        setNeedsDisplay()
    }
    
    func updateFormData(score: Int, feedback: String) {
        self.formScore = score
        self.feedback = feedback
        setNeedsDisplay()
    }
    
    func clearSkeleton() {
        currentObservation = nil
        currentPixelBuffer = nil
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let observation = currentObservation else {
            // Clear the context if no observation
            if let context = UIGraphicsGetCurrentContext() {
                context.clear(rect)
            }
            return
        }
        
        // Clear the context
        context.clear(rect)
        
        // Draw the skeleton
        drawSkeleton(context: context, observation: observation)
    }
    
    // MARK: - Skeleton Drawing
    
    private func drawSkeleton(context: CGContext, observation: VNHumanBodyPoseObservation) {
        // Set line properties
        context.setLineWidth(3.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Get joint positions
        let jointPositions = getJointPositions(from: observation)
        
        // Draw skeleton connections
        drawSkeletonConnections(context: context, points: jointPositions)
        
        // Draw joint nodes
        drawJointNodes(context: context, points: jointPositions)
    }
    
    private func getJointPositions(from observation: VNHumanBodyPoseObservation) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var positions: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        
        // Get all available joints
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .root,
            .leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle,
            .rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle
        ]
        
        for jointName in jointNames {
            do {
                let point = try observation.recognizedPoint(jointName)
                if point.confidence > 0.1 { // Lower threshold for better tracking
                    let screenPoint = convertToScreenCoordinates(point: point)
                    positions[jointName] = screenPoint
                    
                    // Debug: Print joint positions for troubleshooting
                    if jointName == .nose || jointName == .leftHip || jointName == .rightHip {
                        print("🔍 \(jointName): confidence=\(String(format: "%.2f", point.confidence)), normalized=(\(String(format: "%.2f", point.location.x)), \(String(format: "%.2f", point.location.y))), screen=(\(String(format: "%.0f", screenPoint.x)), \(String(format: "%.0f", screenPoint.y)))")
                    }
                }
            } catch {
                // Joint not available
                continue
            }
        }
        
        return positions
    }
    
    private func convertToScreenCoordinates(point: VNRecognizedPoint) -> CGPoint {
        // Convert normalized coordinates to screen coordinates
        // For front camera, rotate 90 degrees clockwise and flip Y to make skeleton upright
        let x = point.location.y * bounds.width // Use Y as X (rotate 90 degrees)
        let y = point.location.x * bounds.height // Use X as Y (rotate 90 degrees, no flip)
        return CGPoint(x: x, y: y)
    }
    
    private func drawSkeletonConnections(context: CGContext, points: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        // Define skeleton connections
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            // Head and neck
            (.nose, .neck),
            (.neck, .root),
            
            // Left arm
            (.neck, .leftShoulder),
            (.leftShoulder, .leftElbow),
            (.leftElbow, .leftWrist),
            
            // Right arm
            (.neck, .rightShoulder),
            (.rightShoulder, .rightElbow),
            (.rightElbow, .rightWrist),
            
            // Left leg
            (.root, .leftHip),
            (.leftHip, .leftKnee),
            (.leftKnee, .leftAnkle),
            
            // Right leg
            (.root, .rightHip),
            (.rightHip, .rightKnee),
            (.rightKnee, .rightAnkle),
            
            // Torso
            (.leftHip, .rightHip)
        ]
        
        // Draw connections
        for (startJoint, endJoint) in connections {
            if let startPoint = points[startJoint], let endPoint = points[endJoint] {
                context.setStrokeColor(UIColor.systemBlue.cgColor)
                context.move(to: startPoint)
                context.addLine(to: endPoint)
                context.strokePath()
            }
        }
    }
    
    private func drawJointNodes(context: CGContext, points: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        for (jointName, point) in points {
            let radius = getJointRadius(for: jointName)
            let color = getJointColor(for: jointName)
            
            context.setFillColor(color.cgColor)
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.0)
            
            let rect = CGRect(x: point.x - radius, y: point.y - radius, 
                            width: radius * 2, height: radius * 2)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        }
    }
    
    // MARK: - Visual Styling
    
    private func getJointRadius(for jointName: VNHumanBodyPoseObservation.JointName) -> CGFloat {
        switch jointName {
        case .nose, .neck:
            return 8.0
        case .root:
            return 7.0
        case .leftShoulder, .rightShoulder, .leftHip, .rightHip:
            return 6.0
        case .leftElbow, .rightElbow, .leftKnee, .rightKnee:
            return 5.0
        case .leftWrist, .rightWrist, .leftAnkle, .rightAnkle:
            return 4.0
        default:
            return 4.0
        }
    }
    
    private func getJointColor(for jointName: VNHumanBodyPoseObservation.JointName) -> UIColor {
        // Determine color based on form feedback
        let baseColor: UIColor
        
        if feedback.lowercased().contains("danger") || feedback.lowercased().contains("warning") || feedback.lowercased().contains("stop") {
            baseColor = .systemRed
        } else if feedback.lowercased().contains("tip") || feedback.lowercased().contains("improve") || feedback.lowercased().contains("try") {
            baseColor = .systemOrange
        } else if feedback.lowercased().contains("good") || feedback.lowercased().contains("great") || feedback.lowercased().contains("excellent") {
            baseColor = .systemGreen
        } else {
            // Default colors based on form score
            if formScore >= 90 {
                baseColor = .systemGreen
            } else if formScore >= 70 {
                baseColor = .systemOrange
            } else {
                baseColor = .systemRed
            }
        }
        
        // Apply slight variations for different joint groups
        switch jointName {
        case .nose, .neck:
            return baseColor
        case .root:
            return baseColor.withAlphaComponent(0.9)
        case .leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle:
            return baseColor.withAlphaComponent(0.8)
        case .rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle:
            return baseColor.withAlphaComponent(0.8)
        default:
            return baseColor.withAlphaComponent(0.7)
        }
    }
}
