# Set - AI Fitness Coach Setup Guide

Welcome to **Set**, an AI-powered fitness coaching app that combines AR form analysis, voice assistance, and intelligent workout tracking.

## 🚀 Quick Start

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ device or simulator
- OpenAI API key (for AI coaching features)

### 1. Clone & Setup
```bash
git clone [your-repo-url]
cd Set
```

### 2. Configure API Keys
```bash
# Copy the config template
cp Set/Config.template.swift Set/Config.swift
```

Then edit `Set/Config.swift` and add your OpenAI API key:
```swift
static let apiKey = "your-actual-openai-api-key-here"
```

**Get your OpenAI API key**: https://platform.openai.com/api-keys

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
├── Views/              # SwiftUI views & UI components
├── Models/             # Data models & OpenAI client
├── Theme/              # App theming & design system
├── Config.swift        # API keys (not in git)
└── Config.template.swift # Template for contributors
```

## 🔑 Features

- **AR Form Analysis**: Real-time exercise form correction using ARKit
- **Voice Assistant**: "Hey Coach" wake word detection and voice commands
- **AI Coaching**: Personalized workout advice powered by OpenAI
- **Activity Tracking**: Apple Fitness-style activity rings with HealthKit
- **Exercise Library**: Comprehensive workout database with instructions

## 🛡️ Security & Legal Notes

### **API Security**
- `Config.swift` is gitignored and contains sensitive API keys
- Never commit API keys to version control
- Use the template file for new contributors
- Rotate API keys regularly

### **⚖️ IMPORTANT: Proprietary License**
- This is **NOT open source** - it's proprietary software
- You may contribute to help improve THIS project only
- You **CANNOT** use this code for your own fitness apps
- You **CANNOT** create competing products or smart mirrors
- All contributions become part of the proprietary codebase
- Read the [LICENSE](LICENSE) file carefully before contributing

## 📱 Testing

The app is designed for gym prototype testing:
- Test on physical devices for best AR performance
- Camera permissions required for AR features
- Microphone permissions needed for voice assistant
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
- Voice assistant feature improvements
- Performance optimizations for gym environments
- Bug fixes and stability improvements

## 📞 Support

For setup issues or questions, please open an issue or contact the team.

---

**Built for the future of fitness coaching** 🏋️‍♂️✨
