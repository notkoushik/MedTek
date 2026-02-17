  // lib/services/maps_service.dart
import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, asin, pi;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapsService {
  final String apiKey;

  MapsService({required this.apiKey});

  /// Get route polyline points between two locations
  Future<List<LatLng>> getRoutePolyline(
      LatLng origin,
      LatLng destination,
      ) async {
    try {
      PolylinePoints polylinePoints = PolylinePoints();

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: apiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }

      return [origin, destination];
    } catch (e) {
      debugPrint('Failed to get route polyline: $e');
      return [origin, destination];
    }
  }

  /// Get distance and duration using Distance Matrix API
  Future<Map<String, dynamic>> getDistanceAndDuration(
      LatLng origin,
      LatLng destination,
      ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json?'
            'origins=${origin.latitude},${origin.longitude}&'
            'destinations=${destination.latitude},${destination.longitude}&'
            'key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['rows'] != null &&
            data['rows'].isNotEmpty &&
            data['rows'][0]['elements'] != null &&
            data['rows'][0]['elements'].isNotEmpty) {
          final element = data['rows'][0]['elements'][0];

          if (element['status'] == 'OK') {
            return {
              'distance': element['distance']['value'] / 1000,
              'duration': element['duration']['value'] / 60,
              'distanceText': element['distance']['text'],
              'durationText': element['duration']['text'],
            };
          }
        }
      }

      return _calculateStraightLineDistance(origin, destination);
    } catch (e) {
      debugPrint('Error getting distance and duration: $e');
      return _calculateStraightLineDistance(origin, destination);
    }
  }

  /// Calculate straight-line distance as fallback
  Map<String, dynamic> _calculateStraightLineDistance(
      LatLng origin,
      LatLng destination,
      ) {
    double distance = _haversineDistance(origin, destination);
    double duration = distance / 40 * 60; // Assuming 40km/h average speed

    return {
      'distance': distance,
      'duration': duration,
      'distanceText': '${distance.toStringAsFixed(1)} km',
      'durationText': '${duration.round()} mins',
    };
  }

  /// Haversine formula to calculate distance between two coordinates
  double _haversineDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371; // km

    // Convert to radians
    double lat1 = _toRadians(from.latitude);
    double lat2 = _toRadians(to.latitude);
    double dLat = _toRadians(to.latitude - from.latitude);
    double dLon = _toRadians(to.longitude - from.longitude);

    // Haversine formula
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  /// Reverse geocode coordinates to address
  Future<String> reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
            'latlng=${location.latitude},${location.longitude}&'
            'key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      return 'Unknown location';
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      return 'Unknown location';
    }
  }

  /// Geocode address to coordinates
  Future<LatLng?> geocodeAddress(String address) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
            'address=${Uri.encodeComponent(address)}&'
            'key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Geocoding failed: $e');
      return null;
    }
  }

  /// Get autocomplete suggestions for places
  Future<List<Map<String, dynamic>>> getPlaceSuggestions(String query) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
            'input=${Uri.encodeComponent(query)}&'
            'key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['predictions'] != null) {
          return List<Map<String, dynamic>>.from(
            data['predictions'].map((prediction) => {
              'description': prediction['description'],
              'placeId': prediction['place_id'],
            }),
          );
        }
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get place suggestions: $e');
      return [];
    }
  }

  /// Get place details by place ID
  Future<LatLng?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?'
            'place_id=$placeId&'
            'fields=geometry&'
            'key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] != null && data['result']['geometry'] != null) {
          final location = data['result']['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get place details: $e');
      return null;
    }
  }

  /// Search for nearby hospitals using Google Places Nearby Search API
  Future<List<Map<String, dynamic>>> searchNearbyHospitals(
    double lat,
    double lng, {
    int radius = 5000, // 5km default
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
            'location=$lat,$lng&'
            'radius=$radius&'
            'type=hospital&'
            'key=$apiKey',
      );

      debugPrint('🏥 Searching nearby hospitals at $lat,$lng');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'] != null) {
          final results = data['results'] as List;
          debugPrint('🏥 Found ${results.length} hospitals');

          return results.map<Map<String, dynamic>>((place) {
            final location = place['geometry']['location'];
            return {
              'id': place['place_id'] ?? '',
              'name': place['name'] ?? 'Unknown Hospital',
              'address': place['vicinity'] ?? '',
              'latitude': (location['lat'] as num).toDouble(),
              'longitude': (location['lng'] as num).toDouble(),
              'rating': place['rating']?.toDouble() ?? 0.0,
              'isOpen': place['opening_hours']?['open_now'] ?? false,
            };
          }).toList();
        } else {
          debugPrint('🏥 Places API status: ${data['status']}');
        }
      }
      return [];
    } catch (e) {
      debugPrint('Failed to search nearby hospitals: $e');
      return [];
    }
  }

  /// Search hospitals by text query
  Future<List<Map<String, dynamic>>> searchHospitalsByText(
    String query,
    double lat,
    double lng,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?'
            'query=${Uri.encodeComponent("$query hospital")}&'
            'location=$lat,$lng&'
            'radius=10000&'
            'type=hospital&'
            'key=$apiKey',
      );

      debugPrint('🔍 Text searching hospitals: $query');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'] != null) {
          final results = data['results'] as List;
          debugPrint('🔍 Found ${results.length} results');

          return results.map<Map<String, dynamic>>((place) {
            final location = place['geometry']['location'];
            return {
              'id': place['place_id'] ?? '',
              'name': place['name'] ?? 'Unknown Hospital',
              'address': place['formatted_address'] ?? place['vicinity'] ?? '',
              'latitude': (location['lat'] as num).toDouble(),
              'longitude': (location['lng'] as num).toDouble(),
              'rating': place['rating']?.toDouble() ?? 0.0,
              'isOpen': place['opening_hours']?['open_now'] ?? false,
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Failed to text search hospitals: $e');
      return [];
    }
  }
}
