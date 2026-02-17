import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/hospital.dart';
import '../services/api_service.dart';
import '../services/maps_service.dart';
import '../services/session_service.dart';
import 'doctor_details_dialog.dart';
import 'doctor_onboarding_guard.dart';

class SelectHospitalPage extends StatefulWidget {
  final bool isEditMode; // When true, skip the existing hospital check
  
  const SelectHospitalPage({super.key, this.isEditMode = false});

  @override
  State<SelectHospitalPage> createState() => _SelectHospitalPageState();
}

class _SelectHospitalPageState extends State<SelectHospitalPage> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;

  geo.Position? _currentPosition;
  List<Hospital> _hospitals = [];
  Hospital? _selectedHospital;

  bool _loading = true;
  bool _searching = false;
  bool _saving = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final ApiService _api = ApiService();
  // Google Maps API key for Places search
  final MapsService _mapsService = MapsService(
    apiKey: 'AIzaSyDZkvVC-1kwBR5_GwiBRiUEjNclpu0W9KY',
  );

  @override
  void initState() {
    super.initState();
    // If in edit mode, skip the hospital check and go straight to location
    if (widget.isEditMode) {
      _initLocation();
    } else {
      _checkExistingHospital();
    }
  }

  Future<void> _checkExistingHospital() async {
    try {
      final session = context.read<SessionService>();
      final role = session.user?['role'];

      if (role == 'lab_assistant') {
        // Check local session for hospital
        if (session.user?['selected_hospital_id'] != null || session.user?['hospital'] != null) {
          debugPrint('✅ Lab Assistant has hospital -> Dashboard');
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/lab-dashboard');
          return;
        }

        // Fetch existing hospitals list (Strict Mode)
        await _fetchExistingHospitals();
        return;
      } else {
        // Doctor check
        final myHospital = await _api.getMyHospital();
        if (myHospital != null && myHospital['hospital'] != null) {
          debugPrint('✅ Doctor already has hospital selected -> go to Guard');

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DoctorOnboardingGuard()),
          );
          return;
        }
      }

      debugPrint('⚠️ No hospital selected, showing selection screen');
      await _initLocation();
    } catch (e) {
      debugPrint('Check hospital error: $e');
      await _initLocation();
    }
  }

  Future<void> _fetchExistingHospitals() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getAllHospitals();
      if (!mounted) return;
      setState(() {
        _hospitals = list.map((h) => Hospital.fromJson(h)).toList();
        _loading = false;
        // Don't set _searching to true, just show list
      });
    } catch (e) {
      debugPrint('Fetch hospitals error: $e');
      setState(() => _loading = false);
    }
  }

  // ... (keeping _initLocation etc unchanged)

  Future<void> _confirmSelection() async {
    if (_selectedHospital == null) return;

    setState(() => _saving = true);

    try {
      final session = context.read<SessionService>();
      final role = session.user?['role'];
      final body = {
        'hospital_id': _selectedHospital!.id, // ✅ Send DB ID if available
        'google_place_id': _selectedHospital!.id,
        'name': _selectedHospital!.name,
        'address': _selectedHospital!.address,
        'city': 'India',
        'latitude': _selectedHospital!.latitude,
        'longitude': _selectedHospital!.longitude,
      };

      if (role == 'lab_assistant') {
        await _api.assignHospitalToUser(body);
      } else {
        await _api.selectHospitalForDoctor(body);
      }

      debugPrint('✅ Hospital selection saved');

      if (!mounted) return;

      // 2) Doctor details dialog (only on first setup, not edit mode)
      if (!widget.isEditMode && role == 'doctor') {
        final doctorId = session.user?['id']?.toString() ?? '';

        if (doctorId.isNotEmpty) {
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => DoctorDetailsDialog(doctorId: doctorId),
          );
        }
      }

      // 3) Refresh /users/me so guard reads latest values
      await session.fetchMe(_api);

      if (!mounted) return;

      // 4) Navigate based on mode
      if (widget.isEditMode) {
        // In edit mode, just pop back to profile
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Hospital updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        if (role == 'lab_assistant') {
           Navigator.of(context).pushReplacementNamed('/lab-dashboard');
        } else {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (_) => const DoctorOnboardingGuard()),
             (_) => false,
           );
        }
      }
    } catch (e) {
      debugPrint('Confirm error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ... (keeping _initLocation etc unchanged)



  Future<void> _initLocation() async {
    geo.Position fallback() => geo.Position(
      latitude: 17.3850,
      longitude: 78.4867,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentPosition = fallback();
          _loading = false;
        });
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.deniedForever ||
          permission == geo.LocationPermission.denied) {
        setState(() {
          _currentPosition = fallback();
          _loading = false;
        });
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = pos;
        _loading = false;
      });
      
      // Auto-load nearby hospitals after getting location
      _loadNearbyHospitals();
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        _currentPosition = fallback();
        _loading = false;
      });
    }
  }

  // Auto-load nearby hospitals using Google Places API
  Future<void> _loadNearbyHospitals() async {
    if (_currentPosition == null) return;

    setState(() {
      _searching = true;
      _hospitals = [];
    });

    try {
      final results = await _mapsService.searchNearbyHospitals(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        radius: 10000, // 10km radius
      );

      final hospitals = results.map((r) => Hospital.fromJson(r)).toList();

      setState(() {
        _hospitals = hospitals;
        _searching = false;
      });

      if (hospitals.isNotEmpty) {
        await _showHospitalMarkers(hospitals);
      }
    } catch (e) {
      debugPrint('Load nearby error: $e');
      setState(() => _searching = false);
    }
  }

  Future<void> _searchHospitals(String query) async {
    if (_currentPosition == null) return;
    
    // If query is empty, load nearby hospitals
    if (query.trim().isEmpty) {
      _loadNearbyHospitals();
      return;
    }

    setState(() {
      _searching = true;
      _hospitals = [];
      _selectedHospital = null;
    });

    try {
      // Use Google Places Text Search API
      final results = await _mapsService.searchHospitalsByText(
        query,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      final hospitals = results.map((r) => Hospital.fromJson(r)).toList();

      setState(() {
        _hospitals = hospitals;
        _searching = false;
      });

      if (hospitals.isNotEmpty) {
        await _showHospitalMarkers(hospitals);
      }
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _searching = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  // Calculate distance between user and hospital
  double _calculateDistance(Hospital hospital) {
    if (_currentPosition == null) return 0;
    
    const earthRadius = 6371.0; // km
    final lat1 = _currentPosition!.latitude * (pi / 180);
    final lat2 = hospital.latitude * (pi / 180);
    final dLat = (hospital.latitude - _currentPosition!.latitude) * (pi / 180);
    final dLon = (hospital.longitude - _currentPosition!.longitude) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _showHospitalMarkers(List<Hospital> hospitals) async {
    if (_pointAnnotationManager == null) return;

    await _pointAnnotationManager!.deleteAll();

    final annotations = <PointAnnotationOptions>[];
    for (final hospital in hospitals) {
      annotations.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(hospital.longitude, hospital.latitude),
          ),
          iconSize: 1.5,
        ),
      );
    }

    await _pointAnnotationManager!.createMulti(annotations);

    if (hospitals.isNotEmpty) {
      final first = hospitals.first;
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(first.longitude, first.latitude)),
          zoom: 14,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 16),
              Text('Checking hospital selection...'),
            ],
          ),
        ),
      );
    }

    final session = context.watch<SessionService>();
    final role = session.user?['role'];

    // ✅ Lab Assistant View: Simple List "Pop Down"
    if (role == 'lab_assistant') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Your Facility'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: _hospitals.isEmpty 
          ? const Center(child: Text('No hospitals available.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _hospitals.length,
              itemBuilder: (context, index) {
                final hospital = _hospitals[index];
                final isSelected = _selectedHospital?.id == hospital.id;
                
                return Card(
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.red : Colors.grey.shade200, 
                      width: isSelected ? 2 : 1
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedHospital = hospital);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.red.shade50 : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_hospital,
                              color: isSelected ? Colors.red : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hospital.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (hospital.address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    hospital.address,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: Colors.red),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
         bottomNavigationBar: SafeArea(
           child: Padding(
             padding: const EdgeInsets.all(16),
             child: ElevatedButton(
               onPressed: (_selectedHospital == null || _saving) ? null : _confirmSelection,
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.red,
                 foregroundColor: Colors.white,
                 padding: const EdgeInsets.symmetric(vertical: 16),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(12),
                 ),
               ),
               child: _saving 
                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                 : const Text('Confirm Selection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
             ),
           ),
         ),
      );
    }

    // Doctor View: Fallback to existing logic if location is null
    if (_currentPosition == null) {
       return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 16),
              Text('Acquiring location...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Hospital'),
        centerTitle: true,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search hospital by name',
                      prefixIcon: const Icon(Icons.search, color: Colors.red),
                      suffixIcon: _searching
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        ),
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    onSubmitted: _searchHospitals,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                  _searching ? null : () => _searchHospitals(_searchCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MapWidget(
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(
                        _currentPosition!.longitude,
                        _currentPosition!.latitude,
                      ),
                    ),
                    zoom: 12,
                  ),
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                  onMapCreated: (mapboxMap) async {
                    _mapboxMap = mapboxMap;
                    _pointAnnotationManager =
                    await mapboxMap.annotations.createPointAnnotationManager();
                  },
                ),
                if (_hospitals.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _selectedHospital != null ? 120 : 0,
                    child: Container(
                      height: 150,
                      color: Colors.white.withOpacity(0.95),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(8),
                        itemCount: _hospitals.length,
                        itemBuilder: (context, index) {
                          final hospital = _hospitals[index];
                          final isSelected = _selectedHospital?.id == hospital.id;

                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedHospital = hospital);
                              _mapboxMap?.flyTo(
                                CameraOptions(
                                  center: Point(
                                    coordinates:
                                    Position(hospital.longitude, hospital.latitude),
                                  ),
                                  zoom: 15,
                                ),
                                MapAnimationOptions(duration: 800),
                              );
                            },
                            child: Container(
                              width: 220,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.red.shade50
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.red
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hospital name
                                  Text(
                                    hospital.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.red.shade900
                                          : Colors.black,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Address
                                  if (hospital.address.isNotEmpty)
                                    Text(
                                      hospital.address,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const Spacer(),
                                  // Distance and rating row
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 12, color: Colors.red.shade400),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${_calculateDistance(hospital).toStringAsFixed(1)} km',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                      if (hospital.rating > 0) ...[
                                        const Spacer(),
                                        Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                                        const SizedBox(width: 2),
                                        Text(
                                          hospital.rating.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_selectedHospital != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_hospital, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedHospital!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Distance badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me, size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 4),
                            Text(
                              '${_calculateDistance(_selectedHospital!).toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Address
                  if (_selectedHospital!.address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Row(
                        children: [
                          Icon(Icons.place, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _selectedHospital!.address,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _confirmSelection,
                      icon: _saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.check_circle),
                      label: Text(_saving ? 'Saving...' : 'Use this hospital'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
