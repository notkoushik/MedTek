import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class AiPillDetectionPage extends StatefulWidget {
  const AiPillDetectionPage({super.key});

  @override
  State<AiPillDetectionPage> createState() => _AiPillDetectionPageState();
}

class _AiPillDetectionPageState extends State<AiPillDetectionPage> {
  File? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  final ImagePicker _picker = ImagePicker();

  // Mock current meds for demo (In real app, fetch from user profile)
  // Using UPPERCASE as required by the API
  final List<String> _currentMeds = ['ASPIRIN', 'METFORMIN']; 

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85, // Optimize size
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = null; 
      });
      _analyzePill(File(pickedFile.path));
    }
  }

  Future<void> _analyzePill(File image) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().checkPillSafety(
        imageFile: image,
        currentMedications: _currentMeds,
      );
      
      setState(() => _result = res);
      
      if (res['success'] != true) {
         _showErrorDialog(res['message'] ?? 'Unknown error occurred');
      }

    } catch (e) {
      _showErrorDialog('Failed to analyze image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper for confidence text
  String _getConfidenceLevel(double confidence) {
    if (confidence >= 0.60) return "High Confidence";
    if (confidence >= 0.40) return "Good Confidence";
    if (confidence >= 0.20) return "Moderate Confidence";
    return "Low Confidence";
  }
  
  // Helper for confidence color
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.60) return Colors.green;
    if (confidence >= 0.40) return Colors.blue;
    if (confidence >= 0.20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Pill Safety Check'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Image Section ---
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0,4))
                ]
              ),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Tap below to scan a pill',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // --- Buttons ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Loading & Results ---
            if (_isLoading)
               const Padding(
                 padding: EdgeInsets.all(20.0),
                 child: Center(child: Column(
                   children: [
                     CircularProgressIndicator(),
                     SizedBox(height: 16),
                     Text('Analyzing pill & checking safety...'),
                   ],
                 )),
               )
            else if (_result != null && _result!['success'] == true)
              _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final pillName = _result?['pill_name'] ?? 'Unknown';
    final confidence = (_result?['confidence'] as num?)?.toDouble() ?? 0.0;
    final isSafe = _result?['safe'] ?? true;
    final interactions = _result?['interactions'] as List<dynamic>? ?? [];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medication, color: Colors.teal, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detected Pill',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        pillName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Confidence
            Row(
              children: [
                 const Text('Confidence:', style: TextStyle(fontWeight: FontWeight.w600)),
                 const SizedBox(width: 8),
                 Text('${(confidence * 100).toStringAsFixed(1)}%'),
                 const SizedBox(width: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   decoration: BoxDecoration(
                     color: _getConfidenceColor(confidence).withOpacity(0.1),
                     borderRadius: BorderRadius.circular(4),
                     border: Border.all(color: _getConfidenceColor(confidence).withOpacity(0.5))
                   ),
                   child: Text(
                     _getConfidenceLevel(confidence),
                     style: TextStyle(fontSize: 12, color: _getConfidenceColor(confidence), fontWeight: FontWeight.bold),
                   ),
                 ),
              ],
            ),
            const Divider(height: 32),
            
            // Safety Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSafe ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSafe ? Colors.green.shade200 : Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    isSafe ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: isSafe ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSafe ? 'No Interactions Found' : 'Safety Warning!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSafe ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                        if (!isSafe)
                          Text(
                            'Potential conflict with your current meds.',
                            style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            if (!isSafe && interactions.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('INTERACTION DETAILS:', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              const SizedBox(height: 10),
              ...interactions.map((i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: Offset(0,2))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${i['drug1']} + ${i['drug2']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (i['severity'] ?? 'UNKNOWN').toString().toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(i['description'] ?? '', style: TextStyle(color: Colors.grey[800])),
                    if (i['mechanism'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Mechanism: ${i['mechanism']}',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[600]),
                      ),
                    ]
                  ],
                ),
              )),
              
             const SizedBox(height: 12),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton.icon(
                 onPressed: () {
                   // Navigate to doctor consult (Placeholder)
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to doctor...')));
                 },
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.red,
                   foregroundColor: Colors.white,
                 ),
                 icon: const Icon(Icons.local_hospital),
                 label: const Text('Consult a Doctor Immediately'),
               ),
             )
            ]
          ],
        ),
      ),
    );
  }
}
