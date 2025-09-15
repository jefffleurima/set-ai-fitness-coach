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
} 