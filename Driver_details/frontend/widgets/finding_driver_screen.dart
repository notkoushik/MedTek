import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_model.dart';
import '../../models/transport_mode.dart';
import '../../services/auto_driver_service.dart';
import '../../services/ride_service.dart';

class FindingDriverScreen extends StatefulWidget {
  final String rideId;
  final LatLng pickupLocation;
  final TransportMode mode;

  const FindingDriverScreen({
    super.key,
    required this.rideId,
    required this.pickupLocation,
    required this.mode,
  });

  @override
  State<FindingDriverScreen> createState() => _FindingDriverScreenState();
}

class _FindingDriverScreenState extends State<FindingDriverScreen> {
  final AutoDriverService _autoDriverService = AutoDriverService();
  final RideService _rideService = RideService();

  Timer? _pollTimer;
  bool _isCancelled = false;
  String _status = 'requested';

  @override
  void initState() {
    super.initState();

    // Start auto-assign using backend
    _autoDriverService.autoAcceptRide(
      rideId: widget.rideId,
      pickupLocation: widget.pickupLocation,
      mode: widget.mode,
    );

    // Poll ride status from backend
    _startPolling();
  }

  void _startPolling() {
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_isCancelled || !mounted) return;
    try {
      final ride = await _rideService.getRideById(widget.rideId);
      if (!mounted || ride == null) return;

      if (ride.status == RideStatus.accepted && !_isCancelled) {
        Navigator.pushReplacementNamed(
          context,
          '/ride-tracking',
          arguments: widget.rideId,
        );
      } else {
        setState(() => _status = ride.status.name);
      }
    } catch (_) {
      // ignore polling errors
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancelRide() async {
    setState(() => _isCancelled = true);
    await _rideService.cancelRide(widget.rideId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchingText = _status == 'accepted'
        ? 'Driver found! Redirecting...'
        : 'Searching for a driver...';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: CircularProgressIndicator(
                strokeWidth: 8,
                valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.redAccent),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              searchingText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "We’re looking for available drivers near you.\nHang tight!",
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel),
              label: const Text("Cancel Ride"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              onPressed: _isCancelled ? null : _cancelRide,
            ),
          ],
        ),
      ),
    );
  }
}
