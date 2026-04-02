import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DriverModel {
  final String id;
  final String name;
  final String phone;
  final double rating;
  final String vehicleNumber;
  final Position currentLocation; // Mapbox position (lng, lat)
  final bool isAvailable;
  final int currentRides;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    required this.vehicleNumber,
    required this.currentLocation,
    required this.isAvailable,
    required this.currentRides,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final lat = (json['current_lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (json['current_lng'] as num?)?.toDouble() ?? 0.0;

    return DriverModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      vehicleNumber: json['vehicle_number'] ?? '',
      currentLocation: Position(lng, lat),
      isAvailable: json['is_available'] as bool? ?? true,
      currentRides: json['current_rides'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'rating': rating,
      'vehicle_number': vehicleNumber,
      'current_lat': currentLocation.lat,
      'current_lng': currentLocation.lng,
      'is_available': isAvailable,
      'current_rides': currentRides,
    };
  }
}
