// lib/src/doctor_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // Import ThemeNotifier

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



class DoctorPatientDashboard extends StatefulWidget {
  const DoctorPatientDashboard({super.key});

  @override
  State<DoctorPatientDashboard> createState() => _DoctorPatientDashboardState();
}

class _DoctorPatientDashboardState extends State<DoctorPatientDashboard> {
  // Key to force FutureBuilder rebuild
  int _refreshKey = 0;

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshKey++;
    });
    // Wait a bit to show the spinner
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final doctorId = session.user?['id']?.toString() ?? '';
    // Re-create API service or use existing.
    final api = ApiService();

    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use Key to force rebuild of children that depend on Futures
    final refreshKey = ValueKey(_refreshKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: () {
              themeNotifier.setMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            key: refreshKey, // Force rebuild on refresh
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DoctorHeaderCard(doctorId: doctorId, api: api),
              const SizedBox(height: 16),
              // Pending Bookings Notification Bar
              _PendingBookingsNotification(
                doctorId: doctorId,
                api: api,
                onStatusChanged: _handleRefresh,
              ),
              const SizedBox(height: 8),
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
                      context: context,
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
                      context: context,
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
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        final value = snapshot.hasData ? extractor(snapshot.data!) : 0;
        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      color: colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (doctorId.isEmpty) {
      return Text(
        'Not logged in as doctor',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
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
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          );
        }

        return Column(
          children: docs.map((data) {
            print('DEBUG Recent: ID=${data['patient_id']}, Appt=${data['appointment_id']}');
            final patient = {
              'id': data['patient_id']?.toString() ?? '',
              'appointment_id': data['appointment_id']?.toString() ?? '',
              'report_id': data['id']?.toString() ?? '', // Medical report ID for completion
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
                  backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade100,
                  child: Text(
                    patient['name']!.isNotEmpty
                        ? patient['name']![0]
                        : '?',
                    style: TextStyle(
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
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
                    Text(
                        'Age: ${patient['age']} • ${patient['condition']}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    if (labTests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Ordered: $labTests',
                          style: TextStyle(
                            color: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
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
                          fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.arrow_forward_ios, size: 16, color: colorScheme.onSurfaceVariant),
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

// ============================================================
// PENDING BOOKINGS NOTIFICATION BAR
// ============================================================
class _PendingBookingsNotification extends StatefulWidget {
  final String doctorId;
  final ApiService api;
  final VoidCallback onStatusChanged;

  const _PendingBookingsNotification({
    required this.doctorId,
    required this.api,
    required this.onStatusChanged,
  });

  @override
  State<_PendingBookingsNotification> createState() => _PendingBookingsNotificationState();
}

class _PendingBookingsNotificationState extends State<_PendingBookingsNotification> {
  List<Map<String, dynamic>> _pendingBookings = [];
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadPendingBookings();
  }

  Future<void> _loadPendingBookings() async {
    setState(() => _loading = true);
    final bookings = await widget.api.getPendingBookings(widget.doctorId);
    if (mounted) {
      setState(() {
        _pendingBookings = bookings;
        _loading = false;
      });
    }
  }

  Future<void> _handleAction(String appointmentId, String action) async {
    final result = await widget.api.updateAppointmentStatus(appointmentId, action);
    if (result != null) {
      await _loadPendingBookings();
      widget.onStatusChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'confirmed' 
                ? '✅ Appointment confirmed!' 
                : '❌ Appointment declined'),
            backgroundColor: action == 'confirmed' ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (_pendingBookings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEE2E2), Color(0xFFFECACA)], // Light red tones
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626), // Red
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Booking Requests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF991B1B), // Dark red
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_pendingBookings.length} pending approval',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB91C1C), // Medium red
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_pendingBookings.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFFB91C1C),
                  ),
                ],
              ),
            ),
          ),

          // Expanded list
          if (_expanded)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: _pendingBookings.map((booking) {
                  final patientName = booking['patient_name'] ?? 'Unknown';
                  final appointmentDate = booking['appointment_date']?.toString() ?? '';
                  final reason = booking['reason']?.toString() ?? 'General Consultation';
                  final apptId = booking['id'].toString();

                  // Parse date and time separately
                  String formattedDate = '';
                  String formattedTime = '';
                  try {
                    final dt = DateTime.parse(appointmentDate);
                    formattedDate = '${dt.day}/${dt.month}/${dt.year}';
                    formattedTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  } catch (_) {
                    formattedDate = appointmentDate;
                    formattedTime = '';
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Avatar - Professional style
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFDC2626),
                                const Color(0xFFEF4444),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Patient Details - Professional layout
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Patient Name - PROMINENT
                              Text(
                                patientName.split(' ').map((word) => 
                                  word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
                                ).join(' '),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  color: Color(0xFF1F2937),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Reason Badge - Subtle and elegant
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Date and Time - Clean inline display
                              Row(
                                children: [
                                  Icon(Icons.event_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (formattedTime.isNotEmpty) ...[
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Icon(Icons.schedule_outlined, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedTime,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Action Buttons - Elegant circular design
                        Column(
                          children: [
                            // Accept Button
                            Material(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => _handleAction(apptId, 'confirmed'),
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Decline Button
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => _handleAction(apptId, 'declined'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFEF4444)),
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}