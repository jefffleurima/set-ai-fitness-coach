import UIKit
import AVFoundation
import Vision

/// MirrorViewController for displaying camera feed with 2D skeleton overlay
/// Uses Vision framework for simple, reliable 2D body tracking
class MirrorViewController: UIViewController {
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var skeletonOverlayView: SkeletonOverlayView?
    private var formAnalyzer: FormAnalyzer?
    
    // UI Elements
    private var exerciseLabel: UILabel?
    private var formScoreLabel: UILabel?
    private var repCountLabel: UILabel?
    private var feedbackLabel: UILabel?
    
    var currentExercise: String = "squats"
    var useFrontCamera: Bool = true
    
    // Form tracking data
    private var currentFormScore: Int = 60
    private var currentRepCount: Int = 0
    private var currentFeedback: String = "Form needs improvement, focus on technique"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupSkeletonOverlay()
        setupUI() // Setup UI last so it appears on top
        setupFormAnalyzer()
        setupGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        
        // Exercise label (top center) - elegant styling
        exerciseLabel = createExerciseLabel(text: currentExercise.capitalized)
        guard let exerciseLabel = exerciseLabel else { return }
        view.addSubview(exerciseLabel)
        
        // Form score label (top left)
        formScoreLabel = createBadgeLabel(text: "\(currentFormScore)%")
        guard let formScoreLabel = formScoreLabel else { return }
        view.addSubview(formScoreLabel)
        
        // Rep count label (top right)
        repCountLabel = createBadgeLabel(text: "\(currentRepCount)")
        guard let repCountLabel = repCountLabel else { return }
        view.addSubview(repCountLabel)
        
        // Feedback label (bottom)
        feedbackLabel = createFeedbackLabel(text: currentFeedback)
        guard let feedbackLabel = feedbackLabel else { return }
        view.addSubview(feedbackLabel)
        
        // Setup constraints
        setupUIConstraints()
        
        // Bring UI elements to the front
        bringUIElementsToFront()
    }
    
    private func createBadgeLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }
    
    private func createExerciseLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }
    
    private func createFeedbackLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }
    
    
    private func setupUIConstraints() {
        guard let exerciseLabel = exerciseLabel,
              let formScoreLabel = formScoreLabel,
              let repCountLabel = repCountLabel,
              let feedbackLabel = feedbackLabel else { return }
        
        NSLayoutConstraint.activate([
            // Exercise name label - TOP center, compact, elegant
            exerciseLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            exerciseLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exerciseLabel.widthAnchor.constraint(equalToConstant: 120), // Compact width
            exerciseLabel.heightAnchor.constraint(equalToConstant: 32), // Compact height
            
            // Form score label - LEFT side, top
            formScoreLabel.topAnchor.constraint(equalTo: exerciseLabel.bottomAnchor, constant: 15),
            formScoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), // Left side
            formScoreLabel.widthAnchor.constraint(equalToConstant: 60), // Smaller width
            formScoreLabel.heightAnchor.constraint(equalToConstant: 30), // Smaller height
            
            // Rep label - RIGHT side, top
            repCountLabel.topAnchor.constraint(equalTo: exerciseLabel.bottomAnchor, constant: 15),
            repCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), // Right side
            repCountLabel.widthAnchor.constraint(equalToConstant: 60), // Smaller width
            repCountLabel.heightAnchor.constraint(equalToConstant: 30),
            
            // Feedback label - bottom center
            feedbackLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            feedbackLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            feedbackLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            feedbackLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
    }
    
    private func bringUIElementsToFront() {
        // Bring all UI elements to the front
        if let exerciseLabel = exerciseLabel {
            view.bringSubviewToFront(exerciseLabel)
        }
        if let formScoreLabel = formScoreLabel {
            view.bringSubviewToFront(formScoreLabel)
        }
        if let repCountLabel = repCountLabel {
            view.bringSubviewToFront(repCountLabel)
        }
        if let feedbackLabel = feedbackLabel {
            view.bringSubviewToFront(feedbackLabel)
        }
    }
    
    // MARK: - Gesture Setup
    
    private func setupGestures() {
        // Add swipe down gesture to end set and return to exercise view
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown(_:)))
        swipeDownGesture.direction = .down
        swipeDownGesture.numberOfTouchesRequired = 1
        view.addGestureRecognizer(swipeDownGesture)
        
        // Ensure gesture recognizer works with all UI elements
        view.isUserInteractionEnabled = true
    }
    
    @objc private func handleSwipeDown(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else { return }
        
        // End the set and return to exercise view
        endSetAndReturnToExercise()
    }
    
    private func endSetAndReturnToExercise() {
        // Stop camera
        stopCamera()
        
        // Dismiss the current view controller
        DispatchQueue.main.async { [weak self] in
            if let presentingViewController = self?.presentingViewController {
                presentingViewController.dismiss(animated: true, completion: {
                    print("✅ Set ended - returned to ExerciseView")
                })
            } else {
                // If no presenting view controller, try to pop if in navigation controller
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.sessionPreset = .high
        
        // Setup camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                   for: .video, 
                                                   position: useFrontCamera ? .front : .back) else {
            print("❌ MirrorViewController: Camera not available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // Setup video output
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            
            // Setup preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = view.bounds
            
            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }
            
        } catch {
            print("❌ MirrorViewController: Error setting up camera: \(error)")
        }
    }
    
    private func startCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    // MARK: - Skeleton Overlay Setup
    
    private func setupSkeletonOverlay() {
        skeletonOverlayView = SkeletonOverlayView()
        guard let skeletonOverlayView = skeletonOverlayView else { return }
        
        skeletonOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skeletonOverlayView)
        
        NSLayoutConstraint.activate([
            skeletonOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            skeletonOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skeletonOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            skeletonOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupFormAnalyzer() {
        formAnalyzer = FormAnalyzer()
        formAnalyzer?.delegate = self
        
        // Set the current exercise for form analysis
        let exercise = Exercise(
            name: currentExercise,
            category: .legs,
            description: "Form analysis for \(currentExercise)",
            imageName: "\(currentExercise.lowercased())_icon",
            phases: [],
            keyJoints: [],
            safetyNotes: [],
            bodyTypeConsiderations: []
        )
        formAnalyzer?.setExercise(exercise)
        
        print("✅ FormAnalyzer setup for exercise: \(currentExercise)")
    }
    
    // MARK: - Layout
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        
        // Ensure UI elements stay on top after layout changes
        bringUIElementsToFront()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MirrorViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Create Vision request for body pose
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            if let error = error {
                print("❌ Vision request error: \(error)")
            return
        }
        
            guard let observations = request.results as? [VNHumanBodyPoseObservation] else { return }
        
        DispatchQueue.main.async {
                self?.processPoseObservations(observations, pixelBuffer: pixelBuffer)
            }
        }
        
        // Perform the request
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("❌ Vision request failed: \(error)")
        }
    }
    
    private func processPoseObservations(_ observations: [VNHumanBodyPoseObservation], pixelBuffer: CVPixelBuffer) {
        guard let observation = observations.first else {
            skeletonOverlayView?.clearSkeleton()
            print("🔍 No pose observations detected")
            return
        }
        
        print("🔍 Pose detected with \(observations.count) observations")
        
        // Update skeleton overlay
        skeletonOverlayView?.updateSkeleton(observation: observation, pixelBuffer: pixelBuffer)
        
        // Update skeleton with current form data
        skeletonOverlayView?.updateFormData(score: currentFormScore, feedback: currentFeedback)
        
        // Analyze form using Vision 2D analysis
        if let formAnalyzer = formAnalyzer {
            let exercise = Exercise(
                name: currentExercise,
                category: .legs,
                description: "Form analysis for \(currentExercise)",
                imageName: "\(currentExercise.lowercased())_icon",
                phases: [],
                keyJoints: [],
                safetyNotes: [],
                bodyTypeConsiderations: []
            )
            let _ = formAnalyzer.analyzeVisionForm(observation: observation, exercise: exercise)
            print("📊 Analyzing pose for \(currentExercise)")
        }
    }
}

// MARK: - FormAnalyzerDelegate

extension MirrorViewController: FormAnalyzerDelegate {
    
    func formAnalyzer(_ analyzer: FormAnalyzer, didUpdateFormScore score: Int) {
        // Handle form score updates - score represents how close to perfect (0-100)
        currentFormScore = max(0, min(100, score)) // Ensure score is between 0-100
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.formScoreLabel?.text = "\(self.currentFormScore)%"
        }
        print("📊 Form Score: \(score)")
    }
    
    func formAnalyzer(_ analyzer: FormAnalyzer, didUpdateRepCount count: Int) {
        // Handle rep counting - only count good reps (form score >= 70)
        currentRepCount = max(0, count) // Ensure rep count is non-negative
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.repCountLabel?.text = "\(self.currentRepCount)"
        }
        print("🔢 Reps: \(count)")
    }
    
    func formAnalyzer(_ analyzer: FormAnalyzer, didProvideFeedback feedback: String) {
        // Display AI feedback in the caption - handles warnings, tips, and all AI speech
        currentFeedback = feedback
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.feedbackLabel?.text = feedback
        }
        print("📝 Form Feedback: \(feedback)")
    }
}
