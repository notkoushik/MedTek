// lib/src/auth_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:ui';
import 'forgot_password_screen.dart';
import 'patient_dashboard.dart';
import 'doctor_dashboard.dart';
import 'doctor_onboarding_guard.dart'; 
import 'patient_profile_setup_page.dart';
import 'select_hospital_page.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  bool isLogin = true;
  String role = 'patient';
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  bool loading = false;
  bool _passwordVisible = false;
  String? error;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  final api = ApiService();

  @override
  void initState() {
    super.initState();
    
    // ✅ Load saved IP address
    api.loadBaseUrl().then((_) => setState(() {}));

    // Main entrance animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // Heartbeat pulse animation for medical cross
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _hospitalCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      Map<String, dynamic> data;

      if (isLogin) {
        data = await api.login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      } else {
        data = await api.register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: role,
          hospitalName: role == 'doctor' ? _hospitalCtrl.text.trim() : null,
        );
      }

      final userMap = data['user'] ?? data['data'] ?? data['profile'];
      if (userMap == null) {
        throw Exception('Invalid auth response: missing user');
      }
      final user = Map<String, dynamic>.from(userMap as Map);

      final tokenValue = data['token'] ?? data['accessToken'] ?? data['jwt'] ?? '';
      final token = tokenValue.toString();
      final userRole = (user['role'] ?? role).toString();

      final session = context.read<SessionService>();
      await session.saveSession(token, user);

      if (!mounted) return;
      _goToDashboard(context, userRole);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;

      String msg = 'Request failed (${status ?? 'unknown'}).';
      if (body is Map<String, dynamic>) {
        msg = (body['message'] ?? body['error'] ?? body['detail'] ?? msg).toString();
      }

      setState(() => error = msg);
    } catch (e) {
      setState(() => error = 'Request failed: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _goToDashboard(BuildContext context, String role) async {
    if (role == 'doctor') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DoctorOnboardingGuard()),
      );
    } else if (role == 'lab_assistant') {
      final session = context.read<SessionService>();
      final user = session.user;
      if (user != null && user['selected_hospital_id'] == null && user['hospital'] == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SelectHospitalPage()),
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/lab-dashboard');
      }
    } else {
      // Check if patient profile is complete
      try {
        final session = context.read<SessionService>();
        final userId = session.user?['id']?.toString();
        
        if (userId != null) {
          final profile = await api.getPatientProfile(userId);
          final age = profile['age'];
          final weight = profile['weight'];

          if (age == null || (age is int && age == 0) || weight == null) {
             if (mounted) {
               // Import needed at top: import 'patient_profile_setup_page.dart';
               // I will add the import via another edit or assume it's fine to add implicitly if I could 
               // but I better be safe. I can't add import here easily.
               // Actually, I should use a replace block that includes imports if I can needed.
               // Let's assume I will add import in a second step or if this file supports it.
               // Let me check imports: lines 1-12.
               
               Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PatientProfileSetupPage()),
              );
              return;
             }
          }
        }
      } catch (e) {
        print('Error checking profile: $e');
        // Fallback to dashboard if error
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PatientDashboard()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade50.withOpacity(0.3),
              Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Subtle medical cross pattern background
            Positioned(
              top: -80,
              right: -80,
              child: Opacity(
                opacity: 0.03,
                child: Icon(
                  Icons.local_hospital,
                  size: 250,
                  color: Colors.red,
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -120,
              child: Opacity(
                opacity: 0.02,
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 350,
                  color: Colors.red,
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ✅ Settings Icon (Top Right)
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.settings, color: Colors.grey),
                                  onPressed: _showIpConfigDialog,
                                  tooltip: 'Configure Backend IP',
                                ),
                              ),

                              // Medical Logo with Pulse Animation
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFD32F2F),
                                        const Color(0xFFEF5350),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.3),
                                        blurRadius: 30,
                                        offset: const Offset(0, 15),
                                      ),
                                      BoxShadow(
                                        color: Colors.red.shade100,
                                        blurRadius: 20,
                                        offset: const Offset(0, -5),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.local_hospital_rounded,
                                    size: 55,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Title
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    const Color(0xFFD32F2F),
                                    Colors.red.shade700,
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'Medtek',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              Text(
                                'Healthcare Management System',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 48),

                              // Card with subtle shadow
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.08),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    // Custom Toggle
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildToggleButton(
                                              'Login',
                                              Icons.login_rounded,
                                              isLogin,
                                                  () => setState(() => isLogin = true),
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildToggleButton(
                                              'Sign Up',
                                              Icons.person_add_rounded,
                                              !isLogin,
                                                  () => setState(() => isLogin = false),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),

                                    // Form
                                    Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          // Name field (signup only)
                                          if (!isLogin)
                                            _buildTextField(
                                              controller: _nameCtrl,
                                              label: 'Full Name',
                                              icon: Icons.person_outline_rounded,
                                              validator: (v) =>
                                              v == null || v.isEmpty ? 'Required' : null,
                                            ),

                                          if (!isLogin) const SizedBox(height: 16),

                                          // Email field
                                          _buildTextField(
                                            controller: _emailCtrl,
                                            label: 'Email Address',
                                            icon: Icons.email_outlined,
                                            keyboardType: TextInputType.emailAddress,
                                            validator: (v) {
                                              if (v == null || v.isEmpty) return 'Required';
                                              if (!v.contains('@')) return 'Invalid email';
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 16),

                                          // Password field
                                          _buildTextField(
                                            controller: _passwordCtrl,
                                            label: 'Password',
                                            icon: Icons.lock_outline_rounded,
                                            obscureText: !_passwordVisible,
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _passwordVisible
                                                    ? Icons.visibility_rounded
                                                    : Icons.visibility_off_rounded,
                                                color: Colors.grey.shade600,
                                              ),
                                              onPressed: () {
                                                setState(() =>
                                                _passwordVisible = !_passwordVisible);
                                              },
                                            ),
                                            validator: (v) => v == null || v.length < 4
                                                ? 'Min 4 characters'
                                                : null,
                                          ),

                                          // Role dropdown (signup only)
                                          if (!isLogin) ...[
                                            const SizedBox(height: 16),
                                            _buildDropdown(),
                                          ],

                                          // Hospital field (doctor signup only)
                                          if (!isLogin && role == 'doctor') ...[
                                            const SizedBox(height: 16),
                                            _buildTextField(
                                              controller: _hospitalCtrl,
                                              label: 'Hospital Name',
                                              icon: Icons.local_hospital_outlined,
                                              validator: (v) =>
                                              v == null || v.isEmpty ? 'Required' : null,
                                            ),
                                          ],

                                          // Forgot password (login only)
                                          if (isLogin) ...[
                                            const SizedBox(height: 12),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                      const ForgotPasswordScreen(),
                                                    ),
                                                  );
                                                },
                                                child: const Text(
                                                  'Forgot Password?',
                                                  style: TextStyle(
                                                    color: Color(0xFFD32F2F),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 24),

                                          // Error message
                                          if (error != null) ...[
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.red.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.error_outline_rounded,
                                                    color: Colors.red.shade700,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      error!,
                                                      style: TextStyle(
                                                        color: Colors.red.shade700,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                          ],

                                          // Submit button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 58,
                                            child: ElevatedButton(
                                              onPressed: loading ? null : _submit,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFD32F2F),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                                elevation: 3,
                                                shadowColor: Colors.red.withOpacity(0.3),
                                              ),
                                              child: loading
                                                  ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                                  : Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    isLogin
                                                        ? Icons.login_rounded
                                                        : Icons.person_add_rounded,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isLogin
                                                        ? 'Login'
                                                        : 'Create Account',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Privacy notice
                              if (!isLogin)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Your health data is secure and HIPAA compliant',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD32F2F) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFFD32F2F), size: 22),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white,
        ),
        child: DropdownButtonFormField<String>(
          value: role,
          dropdownColor: Colors.white,
          decoration: const InputDecoration(
            border: InputBorder.none,
            icon: Icon(Icons.badge_outlined, color: Color(0xFFD32F2F), size: 22),
            labelText: 'Select Role',
            labelStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          items: [
            DropdownMenuItem(
              value: 'patient',
              child: Text('Patient', style: TextStyle(color: Colors.grey.shade800)),
            ),
            DropdownMenuItem(
              value: 'doctor',
              child: Text('Doctor', style: TextStyle(color: Colors.grey.shade800)),
            ),
            DropdownMenuItem(
              value: 'lab_assistant',
              child: Text('Lab Assistant', style: TextStyle(color: Colors.grey.shade800)),
            ),
          ],
          onChanged: (v) {
            setState(() => role = v ?? 'patient');
          },
        ),
      ),
    );
  }

  // ✅ Dynamic IP Configuration Dialog
  void _showIpConfigDialog() {
    final ipCtrl = TextEditingController(text: ApiService.host); 
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the IP address of your computer (e.g., 192.168.1.151). No need for http:// or port.'),
            const SizedBox(height: 16),
            TextField(
              controller: ipCtrl,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                border: OutlineInputBorder(),
                hintText: '192.168.1.151',
              ),
              keyboardType: TextInputType.number, 
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.wifi_find_rounded),
                label: const Text('Test Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                  elevation: 0,
                ),
                onPressed: () async {
                   final testIp = ipCtrl.text.trim();
                   final messenger = ScaffoldMessenger.of(context);
                   Navigator.pop(context); // Close dialog to show snackbar
                   
                   messenger.showSnackBar(
                     const SnackBar(
                       content: Text('Testing connection...'),
                       duration: Duration(seconds: 1),
                     ),
                   );

                   try {
                     final dio = Dio(BaseOptions(
                       baseUrl: 'http://$testIp:4000',
                       connectTimeout: const Duration(seconds: 5),
                     ));
                     final res = await dio.get('/');
                     messenger.showSnackBar(
                       SnackBar(
                         content: Text('✅ Connected! Status: ${res.statusCode}'),
                         backgroundColor: Colors.green,
                         duration: const Duration(seconds: 3),
                       ),
                     );
                   } on DioException catch (e) {
                     String errorMsg = 'Connection Failed';
                     if (e.type == DioExceptionType.connectionTimeout) {
                       errorMsg = 'Timeout: Check Firewall';
                     } else if (e.type == DioExceptionType.connectionError) {
                       errorMsg = 'Connection Refused: Check IP/Port';
                     } else {
                       errorMsg = 'Error: ${e.message}';
                     }
                     
                     messenger.showSnackBar(
                       SnackBar(
                         content: Text('❌ $errorMsg'),
                         backgroundColor: Colors.red,
                         duration: const Duration(seconds: 5),
                       ),
                     );
                   } catch (e) {
                      messenger.showSnackBar(
                       SnackBar(
                         content: Text('❌ Error: $e'),
                         backgroundColor: Colors.red,
                       ),
                     );
                   }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
               final newIp = ipCtrl.text.trim();
               if (newIp.isNotEmpty) {
                 await api.updateBaseUrl(newIp);
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Backend updated to ${ApiService.baseUrl}')),
                   );
                   Navigator.pop(context);
                 }
               }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
