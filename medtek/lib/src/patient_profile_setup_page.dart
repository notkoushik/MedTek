import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'patient_dashboard.dart';

class PatientProfileSetupPage extends StatefulWidget {
  const PatientProfileSetupPage({super.key});

  @override
  State<PatientProfileSetupPage> createState() => _PatientProfileSetupPageState();
}

class _PatientProfileSetupPageState extends State<PatientProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _dobController = TextEditingController(); // NEW
  final _ageController = TextEditingController(); // Keep for API, maybe hide or make read-only
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'O+';
  bool _isLoading = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['Result Pending', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false, 
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Help doctors know you better',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Date of Birth (Calculates Age)
              _buildInputLabel('Date of Birth'),
              TextFormField(
                controller: _dobController,
                readOnly: true, // Prevent manual typing
                decoration: _inputDecoration('Select Date of Birth').copyWith(
                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)), // Default 20 years ago
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
                      final age = _calculateAge(picked);
                      _ageController.text = age.toString();
                    });
                  }
                },
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please select date of birth';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Age (Auto-calculated, Read-only)
              _buildInputLabel('Age (Years)'),
              TextFormField(
                controller: _ageController,
                readOnly: true,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Age will appear here'),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Age is required';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Weight
              _buildInputLabel('Weight (kg)'),
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Enter weight in kg'),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter weight';
                  if (double.tryParse(val) == null) return 'Invalid weight';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Height
              _buildInputLabel('Height (cm)'),
              TextFormField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Enter height in cm'),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter height';
                  if (double.tryParse(val) == null) return 'Invalid height';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Gender
              _buildInputLabel('Gender'),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val!),
                decoration: _inputDecoration(''),
              ),
              const SizedBox(height: 20),

              // Blood Group
              _buildInputLabel('Blood Group'),
              DropdownButtonFormField<String>(
                value: _selectedBloodGroup,
                items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                onChanged: (val) => setState(() => _selectedBloodGroup = val!),
                decoration: _inputDecoration(''),
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save & Continue',
                        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade200)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final session = context.read<SessionService>();
      final userId = session.user?['id']?.toString();
      
      if (userId == null) throw Exception('User not found');

      final api = ApiService();
      await api.updatePatientProfileData(userId, {
        'age': int.parse(_ageController.text),
        'weight': double.parse(_weightController.text),
        'height': double.parse(_heightController.text),
        'gender': _selectedGender,
        'blood_group': _selectedBloodGroup,
      });

      if (!mounted) return;
      
      // Navigate to Dashboard replacing the setup page so they can't go back
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PatientDashboard()),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
}
