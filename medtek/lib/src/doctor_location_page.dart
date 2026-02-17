import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/api_service.dart';
import '../models/hospital.dart';

class DoctorLocationPage extends StatefulWidget {
  const DoctorLocationPage({super.key});

  @override
  State<DoctorLocationPage> createState() => _DoctorLocationPageState();
}

class _DoctorLocationPageState extends State<DoctorLocationPage> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _currentAnnotation;

  geo.Position? _currentPosition;
  Point? _selectedPoint;
  
  bool _loadingLocation = true;
  bool _saving = false;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  List<Hospital> _searchResults = [];
  bool _isSearching = false;

  static const double _initialLat = 20.5937;
  static const double _initialLng = 78.9629;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    try {
      serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
         _setDefaultLocation();
         return;
      }

      permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
           _setDefaultLocation();
           return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
         _setDefaultLocation();
         return;
      }

      final pos = await geo.Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = pos;
        _loadingLocation = false;
        // Auto-select
        final pt = Point(coordinates: Position(pos.longitude, pos.latitude));
        _selectedPoint = pt;
      });
    } catch (e) {
      debugPrint('Location error: $e');
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _currentPosition = null; 
      _loadingLocation = false;
    });
  }

  Future<void> _updateMarker(Point point) async {
    if (_pointAnnotationManager == null) return;
    
    setState(() {
       _selectedPoint = point;
       _searchResults = []; // Clear search on manual selection
    });

    if (_currentAnnotation != null) {
      await _pointAnnotationManager!.delete(_currentAnnotation!);
    }

    final options = PointAnnotationOptions(
      geometry: point,
      iconSize: 1.5,
      textField: "📍", 
      textSize: 30,
      textOffset: [0, -1],
    );
    
    _currentAnnotation = await _pointAnnotationManager!.create(options);
  }
  
  Future<void> _searchHospitals(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() => _isSearching = true);
    try {
      final api = ApiService();
      // Use fallback lat/lng if no position yet
      final lat = _currentPosition?.latitude ?? _initialLat;
      final lng = _currentPosition?.longitude ?? _initialLng;
      
      final results = await api.searchHospitals(
        query: query,
        lat: lat,
        lng: lng,
      );
      
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(Hospital hospital) {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
      _searchController.text = hospital.name;
    });
    
    final pt = Point(coordinates: Position(hospital.longitude, hospital.latitude));
    
    // Move map
    _mapboxMap?.flyTo(
      CameraOptions(
        center: pt,
        zoom: 15,
      ),
      MapAnimationOptions(duration: 1000),
    );
    
    _updateMarker(pt);
  }

  Future<void> _saveLocation() async {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please tap on the map to select a location')));
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ApiService();
      final lng = _selectedPoint!.coordinates.lng;
      final lat = _selectedPoint!.coordinates.lat;
      
      await api.updateDoctorLocation(
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        address: _addressController.text.isNotEmpty ? _addressController.text : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location updated successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLocation) {
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final initialCamera = _currentPosition != null
        ? CameraOptions(
            center: Point(coordinates: Position(_currentPosition!.longitude, _currentPosition!.latitude)),
            zoom: 14)
        : CameraOptions(
            center: Point(coordinates: Position(_initialLng, _initialLat)),
            zoom: 4);

    return Scaffold(
      appBar: AppBar(title: const Text('Update Hospital Location')),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: MapWidget(
                  cameraOptions: initialCamera,
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                  onMapCreated: (mapboxMap) async {
                    _mapboxMap = mapboxMap;
                    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                    
                    if (_currentPosition != null) {
                        _updateMarker(Point(coordinates: Position(_currentPosition!.longitude, _currentPosition!.latitude)));
                    }
                  },
                  onTapListener: (MapContentGestureContext context) {
                     _updateMarker(context.point);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
                ),
                child: Column(
                  children: [
                    if (_selectedPoint != null)
                      Text(
                        'Selected: ${_selectedPoint!.coordinates.lat.toStringAsFixed(4)}, ${_selectedPoint!.coordinates.lng.toStringAsFixed(4)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 12),
                     TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, 
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16)
                        ),
                        child: _saving 
                           ? const CircularProgressIndicator(color: Colors.white) 
                           : const Text('SAVE LOCATION'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Search Bar Overlay
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Hospital...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching 
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) 
                        : IconButton(
                            icon: const Icon(Icons.clear), 
                            onPressed: () { 
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            }
                          ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (val) {
                       // Debounce could be added, but simple call is fine for now
                       if (val.length > 2) _searchHospitals(val);
                       else setState(() => _searchResults = []);
                    },
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: Card(
                      elevation: 4,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final hospital = _searchResults[index];
                          return ListTile(
                            title: Text(hospital.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Lat: ${hospital.latitude}, Lng: ${hospital.longitude}'),
                            onTap: () => _selectSearchResult(hospital),
                          );
                        },
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
}
