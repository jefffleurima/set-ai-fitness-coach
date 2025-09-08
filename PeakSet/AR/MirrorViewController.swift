import UIKit
import AVFoundation
import SwiftUI
import Vision

class MirrorViewController: UIViewController {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    // Vision framework for pose detection
    private var poseRequest: VNDetectHumanBodyPose3DRequest?
    
    // Form analyzer
    private var formAnalyzer: FormAnalyzer?
    
    // UI overlays
    private var exerciseInfoLabel: UILabel?
    private var formFeedbackLabel: UILabel?
    private var formScoreLabel: UILabel?
    private var repCountLabel: UILabel?
    private var skeletonOverlayView: SkeletonOverlayView?
    
    // Gesture recognizers
    private var swipeDownGesture: UISwipeGestureRecognizer?
    
    // State tracking
    private var isCameraSetup = false
    private var isUsingFrontCamera = true  // Always use front camera for mirror view
    private var currentExercise: String = "squats"
    private var currentFormScore: Int = 0
    private var currentRepCount: Int = 0
    
    // Dismiss closure for SwiftUI integration
    var dismissClosure: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔧 MirrorViewController: viewDidLoad called")
        setupUI()
        setupVision()
        setupFormAnalyzer()
        setupGestureRecognizers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔧 MirrorViewController: viewDidAppear called")
        
        // Setup camera only when view is fully visible
        if !isCameraSetup {
            setupCamera()
            isCameraSetup = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update preview layer frame when view layout changes
        previewLayer?.frame = view.bounds
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Create preview layer for camera feed
        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        print("✅ MirrorViewController: Preview layer created and added to view hierarchy")
        
        // Create skeleton overlay
        skeletonOverlayView = SkeletonOverlayView(frame: view.bounds)
        skeletonOverlayView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let skeletonView = skeletonOverlayView {
            view.addSubview(skeletonView)
        }
        
        // Create UI overlays
        createUIOverlays()
    }
    
    private func setupCamera() {
        print("🔧 MirrorViewController: Setting up camera")
        
        // Check camera permissions first
        checkCameraPermissions { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    self?.showCameraPermissionAlert()
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.configureCameraSession()
            }
        }
    }
    
    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func configureCameraSession() {
        print("🔧 MirrorViewController: Starting camera configuration...")
        
        // Create capture session with optimal settings for 3D pose detection
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .hd1920x1080 // Higher resolution for better 3D detection
        
        guard let captureSession = captureSession else { 
            print("❌ MirrorViewController: Failed to create capture session")
            return 
        }
        
        // Get camera device (ALWAYS use front camera)
        let devicePosition: AVCaptureDevice.Position = .front
        guard let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition) else {
            print("❌ MirrorViewController: Front camera not available")
            showCameraErrorAlert()
            return
        }
        
        print("✅ MirrorViewController: Front camera device found")
        
        // Configure camera for optimal 3D pose detection
        do {
            try cameraDevice.lockForConfiguration()
            
            // Set optimal settings for pose detection
            if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                cameraDevice.focusMode = .continuousAutoFocus
            }
            if cameraDevice.isExposureModeSupported(.continuousAutoExposure) {
                cameraDevice.exposureMode = .continuousAutoExposure
            }
            if cameraDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                cameraDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Set optimal frame rate for pose detection
            if cameraDevice.isLockingFocusWithCustomLensPositionSupported {
                cameraDevice.setFocusModeLocked(lensPosition: 0.5, completionHandler: nil)
            }
            
            cameraDevice.unlockForConfiguration()
            
            let cameraInput = try AVCaptureDeviceInput(device: cameraDevice)
            if captureSession.canAddInput(cameraInput) {
                captureSession.addInput(cameraInput)
                print("✅ MirrorViewController: Camera input added to session")
            } else {
                print("❌ MirrorViewController: Cannot add camera input to session")
            }
        } catch {
            print("❌ MirrorViewController: Failed to create camera input: \(error)")
            showCameraErrorAlert()
            return
        }
        
        // Create video output with optimal settings for 3D pose detection
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        videoOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            print("✅ MirrorViewController: Video output added to session")
        } else {
            print("❌ MirrorViewController: Cannot add video output to session")
        }
        
        // Update preview layer
        previewLayer?.session = captureSession
        print("✅ MirrorViewController: Preview layer session updated")
        
        // Start capture session on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            print("🔧 MirrorViewController: Starting capture session on background queue...")
            captureSession.startRunning()
            
            DispatchQueue.main.async {
                if captureSession.isRunning {
                    print("✅ MirrorViewController: Camera session started successfully")
                    // Force a layout update to ensure preview layer is visible
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                } else {
                    print("❌ MirrorViewController: Camera session failed to start")
                }
            }
        }
    }
    
    private func stopCamera() {
        captureSession?.stopRunning()
        print("🛑 MirrorViewController: Camera session stopped")
    }
    
    private func setupVision() {
        // Configure the pose request with optimized 3D detection settings
        poseRequest = VNDetectHumanBodyPose3DRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 3D Pose detection error: \(error)")
                return
            }
            
            guard let results = request.results as? [VNHumanBodyPose3DObservation] else { 
                print("⚠️ No 3D pose detection results")
                return 
            }
            
            print("🔍 Vision detected \(results.count) 3D pose(s)")
            
            // Process the first detected pose
            if let observation = results.first {
                print("🔍 Processing 3D pose with confidence: \(observation.confidence)")
                self.processPoseObservation(observation)
            } else {
                print("⚠️ No valid 3D pose observations found")
            }
        }
        
        // Configure the request for optimal 3D detection
        poseRequest?.revision = VNDetectHumanBodyPose3DRequestRevision1
        
        print("✅ MirrorViewController: Vision framework configured with optimized 3D pose detection")
    }
    
    
    private func setupFormAnalyzer() {
        formAnalyzer = FormAnalyzer()
        // Set initial exercise from database
        if let exercise = Exercise.getExercise(named: currentExercise) {
            formAnalyzer?.setExercise(exercise)
            print("✅ MirrorViewController: Exercise set to \(exercise.name) with \(exercise.phases.count) phases")
        } else {
            print("❌ MirrorViewController: Exercise '\(currentExercise)' not found in database")
        }
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPose3DObservation) {
        guard let analyzer = formAnalyzer else { return }
        
        // Debug: Print detailed observation information
        print("🔍 3D Pose Observation Details:")
        print("  - Confidence: \(observation.confidence)")
        print("  - Available joints: \(observation.availableJointNames.count)")
        
        // Check observation quality - lower threshold for better detection
        guard observation.confidence > 0.05 else {
            // Very low confidence observation, skip processing
            print("⚠️ MirrorViewController: Very low confidence pose observation: \(observation.confidence)")
            DispatchQueue.main.async {
                self.formFeedbackLabel?.text = "Move into camera view for better tracking"
            }
            return
        }
        
        print("✅ MirrorViewController: Processing pose observation with confidence: \(observation.confidence)")
        
        // Update skeleton overlay on main thread for smooth UI
        DispatchQueue.main.async {
            // For now, use identity matrix since we don't have AR session
            // In a real AR app, you'd get this from ARSession.currentFrame?.camera.transform
            self.skeletonOverlayView?.updateSkeleton(observation: observation, cameraTransform: matrix_identity_float4x4)
        }
        
        // Analyze form using the analyzer (can be done on background thread)
        guard let exercise = Exercise.getExercise(named: currentExercise) else {
            print("❌ MirrorViewController: Exercise '\(currentExercise)' not found for analysis")
            return
        }
        
        let formAnalysis = analyzer.analyzeForm(observation: observation, exercise: exercise)
        
        // Update UI with form analysis results on main thread
        DispatchQueue.main.async {
            self.updateFormFeedback(formAnalysis)
        }
    }
    
    
    private func updateFormFeedback(_ analysis: FormAnalyzer.FormAnalysis) {
        // Update form score (convert to percentage)
        currentFormScore = Int(analysis.score * 100)
        formScoreLabel?.text = "\(currentFormScore)%"
        
        // Update rep count (only good reps)
        currentRepCount = analysis.repCount
        repCountLabel?.text = "\(currentRepCount)"
        
        // Update form feedback with comprehensive information
        var feedbackText = analysis.feedback
        
        // Add warnings if any
        if !analysis.warnings.isEmpty {
            feedbackText += "\n⚠️ " + analysis.warnings.joined(separator: " ")
        }
        
        // Add tips if form is poor
        if analysis.quality == .poor || analysis.quality == .dangerous {
            if !analysis.tips.isEmpty {
                feedbackText += "\n💡 " + analysis.tips.prefix(2).joined(separator: " ")
            }
        }
        
        formFeedbackLabel?.text = feedbackText
        
        // Update exercise name
        exerciseInfoLabel?.text = "Exercise: \(currentExercise.capitalized)"
        
        // Update colors based on form quality
        updateLabelColors(quality: analysis.quality)
        
        // Debug output
        print("📊 Form Analysis: Score=\(currentFormScore)%, Reps=\(currentRepCount), Quality=\(analysis.quality.rawValue)")
    }
    
    private func updateLabelColors(quality: FormQuality) {
        let backgroundColor: UIColor
        switch quality {
        case .excellent, .good:
            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        case .acceptable:
            backgroundColor = UIColor.systemYellow.withAlphaComponent(0.8)
        case .poor:
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        case .dangerous:
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        }
        
        formScoreLabel?.backgroundColor = backgroundColor
        repCountLabel?.backgroundColor = backgroundColor
        formFeedbackLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.8) // Always black for readability
        exerciseInfoLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.8) // Always black
    }
    
    /// Update the voice feedback caption for different voice assistant states
    func updateVoiceFeedback(_ message: String) {
        DispatchQueue.main.async {
            self.formFeedbackLabel?.text = message
            // Reset to default black background for voice feedback
            self.formFeedbackLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
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
        // No voice assistant overlay needed - the black caption at bottom handles voice feedback
        // This keeps the interface hands-free and clean
        
        // Create exercise info label (top center) - Black rectangular label with dynamic sizing
        exerciseInfoLabel = UILabel()
        exerciseInfoLabel?.text = "Exercise: \(currentExercise.capitalized)"
        exerciseInfoLabel?.textColor = .white
        exerciseInfoLabel?.font = UIFont.preferredFont(forTextStyle: .headline) // Dynamic system font
        exerciseInfoLabel?.textAlignment = .center
        exerciseInfoLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        exerciseInfoLabel?.layer.cornerRadius = 12 // Slightly more rounded
        exerciseInfoLabel?.layer.masksToBounds = true
        exerciseInfoLabel?.numberOfLines = 0 // Allow multiple lines
        exerciseInfoLabel?.adjustsFontSizeToFitWidth = true // Auto-adjust font size
        exerciseInfoLabel?.minimumScaleFactor = 0.7 // Minimum scale factor
        exerciseInfoLabel?.padding = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        
        if let exerciseLabel = exerciseInfoLabel {
            view.addSubview(exerciseLabel)
            exerciseLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                exerciseLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                exerciseLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
        }
        
        // Create form score label (top left) - Black rectangular label with dynamic sizing
        formScoreLabel = UILabel()
        formScoreLabel?.text = "0%"
        formScoreLabel?.textColor = .white
        formScoreLabel?.font = UIFont.preferredFont(forTextStyle: .title2) // Dynamic system font
        formScoreLabel?.textAlignment = .center
        formScoreLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.8) // Always black
        formScoreLabel?.layer.cornerRadius = 12 // Slightly more rounded
        formScoreLabel?.layer.masksToBounds = true
        formScoreLabel?.adjustsFontSizeToFitWidth = true // Auto-adjust font size
        formScoreLabel?.minimumScaleFactor = 0.6 // Minimum scale factor
        formScoreLabel?.padding = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        
        if let scoreLabel = formScoreLabel {
            view.addSubview(scoreLabel)
            scoreLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
            ])
        }
        
        // Create rep count label (top right) - Black rectangular label with dynamic sizing
        repCountLabel = UILabel()
        repCountLabel?.text = "0"
        repCountLabel?.textColor = .white
        repCountLabel?.font = UIFont.preferredFont(forTextStyle: .title2) // Dynamic system font
        repCountLabel?.textAlignment = .center
        repCountLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.8) // Always black
        repCountLabel?.layer.cornerRadius = 12 // Slightly more rounded
        repCountLabel?.layer.masksToBounds = true
        repCountLabel?.adjustsFontSizeToFitWidth = true // Auto-adjust font size
        repCountLabel?.minimumScaleFactor = 0.6 // Minimum scale factor
        repCountLabel?.padding = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        
        if let repLabel = repCountLabel {
            view.addSubview(repLabel)
            repLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                repLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                repLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
            ])
        }
        
        // Create form feedback label (bottom center) - Long rectangular caption spanning side to side
        formFeedbackLabel = UILabel()
        formFeedbackLabel?.text = "Say 'Hey Rex' for help"
        formFeedbackLabel?.textColor = .white
        formFeedbackLabel?.font = UIFont.preferredFont(forTextStyle: .body) // Dynamic system font
        formFeedbackLabel?.textAlignment = .center
        formFeedbackLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        formFeedbackLabel?.layer.cornerRadius = 12 // Slightly more rounded
        formFeedbackLabel?.layer.masksToBounds = true
        formFeedbackLabel?.padding = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20) // Thick padding for 2 lines of text
        formFeedbackLabel?.numberOfLines = 0 // Allow multiple lines
        formFeedbackLabel?.lineBreakMode = .byWordWrapping
        formFeedbackLabel?.adjustsFontSizeToFitWidth = true // Auto-adjust font size
        formFeedbackLabel?.minimumScaleFactor = 0.8 // Minimum scale factor
        
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
    
    private func showCameraErrorAlert() {
        let alert = UIAlertController(
            title: "Camera Error",
            message: "Unable to access front camera. Please check camera permissions.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Permission Required",
            message: "This app needs camera access to track your form. Please enable camera permissions in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
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
        
        // Try to get the exercise from the database first
        if let existingExercise = Exercise.getExercise(named: exercise) {
            formAnalyzer?.setExercise(existingExercise)
            exerciseInfoLabel?.text = "Exercise: \(exercise.capitalized)"
            print("✅ MirrorViewController: Exercise set to \(exercise) from database")
        } else {
            // Fallback: create a basic exercise object
            let exerciseObj = Exercise(
                name: exercise,
                category: .legs,
                description: "Exercise",
                imageName: "exercise_image",
                phases: [],
                keyJoints: [],
                safetyNotes: [],
                bodyTypeConsiderations: []
            )
            formAnalyzer?.setExercise(exerciseObj)
            exerciseInfoLabel?.text = "Exercise: \(exercise.capitalized)"
            print("✅ MirrorViewController: Exercise set to \(exercise) (fallback)")
        }
    }
    

}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension MirrorViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            print("❌ MirrorViewController: Failed to get pixel buffer from sample buffer")
            return 
        }
        
        // Debug: Print pixel buffer information
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("🔍 Processing frame: \(width)x\(height)")
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        do {
            // Perform 3D pose detection
            if let poseRequest = poseRequest {
                try handler.perform([poseRequest])
            } else {
                print("⚠️ MirrorViewController: No pose request available")
            }
        } catch {
            print("❌ MirrorViewController: Failed to perform Vision request: \(error)")
        }
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