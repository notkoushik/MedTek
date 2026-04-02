# MedTek AI Coding Guidelines

## Architecture Overview
MedTek is a Flutter mobile app with Node.js/Express backend and PostgreSQL database. The system integrates medical appointment booking, doctor verification, ride services, and AI-powered triage.

**Key Components:**
- **Frontend**: Flutter app using Provider for state management, Dio for API calls, Mapbox/Google Maps for location services
- **Backend**: Express.js with JWT authentication, multer for file uploads, Tesseract.js for OCR
- **Database**: PostgreSQL with JSONB fields for flexible verification data
- **AI**: Google Gemini integration for medical triage chat
- **Verification**: Multi-step process (NMC check → Document OCR → Liveness photo) awarding points (20/30/15)

## Critical Workflows

### Database Setup
```bash
# Initialize database
cd backend
node scripts/init_db.js

# Validate schema
node scripts/check_schema.js

# Seed data
node scripts/repair_and_seed.js
```

### Backend Development
- Use `pool.query()` for database operations with parameterized queries
- Authentication via JWT middleware (`authMiddleware`)
- File uploads stored in `uploads/` directory with multer
- Rate limiting enabled only in production (`NODE_ENV === 'production'`)

### Flutter Development
- API calls through `ApiService` singleton with Dio
- Session management via `SessionService` with SharedPreferences
- Location services use `LocationProvider` and `Geolocator`
- Mapbox token set in `main.dart`, Google API key in `RideProvider`

## Project-Specific Patterns

### Backend API Structure
```javascript
// Route mounting in index.js
app.use('/verification-v2', require('./routes/verification_v2'));

// Database queries with pool
const result = await pool.query('SELECT * FROM doctors WHERE id = $1', [doctorId]);

// Error handling
try { /* code */ } catch (e) {
  console.error('❌ Error:', e);
  res.status(500).json({ error: e.message });
}
```

### Verification System
- Points-based verification: NMC (20pts), OCR (30pts), Liveness (15pts)
- Status progression: 0pts → rejected, 45pts → manual_review, 60pts → verified
- Store verification details in `verification_details` JSONB field
- Use `resolveDoctorId()` utility for flexible doctor ID lookup

### Flutter State Management
```dart
// Provider usage
ChangeNotifierProvider(create: (_) => RideProvider(googleApiKey: 'key'))

// API service calls
final api = ApiService();
final response = await api.dio.post('/verification-v2/nmc', data: {'nmcNumber': number});
```

### File Uploads
- Documents stored in `uploads/verification/` with timestamped filenames
- Use `multer.diskStorage` with custom destination and filename functions
- Serve static files via `app.use('/uploads', express.static('uploads'))`

### AI Integration
- Gemini model: `gemini-2.5-flash` with system prompt for medical triage
- Chat history mapped from `{role, message}` to Gemini's `{role, parts}` format
- Retry logic (3 attempts) for API reliability

## Key Files and Directories
- `backend/routes/verification_v2.js`: Multi-step doctor verification logic
- `backend/scripts/`: Database migrations, seeding, and utility scripts
- `lib/services/api_service.dart`: Centralized API client with Dio
- `lib/providers/`: State management for rides, location, session
- `pubspec.yaml`: Flutter dependencies including maps, TTS, image processing
- `backend/package.json`: Node dependencies with Gemini, Tesseract, PostgreSQL

## Development Conventions
- Use async/await consistently for all async operations
- Console logging with emojis for backend debugging (✅ success, ❌ error, 📄 info)
- Flutter routes defined in `main.dart` with argument passing via `ModalRoute.of(context)?.settings.arguments`
- Database foreign keys with CASCADE/SET NULL as appropriate
- Environment variables for API keys (GEMINI_API_KEY, DATABASE_URL, JWT_SECRET)</content>
<parameter name="filePath">c:\Users\botch\New_app\MedTek\AI_Flutter_Applications-medtek\.github\copilot-instructions.md