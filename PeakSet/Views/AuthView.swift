//
//  AuthenticationView.swift
//  PeakSet Data Collection
//
//  Created by Jeff Fleurima on 9/19/25.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthenticationView: View {
    @ObservedObject var userManager: UserManager
    @Binding var isPresented: Bool
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAnimating = false
    @State private var showingOnboarding = false
    @State private var signedInUser: User?
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var currentNonce: String?
    @State private var showingEmailAuth = false
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    
    // Debug flag to force onboarding - remove in production
    private let forceOnboarding = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with gradient (matching app theme)
                LinearGradient(
                    gradient: Gradient(colors: [AppTheme.background, AppTheme.surface]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Hero Section
                    VStack(spacing: 24) {
                        // Logo (matching app theme)
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(AppTheme.primary)
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimating)
                        
                        // Title and Subtitle
                        VStack(spacing: 12) {
                            Text("Welcome to PeakSet")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.text)
                                .opacity(isAnimating ? 1.0 : 0.8)
                                .animation(.easeInOut(duration: 1).delay(0.5), value: isAnimating)
                            
                            Text("Start your fitness journey with AI-powered form analysis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .opacity(isAnimating ? 1.0 : 0.6)
                                .animation(.easeInOut(duration: 1).delay(0.7), value: isAnimating)
                        }
                    }
                    
                    Spacer()
                    
                    // Features preview
                    HStack(spacing: 20) {
                        FeatureBadge(icon: "figure.strengthtraining.traditional", text: "AI Form")
                        FeatureBadge(icon: "chart.line.uptrend.xyaxis", text: "Progress")
                        FeatureBadge(icon: "waveform", text: "Voice Coach")
                    }
                    .padding(.horizontal)
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: isAnimating)
                    
                    Spacer()
                    
                    // Authentication Options
                    VStack(spacing: 20) {
                        // Apple Sign In Button
                        SignInWithAppleButton(
                            onRequest: { request in
                                let nonce = randomNonceString()
                                currentNonce = nonce
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = sha256(nonce)
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result: result)
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .frame(maxWidth: 350)
                        .cornerRadius(28)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .scaleEffect(isAnimating ? 1.0 : 0.95)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2), value: isAnimating)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal, 16)
                            Rectangle()
                                .fill(AppTheme.textSecondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 32)
                        
                        // Email Authentication Button
                        Button(action: {
                            showingEmailAuth = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18))
                                Text("Continue with Email")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(height: 56)
                            .frame(maxWidth: 350)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(AppTheme.primary)
                            )
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .scaleEffect(isAnimating ? 1.0 : 0.95)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.4), value: isAnimating)
                        
                        // Bottom Info
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.primary)
                                
                                Text("Your data is encrypted and secure")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            Text("Join thousands improving their form daily")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                            
                            Text("Signing in creates your account and you agree to our Terms of Service and Privacy Policy")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 1).delay(1.4), value: isAnimating)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(userEmail: signedInUser?.email)
                .onDisappear {
                    // Complete sign in after onboarding
                    if let user = signedInUser {
                        userManager.currentUser = user
                        userManager.authenticationState = .signedIn(user)
                        isPresented = false
                    }
                }
        }
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView(
                isSignUp: $isSignUp,
                email: $email,
                password: $password,
                confirmPassword: $confirmPassword,
                fullName: $fullName,
                onSignIn: handleEmailSignIn,
                onSignUp: handleEmailSignUp,
                onDismiss: {
                    showingEmailAuth = false
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    fatalError("Invalid state: A login callback was received, but no login request was sent.")
                }
                
                guard let appleIDToken = appleIDCredential.identityToken else {
                    fatalError("Invalid state: A login callback was received, but no login request was sent.")
                }
                
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                    return
                }
                
                Task {
                    do {
                        try await supabaseManager.signInWithApple(
                            idToken: idTokenString,
                            nonce: nonce
                        )
                        
                                await MainActor.run {
                                    // Create user from Supabase response
                                    signedInUser = User(
                                        id: supabaseManager.currentUser?.id.uuidString ?? "",
                                        email: supabaseManager.currentUser?.email,
                                        fullName: supabaseManager.currentUser?.userMetadata["full_name"]?.stringValue,
                                        firstName: supabaseManager.currentUser?.userMetadata["first_name"]?.stringValue,
                                        lastName: supabaseManager.currentUser?.userMetadata["last_name"]?.stringValue,
                                        signInMethod: .apple
                                    )
                                    
                                    // Check if user has completed onboarding
                                    Task {
                                        do {
                                            let existingProfile = try await SupabaseManager.shared.loadUserProfile()
                                            print("🔍 AuthView: Profile check result: \(existingProfile != nil ? "Profile exists" : "No profile found")")
                                            await MainActor.run {
                                                if existingProfile != nil && !forceOnboarding {
                                                    print("🔍 AuthView: User has profile, going to main app")
                                                    // User has completed onboarding, go to main app
                                                    userManager.currentUser = signedInUser
                                                    userManager.authenticationState = .signedIn(signedInUser!)
                                                    isPresented = false
                                                } else {
                                                    print("🔍 AuthView: No profile found or force onboarding enabled, showing onboarding")
                                                    // First time user, show onboarding
                                                    showingOnboarding = true
                                                }
                                            }
                                        } catch {
                                            print("🔍 AuthView: Profile check error: \(error.localizedDescription)")
                                            await MainActor.run {
                                                // If we can't load profile, assume first time user
                                                print("🔍 AuthView: Error loading profile, showing onboarding")
                                                showingOnboarding = true
                                            }
                                        }
                                    }
                                }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Crypto Helper Functions
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Email Authentication Handlers
    
    private func handleEmailSignIn() {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            showError = true
            return
        }
        
        Task {
            do {
                try await supabaseManager.signInWithEmail(email: email, password: password)
                
                await MainActor.run {
                    // Create user from Supabase response
                    signedInUser = User(
                        id: supabaseManager.currentUser?.id.uuidString ?? "",
                        email: supabaseManager.currentUser?.email ?? email,
                        fullName: supabaseManager.currentUser?.userMetadata["full_name"]?.stringValue,
                        firstName: supabaseManager.currentUser?.userMetadata["first_name"]?.stringValue,
                        lastName: supabaseManager.currentUser?.userMetadata["last_name"]?.stringValue,
                        signInMethod: .email
                    )
                    showingEmailAuth = false
                    
                    // Check if user has completed onboarding
                    Task {
                        do {
                            let existingProfile = try await SupabaseManager.shared.loadUserProfile()
                            await MainActor.run {
                                if existingProfile != nil {
                                    // User has completed onboarding, go to main app
                                    userManager.currentUser = signedInUser
                                    userManager.authenticationState = .signedIn(signedInUser!)
                                    isPresented = false
                                } else {
                                    // First time user, show onboarding
                                    showingOnboarding = true
                                }
                            }
                        } catch {
                            await MainActor.run {
                                // If we can't load profile, assume first time user
                                showingOnboarding = true
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func handleEmailSignUp() {
        guard !email.isEmpty && !password.isEmpty && !fullName.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showError = true
            return
        }
        
        if isSignUp && password != confirmPassword {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }
        
        Task {
            do {
                if isSignUp {
                    try await supabaseManager.signUpWithEmail(email: email, password: password, fullName: fullName)
                } else {
                    try await supabaseManager.signInWithEmail(email: email, password: password)
                }
                
                await MainActor.run {
                    // Create user from Supabase response
                    signedInUser = User(
                        id: supabaseManager.currentUser?.id.uuidString ?? "",
                        email: supabaseManager.currentUser?.email ?? email,
                        fullName: supabaseManager.currentUser?.userMetadata["full_name"]?.stringValue ?? fullName,
                        firstName: fullName.components(separatedBy: " ").first,
                        lastName: fullName.components(separatedBy: " ").dropFirst().joined(separator: " "),
                        signInMethod: .email
                    )
                    showingEmailAuth = false
                    
                    // Check if user has completed onboarding
                    Task {
                        do {
                            let existingProfile = try await SupabaseManager.shared.loadUserProfile()
                            await MainActor.run {
                                if existingProfile != nil {
                                    // User has completed onboarding, go to main app
                                    userManager.currentUser = signedInUser
                                    userManager.authenticationState = .signedIn(signedInUser!)
                                    isPresented = false
                                } else {
                                    // First time user, show onboarding
                                    showingOnboarding = true
                                }
                            }
                        } catch {
                            await MainActor.run {
                                // If we can't load profile, assume first time user
                                showingOnboarding = true
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
}

// MARK: - Supporting Views

struct FeatureBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.primary)
            
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct EmailAuthView: View {
    @Binding var isSignUp: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var fullName: String
    let onSignIn: () -> Void
    let onSignUp: () -> Void
    let onDismiss: () -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: isSignUp ? "person.badge.plus" : "envelope.open")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.primary)
                            
                            Text(isSignUp ? "Create Account" : "Welcome Back")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.text)
                            
                            Text(isSignUp ? "Sign up to get started with PeakSet" : "Sign in to continue your fitness journey")
                                .font(.body)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 40)
                        
                        // Form
                        VStack(spacing: 20) {
                            if isSignUp {
                                // Full Name Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Full Name")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.text)
                                    
                                    TextField("Enter your full name", text: $fullName)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(AppTheme.surface)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                        .foregroundColor(AppTheme.text)
                                        .autocapitalization(.words)
                                }
                            }
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.text)
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppTheme.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(AppTheme.text)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.text)
                                
                                SecureField("Enter your password", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppTheme.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(AppTheme.text)
                            }
                            
                            if isSignUp {
                                // Confirm Password Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Confirm Password")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.text)
                                    
                                    SecureField("Confirm your password", text: $confirmPassword)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(AppTheme.surface)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                        .foregroundColor(AppTheme.text)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Action Button
                        Button(action: isSignUp ? onSignUp : onSignIn) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(height: 56)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(AppTheme.primary)
                            )
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 32)
                        
                        // Toggle Sign Up/Sign In
                        Button(action: {
                            isSignUp.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(AppTheme.textSecondary)
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .foregroundColor(AppTheme.primary)
                                    .fontWeight(.medium)
                            }
                            .font(.body)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                }
            }
        }
    }
}

#Preview {
    AuthenticationView(
        userManager: UserManager(),
        isPresented: .constant(true)
    )
}
