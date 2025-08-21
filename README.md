# Set - AI Fitness Coach

> **Revolutionizing fitness coaching through AR, AI, and voice assistance**

An intelligent iOS fitness app that combines real-time form analysis, AI coaching, and comprehensive activity tracking to create the future of workout experiences.

## 🌟 Key Features

### 🤖 **AI-Powered Coaching**
- Real-time exercise form correction and feedback
- Personalized workout recommendations
- Post-exercise analysis and improvement suggestions
- Natural language coaching powered by OpenAI

### 📱 **AR Form Analysis**
- Live body tracking using ARKit
- 3D pose estimation and form validation
- Visual feedback overlays during workouts
- Computer vision-based movement analysis

### 🎤 **Voice Assistant**
- "Hey Rex" wake word detection
- Hands-free workout control
- Voice-activated exercise selection
- Conversational fitness guidance

### 📊 **Activity Tracking**
- Apple Fitness-style activity rings
- HealthKit integration for comprehensive metrics
- Workout history and progress tracking
- Calorie, steps, and distance monitoring


## 🚀 Getting Started

See [SETUP.md](SETUP.md) for detailed installation and configuration instructions.

## 🏗️ Architecture

Built with modern iOS development practices:
- **SwiftUI** for responsive, declarative UI
- **ARKit** for real-time body tracking
- **HealthKit** for fitness data integration
- **Picovoice** for "Hey Rex" wake word detection
- **OpenAI API** for intelligent coaching


## 🧪 Testing

Designed for real-world gym environments:
- Optimized for various lighting conditions
- Tested across different exercise types
- Validated with fitness professionals
- Ready for investor demonstrations

## 🤝 Contributing

We welcome contributors who share our vision of revolutionizing fitness technology:

1. **Setup**: Follow the [SETUP.md](SETUP.md) guide
2. **Security**: Never commit API keys or sensitive data
3. **Quality**: Test thoroughly on physical devices
4. **Innovation**: Help us build the future of fitness coaching

## 📄 License

This project is licensed under a **Proprietary Software License** - see the [LICENSE](LICENSE) file for complete terms.

### 🔒 **Key Restrictions**
- ✅ **Contributions Welcome** - Help improve this specific project
- ✅ **Educational Use** - Learn from the code and techniques
- ❌ **No Commercial Use** - Cannot be used commercially without permission
- ❌ **No Distribution** - Cannot be shared or redistributed
- ❌ **No Competing Products** - Cannot create similar fitness/gym software

## 🔐 Security & API Keys

### **API Key Management:**
- ✅ **Info.plist**: Safe for development (excluded from git)
- ❌ **Never hardcode**: Don't put keys directly in Swift files
- 📋 **Use template**: Copy `Info.template.plist` → `Info.plist` and add your key

### **For Contributors:**
```bash
# 1. Setup your Info.plist
cp Set/Info.template.plist Set/Info.plist

# 2. Add your OpenAI API key to Info.plist
# Replace "YOUR_OPENAI_API_KEY_HERE" with your actual key

# 3. Never commit Info.plist with real keys!
```

**⚠️ Your API key is automatically protected by `.gitignore`**

## 📞 Contact

For collaboration opportunities, technical questions, or investment inquiries, please reach out through GitHub issues.

---

**Building the future of intelligent fitness coaching** 🏋️‍♂️✨
