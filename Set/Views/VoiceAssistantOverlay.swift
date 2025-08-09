import SwiftUI

struct VoiceAssistantOverlay: View {
    @EnvironmentObject var voiceAssistant: VoiceAssistantManager

    var body: some View {
        VStack(spacing: 15) {
            // Feedback message bubble with better text handling
            if let message = voiceAssistant.feedbackMessage, !message.isEmpty, !voiceAssistant.isListening, message != "Listening..." {
                ScrollView {
                    Text(message)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .frame(maxHeight: 120) // Limit height for very long messages
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.75))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            }

            // Hands-free indicator with improved design
            VStack(spacing: 10) {
                ZStack {
                    // Background circle with gradient
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
                    
                    if voiceAssistant.isListening {
                        PulsingListeningView()
                    }

                    // Icon with better styling
                    Image(systemName: voiceAssistant.isListening ? "waveform.circle.fill" : "waveform")
                        .font(.title)
                        .foregroundColor(voiceAssistant.isListening ? .blue : .white.opacity(0.8))
                        .scaleEffect(voiceAssistant.isListening ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: voiceAssistant.isListening)
                }
                
                // Status text with better typography
                Text(voiceAssistant.isListening ? "Listening..." : "Say 'Hey Coach' for help")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .animation(.easeInOut(duration: 0.3), value: voiceAssistant.isListening)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: voiceAssistant.isListening)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: voiceAssistant.feedbackMessage)
    }
}

struct PulsingListeningView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Outer pulse
            Circle()
                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                .frame(width: 70, height: 70)
                .scaleEffect(isAnimating ? 1.6 : 1.0)
                .opacity(isAnimating ? 0 : 1)
            
            // Middle pulse
            Circle()
                .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                .frame(width: 70, height: 70)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .opacity(isAnimating ? 0.3 : 0)
        
            // Inner pulse
            Circle()
                .stroke(Color.blue.opacity(0.8), lineWidth: 2)
                .frame(width: 70, height: 70)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .opacity(isAnimating ? 0.6 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
} 