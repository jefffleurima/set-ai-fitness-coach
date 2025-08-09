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
    
    init(arView: ARView) {
        self.arView = arView
        super.init()
        setupARKit()
    }
    
    private func setupARKit() {
        guard let arView = arView else { return }
        
        // Check if body tracking is supported
        guard ARBodyTrackingConfiguration.isSupported else {
            print("❌ BodyMeshRenderer: Body tracking not supported on this device")
            // Add a test mesh for devices without body tracking
            addTestMesh()
            return
        }
        
        print("✅ BodyMeshRenderer: Body tracking is supported")
        
        // Don't configure ARKit session here - let MirrorViewController handle it
        // Just set up the render options
        arView.renderOptions = [.disablePersonOcclusion, .disableMotionBlur]
        
        print("✅ BodyMeshRenderer: Render options configured")
        
        // Add a test mesh to verify ARKit is working
        addTestMesh()
    }
    
    private func setupWorldTracking() {
        guard let arView = arView else { return }
        
        print("🔧 BodyMeshRenderer: Setting up world tracking for testing")
        
        // Use world tracking configuration (works on simulator)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        arView.session.run(configuration)
        arView.session.delegate = self
        
        print("✅ BodyMeshRenderer: World tracking set up")
        
        // Add a test mesh to verify ARKit is working
        addTestMesh()
    }
    
    private func addTestMesh() {
        guard let arView = arView else { return }
        
        print("🎯 BodyMeshRenderer: Adding test mesh")
        
        // Create a simple red sphere that should always be visible
        let sphereMesh = MeshResource.generateSphere(radius: 0.1)
        var material = UnlitMaterial()
        material.color = .init(tint: .systemRed.withAlphaComponent(0.9))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.9))
        
        let testEntity = ModelEntity(mesh: sphereMesh, materials: [material])
        
        // Position it in front of the camera
        let testAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1))
        testAnchor.addChild(testEntity)
        
        arView.scene.addAnchor(testAnchor)
        
        print("✅ BodyMeshRenderer: Test mesh added - you should see a red sphere")
    }
    
    // Called from MirrorViewController with Vision framework data
    func updateMeshWithVisionData(_ observation: VNHumanBodyPose3DObservation, formAnalysis: FormAnalyzer.FormAnalysis) {
        self.currentFormAnalysis = formAnalysis
        updateMeshColors()
    }
    
    private func updateMeshColors() {
        guard let meshEntity = meshEntity,
              let formAnalysis = currentFormAnalysis else { return }
        
        // Create heat map material based on form analysis
        let material = createHeatMapMaterial(formAnalysis: formAnalysis)
        meshEntity.model?.materials = [material]
    }
    
    private func createHeatMapMaterial(formAnalysis: FormAnalyzer.FormAnalysis) -> UnlitMaterial {
        var material = UnlitMaterial()
        
        // Create gradient texture based on form score
        let score = Double(formAnalysis.score) / 100.0
        let color = getHeatMapColor(score: score)
        
        material.color = .init(tint: color)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.8)) // More visible
        
        return material
    }
    
    private func getHeatMapColor(score: Double) -> UIColor {
        switch score {
        case 0.8...1.0:
            return UIColor.systemGreen.withAlphaComponent(0.9)
        case 0.6..<0.8:
            return UIColor.systemYellow.withAlphaComponent(0.9)
        case 0.4..<0.6:
            return UIColor.systemOrange.withAlphaComponent(0.9)
        default:
            return UIColor.systemRed.withAlphaComponent(0.9)
        }
    }
    
    func clearVisualization() {
        meshEntity?.removeFromParent()
        meshEntity = nil
        anchorEntity?.removeFromParent()
        anchorEntity = nil
    }
}

// MARK: - ARSessionDelegate
extension BodyMeshRenderer: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("🔍 BodyMeshRenderer: ARSession didAdd anchors: \(anchors.count)")
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                print("✅ BodyMeshRenderer: Body anchor detected!")
                self.bodyAnchor = bodyAnchor
                createBodyMeshEntity(for: bodyAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                self.bodyAnchor = bodyAnchor
                updateBodyMesh(for: bodyAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARBodyAnchor {
                print("❌ BodyMeshRenderer: Body anchor removed")
                clearVisualization()
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Check if we have a body anchor but no mesh entity
        if bodyAnchor != nil && meshEntity == nil {
            print("🔄 BodyMeshRenderer: Found body anchor but no mesh, creating mesh...")
            createBodyMeshEntity(for: bodyAnchor!)
        }
    }
}

// MARK: - Body Mesh Creation
extension BodyMeshRenderer {
    private func createBodyMeshEntity(for bodyAnchor: ARBodyAnchor) {
        guard let arView = arView else { return }
        
        print("🎯 BodyMeshRenderer: Creating body mesh entity")
        
        // Create a simple, visible body mesh
        let meshResource = createSimpleBodyMesh(from: bodyAnchor.skeleton)
        
        // Create initial material - make it very visible
        var material = UnlitMaterial()
        material.color = .init(tint: .systemGreen.withAlphaComponent(0.9))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.9))
        
        // Create the mesh entity
        let meshEntity = ModelEntity(mesh: meshResource, materials: [material])
        
        // Create anchor entity that follows the body
        let anchorEntity = AnchorEntity(world: bodyAnchor.transform)
        anchorEntity.addChild(meshEntity)
        
        // Add to AR scene
        arView.scene.addAnchor(anchorEntity)
        
        // Store references for updates
        self.meshEntity = meshEntity
        self.anchorEntity = anchorEntity
        
        print("✅ BodyMeshRenderer: Body mesh entity created and added to scene")
    }
    
    private func updateBodyMesh(for bodyAnchor: ARBodyAnchor) {
        guard let anchorEntity = anchorEntity else { return }
        
        // Update the anchor entity's transform to follow the body
        let transform = Transform(matrix: bodyAnchor.transform)
        anchorEntity.transform = transform
    }
    
    private func createSimpleBodyMesh(from skeleton: ARSkeleton3D) -> MeshResource {
        print("🎯 BodyMeshRenderer: Creating simple body mesh")
        
        // Create a simple, visible body suit using key joints
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        
        // Get key joint positions
        let jointNames = skeleton.definition.jointNames
        var jointPositions: [SIMD3<Float>] = []
        
        for (index, _) in jointNames.enumerated() {
            let transform = skeleton.jointModelTransforms[index]
            let position = SIMD3<Float>(transform[3][0], transform[3][1], transform[3][2])
            jointPositions.append(position)
        }
        
        print("🎯 BodyMeshRenderer: Found \(jointPositions.count) joints")
        
        // Create a simple body suit if we have enough joints
        if jointPositions.count >= 4 {
            // Use key joints for a simple body shape
            let spine = jointPositions[0] // Root/spine
            let _ = jointPositions[1] // Left shoulder (unused)
            let _ = jointPositions[2] // Right shoulder (unused)
            let leftHip = jointPositions[3] // Left hip
            
            // Create a simple body suit
            let suitThickness: Float = 0.05 // Thicker for visibility
            
            // Create cylindrical torso
            let segments = 8
            let heightSegments = 4
            
            for h in 0...heightSegments {
                let heightRatio = Float(h) / Float(heightSegments)
                let currentHeight = spine.y + (leftHip.y - spine.y) * heightRatio
                
                for s in 0..<segments {
                    let angle = Float(s) * 2.0 * Float.pi / Float(segments)
                    let x = spine.x + cos(angle) * suitThickness // Use spine.x for horizontal movement
                    let z = spine.z + sin(angle) * suitThickness
                    let y = currentHeight
                    
                    vertices.append(SIMD3<Float>(x, y, z))
                }
            }
            
            // Create simple indices
            indices = createSimpleIndices(vertexCount: vertices.count)
            
            print("🎯 BodyMeshRenderer: Created \(vertices.count) vertices and \(indices.count) indices")
        } else {
            // Fallback to a simple box if not enough joints
            print("⚠️ BodyMeshRenderer: Not enough joints, using fallback mesh")
            return createFallbackBodyMesh()
        }
        
        // Create mesh descriptor
        var descriptor = MeshDescriptor(name: "simpleBodySuitMesh")
        descriptor.positions = MeshBuffer(vertices)
        descriptor.primitives = .triangles(indices)
        
        do {
            let meshResource = try MeshResource.generate(from: [descriptor])
            print("✅ BodyMeshRenderer: Successfully created mesh resource")
            return meshResource
        } catch {
            print("❌ BodyMeshRenderer: Failed to create mesh resource: \(error)")
            return createFallbackBodyMesh()
        }
    }
    
    private func createSimpleIndices(vertexCount: Int) -> [UInt32] {
        var indices: [UInt32] = []
        
        // Create simple triangles for the mesh
        for i in stride(from: 0, to: vertexCount - 2, by: 2) {
            indices.append(UInt32(i))
            indices.append(UInt32(i + 1))
            indices.append(UInt32(i + 2))
            
            indices.append(UInt32(i + 1))
            indices.append(UInt32(i + 3))
            indices.append(UInt32(i + 2))
        }
        
        return indices
    }
    
    private func createFallbackBodyMesh() -> MeshResource {
        print("🎯 BodyMeshRenderer: Creating fallback body mesh")
        
        // Create a simple, visible body-shaped mesh
        let vertices: [SIMD3<Float>] = [
            // Torso
            SIMD3<Float>(-0.2, 0.8, 0.0),   // Top left
            SIMD3<Float>(0.2, 0.8, 0.0),    // Top right
            SIMD3<Float>(0.2, -0.8, 0.0),   // Bottom right
            SIMD3<Float>(-0.2, -0.8, 0.0),  // Bottom left
            SIMD3<Float>(-0.2, 0.8, 0.1),   // Top left back
            SIMD3<Float>(0.2, 0.8, 0.1),    // Top right back
            SIMD3<Float>(0.2, -0.8, 0.1),   // Bottom right back
            SIMD3<Float>(-0.2, -0.8, 0.1),  // Bottom left back
        ]
        
        let indices: [UInt32] = [
            // Front face
            0, 1, 2, 0, 2, 3,
            // Back face
            4, 6, 5, 4, 7, 6,
            // Left face
            0, 3, 7, 0, 7, 4,
            // Right face
            1, 5, 6, 1, 6, 2,
            // Top face
            0, 4, 5, 0, 5, 1,
            // Bottom face
            3, 2, 6, 3, 6, 7
        ]
        
        var descriptor = MeshDescriptor(name: "fallbackBodyMesh")
        descriptor.positions = MeshBuffer(vertices)
        descriptor.primitives = .triangles(indices)
        
        do {
            let meshResource = try MeshResource.generate(from: [descriptor])
            print("✅ BodyMeshRenderer: Successfully created fallback mesh")
            return meshResource
        } catch {
            print("❌ BodyMeshRenderer: Failed to create fallback mesh: \(error)")
            return .generateBox(size: 0.3) // Large visible box
        }
    }
    
    private func distance(_ point1: SIMD3<Float>, _ point2: SIMD3<Float>) -> Float {
        let diff = point2 - point1
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
} 