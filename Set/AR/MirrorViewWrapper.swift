import SwiftUI
import UIKit

struct MirrorViewWrapper: UIViewControllerRepresentable {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MirrorViewController {
        print("🔧 MirrorViewWrapper: Creating MirrorViewController for exercise: \(exercise.name)")
        let viewController = MirrorViewController()
        
        // Set the exercise and dismiss closure
        DispatchQueue.main.async {
            viewController.setExercise(self.exercise.name)
            viewController.dismissClosure = {
                self.dismiss()
            }
        }
        print("✅ MirrorViewWrapper: MirrorViewController created successfully")
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: MirrorViewController, context: Context) {
        // Update if needed
    }
} 