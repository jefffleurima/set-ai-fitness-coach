import UIKit
import ARKit
import RealityKit
import Vision
import simd

class BodyMeshRenderer: NSObject {
    private weak var arView: ARView?
    private var bodyAnchor: ARBodyAnchor?
    private var meshEntity: ModelEntity?
    private var currentFormAnalysis: FormAnalyzer.FormAnalysis?
    private var anchorEntity: AnchorEntity?
    private var jointEntities: [String: ModelEntity] = [:]
    
    // Configuration
    private let meshOpacity: Float = 0.85
    private let jointSphereRadius: Float = 0.03
    private let boneCylinderRadius: Float = 0.015
    
    init(arView: ARView) {
        self.arView = arView
        super.init()
        setupARKit()
    }
    
    private func setupARKit() {
        guard let arView = arView else { return }
        
        guard ARBodyTrackingConfiguration.isSupported else {
            print("❌ Body tracking not supported")
            addTestMesh()
            return
        }
        
        arView.renderOptions = [.disablePersonOcclusion, .disableMotionBlur]
        addTestMesh()
    }
    
    // MARK: - Mesh Visualization
    
    private func createBodyMeshEntity(for bodyAnchor: ARBodyAnchor) {
        guard let arView = arView else { return }
        
        // Clear previous entities
        clearVisualization()
        
        // Create anchor that follows the body
        let anchorEntity = AnchorEntity(world: bodyAnchor.transform)
        
        // Create skeleton visualization
        createSkeletonVisualization(from: bodyAnchor.skeleton, parent: anchorEntity)
        
        // Add to scene
        arView.scene.addAnchor(anchorEntity)
        
        self.anchorEntity = anchorEntity
    }
    
    private func createSkeletonVisualization(from skeleton: ARSkeleton3D, parent: AnchorEntity) {
        let definition = skeleton.definition
        
        // Create joints
        for jointName in definition.jointNames {
            guard let jointIndex = definition.index(for: jointName) else { continue }
            
            let jointTransform = skeleton.jointModelTransforms[jointIndex]
            let jointPosition = SIMD3<Float>(jointTransform.columns.3.x,
                                           jointTransform.columns.3.y,
                                           jointTransform.columns.3.z)
            
            let jointEntity = createJointEntity(at: jointPosition, name: jointName)
            parent.addChild(jointEntity)
            jointEntities[jointName] = jointEntity
        }
        
        // Create bones between joints
        for (jointName, parentName) in definition.parentIndices {
            guard let jointEntity = jointEntities[jointName],
                  let parentEntity = jointEntities[parentName] else { continue }
            
            let boneEntity = createBoneEntity(between: jointEntity, and: parentEntity)
            parent.addChild(boneEntity)
        }
    }
    
    private func createJointEntity(at position: SIMD3<Float>, name: String) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: jointSphereRadius)
        var material = SimpleMaterial()
        material.color = .init(tint: .systemBlue.withAlphaComponent(0.8))
        material.metallic = .float(0.2)
        material.roughness = .float(0.5)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        entity.name = "joint_\(name)"
        return entity
    }
    
    private func createBoneEntity(between joint1: ModelEntity, and joint2: ModelEntity) -> ModelEntity {
        let direction = joint2.position - joint1.position
        let length = length(direction)
        let midpoint = (joint1.position + joint2.position) / 2
        
        // Create cylinder for bone
        let mesh = MeshResource.generateCylinder(radius: boneCylinderRadius,
                                               height: length,
                                               splitFaces: false)
        
        var material = SimpleMaterial()
        material.color = .init(tint: .systemGreen.withAlphaComponent(0.7))
        material.metallic = .float(0.1)
        material.roughness = .float(0.4)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = midpoint
        
        // Orient the cylinder to point from joint1 to joint2
        let upVector: SIMD3<Float> = [0, 1, 0]
        let axis = normalize(cross(upVector, direction))
        let angle = acos(dot(upVector, normalize(direction)))
        entity.orientation = simd_quatf(angle: angle, axis: axis)
        
        return entity
    }
    
    private func updateSkeletonVisualization(with skeleton: ARSkeleton3D) {
        let definition = skeleton.definition
        
        for jointName in definition.jointNames {
            guard let jointIndex = definition.index(for: jointName),
                  let jointEntity = jointEntities[jointName] else { continue }
            
            let jointTransform = skeleton.jointModelTransforms[jointIndex]
            jointEntity.position = SIMD3<Float>(jointTransform.columns.3.x,
                                             jointTransform.columns.3.y,
                                             jointTransform.columns.3.z)
        }
    }
    
    // MARK: - Form Analysis Visualization
    
    func updateMeshWithVisionData(_ observation: VNHumanBodyPose3DObservation, formAnalysis: FormAnalyzer.FormAnalysis) {
        self.currentFormAnalysis = formAnalysis
        updateJointColors()
    }
    
    private func updateJointColors() {
        guard let formAnalysis = currentFormAnalysis else { return }
        
        for (jointName, jointEntity) in jointEntities {
            if let jointScore = formAnalysis.jointScores[jointName] {
                let color = getHeatMapColor(score: jointScore)
                if var material = jointEntity.model?.materials.first as? SimpleMaterial {
                    material.color = .init(tint: color)
                    jointEntity.model?.materials = [material]
                }
            }
        }
    }
    
    private func getHeatMapColor(score: Float) -> UIColor {
        let normalizedScore = score / 100.0
        
        switch normalizedScore {
        case 0.8...1.0: return .systemGreen.withAlphaComponent(0.9)
        case 0.6..<0.8: return .systemYellow.withAlphaComponent(0.9)
        case 0.4..<0.6: return .systemOrange.withAlphaComponent(0.9)
        default: return .systemRed.withAlphaComponent(0.9)
        }
    }
    
    // MARK: - Utility Methods
    
    private func addTestMesh() {
        guard let arView = arView else { return }
        
        let sphereMesh = MeshResource.generateSphere(radius: 0.1)
        var material = SimpleMaterial()
        material.color = .init(tint: .systemRed.withAlphaComponent(0.9))
        
        let testEntity = ModelEntity(mesh: sphereMesh, materials: [material])
        let testAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1))
        testAnchor.addChild(testEntity)
        arView.scene.addAnchor(testAnchor)
    }
    
    func clearVisualization() {
        meshEntity?.removeFromParent()
        meshEntity = nil
        anchorEntity?.removeFromParent()
        anchorEntity = nil
        jointEntities.removeAll()
    }
}

// MARK: - ARSessionDelegate
extension BodyMeshRenderer: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                self.bodyAnchor = bodyAnchor
                createBodyMeshEntity(for: bodyAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                self.bodyAnchor = bodyAnchor
                
                if anchorEntity == nil {
                    createBodyMeshEntity(for: bodyAnchor)
                } else {
                    anchorEntity?.transform = Transform(matrix: bodyAnchor.transform)
                    updateSkeletonVisualization(with: bodyAnchor.skeleton)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARBodyAnchor {
                clearVisualization()
            }
        }
    }
}