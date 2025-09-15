import SwiftUI

/// Test view for the Vision 2D skeleton system
struct VisionSkeletonTestView: View {
    @State private var isPresented = false
    @State private var selectedExercise = "squats"
    
    let exercises = ["squats", "Deadlift"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Vision 2D Skeleton Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("17 Joint Tracking")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Features:")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("17 reliable joints for body tracking")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Fast and stable performance")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Perfect for squats and deadlifts")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Front camera support")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(spacing: 15) {
                    Text("Select Exercise:")
                        .font(.headline)
                    
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(exercises, id: \.self) { exercise in
                            Text(exercise.capitalized)
                                .tag(exercise)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "camera")
                                .foregroundColor(.blue)
                            Text("Front Camera")
                                .font(.headline)
                        }
                        
                        Text("✅ Front camera: Stable 2D tracking")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Button(action: {
                    isPresented = true
                }) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                        Text("Start Vision 2D Test")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Text("Perfect for squats and deadlifts! The 17 joints provide reliable tracking for form analysis.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Skeleton Test")
            .sheet(isPresented: $isPresented) {
                MirrorViewWrapper(
                    isPresented: $isPresented,
                    exercise: selectedExercise,
                    useFrontCamera: true
                )
            }
        }
    }
}

#Preview {
    VisionSkeletonTestView()
}
