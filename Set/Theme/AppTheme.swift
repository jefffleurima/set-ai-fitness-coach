import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let primary = Color("AccentBlue")
    static let secondary = Color("Surface")
    static let accent = Color("AccentBlue")
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let text = Color("Text")
    static let textSecondary = Color("TextSecondary")
    
    // MARK: - Animation Constants
    static let defaultAnimation: Animation = .easeInOut(duration: 0.3)
    static let buttonAnimation = Animation.spring(response: 0.2, dampingFraction: 0.6)
    static let transitionAnimation = Animation.spring(response: 0.4, dampingFraction: 0.8)
    
    // MARK: - View Modifiers
    struct CardStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding()
                .background(AppTheme.surface)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    struct PrimaryButtonStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppTheme.primary)
                .cornerRadius(10)
                .shadow(color: AppTheme.primary.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(AppTheme.CardStyle())
    }
    
    func primaryButtonStyle() -> some View {
        modifier(AppTheme.PrimaryButtonStyle())
    }
}
// Force re-indexing 