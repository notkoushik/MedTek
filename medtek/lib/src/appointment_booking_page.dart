import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/location_service.dart';
import '../screens/rider/ride_booking_screen.dart';
import 'package:geocoding/geocoding.dart';
import '../config/env_config.dart';

class BookAppointmentPage extends StatefulWidget {
  final Map<String, dynamic> doctor;   // must contain doctorId, userId, name, specialization
  final Map<String, dynamic> hospital;

  const BookAppointmentPage({
    Key? key,
    required this.doctor,
    required this.hospital,
  }) : super(key: key);

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  MapboxMap? _map;
  PointAnnotationManager? _pointManager;
  CircleAnnotationManager? _circleManager;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedReason;
  bool _isBooking = false;

  final List<String> _appointmentReasons = const [
    'General Consultation',
    'Follow-up',
    'Emergency',
    'Routine Checkup',
    'Second Opinion',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final hospitalLat =
        _toDouble(widget.hospital['latitude'] ?? widget.hospital['lat']) ??
            17.385044;
    final hospitalLng =
        _toDouble(widget.hospital['longitude'] ?? widget.hospital['lng']) ??
            78.486671;

    final hospitalPos = Position(hospitalLng, hospitalLat);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Success banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hospital location available • Transport booking enabled',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mapbox Map
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
                        key: const ValueKey('bookAppointmentMap'),
                        cameraOptions: CameraOptions(
                          center: Point(coordinates: hospitalPos),
                          zoom: 14.0,
                        ),
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                        onMapCreated: (mapboxMap) async {
                          _map = mapboxMap;

                          _pointManager ??=
                          await _map!.annotations.createPointAnnotationManager();
                          _circleManager ??=
                          await _map!.annotations.createCircleAnnotationManager();

                          await _addHospitalAnnotations(hospitalPos);
                        },
                      ),
                    ),
                  ),

                  // Doctor Info Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.red, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${widget.doctor['name']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937), // Dark gray
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.doctor['specialization']?.toString() ??
                                    'General Physician',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4B5563), // Medium gray
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.hospital['name']?.toString() ??
                                          'Hospital',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Appointment Details title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Appointment Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937), // Dark gray
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date Picker
                  _buildSelectionCard(
                    icon: Icons.calendar_today,
                    title: 'Select Date',
                    value: _selectedDate != null
                        ? DateFormat('EEEE, MMMM d, y').format(_selectedDate!)
                        : 'Choose appointment date',
                    onTap: _selectDate,
                  ),

                  // Time Picker
                  _buildSelectionCard(
                    icon: Icons.access_time,
                    title: 'Select Time',
                    value: _selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'Choose appointment time',
                    onTap: _selectTime,
                  ),

                  // Reason Dropdown
                  Container(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.medical_services,
                                  color: Colors.blue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Reason for Visit',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937), // Dark gray
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedReason,
                          decoration: InputDecoration(
                            hintText: 'Select reason',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _appointmentReasons.map((reason) {
                            return DropdownMenuItem(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedReason = value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Confirm Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canBook() ? _confirmBooking : null,
                  icon: _isBooking
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _isBooking ? 'Booking...' : 'Confirm Booking',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addHospitalAnnotations(Position hospitalPos) async {
    if (_pointManager == null || _circleManager == null) return;

    await _pointManager!.deleteAll();
    await _circleManager!.deleteAll();

    // Hospital marker (red)
    await _pointManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: hospitalPos),
        iconSize: 1.5,
      ),
    );

    await _circleManager!.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: hospitalPos),
        circleRadius: 10.0,
        circleColor: Colors.red.value,
        circleOpacity: 0.8,
      ),
    );

    // Get user location and add marker + route
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      
      // User marker (blue)
      await _circleManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: 8.0,
          circleColor: Colors.blue.value,
          circleOpacity: 0.8,
        ),
      );

      // Draw route line
      await _drawRouteLine(
        position.latitude, position.longitude,
        hospitalPos.lat.toDouble(), hospitalPos.lng.toDouble(),
      );

      // Adjust camera to show both points
      await _map!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(
            (position.longitude + hospitalPos.lng.toDouble()) / 2,
            (position.latitude + hospitalPos.lat.toDouble()) / 2,
          )),
          zoom: 12.0,
        ),
        MapAnimationOptions(duration: 800),
      );
    } catch (e) {
      debugPrint('Error getting user location for route: $e');
    }
  }

  // Draw a soft, clean route line from user to hospital
  Future<void> _drawRouteLine(double userLat, double userLng, double hospLat, double hospLng) async {
    if (_map == null) return;

    debugPrint('🗺️ Drawing route from ($userLat, $userLng) to ($hospLat, $hospLng)');

    try {
      // Fetch route from Mapbox Directions API
      final accessToken = EnvConfig.mapboxAccessToken;
      final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '$userLng,$userLat;'
          '$hospLng,$hospLat'
          '?geometries=geojson&overview=full&access_token=$accessToken';
      
      debugPrint('🌐 Fetching route from: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List;
        
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          debugPrint('✅ Got ${coordinates.length} route points');
          
          // Convert to Position list
          final routeCoords = coordinates.map<Position>((coord) => 
            Position((coord[0] as num).toDouble(), (coord[1] as num).toDouble())
          ).toList();
          
          // Use polyline annotation manager (more reliable)
          final polylineManager = await _map!.annotations.createPolylineAnnotationManager();
          await polylineManager.create(PolylineAnnotationOptions(
            geometry: LineString(coordinates: routeCoords),
            lineColor: const Color(0xFF4ECDC4).value, // Soft teal
            lineWidth: 5.0,
            lineOpacity: 0.9,
          ));
          
          debugPrint('✅ Route line drawn successfully');
        } else {
          debugPrint('⚠️ No routes found in response');
          _drawStraightLine(userLat, userLng, hospLat, hospLng);
        }
      } else {
        debugPrint('❌ API error: ${response.body}');
        _drawStraightLine(userLat, userLng, hospLat, hospLng);
      }
    } catch (e) {
      debugPrint('❌ Error drawing route: $e');
      _drawStraightLine(userLat, userLng, hospLat, hospLng);
    }
  }

  // Fallback: draw a simple straight line
  Future<void> _drawStraightLine(double userLat, double userLng, double hospLat, double hospLng) async {
    try {
      debugPrint('📏 Drawing straight line fallback');
      final polylineManager = await _map!.annotations.createPolylineAnnotationManager();
      await polylineManager.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: [
          Position(userLng, userLat),
          Position(hospLng, hospLat),
        ]),
        lineColor: const Color(0xFF4ECDC4).value,
        lineWidth: 4.0,
        lineOpacity: 0.8,
      ));
      debugPrint('✅ Straight line drawn');
    } catch (e) {
      debugPrint('❌ Fallback route error: $e');
    }
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937), // Dark gray
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4B5563), // Medium gray
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canBook() {
    return _selectedDate != null &&
        _selectedTime != null &&
        _selectedReason != null &&
        !_isBooking;
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.red),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }



  Future<void> _selectTime() async {
    // Default to now or previously selected
    final initial = _selectedTime ?? TimeOfDay.now();
    int selectedHour = initial.hourOfPeriod;
    if (selectedHour == 0) selectedHour = 12; // Handle 12 AM/PM logic
    int selectedMinute = initial.minute;
    String selectedPeriod = initial.period == DayPeriod.am ? 'AM' : 'PM';

    final result = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Center(child: Text('Select Time')),
              content: SizedBox(
                height: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // HOUR
                    _buildScrollPicker(
                      values: List.generate(12, (index) => (index + 1).toString()),
                      selectedValue: selectedHour.toString(),
                      onChanged: (val) {
                        setDialogState(() => selectedHour = int.parse(val));
                      },
                    ),
                    const Text(' : ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    // MINUTE
                    _buildScrollPicker(
                      values: List.generate(60, (index) => index.toString().padLeft(2, '0')),
                      selectedValue: selectedMinute.toString().padLeft(2, '0'),
                      onChanged: (val) {
                        setDialogState(() => selectedMinute = int.parse(val));
                      },
                    ),
                    const SizedBox(width: 10),
                    // AM/PM
                    _buildScrollPicker(
                      values: ['AM', 'PM'],
                      selectedValue: selectedPeriod,
                      onChanged: (val) {
                        setDialogState(() => selectedPeriod = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    // Convert back to TimeOfDay (24h format)
                    int hour24 = selectedHour;
                    if (selectedPeriod == 'AM' && selectedHour == 12) hour24 = 0;
                    if (selectedPeriod == 'PM' && selectedHour != 12) hour24 += 12;

                    Navigator.pop(context, TimeOfDay(hour: hour24, minute: selectedMinute));
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _selectedTime = result);
    }
  }

  Widget _buildScrollPicker({
    required List<String> values,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      width: 50,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListWheelScrollView.useDelegate(
        itemExtent: 40,
        diameterRatio: 1.2,
        perspective: 0.005,
        physics: const FixedExtentScrollPhysics(),
        controller: FixedExtentScrollController(
          initialItem: values.indexOf(selectedValue),
        ),
        onSelectedItemChanged: (index) {
          onChanged(values[index]);
        },
        childDelegate: ListWheelChildLoopingListDelegate(
          children: values.map((v) {
            final isSelected = v == selectedValue;
            return Center(
              child: Text(
                v,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.red : Colors.black,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    final session = context.read<SessionService>();
    final user = session.user;

    if (user == null) {
      _showSnack('Please sign in to book appointments', isError: true);
      return;
    }

    setState(() => _isBooking = true);

    try {
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final payload = {
        'user_id': user['id'],                        // patient users.id
        'doctor_id': widget.doctor['doctorId'],       // doctors.id
        'hospital_id': widget.hospital['id'],
        'appointment_date': appointmentDateTime.toIso8601String(),
        'reason': _selectedReason,
        'status': 'pending',
      };

      print('DEBUG createAppointment payload: $payload');

      final api = ApiService();
      await api.createAppointment(payload);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Booking Confirmed!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your appointment with Dr. ${widget.doctor['name']} has been booked successfully.',
              ),
              const SizedBox(height: 16),
              Text(
                'Date: ${DateFormat('MMMM d, y').format(_selectedDate!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Time: ${_selectedTime!.format(context)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // booking page
                Navigator.pop(context); // hospital detail page
              },
              child: const Text('OK'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.directions_car, size: 18),
              label: const Text('Book Ride'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              onPressed: () async {
                try {
                  // Show loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Getting current location...')),
                  );

                  // Get current location (automatically requests permission if needed)
                  final locService = LocationService();
                  final pos = await locService.getCurrentLocation();
                  
                  var hospLat = _toDouble(widget.hospital['latitude'] ?? widget.hospital['lat']) ?? 0.0;
                  var hospLng = _toDouble(widget.hospital['longitude'] ?? widget.hospital['lng']) ?? 0.0;

                  // Fallback if coordinates are missing
                  if (hospLat == 0.0 || hospLng == 0.0) {
                    final address = widget.hospital['address']?.toString();
                    if (address != null && address.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fetching hospital location from address...')),
                      );
                      try {
                        List<Location> locations = await locationFromAddress(address);
                        if (locations.isNotEmpty) {
                          hospLat = locations.first.latitude;
                          hospLng = locations.first.longitude;
                        }
                      } catch (e) {
                         print("Geocoding failed: $e");
                      }
                    }
                  }

                  if (hospLat == 0.0 || hospLng == 0.0) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hospital location not available. Cannot book ride.'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  if (!mounted) return;
                  
                  // Close dialog/popups
                  Navigator.pop(context); 

                  // Navigate to Ride Booking
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RideBookingPage(
                        pickupLat: pos.lat.toDouble(),
                        pickupLng: pos.lng.toDouble(),
                        dropoffLat: hospLat,
                        dropoffLng: hospLng,
                        hospitalName: widget.hospital['name']?.toString() ?? 'Hospital',
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Location error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Booking failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
