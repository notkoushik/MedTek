# 🏥 MedTek AI Healthcare Platform

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.9.2%2B-00A8E1?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20|%20iOS%20|%20Web%20|%20Desktop-brightgreen)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-Proprietary-red)](LICENSE)
[![Node.js](https://img.shields.io/badge/Backend-Node.js%2018%2B-green?logo=nodedotjs)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL%2014%2B-336791?logo=postgresql)](https://www.postgresql.org)

**A comprehensive AI-powered healthcare platform with multi-role support, real-time location tracking, and advanced medical AI services.**

[Overview](#-overview) • [Features](#-key-features) • [Architecture](#-architecture) • [Getting Started](#-getting-started) • [Contributing](#-contributing)

</div>

---

## 🎯 Overview

**MedTek** is a cross-platform healthcare management system built with **Flutter** and **Node.js**, designed to connect patients, doctors, lab assistants, and hospitals in a seamless ecosystem. The platform leverages advanced AI technologies (Gemini Vision, Ollama LLM) for medical consultations, pill identification, and intelligent triage assessment.

### Why MedTek?

✅ **Multi-Platform**: One codebase deployed across 6 platforms (Android, iOS, Web, macOS, Windows, Linux)
✅ **AI-Driven**: Medical triage chatbot + pill identification with drug safety checks
✅ **Real-Time**: Location tracking, live ride coordination, instant status updates
✅ **Enterprise-Ready**: JWT authentication, role-based access, production deployment guides
✅ **Scalable**: RESTful API with PostgreSQL backend, PM2 process management

### Key Statistics

| Metric | Count |
|--------|-------|
| **Supported Platforms** | 6 (Android, iOS, Web, macOS, Windows, Linux) |
| **User Roles** | 4 (Patient, Doctor, Lab Assistant, Rider) |
| **Main Screens** | 20+ |
| **API Endpoints** | 50+ |
| **Direct Dependencies** | 25+ |
| **AI Services** | 3 (Triage, Pill ID, Chatbot) |

---

## ✨ Key Features

### 👥 **User Management**
- 🔐 Multi-role authentication (Patient, Doctor, Lab Assistant, Rider)
- 📱 Profile personalization with picture upload
- 🏆 Doctor verification & credential management
- 📊 User activity tracking

### 📋 **Appointment System**
- 📅 Intelligent appointment booking with calendar
- 🏥 Hospital-specific doctor selection
- ⏰ Real-time appointment status tracking (pending → approved → completed)
- 📞 Appointment reason tracking (consultation, follow-up, emergency)
- 🔔 Instant notifications for status changes

### 🏥 **Medical Records & Lab Management**
- 📝 Comprehensive medical report generation
- 🧪 Lab test ordering and tracking workflow
- 📊 Real-time lab test status (pending → sample collected → completed)
- 📈 Medical history analysis
- 🎯 Test categorization (blood sample, temperature, injury, etc.)

### 🗺️ **Location-Based Services**
- 📍 Real-time GPS tracking for doctors & drivers
- 🔍 Intelligent hospital search by location & specialty
- 🚗 Ride booking integration with nearby driver assignment
- 📐 Distance calculation & route optimization
- 🗺️ Dual map support (Mapbox + Google Maps)

### 🤖 **AI-Powered Services**

#### Medical Triage (Ollama OptGPT-4)
- 🌍 Multi-language support (English, Hindi, Telugu, Tamil, Arabic)
- 🎤 Voice input with speech-to-text
- 🔊 Natural voice response with text-to-speech
- 💬 Conversational AI with context awareness
- 📊 Structured medical assessment generation

#### Pill Identification (Gemini Vision)
- 📸 Pill image recognition & identification
- ⚠️ Drug interaction detection
- ✅ Safety assessment against current medications
- 💊 Medication metadata extraction
- 🎯 Confidence level reporting (High/Good/Moderate/Low)

#### Medical Chatbot
- 💭 Context-aware Q&A with user profile injection
- 🔄 Multi-turn conversation management
- 📚 Medical knowledge base integration
- 🌐 Multilingual support

### 🏢 **Hospital Network**
- 🔍 Browse doctors by hospital & specialty
- ⭐ Doctor rating & review system
- 📍 Hospital facility information
- 🏆 Trending doctors & facilities
- 🗂️ Hospital categorization & filtering

### 🧑‍⚕️ **Lab Assistant Dashboard**
- 📋 Pending test queue management
- 🧬 Sample collection workflow
- ✔️ Test completion tracking
- 📊 Lab statistics & analytics

---

## 🏗️ Architecture

### Tech Stack

#### **Frontend (Flutter)**
| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Framework** | Flutter | 3.x | Cross-platform UI |
| **Language** | Dart | 3.9.2+ | Core logic |
| **State Management** | Provider | 6.1.2 | Reactive state |
| **HTTP Client** | Dio | 5.4.0 | API communication |
| **Maps** | Mapbox + Google Maps | 2.0.0 / 2.7.0 | Location services |
| **Location** | Geolocator | 10.1.0 | GPS tracking |
| **Speech** | speech_to_text / flutter_tts | 7.0.0 / 4.1.0 | Voice I/O |
| **Image Handling** | image_picker / flutter_image_compress | 1.0.7 / 2.1.0 | Media management |
| **Cloud Storage** | cloudinary_public | 0.21.0 | Image hosting |
| **Local Storage** | shared_preferences | 2.2.2 | Persistent data |
| **SVG Rendering** | flutter_svg | 2.0.10 | Vector graphics |
| **Internationalization** | intl | 0.19.0 | Multi-language support |

#### **Backend (Node.js)**
| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Runtime** | Node.js | 18+ / 20+ | Server runtime |
| **Framework** | Express.js | 5.1.0 | REST API framework |
| **Database** | PostgreSQL | 14+ | Data persistence |
| **Authentication** | JWT | 9.0.2 | Stateless auth |
| **Password Hashing** | bcrypt | 6.0.0 | Secure passwords |
| **AI - Chat** | Gemini API | 0.24.1 | Cloud AI |
| **AI - Triage** | Ollama | Local | Medical LLM |
| **OCR** | Tesseract.js | 7.0.0 | Text extraction |
| **Process Manager** | PM2 | Latest | Production management |
| **Security** | helmet / cors / rate-limit | Latest | API security |
| **File Upload** | multer | 2.0.2 | Multipart handling |

### Platform Support Matrix

| Feature | Android | iOS | Web | macOS | Windows | Linux |
|---------|---------|-----|-----|-------|---------|-------|
| **Maps** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Location** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Camera** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Permissions** | ✅ | ✅ | ⚠️ Limited | ✅ | ✅ | ✅ |
| **Speech-to-Text** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ Limited |
| **Text-to-Speech** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ Limited |
| **Push Notifications** | ✅ Firebase | ✅ Firebase | ⚠️ Web Push | ✅ | ✅ | ✅ |
| **Offline Support** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Application Architecture

```
┌─────────────────────────────────────────────────────────── Flutter Frontend ───────────────────────────────────────────────────────────┐
│                                                                                                                                          │
│  ┌──────────────────────────────┐                    ┌──────────────────────┐                  ┌──────────────────────────────┐      │
│  │    📱 UI Layer (Screens)     │◄──Provider─────────┤  🎯 State Management │◄─────Local────┤  💾 SharedPreferences        │      │
│  │  • Patient Dashboard         │              │     │  • LocationProvider  │           └────┤  • Tokens, Preferences       │      │
│  │  • Doctor Dashboard          │              │     │  • RideProvider      │                └──────────────────────────────┘      │
│  │  • Lab Dashboard             │              │     │  • SessionService    │                                                      │
│  │  • Triage Page               │              │     └──────────────────────┘                ┌──────────────────────────────┐      │
│  │  • Hospital Booking          │              │                                            │  🗺️ Location Services       │      │
│  └──────────────────────────────┘              │     ┌──────────────────────┐              │  • Geolocator               │      │
│                                                └─────►│  🏗️ Services Layer   │◄────────────┤  • Geocoding                 │      │
│  ┌──────────────────────────────┐                    │  • ApiService        │              └──────────────────────────────┘      │
│  │    🎨 Widgets/Components    │                    │  • LocationService   │                                                      │
│  │  • Custom Cards             │                    │  • MapsService       │              ┌──────────────────────────────┐      │
│  │  • Maps                      │                    │  • OllamaService     │              │  📸 Media Services          │      │
│  │  • Forms                     │                    │  • CloudinaryService │              │  • Image Picker              │      │
│  │  • Chat UI                   │                    └──────────────────────┘              │  • Image Compression        │      │
│  └──────────────────────────────┘                           ▲                              │  • Upload to Cloudinary     │      │
│                                                               │                              └──────────────────────────────┘      │
│                                                        ┌──────┴─────────┐                                                           │
│                                                        │                │                                                           │
│                                    ┌─────────────────────────────────────────────┐                                                 │
│                                    │  🌐 HTTP Client (Dio)                      │                                                 │
│                                    │  • Bearer Token Interceptor                │                                                 │
│                                    │  • Request/Response Logging                │                                                 │
│                                    │  • Timeout Management (60s)                │                                                 │
│                                    └──────────────┬──────────────────────────────┘                                                 │
└────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────┘
                                                     │ REST API
                                    ┌────────────────▼──────────────────┐
                                    │   📡 Backend API (Node.js)        │
                                    │   http://192.168.1.56:4000 🔗     │
                                    │   Production: Configurable        │
                                    └────────────┬──────────────────────┘
                                                 │
                    ┌────────────────────────────┼────────────────────────────┐
                    │                            │                            │
        ┌───────────▼────────────┐   ┌──────────▼────────────┐  ┌───────────▼──────────┐
        │  🗄️ PostgreSQL DB     │   │  🤖 AI Services     │  │  🌍 External APIs  │
        │  • Users              │   │  • Gemini API       │  │  • Mapbox Tiles    │
        │  • Appointments       │   │  • Ollama LLM       │  │  • Google Maps     │
        │  • Medical Reports    │   │  • Text-to-Speech   │  │  • Cloudinary      │
        │  • Lab Tests          │   │  • Speech-to-Text   │  │                    │
        │  • Rides              │   └─────────────────────┘  └────────────────────┘
        │  • Tasks              │
        └───────────────────────┘
```

### Project Structure

```
medtek/
├── 📱 android/              # Android native code & Gradle config
│   ├── app/build.gradle.kts # API 21+, Java 11
│   └── build.gradle.kts     # Gradle 8.9.1, Kotlin 2.1.0
├── 🍎 ios/                  # iOS native code & Xcode project
├── 💻 web/                  # Web platform (HTML5, Canvas)
├── 🖥️  linux/               # Linux desktop (CMake)
├── 🖱️  windows/             # Windows desktop (CMake)
├── 🍎 macos/                # macOS desktop
├── 📦 backend/              # Node.js API Server
│   ├── index.js             # Express entry point
│   ├── routes/              # API route handlers
│   ├── middleware/          # Auth, CORS, validation
│   ├── services/            # Business logic
│   ├── models/              # Database schemas
│   ├── package.json         # Backend dependencies
│   └── ecosystem.config.js  # PM2 configuration
├── 📚 lib/                  # Flutter Dart source
│   ├── main.dart            # App entry, MultiProvider setup
│   ├── 🎨 theme/            # Color schemes, styles
│   ├── 🧩 widgets/          # Reusable UI components
│   │   ├── custom_card.dart
│   │   ├── map_widget.dart
│   │   └── ...
│   ├── 📱 screens/          # Full-screen pages
│   ├── 🎯 src/              # Feature screens
│   │   ├── auth_page.dart
│   │   ├── patient_dashboard.dart
│   │   ├── doctor_dashboard.dart
│   │   ├── triage_page.dart
│   │   ├── ai_pill_detection_page.dart
│   │   ├── appointment_booking_page.dart
│   │   ├── hospital_detail_page.dart
│   │   └── [20+ more screens]
│   ├── 📊 models/           # Data structures
│   │   ├── user_model.dart
│   │   ├── hospital.dart
│   │   ├── ride_model.dart
│   │   └── ...
│   ├── 🔧 services/         # Business logic
│   │   ├── api_service.dart (50+ endpoints)
│   │   ├── session_service.dart
│   │   ├── location_service.dart
│   │   ├── maps_service.dart
│   │   ├── ride_service.dart
│   │   ├── ollama_service.dart
│   │   ├── cloudinary_service.dart
│   │   └── storage_service.dart
│   ├── 🎮 providers/        # State management
│   │   ├── location_provider.dart
│   │   ├── ride_provider.dart
│   │   └── theme_notifier.dart
│   └── 🎵 assets/           # Images, icons, fonts
├── ✅ test/                 # Unit & widget tests
├── 📄 DEPLOYMENT.md         # Deployment guide
├── firebase.json            # Firebase config
├── pubspec.yaml             # Flutter dependencies
├── analysis_options.yaml    # Linting rules
└── README.md                # This file
```

---

## 🚀 Getting Started

### ✅ Prerequisites

**System Requirements:**
- 💻 **macOS 12+** or **Windows 10+** or **Linux (Ubuntu 20.04+)**
- 🔧 **Xcode 13+** (for iOS development on macOS)
- ☕ **Java JDK 11+** (for Android builds)
- 📱 **Android SDK API 21+** (via Android Studio)

**Software Installation:**
```bash
# 1️⃣ Install Flutter (3.x)
# From: https://flutter.dev/docs/get-started/install
flutter --version  # Should show 3.x.x

# 2️⃣ Install Dart (usually bundled with Flutter)
dart --version     # Should show 3.9.2+

# 3️⃣ Validate environment
flutter doctor     # All items should show ✓

# 4️⃣ Clone the repository
git clone https://github.com/your-org/medtek.git
cd medtek/medtek

# 5️⃣ Install dependencies
flutter pub get

# 6️⃣ (Optional) Configure Firebase
flutterfire configure
```

### 🔧 Configuration

#### Backend Setup (.env)
Create `/backend/.env`:
```bash
# Server
PORT=4000
NODE_ENV=development

# Database
DATABASE_URL=postgres://user:password@localhost:5432/medtek?sslmode=require
DB_SSL=true

# Authentication
JWT_SECRET=your-super-secure-random-string-min-32-chars

# AI Services
GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Ollama (Local AI)
OLLAMA_BASE_URL=http://192.168.1.117:8006/api/generate
OLLAMA_MODEL=OptGPT-4:latest

# Cloudinary
CLOUDINARY_CLOUD_NAME=diwftm6np
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

### 🎮 Running the App

#### 📱 Android
```bash
# List connected devices
flutter devices

# Run on Android emulator/device
flutter run -d <device_id>

# Debug with detailed logging
flutter run -d android --verbose
```

#### 🍎 iOS
```bash
# Update iOS dependencies
cd ios && pod install --repo-update && cd ..

# Run on iOS simulator
flutter run -d "iPhone 15 Pro Max"
```

#### 🌐 Web
```bash
# Run on Chrome (default)
flutter run -d chrome

# Build for production
flutter build web --release
```

#### 🖥️ Backend (Node.js)
```bash
cd backend
npm install
npm run dev  # or: node index.js
```

---

## 📡 API Integration

### API Endpoints Summary

**Authentication**
- `POST /auth/login` - User login
- `POST /auth/register` - User registration
- `POST /password-reset/request` - Reset password

**Appointments**
- `GET /appointments` - Get appointments (doctor)
- `POST /appointments` - Create appointment
- `PATCH /appointments/{id}/status` - Approve/reject

**Medical Reports**
- `GET /medical-reports/mine` - Get user's reports
- `POST /medical-reports` - Create report

**Hospital & Doctors**
- `GET /hospitals/search` - Search by location/query
- `GET /doctors/search` - Search doctors
- `GET /doctors/trending` - Top-rated doctors

**AI Services**
- `POST /ai/chat` - Gemini chat
- `POST /ai/chat-ollama` - Medical triage
- `POST /ai/identify-pill` - Pill identification

📚 **Full API documentation**: See docs/API_DOCS.md for complete reference

---

## 🤖 AI Features

### Medical Triage (Ollama OptGPT-4)
- 🌍 Multi-language support (English, Hindi, Telugu, Tamil, Arabic)
- 🎤 Voice input & 🔊 voice output
- 💬 Context-aware medical consultation
- 📊 Structured medical assessment

### Pill Identification (Gemini Vision)
- 📸 AI pill recognition from image
- ⚠️ Drug interaction detection
- ✅ Safety assessment
- 📊 Confidence scoring

### Medical Chatbot
- 💭 Context-aware Q&A
- 📚 Medical knowledge base
- 🌐 Multi-language support

---

## 🔐 Security

✅ **JWT Bearer Tokens** - Stateless authentication
✅ **Role-Based Access Control** - Patient, Doctor, Lab Assistant roles
✅ **Password Security** - bcrypt hashing
✅ **HTTPS/TLS** - Encrypted communication
✅ **Permission Validation** - Runtime permission checks
✅ **Rate Limiting** - API brute-force protection
✅ **SQL Injection Prevention** - Parameterized queries

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Integration tests
flutter drive --target=test_driver/app.dart
```

---

## 📦 Production Deployment

### 🔶 Android (Play Store)

```bash
# Build release APK/App Bundle
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# Then upload to Google Play Console
```

### 🍎 iOS (App Store)

```bash
# Build iOS app
flutter build ios --release
cd ios && pod install --repo-update && cd ..

# Archive in Xcode and upload to App Store Connect
flutter build ipa --release
```

### 🌐 Web (Firebase Hosting)

```bash
flutter build web --release
firebase deploy --only hosting
```

### 📦 Backend (Node.js / PM2)

```bash
# Start with PM2
pm2 start ecosystem.config.js
pm2 logs medtek-api
pm2 save
pm2 startup systemd
```

### Database Management

```bash
# PostgreSQL backup
pg_dump medtek_db | gzip > medtek_backup.sql.gz

# Restore from backup
gunzip medtek_backup.sql.gz
psql medtek_db < medtek_backup.sql

# Check tables sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 🤝 Contributing

### Code Style Guidelines

**Dart/Flutter**:
```dart
// ✅ Use Provider for state management
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MyProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Title')),
          body: ListView(children: provider.items),
        );
      },
    );
  }
}
```

### Branch Naming

```
main          # Production-ready
├── develop   # Integration branch
├── feature/* # New features
├── bugfix/*  # Bug fixes
└── hotfix/*  # Urgent fixes
```

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

# Types: feat, fix, docs, style, refactor, test, chore
# Example:
feat(triage): add multilingual support
- Added 5 language options
- Updated UI language picker
Closes #123
```

### Pull Request Process

1. Fork & create feature branch
2. Make changes following code style
3. Test locally (`flutter test`)
4. Commit with message format
5. Push & open PR with description
6. Address reviews
7. Merge once approved

---

## 🐛 Troubleshooting

### Common Issues

**Location Permission Denied**
```bash
# Android: Settings > Apps > MedTek > Permissions > Location
# iOS: Settings > MedTek > Location > While Using
```

**API Connection Failed**
```bash
# Check backend is running
ps aux | grep node
# Verify health
curl http://192.168.1.56:4000/health
```

**Speech Recognition Not Working**
```xml
<!-- Add to AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- Add to Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>Needed for voice medical consultation</string>
```

**Ollama Timeout**
```bash
# Verify Ollama is running
curl http://192.168.1.117:8006/api/tags
# Load model if needed
ollama pull OptGPT-4:latest
```

---

## 📚 Additional Resources

### Documentation
- 📖 [Flutter Docs](https://flutter.dev/docs)
- 🎯 [Dart Language](https://dart.dev/guides/language/language-tour)
- 📦 [Provider Package](https://pub.dev/packages/provider)
- 🗺️ [Mapbox Docs](https://docs.mapbox.com)
- 🌐 [Express.js Guide](https://expressjs.com)
- 🗄️ [PostgreSQL Docs](https://www.postgresql.org/docs)

### Project Documentation
- 📡 [API Reference](./docs/API_DOCS.md)
- 🚀 [Deployment Guide](./DEPLOYMENT.md)
- 🤖 [AI Setup](./docs/AI_SETUP.md)

---

## 📄 License

**🔒 PROPRIETARY SOFTWARE**

MedTek is **NOT open source**. Unauthorized copying, modification, or distribution is prohibited.

- ✋ **Do NOT** fork or redistribute without permission
- ✋ **Do NOT** use for commercial purposes without license
- ✅ **Internal use only** within authorized organization
- 📧 Licensing inquiries: legal@medtek-healthcare.com

---

## 📞 Support & Contact

### Getting Help

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/your-org/medtek/issues)
- 💬 **Features**: [GitHub Discussions](https://github.com/your-org/medtek/discussions)
- 📧 **Email**: support@medtek-healthcare.com
- 📚 **Wiki**: [Project Wiki](https://github.com/your-org/medtek/wiki)

### Team

- 👨‍💼 **Project Lead**: [Contact]
- 👨‍💻 **Lead Developer**: [Contact]
- 🤖 **AI Features**: [Contact]

---

<div align="center">

**Made with ❤️ by the MedTek Team**

[Back to Top](#-medtek-ai-healthcare-platform) • [Report Issue](https://github.com/your-org/medtek/issues) • [Request Feature](https://github.com/your-org/medtek/discussions)

**Last Updated**: February 2024 | **Version**: 1.0.0

</div>
