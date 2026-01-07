import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        centerTitle: true,
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
    print('DEBUG doctorId in PatientsListPage: $doctorId, status=$status');
    if (doctorId.isEmpty) {
      return Center(
        child: Text(
          'Not logged in as doctor',
          style: TextStyle(color: Colors.grey.shade600),
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
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No $status patients',
              style: TextStyle(color: Colors.grey.shade600),
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
              'triageDiagnosis':
              (data['triage_diagnosis'] ?? '').toString(),
              'triageTests':
              (data['triage_selected_tests'] ?? '').toString(),
              // NEW: appointment id passed to PatientDetailPage
              'appointment_id': data['id']?.toString() ?? '',
            };

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: statusColor.withOpacity(0.2),
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
                title: Text(
                  patient['name']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Age: ${patient['age']} | ${patient['condition']}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
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
