// lib/src/hospital_selection_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../services/api_service.dart';
import 'hospital_detail_page.dart';

class HospitalSelectionPage extends StatefulWidget {
  final Map<String, dynamic> triageResult;
  final List<String> recommendedSpecialties;
  final List<Map<String, dynamic>> nearbyDoctors;

  const HospitalSelectionPage({
    Key? key,
    required this.triageResult,
    required this.recommendedSpecialties,
    required this.nearbyDoctors,
  }) : super(key: key);

  @override
  State<HospitalSelectionPage> createState() => _HospitalSelectionPageState();
}

class _HospitalSelectionPageState extends State<HospitalSelectionPage> {
  bool _loading = true;
  bool _showMap = true;
  List<Map<String, dynamic>> _hospitals = [];
  String? _errorMessage;
  geo.Position? _userPosition;
  MapboxMap? _mapboxMap;

  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final position = await _getCurrentLocation();

      // Get hospitals from both DB and Google Places
      final dbHospitals = await _api.getHospitals();
      final dbItems = dbHospitals.cast<Map<String, dynamic>>();

      List<Map<String, dynamic>> liveItems = [];
      if (position != null) {
        liveItems = await _api.getLiveNearbyHospitals(
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: 10, // 10km radius
        );
      }

      // Merge: DB hospitals + live nearby hospitals
      final allItems = [...dbItems, ...liveItems];

      debugPrint('Hospitals loaded: ${dbItems.length} from DB + ${liveItems.length} from Google Places');

      // Calculate distances for all
      if (position != null) {
        for (final hospital in allItems) {
          final lat = _toDouble(hospital['latitude']);
          final lng = _toDouble(hospital['longitude']);

          if (lat != null && lng != null) {
            final distance = _calculateDistance(
              position.latitude,
              position.longitude,
              lat,
              lng,
            );
            hospital['distance'] = distance;
          }
        }

        // Sort by distance
        allItems.sort((a, b) {
          final distA = (a['distance'] ?? double.infinity) as num;
          final distB = (b['distance'] ?? double.infinity) as num;
          return distA.compareTo(distB);
        });
      }

      if (!mounted) return;
      setState(() {
        _hospitals = allItems;
        _userPosition = position;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load hospitals: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _loadData,
          ),
        ),
      );
    }
  }

  Future<geo.Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return null;
      }

      if (permission == geo.LocationPermission.deniedForever) return null;

      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceInKm.toStringAsFixed(1)} km away';
  }

  Future<void> _addHospitalMarkers() async {
    if (_mapboxMap == null || _hospitals.isEmpty) return;

    try {
      final pointManager =
      await _mapboxMap!.annotations.createPointAnnotationManager();
      final circleManager =
      await _mapboxMap!.annotations.createCircleAnnotationManager();

      // User marker
      if (_userPosition != null) {
        final userPos =
        Position(_userPosition!.longitude, _userPosition!.latitude);

        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: userPos),
            iconSize: 1.8,
            iconColor: Colors.blue.value,
          ),
        );

        await circleManager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: userPos),
            circleRadius: 8.0,
            circleColor: Colors.blue.value,
            circleOpacity: 0.3,
          ),
        );
      }

      // Hospitals with valid coordinates
      for (final hospital in _hospitals) {
        final lat = _toDouble(hospital['latitude']);
        final lng = _toDouble(hospital['longitude']);
        if (lat == null || lng == null) continue;

        final pos = Position(lng, lat);

        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: pos),
            iconSize: 1.5,
            iconColor: Colors.red.value,
          ),
        );

        await circleManager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: pos),
            circleRadius: 8.0,
            circleColor: Colors.red.value,
            circleOpacity: 0.2,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding markers: $e');
    }
  }

  void _selectHospital(Map<String, dynamic> hospital) {
    final source = hospital['source']?.toString();

    if (source == 'google_places') {
      // For now, show a message that Google Places hospitals can't show details
      // (since they're not in your DB and have no doctors)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${hospital['name']} - External hospital (details not available)'),
          action: SnackBarAction(
            label: 'Book Ride',
            onPressed: () {
              // Navigate directly to ride booking with this hospital's coordinates
              Navigator.pushNamed(
                context,
                '/ride-booking',
                arguments: {
                  'pickupLat': _userPosition?.latitude,
                  'pickupLng': _userPosition?.longitude,
                  'dropoffLat': hospital['latitude'],
                  'dropoffLng': hospital['longitude'],
                  'hospitalName': hospital['name'],
                },
              );
            },
          ),
        ),
      );
      return;
    }

    // DB hospital - navigate to detail page as before
    debugPrint('Selected hospital: ${hospital['id']} ${hospital['name']}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalDetailPage(
          hospitalId: hospital['id'].toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Choose Hospital'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_loading) ...[
            IconButton(
              icon: Icon(_showMap ? Icons.list : Icons.map),
              onPressed: () => setState(() => _showMap = !_showMap),
              tooltip: _showMap ? 'List View' : 'Map View',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Loading hospitals...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load hospitals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hospitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_hospital_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No hospitals available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hospitals will appear here once doctors add them',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _showMap ? _buildMapView() : _buildListView();
  }

  Widget _buildMapView() {
    final first = _hospitals.first;
    final centerLat =
        _userPosition?.latitude ?? _toDouble(first['latitude']) ?? 17.385044;
    final centerLng =
        _userPosition?.longitude ?? _toDouble(first['longitude']) ?? 78.486671;

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('hospital_selection_map'),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(centerLng, centerLat)),
            zoom: 12.0,
          ),
          onMapCreated: (mapboxMap) {
            _mapboxMap = mapboxMap;
            _addHospitalMarkers();
          },
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.18,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.18, 0.35, 0.6, 0.85],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Improved drag handle
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_hospitals.length} Hospitals Found',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_userPosition != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.near_me,
                                    size: 14, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Sorted by distance',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _hospitals.length,
                      itemBuilder: (context, index) =>
                          _buildHospitalCard(_hospitals[index]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_hospitals.length} Hospitals Found',
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_userPosition != null)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.near_me,
                          size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Sorted by distance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _hospitals.length,
            itemBuilder: (context, index) =>
                _buildHospitalCard(_hospitals[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> hospital) {
    final name = hospital['name']?.toString() ?? 'Hospital';
    final address =
    (hospital['address'] ?? hospital['location_name'] ?? '').toString();
    final distance = hospital['distance'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
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
          onTap: () => _selectHospital(hospital),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.redAccent],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_hospital,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (distance != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.near_me,
                                  size: 12, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                _formatDistance(distance as double),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Select',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
