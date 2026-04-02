import 'package:flutter/material.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';

class RideSuccessPage extends StatefulWidget {
  final String rideId;
  final String hospitalName;
  final double estimatedFare;
  final double estimatedDistance;

  const RideSuccessPage({
    Key? key,
    required this.rideId,
    required this.hospitalName,
    required this.estimatedFare,
    required this.estimatedDistance,
  }) : super(key: key);

  @override
  State<RideSuccessPage> createState() => _RideSuccessPageState();
}

class _RideSuccessPageState extends State<RideSuccessPage> {
  final RideService _rideService = RideService();
  RideModel? _ride;
  bool _loading = true;
  String _status = 'requested';
  String? _driverName;
  double? _fare;
  double? _distance;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    try {
      final ride = await _rideService.getRideById(widget.rideId);
      if (!mounted) return;
      if (ride == null) {
        setState(() {
          _ride = null;
          _status = 'requested';
          _driverName = 'Driver';
          _fare = widget.estimatedFare;
          _distance = widget.estimatedDistance;
          _loading = false;
        });
        return;
      }

      setState(() {
        _ride = ride;
        _status = ride.status.name;
        _driverName = 'Driver'; // extend RideModel later if you add driver_name
        _fare = ride.fare;
        _distance = ride.distance;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ride = null;
        _status = 'requested';
        _driverName = 'Driver';
        _fare = widget.estimatedFare;
        _distance = widget.estimatedDistance;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final rideCompleted = (_status == 'completed');
    final middleText = rideCompleted
        ? 'Rate your driver: ${_driverName ?? "Driver"}'
        : (_status == 'accepted'
        ? 'Driver assigned: ${_driverName ?? "Driver"}'
        : 'Finding you a driver...');

    final fare = _fare ?? widget.estimatedFare;
    final distance = _distance ?? widget.estimatedDistance;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Ride Booked Successfully!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                middleText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: rideCompleted
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      context,
                      Icons.local_hospital,
                      'Destination',
                      widget.hospitalName,
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailRow(
                            context,
                            Icons.straighten,
                            'Distance',
                            '${distance.toStringAsFixed(1)} km',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 50,
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                        ),
                        Expanded(
                          child: _buildDetailRow(
                            context,
                            Icons.currency_rupee,
                            'Fare',
                            '₹${fare.toStringAsFixed(0)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home, size: 24),
                  label: const Text(
                    'Back to Home',
                    style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
