# Set - AI Fitness Coach Setup Guide

Welcome to **Set**, an AI-powered fitness coaching app that combines AR form analysis, voice assistance, and intelligent workout tracking.

## 🚀 Quick Start

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ device or simulator
- OpenAI API key (for AI coaching features)
- ElevenLabs API key (recommended for premium voice quality)

### 1. Clone & Setup
```bash
git clone [your-repo-url]
cd Set
```

### 2. Configure API Keys
```bash
# Copy the info template
cp Set/Info.template.plist Set/Info.plist
```

Then edit `Set/Info.plist` and add your API keys:
```xml
<key>OPENAI_API_KEY</key>
<string>your-actual-openai-api-key-here</string>
<key>ELEVENLABS_API_KEY</key>
<string>your-actual-elevenlabs-api-key-here</string>
```

**Get your API keys**:
- **OpenAI**: https://platform.openai.com/api-keys
- **ElevenLabs**: https://elevenlabs.io/ (Free tier available)

### 3. Install Dependencies
```bash
# Dependencies are managed via Swift Package Manager
# They'll be automatically resolved when you open the project
```

### 4. Build & Run
1. Open `Set.xcodeproj` in Xcode
2. Select your target device/simulator
3. Press `Cmd+R` to build and run

## 🏗️ Project Structure

```
Set/
├── AR/                 # ARKit body tracking & form analysis
├── Voice/              # Voice assistant & Picovoice integration
│   ├── AudioSessionManager.swift    # Centralized audio session management
│   ├── ElevenLabsVoiceManager.swift # ElevenLabs AI voice integration
│   └── VoiceAssistantManager.swift # Core voice assistant logic
├── Views/              # SwiftUI views & UI components
├── Models/             # Data models & OpenAI client
├── Theme/              # App theming & design system
├── Info.plist          # API keys (not in git)
└── Info.template.plist # Template for contributors
```

## 🎤 Voice System Setup

### **Required Components:**
- **Picovoice Porcupine**: Custom "Hey Rex" wake word model (included)
- **ElevenLabs API**: For human-like voice synthesis (recommended)
- **OpenAI API**: For intelligent coaching conversations (required)

### **Voice System Features:**
- **Wake Word**: "Hey Rex" - custom trained for gym environments
- **Voice Quality**: ElevenLabs AI voices with Apple TTS fallback
- **Conversation Flow**: 4-second listening window with check-in prompts
- **iOS Simulator**: Fully compatible with smart format detection
- **Audio Management**: Centralized session coordination and conflict resolution

## 🔑 Features

- **AR Form Analysis**: Real-time exercise form correction using ARKit
- **Voice Assistant**: "Hey Rex" wake word detection with ElevenLabs AI voices
- **AI Coaching**: Personalized workout advice powered by OpenAI GPT-4
- **Activity Tracking**: Apple Fitness-style activity rings with HealthKit
- **Exercise Library**: Comprehensive workout database with instructions
- **iOS Simulator Compatible**: Full voice system testing on simulator and device

## 🛡️ Security & Legal Notes

### **API Security**
- `Info.plist` is gitignored and contains sensitive API keys
- Never commit API keys to version control
- Use the template file for new contributors
- Rotate API keys regularly
- Both OpenAI and ElevenLabs keys are required for full functionality

### **⚖️ IMPORTANT: Proprietary License**
- This is **NOT open source** - it's proprietary software
- You may contribute to help improve THIS project only
- You **CANNOT** use this code for your own fitness apps
- You **CANNOT** create competing products or smart mirrors
- All contributions become part of the proprietary codebase
- Read the [LICENSE](LICENSE) file carefully before contributing

## 📱 Testing

The app is designed for gym prototype testing:
- **Voice System**: Fully tested on both iOS Simulator and physical devices
- **AR Features**: Test on physical devices for best AR performance
- **Camera permissions** required for AR features
- **Microphone permissions** needed for voice assistant
- **Audio Session Management**: Robust handling of audio conflicts and format issues
- **Testing is for development of THIS project only**

## 🤝 Contributing Guidelines

### **Before You Contribute**
1. **Read the LICENSE** - Understand this is proprietary software
2. **Contributor Agreement** - Your contributions help THIS project only
3. **No Competing Use** - Cannot use knowledge gained here for other fitness apps

### **How to Contribute**
1. Follow the setup guide above
2. Create feature branches from `main`
3. Focus on improving the existing features and user experience
4. Test thoroughly on device before submitting PRs
5. Never commit sensitive configuration files

### **What We're Looking For**
- UI/UX improvements for the fitness tracking screens
- AR form analysis enhancements
- Voice assistant feature improvements and ElevenLabs integration
- Audio session management and iOS Simulator compatibility
- Performance optimizations for gym environments
- Bug fixes and stability improvements

## 📞 Support

For setup issues or questions, please open an issue or contact jefffleurima15@icloud.com.

---

**Built for the future of fitness coaching** 🏋️‍♂️✨
