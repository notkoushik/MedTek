// lib/src/lab_dashboard.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class LabDashboard extends StatefulWidget {
  const LabDashboard({super.key});

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _pendingTests = [];
  Map<String, int> _stats = {'pending': 0, 'sample_collected': 0, 'completed_today': 0};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load pending tests and stats in parallel
      final results = await Future.wait([
        _api.getLabPendingTests(),
        _api.getLabStats(),
      ]);

      setState(() {
        _pendingTests = List<Map<String, dynamic>>.from(results[0]['tests'] ?? []);
        _stats = Map<String, int>.from({
          'pending': results[1]['pending'] ?? 0,
          'sample_collected': results[1]['sample_collected'] ?? 0,
          'completed_today': results[1]['completed_today'] ?? 0,
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _collectSample(int reportId, String testName) async {
    try {
      await _api.labCollectSample(reportId, testName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample collected for $testName'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadData(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _completeTest(int reportId, String testName) async {
    try {
      final result = await _api.labCompleteTest(reportId, testName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['all_tests_done'] == true
              ? '✅ All tests completed! Ready for doctor review.'
              : '✅ $testName completed'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout() async {
    await SessionService.instance.clear(); // ✅ Correct method
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Lab Dashboard'),
        backgroundColor: const Color(0xFF16213E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Cards
                          _buildStatsRow(),
                          const SizedBox(height: 24),

                          // Pending Tests Header
                          Row(
                            children: [
                              const Icon(Icons.science, color: Colors.white70),
                              const SizedBox(width: 8),
                              const Text(
                                'Pending Tests',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_pendingTests.length} tests',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Test Cards
                          if (_pendingTests.isEmpty)
                            _buildEmptyState()
                          else
                            ..._pendingTests.map((test) => _buildTestCard(test)),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending',
            _stats['pending'] ?? 0,
            Colors.orange,
            Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Collected',
            _stats['sample_collected'] ?? 0,
            Colors.blue,
            Icons.inventory_2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Done Today',
            _stats['completed_today'] ?? 0,
            Colors.green,
            Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test) {
    final status = test['test_status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final isSampleCollected = status == 'sample_collected';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? Colors.orange.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Test Name & Status Badge
          Row(
            children: [
              Expanded(
                child: Text(
                  test['test_name'] ?? 'Unknown Test',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange : Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPending ? 'PENDING' : 'SAMPLE COLLECTED',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Patient Info
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                '${test['patient_name'] ?? 'Unknown'} (${test['patient_age'] ?? 'N/A'})',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Doctor Info
          Row(
            children: [
              const Icon(Icons.medical_services, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                'Dr. ${test['doctor_name'] ?? 'Unknown'}',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final reportId = test['report_id'] as int;
                final testName = test['test_name'] as String;

                if (isPending) {
                  _collectSample(reportId, testName);
                } else if (isSampleCollected) {
                  _completeTest(reportId, testName);
                }
              },
              icon: Icon(
                isPending ? Icons.inventory_2 : Icons.check_circle,
                size: 18,
              ),
              label: Text(
                isPending ? 'Collect Sample' : 'Mark as Complete',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPending ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'All caught up!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No pending lab tests at the moment.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
