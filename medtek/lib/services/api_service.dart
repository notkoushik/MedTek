// lib/services/api_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Add this
import 'session_service.dart';
import '../models/hospital.dart';

class ApiService {
  // ✅ CONFIGURATION (Dynamic)
  static String _baseUrl = 'http://192.168.1.151:4000'; 
  
  static String get baseUrl => _baseUrl;
  
  // Helper to get the base host IP for other services (Ollama)
  static String get host {
     try {
       return Uri.parse(_baseUrl).host;
     } catch (e) {
       return '192.168.1.151';
     }
  }

  // Helper for Ollama endpoint
  static String get ollamaBaseUrl => 'http://$host:8006/api/generate';

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Attach Bearer token on every request
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SessionService.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // ✅ Initialize IP from Storage
  Future<void> loadBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('backend_ip');
      if (savedIp != null && savedIp.isNotEmpty) {
        // Construct full URL if user just saved IP
        String newUrl = savedIp.startsWith('http') ? savedIp : 'http://$savedIp:4000';
        updateBaseUrl(newUrl, save: false); // Already saved
      }
    } catch (e) {
      print('Error loading saved IP: $e');
    }
  }

  // ✅ Update IP Method
  Future<void> updateBaseUrl(String newUrl, {bool save = true}) async {
    // Ensure URL has scheme and port
    if (!newUrl.startsWith('http')) {
      newUrl = 'http://$newUrl';
    }
    // If user enters just IP, assume port 4000
    if (newUrl.split(':').length < 3) {
       newUrl = '$newUrl:4000';
    }

    _baseUrl = newUrl;
    
    // Re-create Dio with new BaseURL
    _dio.options.baseUrl = _baseUrl;

    if (save) {
      final prefs = await SharedPreferences.getInstance();
      // Save just the IP part if possible, or the whole URL? 
      // Let's save the whole URL for simplicity
      await prefs.setString('backend_ip', _baseUrl);
    }
    print('✅ API Base URL updated to: $_baseUrl');
  }



  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  // ✅ PUBLIC GETTER - Access dio instance
  Dio get dio => _dio;

  // Generic POST helper
  Future<dynamic> post(String path, {Map<String, dynamic>? data}) async {
    final response = await _dio.post(path, data: data);
    return response.data;
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Get appointments for a doctor (with optional date filter)
  Future<List<Map<String, dynamic>>> getDoctorAppointments(String doctorId,
      {DateTime? date}) async {
    try {
      String url = '$baseUrl/appointments?doctor_id=$doctorId';
      if (date != null) {
        final dateStr = date.toIso8601String().split('T').first; // YYYY-MM-DD
        url += '&date=$dateStr';
      }

      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        return (data['appointments'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching doctor appointments: $e');
      throw Exception('Failed to load appointments');
    }
  }

  // ---------- PASSWORD RESET ----------

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final res = await _dio.post('/password-reset/request', data: {
        'email': email,
      });
      return res.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to send reset code');
    }
  }

  Future<void> verifyResetToken(String email, String token) async {
    try {
      await _dio.post('/password-reset/verify', data: {
        'email': email,
        'token': token,
      });
    } catch (e) {
      throw Exception('Invalid or expired reset code');
    }
  }

  Future<void> resetPassword(String email, String token, String newPassword) async {
    try {
      await _dio.post('/password-reset/reset', data: {
        'email': email,
        'token': token,
        'newPassword': newPassword,
      });
    } catch (e) {
      throw Exception('Failed to reset password');
    }
  }

  // ---------- PROFILE PICTURE & USER UPDATE ----------

  Future<Map<String, dynamic>> uploadProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    try {
      print('📤 Starting upload for user: $userId');

      final fileSize = await imageFile.length();
      print('📊 Original file size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image too large. Please select an image smaller than 5MB');
      }

      final formData = FormData.fromMap({
        'profile_picture': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'profile-${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      print('📤 Uploading to: /users/$userId/upload-profile-picture');

      final res = await _dio.post(
        '/users/$userId/upload-profile-picture',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        onSendProgress: (sent, total) {
          if (total != -1) {
            final progress = (sent / total * 100).toStringAsFixed(0);
            print('📊 Upload progress: $progress% ($sent/$total bytes)');
          }
        },
      );

      print('✅ Upload response received: ${res.statusCode}');

      final data = res.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>?;

      if (user != null) {
        print('✅ User data received: ${user['profile_picture']}');
        await SessionService.instance.updateUser(user);
        return user;
      }

      return data;
    } on DioException catch (e) {
      print('❌ DioException during upload:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Response: ${e.response?.data}');

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          throw Exception('Connection timeout - please check your internet connection');
        case DioExceptionType.sendTimeout:
          throw Exception('Upload timeout - please try with a smaller image');
        case DioExceptionType.receiveTimeout:
          throw Exception('Server response timeout - please try again');
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          if (statusCode == 413) {
            throw Exception('Image too large - please select a smaller image');
          } else if (statusCode == 404) {
            throw Exception('Upload endpoint not found - check backend server');
          } else if (statusCode == 401) {
            throw Exception('Unauthorized - please login again');
          }
          throw Exception('Upload failed: ${e.response?.data?['error'] ?? 'Unknown error'}');
        case DioExceptionType.connectionError:
          throw Exception('Connection error - is the backend server running?');
        default:
          throw Exception('Upload failed: ${e.message}');
      }
    } catch (e) {
      print('❌ Unexpected error during upload: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    String? name,
    String? profilePicture,
  }) async {
    final body = <String, dynamic>{};

    if (name != null) body['name'] = name;
    if (profilePicture != null) body['profile_picture'] = profilePicture;

    if (body.isEmpty) {
      throw Exception('No fields to update');
    }

    final res = await _dio.patch('/users/$userId', data: body);
    final user = res.data['user'] as Map<String, dynamic>;

    await SessionService.instance.updateUser(user);

    return user;
  }

  String getProfilePictureUrl(String filename) {
    return '${_dio.options.baseUrl}/uploads/profile-pictures/$filename';
  }

  // ---------- AUTH ----------

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Empty login response');
    return data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/users/me');
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Empty /users/me response');
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? hospitalName,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'hospitalName': hospitalName,
    });
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Empty register response');
    return data;
  }

  // ---------- HOSPITALS & DOCTORS ----------

  Future<List<Map<String, dynamic>>> getHospitals() async {
    final res = await _dio.get('/hospitals');
    final body = res.data;
    if (body is List) return body.cast<Map<String, dynamic>>();
    if (body is Map<String, dynamic>) {
      final list = body['hospitals'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Hospital>> searchHospitals({
    required String query,
    required double lat,
    required double lng,
    int radius = 10000,
  }) async {
    final res = await _dio.get(
      '/hospitals/search',
      queryParameters: {
        'query': query,
        'lat': lat,
        'lng': lng,
        'radius': radius,
      },
    );

    final body = res.data;
    List<dynamic> hospitalList;

    if (body is Map<String, dynamic>) {
      hospitalList = body['hospitals'] as List<dynamic>? ?? [];
    } else if (body is List) {
      hospitalList = body;
    } else {
      return [];
    }

    return hospitalList
        .cast<Map<String, dynamic>>()
        .map((json) => Hospital.fromJson(json))
        .toList();
  }

  // ✅ NEW METHOD - Get doctor's selected hospital
  Future<Map<String, dynamic>?> getMyHospital() async {
    try {
      final res = await _dio.get('/doctors/my-hospital');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // No hospital selected
      }
      rethrow;
    }
  }

  Future<void> selectHospitalForDoctor(Map<String, dynamic> body) async {
    await _dio.post('/doctors/select-hospital', data: body);
  }

  Future<Map<String, dynamic>> getHospitalById(String hospitalId) async {
    final res = await _dio.get('/hospitals/$hospitalId');
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Empty /hospitals/$hospitalId response');
    return data;
  }

  Future<Map<String, dynamic>> getHospitalDoctors(String hospitalId) async {
    final res = await _dio.get('/hospitals/$hospitalId/doctors');
    final data = res.data as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Empty /hospitals/$hospitalId/doctors response');
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getDoctorsForHospital(
      String hospitalId,
      ) async {
    final res = await _dio.get('/hospitals/$hospitalId/doctors');
    final body = res.data;
    if (body is Map<String, dynamic>) {
      final list = body['doctors'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    if (body is List) return body.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getDoctorSummary(String doctorId) async {
    final res = await _dio.get('/doctors/$doctorId/summary');
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Empty summary response');
    return data;
  }

  Future<List<Map<String, dynamic>>> getRecentReports({
    required String doctorId,
    required int limit,
  }) async {
    final res = await _dio.get(
      '/doctors/$doctorId/recent-reports',
      queryParameters: {'limit': limit},
    );
    final map = res.data as Map<String, dynamic>?;
    final list = map?['items'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getDoctorReviews(
      String doctorId,
      ) async {
    final res = await _dio.get('/doctors/$doctorId/reviews');
    final map = res.data as Map<String, dynamic>?;
    final list = map?['reviews'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getDoctorPatients({
    required String doctorId,
    required String status,
  }) async {
    if (status == 'pending') {
      final res = await _dio.get(
        '/appointments/pending',
        queryParameters: {'doctor_id': doctorId},
        options: Options(headers: {'Cache-Control': 'no-cache'}),
      );

      final map = res.data as Map<String, dynamic>?;
      final list = map?['appointments'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }

    if (status == 'active') {
      // User Request: "Active" = Today's appointments (any status)
      final now = DateTime.now();
      final dateStr = now.toIso8601String().split('T').first;
      
      final res = await _dio.get(
        '/appointments',
        queryParameters: {'doctor_id': doctorId, 'date': dateStr},
        options: Options(headers: {'Cache-Control': 'no-cache'}),
      );
      final map = res.data as Map<String, dynamic>?;
      final list = map?['appointments'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }

    // Default/Completed behavior
    final res = await _dio.get(
      '/appointments',
      queryParameters: {'doctor_id': doctorId},
      options: Options(headers: {'Cache-Control': 'no-cache'}),
    );
    final map = res.data as Map<String, dynamic>?;
    final all = map?['appointments'] as List<dynamic>? ?? [];
    return all
        .cast<Map<String, dynamic>>()
        .where((apt) => apt['status'] == status)
        .toList();
  }

  // Update status of a specific lab test
  Future<bool> updateLabTestStatus(String reportId, String testName, String status) async {
    try {
      await _dio.patch(
        '/medical-reports/$reportId/test-status',
        data: {'testName': testName, 'status': status},
      );
      return true;
    } catch (e) {
      print('Error updating lab test status: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getTrendingDoctors() async {
    final res = await _dio.get('/doctors/trending');
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Empty /doctors/trending response');
    return data;
  }

  Future<List<Map<String, dynamic>>> searchDoctors({String? query}) async {
    final res = await _dio.get(
      '/doctors/search',
      queryParameters: query != null ? {'query': query} : null,
    );
    final map = res.data as Map<String, dynamic>?;
    final list = map?['doctors'] as List<dynamic>? ?? [];

    return list.map((doctor) {
      final doc = Map<String, dynamic>.from(doctor as Map);
      if (doc['rating'] is String) {
        doc['rating'] = double.tryParse(doc['rating'].toString()) ?? 0.0;
      }
      return doc;
    }).toList();
  }

  // Future<Map<String, dynamic>> updateDoctorProfile({
  //   required String userId,
  //   String? specialization,
  //   int? experienceYears,
  //   String? about,
  // }) async {
  //   final body = <String, dynamic>{};
  //
  //   if (specialization != null) body['specialization'] = specialization;
  //   if (experienceYears != null) body['experience_years'] = experienceYears;
  //   if (about != null) body['about'] = about;
  //
  //   final res = await _dio.patch('/users/$userId', data: body);
  //   final user = res.data['user'] as Map<String, dynamic>;
  //
  //   await SessionService.instance.updateUser(user);
  //
  //   return user;
  // }
  // lib/services/api_service.dart

  /// Update doctor profile - NEW VERSION
  Future<Map<String, dynamic>> updateDoctorProfile({
    String? specialization,
    int? experienceYears,
    String? about,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (specialization != null) body['specialization'] = specialization;
      if (experienceYears != null) body['experience_years'] = experienceYears;
      if (about != null) body['about'] = about;

      if (body.isEmpty) {
        throw Exception('No fields to update');
      }

      print('📝 Updating doctor profile...');
      print('   Body: $body');

      // ✅ Use /doctors/profile (NOT /users/:userId)
      final res = await _dio.patch('/doctors/profile', data: body);

      print('✅ Response: ${res.data}');

      final data = res.data as Map<String, dynamic>;

      // ✅ Update session with returned user data
      if (data['user'] != null) {
        final updatedUser = data['user'] as Map<String, dynamic>;
        await SessionService.instance.updateUser(updatedUser);
        print('✅ Session updated with new profile data');
        return updatedUser;
      }

      return data;
    } catch (e) {
      print('❌ Update doctor profile error: $e');
      rethrow;
    }
  }


  // ---------- RIDE / DRIVERS ----------

  Future<Map<String, dynamic>> getRide(String rideId) async {
    final res = await _dio.get('/rides/$rideId');
    final map = res.data as Map<String, dynamic>?;
    final ride = map?['ride'] as Map<String, dynamic>?;
    if (ride == null) throw Exception('Ride not found');
    return ride;
  }

  Future<List<Map<String, dynamic>>> getMyRides({
    required String riderId,
    String? status,
  }) async {
    final res = await _dio.get(
      '/rides',
      queryParameters: {
        'rider_id': riderId,
        if (status != null) 'status': status,
      },
    );
    final map = res.data as Map<String, dynamic>?;
    final list = map?['rides'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> assignDriver(
      String rideId,
      Map<String, dynamic> driverData,
      ) async {
    await _dio.post('/rides/$rideId/assign', data: driverData);
  }

  Future<List<dynamic>> findNearbyDrivers(
      double lat,
      double lng,
      double radiusKm,
      ) async {
    final res = await _dio.get(
      '/drivers/nearby',
      queryParameters: {'lat': lat, 'lng': lng, 'radiusKm': radiusKm},
    );
    final map = res.data as Map<String, dynamic>?;
    return (map?['drivers'] as List<dynamic>? ?? []);
  }

  Future<void> updateDriverLocation(String rideId, double lat, double lng) =>
      _dio.patch('/rides/$rideId/driver-location', data: {
        'driverLat': lat,
        'driverLng': lng,
      });

  Future<void> verifyRidePin(String rideId, String pin) =>
      _dio.post('/rides/$rideId/verify-pin', data: {'pin': pin});

  Future<void> updateRideStatus(String rideId, String status) async {
    await _dio.patch('/rides/$rideId/status', data: {'status': status});
  }

  Future<Map<String, dynamic>> createRide({
    required String riderId,
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    double? distanceKm,
    double? estimatedFare,
  }) async {
    final response = await _dio.post(
      '/rides',
      data: {
        'riderId': riderId,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropLat': dropLat,
        'dropLng': dropLng,
        'distanceKm': distanceKm,
        'estimatedFare': estimatedFare,
      },
    );
    return (response.data as Map<String, dynamic>);
  }

  // ---------- APPOINTMENTS / MEDICAL REPORTS ----------

  Future<Map<String, dynamic>> createAppointment(
      Map<String, dynamic> appointmentData,
      ) async {
    final res = await _dio.post('/appointments', data: appointmentData);
    return res.data as Map<String, dynamic>;
  }

  Future<void> sendTriageResult({
    required int appointmentId,
    required String diagnosis,
    required List<String> selectedTests,
    String? notes,
  }) async {
    await _dio.post(
      '/appointments/$appointmentId/triage-result',
      data: {
        'diagnosis': diagnosis,
        'selectedTests': selectedTests,
        'notes': notes,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getMyMedicalReports() async {
    final res = await _dio.get('/medical-reports/mine');
    final map = res.data as Map<String, dynamic>?;
    final list = map?['reports'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> createMedicalReport({
    required int patientId,
    required int appointmentId,
    String? reportText,
    String? imageUrl,
    String? cloudinaryId,
  }) async {
    await _dio.post(
      '/medical-reports',
      data: {
        'patient_id': patientId,
        'appointment_id': appointmentId,
        'report_text': reportText,
        'image_url': imageUrl,
        'cloudinary_id': cloudinaryId,
      },
    );
  }

  // ---------- HOSPITALS NEARBY ----------

  Future<List<Map<String, dynamic>>> getLiveNearbyHospitals({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    try {
      final res = await _dio.get(
        '/hospitals/nearby-live',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': (radiusKm * 1000).toInt(),
        },
      );
      final body = res.data;
      if (body is Map<String, dynamic>) {
        final list = body['hospitals'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getNearbyHospitals({
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    final res = await _dio.get(
      '/hospitals/nearby',
      queryParameters: {'lat': lat, 'lon': lon, 'radiusKm': radiusKm},
    );
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Empty /hospitals/nearby response');
    return data;
  }

  // ---------- VERIFICATION ----------

  Future<Map<String, dynamic>> getVerificationStatus() async {
    final res = await _dio.get('/verification/status');
    return res.data as Map<String, dynamic>;
  }

  Future<void> submitDoctorVerification({
    required String licenseNumber,
    required String authority,
    String? hospitalAffiliation,
    String? notes,
    required List<File> documents,
  }) async {
    final formData = FormData();

    formData.fields.add(MapEntry('medical_license_number', licenseNumber));
    formData.fields.add(MapEntry('license_authority', authority));
    if (hospitalAffiliation != null) {
      formData.fields.add(MapEntry('hospital_affiliation', hospitalAffiliation));
    }
    if (notes != null) {
      formData.fields.add(MapEntry('notes', notes));
    }

    for (var doc in documents) {
      formData.files.add(
        MapEntry(
          'documents',
          await MultipartFile.fromFile(
            doc.path,
            filename: doc.path.split('/').last,
          ),
        ),
      );
    }

    await _dio.post('/verification/submit-doctor', data: formData);
  }

  // ---------- USER PROFILE ----------

  Future<Map<String, dynamic>> getUserById(String userId) async {
    print('🔍 DEBUG: Calling GET /users/$userId');
    print('🔍 DEBUG: Base URL = ${_dio.options.baseUrl}');
    try {
      final res = await _dio.get('/users/$userId');
      print('✅ DEBUG: Response status: ${res.statusCode}');
      print('✅ DEBUG: Response data: ${res.data}');

      final map = res.data as Map<String, dynamic>?;
      final user = map?['user'] as Map<String, dynamic>?;
      if (user == null) throw Exception('User not found in response');
      return user;
    } catch (e, stackTrace) {
      print('❌ DEBUG: getUserById error: $e');
      print('❌ DEBUG: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPatientProfile(String userId) async {
    final res = await _dio.get('/users/$userId/profile');
    return res.data as Map<String, dynamic>;
  }

  Future<void> updatePatientProfileData(
      String userId,
      Map<String, dynamic> data,
      ) async {
    await _dio.patch('/users/$userId/profile', data: data);
  }

  Future<void> assignDoctorToPatient(String patientId, String doctorId) async {
    await _dio.post(
      '/users/$patientId/assign-doctor',
      data: {'doctorId': doctorId},
    );
  }

  // ---------- ACTIVITIES ----------

  Future<Map<String, dynamic>> getActivities({
    required String type,
    required String userId,
    required String status,
  }) async {
    final res = await _dio.get(
      '/activities/$type',
      queryParameters: {'userId': userId, 'status': status},
    );
    final data = res.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Empty activities response');
    return data;
  }

  Future<List<Map<String, dynamic>>> getPatientActivities(
      String patientId, {
        String status = 'all',
        String type = 'patient',
      }) async {
    try {
      final res =
      await getActivities(type: type, userId: patientId, status: status);

      if (res.containsKey('activities') && res['activities'] is List) {
        return (res['activities'] as List).cast<Map<String, dynamic>>();
      }

      if (res.containsKey('data') && res['data'] is List) {
        return (res['data'] as List).cast<Map<String, dynamic>>();
      }

      if (res.containsKey('items') && res['items'] is List) {
        return (res['items'] as List).cast<Map<String, dynamic>>();
      }

      final numericKeys =
      res.keys.where((k) => int.tryParse(k) != null).toList();
      if (numericKeys.isNotEmpty) {
        numericKeys.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
        final list = numericKeys
            .map((k) => (res[k] as Map<String, dynamic>))
            .toList();
        return list;
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }

  // ---------- AI CHAT (Gemini) ----------

  Future<String> sendChatMessage(String message, List<Map<String, String>> history) async {
    try {
      final res = await _dio.post('/ai/chat', data: {
        'message': message,
        'history': history,
      });
      return res.data['reply']?.toString() ?? 'Sorry, I did not get a response.';
    } catch (e) {
      print('AI Chat Error: $e');
      throw Exception('Failed to get AI response');
    }
  }
}
