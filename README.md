# PeakSet - AI Fitness Coach

> **Revolutionizing fitness coaching through AR, AI, and voice assistance**

An intelligent iOS fitness app that combines real-time form analysis, AI coaching, and comprehensive activity tracking to create the future of workout experiences.

## 🌟 Key Features

### 🤖 **AI-Powered Coaching**
- Real-time exercise form correction and feedback
- Personalized workout recommendations
- Post-exercise analysis and improvement suggestions
- Natural language coaching powered by OpenAI

### 📱 **AR Form Analysis**
- Real-time 3D pose detection using ARKit and Vision framework
- Comprehensive form analysis with exercise-specific criteria
- Visual skeleton overlay with joint tracking
- Rep counting and form quality scoring
- Safety warnings and improvement tips

### 🎤 **Rex Voice AI System**
- 🎙️ **"Hey Rex" wake word detection** - Custom trained model for gym environments
- 🗣️ **Human-like voice responses** - ElevenLabs AI voices, not robotic Apple TTS
- 💬 **Continuous conversation flow** - 4-second listening after responses with check-in prompts
- 🧠 **Comprehensive knowledge** - Fitness, nutrition, supplements, health guidance
- ⚡ **Ultra-responsive** - 2-second max response time with smart delays
- 🎯 **Contextual coaching** - Knows your workout and provides targeted advice
- 🔧 **iOS Simulator compatible** - Works perfectly on both real devices and simulator
- 🎵 **Robust audio handling** - Smart format detection and fallback systems
- ♿ **VoiceOver compatibility** - Built-in accessibility support

### 📊 **Activity Tracking**
- Apple Fitness-style activity rings with daily/weekly views
- Comprehensive HealthKit integration for all fitness metrics
- Real-time step count, calories, and distance tracking
- Workout session history and progress analysis
- Hourly activity breakdowns and trends

## 🤖 **Meet Rex - Your AI Coach**

Rex isn't just a voice assistant - he's your intelligent fitness companion:

### **🎯 What Makes Rex Special:**
- **"Hey Rex"** - Natural wake word that won't conflict with other assistants
- **Premium voice quality** - ElevenLabs AI voices that sound like real personal trainers
- **Smart conversation** - Remembers context, no need to repeat "Hey Rex" constantly
- **Broad expertise** - Ask about workouts, nutrition, supplements, recovery, anything fitness-related
- **Instant responses** - Get coaching advice without breaking your flow

### **💬 Try Asking Rex:**
- *"Hey Rex, how's my squat form looking?"*
- *"What protein should I take after this workout?"*
- *"Tell me about creatine supplementation"*
- *"How much rest should I take between sets?"*
- *"What should I eat for muscle growth?"*

### **🎤 Voice System Features:**
Rex provides intelligent voice coaching with multiple personality styles:

- **🎯 Coaching Styles** - Motivational, technical, supportive, and professional voices
- **🔄 Smart Fallback** - ElevenLabs AI voices with Apple TTS backup for reliability
- **💬 Natural Conversation** - 8-second listening window with check-in prompts
- **🎵 Audio Management** - Centralized session coordination and conflict resolution
- **♿ Accessibility** - VoiceOver compatibility and inclusive design

## 🚀 Getting Started

See [SETUP.md](SETUP.md) for detailed installation and configuration instructions.

## 🏗️ Architecture

Built with modern iOS development practices and premium voice AI:

### **🎤 Rex Voice System:**
- **Picovoice Porcupine** - Custom "Hey Rex" wake word model
- **ElevenLabs AI Voices** - Human-like speech synthesis with coaching personalities
- **iOS Speech Framework** - Advanced speech recognition with noise filtering
- **AudioSessionManager** - Centralized audio session coordination and conflict resolution
- **AVFoundation** - Professional audio format conversion and playback management
- **OpenAI GPT-4** - Intelligent conversational AI with fitness expertise
- **VoiceOver Integration** - Seamless accessibility support for all users

### **📱 Core Technologies:**
- **SwiftUI** - Modern declarative user interface with TabView navigation
- **ARKit + Vision Framework** - Real-time 3D pose detection and form analysis
- **HealthKit** - Comprehensive fitness data integration with activity rings
- **Picovoice Porcupine** - Custom "Hey Rex" wake word detection
- **ElevenLabs API** - Premium human-like voice synthesis
- **OpenAI GPT-4** - Intelligent conversational AI for fitness coaching


## 🎯 **Current Implementation Status**

### **✅ Fully Implemented Features:**
- **Voice Assistant** - "Hey Rex" wake word detection with ElevenLabs AI voices
- **AR Form Analysis** - Real-time 3D pose detection and exercise form validation
- **HealthKit Integration** - Comprehensive activity tracking with Apple Fitness-style rings
- **AI Coaching** - OpenAI GPT-4 powered conversational fitness coaching
- **Exercise Database** - Built-in exercise library with form criteria and safety guidelines
- **iOS Simulator Support** - Full voice system testing on both simulator and device

## 🧪 Testing

The app is designed for comprehensive testing across different environments:

### **🎤 Voice System Testing:**
- **iOS Simulator Compatible** - Full voice functionality on simulator and device
- **Audio Format Handling** - Robust fallback systems for various audio configurations
- **ElevenLabs Integration** - Premium voice synthesis with Apple TTS fallback
- **Wake Word Detection** - Custom "Hey Rex" model optimized for gym environments
- **Accessibility Support** - VoiceOver compatibility and inclusive design

### **📱 AR & HealthKit Testing:**
- **3D Pose Detection** - Real-time body tracking with Vision framework
- **Form Analysis** - Exercise-specific criteria validation and feedback
- **HealthKit Integration** - Comprehensive fitness data tracking and permissions
- **Activity Rings** - Apple Fitness-style progress visualization
- **Cross-device Compatibility** - Tested on various iOS devices and simulators

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
- 📋 **Use template**: Copy `Info.template.plist` → `Info.plist` and add your keys

### **Required API Keys:**

#### **1. OpenAI API Key**
- Used for: AI coaching conversations and fitness advice
- Get it from: [OpenAI Platform](https://platform.openai.com/api-keys)
- Cost: ~$0.01-0.10 per conversation

#### **2. ElevenLabs API Key (Recommended)**
- Used for: Human-like voice synthesis (replaces robotic Apple TTS)
- Get it from: [ElevenLabs](https://elevenlabs.io/) (Free tier available)
- Cost: Free tier includes 10,000 characters/month
- **Why ElevenLabs?** Professional voice quality that sounds like real trainers

### **For Contributors:**
```bash
# 1. Setup your Info.plist
cp PeakSet/Info.template.plist PeakSet/Info.plist

# 2. Add your API keys to Info.plist
# Replace "YOUR_OPENAI_API_KEY_HERE" with your OpenAI key
# Replace "YOUR_ELEVENLABS_API_KEY_HERE" with your ElevenLabs key

# 3. Never commit Info.plist with real keys!
```

**⚠️ Your API keys are automatically protected by `.gitignore`**

### **🎤 Voice Quality Comparison:**
- **Apple TTS (Fallback)**: Robotic, limited personality, basic quality - only used when ElevenLabs fails
- **ElevenLabs (Primary)**: Human-like, emotional inflection, coaching personalities - custom "Rex" voice
- **Audio Format Handling**: Smart conversion and fallback for optimal compatibility across all devices

## 📞 Contact

For collaboration opportunities, technical questions, or investment inquiries, please reach out through GitHub issues.

---

**Building the future of intelligent fitness coaching** 🏋️‍♂️✨
