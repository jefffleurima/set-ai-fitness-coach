import UIKit
import ARKit
import RealityKit
import Vision
import Combine

class MirrorViewController: UIViewController {
    
    // MARK: - Properties
    
    private var arView: ARView!
    private var bodyMeshRenderer: BodyMeshRenderer?
    private var formAnalyzer = FormAnalyzer()
    private var currentExercise: Exercise?
    private var cancellables = Set<AnyCancellable>()
    
    // UI Components
    private var swipeIndicator = UIView()
    private var exerciseNameLabel = UILabel()
    private var scoreLabel = UILabel()
    private var repLabel = UILabel()
    private var feedbackLabel = UILabel()
    private var stateLabel = UILabel()
    private var debugView = UIView()
    
    // State Management
    private var state: MirrorState = .initializing {
        didSet { updateUIForState() }
    }
    
    private var lastRepTime: Date?
    private var repHistory: [Float] = []
    private var frameCount = 0
    
    // Dependencies
    var dismissClosure: (() -> Void)?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupUI()
        setupGestureRecognizers()
        setupObservers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseARSession()
    }
    
    // MARK: - Setup Methods
    
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.backgroundColor = .black
        view.addSubview(arView)
        
        bodyMeshRenderer = BodyMeshRenderer(arView: arView)
    }
    
    private func setupUI() {
        // Swipe Indicator
        swipeIndicator.backgroundColor = .white.withAlphaComponent(0.3)
        swipeIndicator.layer.cornerRadius = 2
        view.addSubview(swipeIndicator)
        
        // Exercise Name Label
        exerciseNameLabel.styleAsHeader()
        view.addSubview(exerciseNameLabel)
        
        // Score Label
        scoreLabel.styleAsMetric()
        view.addSubview(scoreLabel)
        
        // Rep Label
        repLabel.styleAsMetric()
        view.addSubview(repLabel)
        
        // Feedback Label
        feedbackLabel.styleAsFeedback()
        view.addSubview(feedbackLabel)
        
        // State Label
        stateLabel.styleAsStateIndicator()
        view.addSubview(stateLabel)
        
        // Debug View (hidden by default)
        debugView.backgroundColor = .black.withAlphaComponent(0.7)
        debugView.isHidden = true
        view.addSubview(debugView)
        
        setupConstraints()
        updateUIForState()
    }
    
    private func setupConstraints() {
        [swipeIndicator, exerciseNameLabel, scoreLabel, repLabel, 
         feedbackLabel, stateLabel, debugView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // Swipe Indicator
            swipeIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            swipeIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            swipeIndicator.widthAnchor.constraint(equalToConstant: 40),
            swipeIndicator.heightAnchor.constraint(equalToConstant: 4),
            
            // Exercise Name
            exerciseNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            exerciseNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exerciseNameLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            
            // Score Label
            scoreLabel.topAnchor.constraint(equalTo: exerciseNameLabel.bottomAnchor, constant: 16),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scoreLabel.widthAnchor.constraint(equalToConstant: 60),
            
            // Rep Label
            repLabel.topAnchor.constraint(equalTo: exerciseNameLabel.bottomAnchor, constant: 16),
            repLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            repLabel.widthAnchor.constraint(equalToConstant: 60),
            
            // Feedback Label
            feedbackLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            feedbackLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            feedbackLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // State Label
            stateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Debug View
            debugView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            debugView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            debugView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            debugView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func setupGestureRecognizers() {
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
    }
    
    private func setupObservers() {
        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pauseARSession()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startARSession()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - AR Session Management
    
    private func startARSession() {
        guard ARBodyTrackingConfiguration.isSupported else {
            state = .error(MirrorError.deviceNotSupported)
            return
        }
        
        let configuration = ARBodyTrackingConfiguration()
        configuration.automaticImageScaleEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        arView.session.delegate = self
        
        state = .ready
    }
    
    private func pauseARSession() {
        arView.session.pause()
    }
    
    // MARK: - Exercise Management
    
    func setExercise(_ exercise: Exercise) {
        currentExercise = exercise
        formAnalyzer.setExercise(exercise)
        
        DispatchQueue.main.async {
            self.exerciseNameLabel.text = exercise.name
            self.repLabel.text = "0"
            self.scoreLabel.text = "0%"
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUIForState() {
        DispatchQueue.main.async {
            switch self.state {
            case .initializing:
                self.stateLabel.text = "Initializing..."
                self.stateLabel.isHidden = false
            case .ready:
                self.stateLabel.text = "Ready - Stand in Frame"
                self.stateLabel.isHidden = false
            case .tracking:
                self.stateLabel.isHidden = true
            case .error(let error):
                self.stateLabel.text = "Error: \(error.localizedDescription)"
                self.stateLabel.isHidden = false
            }
        }
    }
    
    private func updateFormAnalysis(_ analysis: FormAnalyzer.FormAnalysis) {
        DispatchQueue.main.async {
            self.scoreLabel.text = "\(Int(analysis.score))%"
            self.repLabel.text = "\(analysis.repCount)"
            
            if !analysis.feedback.isEmpty {
                self.feedbackLabel.text = analysis.feedback.joined(separator: "\n")
            }
            
            // Update state based on phase
            switch analysis.currentPhase {
            case .preparation:
                self.state = .ready
            default:
                self.state = .tracking
            }
        }
    }
    
    // MARK: - User Interaction
    
    @objc private func handleSwipeDown() {
        dismissClosure?()
    }
    
    @objc private func handleDoubleTap() {
        debugView.isHidden = !debugView.isHidden
    }
    
    // MARK: - Performance Optimization
    
    private func shouldProcessFrame() -> Bool {
        frameCount += 1
        // Process every 3rd frame for performance
        return frameCount % 3 == 0
    }
}

// MARK: - ARSessionDelegate
extension MirrorViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard shouldProcessFrame() else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, orientation: .up)
        let request = VNDetectHumanBodyPose3DRequest()
        
        do {
            try handler.perform([request])
            
            if let observation = request.results?.first {
                processPoseObservation(observation)
            } else if state == .tracking {
                state = .ready // No body detected
            }
        } catch {
            state = .error(error)
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        anchors.compactMap { $0 as? ARBodyAnchor }.forEach {
            bodyMeshRenderer?.session(session, didAdd: [$0])
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        anchors.compactMap { $0 as? ARBodyAnchor }.forEach {
            bodyMeshRenderer?.session(session, didUpdate: [$0])
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        state = .error(error)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        state = .error(MirrorError.sessionInterrupted)
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        startARSession()
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPose3DObservation) {
        let analysis = formAnalyzer.analyzeForm(observation)
        updateFormAnalysis(analysis)
        bodyMeshRenderer?.updateMeshWithVisionData(observation, formAnalysis: analysis)
    }
}

// MARK: - State & Error Handling
private enum MirrorState {
    case initializing
    case ready
    case tracking
    case error(Error)
}

private enum MirrorError: LocalizedError {
    case deviceNotSupported
    case sessionInterrupted
    
    var errorDescription: String? {
        switch self {
        case .deviceNotSupported:
            return "This device doesn't support body tracking"
        case .sessionInterrupted:
            return "Session was interrupted"
        }
    }
}

// MARK: - UI Styling Extensions
private extension UILabel {
    func styleAsHeader() {
        textColor = .white
        font = .systemFont(ofSize: 18, weight: .semibold)
        textAlignment = .center
        backgroundColor = .black.withAlphaComponent(0.5)
        layer.cornerRadius = 12
        layer.masksToBounds = true
        numberOfLines = 1
    }
    
    func styleAsMetric() {
        textColor = .white
        font = .systemFont(ofSize: 16, weight: .bold)
        textAlignment = .center
        backgroundColor = .black.withAlphaComponent(0.6)
        layer.cornerRadius = 6
        layer.masksToBounds = true
    }
    
    func styleAsFeedback() {
        textColor = .white
        font = .systemFont(ofSize: 16, weight: .medium)
        textAlignment = .center
        backgroundColor = .black.withAlphaComponent(0.7)
        layer.cornerRadius = 8
        layer.masksToBounds = true
        numberOfLines = 0
    }
    
    func styleAsStateIndicator() {
        textColor = .white
        font = .systemFont(ofSize: 20, weight: .medium)
        textAlignment = .center
        numberOfLines = 0
    }
}