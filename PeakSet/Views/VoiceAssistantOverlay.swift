import SwiftUI

struct VoiceAssistantOverlay: View {
    @EnvironmentObject var voiceAssistant: VoiceAssistantManager

    var body: some View {
        VStack(spacing: 15) {
            // Feedback message bubble with better text handling
            if let message = voiceAssistant.feedbackMessage, !message.isEmpty, !voiceAssistant.isListening, message != "Listening..." {
                ScrollView {
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.8))
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))
                }
                .frame(maxHeight: 200)
            }
            
            // Main assistant controls
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
                                lineWidth: voiceAssistant.isListening ? 2 : 1)
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
                
                // Context-sensitive status text
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .transition(.opacity)
                
                // Test button for debugging (only show in debug builds)
                #if DEBUG
                Button("Test Conversation") {
                    voiceAssistant.testConversation()
                }
                .font(.caption2)
                .foregroundColor(.blue)
                .padding(.top, 5)
                #endif
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: voiceAssistant.isListening)
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if voiceAssistant.isListening {
            return "Listening..."
        } else {
            return "Say 'Hey Rex' for help"
        }
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