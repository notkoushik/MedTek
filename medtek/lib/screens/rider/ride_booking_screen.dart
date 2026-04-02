// lib/pages/ride_booking_page.dart
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:medtek/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'ride_tracking_screen.dart';
import 'package:provider/provider.dart';
import '../../services/session_service.dart';
import '../../services/auto_driver_service.dart';
import '../../models/transport_mode.dart';
import '../../config/env_config.dart';

class RideBookingPage extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String hospitalName;

  const RideBookingPage({
    Key? key,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.hospitalName,
  }) : super(key: key);

  @override
  State<RideBookingPage> createState() => _RideBookingPageState();
}

class _RideBookingPageState extends State<RideBookingPage> {
  MapboxMap? _mapboxMap;
  final _api = ApiService();
  bool _booking = false;

  double? _distanceKm;
  double? _estimatedFare;

  @override
  void initState() {
    super.initState();
    _computeDistanceAndFare();
  }

  void _computeDistanceAndFare() {
    final d = _haversine(
      widget.pickupLat,
      widget.pickupLng,
      widget.dropoffLat,
      widget.dropoffLng,
    );
    const baseFare = 30.0;
    const perKm = 12.0;
    setState(() {
      _distanceKm = d;
      _estimatedFare = baseFare + perKm * d;
    });
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return r * c;
  }

  double _deg2rad(double d) => d * pi / 180;

  Future<void> _createRide() async {
    if (_booking) return;

    final session = context.read<SessionService>();
    final riderId = session.user?['id']?.toString();
    if (riderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in')),
      );
      return;
    }

    setState(() => _booking = true);

    final res = await _api.createRide(
      riderId: riderId,
      pickupLat: widget.pickupLat,
      pickupLng: widget.pickupLng,
      dropLat: widget.dropoffLat,
      dropLng: widget.dropoffLng,
      distanceKm: _distanceKm,
      estimatedFare: _estimatedFare,
    );

    final rideId = res['ride']['id'].toString();

    // Start auto-driver simulation
    AutoDriverService().autoAcceptRide(
      rideId: rideId,
      pickupLat: widget.pickupLat,
      pickupLng: widget.pickupLng,
      mode: TransportMode.auto, // Default to Auto for now
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RideTrackingScreen(rideId: rideId),
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Ride'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: MapWidget(
              styleUri: MapboxStyles.MAPBOX_STREETS,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    (widget.pickupLng + widget.dropoffLng) / 2,
                    (widget.pickupLat + widget.dropoffLat) / 2,
                  ),
                ),
                zoom: 13.0,
              ),
              onMapCreated: (mapboxMap) async {
                _mapboxMap = mapboxMap;
                await _addMarkers();
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Destination',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  widget.hospitalName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_distanceKm != null && _estimatedFare != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '~${_distanceKm!.toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '₹${_estimatedFare!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _booking ? null : _createRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _booking
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Confirm ride',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Driver assignment & live tracking can be added later.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null) return;

    try {
      // Create circle annotation manager for markers
      final circleManager =
          await _mapboxMap!.annotations.createCircleAnnotationManager();

      // Pickup marker (blue circle)
      await circleManager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(widget.pickupLng, widget.pickupLat),
          ),
          circleRadius: 10.0,
          circleColor: Colors.blue.value,
          circleOpacity: 0.9,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        ),
      );

      // Dropoff marker (red circle)
      await circleManager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(widget.dropoffLng, widget.dropoffLat),
          ),
          circleRadius: 10.0,
          circleColor: Colors.red.value,
          circleOpacity: 0.9,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
      
      // Add route line
      await _addRouteLine();
    } catch (e) {
      debugPrint('Error adding markers: $e');
    }
  }

  // Draw a soft, clean route line from pickup to dropoff
  Future<void> _addRouteLine() async {
    if (_mapboxMap == null) return;
    
    debugPrint('🗺️ Drawing route from (${widget.pickupLat}, ${widget.pickupLng}) to (${widget.dropoffLat}, ${widget.dropoffLng})');
    
    try {
      // Fetch route from Mapbox Directions API
      final accessToken = EnvConfig.mapboxAccessToken;
      final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${widget.pickupLng},${widget.pickupLat};'
          '${widget.dropoffLng},${widget.dropoffLat}'
          '?geometries=geojson&overview=full&access_token=$accessToken';
      
      debugPrint('🌐 Fetching route from API...');
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
          final polylineManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
          await polylineManager.create(PolylineAnnotationOptions(
            geometry: LineString(coordinates: routeCoords),
            lineColor: const Color(0xFF4ECDC4).value, // Soft teal
            lineWidth: 5.0,
            lineOpacity: 0.9,
          ));
          
          debugPrint('✅ Route line drawn successfully');
          
          // Fit camera to show the entire route
          final centerLng = (widget.pickupLng + widget.dropoffLng) / 2;
          final centerLat = (widget.pickupLat + widget.dropoffLat) / 2;
          
          await _mapboxMap!.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(centerLng, centerLat)),
              zoom: 12.0,
            ),
            MapAnimationOptions(duration: 800),
          );
        } else {
          debugPrint('⚠️ No routes found');
          _drawStraightLine();
        }
      } else {
        debugPrint('❌ API error: ${response.statusCode}');
        _drawStraightLine();
      }
    } catch (e) {
      debugPrint('❌ Error drawing route: $e');
      _drawStraightLine();
    }
  }

  // Fallback: draw a simple straight line
  Future<void> _drawStraightLine() async {
    try {
      debugPrint('📏 Drawing straight line fallback');
      final polylineManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
      await polylineManager.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: [
          Position(widget.pickupLng, widget.pickupLat),
          Position(widget.dropoffLng, widget.dropoffLat),
        ]),
        lineColor: const Color(0xFF4ECDC4).value,
        lineWidth: 4.0,
        lineOpacity: 0.8,
      ));
      debugPrint('✅ Straight line drawn');
    } catch (e2) {
      debugPrint('❌ Fallback route error: $e2');
    }
  }
}
