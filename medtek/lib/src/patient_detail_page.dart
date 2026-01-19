import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../services/storage_service.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';

class PatientDetailPage extends StatefulWidget {
  /// Must include:
  ///  id              -> patient user id (string)
  ///  appointment_id  -> appointment id (string)
  final Map<String, String> patient;

  const PatientDetailPage({Key? key, required this.patient}) : super(key: key);

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  final _notesController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _descriptionTextController = TextEditingController();

  bool _saving = false;
  bool _useImageDescription = false;
  File? _descriptionImageFile;

  List<String> _selectedLabTests = [];

  final Map<String, List<String>> _labTestCategories = {
    'Blood Tests': [
      'Complete Blood Count (CBC)',
      'Blood Sugar (Fasting/PP)',
      'Lipid Profile',
      'Liver Function Test (LFT)',
      'Kidney Function Test (KFT)',
      'Thyroid Profile (T3, T4, TSH)',
    ],
    'Imaging': [
      'X-Ray Chest',
      'X-Ray Limb',
      'Ultrasound Abdomen',
      'CT Scan Brain',
      'MRI Spine',
    ],
    'Cardiac': [
      'ECG',
      '2D Echo',
      'TMT',
    ],
    'Infection / Others': [
      'Urine Routine',
      'Stool Routine',
      'COVID RT‑PCR',
      'Dengue NS1/IgM',
      'Malaria Smear',
    ],
  };

  late ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ApiService();

    final triageDx = widget.patient['triageDiagnosis'] ?? '';
    _diagnosisController.text =
    triageDx.isNotEmpty ? triageDx : (widget.patient['condition'] ?? '');

    final triageTests = widget.patient['triageTests'];
    if (triageTests != null && triageTests.isNotEmpty) {
      _selectedLabTests = triageTests
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _prescriptionController.dispose();
    _diagnosisController.dispose();
    _descriptionTextController.dispose();
    super.dispose();
  }

  Future<void> _pickDescriptionImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _descriptionImageFile = File(picked.path);
      });
    }
  }

  void _showLabTestPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Text(
                'Select Lab Tests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: StatefulBuilder(
                builder: (context, setModalState) => ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: _labTestCategories.entries.map((category) {
                    return ExpansionTile(
                      title: Text(
                        category.key,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: category.value.map((test) {
                        final isSelected = _selectedLabTests.contains(test);
                        return CheckboxListTile(
                          title: Text(test),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                _selectedLabTests.add(test);
                              } else {
                                _selectedLabTests.remove(test);
                              }
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveReport() async {
    if (_diagnosisController.text.trim().isEmpty) {
      _showMessage('Please enter a diagnosis', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final session = context.read<SessionService>();
      final doctorId = session.user?['id']?.toString();
      if (doctorId == null) {
        _showMessage('Not logged in as doctor', isError: true);
        setState(() => _saving = false);
        return;
      }

      final rawPatientId = widget.patient['id'];
      final rawAppointmentId = widget.patient['appointment_id'];

      print('DEBUG: Saving report with PatientID=$rawPatientId, ApptID=$rawAppointmentId');

      if (rawPatientId == null || rawAppointmentId == null) {
        _showMessage(
          'Missing patient or appointment id',
          isError: true,
        );
        setState(() => _saving = false);
        return;
      }

      // Robust parsing
      final patientId = int.tryParse(rawPatientId.toString().trim());
      final appointmentId = int.tryParse(rawAppointmentId.toString().trim());

      if (patientId == null || appointmentId == null) {
        _showMessage(
          'Invalid ID format: P=$rawPatientId, A=$rawAppointmentId',
          isError: true,
        );
        setState(() => _saving = false);
        return;
      }

      // Upload image to Cloudinary if selected
      String? imageUrl;
      if (_useImageDescription && _descriptionImageFile != null) {
        _showMessage('Uploading image...', isError: false);

        imageUrl = await CloudinaryService.uploadImage(_descriptionImageFile!);

        if (imageUrl == null) {
          _showMessage('Failed to upload image', isError: true);
          setState(() => _saving = false);
          return;
        }
      }

      // Call API with all required fields matching backend table
      await _api.post(
        '/medical-reports',
        data: {
          'patient_id': patientId,
          'appointment_id': appointmentId,
          'diagnosis': _diagnosisController.text.trim(),
          'prescription': _prescriptionController.text.trim(),
          'lab_tests': _selectedLabTests.join(','),
          'notes': _notesController.text.trim(),
          'description_type': _useImageDescription ? 'image' : 'text',
          'description_text':
          _useImageDescription ? '' : _descriptionTextController.text.trim(),
          'description_image_url': _useImageDescription ? imageUrl : null,
          'status':
          _selectedLabTests.isEmpty ? 'completed' : 'pending_lab_tests',
          'report_status': _selectedLabTests.isEmpty
              ? 'completed'
              : 'awaiting_lab_results',
        },
      );

      if (!mounted) return;

      if (_selectedLabTests.isNotEmpty) {
        _showMessage('Report saved! Lab tests have been ordered.');
      } else {
        _showMessage('Medical report saved successfully!');
      }

      Navigator.of(context).pop();
    } catch (e) {
      _showMessage('Error saving report: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.patient['name'] ?? 'Patient';
    final age = widget.patient['age'] ?? 'N/A';
    final condition = widget.patient['condition'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text('Patient: $name'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Age: $age • Gender: ${widget.patient['gender'] ?? 'N/A'}'),
                    Text('Weight: ${widget.patient['weight'] ?? 'N/A'} kg • Height: ${widget.patient['height'] ?? 'N/A'} cm'),
                    Text('Blood Group: ${widget.patient['blood_group'] ?? 'N/A'}'),
                    const SizedBox(height: 4),
                    Text('Reason: $condition', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Diagnosis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _diagnosisController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter diagnosis',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Prescription',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prescriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter prescription',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lab Tests',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: _showLabTestPicker,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Select'),
                ),
              ],
            ),
            if (_selectedLabTests.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                _selectedLabTests.map((t) => Chip(label: Text(t))).toList(),
              ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Text'),
                  selected: !_useImageDescription,
                  onSelected: (_) =>
                      setState(() => _useImageDescription = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Image'),
                  selected: _useImageDescription,
                  onSelected: (_) => setState(() => _useImageDescription = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_useImageDescription)
              TextField(
                controller: _descriptionTextController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type description',
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_descriptionImageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _descriptionImageFile!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(_descriptionImageFile == null
                        ? 'Upload Image'
                        : 'Change Image'),
                    onPressed: _pickDescriptionImage,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
              'Notes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Additional notes',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveReport,
                child: _saving
                    ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
                    : const Text('Save Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
