import Foundation

// MARK: - App Configuration
// This is a template file. Copy this to Config.swift and add your actual API keys.

struct AppConfig {
    // MARK: - API Keys
    // Get your OpenAI API key from: https://platform.openai.com/api-keys
    static let apiKey = "YOUR_OPENAI_API_KEY_HERE"
    
    // MARK: - App Settings
    static let appName = "Set"
    static let version = "1.0.0"
    
    // MARK: - Debug Settings
    static let isDebugMode = true
    static let enableLogging = true
}

// MARK: - Setup Instructions
/*
 🔧 SETUP INSTRUCTIONS FOR NEW CONTRIBUTORS:
 
 1. Copy this file to Config.swift:
    cp Config.template.swift Config.swift
 
 2. Get your OpenAI API key:
    - Go to https://platform.openai.com/api-keys
    - Create a new API key
    - Replace "YOUR_OPENAI_API_KEY_HERE" with your actual key
 
 3. Never commit Config.swift to git (it's in .gitignore)
 
 ⚠️ SECURITY WARNING:
 - Never share your API keys
 - Never commit Config.swift to version control
 - Keep your API keys secure and rotate them regularly
*/
