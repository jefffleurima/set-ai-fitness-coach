import UIKit
import AVFoundation
import Vision
import CoreImage

// MARK: - Lighting Quality Types

enum LightingQuality {
    case tooLow(String)
    case tooHigh(String)
    case backlit(String)
    case uneven(String)
    case good
    
    var isGood: Bool {
        if case .good = self {
            return true
        }
        return false
    }
    
    var feedbackMessage: String {
        switch self {
        case .tooLow(let message), .tooHigh(let message), .backlit(let message), .uneven(let message):
            return message
        case .good:
            return "Lighting looks good!"
        }
    }
    
    var severity: LightingSeverity {
        switch self {
        case .tooLow, .backlit:
            return .critical
        case .tooHigh, .uneven:
            return .warning
        case .good:
            return .none
        }
    }
}

enum LightingSeverity {
    case none
    case warning
    case critical
}

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
    
    // Frame throttling for performance
    private var lastProcessedFrameTime: Date = Date()
    private let frameProcessingInterval: TimeInterval = 0.05 // Process every 50ms (20 FPS) for smoother skeleton
    
    // Cache exercise object to avoid recreating every frame
    private var cachedExercise: Exercise?
    
    // Speech throttling to prevent API spam
    private var lastSpokenFeedback: String = ""
    private var lastSpeechTime: Date = Date.distantPast
    
    // Greeting system
    private var hasGreeted = false
    private var greetingComplete = false // Track when greeting is fully delivered
    private var isGreetingLocked = false // Prevent caption updates during greeting
    private var currentGreetingText: String = "" // Full greeting text
    private var greetingTimer: Timer? // Timer for animated caption
    private var pendingCaptionText: String? // Text waiting for voice to start
    private var captionChunks: [String] = [] // Chunks to display
    private var currentChunkIndex: Int = 0 // Current chunk being displayed
    private var stabilityCheckCount = 0
    private let stabilityRequiredFrames = 30 // Wait for 30 stable frames (1.5 seconds at 20fps)
    private var lastStablePoseTime: Date = Date()
    private var isUserStable = false
    private var lastHipPosition: CGPoint?
    private var lastAnklePosition: CGPoint?
    
    // Lighting quality system
    private var currentLightingQuality: LightingQuality = .good
    private var lightingCheckFrameCount = 0
    private let lightingCheckInterval = 20 // Check every 20 frames (1 second at 20fps)
    private var lastLightingWarningTime: Date = Date.distantPast
    private let lightingWarningCooldown: TimeInterval = 10.0
    
    // Debug frame counter
    private var debugFrameCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupSkeletonOverlay()
        setupUI() // Setup UI last so it appears on top
        setupFormAnalyzer()
        setupGestures()
        
        // Set up notification observers for live captions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLiveCaptionRequest(_:)),
            name: NSNotification.Name("DisplayLiveCaptionNotification"),
            object: nil
        )
        
        // Observe when ElevenLabs audio actually starts playing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioPlaybackStarted),
            name: NSNotification.Name("ElevenLabsPlaybackStarted"),
            object: nil
        )
    }
    
    @objc private func handleLiveCaptionRequest(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let text = userInfo["text"] as? String {
            print("📺 Received live caption request from VoiceAssistantManager: \(text.prefix(50))...")
            
            // Store text and wait for actual audio playback to start
            pendingCaptionText = text
        }
    }
    
    @objc private func handleAudioPlaybackStarted(_ notification: Notification) {
        print("🎤 Audio playback STARTED - Beginning live caption sync")
        
        // Get actual audio duration from notification
        let audioDuration = notification.userInfo?["duration"] as? TimeInterval ?? 0.0
        print("⏱️ Actual audio duration: \(String(format: "%.1f", audioDuration))s")
        
        // Start caption animation NOW that audio is actually playing
        if let text = pendingCaptionText {
            displayLiveCaptionForFeedback(text, audioDuration: audioDuration)
            pendingCaptionText = nil
        } else if !currentGreetingText.isEmpty {
            // This is for the greeting
            animateCaptionWithVoice(text: currentGreetingText, audioDuration: audioDuration)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCamera()
        
        // Wake word detection is already running globally - no need to start/stop here
        // Users can say "Hey Rex" anytime during workout or outside of it
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
        
        // Clean up greeting timer
        greetingTimer?.invalidate()
        greetingTimer = nil
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Wake word detection stays active globally - mic only opens on "Hey Rex"
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
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium) // Reduced font size
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 3 // Limit to 3 lines instead of unlimited
        label.lineBreakMode = .byTruncatingTail // Truncate with "..." if too long
        label.adjustsFontSizeToFitWidth = false // Don't shrink text
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
            
            // Feedback label - bottom center with max height
            feedbackLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            feedbackLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            feedbackLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            feedbackLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            feedbackLabel.heightAnchor.constraint(lessThanOrEqualToConstant: 100) // Max height to prevent overflow
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
        // End workout session and save data
        Task {
            await formAnalyzer?.endWorkoutSession()
        }
        
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
        
        // Set the current exercise for form analysis and cache it
        cachedExercise = Exercise(
            name: currentExercise,
            category: ExerciseCategory.legs,
            description: "Form analysis for \(currentExercise)",
            imageName: "\(currentExercise.lowercased())_icon",
            phases: [],
            keyJoints: [],
            safetyNotes: [],
            bodyTypeConsiderations: []
        )
        
        if let exercise = cachedExercise {
            formAnalyzer?.setExercise(exercise)
            print("✅ FormAnalyzer setup for exercise: \(currentExercise)")
        }
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
        // Throttle frame processing for better performance (10 FPS instead of 30 FPS)
        let now = Date()
        guard now.timeIntervalSince(lastProcessedFrameTime) >= frameProcessingInterval else { return }
        lastProcessedFrameTime = now
        
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
            print("⚠️ No pose observation detected")
            return
        }
        
        // Debug: Log that we're processing poses
        debugFrameCount += 1
        if debugFrameCount % 20 == 0 {
            print("📹 Processing frame #\(debugFrameCount) - hasGreeted: \(hasGreeted), greetingComplete: \(greetingComplete)")
        }
        
        // Check lighting quality periodically
        lightingCheckFrameCount += 1
        if lightingCheckFrameCount >= lightingCheckInterval {
            lightingCheckFrameCount = 0
            checkLightingQuality(pixelBuffer: pixelBuffer, observation: observation)
        }
        
        // SIMPLIFIED GREETING: Just wait 2 seconds after pose detected, then greet
        // Don't require perfect 4-point tracking since left ankle is unreliable
        if !hasGreeted && debugFrameCount == 40 {  // 40 frames = 2 seconds at 20fps
            hasGreeted = true
            print("⏱️ 2 seconds elapsed - delivering greeting")
            deliverPersonalizedGreeting()
        }
        
        // Update skeleton overlay (combines both updates for efficiency)
        skeletonOverlayView?.updateSkeleton(observation: observation, pixelBuffer: pixelBuffer)
        skeletonOverlayView?.updateFormData(score: currentFormScore, feedback: currentFeedback)
        
        // ONLY analyze form AFTER greeting is complete
        if greetingComplete {
            if let formAnalyzer = formAnalyzer, let cachedExercise = cachedExercise {
                let _ = formAnalyzer.analyzeVisionForm(observation: observation, exercise: cachedExercise)
            }
        } else {
            // Before greeting, just show "Detecting your position..." in caption
            if hasGreeted && !greetingComplete {
                // Greeting is being spoken, wait for it to complete
            }
        }
    }
}

// MARK: - FormAnalyzerDelegate

extension MirrorViewController: FormAnalyzerDelegate {
    
    func formAnalyzer(_ analyzer: FormAnalyzer, didUpdateFormScore score: Int) {
        // CRITICAL FIX: Don't update UI until greeting complete
        guard greetingComplete else {
            print("🚫 Blocked FormAnalyzer score update during greeting: \(score)")
            return
        }
        
        // Handle form score updates - score represents how close to perfect (0-100)
        currentFormScore = max(0, min(100, score)) // Ensure score is between 0-100
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.formScoreLabel?.text = "\(self.currentFormScore)%"
        }
        print("📊 Form Score: \(score)")
    }
    
    func formAnalyzer(_ analyzer: FormAnalyzer, didUpdateRepCount count: Int) {
        // CRITICAL FIX: Don't update UI until greeting complete
        guard greetingComplete else {
            print("🚫 Blocked FormAnalyzer rep count during greeting: \(count)")
            return
        }
        
        // Handle rep counting - only count good reps (form score >= 70)
        currentRepCount = max(0, count) // Ensure rep count is non-negative
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.repCountLabel?.text = "\(self.currentRepCount)"
        }
        print("🔢 Reps: \(count)")
    }
    
    func formAnalyzer(_ analyzer: FormAnalyzer, didProvideFeedback feedback: String) {
        // CRITICAL FIX: Don't let FormAnalyzer overwrite greeting!
        guard greetingComplete else {
            print("🚫 Blocked FormAnalyzer feedback during greeting: \(feedback)")
            return
        }
        
        // Display AI feedback in the caption
        currentFeedback = feedback
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Don't update caption if greeting is locked
            if self.isGreetingLocked {
                print("🔒 Caption locked during greeting - skipping update")
                return
            }
            
            // For short feedback (< 80 chars), display immediately
            // For longer feedback, use live caption animation
            if feedback.count <= 80 {
                self.feedbackLabel?.text = feedback
                print("📝 Caption updated: \(feedback)")
            } else {
                // Use live caption system for long feedback
                self.displayLiveCaptionForFeedback(feedback)
            }
            
            // Voice coaching throttling (separate from caption)
            let timeSinceLastSpeech = Date().timeIntervalSince(self.lastSpeechTime)
            let feedbackChanged = feedback != self.lastSpokenFeedback
            let enoughTimePassed = timeSinceLastSpeech >= 3.0
            
            // Don't repeatedly speak "Get ready" message (but still show in caption)
            let isReadyMessage = feedback.contains("Get ready") || feedback.contains("start when you're ready")
            
            // Speak actual coaching cues, skip ready message
            if feedbackChanged && enoughTimePassed && !feedback.isEmpty && !isReadyMessage {
                self.lastSpokenFeedback = feedback
                self.lastSpeechTime = Date()
                print("🎤 Speaking coaching cue: \(feedback)")
                self.speakAIResponse(feedback)
            } else if isReadyMessage && self.lastSpokenFeedback != feedback {
                // Update last feedback but don't speak
                self.lastSpokenFeedback = feedback
            }
        }
        
        // Only print when feedback changes
        if feedback != currentFeedback {
            print("📝 AI Form Feedback: \(feedback)")
        }
    }
    
    func formAnalyzer(_ analyzer: FormAnalyzer, didCompleteWorkout session: FormAnalyzer.WorkoutSessionData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Show comprehensive workout completion
            self.showWorkoutCompletion(session: session)
        }
        print("✅ Workout completed with comprehensive data")
    }
    
    private func showWorkoutCompletion(session: FormAnalyzer.WorkoutSessionData) {
        // Create comprehensive workout summary
        let summary = """
        🎉 Workout Complete!
        
        Exercise: \(session.exercise.name)
        Duration: \(Int(session.duration / 60)) minutes
        Total Reps: \(session.totalReps)
        Good Reps: \(session.goodReps)
        Average Form: \(Int(session.averageFormScore * 100))%
        
        \(session.overallAssessment)
        """
        
        // Update UI with summary
        feedbackLabel?.text = summary
        
        // Speak the assessment
        speakAIResponse(session.overallAssessment)
        
        // TODO: Save session data to HealthKit or local storage
        // TODO: Trigger AI post-workout assessment
    }
    
    // MARK: - Lighting Quality System
    
    private func checkLightingQuality(pixelBuffer: CVPixelBuffer, observation: VNHumanBodyPoseObservation?) {
        // Assess lighting quality
        let quality = assessLightingQuality(from: pixelBuffer)
        currentLightingQuality = quality
        
        // Only warn user if lighting is bad (don't mention if good)
        if !quality.isGood && shouldWarnAboutLighting() {
            // Show in feedback label
            DispatchQueue.main.async { [weak self] in
                self?.feedbackLabel?.text = quality.feedbackMessage
            }
            
            // Speak warning for critical issues only
            if quality.severity == .critical {
                speakAIResponse(quality.feedbackMessage)
            }
            
            print("⚠️ Lighting warning: \(quality.feedbackMessage)")
            lastLightingWarningTime = Date()
        }
    }
    
    private func shouldWarnAboutLighting() -> Bool {
        let timeSinceLastWarning = Date().timeIntervalSince(lastLightingWarningTime)
        return timeSinceLastWarning >= lightingWarningCooldown
    }
    
    private func assessLightingQuality(from pixelBuffer: CVPixelBuffer) -> LightingQuality {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let brightness = calculateAverageBrightness(ciImage)
        
        // Check brightness levels
        if brightness < 0.2 {
            return .tooLow("Move to a brighter area or turn on more lights")
        }
        
        if brightness > 0.85 {
            return .tooHigh("Too bright - avoid direct lights or move to a dimmer area")
        }
        
        // Check for backlighting (center darker than edges)
        let centerBrightness = calculateCenterBrightness(ciImage)
        if brightness - centerBrightness > 0.4 {
            return .backlit("Avoid backlighting - move away from windows or bright lights behind you")
        }
        
        return .good
    }
    
    private func calculateAverageBrightness(_ image: CIImage) -> CGFloat {
        let extentVector = CIVector(x: image.extent.origin.x,
                                    y: image.extent.origin.y,
                                    z: image.extent.size.width,
                                    w: image.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: extentVector
        ]) else { return 0.5 }
        
        guard let outputImage = filter.outputImage else { return 0.5 }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)
        
        // Calculate luminance from RGB
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
    
    private func calculateCenterBrightness(_ image: CIImage) -> CGFloat {
        let centerRect = CGRect(
            x: image.extent.width * 0.3,
            y: image.extent.height * 0.3,
            width: image.extent.width * 0.4,
            height: image.extent.height * 0.4
        )
        
        let centerImage = image.cropped(to: centerRect)
        return calculateAverageBrightness(centerImage)
    }
    
    // MARK: - Greeting System
    
    private func checkUserStability(observation: VNHumanBodyPoseObservation) {
        // Check if user is standing and stable
        guard let leftHip = try? observation.recognizedPoint(.leftHip),
              let rightHip = try? observation.recognizedPoint(.rightHip),
              let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
              let rightAnkle = try? observation.recognizedPoint(.rightAnkle) else {
            stabilityCheckCount = 0
            lastHipPosition = nil
            lastAnklePosition = nil
            print("❌ Stability check failed: Missing joints")
            return
        }
        
        // Check confidence levels (user must be clearly visible)
        let minConfidence: Float = 0.3  // Lowered to 0.3 to match skeleton display
        print("🔍 Joint confidences: LH:\(String(format: "%.2f", leftHip.confidence)) RH:\(String(format: "%.2f", rightHip.confidence)) LA:\(String(format: "%.2f", leftAnkle.confidence)) RA:\(String(format: "%.2f", rightAnkle.confidence))")
        
        guard leftHip.confidence >= minConfidence && rightHip.confidence >= minConfidence &&
              leftAnkle.confidence >= minConfidence && rightAnkle.confidence >= minConfidence else {
            stabilityCheckCount = 0
            lastHipPosition = nil
            lastAnklePosition = nil
            print("❌ Stability check failed: Low confidence (min: \(minConfidence))")
            return
        }
        
        // Check if user is standing (hips above ankles)
        // ACTUAL coordinate system from logs: Y increases DOWN the body (head=0.4, hips=0.55, ankles=0.60)
        // So when standing: Hip Y < Ankle Y (hips are higher up = smaller Y)
        let hipsAboveAnkles = (leftHip.location.y < leftAnkle.location.y) && (rightHip.location.y < rightAnkle.location.y)
        
        // Log the distances for debugging
        let leftHipAnkleDistance = abs(leftAnkle.location.y - leftHip.location.y)
        let rightHipAnkleDistance = abs(rightAnkle.location.y - rightHip.location.y)
        
        if !hipsAboveAnkles {
            print("❌ Not standing: Hip Y >= Ankle Y (LH:\(String(format: "%.3f", leftHip.location.y)) LA:\(String(format: "%.3f", leftAnkle.location.y)))")
            stabilityCheckCount = 0
            lastHipPosition = nil
            lastAnklePosition = nil
            return
        }
        
        // Log successful standing detection
        if stabilityCheckCount == 0 && lastHipPosition == nil {
            print("✅ Standing detected: Hip-Ankle distance L:\(String(format: "%.3f", leftHipAnkleDistance)) R:\(String(format: "%.3f", rightHipAnkleDistance))")
        }
        
        // Calculate average hip and ankle positions
        let avgHipPos = CGPoint(
            x: (leftHip.location.x + rightHip.location.x) / 2,
            y: (leftHip.location.y + rightHip.location.y) / 2
        )
        let avgAnklePos = CGPoint(
            x: (leftAnkle.location.x + rightAnkle.location.x) / 2,
            y: (leftAnkle.location.y + rightAnkle.location.y) / 2
        )
        
        // Check for actual stability (position not changing much)
        if let lastHip = lastHipPosition, let lastAnkle = lastAnklePosition {
            let hipMovement = sqrt(pow(avgHipPos.x - lastHip.x, 2) + pow(avgHipPos.y - lastHip.y, 2))
            let ankleMovement = sqrt(pow(avgAnklePos.x - lastAnkle.x, 2) + pow(avgAnklePos.y - lastAnkle.y, 2))
            
            // Movement threshold - MORE LENIENT to handle skeleton jitter
            let movementThreshold: CGFloat = 0.05  // 5% of screen (increased from 2%)
            
            if hipMovement < movementThreshold && ankleMovement < movementThreshold {
                // User is truly stable
                stabilityCheckCount += 1
                
                // Log progress every 5 frames for better visibility
                if stabilityCheckCount % 5 == 0 {
                    print("⏳ Stability check: \(stabilityCheckCount)/\(stabilityRequiredFrames) frames (hip: \(String(format: "%.4f", hipMovement)), ankle: \(String(format: "%.4f", ankleMovement)))")
                }
            } else {
                // Too much movement, reset
                if stabilityCheckCount > 0 {  // Only log if we had progress
                    print("🔄 Stability reset - movement detected (hip: \(String(format: "%.4f", hipMovement)), ankle: \(String(format: "%.4f", ankleMovement)), threshold: \(movementThreshold))")
                }
                stabilityCheckCount = 0
            }
        } else {
            print("📍 Initializing position tracking")
        }
        
        // Update last positions
        lastHipPosition = avgHipPos
        lastAnklePosition = avgAnklePos
        
        // User is stable enough for greeting
        if stabilityCheckCount >= stabilityRequiredFrames && !hasGreeted {
            hasGreeted = true
            isUserStable = true
            print("✅ User is stable! Delivering greeting for exercise: \(currentExercise)")
            deliverPersonalizedGreeting()
        }
    }
    
    private func deliverPersonalizedGreeting() {
        print("🎬 deliverPersonalizedGreeting() called")
        
        // Get user name from SupabaseManager
        let userName = getUserDisplayName()
        print("👤 User name: \(userName)")
        
        // Get personalized greeting from WorkoutCoachingTemplates (centralized location)
        let displayName = userName == "there" ? nil : userName
        let greeting = WorkoutCoachingTemplates.shared.getExerciseSetupInstructions(
            exercise: currentExercise,
            userName: displayName
        )
        
        print("📝 Generated greeting: \(greeting.prefix(100))...")
        print("📏 Greeting length: \(greeting.count) characters")
        
        // DON'T update caption yet - wait for voice to start
        // Caption will be updated when voice actually begins speaking
        
        // Speak the greeting FIRST
        print("🎤 Attempting to speak greeting...")
        speakGreeting(greeting)
        
        // Mark greeting as complete after a longer delay for instructions (estimate 15 seconds for full squat instructions)
        let greetingDuration: TimeInterval = greeting.count > 200 ? 15.0 : 8.0
        DispatchQueue.main.asyncAfter(deadline: .now() + greetingDuration) { [weak self] in
            self?.greetingComplete = true
            print("✅ Greeting complete - form analysis now active")
        }
        
        print("👋 Personalized greeting process completed for \(currentExercise): \(userName)")
    }
    
    private func speakGreeting(_ text: String) {
        // Save greeting to conversation history
        ConversationMemory.shared.addWorkoutGreeting(text, exercise: currentExercise)
        
        // Store full greeting text for caption animation (will start when audio plays)
        currentGreetingText = text
        
        // Lock caption immediately to prevent FormAnalyzer from showing "Get ready..."
        isGreetingLocked = true
        print("🔒 Caption LOCKED - Waiting for audio playback to start...")
        
        // Use VoiceAssistantManager's premium ElevenLabs voice
        // Caption animation will start automatically when ElevenLabsPlaybackStarted notification fires
        VoiceAssistantManager.shared.speakWithPersonality(text, style: .supportive)
    }
    
    /// Animate caption to display text as AI speaks (like live subtitles)
    private func animateCaptionWithVoice(text: String, audioDuration: TimeInterval) {
        // Split text into chunks (sentences or phrases)
        let chunks = splitIntoDisplayChunks(text)
        
        // Use ACTUAL audio duration instead of estimated duration
        let totalDuration = audioDuration > 0 ? audioDuration : Double(text.count) / 15.0 // Fallback to char-based estimate
        let chunkDuration = totalDuration / Double(chunks.count)
        
        print("📺 Live Caption: \(chunks.count) chunks, \(String(format: "%.1f", totalDuration))s ACTUAL audio, \(String(format: "%.1f", chunkDuration))s per chunk")
        
        var currentChunkIndex = 0
        
        // Cancel any existing timer
        greetingTimer?.invalidate()
        
        // Start with first chunk immediately
        feedbackLabel?.text = chunks[0]
        print("📺 Caption [1/\(chunks.count)]: \(chunks[0].prefix(50))...")
        currentChunkIndex = 1
        
        // Update caption with each chunk as AI speaks
        greetingTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if currentChunkIndex < chunks.count {
                let chunk = chunks[currentChunkIndex]
                self.feedbackLabel?.text = chunk
                print("📺 Caption [\(currentChunkIndex + 1)/\(chunks.count)]: \(chunk.prefix(50))...")
                currentChunkIndex += 1
            } else {
                // All chunks displayed - unlock and cleanup
                timer.invalidate()
                self.greetingTimer = nil
                self.isGreetingLocked = false
                print("🔓 Caption UNLOCKED - Live subtitle animation complete")
            }
        }
    }
    
    /// Display live caption for any feedback during workout
    private func displayLiveCaptionForFeedback(_ text: String, audioDuration: TimeInterval = 0.0) {
        // Lock caption briefly during animation
        let wasLocked = isGreetingLocked
        isGreetingLocked = true
        
        // Animate the caption
        let chunks = splitIntoDisplayChunks(text)
        
        // Use ACTUAL audio duration if provided, otherwise estimate
        let totalDuration = audioDuration > 0 ? audioDuration : Double(text.count) / 15.0
        let chunkDuration = totalDuration / Double(chunks.count)
        
        print("📺 Live Feedback Caption: \(chunks.count) chunks, \(String(format: "%.1f", totalDuration))s \(audioDuration > 0 ? "ACTUAL" : "estimated")")
        
        var currentChunkIndex = 0
        
        // Cancel any existing timer
        greetingTimer?.invalidate()
        
        // Start with first chunk
        feedbackLabel?.text = chunks[0]
        currentChunkIndex = 1
        
        // Update caption with each chunk
        greetingTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if currentChunkIndex < chunks.count {
                self.feedbackLabel?.text = chunks[currentChunkIndex]
                currentChunkIndex += 1
            } else {
                timer.invalidate()
                self.greetingTimer = nil
                self.isGreetingLocked = wasLocked // Restore previous lock state
                print("📺 Live caption complete")
            }
        }
    }
    
    /// Split text into readable chunks for live caption display
    private func splitIntoDisplayChunks(_ text: String) -> [String] {
        // Split by sentences first
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var chunks: [String] = []
        
        for sentence in sentences {
            // If sentence is short (< 80 chars), show as one chunk
            if sentence.count <= 80 {
                chunks.append(sentence)
            } else {
                // Split long sentences into smaller chunks at natural breaks
                let words = sentence.components(separatedBy: .whitespaces)
                var currentChunk = ""
                
                for word in words {
                    if (currentChunk + " " + word).count <= 80 {
                        currentChunk += (currentChunk.isEmpty ? "" : " ") + word
                    } else {
                        if !currentChunk.isEmpty {
                            chunks.append(currentChunk)
                        }
                        currentChunk = word
                    }
                }
                
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
            }
        }
        
        return chunks.isEmpty ? [text] : chunks
    }
    
    private func getUserDisplayName() -> String {
        // Priority 1: Check UserDefaults for saved name (from conversation extraction)
        if let savedName = UserDefaults.standard.string(forKey: "userName"), !savedName.isEmpty {
            print("👤 Using saved name from UserDefaults: \(savedName)")
            return savedName
        }
        
        // Priority 2: Check UserProfileManager for name
        let profileName = UserProfileManager.shared.profile.personalInfo.name
        if !profileName.isEmpty {
            print("👤 Using name from UserProfileManager: \(profileName)")
            return profileName
        }
        
        // Priority 3: Get user from SupabaseManager metadata
        if let user = SupabaseManager.shared.currentUser {
            // Try to get name from user metadata (AnyJSON type)
            if let fullNameJSON = user.userMetadata["full_name"],
               case let .string(fullName) = fullNameJSON {
                let firstName = fullName.components(separatedBy: " ").first ?? "there"
                print("👤 Using name from Supabase metadata: \(firstName)")
                return firstName
            }
            // Try to get name from email
            if let email = user.email {
                let name = email.components(separatedBy: "@").first
                let firstName = name?.components(separatedBy: ".").first?.capitalized ?? "there"
                print("👤 Using name from email: \(firstName)")
                return firstName
            }
        }
        
        print("👤 No name found, using default greeting")
        return "there"
    }
    
    // MARK: - AI Voice Integration
    
    private func speakAIResponse(_ text: String) {
        print("🔊 speakAIResponse() called with text length: \(text.count)")
        
        // Skip speaking if it's just the temporary "Analyzing form..." message
        guard !text.contains("Analyzing form") else {
            print("⏭️ Skipped: Contains 'Analyzing form'")
            return
        }
        
        // Skip speaking if it's too short or generic
        guard text.count > 20 else {
            print("⏭️ Skipped: Text too short (\(text.count) chars)")
            return
        }
        
        print("🎤 Speaking AI feedback (first 100 chars): \(text.prefix(100))...")
        
        // Store text for live caption when audio starts playing
        if text.count > 80 {
            pendingCaptionText = text
            print("📺 Pending live caption for: \(text.prefix(50))... (waiting for audio)")
        } else {
            // Short text - display immediately
            feedbackLabel?.text = text
        }
        
        // Use VoiceAssistantManager's premium ElevenLabs voice
        VoiceAssistantManager.shared.speakWithPersonality(text, style: .technical)
        
        print("✅ Voice command sent to VoiceAssistantManager")
    }
}
