import SwiftUI
import UIKit

struct MirrorViewWrapper: UIViewControllerRepresentable {
    // MARK: - Properties
    
    let exercise: Exercise
    @Binding var isPresented: Bool
    @State private var hasAppeared = false
    
    // Configuration
    private let debugMode: Bool
    private let performanceMode: PerformanceMode
    
    // MARK: - Initialization
    
    init(exercise: Exercise, isPresented: Binding<Bool>, debugMode: Bool = false, performanceMode: PerformanceMode = .balanced) {
        self.exercise = exercise
        self._isPresented = isPresented
        self.debugMode = debugMode
        self.performanceMode = performanceMode
    }
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> MirrorViewController {
        let viewController = MirrorViewController()
        configureViewController(viewController)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: MirrorViewController, context: Context) {
        // Only update if the exercise changed
        if uiViewController.currentExercise?.id != exercise.id {
            uiViewController.setExercise(exercise)
        }
        
        // Update debug mode if changed
        uiViewController.setDebugMode(debugMode)
    }
    
    // MARK: - Configuration
    
    private func configureViewController(_ viewController: MirrorViewController) {
        viewController.setExercise(exercise)
        viewController.setPerformanceMode(performanceMode)
        viewController.setDebugMode(debugMode)
        
        viewController.dismissClosure = { [weak viewController] in
            viewController?.cleanupBeforeDismissal()
            isPresented = false
        }
    }
    
    // MARK: - View Lifecycle
    
    private func handleAppLifecycle(for controller: MirrorViewController) -> some View {
        Group {
            if hasAppeared {
                EmptyView()
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        controller.pauseSession()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        controller.resumeSession()
                    }
            }
        }
    }
    
    // MARK: - Performance Modes
    
    enum PerformanceMode {
        case quality
        case balanced
        case performance
        
        var frameProcessingRate: Int {
            switch self {
            case .quality: return 1  // Process every frame
            case .balanced: return 2 // Process every 2nd frame
            case .performance: return 3 // Process every 3rd frame
            }
        }
    }
}

// MARK: - Preview

struct MirrorViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        MirrorViewWrapper(
            exercise: Exercise(id: "preview", name: "Preview Exercise", type: .squat),
            isPresented: .constant(true)
        )
    }
}

// MARK: - MirrorViewController Extensions

extension MirrorViewController {
    func setPerformanceMode(_ mode: MirrorViewWrapper.PerformanceMode) {
        // Implement performance mode adjustment
    }
    
    func setDebugMode(_ enabled: Bool) {
        // Implement debug mode toggling
    }
    
    func cleanupBeforeDismissal() {
        // Clean up resources before dismissal
        pauseARSession()
    }
    
    func pauseSession() {
        pauseARSession()
    }
    
    func resumeSession() {
        startARSession()
    }
}