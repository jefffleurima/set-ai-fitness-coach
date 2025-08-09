import UIKit
import AVFoundation
import Vision
import ARKit
import RealityKit

class MirrorViewController: UIViewController {
    private var arView: ARView?
    private var bodyMeshRenderer: BodyMeshRenderer?
    
    // Vision framework for pose detection
    private var poseRequest: VNDetectHumanBodyPose3DRequest?
    
    // Form analysis
    private var formAnalyzer = FormAnalyzer()
    private var currentExercise: Exercise?
    private var repCount = 0
    private var lastRepTime: Date?
    private var repHistory: [Float] = []
    
    // UI Elements
    private var exerciseNameLabel: UILabel?
    private var scoreLabel: UILabel?
    private var repLabel: UILabel?
    private var feedbackLabel: UILabel?
    
    // SwiftUI dismiss closure
    var dismissClosure: (() -> Void)?
    
    // Initialization state
    private var isARKitSetup = false
    
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
        
        // Configure ARKit for body tracking (uses back camera by default)
        let configuration = ARBodyTrackingConfiguration()
        configuration.automaticImageScaleEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        
        print("🔧 MirrorViewController: Starting ARKit session")
        arView.session.run(configuration)
        arView.session.delegate = self
        arView.renderOptions = [.disablePersonOcclusion, .disableMotionBlur]
        
        print("✅ MirrorViewController: ARKit session started")
    }
    
    private func setupVision() {
        // Configure Vision framework for 3D pose detection
        poseRequest = VNDetectHumanBodyPose3DRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNHumanBodyPose3DObservation],
                  let observation = observations.first else { return }
            
            DispatchQueue.main.async {
                self.processVisionPoseObservation(observation)
            }
        }
    }
    
    private func setupFormAnalyzer() {
        formAnalyzer = FormAnalyzer()
        if let exercise = currentExercise {
            formAnalyzer.setExercise(exercise)
        }
    }
    
    private func processVisionPoseObservation(_ observation: VNHumanBodyPose3DObservation) {
        // Analyze form using Vision framework data
        let formAnalysis = formAnalyzer.analyzeForm(observation)
        
        // Update UI
        updateUI(with: formAnalysis)
        
        // Update ARKit mesh with Vision data
        bodyMeshRenderer?.updateMeshWithVisionData(observation, formAnalysis: formAnalysis)
        
        // Track reps
        trackReps(formAnalysis: formAnalysis)
    }
    
    private func updateUI(with formAnalysis: FormAnalyzer.FormAnalysis) {
        scoreLabel?.text = "\(Int(formAnalysis.score))%"
        repLabel?.text = "\(formAnalysis.repCount)"
        feedbackLabel?.text = formAnalysis.feedback
    }
    
    private func trackReps(formAnalysis: FormAnalyzer.FormAnalysis) {
        if formAnalysis.isGoodRep {
            repCount = formAnalysis.repCount
            lastRepTime = Date()
            repHistory.append(formAnalysis.score)
            
            // Keep only last 10 reps
            if repHistory.count > 10 {
                repHistory.removeFirst()
            }
        }
    }
    
    func setExercise(_ exercise: Exercise) {
        currentExercise = exercise
        formAnalyzer.setExercise(exercise)
        
        // Update exercise name label
        DispatchQueue.main.async {
            self.exerciseNameLabel?.text = exercise.name
        }
        
        print("✅ MirrorViewController: Exercise set to \(exercise.name)")
    }
    
    private func showUnsupportedDeviceAlert() {
        let alert = UIAlertController(
            title: "Device Not Supported",
            message: "Body tracking requires iPhone X or newer with A12 Bionic chip.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func setupGestureRecognizers() {
        // Add swipe down gesture to exit camera screen
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDownGesture.direction = .down
        view.addGestureRecognizer(swipeDownGesture)
        
        print("✅ MirrorViewController: Swipe down gesture added - swipe down to exit")
    }
    
    @objc private func handleSwipeDown() {
        print("🔄 MirrorViewController: Swipe down detected - dismissing camera screen")
        
        // Stop ARKit session immediately
        arView?.session.pause()
        
        // Use SwiftUI dismiss for smooth transition
        if let dismissClosure = dismissClosure {
            dismissClosure()
        } else {
            // Fallback to standard dismiss
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func createUIOverlays() {
        // Add swipe down indicator at the top
        let swipeIndicator = UIView()
        swipeIndicator.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        swipeIndicator.layer.cornerRadius = 2
        swipeIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(swipeIndicator)
        
        // Position swipe indicator at top center
        NSLayoutConstraint.activate([
            swipeIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            swipeIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            swipeIndicator.widthAnchor.constraint(equalToConstant: 40),
            swipeIndicator.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        // Exercise Name Label - TOP center, compact, elegant
        exerciseNameLabel = UILabel()
        exerciseNameLabel?.text = "Exercise"
        exerciseNameLabel?.textColor = .white
        exerciseNameLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold) // Smaller, more elegant font
        exerciseNameLabel?.textAlignment = .center
        exerciseNameLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.5) // Lighter background
        exerciseNameLabel?.layer.cornerRadius = 12 // Rounded corners
        exerciseNameLabel?.layer.masksToBounds = true
        exerciseNameLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        // Form Score Label - LEFT side, small, dark transparent
        scoreLabel = UILabel()
        scoreLabel?.text = "0%"
        scoreLabel?.textColor = .white
        scoreLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold) // Smaller font
        scoreLabel?.textAlignment = .center
        scoreLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.6) // Darker transparent
        scoreLabel?.layer.cornerRadius = 6 // Smaller radius
        scoreLabel?.layer.masksToBounds = true
        scoreLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        // Rep Label - RIGHT side, small, dark transparent
        repLabel = UILabel()
        repLabel?.text = "0"
        repLabel?.textColor = .white
        repLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold) // Smaller font
        repLabel?.textAlignment = .center
        repLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.6) // Darker transparent
        repLabel?.layer.cornerRadius = 6 // Smaller radius
        repLabel?.layer.masksToBounds = true
        repLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        // Feedback Label - bottom center
        feedbackLabel = UILabel()
        feedbackLabel?.text = ""
        feedbackLabel?.textColor = .white
        feedbackLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        feedbackLabel?.textAlignment = .center
        feedbackLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        feedbackLabel?.layer.cornerRadius = 8
        feedbackLabel?.layer.masksToBounds = true
        feedbackLabel?.translatesAutoresizingMaskIntoConstraints = false
        feedbackLabel?.numberOfLines = 0
        
        // Add to view
        if let exerciseNameLabel = exerciseNameLabel {
            view.addSubview(exerciseNameLabel)
        }
        if let scoreLabel = scoreLabel {
            view.addSubview(scoreLabel)
        }
        if let repLabel = repLabel {
            view.addSubview(repLabel)
        }
        if let feedbackLabel = feedbackLabel {
            view.addSubview(feedbackLabel)
        }
        
        // Setup constraints
        setupConstraints()
    }
    
    private func setupConstraints() {
        guard let exerciseNameLabel = exerciseNameLabel,
              let scoreLabel = scoreLabel,
              let repLabel = repLabel,
              let feedbackLabel = feedbackLabel else { return }
        
        NSLayoutConstraint.activate([
            // Exercise name label - TOP center, compact
            exerciseNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            exerciseNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exerciseNameLabel.widthAnchor.constraint(equalToConstant: 120), // Compact width
            exerciseNameLabel.heightAnchor.constraint(equalToConstant: 32), // Compact height
            
            // Form score label - LEFT side, top
            scoreLabel.topAnchor.constraint(equalTo: exerciseNameLabel.bottomAnchor, constant: 15),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), // Left side
            scoreLabel.widthAnchor.constraint(equalToConstant: 60), // Smaller width
            scoreLabel.heightAnchor.constraint(equalToConstant: 30), // Smaller height
            
            // Rep label - RIGHT side, top
            repLabel.topAnchor.constraint(equalTo: exerciseNameLabel.bottomAnchor, constant: 15),
            repLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), // Right side
            repLabel.widthAnchor.constraint(equalToConstant: 60), // Smaller width
            repLabel.heightAnchor.constraint(equalToConstant: 30),
            
            // Feedback label - bottom center
            feedbackLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            feedbackLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            feedbackLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            feedbackLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
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
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ MirrorViewController: ARKit session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("✅ MirrorViewController: ARKit session interruption ended")
    }
} 