import SwiftUI
import ARKit

struct VoiceAssistantOverlay: View {
    @EnvironmentObject var voiceAssistant: VoiceAssistantManager
    @ObservedObject var viewModel: AICoachViewModel
    
    // Animation states
    @State private var showFormTips = false
    @State private var activeTipIndex = 0
    @State private var isShowingExerciseDemo = false
    
    // Form feedback animation
    @Namespace private var feedbackAnimation
    
    var body: some View {
        VStack(spacing: 15) {
            // Combined feedback area for both voice and form analysis
            feedbackDisplay
            
            // Main assistant controls
            assistantControls
            
            // Exercise-specific tips when available
            if showFormTips, let currentExercise = viewModel.currentWorkoutContext?.exercise {
                exerciseTipsView(for: currentExercise)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: voiceAssistant.isListening)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.7), value: viewModel.currentPoseAnalysis)
        .onChange(of: viewModel.currentPoseAnalysis) { newAnalysis in
            handleNewPoseAnalysis(newAnalysis)
        }
    }
    
    // MARK: - Subviews
    
    private var feedbackDisplay: some View {
        Group {
            if let message = voiceAssistant.feedbackMessage, !message.isEmpty, !voiceAssistant.isListening {
                // Voice feedback message
                FeedbackBubble(text: message, type: .voice)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    )
            } else if let analysis = viewModel.currentPoseAnalysis, analysis.overallScore < 80 {
                // Form feedback when score is low
                FormFeedbackView(analysis: analysis)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    )
            }
        }
    }
    
    private var assistantControls: some View {
        VStack(spacing: 10) {
            ZStack {
                // Background with interactive effect
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.4), Color.black.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .overlay(
                        Circle()
                            .stroke(voiceAssistant.isListening ? Color.blue : Color.white.opacity(0.2), 
                            lineWidth: voiceAssistant.isListening ? 2 : 1
                    )
                    .scaleEffect(voiceAssistant.isListening ? 1.05 : 1.0)
                
                if voiceAssistant.isListening {
                    PulsingListeningView()
                }
                
                // Icon with context-sensitive appearance
                Image(systemName: voiceAssistant.isListening ? "waveform.circle.fill" : "waveform")
                    .font(.title)
                    .foregroundColor(voiceAssistant.isListening ? .blue : .white.opacity(0.8))
                    .symbolEffect(.bounce, options: .speed(0.5), value: voiceAssistant.isListening)
            }
            .onTapGesture {
                voiceAssistant.toggleListening()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                showFormTips.toggle()
            }
            
            // Context-sensitive status text
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .transition(.opacity)
        }
    }
    
    private func exerciseTipsView(for exercise: String) -> some View {
        VStack(spacing: 8) {
            if let analyzer = viewModel.formAnalyzers[exercise.lowercased()] {
                Text("\(exercise.capitalized) Tips")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                TabView(selection: $activeTipIndex) {
                    ForEach(Array(analyzer.tips.enumerated()), id: \.offset) { index, tip in
                        Text(tip)
                            .font(.footnote)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 80)
                
                if let demoVideoURL = analyzer.demoVideoURL {
                    Button(action: {
                        isShowingExerciseDemo = true
                    }) {
                        Label("Watch Demo", systemImage: "play.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $isShowingExerciseDemo) {
                        VideoPlayerView(url: demoVideoURL)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.75))
                .shadow(radius: 5)
        )
        .transition(.move(edge: .bottom))
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if voiceAssistant.isListening {
            return "Listening..."
        } else if viewModel.currentWorkoutContext?.exercise != nil {
            return "Tap & hold for form tips"
        } else {
            return "Say 'Hey Coach' for help"
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleNewPoseAnalysis(_ analysis: PoseAnalysisResult?) {
        guard let analysis = analysis else { return }
        
        // Show tips automatically when form is poor
        if analysis.overallScore < 70 && !showFormTips {
            withAnimation {
                showFormTips = true
            }
        }
        
        // Hide tips when form improves
        if analysis.overallScore > 85 && showFormTips {
            withAnimation {
                showFormTips = false
            }
        }
    }
}

// MARK: - Component Views

struct FeedbackBubble: View {
    let text: String
    let type: FeedbackType
    
    enum FeedbackType {
        case voice
        case form
    }
    
    var body: some View {
        ScrollView {
            Text(text)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(maxHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(type == .voice ? Color.black.opacity(0.75) : Color.blue.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct FormFeedbackView: View {
    let analysis: PoseAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Form Score: \(analysis.overallScore)/100")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Visual score indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(scoreColor)
                    .frame(width: CGFloat(analysis.overallScore) / 100 * 150, height: 8)
            }
            
            if let primaryIssue = analysis.issues.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus on:")
                        .font(.caption)
                        .opacity(0.8)
                    
                    Text(primaryIssue.message)
                        .font(.footnote)
                        .bold()
                }
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.blue.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var scoreColor: Color {
        switch analysis.overallScore {
        case 0..<50: return .red
        case 50..<75: return .orange
        case 75..<90: return .yellow
        default: return .green
        }
    }
}

struct PulsingListeningView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                let scale = 1.0 + (0.2 * Double(index + 1))
                let opacity = 1.0 - (0.3 * Double(index))
                
                Circle()
                    .stroke(Color.blue.opacity(opacity), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isAnimating ? scale : 1.0)
                    .opacity(isAnimating ? 0 : opacity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

struct VoiceAssistantOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            VoiceAssistantOverlay(viewModel: AICoachViewModel())
                .environmentObject(VoiceAssistantManager())
        }
        .previewLayout(.sizeThatFits)
    }
}