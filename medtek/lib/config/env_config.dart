// lib/config/env_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  /// Mapbox Access Token
  static String get mapboxAccessToken {
    return dotenv.env['MAPBOX_ACCESS_TOKEN'] ??
      'YOUR_MAPBOX_TOKEN_NOT_SET'; // Fallback with clear error
  }

  /// Backend API URL
  static String get apiUrl {
    return dotenv.env['API_URL'] ?? 'http://192.168.1.56:4000';
  }

  /// Ollama Base URL for AI services
  static String get ollamaBaseUrl {
    return dotenv.env['OLLAMA_BASE_URL'] ?? 'http://192.168.1.117:8006/api/generate';
  }

  /// Gemini API Key for pill identification
  static String get geminiApiKey {
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  /// Cloudinary configuration
  static String get cloudinaryCloudName {
    return dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  }

  static String get cloudinaryUploadPreset {
    return dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  }
}
