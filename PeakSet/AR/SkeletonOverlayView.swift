import UIKit
import Vision
import ARKit

/// SkeletonOverlayView for displaying 3D pose detection results
/// Uses VNHumanBodyPose3DObservation to get actual 3D coordinates
/// Based on Apple's Vision framework 3D pose detection API
class SkeletonOverlayView: UIView {
    
    private var observation: VNHumanBodyPose3DObservation?
    private var cameraTransform: simd_float4x4?
    
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
        isUserInteractionEnabled = false
    }
    
    func updateSkeleton(observation: VNHumanBodyPose3DObservation, cameraTransform: simd_float4x4) {
        self.observation = observation
        self.cameraTransform = cameraTransform
        
        // Debug: Print joint information organized by groups
        let jointPositions = get3DJointPositions(from: observation)
        print("🔍 SkeletonOverlayView: Detected \(jointPositions.count)/17 joints")
        print("🔍 Screen bounds: \(bounds)")
        
        // Check if we have enough joints for meaningful tracking
        if jointPositions.count < 5 {
            print("⚠️ Too few joints detected (\(jointPositions.count)), body may not be visible")
            setNeedsDisplay()
            return
        }
        
        // Group joints for better debugging
        let headJoints = jointPositions.filter { [.topHead, .centerHead].contains($0.key) }
        let torsoJoints = jointPositions.filter { [.centerShoulder, .leftShoulder, .rightShoulder, .spine, .root, .leftHip, .rightHip].contains($0.key) }
        let leftArmJoints = jointPositions.filter { [.leftElbow, .leftWrist].contains($0.key) }
        let rightArmJoints = jointPositions.filter { [.rightElbow, .rightWrist].contains($0.key) }
        let leftLegJoints = jointPositions.filter { [.leftKnee, .leftAnkle].contains($0.key) }
        let rightLegJoints = jointPositions.filter { [.rightKnee, .rightAnkle].contains($0.key) }
        
        print("  📍 Head Group: \(headJoints.count)/2 joints")
        print("  🫀 Torso Group: \(torsoJoints.count)/7 joints") 
        print("  🤚 Left Arm: \(leftArmJoints.count)/2 joints")
        print("  🤚 Right Arm: \(rightArmJoints.count)/2 joints")
        print("  🦵 Left Leg: \(leftLegJoints.count)/2 joints")
        print("  🦵 Right Leg: \(rightLegJoints.count)/2 joints")
        
        // Test coordinate conversion for debugging
        if let firstJoint = jointPositions.first {
            let testPoint = project3DPointToScreen(firstJoint.value)
            print("🔍 Test conversion: \(firstJoint.key) -> \(testPoint)")
        }
        
        setNeedsDisplay()
    }
    
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let observation = observation else { return }
        
        // Clear the context
        context.clear(rect)
        
        // Draw 3D skeleton
        drawSkeleton(context: context, observation: observation)
    }
    
    private func drawSkeleton(context: CGContext, observation: VNHumanBodyPose3DObservation) {
        // Set line properties for better visibility
        context.setLineWidth(4.0) // Increased line width for better visibility
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Get 3D coordinates for all available joints
        let jointPositions = get3DJointPositions(from: observation)
        
        // Convert 3D positions to screen coordinates
        let screenPoints = convert3DPointsToScreen(points: jointPositions)
        
        // Debug: Print screen coordinates to understand positioning
        print("🔍 Screen bounds: \(bounds)")
        for (jointName, screenPoint) in screenPoints {
            print("  📍 \(jointName): screen(\(screenPoint.x), \(screenPoint.y))")
        }
        
        // Draw skeleton connections first
        drawSkeletonConnections(context: context, points: screenPoints)
        
        // Then draw joint nodes on top
        drawJointNodes(context: context, points: screenPoints)
    }
    
    
    // MARK: - 3D Joint Position Extraction
    
    private func get3DJointPositions(from observation: VNHumanBodyPose3DObservation) -> [VNHumanBodyPose3DObservation.JointName: simd_float3] {
        var jointPositions: [VNHumanBodyPose3DObservation.JointName: simd_float3] = [:]
        
        // All 17 joint points detected by Apple's Vision framework 3D human body pose detection
        // Organized by anatomical groups for better understanding and maintenance
        let allJointNames: [VNHumanBodyPose3DObservation.JointName] = [
            // Head Group (2 joints)
            .topHead, .centerHead,
            
            // Torso Group (7 joints) - Core body structure
            .centerShoulder, .leftShoulder, .rightShoulder, .spine, .root, .leftHip, .rightHip,
            
            // Left Arm Group (2 joints)
            .leftElbow, .leftWrist,
            
            // Right Arm Group (2 joints)
            .rightElbow, .rightWrist,
            
            // Left Leg Group (2 joints)
            .leftKnee, .leftAnkle,
            
            // Right Leg Group (2 joints)
            .rightKnee, .rightAnkle
        ]
        
        do {
            // Use recognizedPoints(.all) which returns VNHumanBodyRecognizedPoint3D
            let recognizedPoints = try observation.recognizedPoints(.all)
            print("🔍 Found \(recognizedPoints.count) recognized points")
            
            for jointName in allJointNames {
                if let point = recognizedPoints[jointName] {
                    // According to Apple's documentation, VNHumanBodyRecognizedPoint3D
                    // has a .position property that returns a simd_float4x4 matrix
                    // This matrix contains the 3D position of the joint
                    let positionMatrix = point.position
                    
                    // Extract 3D coordinates from the position matrix
                    // The position is in the last column of the matrix (columns 0-2 for x, y, z)
                    let x: Float = positionMatrix.columns.3.x
                    let y: Float = positionMatrix.columns.3.y
                    let z: Float = positionMatrix.columns.3.z
                    
                    // Debug: Check if coordinates are reasonable
                    if abs(x) > 10 || abs(y) > 10 || abs(z) > 10 {
                        print("⚠️ Unusual coordinates for \(jointName): x=\(x), y=\(y), z=\(z)")
                    }
                    
                    // Debug: Print actual 3D coordinates to understand the coordinate system
                    print("🔍 Joint \(jointName): x=\(x), y=\(y), z=\(z)")
                    
                    jointPositions[jointName] = simd_float3(x, y, z)
                } else {
                    print("⚠️ Missing joint: \(jointName)")
                }
            }
        } catch {
            print("❌ Error getting recognized points: \(error)")
        }
        
        return jointPositions
    }
    
    
    // MARK: - 3D to Screen Coordinate Conversion
    
    private func convert3DPointsToScreen(points: [VNHumanBodyPose3DObservation.JointName: simd_float3]) -> [VNHumanBodyPose3DObservation.JointName: CGPoint] {
        var screenPoints: [VNHumanBodyPose3DObservation.JointName: CGPoint] = [:]
        
        // Calculate the center of mass for better positioning
        var centerOfMass = simd_float3(0, 0, 0)
        var validPointCount = 0
        
        for (_, position3D) in points {
            centerOfMass += position3D
            validPointCount += 1
        }
        
        if validPointCount > 0 {
            centerOfMass /= Float(validPointCount)
        }
        
        for (jointName, position3D) in points {
            // Project 3D coordinates directly to screen coordinates
            let screenPosition = project3DPointToScreen(position3D)
            screenPoints[jointName] = screenPosition
        }
        
        return screenPoints
    }
    
    private func applyCameraTransform(_ position: simd_float3) -> simd_float3 {
        guard let cameraTransform = cameraTransform else { return position }
        
        // Convert 3D point to homogeneous coordinates
        let homogeneousPoint = simd_float4(position.x, position.y, position.z, 1.0)
        
        // Apply camera transform
        let transformedPoint = cameraTransform * homogeneousPoint
        
        // Convert back to 3D coordinates
        return simd_float3(transformedPoint.x, transformedPoint.y, transformedPoint.z)
    }
    
    private func worldToScreen(_ worldPosition: simd_float3) -> CGPoint {
        // Simple projection: assume camera is at origin looking down -Z axis
        // In a real AR app, you'd use proper camera projection matrices
        
        let x = CGFloat(worldPosition.x)
        let y = CGFloat(worldPosition.y)
        
        // Convert to screen coordinates (center of screen is origin)
        let screenX = bounds.midX + x * bounds.width
        let screenY = bounds.midY + y * bounds.height // Don't flip Y axis - this was causing upside down
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    /// Project 3D coordinates to 2D screen coordinates
    private func project3DPointToScreen(_ point3D: simd_float3) -> CGPoint {
        let screenWidth = bounds.width
        let screenHeight = bounds.height
        
        // Debug: Print the 3D coordinates to understand the coordinate system
        print("🔍 Projecting 3D point: x=\(point3D.x), y=\(point3D.y), z=\(point3D.z)")
        
        // The Vision framework 3D coordinates are in a normalized coordinate system
        // where the center of the image is (0, 0, 0) and coordinates range roughly from -1 to 1
        // We need to map these to screen coordinates properly
        
        // Scale factor - based on the actual coordinate range from debug output
        // The coordinates range from approximately -0.3 to 0.3, so we need a larger scale
        let coordinateRange: CGFloat = 0.6 // Approximate range of coordinates (-0.3 to 0.3)
        let scale: CGFloat = min(screenWidth, screenHeight) / coordinateRange
        
        // Map 3D coordinates to screen coordinates
        // The coordinates are centered around 0, so we map them to screen center
        let x = screenWidth * 0.5 + CGFloat(point3D.x) * scale
        let y = screenHeight * 0.5 - CGFloat(point3D.y) * scale // Flip Y for correct orientation
        
        // Clamp to screen bounds to prevent joints from going off-screen
        let clampedX = max(0, min(screenWidth, x))
        let clampedY = max(0, min(screenHeight, y))
        
        let screenPoint = CGPoint(x: clampedX, y: clampedY)
        print("🔍 Screen point: x=\(screenPoint.x), y=\(screenPoint.y)")
        
        return screenPoint
    }
    
    /// Calculate 3D angle between two vectors
    private func calculate3DAngle(vector1: simd_float3, vector2: simd_float3) -> Float {
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
    
    /// Calculate length of a 3D vector
    private func length(_ vector: simd_float3) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
    
    // MARK: - Skeleton Drawing
    
    private func drawSkeletonConnections(context: CGContext, points: [VNHumanBodyPose3DObservation.JointName: CGPoint]) {
        // Define comprehensive skeleton connections based on Apple's 17-joint 3D human body pose detection
        // Organized by anatomical groups for maximum coverage and realistic bone structure
        let connections: [(VNHumanBodyPose3DObservation.JointName, VNHumanBodyPose3DObservation.JointName)] = [
            // Head Group connections
            (.topHead, .centerHead),
            (.centerHead, .centerShoulder),
            
            // Torso Group connections - Core body structure
            (.centerShoulder, .leftShoulder), (.centerShoulder, .rightShoulder),
            (.leftShoulder, .rightShoulder), // Shoulder line
            (.leftShoulder, .spine), (.rightShoulder, .spine),
            (.spine, .leftHip), (.spine, .rightHip),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), // Side torso
            (.leftHip, .rightHip), // Hip line
            (.leftHip, .root), (.rightHip, .root), // Root connections
            
            // Left Arm Group connections
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            
            // Right Arm Group connections
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            
            // Left Leg Group connections
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            
            // Right Leg Group connections
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
        ]
        
        // Draw each connection with realistic 3D bone appearance
        for (startJoint, endJoint) in connections {
            guard let startPoint = points[startJoint],
                  let endPoint = points[endJoint] else { continue }
            
            // Calculate bone length for dynamic sizing
            let boneLength = sqrt(pow(endPoint.x - startPoint.x, 2) + pow(endPoint.y - startPoint.y, 2))
            let dynamicLineWidth = max(3.0, min(8.0, boneLength * 0.02)) // Dynamic width based on bone length
            
            // Set line color based on joint confidence
            let startConfidence = getJointConfidence(startJoint)
            let endConfidence = getJointConfidence(endJoint)
            let avgConfidence = (startConfidence + endConfidence) / 2
            let color = getColorForConfidence(avgConfidence)
            
            // Draw bone shadow for 3D effect
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(dynamicLineWidth + 1)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: startPoint.x + 1, y: startPoint.y + 1))
            context.addLine(to: CGPoint(x: endPoint.x + 1, y: endPoint.y + 1))
            context.strokePath()
            
            // Draw main bone with gradient-like effect
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(dynamicLineWidth)
            context.setLineCap(.round)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
            
            // Draw highlight line for 3D depth
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(dynamicLineWidth * 0.4)
            context.setLineCap(.round)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
    }
    
    private func drawJointNodes(context: CGContext, points: [VNHumanBodyPose3DObservation.JointName: CGPoint]) {
        for (jointName, point) in points {
            let confidence = getJointConfidence(jointName)
            let color = getColorForConfidence(confidence)
            
            // Draw joint circle with different sizes based on joint importance
            let radius: CGFloat = getJointRadius(for: jointName) * 1.5 // Increased size for better visibility
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            
            // Create realistic 3D-like joint appearance like the hand example
            // Outer glow effect for depth
            let glowRadius = radius * 1.3
            let glowRect = CGRect(x: point.x - glowRadius, y: point.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
            context.setFillColor(color.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: glowRect)
            
            // Main joint circle with gradient-like effect
            context.setFillColor(color.cgColor)
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2.5) // Thicker border for more definition
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
            
            // Inner highlight circle for 3D depth (like hand example)
            let innerRadius = radius * 0.6
            let innerRect = CGRect(x: point.x - innerRadius, y: point.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2)
            context.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            context.fillEllipse(in: innerRect)
            
            // Center dot for maximum detail and realism
            let centerRadius = radius * 0.25
            let centerRect = CGRect(x: point.x - centerRadius, y: point.y - centerRadius, width: centerRadius * 2, height: centerRadius * 2)
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: centerRect)
            
            // Add subtle shadow for 3D effect
            let shadowRadius = radius * 0.9
            let shadowRect = CGRect(x: point.x - shadowRadius + 1, y: point.y - shadowRadius + 1, width: shadowRadius * 2, height: shadowRadius * 2)
            context.setFillColor(UIColor.black.withAlphaComponent(0.2).cgColor)
            context.fillEllipse(in: shadowRect)
        }
    }
    
    /// Get appropriate radius for different joint types based on anatomical importance
    /// Varied sizes like the hand example for more realistic 3D appearance
    private func getJointRadius(for jointName: VNHumanBodyPose3DObservation.JointName) -> CGFloat {
        switch jointName {
        // Head Group - Most prominent for tracking (like wrist in hand)
        case .topHead:
            return 12.0 // Largest - most visible point
        case .centerHead:
            return 10.0 // Large - head center
            
        // Torso Group - Core body structure (like palm base in hand)
        case .centerShoulder:
            return 11.0 // Very large - shoulder center
        case .spine:
            return 9.0 // Large - spine center
        case .root:
            return 8.0 // Medium-large - hip center
        case .leftShoulder, .rightShoulder:
            return 9.0 // Large - major shoulder joints
        case .leftHip, .rightHip:
            return 8.0 // Medium-large - major hip joints
            
        // Arm Groups - Limb joints (like finger joints in hand)
        case .leftElbow, .rightElbow:
            return 7.0 // Medium - arm joints
        case .leftWrist, .rightWrist:
            return 6.0 // Smaller - arm extremities
            
        // Leg Groups - Limb joints (like finger joints in hand)
        case .leftKnee, .rightKnee:
            return 7.0 // Medium - leg joints
        case .leftAnkle, .rightAnkle:
            return 6.0 // Smaller - leg extremities
            
        default:
            return 7.0 // Default size for any missed joints
        }
    }
    
    // MARK: - Utility Methods
    
    private func getJointConfidence(_ jointName: VNHumanBodyPose3DObservation.JointName) -> Float {
        do {
            // Use the recognizedPoints method which returns VNHumanBodyRecognizedPoint3D
            let recognizedPoints = try observation?.recognizedPoints(.all)
            if let points = recognizedPoints, let _ = points[jointName] {
                // VNHumanBodyRecognizedPoint3D doesn't have a .confidence property
                // For now, return a default confidence value
                // In a real implementation, you might calculate confidence based on other factors
                return 0.8 // Default high confidence
            }
        } catch {
            print("Error getting joint confidence: \(error)")
        }
        return 0.0
    }
    
    private func getColorForConfidence(_ confidence: Float) -> UIColor {
        if confidence > 0.8 {
            return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0) // Bright vibrant orange like hand example
        } else if confidence > 0.6 {
            return UIColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0) // Golden orange
        } else if confidence > 0.4 {
            return UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0) // Bright yellow
        } else if confidence > 0.2 {
            return UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) // Coral red
        } else {
            return UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) // Muted gray for very low confidence
        }
    }
    
}