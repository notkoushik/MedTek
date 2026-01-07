// lib/src/doctor_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_service.dart';
import '../services/api_service.dart';
import 'patient_detail_page.dart';
import 'patients_list_page.dart';
import 'doctor_profile_page.dart';
import 'doctor_schedule_page.dart';
import 'patient_monitor_page.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DoctorPatientDashboard(),
      const PatientsListPage(),
      const DoctorProfilePage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Patients'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DoctorPatientDashboard extends StatelessWidget {
  const DoctorPatientDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final doctorId = session.user?['id']?.toString() ?? '';
    final api = ApiService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DoctorHeaderCard(doctorId: doctorId, api: api),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Today\'s\nPatients',
                    color: Colors.green,
                    icon: Icons.people,
                    future: api.getDoctorSummary(doctorId),
                    extractor: (m) => m['todaysPatients'] as int? ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientsListPage(initialIndex: 0), // Active
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Pending\nReports',
                    color: Colors.orange,
                    icon: Icons.pending_actions,
                    future: api.getDoctorSummary(doctorId),
                    extractor: (m) => m['pendingReports'] as int? ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientsListPage(initialIndex: 1), // Pending
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Lab Tests\nOrdered',
                    color: Colors.purple,
                    icon: Icons.biotech,
                    future: api.getDoctorSummary(doctorId),
                    extractor: (m) => m['labTestsOrdered'] as int? ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientsListPage(initialIndex: 2), // Completed/Labs
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Patients',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PatientsListPage(),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RecentPatientsList(doctorId: doctorId, api: api),
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Schedule',
                    icon: Icons.calendar_today,
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DoctorSchedulePage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'Reports',
                    icon: Icons.assignment,
                    color: Colors.teal,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final Future<Map<String, dynamic>> future;
  final int Function(Map<String, dynamic>) extractor;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.future,
    required this.extractor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        final value = snapshot.hasData ? extractor(snapshot.data!) : 0;
        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DoctorHeaderCard extends StatelessWidget {
  final String doctorId;
  final ApiService api;

  const _DoctorHeaderCard({
    required this.doctorId,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    if (doctorId.isEmpty) {
      return _buildCard(context, 'Doctor', 'Medical Professional');
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: api.getUserById(doctorId),
      builder: (context, snapshot) {
        String name = 'Doctor';
        String specialization = 'Medical Professional';

        if (snapshot.hasData) {
          final data = snapshot.data!;
          name = (data['name'] ?? 'Doctor').toString();
          specialization =
              (data['specialization'] ?? 'Medical Professional').toString();
        }

        return _buildCard(context, name, specialization);
      },
    );
  }

  Widget _buildCard(BuildContext context, String name, String specialization) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.red.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👋 Welcome back,',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Dr. $name',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              specialization,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPatientsList extends StatelessWidget {
  final String doctorId;
  final ApiService api;

  const _RecentPatientsList({
    required this.doctorId,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    if (doctorId.isEmpty) {
      return Text(
        'Not logged in as doctor',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.getRecentReports(doctorId: doctorId, limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No recent patients yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return Column(
          children: docs.map((data) {
            final patient = {
              'id': data['patient_id']?.toString() ?? '',
              'appointment_id': data['appointment_id']?.toString() ?? '',
              'name': (data['patient_name'] ?? 'Unknown').toString(),
              'age': (data['patient_age'] ?? 'N/A').toString(),
              'condition': (data['condition'] ?? 'N/A').toString(),
              'lab_tests': (data['lab_tests'] ?? '').toString(),
              'lab_tests_json': data['lab_tests_json'], // Keep as dynamic (Map)
              'weight': (data['weight'] ?? 'N/A').toString(),
              'height': (data['height'] ?? 'N/A').toString(),
              'gender': (data['gender'] ?? 'N/A').toString(),
              'blood_group': (data['blood_group'] ?? 'N/A').toString(),
            };
            final labTests = (data['lab_tests'] ?? '').toString();
            final createdAt = data['created_at']?.toString() ?? '';
            final timeLabel = createdAt.isNotEmpty
                ? createdAt.replaceFirst('T', ' ').split('.').first
                : 'Unknown time';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    patient['name']!.isNotEmpty
                        ? patient['name']![0]
                        : '?',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  patient['name']!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Age: ${patient['age']} • ${patient['condition']}'),
                    if (labTests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Ordered: $labTests',
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeLabel,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PatientMonitorPage(patient: {
                              ...patient,
                              'lab_tests': labTests,
                              'created_at': createdAt,
                          }),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}