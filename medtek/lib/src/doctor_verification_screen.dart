// lib/src/doctor_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class DoctorVerificationScreen extends StatefulWidget {
  const DoctorVerificationScreen({Key? key}) : super(key: key);

  @override
  State<DoctorVerificationScreen> createState() => _DoctorVerificationScreenState();
}

class _DoctorVerificationScreenState extends State<DoctorVerificationScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();

  int _currentStep = 0;
  bool _isLoading = false;

  // STEP 1: NMC
  final _nmcController = TextEditingController();
  bool _nmcVerified = false;
  Map<String, dynamic>? _nmcData;

  // STEP 2: OCR
  File? _certificateImage;
  String? _extractedText;
  bool _ocrVerified = false;
  int _points = 0;

  // STEP 3: LIVENESS
  File? _selfieImage;
  bool _livenessVerified = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    // Ideally fetch current progress from backend if needed
  }

  // --------------------------------------------------------------------------
  // ACTIONS
  // --------------------------------------------------------------------------

  Future<void> _verifyNMC() async {
    if (_nmcController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter valid NMC Number")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // API CALL
      final res = await _api.dio.post('/verification-v2/nmc', data: {
        'doctorId': (await _api.getMe())['user']['id'],
        'nmcNumber': _nmcController.text.trim()
      });

      if (res.data['success']) {
        setState(() {
          _nmcVerified = true;
          _nmcData = res.data['data'];
          _points = res.data['totalPoints'] ?? 20;
          _currentStep = 1; // Auto advance
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification Failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCertificate() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      setState(() => _certificateImage = File(xfile.path));
    }
  }

  Future<void> _processOCR() async {
    if (_certificateImage == null) return;
    setState(() => _isLoading = true);

    try {
      final userId = (await _api.getMe())['user']['id'];
      
      String fileName = _certificateImage!.path.split('/').last;
      FormData formData = FormData.fromMap({
        'doctorId': userId,
        'document': await MultipartFile.fromFile(_certificateImage!.path, filename: fileName),
      });

      final res = await _api.dio.post('/verification-v2/ocr', data: formData);

      setState(() {
        _extractedText = res.data['extractedText'];
        _ocrVerified = res.data['success'];
        _points = res.data['totalPoints'] ?? (_points + 30);
        if (_ocrVerified) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Certificate Verified!")));
          Future.delayed(const Duration(seconds: 1), () => setState(() => _currentStep = 2));
        } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not read essential details. Try again.")));
        }
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OCR Failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _takeSelfie() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (xfile != null) {
      setState(() => _selfieImage = File(xfile.path));
      
      // Auto submit liveness to simulate "Detection"
       _verifyLiveness();
    }
  }

  Future<void> _verifyLiveness() async {
      if (_selfieImage == null) return;
      setState(() => _isLoading = true);

       try {
        final userId = (await _api.getMe())['user']['id'];
        
        String fileName = _selfieImage!.path.split('/').last;
        FormData formData = FormData.fromMap({
            'doctorId': userId,
            'live_photo': await MultipartFile.fromFile(_selfieImage!.path, filename: fileName),
        });

        final res = await _api.dio.post('/verification-v2/submit', data: formData);

        setState(() {
            _livenessVerified = true;
            _points = res.data['totalPoints'];
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Liveness Verified!")));
        });

       } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission Failed: $e")));
       } finally {
        setState(() => _isLoading = false);
       }
  }


  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Verification")),
      body: Stepper(
        currentStep: _currentStep,
        onStepTapped: (index) {
          // Only allow tap to previous steps or next step if current is complete
          // For simplicity, strict flow:
          // setState(() => _currentStep = index);
        },
        onStepContinue: () {
          if (_currentStep < 2) {
             setState(() => _currentStep++);
          } else {
            Navigator.pop(context);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        controlsBuilder: (context, details) {
            // We hide default controls and use custom buttons inside steps
            return const SizedBox.shrink();
        },
        steps: [
          // STEP 1
          Step(
            title: const Text("NMC Registration"),
            isActive: _currentStep >= 0,
            state: _nmcVerified ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Enter your NMC Registration Number for instant verification."),
                const SizedBox(height: 10),
                TextField(
                  controller: _nmcController,
                  decoration: const InputDecoration(
                    labelText: "NMC Number",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 10),
                if (_nmcVerified && _nmcData != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 10),
                      Text("Verified: ${_nmcData!['name']}"),
                    ]),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyNMC,
                    child: _isLoading ? const CircularProgressIndicator() : const Text("Verify with NMC"),
                  ),
                )
              ],
            ),
          ),

          // STEP 2
          Step(
            title: const Text("Degree Certificate"),
             isActive: _currentStep >= 1,
            state: _ocrVerified ? StepState.complete : StepState.indexed,
            content: Column(
                children: [
                    const Text("Upload a clear photo of your MBBS/MD Degree."),
                     const SizedBox(height: 10),
                     GestureDetector(
                         onTap: _pickCertificate,
                         child: Container(
                             height: 150,
                             width: double.infinity,
                             decoration: BoxDecoration(
                                 border: Border.all(color: Colors.grey),
                                 borderRadius: BorderRadius.circular(10),
                                 color: Colors.grey[100]
                             ),
                             child: _certificateImage == null 
                                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload_file, size: 40), Text("Tap to Upload")])
                                : Image.file(_certificateImage!, fit: BoxFit.cover),
                         ),
                     ),
                     const SizedBox(height: 10),
                     if (_extractedText != null)
                      ExpansionTile(title: const Text("Extracted Text"), children: [Padding(padding: const EdgeInsets.all(8.0), child: Text(_extractedText!))]),
                    
                     const SizedBox(height: 20),
                     SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: (_isLoading || _certificateImage == null) ? null : _processOCR,
                             child: _isLoading ? const CircularProgressIndicator() : const Text("Scan & Verify"),
                        ),
                     )
                ],
            ),
          ),

          // STEP 3
          Step(
            title: const Text("Liveness Check"),
             isActive: _currentStep >= 2,
            state: _livenessVerified ? StepState.complete : StepState.indexed,
            content: Column(
                children: [
                    const Text("Take a live selfie to confirm your identity."),
                    const SizedBox(height: 10),
                     GestureDetector(
                         onTap: _takeSelfie,
                          child: Container(
                             height: 200,
                             width: 200,
                             decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 border: Border.all(color: _livenessVerified ? Colors.green : Colors.grey, width: 3),
                                  color: Colors.grey[100]
                             ),
                             child: _selfieImage == null 
                                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_front, size: 40), Text("Take Selfie")])
                                : ClipOval(child: Image.file(_selfieImage!, fit: BoxFit.cover)),
                         ),
                     ),
                      if (_livenessVerified)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Liveness Verified ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                     const SizedBox(height: 20),
                     if (_livenessVerified)
                     SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification process completed!")));
                            },
                             child: const Text("Finish & Submit"),
                        ),
                     )
                ],
            ),
          ),
        ],
      ),
    );
  }
}
