//
//  User.swift
//  PeakSet Data Collection
//
//  Created by Jeff Fleurima on 9/19/25.
//

import Foundation
import AuthenticationServices

// MARK: - User Model
struct User: Identifiable, Codable {
    let id: String
    let email: String?
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let signInMethod: SignInMethod
    let createdAt: Date
    let lastSignIn: Date
    
    enum SignInMethod: String, Codable, CaseIterable {
        case apple = "apple"
        case email = "email"
    }
    
    init(id: String, email: String? = nil, fullName: String? = nil, firstName: String? = nil, lastName: String? = nil, signInMethod: SignInMethod) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.firstName = firstName
        self.lastName = lastName
        self.signInMethod = signInMethod
        self.createdAt = Date()
        self.lastSignIn = Date()
    }
}

// MARK: - Authentication State
enum AuthenticationState {
    case loading
    case signedIn(User)
    case signedOut
    case error(String)
}

// MARK: - User Manager
class UserManager: NSObject, ObservableObject {
    @Published var authenticationState: AuthenticationState = .loading
    @Published var currentUser: User?
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "current_user"
    
    override init() {
        super.init()
        checkAuthenticationState()
    }
    
    // MARK: - Apple Sign In
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // MARK: - Sign Out
    func signOut() {
        Task {
            do {
                try await SupabaseManager.shared.signOut()
            } catch {
                print("❌ UserManager: Error signing out from Supabase: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                currentUser = nil
                authenticationState = .signedOut
                userDefaults.removeObject(forKey: userKey)
            }
        }
    }
    
    // MARK: - Authentication State Management
    private func checkAuthenticationState() {
        print("🔄 UserManager: Checking authentication state...")
        Task {
            await MainActor.run {
                authenticationState = .loading
            }
            
            // Wait for SupabaseManager to complete session check
            print("⏳ UserManager: Waiting for SupabaseManager to restore session...")
            let supabaseManager = SupabaseManager.shared
            
            // Poll until session check is complete (max 10 seconds)
            var attempts = 0
            while !supabaseManager.sessionCheckComplete && attempts < 100 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                attempts += 1
            }
            
            if attempts >= 100 {
                print("⚠️ UserManager: Session check timeout after 10 seconds")
            } else {
                print("✅ UserManager: Session check completed after \(attempts * 100)ms")
            }
            
            print("🔍 UserManager: Checking SupabaseManager state...")
            print("   isSignedIn: \(supabaseManager.isSignedIn)")
            print("   currentUser: \(supabaseManager.currentUser?.email ?? "nil")")
            
            if supabaseManager.isSignedIn, let supabaseUser = supabaseManager.currentUser {
                // User is signed in with Supabase, create our User object
                print("✅ UserManager: Found valid Supabase session, creating User object...")
                let user = User(
                    id: supabaseUser.id.uuidString,
                    email: supabaseUser.email,
                    fullName: supabaseUser.userMetadata["full_name"]?.stringValue,
                    firstName: supabaseUser.userMetadata["first_name"]?.stringValue,
                    lastName: supabaseUser.userMetadata["last_name"]?.stringValue,
                    signInMethod: .email // Default to email, could be enhanced
                )
                
                await MainActor.run {
                    self.currentUser = user
                    self.authenticationState = .signedIn(user)
                    self.saveUser(user)
                }
                
                print("✅ UserManager: User session restored from Supabase: \(supabaseUser.email ?? "unknown")")
            } else {
                await MainActor.run {
                    self.currentUser = nil
                    self.authenticationState = .signedOut
                }
                print("❌ UserManager: No valid session found - user will need to sign in")
            }
        }
    }
    
    // MARK: - Save/Load User
    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            userDefaults.set(data, forKey: userKey)
        }
    }
    
    private func handleAppleSignInSuccess(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authenticationState = .error("Invalid Apple ID credential")
            return
        }
        
        let userIdentifier = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        let firstName = fullName?.givenName
        let lastName = fullName?.familyName
        
        let user = User(
            id: userIdentifier,
            email: email,
            fullName: fullName.map { "\($0.givenName ?? "") \($0.familyName ?? "")".trimmingCharacters(in: .whitespaces) },
            firstName: firstName,
            lastName: lastName,
            signInMethod: .apple
        )
        
        self.currentUser = user
        self.authenticationState = .signedIn(user)
        saveUser(user)
        
        print("✅ UserManager: Apple Sign In successful for user: \(userIdentifier)")
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension UserManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleAppleSignInSuccess(authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let errorMessage = (error as NSError).localizedDescription
        authenticationState = .error(errorMessage)
        print("❌ UserManager: Apple Sign In failed: \(errorMessage)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension UserManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign In")
        }
        return window
    }
}
