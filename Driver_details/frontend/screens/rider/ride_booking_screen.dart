// lib/pages/ride_booking_page.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:medtek/services/api_service.dart';
import 'ride_tracking_screen.dart';
import 'package:provider/provider.dart';
import '../../services/session_service.dart';

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
      final pointManager =
      await _mapboxMap!.annotations.createPointAnnotationManager();

      // Pickup marker (blue)
      final pickupMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.pickupLng, widget.pickupLat),
        ),
        iconSize: 1.5,
        iconColor: Colors.blue.value,
      );
      await pointManager.create(pickupMarker);

      // Dropoff marker (red)
      final dropoffMarker = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.dropoffLng, widget.dropoffLat),
        ),
        iconSize: 1.5,
        iconColor: Colors.red.value,
      );
      await pointManager.create(dropoffMarker);
    } catch (e) {
      debugPrint('Error adding markers: $e');
    }
  }
}
