import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/session_service.dart';
import '../services/api_service.dart';
import 'patient_detail_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _selectedDate;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get doctorId {
    final session = context.read<SessionService>();
    return session.user?['doctor_id']?.toString() ??
        session.user?['id']?.toString() ??
        '';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final displayDate = DateFormat('EEE, MMM d, y').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayDate,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                InkWell(
                    onTap: () => _selectDate(context),
                    child: Text(
                      'Change',
                      style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600),
                    ))
              ],
            ),
          ),
          Expanded(
            child: doctorId.isEmpty
                ? Center(
                    child: Text(
                      'Not logged in as doctor',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _api.getDoctorAppointments(
                        doctorId: doctorId, date: dateStr),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child:
                                Text('Error loading schedule: ${snapshot.error}'));
                      }

                      final appointments = snapshot.data ?? [];

                      if (appointments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No appointments for today',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final apt = appointments[index];
                          final timeStr = apt['appointment_date'] != null
                              ? DateFormat('hh:mm a').format(
                                  DateTime.parse(apt['appointment_date'])
                                      .toLocal())
                              : '--:--';

                          final patientName =
                              apt['patient_name']?.toString() ?? 'Unknown';
                          final reason =
                              apt['reason']?.toString() ?? 'Check-up';
                          final status =
                              apt['status']?.toString().toUpperCase() ??
                                  'PENDING';

                          Color statusColor = Colors.grey;
                          if (status == 'CONFIRMED') statusColor = Colors.green;
                          if (status == 'PENDING') statusColor = Colors.orange;
                          if (status == 'COMPLETED') statusColor = Colors.blue;

                           // Construct patient object for Detail Page
                          final patientObj = <String, String>{
                            'id': apt['user_id']?.toString() ?? '',
                            'name': patientName,
                            'age': apt['patient_age']?.toString() ?? 'N/A', // might need age calc logic
                            'condition': reason,
                            'appointment_id': apt['id']?.toString() ?? '',
                            'triageDiagnosis': (apt['triage_diagnosis'] ?? '').toString(),
                            'triageTests': (apt['triage_selected_tests'] ?? '').toString(),
                          };

                          return InkWell(
                            onTap: () {
                               Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PatientDetailPage(patient: patientObj),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Time Column
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      timeStr,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.grey.shade700),
                                    ),
                                  ),
                                  // Timeline Line
                                  Column(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.blue.shade400,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                      ),
                                      Container(
                                        width: 2,
                                        height: 80,
                                        color: Colors.grey.shade300,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Card
                                  Expanded(
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  patientName,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                        color: statusColor,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              reason,
                                              style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
