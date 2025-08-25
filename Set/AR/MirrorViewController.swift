import UIKit
import ARKit
import RealityKit
import SwiftUI
import Vision

class MirrorViewController: UIViewController {
    private var arView: ARView?
    private var bodyMeshRenderer: BodyMeshRenderer?
    
    // Vision framework for pose detection
    private var poseRequest: VNDetectHumanBodyPose3DRequest?
    
    // Form analyzer
    private var formAnalyzer: FormAnalyzer?
    
    // UI overlays
    private var voiceAssistantOverlay: UIHostingController<VoiceAssistantOverlay>?
    private var exerciseInfoLabel: UILabel?
    private var formFeedbackLabel: UILabel?
    
    // Gesture recognizers
    private var swipeDownGesture: UISwipeGestureRecognizer?
    
    // State tracking
    private var isARKitSetup = false
    private var currentExercise: String = "squats"
    
    // Dismiss closure for SwiftUI integration
    var dismissClosure: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔧 MirrorViewController: viewDidLoad called")
        setupUI()
        setupVision()
        setupFormAnalyzer()
        setupGestureRecognizers()
        // Don't setup ARKit here - wait for viewDidAppear
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔧 MirrorViewController: viewDidAppear called")
        
        // Setup ARKit only when view is fully visible
        if !isARKitSetup {
            setupARKit()
            isARKitSetup = true
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Create ARView for body tracking
        arView = ARView(frame: view.bounds)
        arView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView?.backgroundColor = .black
        
        // Ensure ARView is ready before adding to hierarchy
        guard let arView = arView else { return }
        view.addSubview(arView)
        
        print("✅ MirrorViewController: ARView created and added to view hierarchy")
        
        // Create UI overlays
        createUIOverlays()
    }
    
    private func setupARKit() {
        guard let arView = arView else {
            print("❌ MirrorViewController: ARView not available, skipping ARKit setup")
            return
        }
        
        // Ensure ARView is properly added to view hierarchy
        guard arView.superview != nil else {
            print("❌ MirrorViewController: ARView not in view hierarchy, skipping ARKit setup")
            return
        }
        
        print("🔧 MirrorViewController: Setting up ARKit")
        
        // Initialize body mesh renderer
        bodyMeshRenderer = BodyMeshRenderer(arView: arView)
        
        // Check if body tracking is supported
        guard ARBodyTrackingConfiguration.isSupported else {
            print("❌ MirrorViewController: Body tracking not supported on this device")
            showUnsupportedDeviceAlert()
            return
        }
        
        print("✅ MirrorViewController: Body tracking is supported")
        
        // Configure AR session
        let configuration = ARBodyTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isLightEstimationEnabled = true
        
        // Set the session delegate
        arView.session.delegate = self
        
        // Start the AR session
        print("🔧 MirrorViewController: Starting ARKit session")
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("✅ MirrorViewController: ARKit session started")
    }
    
    private func setupVision() {
        poseRequest = VNDetectHumanBodyPose3DRequest { [weak self] request, error in
            if let error = error {
                print("❌ MirrorViewController: Vision pose detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNHumanBodyPose3DObservation],
                  let observation = observations.first else {
                return
            }
            
            // Process pose data for form analysis
            self?.processPoseObservation(observation)
        }
    }
    
    private func setupFormAnalyzer() {
        formAnalyzer = FormAnalyzer()
        // Set initial exercise
        let exercise = Exercise(
            name: currentExercise,
            category: .legs,
            description: "Exercise",
            imageName: "exercise_image",
            formRequirements: [:],
            keyJoints: [],
            squatVariation: nil
        )
        formAnalyzer?.setExercise(exercise)
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPose3DObservation) {
        guard let analyzer = formAnalyzer else { return }
        
        // Analyze form using the analyzer
        let formAnalysis = analyzer.analyzeForm(observation)
        
        // Update UI with form analysis results
        DispatchQueue.main.async {
            self.updateFormFeedback(formAnalysis)
        }
    }
    
    private func updateFormFeedback(_ analysis: FormAnalyzer.FormAnalysis) {
        formFeedbackLabel?.text = "Form Score: \(Int(analysis.score * 100))%"
        
        // Update color based on score
        if analysis.score >= 0.8 {
            formFeedbackLabel?.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.7)
        } else if analysis.score >= 0.6 {
            formFeedbackLabel?.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.7)
        } else {
            formFeedbackLabel?.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
        }
    }
    
    private func setupGestureRecognizers() {
        // Add swipe down gesture to exit
        swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDownGesture?.direction = .down
        view.addGestureRecognizer(swipeDownGesture!)
        print("✅ MirrorViewController: Swipe down gesture added - swipe down to exit")
    }
    
    private func createUIOverlays() {
        // Create voice assistant overlay using SwiftUI hosting controller
        let voiceOverlay = VoiceAssistantOverlay()
        voiceAssistantOverlay = UIHostingController(rootView: voiceOverlay)
        
        if let voiceOverlayController = voiceAssistantOverlay {
            addChild(voiceOverlayController)
            view.addSubview(voiceOverlayController.view)
            voiceOverlayController.view.frame = view.bounds
            voiceOverlayController.didMove(toParent: self)
        }
        
        // Create exercise info label
        exerciseInfoLabel = UILabel()
        exerciseInfoLabel?.text = "Exercise: \(currentExercise.capitalized)"
        exerciseInfoLabel?.textColor = .white
        exerciseInfoLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        exerciseInfoLabel?.textAlignment = .center
        exerciseInfoLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        exerciseInfoLabel?.layer.cornerRadius = 8
        exerciseInfoLabel?.layer.masksToBounds = true
        exerciseInfoLabel?.padding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        if let exerciseLabel = exerciseInfoLabel {
            view.addSubview(exerciseLabel)
            exerciseLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                exerciseLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                exerciseLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
        }
        
        // Create form feedback label
        formFeedbackLabel = UILabel()
        formFeedbackLabel?.text = "Ready to analyze form..."
        formFeedbackLabel?.textColor = .white
        formFeedbackLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        formFeedbackLabel?.textAlignment = .center
        formFeedbackLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        formFeedbackLabel?.layer.cornerRadius = 8
        formFeedbackLabel?.layer.masksToBounds = true
        formFeedbackLabel?.padding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        if let feedbackLabel = formFeedbackLabel {
            view.addSubview(feedbackLabel)
            feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                feedbackLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                feedbackLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                feedbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
                feedbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
            ])
        }
    }
    
    private func showUnsupportedDeviceAlert() {
        let alert = UIAlertController(
            title: "Device Not Supported",
            message: "Body tracking is not supported on this device. Please use a device with A12 Bionic chip or later.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    @objc private func handleSwipeDown() {
        print("🔄 MirrorViewController: Swipe down detected - dismissing camera screen")
        dismiss(animated: true)
    }
    
    func setExercise(_ exercise: String) {
        currentExercise = exercise
        let exerciseObj = Exercise(
            name: exercise,
            category: .legs,
            description: "Exercise",
            imageName: "exercise_image",
            formRequirements: [:],
            keyJoints: [],
            squatVariation: nil
        )
        formAnalyzer?.setExercise(exerciseObj)
        exerciseInfoLabel?.text = "Exercise: \(exercise.capitalized)"
        print("✅ MirrorViewController: Exercise set to \(exercise)")
    }
}

// MARK: - ARSessionDelegate
extension MirrorViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Process camera frame with Vision framework
        let pixelBuffer = frame.capturedImage
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        do {
            try handler.perform([poseRequest].compactMap { $0 })
        } catch {
            print("❌ MirrorViewController: Failed to perform Vision request: \(error)")
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("🔍 MirrorViewController: ARSession didAdd anchors: \(anchors.count)")
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                print("✅ MirrorViewController: Body anchor detected!")
                // Pass body anchor to mesh renderer
                bodyMeshRenderer?.session(session, didAdd: [bodyAnchor])
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                print("🔄 MirrorViewController: Body anchor updated")
                // Pass body anchor updates to mesh renderer
                bodyMeshRenderer?.session(session, didUpdate: [bodyAnchor])
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                print("❌ MirrorViewController: Body anchor removed")
                // Pass body anchor removal to mesh renderer
                bodyMeshRenderer?.session(session, didRemove: [bodyAnchor])
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ MirrorViewController: ARKit session failed: \(error)")
    }
}

// MARK: - UILabel Extension for Padding
extension UILabel {
    var padding: UIEdgeInsets {
        get {
            return UIEdgeInsets.zero
        }
        set {
            let paddingView = UIView()
            paddingView.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(paddingView)
            
            NSLayoutConstraint.activate([
                paddingView.topAnchor.constraint(equalTo: self.topAnchor, constant: newValue.top),
                paddingView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -newValue.bottom),
                paddingView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: newValue.left),
                paddingView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -newValue.right)
            ])
        }
    }
} 