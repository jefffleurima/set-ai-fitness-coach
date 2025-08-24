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
- 🗣️ **Human-like voice responses** - ElevenLabs AI voices, not robotic Apple TTS
- 💬 **Continuous conversation flow** - 4-second listening after responses with check-in prompts
- 🧠 **Comprehensive knowledge** - Fitness, nutrition, supplements, health guidance
- ⚡ **Ultra-responsive** - 2-second max response time with smart delays
- 🎯 **Contextual coaching** - Knows your workout and provides targeted advice
- 🔧 **iOS Simulator compatible** - Works perfectly on both real devices and simulator
- 🎵 **Robust audio handling** - Smart format detection and fallback systems
- ♿ **VoiceOver compatibility** - Built-in accessibility support

### 📊 **Activity Tracking**
- Apple Fitness-style activity rings
- HealthKit integration for comprehensive metrics
- Workout history and progress tracking
- Calorie, steps, and distance monitoring

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

### **🚨 Professional Speech Priority System:**
Rex uses enterprise-grade speech management with 4 priority levels:

- **🚨 Immediate Interrupt** - Safety alerts and form corrections stop everything
- **⏱️ Immediate Blocking** - Set/rest timing and critical coaching  
- **💪 Normal Priority** - Standard form feedback and encouragement
- **🎉 Low Priority** - Background motivation that can be interrupted

**Smart Features:**
- **Thread-safe queue management** with professional interruption handling
- **VoiceOver compatibility** - Automatically defers to accessibility when needed
- **Contextual responses** - Different priorities for different workout phases
- **Timeout protection** - Prevents stuck speech and ensures responsiveness

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
- **SwiftUI** - Responsive, declarative user interface
- **ARKit** - Real-time body tracking and pose estimation
- **Vision Framework** - Computer vision for form analysis
- **HealthKit** - Comprehensive fitness data integration
- **Core ML** - On-device machine learning capabilities


## 🆕 **Latest Voice System Improvements**

### **🔧 iOS Simulator Compatibility (v2.1)**
- **Smart Format Detection** - Automatically detects iOS Simulator vs real device
- **Multiple Fallback Formats** - Tries 44.1kHz, 48kHz, 16kHz for optimal compatibility
- **Robust Audio Conversion** - Handles format mismatches gracefully with AVAudioConverter
- **Alternative Setup Methods** - If main setup fails, automatically tries simpler approaches
- **Audio Session Coordination** - Centralized management prevents conflicts between components

### **💬 Enhanced Conversation Flow**
- **4-Second Listening Window** - Extended from 2 seconds for more natural conversation
- **Check-in Prompts** - AI asks "Is there anything else I can help with?" before ending
- **Smooth Transitions** - Seamless handoff between ElevenLabs and Apple TTS fallback
- **Error Recovery** - Multiple retry attempts with exponential backoff for reliability

## 🧪 Testing

Designed and tested for real-world gym environments:

### **🎤 Rex Voice Testing:**
- **Noise-resistant** - Works with background music and gym equipment sounds
- **Natural conversation** - Tested for human-like interaction patterns
- **Response speed** - Validated 2-second max response times
- **Knowledge accuracy** - Verified fitness, nutrition, and health expertise
- **iOS Simulator compatibility** - Fully tested and optimized for development
- **Audio format handling** - Robust fallback systems for various audio configurations
- **Accessibility testing** - VoiceOver compatibility verified across scenarios

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
cp Set/Info.template.plist Set/Info.plist

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
