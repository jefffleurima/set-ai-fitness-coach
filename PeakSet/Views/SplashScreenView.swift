import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.5
    @State private var logoRotation = 0.0
    @State private var textOpacity = 0.0
    @State private var textOffset: CGFloat = 50
    @State private var buttonOpacity = 0.0
    @State private var buttonScale = 0.5
    @State private var gradientStart = UnitPoint(x: 0, y: 0)
    @State private var gradientEnd = UnitPoint(x: 1, y: 1)

    var body: some View {
        if isActive {
            MainAppView()
        } else {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [AppTheme.background, AppTheme.surface]), startPoint: gradientStart, endPoint: gradientEnd)
                    .ignoresSafeArea()
                    .animation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: true), value: gradientStart)
                    .animation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: true), value: gradientEnd)
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    // App Logo
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(AppTheme.primary)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .rotationEffect(.degrees(logoRotation))
                        .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.5), value: logoScale)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: logoOpacity)
                        .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.5), value: logoRotation)
                    
                    // App Name
                    Text("P E A K S E T")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .kerning(8)
                        .foregroundColor(AppTheme.text)
                        .opacity(textOpacity)
                        .offset(y: textOffset)
                        .animation(.easeOut(duration: 0.7).delay(0.7), value: textOpacity)
                        .animation(.easeOut(duration: 0.7).delay(0.7), value: textOffset)

                    // App Subtitle
                    Text("AI-Driven Fitness. Real-Time Form. Next-Level Results.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(textOpacity)
                        .offset(y: textOffset)
                        .animation(.easeOut(duration: 0.7).delay(0.9), value: textOpacity)
                        .animation(.easeOut(duration: 0.7).delay(0.9), value: textOffset)
                    
                    // Brief Description
                    Text("Meet your intelligent gym coach. Analyze, improve, and elevate every rep—instantly.")
                        .font(.headline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(textOpacity)
                        .offset(y: textOffset)
                        .animation(.easeOut(duration: 0.7).delay(1.1), value: textOpacity)
                        .animation(.easeOut(duration: 0.7).delay(1.1), value: textOffset)
                    
                    Spacer()
                    
                    // Get Started Button
                    Button(action: {
                        withAnimation {
                            isActive = true
                        }
                    }) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.primary)
                            .cornerRadius(25)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 40)
                }
                .onAppear {
                    withAnimation(AppTheme.transitionAnimation) {
                        self.logoOpacity = 1.0
                        self.logoScale = 1.0
                        self.logoRotation = 360.0
                        self.textOpacity = 1.0
                        self.textOffset = 0
                        self.buttonOpacity = 1.0
                        self.buttonScale = 1.0
                        
                        // Animate gradient for background
                        self.gradientStart = UnitPoint(x: 1, y: 1)
                        self.gradientEnd = UnitPoint(x: 0, y: 0)
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
} 
