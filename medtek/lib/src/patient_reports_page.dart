import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PatientReportsPage extends StatelessWidget {
  const PatientReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medical Reports'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: api.getMyMedicalReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load reports',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const Center(child: Text('No reports yet'));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final r = reports[index];
              final createdAt = DateTime.tryParse(r['created_at'] ?? '') ??
                  DateTime.now();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(r['diagnosis'] ?? 'Diagnosis'),
                  subtitle: Text(
                    '${r['condition'] ?? ''}\n'
                        '${createdAt.toLocal()}',
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientReportDetailPage(report: r),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PatientReportDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;

  const PatientReportDetailPage({super.key, required this.report});

  @override
  State<PatientReportDetailPage> createState() => _PatientReportDetailPageState();
}

class _PatientReportDetailPageState extends State<PatientReportDetailPage> {
  final _api = ApiService();
  late Map<String, dynamic> _labTestsJson;

  @override
  void initState() {
    super.initState();
    _labTestsJson = Map<String, dynamic>.from(widget.report['lab_tests_json'] ?? {});
    
    // Fallback if JSON is empty but string exists (for old reports)
    if (_labTestsJson.isEmpty) {
      final labString = widget.report['lab_tests']?.toString() ?? '';
      if (labString.isNotEmpty) {
        for (var t in labString.split(',')) {
          if (t.trim().isNotEmpty) {
             _labTestsJson[t.trim()] = 'pending';
          }
        }
      }
    }
  }

  Future<void> _toggleTest(String testName, bool? value) async {
    if (value == null) return;
    final newStatus = value ? 'done' : 'pending';
    
    // Optimistic update
    setState(() {
      _labTestsJson[testName] = newStatus;
    });

    final success = await _api.updateLabTestStatus(
      widget.report['id'].toString(), 
      testName, 
      newStatus
    );

    if (!success) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _labTestsJson[testName] = value ? 'pending' : 'done';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.report['description_image_url'] as String?;
    final isImage = widget.report['description_type'] == 'image';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lab Tests Section
            if (_labTestsJson.isNotEmpty) ...[
              const Text('Lab Tests (Check when done)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: _labTestsJson.entries.map((e) {
                    final isDone = e.value == 'done';
                    return CheckboxListTile(
                      title: Text(e.key, style: TextStyle(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : Colors.black87,
                      )),
                      value: isDone,
                      activeColor: Colors.green,
                      onChanged: (val) => _toggleTest(e.key, val),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            Text('Diagnosis',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.report['diagnosis'] ?? ''),
            const SizedBox(height: 12),
            Text('Prescription',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.report['prescription'] ?? ''),
            const SizedBox(height: 12),
            Text('Notes',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.report['notes'] ?? ''),
            const SizedBox(height: 16),
            if (isImage && imageUrl != null && imageUrl.isNotEmpty) ...[
              const Text(
                'Attached Image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ] else if (widget.report['description_text'] != null &&
                (widget.report['description_text'] as String).isNotEmpty) ...[
              const Text(
                'Description',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(widget.report['description_text']),
            ],
          ],
        ),
      ),
    );
  }
}
