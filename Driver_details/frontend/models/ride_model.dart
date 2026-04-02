import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

enum RideStatus {
  requested,
  accepted,
  arrived,
  pickupReached,
  onRide,
  inProgress,
  completed,
  cancelled,
}

extension RideStatusExtension on RideStatus {
  String get name {
    switch (this) {
      case RideStatus.requested:
        return 'requested';
      case RideStatus.accepted:
        return 'accepted';
      case RideStatus.arrived:
        return 'arrived';
      case RideStatus.pickupReached:
        return 'pickupReached';
      case RideStatus.onRide:
        return 'onRide';
      case RideStatus.inProgress:
        return 'in_progress';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.cancelled:
        return 'cancelled';
    }
  }
}

class RideModel {
  final String id;
  final String riderId;
  final Position pickupLocation;   // lng, lat
  final Position dropoffLocation;  // lng, lat
  final String pickupAddress;
  final String dropoffAddress;
  final RideStatus status;
  final double fare;
  final DateTime createdAt;
  final double distance;
  final int estimatedDuration;
  final String? driverId;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? pin;
  final Position? driverLocation;  // lng, lat from driver_lat/driver_lng

  RideModel({
    required this.id,
    required this.riderId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.status,
    required this.fare,
    required this.createdAt,
    required this.distance,
    required this.estimatedDuration,
    this.driverId,
    this.acceptedAt,
    this.completedAt,
    this.pin,
    this.driverLocation,
  });

  double get estimatedFare => fare;
  double get estimatedDistance => distance;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rider_id': riderId,
      'pickup_lat': pickupLocation.lat,
      'pickup_lng': pickupLocation.lng,
      'drop_lat': dropoffLocation.lat,
      'drop_lng': dropoffLocation.lng,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'status': status.name,
      'fare': fare,
      'created_at': createdAt.toIso8601String(),
      'distance_km': distance,
      'estimated_duration_sec': estimatedDuration,
      'driver_id': driverId,
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'pin': pin,
      'driver_lat': driverLocation?.lat,
      'driver_lng': driverLocation?.lng,
    };
  }

  // helpers to safely parse numbers coming as num or String
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory RideModel.fromJson(Map<String, dynamic> data) {
    final pickupLat = _toDouble(data['pickup_lat']);
    final pickupLng = _toDouble(data['pickup_lng']);
    final dropLat = _toDouble(data['drop_lat']);
    final dropLng = _toDouble(data['drop_lng']);

    final driverLat = _toDouble(data['driver_lat']);
    final driverLng = _toDouble(data['driver_lng']);
    final hasDriverLoc = driverLat != 0.0 || driverLng != 0.0;

    return RideModel(
      id: data['id'].toString(),
      riderId: data['rider_id'].toString(),
      pickupLocation: Position(pickupLng, pickupLat),
      dropoffLocation: Position(dropLng, dropLat),
      pickupAddress: data['pickup_address'] ?? '',
      dropoffAddress: data['dropoff_address'] ?? '',
      status: _parseStatus(data['status'] as String?),
      fare: _toDouble(data['fare']),
      createdAt: DateTime.parse(
        (data['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      distance: _toDouble(data['distance_km']),
      estimatedDuration: _toInt(data['estimated_duration_sec']),
      driverId: data['driver_id']?.toString(),
      acceptedAt: _parseDateTime(data['accepted_at']),
      completedAt: _parseDateTime(data['completed_at']),
      pin: data['pin']?.toString(),
      driverLocation:
      hasDriverLoc ? Position(driverLng, driverLat) : null,
    );
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  static RideStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return RideStatus.accepted;
      case 'arrived':
        return RideStatus.arrived;
      case 'pickupreached':
        return RideStatus.pickupReached;
      case 'onride':
        return RideStatus.onRide;
      case 'in_progress':
      case 'inprogress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      default:
        return RideStatus.requested;
    }
  }

  RideModel copyWith({
    String? id,
    String? riderId,
    Position? pickupLocation,
    Position? dropoffLocation,
    String? pickupAddress,
    String? dropoffAddress,
    RideStatus? status,
    double? fare,
    DateTime? createdAt,
    double? distance,
    int? estimatedDuration,
    String? driverId,
    DateTime? acceptedAt,
    DateTime? completedAt,
    String? pin,
    Position? driverLocation,
  }) {
    return RideModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      status: status ?? this.status,
      fare: fare ?? this.fare,
      createdAt: createdAt ?? this.createdAt,
      distance: distance ?? this.distance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      driverId: driverId ?? this.driverId,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      pin: pin ?? this.pin,
      driverLocation: driverLocation ?? this.driverLocation,
    );
  }
}
