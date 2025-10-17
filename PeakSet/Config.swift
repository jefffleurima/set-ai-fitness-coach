import Foundation

enum AppConfig {
    static var apiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              key != "YOUR_OPENAI_API_KEY_HERE" && !key.isEmpty else {
            print("❌ AppConfig: OpenAI API key not found or invalid in Info.plist")
            return ""
        }
        return key
    }
    
    static var elevenLabsApiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_API_KEY") as? String,
              key != "YOUR_ELEVENLABS_API_KEY_HERE" && !key.isEmpty else {
            print("❌ AppConfig: ElevenLabs API key not found or invalid in Info.plist")
            return ""
        }
        return key
    }
    
    // MARK: - Supabase Configuration
    static var supabaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              url != "YOUR_SUPABASE_URL_HERE" && !url.isEmpty else {
            print("❌ AppConfig: Supabase URL not found or invalid in Info.plist")
            return ""
        }
        return url
    }
    
    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              key != "YOUR_SUPABASE_ANON_KEY_HERE" && !key.isEmpty else {
            print("❌ AppConfig: Supabase anon key not found or invalid in Info.plist")
            return ""
        }
        return key
    }
    
    // MARK: - Configuration Validation
    static var isSupabaseConfigured: Bool {
        return !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }
    
    static func validateSupabase() throws {
        guard isSupabaseConfigured else {
            throw SupabaseError.configurationMissing
        }
        
        guard URL(string: supabaseURL) != nil else {
            throw SupabaseError.invalidURL
        }
        
        guard !supabaseAnonKey.isEmpty else {
            throw SupabaseError.invalidKey
        }
    }
}

// MARK: - Supabase Errors
enum SupabaseError: Error, LocalizedError {
    case configurationMissing
    case invalidURL
    case invalidKey
    case userNotAuthenticated
    case profileNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "Supabase configuration is missing. Please add SUPABASE_URL and SUPABASE_ANON_KEY to Info.plist."
        case .invalidURL:
            return "Invalid Supabase URL format in Info.plist."
        case .invalidKey:
            return "Invalid Supabase anon key in Info.plist."
        case .userNotAuthenticated:
            return "User not authenticated"
        case .profileNotFound:
            return "User profile not found"
        case .networkError:
            return "Network error occurred"
        }
    }
} 