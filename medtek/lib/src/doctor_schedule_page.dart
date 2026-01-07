import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'patient_detail_page.dart';

class DoctorSchedulePage extends StatefulWidget {
  const DoctorSchedulePage({super.key});

  @override
  State<DoctorSchedulePage> createState() => _DoctorSchedulePageState();
}

class _DoctorSchedulePageState extends State<DoctorSchedulePage> {
  final _api = ApiService();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final session = context.read<SessionService>();
      final doctorId = session.user?['id']?.toString() ?? '';
      
      if (doctorId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final data = await _api.getDoctorAppointments(doctorId, date: _selectedDate);
      
      if (!mounted) return;
      setState(() {
        _appointments = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading schedule: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.red.shade400,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Schedule',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: Colors.red.shade400),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _appointments.isEmpty
                    ? _buildEmptyState()
                    : _buildTimelineList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final dateStr = DateFormat('MMMM yyyy').format(_selectedDate);
    final dayStr = DateFormat('EEE, d').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    dayStr,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.calendar_today, color: Colors.red.shade400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Day Scroller (Mock UI for visual appeal)
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (context, index) {
                // Generate relative days
                final day = _selectedDate.subtract(const Duration(days: 3)).add(Duration(days: index));
                final isSelected = index == 3; // Center is selected
                return GestureDetector(
                   onTap: () {
                     setState(() => _selectedDate = day);
                     _fetchAppointments();
                   },
                   child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    width: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red.shade400 : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(day),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade800,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // Summary
           Row(
            children: [
              _buildSummaryChip('${_appointments.length} Patients', Colors.blue.shade50, Colors.blue),
              const SizedBox(width: 10),
              _buildSummaryChip('Select Date', Colors.grey.shade100, Colors.grey.shade600, onTap: () => _selectDate(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, Color bg, Color text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No appointments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'You are free for the day!',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appt = _appointments[index];
        final time = _formatTime(appt['appointment_date']);
        
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Column
              SizedBox(
                width: 60,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      fontSize: 13
                    ),
                  ),
                ),
              ),
              // Timeline line
              Column(
                children: [
                  Container(
                    width: 2,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                         BoxShadow(
                           color: Colors.red.withOpacity(0.3),
                           blurRadius: 4,
                           spreadRadius: 2
                         )
                      ]
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: _buildAppointmentCard(appt),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  String _formatTime(String? isoDate) {
    if (isoDate == null) return '';
    final dt = DateTime.parse(isoDate);
    return DateFormat('h:mm a').format(dt);
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final name = appt['patient_name']?.toString() ?? 'Unknown';
    final age = appt['patient_age']?.toString() ?? 'N/A';
    final reason = appt['reason']?.toString() ?? 'Check-up';
    final status = appt['status']?.toString().toUpperCase() ?? 'PENDING';

    Color statusColor = Colors.orange;
    if (status == 'CONFIRMED') statusColor = Colors.green;
    if (status == 'CANCELLED') statusColor = Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to detail similar to PatientList
            final patientData = {
              'name': name,
              'age': age,
              'condition': reason, // Using reason as condition for context
            };
            Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailPage(patient: patientData)));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10
                        ),
                      ),
                    ),
                    Icon(Icons.more_horiz, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                     CircleAvatar(
                       radius: 20,
                       backgroundColor: Colors.blue.shade50,
                       child: Text(
                         name.isNotEmpty ? name[0] : '?',
                         style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                       ),
                     ),
                     const SizedBox(width: 12),
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           name,
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                         ),
                         Text(
                           'Age: $age • General',
                           style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                         ),
                       ],
                     ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Reason: $reason',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Reschedule', style: TextStyle(color: Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
