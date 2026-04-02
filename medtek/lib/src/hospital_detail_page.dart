// lib/src/hospital_detail_page.dart
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import 'appointment_booking_page.dart';
import 'doctor_detail_page.dart';
import '../screens/rider/ride_booking_screen.dart';
import '../config/env_config.dart';

class HospitalDetailPage extends StatefulWidget {
  final String hospitalId;

  const HospitalDetailPage({Key? key, required this.hospitalId})
      : super(key: key);

  @override
  State<HospitalDetailPage> createState() => _HospitalDetailPageState();
}

class _HospitalDetailPageState extends State<HospitalDetailPage> {
  Map<String, dynamic>? _hospital;
  geo.Position? _userPosition;
  bool _isLoading = true;
  double? _distance;
  MapboxMap? _mapboxMap;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final hospital = await _fetchHospital();
    final position = await _getCurrentLocation();

    double? distance;
    if (hospital != null && position != null) {
      final lat = _toDouble(hospital['latitude'] ?? hospital['lat']);
      final lng =
      _toDouble(hospital['longitude'] ?? hospital['lng'] ?? hospital['lon']);

      if (lat != null && lng != null) {
        distance = _calculateDistance(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _hospital = hospital;
      _userPosition = position;
      _distance = distance;
      _isLoading = false;
    });
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Backend returns the hospital object directly (not { hospital: {...} })
  Future<Map<String, dynamic>?> _fetchHospital() async {
    try {
      final res = await _api.getHospitalById(widget.hospitalId);
      debugPrint('Hospital detail response: $res');
      return res as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching hospital: $e');
      return null;
    }
  }

  Future<geo.Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return null;
      }

      if (permission == geo.LocationPermission.deniedForever) return null;

      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceInKm.toStringAsFixed(1)} km';
  }

  Future<void> _addHospitalMarker() async {
    if (_mapboxMap == null || _hospital == null) return;

    final hospitalLat = _toDouble(_hospital!['latitude'] ?? _hospital!['lat']);
    final hospitalLng =
    _toDouble(_hospital!['longitude'] ?? _hospital!['lng']);

    if (hospitalLat == null || hospitalLng == null) return;

    try {
      final pointManager =
      await _mapboxMap!.annotations.createPointAnnotationManager();

      final hospitalMarker = PointAnnotationOptions(
        geometry: Point(coordinates: Position(hospitalLng, hospitalLat)),
        iconSize: 2.0,
        iconColor: Colors.red.value,
      );
      await pointManager.create(hospitalMarker);

      final circleManager =
      await _mapboxMap!.annotations.createCircleAnnotationManager();
      final circleOptions = CircleAnnotationOptions(
        geometry: Point(coordinates: Position(hospitalLng, hospitalLat)),
        circleRadius: 10.0,
        circleColor: Colors.red.value,
        circleOpacity: 0.3,
      );
      await circleManager.create(circleOptions);

      if (_userPosition != null) {
        final userMarker = PointAnnotationOptions(
          geometry: Point(
            coordinates:
            Position(_userPosition!.longitude, _userPosition!.latitude),
          ),
          iconSize: 1.5,
          iconColor: Colors.blue.value,
        );
        await pointManager.create(userMarker);

        final userCircle = CircleAnnotationOptions(
          geometry: Point(
            coordinates:
            Position(_userPosition!.longitude, _userPosition!.latitude),
          ),
          circleRadius: 8.0,
          circleColor: Colors.blue.value,
          circleOpacity: 0.3,
        );
        await circleManager.create(userCircle);
        
        // Add route line from user to hospital
        await _addRouteLine(hospitalLat, hospitalLng);
      }
    } catch (e) {
      debugPrint('Error adding marker: $e');
    }
  }

  // Draw a soft, clean route line from user to hospital
  Future<void> _addRouteLine(double hospitalLat, double hospitalLng) async {
    if (_mapboxMap == null || _userPosition == null) return;

    try {
      // Fetch route from Mapbox Directions API
      final accessToken = EnvConfig.mapboxAccessToken;
      final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${_userPosition!.longitude},${_userPosition!.latitude};'
          '$hospitalLng,$hospitalLat'
          '?geometries=geojson&overview=full&access_token=$accessToken';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List;
        
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          // Create polyline coordinates
          final lineCoords = coordinates.map((coord) => 
            Position(coord[0].toDouble(), coord[1].toDouble())
          ).toList();
          
          // Add the route as a GeoJSON source and layer
          final geoJsonSource = GeoJsonSource(
            id: 'route-source',
            data: jsonEncode({
              'type': 'Feature',
              'properties': {},
              'geometry': {
                'type': 'LineString',
                'coordinates': coordinates,
              }
            }),
          );
          
          await _mapboxMap!.style.addSource(geoJsonSource);
          
          // Add a soft, clean line layer
          final lineLayer = LineLayer(
            id: 'route-layer',
            sourceId: 'route-source',
            lineColor: const Color(0xFF4ECDC4).value, // Soft teal
            lineWidth: 4.0,
            lineOpacity: 0.8,
            lineCap: LineCap.ROUND,
            lineJoin: LineJoin.ROUND,
          );
          
          await _mapboxMap!.style.addLayer(lineLayer);
          
          // Fit camera to show the entire route
          final bounds = CoordinateBounds(
            southwest: Point(coordinates: Position(
              min(_userPosition!.longitude, hospitalLng),
              min(_userPosition!.latitude, hospitalLat),
            )),
            northeast: Point(coordinates: Position(
              max(_userPosition!.longitude, hospitalLng),
              max(_userPosition!.latitude, hospitalLat),
            )),
            infiniteBounds: false,
          );
          
          await _mapboxMap!.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(
                (_userPosition!.longitude + hospitalLng) / 2,
                (_userPosition!.latitude + hospitalLat) / 2,
              )),
              zoom: 12.0,
            ),
            MapAnimationOptions(duration: 1000),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding route: $e');
      // Fallback: draw a simple straight line
      try {
        final polylineManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
        await polylineManager.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: [
            Position(_userPosition!.longitude, _userPosition!.latitude),
            Position(hospitalLng, hospitalLat),
          ]),
          lineColor: const Color(0xFF4ECDC4).value,
          lineWidth: 3.0,
          lineOpacity: 0.7,
        ));
      } catch (e2) {
        debugPrint('Fallback route error: $e2');
      }
    }
  }

  Future<void> _bookRideToHospital() async {
    if (_hospital == null) {
      _showSnackBar('Hospital data not available', isError: true);
      return;
    }
    if (_userPosition == null) {
      _showSnackBar('Please enable location services', isError: true);
      return;
    }

    double? hospitalLat =
    _toDouble(_hospital!['latitude'] ?? _hospital!['lat']);
    double? hospitalLng =
    _toDouble(_hospital!['longitude'] ?? _hospital!['lng'] ?? _hospital!['lon']);
    final hospitalName = _hospital!['name']?.toString() ?? 'Hospital';

    if (hospitalLat == null || hospitalLng == null) {
      // Fallback for demo if coordinates are missing
      hospitalLat = 17.3850;
      hospitalLng = 78.4867;
      _showSnackBar('Using mock location for demo (hospital coords missing)', isError: false);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideBookingPage(
          pickupLat: _userPosition!.latitude,
          pickupLng: _userPosition!.longitude,
          dropoffLat: hospitalLat!,
          dropoffLng: hospitalLng!,
          hospitalName: hospitalName,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Hospital Details'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.red),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hospital == null
          ? _buildErrorView()
          : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Hospital not found',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final name = _hospital!['name'] ?? 'Unknown Hospital';
    final address = _hospital!['address'] ?? 'No address available';
    final hospitalLat =
        _toDouble(_hospital!['latitude'] ?? _hospital!['lat']) ?? 17.385044;
    final hospitalLng =
        _toDouble(_hospital!['longitude'] ?? _hospital!['lng']) ?? 78.486671;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map
          Container(
            height: 250,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MapWidget(
                key: ValueKey('hospital_map_${widget.hospitalId}'),
                styleUri: MapboxStyles.MAPBOX_STREETS,
                cameraOptions: CameraOptions(
                  center:
                  Point(coordinates: Position(hospitalLng, hospitalLat)),
                  zoom: 14.0,
                ),
                onMapCreated: (mapboxMap) {
                  _mapboxMap = mapboxMap;
                  _addHospitalMarker();
                },
              ),
            ),
          ),

          if (_userPosition != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.my_location,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Location',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, 
                              fontSize: 14,
                              color: Color(0xFF1E3A5F)), // Dark blue
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_userPosition!.latitude.toStringAsFixed(5)}, '
                              '${_userPosition!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Hospital card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.redAccent],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.local_hospital,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 18,
                                color: Color(0xFF1F2937)), // Dark gray
                          ),
                          if (_distance != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.near_me,
                                      size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDistance(_distance!),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on,
                        size: 20, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        address.toString(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Enhanced Hospital Details
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hospital Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.phone_in_talk, 'Contact', '+1 (555) 123-4567'),
                const Divider(height: 24),
                _buildDetailRow(Icons.access_time_filled, 'Hours', 'Open 24 Hours'),
                const Divider(height: 24),
                _buildDetailRow(Icons.emergency, 'Emergency Services', 'Available 24/7'),
                const Divider(height: 24),
                _buildDetailRow(Icons.medical_services, 'Specialties', 'Cardiology, Neurology, Pediatrics, General'),
              ],
            ),
          ),

          const SizedBox(height: 32),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Available Doctors',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          _DoctorsList(hospitalId: widget.hospitalId, hospital: _hospital!),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctorsList extends StatelessWidget {
  final String hospitalId;
  final Map<String, dynamic> hospital;

  const _DoctorsList({required this.hospitalId, required this.hospital});

  Future<void> _bookAppointment(
      BuildContext context,
      Map<String, dynamic> doctor,
      ) async {
    // Map raw doctor from API into the shape BookAppointmentPage expects
    final mappedDoctor = {
      'doctorId': doctor['id'],
      'userId': doctor['user_id'],
      'name': doctor['name'],
      'specialization':
      doctor['specialty'] ?? doctor['specialization'] ?? 'General Physician',
      'hospital_id': doctor['hospital_id'],
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookAppointmentPage(
          doctor: mappedDoctor,
          hospital: hospital,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return FutureBuilder<Map<String, dynamic>>(
      future: api.getHospitalDoctors(hospitalId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Error loading doctors',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          );
        }

        final list = (snapshot.data?['doctors'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No doctors available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final doctor = list[index];
            final name = doctor['name']?.toString() ?? 'Doctor';
            final specialty = doctor['specialty']?.toString() ?? 'General';

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DoctorDetailPage(
                      doctor: doctor,
                      hospital: hospital,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: 'doctor_${doctor['id']}',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person,
                            size: 28, color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. $name',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.medical_information,
                                  size: 16, color: Colors.red),
                              const SizedBox(width: 6),
                              Text(
                                specialty,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => _bookAppointment(context, doctor),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Book'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
