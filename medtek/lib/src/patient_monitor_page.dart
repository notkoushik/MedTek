import 'package:flutter/material.dart';
import 'patient_detail_page.dart';

class PatientMonitorPage extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientMonitorPage({super.key, required this.patient});

  @override
  State<PatientMonitorPage> createState() => _PatientMonitorPageState();
}

class _PatientMonitorPageState extends State<PatientMonitorPage> {
  late List<Map<String, dynamic>> _labTests;

  @override
  void initState() {
    super.initState();
    _parseLabTests();
  }

  void _parseLabTests() {
    final rawTests = widget.patient['lab_tests']?.toString() ?? '';
    final jsonStatus = widget.patient['lab_tests_json'];

    if (rawTests.isEmpty) {
      _labTests = [];
      return;
    }

    _labTests = rawTests.split(',').map((test) {
      final name = test.trim();
      var isDone = false;
      
      // Check real status from JSON if available
      if (jsonStatus != null && jsonStatus is Map) {
        final status = jsonStatus[name];
         // Check both exact match or case-insensitive if needed, for now exact
        isDone = status == 'done';
      } else {
        // Fallback for old data or no JSON
        isDone = false; 
      }

      return {
        'name': name,
        'status': isDone ? 'Completed' : 'Pending',
        'isDone': isDone,
      };
    }).toList();
  }

  bool get _allTestsCompleted => _labTests.every((t) => t['isDone'] == true);

  @override
  Widget build(BuildContext context) {
    final name = widget.patient['name'] ?? 'Unknown';
    final age = widget.patient['age'] ?? 'N/A';
    final condition = widget.patient['condition'] ?? 'N/A';
    // Use createdAt if available, else current date
    final date = widget.patient['created_at'] != null 
        ? widget.patient['created_at'].toString().split('T')[0] 
        : DateTime.now().toString().split(' ')[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F9),
      appBar: AppBar(
        title: const Text('Patient Monitor'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Patient Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$age Years • $condition',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: $date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildInfoChip(Icons.monitor_weight_outlined, '${widget.patient['weight'] ?? 'N/A'} kg'),
                            _buildInfoChip(Icons.height, '${widget.patient['height'] ?? 'N/A'} cm'),
                            _buildInfoChip(Icons.person_outline, '${widget.patient['gender'] ?? 'N/A'}'),
                            _buildInfoChip(Icons.bloodtype_outlined, '${widget.patient['blood_group'] ?? 'N/A'}', color: Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Lab Tests Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lab Tests Monitor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_labTests.where((t) => t['isDone']).length}/${_labTests.length} Done',
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Lab Tests List
            if (_labTests.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'No lab tests ordered',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 20),
                    // If no tests ordered, enable checkout immediately
                    ElevatedButton.icon(
                          onPressed: () {
                             // Fix: Convert Map<String, dynamic> to Map<String, String>
                             final patientData = widget.patient.map((key, value) => MapEntry(key, value?.toString() ?? ''));

                             Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PatientDetailPage(patient: patientData),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Check Out / Prescribe'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _labTests.length,
                itemBuilder: (context, index) {
                  final test = _labTests[index];
                  final isDone = test['isDone'] as bool;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDone ? Colors.green.shade100 : Colors.orange.shade100,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade50,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone ? Icons.check : Icons.hourglass_top,
                          color: isDone ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        test['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDone ? Colors.black87 : Colors.black54,
                          decoration: isDone ? TextDecoration.none : null,
                        ),
                      ),
                      subtitle: Text(
                        test['status'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isDone ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
              
              // 4. Action Buttons (Only show if there are tests, otherwise handled in empty state above)
              if (_labTests.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.call),
                      label: const Text('Contact Patient'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final allDone = _labTests.every((t) => t['isDone'] == true);
                        
                        return ElevatedButton.icon(
                          onPressed: allDone ? () {
                             final patientData = widget.patient.map((key, value) => MapEntry(key, value?.toString() ?? ''));

                             Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PatientDetailPage(patient: patientData),
                              ),
                            );
                          } : null, // Disabled if not done
                          icon: Icon(allDone ? Icons.check_circle : Icons.hourglass_empty),
                          label: Text(allDone ? 'Check Out / Prescribe' : 'Patient Testing...'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allDone ? Colors.blue.shade600 : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        );
                      }
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color color = Colors.blueGrey}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
