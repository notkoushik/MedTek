// lib/src/patients_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // ThemeNotifier

import '../services/session_service.dart';
import '../services/api_service.dart';
import 'patient_detail_page.dart';

class PatientsListPage extends StatefulWidget {
  final int initialIndex;
  const PatientsListPage({super.key, this.initialIndex = 0});

  @override
  State<PatientsListPage> createState() => _PatientsListPageState();
}

class _PatientsListPageState extends State<PatientsListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ApiService _api;

  String get doctorId {
    final session = context.read<SessionService>();
    return session.user?['id']?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
      vsync: this, 
      initialIndex: widget.initialIndex
    );
    _api = ApiService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: () {
              themeNotifier.setMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPatientsList('active', Colors.green),
          _buildPatientsList('pending', Colors.orange),
          _buildPatientsList('completed', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildPatientsList(String status, Color statusColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    print('DEBUG doctorId in PatientsListPage: $doctorId, status=$status');
    if (doctorId.isEmpty) {
      return Center(
        child: Text(
          'Not logged in as doctor',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _api.getDoctorPatients(doctorId: doctorId, status: status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: colorScheme.error),
            ),
          );
        }

        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No $status patients',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];

            // data is an appointment row: use its id as appointment_id
            final patient = <String, String>{
              'id': data['user_id']?.toString() ?? '',
              'name': (data['patient_name'] ?? 'Unknown').toString(),
              'age': (data['patient_age'] ?? 'N/A').toString(),
              'condition': (data['reason'] ?? 'N/A').toString(),
              'triageDiagnosis': (data['triage_diagnosis'] ?? '').toString(),
              'triageTests': (data['triage_selected_tests'] ?? '').toString(),
              // NEW: appointment id passed to PatientDetailPage
              'appointment_id': data['id']?.toString() ?? '',
              // NEW: Status tracking
              'status': data['status']?.toString() ?? 'pending',
              'reportStatus': data['report_status']?.toString() ?? '',
            };

            final aptStatus = patient['status'];
            final reportStatus = patient['reportStatus'];

            // Determine display status
            String displayStatus = 'New';
            Color statusColor = Colors.blue;

            if (aptStatus == 'completed') {
              displayStatus = 'Consultation Done';
              statusColor = Colors.green;
            } else if (aptStatus == 'testing_in_progress' || aptStatus == 'in_progress' || reportStatus == 'awaiting_lab_results') {
              displayStatus = 'Testing in Progress';
              statusColor = Colors.orange;
            } else if (aptStatus == 'pending') {
              displayStatus = 'New';
              statusColor = Colors.blue;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Text(
                    patient['name']!.isNotEmpty
                        ? patient['name']![0]
                        : '?',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        patient['name']!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (displayStatus.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          displayStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Age: ${patient['age']} • ${patient['condition']}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatientDetailPage(patient: patient),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
