import SwiftUI
import UIKit

/// MirrorViewWrapper - SwiftUI wrapper for MirrorViewController
/// Provides a simple interface to the Vision 2D camera and skeleton system
struct MirrorViewWrapper: UIViewControllerRepresentable {
    
    @Binding var isPresented: Bool
    let exercise: String
    var useFrontCamera: Bool = true
    
    func makeUIViewController(context: Context) -> MirrorViewController {
        let controller = MirrorViewController()
        controller.currentExercise = exercise
        controller.useFrontCamera = useFrontCamera
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MirrorViewController, context: Context) {
        uiViewController.currentExercise = exercise
        uiViewController.useFrontCamera = useFrontCamera
    }
}
