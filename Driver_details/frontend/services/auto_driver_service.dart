import 'dart:async';
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/transport_mode.dart';
import 'api_service.dart';

class AutoDriverService {
  final ApiService _api = ApiService();

  // Simulated driver names
  static const _driverNames = [
    'Raju Kumar',
    'Venkat Reddy',
    'Srinivas Rao',
    'Ramesh Babu',
    'Anil Kumar',
    'Prakash Singh',
    'Suresh Reddy',
    'Mahesh Kumar',
  ];

  // Generate a random driver near the pickup location
  Map<String, dynamic> _generateNearbyDriver(
      LatLng pickupLocation,
      TransportMode mode,
      ) {
    final random = Random();

    // Generate driver location within ~2km radius
    final latOffset = (random.nextDouble() - 0.5) * 0.02; // ~2km
    final lngOffset = (random.nextDouble() - 0.5) * 0.02;

    final driverLat = pickupLocation.latitude + latOffset;
    final driverLng = pickupLocation.longitude + lngOffset;

    return {
      'name': _driverNames[random.nextInt(_driverNames.length)],
      'phone': '+91${9000000000 + random.nextInt(99999999)}',
      'rating': (3.5 + random.nextDouble() * 1.5).toStringAsFixed(1),
      'vehicle_number':
      'TS${random.nextInt(10)}${String.fromCharCode(65 + random.nextInt(26))}'
          '${String.fromCharCode(65 + random.nextInt(26))}'
          '${1000 + random.nextInt(9000)}',
      'driver_lat': driverLat,
      'driver_lng': driverLng,
      'mode': mode.name,
    };
  }

  /// Auto-accept ride after 10 seconds using Postgres backend.
  ///
  /// Assumes backend has:
  /// - GET /rides/:id           -> { ride: {...} }
  /// - POST /rides/:id/assign   -> body { driverName, driverPhone, ... }
  Future<void> autoAcceptRide({
    required String rideId,
    required LatLng pickupLocation,
    required TransportMode mode,
  }) async {
    print('⏰ Starting auto-accept timer for ride: $rideId');

    // Wait 10 seconds (was 30 earlier)
    await Future.delayed(const Duration(seconds: 10));

    try {
      // 1) Check if ride still exists and is pending
      final ride = await _api.getRide(rideId); // GET /rides/:id
      if (ride.isEmpty) {
        print('❌ Ride $rideId not found');
        return;
      }

      if (ride['status'] != 'requested') {
        print('⚠️ Ride already accepted or cancelled: ${ride['status']}');
        return;
      }

      // 2) Generate automated driver
      final driver = _generateNearbyDriver(pickupLocation, mode);

      // 3) Call backend to assign driver and update ride status
      await _api.assignDriver(rideId, driver);

      print('✅ Auto-accepted ride $rideId with driver: ${driver['name']}');
    } catch (e) {
      print('❌ Error auto-accepting ride: $e');
    }
  }

  /// Calculate fare based on distance and transport mode
  double calculateFare(double distanceKm, TransportMode mode) {
    return mode.basePrice + (distanceKm * mode.pricePerKm);
  }
}
