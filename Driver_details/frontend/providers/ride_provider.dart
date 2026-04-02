// lib/providers/ride_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/ride_model.dart';
import '../services/ride_service.dart';

class RideProvider with ChangeNotifier {
  final String? googleApiKey; // still kept if you use Places API
  final RideService _rideService = RideService();

  RideModel? currentRide;
  StreamSubscription<RideModel>? _rideListener;

  RideProvider({this.googleApiKey});

  /// Create a ride via Node/Postgres backend
  Future<String?> createRideWithMode({
    required String riderId,
    required Position pickupLocation,   // Mapbox Position
    required Position dropoffLocation,  // Mapbox Position
    required String pickupAddress,
    required String dropoffAddress,
    required dynamic transportMode, // kept for compatibility with UI
    required double estimatedFare,
    required double estimatedDistance,
  }) async {
    try {
      final ride = RideModel(
        id: 'temp', // backend generates real id
        riderId: riderId,
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        status: RideStatus.requested,
        fare: estimatedFare,
        createdAt: DateTime.now(),
        distance: estimatedDistance,
        estimatedDuration: 10 * 60, // 10 minutes in seconds
      );

      final rideId = await _rideService.createRide(ride);
      return rideId;
    } catch (e) {
      debugPrint('CREATE RIDE ERROR: $e');
      return null;
    }
  }

  /// Listen to ride updates by polling backend periodically
  void listenToRideUpdates(String rideId) {
    _rideListener?.cancel();

    _rideListener = _rideService
        .getRideStream(rideId, interval: const Duration(seconds: 3))
        .listen(
          (ride) {
        currentRide = ride;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('RIDE STREAM ERROR: $e');
      },
    );
  }

  Future<void> cancelRide(String rideId) async {
    try {
      await _rideService.cancelRide(rideId);
    } catch (e) {
      debugPrint('CANCEL RIDE ERROR: $e');
    }
  }

  @override
  void dispose() {
    _rideListener?.cancel();
    super.dispose();
  }
}
