import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/ride_model.dart';
import '../models/driver_model.dart';
import 'api_service.dart';

class RideService {
  final ApiService _api = ApiService();

  // Calculate fare based on distance
  double calculateFare(double distanceKm) {
    const double baseFare = 50.0;
    const double perKmRate = 15.0;
    const double minimumFare = 80.0;

    double fare = baseFare + (distanceKm * perKmRate);
    return fare < minimumFare ? minimumFare : fare;
  }

  // Create a new ride (POST /rides)
  // lib/services/ride_service.dart
  // lib/services/ride_service.dart
  Future<String> createRide(RideModel ride) async {
    try {
      final payload = ride.toJson();

      final data = await _api.createRide(
        riderId: payload['rider_id'].toString(),
        pickupLat: (payload['pickup_lat'] as num).toDouble(),
        pickupLng: (payload['pickup_lng'] as num).toDouble(),
        dropLat: (payload['drop_lat'] as num).toDouble(),
        dropLng: (payload['drop_lng'] as num).toDouble(),
        distanceKm: (payload['distance_km'] as num?)?.toDouble(),
        estimatedFare: (payload['fare'] as num?)?.toDouble(),
      );

      // data = { "ride": { "id": 123, ... } }
      final rideMap = data['ride'] as Map<String, dynamic>;
      return rideMap['id'].toString();
    } catch (e) {
      throw Exception('Failed to create ride: $e');
    }
  }

  // Future<String> createRide(RideModel ride) async {
  //   try {
  //     final payload = ride.toJson();
  //     final rideId = await _api.createRide(payload);
  //     return rideId;
  //   } catch (e) {
  //     throw Exception('Failed to create ride: $e');
  //   }
  // }

  // Get ride by ID (GET /rides/:id)
  Future<RideModel?> getRideById(String rideId) async {
    try {
      final data = await _api.getRide(rideId);
      if (data.isEmpty) return null;
      return RideModel.fromJson(data);
    } catch (e) {
      throw Exception('Failed to get ride: $e');
    }
  }

  // Poll ride status instead of Firestore stream
  Stream<RideModel> getRideStream(String rideId,
      {Duration interval = const Duration(seconds: 3)}) async* {
    while (true) {
      final ride = await getRideById(rideId);
      if (ride == null) {
        throw Exception('Ride not found');
      }
      yield ride;
      await Future.delayed(interval);
    }
  }

  // Update ride status (PATCH /rides/:id/status or generic update)
  Future<void> updateRideStatus(String rideId, RideStatus status) async {
    try {
      await _api.updateRideStatus(rideId, status.name);
    } catch (e) {
      throw Exception('Failed to update ride status: $e');
    }
  }

  // Find nearby drivers (using your own API, not Firestore)
  Future<List<DriverModel>> findNearbyDrivers(
      LatLng location,
      double radiusKm,
      ) async {
    try {
      final driversJson =
      await _api.findNearbyDrivers(location.latitude, location.longitude, radiusKm);
      return driversJson
          .map<DriverModel>((d) => DriverModel.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to find nearby drivers: $e');
    }
  }


  Future<void> updateDriverLocation(String rideId, double lat, double lng) async {
    await _api.updateDriverLocation(rideId, lat, lng);
  }

  Future<void> verifyPin(String rideId, String pin) async {
    await _api.verifyRidePin(rideId, pin);
  }


  // Assign driver to ride (POST /rides/:id/assign already used by AutoDriverService)
  Future<void> assignDriver(String rideId, String driverId) async {
    try {
      await _api.assignDriver(rideId, {'driver_id': driverId});
    } catch (e) {
      throw Exception('Failed to assign driver: $e');
    }
  }

  // Cancel ride
  Future<void> cancelRide(String rideId) async {
    try {
      await updateRideStatus(rideId, RideStatus.cancelled);
    } catch (e) {
      throw Exception('Failed to cancel ride: $e');
    }
  }



  // Complete ride
  Future<void> completeRide(String rideId) async {
    try {
      await updateRideStatus(rideId, RideStatus.completed);
    } catch (e) {
      throw Exception('Failed to complete ride: $e');
    }
  }
}
