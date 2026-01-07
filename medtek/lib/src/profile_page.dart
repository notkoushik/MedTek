// lib/src/patient_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../services/session_service.dart';
import '../services/api_service.dart';
import 'auth_page.dart';
import 'patient_reports_page.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({Key? key}) : super(key: key);

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final _api = ApiService();
  final ageController = TextEditingController();
  final referenceController = TextEditingController();
  final insuranceController = TextEditingController();

  List<String> references = [];
  List<String> insurances = [];
  Map<String, dynamic>? assignedDoctor;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  // Activities state
  List<Map<String, dynamic>> activities = [];
  bool _loadingActivities = true;

  // Profile picture state
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final session = context.read<SessionService>();
      final patientId = session.user?['id']?.toString() ?? '';

      if (patientId.isEmpty) {
        setState(() {
          _loading = false;
          _loadingActivities = false;
        });
        return;
      }

      final profile = await _api.getPatientProfile(patientId);

      setState(() {
        ageController.text = profile['age']?.toString() ?? '';
        references = List<String>.from(profile['reference_notes'] != null
            ? (profile['reference_notes'] is String
            ? []
            : profile['reference_notes'])
            : []);
        insurances = List<String>.from(profile['insurances'] != null
            ? (profile['insurances'] is String
            ? []
            : profile['insurances'])
            : []);
        assignedDoctor = profile['assigned_doctor'] as Map<String, dynamic>?;

        // Load profile picture from session
        final user = session.user;
        final profilePic = user?['profile_picture']?.toString();
        if (profilePic != null && profilePic.isNotEmpty) {
          _profilePictureUrl = _api.getProfilePictureUrl(profilePic);
        }

        _loading = false;
      });

      await _loadActivities(patientId);
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _loading = false;
        _loadingActivities = false;
      });
    }
  }

  Future<void> _loadActivities(String patientId) async {
    setState(() => _loadingActivities = true);
    try {
      final list = await _api.getPatientActivities(patientId, status: 'all');
      if (!mounted) return;
      setState(() {
        activities = list;
        _loadingActivities = false;
      });
    } catch (e) {
      print('Error loading activities: $e');
      if (!mounted) return;
      setState(() {
        activities = [];
        _loadingActivities = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _uploading = true);

    try {
      final imageFile = File(pickedFile.path);
      final session = context.read<SessionService>();
      final userId = session.user?['id']?.toString();

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Upload and get updated user
      final updatedUser = await _api.uploadProfilePicture(
        userId: userId,
        imageFile: imageFile,
      );

      if (!mounted) return;

      // Update profile picture URL immediately
      final profilePic = updatedUser['profile_picture']?.toString();
      setState(() {
        _uploading = false;
        if (profilePic != null && profilePic.isNotEmpty) {
          _profilePictureUrl = _api.getProfilePictureUrl(profilePic);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile picture updated!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _uploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Upload failed: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final session = context.read<SessionService>();
      final patientId = session.user?['id']?.toString() ?? '';

      await _api.updatePatientProfileData(
        patientId,
        {
          'age': int.tryParse(ageController.text) ?? 0,
          'references': references,
          'insurances': insurances,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final session = context.read<SessionService>();
    await session.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
          (_) => false,
    );
  }

  void _addReference() {
    final ref = referenceController.text.trim();
    if (ref.isNotEmpty) {
      setState(() {
        references.add(ref);
        referenceController.clear();
      });
    }
  }

  void _addInsurance() {
    final ins = insuranceController.text.trim();
    if (ins.isNotEmpty) {
      setState(() {
        insurances.add(ins);
        insuranceController.clear();
      });
    }
  }

  Widget _buildActivitiesSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.red.shade100.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark ? Border.all(color: Colors.white10) : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFE3F2FD),
              child: const Icon(Icons.history, color: Colors.blue),
            ),
            title: Text(
              'My Activities',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Recent actions, appointments and posts',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            trailing: TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/activities');
              },
              child: const Text('View all'),
            ),
          ),
          const Divider(height: 8),
          if (_loadingActivities)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No recent activities.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          else
            Column(
              children: activities.take(5).map((act) {
                final title = act['title'] ?? act['type'] ?? 'Activity';
                final subtitle = act['details'] ?? act['description'] ?? '';
                final rawDate = act['timestamp'] ?? act['created_at'] ?? '';
                String dateStr = '';
                try {
                  dateStr = rawDate.toString();
                } catch (_) {
                  dateStr = rawDate?.toString() ?? '';
                }

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: Icon(Icons.circle, size: 12, color: colorScheme.primary.withOpacity(0.7)),
                  title: Text(
                    title.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    subtitle.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Text(
                    dateStr,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Activity: $title')),
                    );
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.user;
    final userName = user?['name']?.toString() ?? 'Patient';
    final userEmail = user?['email']?.toString() ?? '';

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          children: [
            // User card with profile picture
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black26 : Colors.red.shade100.withOpacity(0.18),
                    spreadRadius: 1,
                    blurRadius: 9,
                  ),
                ],
                border: isDark ? Border.all(color: Colors.white10) : null,
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Profile Picture with upload
                  GestureDetector(
                    onTap: _uploading ? null : _pickAndUploadImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.shade200,
                            border: Border.all(
                              color: Colors.red.shade300,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _uploading
                                ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                                : _profilePictureUrl != null
                                ? Image.network(
                              _profilePictureUrl!,
                              fit: BoxFit.cover,
                              width: 70,
                              height: 70,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    fontSize: 30,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: loadingProgress
                                          .expectedTotalBytes !=
                                          null
                                          ? loadingProgress
                                          .cumulativeBytesLoaded /
                                          loadingProgress
                                              .expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            )
                                : Center(
                              child: Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  fontSize: 30,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!_uploading)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Age: ${ageController.text.isEmpty ? 'N/A' : ageController.text}',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // My Medical Reports
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black26 : Colors.red.shade100.withOpacity(0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isDark ? Border.all(color: Colors.white10) : null,
              ),
              padding: const EdgeInsets.all(18),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFFFEBEE),
                  child: const Icon(Icons.assignment, color: Colors.red),
                ),
                title: Text(
                  'My Medical Reports',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'View prescriptions, lab tests and attached images',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
                trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PatientReportsPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // My Activities
            _buildActivitiesSection(context),
            const SizedBox(height: 24),

            // Profile Details
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black26 : Colors.red.shade100.withOpacity(0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isDark ? Border.all(color: Colors.white10) : null,
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 22, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        "Profile Details",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: ageController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: Colors.red.shade400,
                      ),
                      labelText: "Age",
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Insurance",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: insuranceController,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: "Add insurance/no.",
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'insuranceAdd',
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.add, color: Colors.white),
                        onPressed: _addInsurance,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: insurances.isEmpty
                          ? [
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            "No insurances recorded.",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        )
                      ]
                          : insurances
                          .map(
                            (ins) => Chip(
                          label: Text(ins),
                          backgroundColor: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          deleteIcon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red,
                          ),
                          onDeleted: () {
                            setState(() => insurances.remove(ins));
                          },
                        ),
                      )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Insurance file upload / Policy search coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload insurance documents / find policy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
                onPressed: _saving ? null : _saveProfile,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ageController.dispose();
    referenceController.dispose();
    insuranceController.dispose();
    super.dispose();
  }
}
