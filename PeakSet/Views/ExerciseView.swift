import SwiftUI
import UIKit

struct ExerciseView: View {
    @AppStorage("userName") private var userName: String = ""
    @State private var selectedExercise: ExerciseCardData? = nil
    @State private var animateGrid = false
    @State private var showWorkoutCamera = false
    @State private var workoutExercise: Exercise? = nil
    @State private var showNoMatchAlert = false
    @State private var fadeIn = false
    
    // Example exercises with system images
    private let exercises: [ExerciseCardData] = [
        ExerciseCardData(name: "Squat", muscle: "Glutes", description: "A fundamental lower body exercise targeting glutes, quads, and hamstrings.", imageName: "figure.strengthtraining.traditional", tips: ["Keep your back straight", "Knees behind toes", "Go as deep as possible"]),
        ExerciseCardData(name: "Deadlift", muscle: "Glutes", description: "A compound movement for glutes, hamstrings, and lower back.", imageName: "figure.strengthtraining.functional", tips: ["Hinge at hips", "Keep bar close", "Drive through heels"]),

    ]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        welcomeSection
                        exerciseGrid
                    }
                    .padding(.vertical, 32)
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.7), value: fadeIn)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedExercise) { exercise in
                ExerciseDetailSheet(exercise: exercise, onStartWorkout: {
                        // Fix name matching - map UI names to Exercise model names
                        let exerciseNameMap = [
                            "Squat": "squats",
                            "Deadlift": "deadlifts"
                        ]
                        
                        let modelName = exerciseNameMap[exercise.name] ?? exercise.name.lowercased()
                        
                        if let match = Exercise.database.first(where: { $0.name.localizedCaseInsensitiveContains(modelName) }) {
                            print("✅ ExerciseView: Found exercise match for \(exercise.name) -> \(match.name)")
                            workoutExercise = match
                            showWorkoutCamera = true
                        } else {
                            print("❌ ExerciseView: No exercise match found for \(exercise.name) (mapped to \(modelName))")
                            showNoMatchAlert = true
                        }
                        selectedExercise = nil // Dismiss sheet by clearing selection
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .fullScreenCover(item: $workoutExercise) { exercise in
                MirrorViewWrapper(exercise: exercise)
            }
            .alert(isPresented: $showNoMatchAlert) {
                Alert(title: Text("Exercise Not Found"), message: Text("Sorry, this exercise is not available for camera tracking yet."), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    animateGrid = true
                }
                withAnimation(.easeOut(duration: 0.7)) {
                    fadeIn = true
                }
            }
        }
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome, \(userName.isEmpty ? "Athlete" : userName)!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.text)
                .padding(.bottom, 2)
            AnimatedAccentBar()
                .frame(height: 4)
                .padding(.bottom, 4)
            Text("Let's fix your form")
                .font(.title3)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal)
    }
    
    private var exerciseGrid: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(Array(exercises.enumerated()), id: \ .element.id) { index, exercise in
                ExerciseImageCard(
                    exercise: exercise,
                    animate: animateGrid,
                    animationDelay: Double(index) * 0.08
                ) {
                    print("🔄 ExerciseView: Exercise card tapped - \(exercise.name)")
                    print("🔄 ExerciseView: Current selectedExercise: \(selectedExercise?.name ?? "nil")")
                    
                    Haptics.tap()
                    
                    // Set selected exercise to trigger sheet presentation
                    selectedExercise = exercise
                    print("✅ ExerciseView: selectedExercise updated to: \(selectedExercise?.name ?? "nil")")
                }
            }
        }
        .padding(.horizontal)
    }
}

struct ExerciseCardData: Identifiable {
    let id = UUID()
    let name: String
    let muscle: String
    let description: String
    let imageName: String // SF Symbol name
    let tips: [String]
}

struct ExerciseImageCard: View {
    let exercise: ExerciseCardData
    let animate: Bool
    let animationDelay: Double
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(AppTheme.surface)
                .shadow(color: AppTheme.primary.opacity(0.18), radius: 16, x: 0, y: 8)
                .overlay(
                    ZStack {
                        Image(systemName: exercise.imageName)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(AppTheme.primary)
                            .opacity(0.7)
                            .padding(24)
                        // Gradient overlay for text contrast
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.45)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(24)
                    }
                )
                .frame(height: 180)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                Text(exercise.muscle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(radius: 2)
            }
            .padding(16)
        }
        .scaleEffect(isPressed ? 0.94 : (animate ? 1 : 0.8))
        .opacity(animate ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay), value: animate)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isPressed = false
                onTap()
            }
        }
    }
}

struct ExerciseDetailSheet: View {
    let exercise: ExerciseCardData
    let onStartWorkout: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var animateContent = false
    
    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.circle.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("AI Coach")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
                Spacer()
            }
            .padding(.top, 24)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 10)
            .animation(.easeOut(duration: 0.4).delay(0.05), value: animateContent)
            
            Image(systemName: exercise.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(AppTheme.primary)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: animateContent)
            
            Text(exercise.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.text)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: animateContent)
            
            Text(exercise.muscle)
                .font(.title3)
                .foregroundColor(AppTheme.textSecondary)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: animateContent)
            
            Text(exercise.description)
                .font(.body)
                .foregroundColor(AppTheme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: animateContent)
            
            Divider()
                .opacity(animateContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.45), value: animateContent)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Form Tips")
                    .font(.headline)
                    .foregroundColor(AppTheme.primary)
                ForEach(exercise.tips, id: \ .self) { tip in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: animateContent)
            
            Spacer()
            
            Button(action: {
                Haptics.impact()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    onStartWorkout()
                }
            }) {
                Text("Start Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primary)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                    .scaleEffect(animateContent ? 1 : 0.95)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6), value: animateContent)
            }
            .padding(.horizontal)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.6), value: animateContent)
            
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.top, 8)
            }
            .opacity(animateContent ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.7), value: animateContent)
            
            Spacer(minLength: 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            animateContent = true
        }
    }
}

struct AnimatedAccentBar: View {
    @State private var animate = false
    var body: some View {
        Capsule()
            .fill(LinearGradient(gradient: Gradient(colors: [AppTheme.primary, AppTheme.primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing))
            .frame(width: animate ? 120 : 0)
            .opacity(animate ? 1 : 0.3)
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animate)
            .onAppear { animate = true }
    }
}

struct Haptics {
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    static func impact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    ExerciseView()
}
