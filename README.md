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

### 🎤 **Rex Voice AI System**
- 🎙️ **"Hey Rex" wake word detection** - Custom trained model for gym environments
- 🗣️ **Human-like voice responses** - Natural speech patterns, not robotic
- 💬 **Continuous conversation flow** - 3-second listening after responses
- 🧠 **Comprehensive knowledge** - Fitness, nutrition, supplements, health guidance
- ⚡ **Ultra-responsive** - 2-second max response time with smart delays
- 🎯 **Contextual coaching** - Knows your workout and provides targeted advice

### 📊 **Activity Tracking**
- Apple Fitness-style activity rings
- HealthKit integration for comprehensive metrics
- Workout history and progress tracking
- Calorie, steps, and distance monitoring

## 🤖 **Meet Rex - Your AI Coach**

Rex isn't just a voice assistant - he's your intelligent fitness companion:

### **🎯 What Makes Rex Special:**
- **"Hey Rex"** - Natural wake word that won't conflict with other assistants
- **Premium voice quality** - Sounds like a real personal trainer, not a robot
- **Smart conversation** - Remembers context, no need to repeat "Hey Rex" constantly
- **Broad expertise** - Ask about workouts, nutrition, supplements, recovery, anything fitness-related
- **Instant responses** - Get coaching advice without breaking your flow

### **💬 Try Asking Rex:**
- *"Hey Rex, how's my squat form looking?"*
- *"What protein should I take after this workout?"*
- *"Tell me about creatine supplementation"*
- *"How much rest should I take between sets?"*
- *"What should I eat for muscle growth?"*

## 🚀 Getting Started

See [SETUP.md](SETUP.md) for detailed installation and configuration instructions.

## 🏗️ Architecture

Built with modern iOS development practices and premium voice AI:

### **🎤 Rex Voice System:**
- **Picovoice Porcupine** - Custom "Hey Rex" wake word model
- **iOS Speech Framework** - Advanced speech recognition with noise filtering
- **AVFoundation** - Professional audio session management
- **OpenAI GPT-4** - Intelligent conversational AI with fitness expertise

### **📱 Core Technologies:**
- **SwiftUI** - Responsive, declarative user interface
- **ARKit** - Real-time body tracking and pose estimation
- **Vision Framework** - Computer vision for form analysis
- **HealthKit** - Comprehensive fitness data integration
- **Core ML** - On-device machine learning capabilities


## 🧪 Testing

Designed and tested for real-world gym environments:

### **🎤 Rex Voice Testing:**
- **Noise-resistant** - Works with background music and gym equipment sounds
- **Natural conversation** - Tested for human-like interaction patterns
- **Response speed** - Validated 2-second max response times
- **Knowledge accuracy** - Verified fitness, nutrition, and health expertise

### **🏋️ Gym Environment:**
- **Various lighting conditions** - From dark to bright gym lighting
- **Multiple exercise types** - Tested across different workout movements
- **Professional validation** - Reviewed by certified fitness trainers
- **Investor-ready demos** - Polished for professional presentations

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
