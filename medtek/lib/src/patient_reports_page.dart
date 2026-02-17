import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class PatientReportsPage extends StatelessWidget {
  const PatientReportsPage({super.key});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final reportDate = DateTime(date.year, date.month, date.day);

    if (reportDate == today) {
      return 'Today';
    } else if (reportDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  String _getReportIcon(Map<String, dynamic> report) {
    final diagnosis = report['diagnosis']?.toString().toLowerCase() ?? '';
    
    if (diagnosis.contains('emergency')) return 'assets/icon/emergency.svg';
    if (diagnosis.contains('blood') || diagnosis.contains('sample')) return 'assets/icon/blood_sample.svg';
    if (diagnosis.contains('temperature') || diagnosis.contains('fever')) return 'assets/icon/temperature.svg';
    if (diagnosis.contains('injury') || diagnosis.contains('wound')) return 'assets/icon/bandage.svg';
    
    // Check for lab tests
    final labTests = report['lab_tests_json'] as Map<String, dynamic>?;
    if (labTests != null && labTests.isNotEmpty) {
      return 'assets/icon/microscope.svg';
    }
    
    return 'assets/icon/diagnosis.svg'; // Default
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Custom app bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Medical Reports',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Color(0xFFFAFAFA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: api.getMyMedicalReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 400,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                if (snapshot.hasError) {
                  return SizedBox(height: 400, child: _buildErrorState(context));
                }

                final reports = snapshot.data ?? [];
                
                if (reports.isEmpty) {
                  return SizedBox(height: 500, child: _buildEmptyState());
                }

                // Calculate stats
                int totalTests = 0;
                int completedTests = 0;
                for (var report in reports) {
                  final labTests = Map<String, dynamic>.from(report['lab_tests_json'] ?? {});
                  totalTests += labTests.length;
                  completedTests += labTests.values.where((v) => v == 'done').length;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              context: context,
                              svgPath: 'assets/icon/test_report.svg',
                              value: reports.length.toString(),
                              label: 'Total',
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              context: context,
                              svgPath: 'assets/icon/microscope.svg',
                              value: (totalTests - completedTests).toString(),
                              label: 'Pending',
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              context: context,
                              svgPath: 'assets/icon/diagnosis.svg',
                              value: completedTests.toString(),
                              label: 'Done',
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Section Header
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        'Recent Reports',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),

                    // Reports List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final r = reports[index];
                        return _buildReportCard(context, r);
                      },
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String svgPath,
    required String value,
    required String label,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            svgPath,
            width: 40,
            height: 40,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> report) {
    final createdAt = DateTime.tryParse(report['created_at'] ?? '') ?? DateTime.now();
    final diagnosis = report['diagnosis']?.toString() ?? 'Medical Report';
    final labTests = Map<String, dynamic>.from(report['lab_tests_json'] ?? {});
    final totalTests = labTests.length;
    final completedTests = labTests.values.where((v) => v == 'done').length;
    final hasTests = totalTests > 0;
    final iconPath = _getReportIcon(report);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientReportDetailPage(report: report),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          iconPath,
                          width: 32,
                          height: 32,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFDC2626),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diagnosis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(createdAt),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Colors.grey[350],
                    ),
                  ],
                ),
                if (hasTests) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: completedTests == totalTests
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SvgPicture.asset(
                            'assets/icon/microscope.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              completedTests == totalTests
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lab Tests',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$completedTests of $totalTests completed',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: completedTests == totalTests
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            completedTests == totalTests ? 'Complete' : 'Pending',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icon/test_report.svg',
            width: 120,
            height: 120,
            colorFilter: const ColorFilter.mode(
              Color(0xFFD1D5DB),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'No Medical Reports',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your medical reports will appear here\nafter your consultations',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Failed to load reports',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please try again later',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
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
    
    setState(() {
      _labTestsJson[testName] = newStatus;
    });

    final success = await _api.updateLabTestStatus(
      widget.report['id'].toString(), 
      testName, 
      newStatus
    );

    if (!success) {
      if (mounted) {
        setState(() {
          _labTestsJson[testName] = value ? 'pending' : 'done';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'))
        );
      }
    }
  }

  void _confirmAllTestsDone() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'All Tests Complete!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your lab test results have been saved successfully. Your doctor will be notified.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to reports list
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.report['description_image_url'] as String?;
    final isImage = widget.report['description_type'] == 'image';
    final totalTests = _labTestsJson.length;
    final completedTests = _labTestsJson.values.where((v) => v == 'done').length;
    final progress = totalTests > 0 ? completedTests / totalTests : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icon/diagnosis.svg',
                        width: 36,
                        height: 36,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFDC2626),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.report['diagnosis']?.toString() ?? 'Medical Report',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, yyyy • h:mm a').format(
                            DateTime.tryParse(widget.report['created_at'] ?? '') ?? DateTime.now(),
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Lab Tests Section
            if (_labTestsJson.isNotEmpty) ...[
              _buildSectionCard(
                context: context,
                svgPath: 'assets/icon/microscope.svg',
                title: 'Lab Tests',
                badgeText: '$completedTests/$totalTests',
                badgeColor: completedTests == totalTests
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completedTests == totalTests 
                              ? const Color(0xFF10B981) 
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._labTestsJson.entries.map((e) {
                      final isDone = e.value == 'done';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDone 
                              ? const Color(0xFFD1FAE5) 
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDone 
                                ? const Color(0xFF6EE7B7) 
                                : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            e.key,
                            style: TextStyle(
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone 
                                  ? const Color(0xFF6B7280) 
                                  : const Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          value: isDone,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (val) => _toggleTest(e.key, val),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: completedTests == totalTests 
                            ? () => _confirmAllTestsDone()
                            : null,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(
                          completedTests == totalTests 
                              ? 'All Tests Complete!' 
                              : 'Mark all tests as done to continue',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          disabledForegroundColor: const Color(0xFF9CA3AF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Diagnosis Card
            _buildInfoCard(
              context: context,
              svgPath: 'assets/icon/diagnosis.svg',
              title: 'Diagnosis',
              content: widget.report['diagnosis']?.toString() ?? 'N/A',
              color: const Color(0xFF4A90E2),
            ),

            const SizedBox(height: 12),

            // Prescription Card
            _buildInfoCard(
              context: context,
              svgPath: 'assets/icon/Precription.svg',
              title: 'Prescription',
              content: widget.report['prescription']?.toString() ?? 'N/A',
              color: const Color(0xFF10B981), // Teal green - professional medical color
            ),

            const SizedBox(height: 12),

            // Notes Card
            if (widget.report['notes'] != null && widget.report['notes'].toString().isNotEmpty)
              _buildInfoCard(
                context: context,
                svgPath: 'assets/icon/description.svg',
                title: 'Notes',
                content: widget.report['notes']?.toString() ?? '',
                color: const Color(0xFFF59E0B),
              ),

            const SizedBox(height: 12),

            // Image/Description Card
            if (isImage && imageUrl != null && imageUrl.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attached Image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else if (widget.report['description_text'] != null &&
                (widget.report['description_text'] as String).isNotEmpty) ...[
              _buildInfoCard(
                context: context,
                svgPath: 'assets/icon/description.svg',
                title: 'Description',
                content: widget.report['description_text']?.toString() ?? '',
                color: const Color(0xFF14B8A6),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 24),

            // Status Banner - shows consultation status
            Builder(
              builder: (context) {
                final status = widget.report['status']?.toString() ?? '';
                final reportStatus = widget.report['report_status']?.toString() ?? '';
                final allTestsDone = _labTestsJson.isNotEmpty && 
                    _labTestsJson.values.every((v) => v == 'done');
                
                // Show "Report Finalized" when status is finalized/completed
                if (status == 'finalized' || status == 'completed') {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Consultation Complete',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your report has been finalized by your doctor',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Show "Awaiting Doctor Review" when all tests done but not finalized
                if (allTestsDone && reportStatus == 'completed' && status != 'finalized') {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Awaiting Doctor Review',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'All tests complete. Doctor will finalize soon.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String svgPath,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(
                  svgPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF6B7280),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String svgPath,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(
                  svgPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    color,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
