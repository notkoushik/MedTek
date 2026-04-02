// lib/pages/ride_tracking_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

import '../../services/ride_service.dart';
import '../../models/ride_model.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  const RideTrackingScreen({Key? key, required this.rideId}) : super(key: key);

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final RideService _rideService = RideService();

  MapboxMap? _map;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _lineManager;

  String? _eta;
  String? _distance;
  String? _pin;
  bool _loadingRoute = true;
  String? _status;
  Position? _driverLoc;
  Position? _pickupLoc;
  Position? _dropoffLoc;
  Timer? _pollTimer;

  static const _mapsApiKey = 'AIzaSyAdk-fdBMVWEzQVz4n-YuSErMtjM9FAjFg';

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    try {
      final ride = await _rideService.getRideById(widget.rideId);
      if (!mounted || ride == null) return;

      final newStatus = ride.status.name;
      final Position newPickup = ride.pickupLocation;
      final Position newDropoff = ride.dropoffLocation;
      final Position? newDriverLoc = ride.driverLocation;
      final String? newPin = ride.pin;

      final shouldRedraw = _status != newStatus ||
          _driverLoc != newDriverLoc ||
          _pickupLoc != newPickup ||
          _dropoffLoc != newDropoff;

      setState(() {
        _status = newStatus;
        _driverLoc = newDriverLoc;
        _pickupLoc = newPickup;
        _dropoffLoc = newDropoff;
        _pin = newPin;
      });

      if (shouldRedraw) {
        await _updateRouteAndMarkers();
      }

      if (_status == 'completed' && mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/ride-success',
          arguments: {
            'rideId': widget.rideId,
            'hospitalName': ride.dropoffAddress,
            'estimatedFare': ride.fare,
            'estimatedDistance': ride.distance,
          },
        );
      }
    } catch (e) {
      debugPrint('Ride poll error: $e');
    }
  }

  Future<void> _updateRouteAndMarkers() async {
    if (!mounted || _map == null || _pointManager == null || _lineManager == null) {
      return;
    }

    setState(() {
      _loadingRoute = true;
      _distance = null;
      _eta = null;
    });

    await _pointManager!.deleteAll();
    await _lineManager!.deleteAll();

    // Driver → Pickup when accepted/arrived
    if ((_status == 'accepted' || _status == 'arrived') &&
        _driverLoc != null &&
        _pickupLoc != null) {
      try {
        await _drawRoute(_driverLoc!, _pickupLoc!);
      } catch (e) {
        debugPrint('Draw route (driver->pickup) error: $e');
      }
      await _addPoint(_driverLoc!, isDriver: true);
      await _addPoint(_pickupLoc!, isPickup: true);
      await _moveCameraToBounds(_driverLoc!, _pickupLoc!);
    }
    // Pickup → Hospital when in progress
    else if (_status == 'in_progress' && _pickupLoc != null && _dropoffLoc != null) {
      try {
        await _drawRoute(_pickupLoc!, _dropoffLoc!);
      } catch (e) {
        debugPrint('Draw route (pickup->dropoff) error: $e');
      }
      await _addPoint(_pickupLoc!, isPickup: true);
      await _addPoint(_dropoffLoc!, isDropoff: true);
      await _moveCameraToBounds(_pickupLoc!, _dropoffLoc!);
    }
    // Default: Pickup → Hospital when searching
    else if (_pickupLoc != null && _dropoffLoc != null) {
      try {
        await _drawRoute(_pickupLoc!, _dropoffLoc!);
      } catch (e) {
        debugPrint('Draw route (pickup->dropoff) error: $e');
      }
      await _addPoint(_pickupLoc!, isPickup: true);
      await _addPoint(_dropoffLoc!, isDropoff: true);
      await _moveCameraToBounds(_pickupLoc!, _dropoffLoc!);
    }

    if (!mounted) return;
    setState(() {
      _loadingRoute = false;
    });
  }

  Future<void> _addPoint(
      Position pos, {
        bool isDriver = false,
        bool isPickup = false,
        bool isDropoff = false,
      }) async {
    if (_pointManager == null) return;

    await _pointManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: pos),
        iconSize: isDriver ? 2.0 : 1.5,
      ),
    );
  }

  Future<void> _drawRoute(Position from, Position to) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${from.lat},${from.lng}'
          '&destination=${to.lat},${to.lng}'
          '&key=$_mapsApiKey',
    );
    final response = await http.get(url);
    if (!mounted) return;

    if (response.statusCode != 200) {
      debugPrint('Directions HTTP error: ${response.statusCode}');
      return;
    }

    final data = jsonDecode(response.body);
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      debugPrint('Directions: no routes returned');
      return;
    }

    final polyline = data['routes'][0]['overview_polyline']['points'] as String;
    final decoded = PolylinePoints().decodePolyline(polyline);
    final coords = decoded.map((p) => Position(p.longitude, p.latitude)).toList();
    final leg = data['routes'][0]['legs'][0];

    if (_lineManager != null && coords.isNotEmpty) {
      await _lineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coords),
          lineColor: Colors.blue.value,
          lineWidth: 6.0,
        ),
      );
    }

    setState(() {
      _distance = leg['distance']['text'] as String?;
      _eta = leg['duration']['text'] as String?;
    });
  }

  Future<void> _moveCameraToBounds(Position a, Position b) async {
    if (_map == null) return;

    final west = min(a.lng, b.lng);
    final south = min(a.lat, b.lat);
    final east = max(a.lng, b.lng);
    final north = max(a.lat, b.lat);

    final center = Position((west + east) / 2, (south + north) / 2);

    await _map!.flyTo(
      CameraOptions(
        center: Point(coordinates: center),
        zoom: 13.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _map = mapboxMap;
    _pointManager = await _map!.annotations.createPointAnnotationManager();
    _lineManager = await _map!.annotations.createPolylineAnnotationManager();
    await _updateRouteAndMarkers();
  }

  @override
  Widget build(BuildContext context) {
    final isAccepted = _status == 'accepted' || _status == 'arrived';
    final isStarted = _status == 'in_progress';
    final showPin = (isAccepted || isStarted) && _pin != null && _pin!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Track Your Ride'),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_status != 'requested')
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map section
          Expanded(
            flex: 3,
            child: MapWidget(
              key: const ValueKey('rideTrackingMap'),
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(78.4867, 17.3850)),
                zoom: 13.0,
              ),
              onMapCreated: _onMapCreated,
            ),
          ),

          if (_loadingRoute) const LinearProgressIndicator(color: Colors.blue),

          // Info section
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Status message
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(), color: _getStatusColor(), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _getStatusMessage(),
                            style: TextStyle(
                              color: _getStatusColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Distance & ETA
                    if (_distance != null && _eta != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildInfoChip(
                            icon: Icons.straighten,
                            label: _distance!,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            icon: Icons.access_time,
                            label: _eta!,
                            color: Colors.orange,
                          ),
                        ],
                      ),

                    if ((_distance != null && _eta != null) && showPin)
                      const SizedBox(height: 16),

                    // PIN display
                    if (showPin)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.black, Colors.grey],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Your Ride PIN',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _pin!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Share this with your driver',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    switch (_status) {
      case 'requested':
        return 'Finding your driver...';
      case 'accepted':
        return 'Driver is on the way!';
      case 'arrived':
        return 'Driver has arrived';
      case 'in_progress':
        return 'Heading to hospital';
      default:
        return 'Processing...';
    }
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case 'requested':
        return Icons.search;
      case 'accepted':
        return Icons.local_taxi;
      case 'arrived':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.local_hospital;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor() {
    switch (_status) {
      case 'requested':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'arrived':
        return Colors.green;
      case 'in_progress':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
