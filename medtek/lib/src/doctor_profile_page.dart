// lib/src/doctor_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_service.dart';
import '../services/api_service.dart';
import 'auth_page.dart';
import 'doctor_verification_screen.dart';

class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({super.key});

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    // ✅ Refresh user data when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
  }

  // ✅ Refresh user data from backend
  Future<void> _refreshUserData() async {
    try {
      final session = context.read<SessionService>();
      final userData = await _api.getMe();

      if (userData['user'] != null) {
        await session.updateUser(userData['user'] as Map<String, dynamic>);
        if (mounted) setState(() {});
        debugPrint('✅ User data refreshed');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to refresh user data: $e');
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

  @override
  // lib/src/doctor_profile_page.dart

  @override
  Widget build(BuildContext context) {
    // ✅ Watch for session changes - UI rebuilds when session.notifyListeners() is called
    final session = context.watch<SessionService>();
    final user = session.user;

    debugPrint('🎨 BUILDING DOCTOR PROFILE PAGE');
    debugPrint('   User: ${user?['name']}');
    debugPrint('   Specialization: ${user?['specialization']}');
    debugPrint('   Experience: ${user?['experience_years']}');
    debugPrint('   Hospital: ${user?['hospital']?['name'] ?? user?['selected_hospital_name']}');

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              try {
                await SessionService.instance.fetchMe(_api);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Refreshed')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _buildProfileContent(user),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> user) {
    // ✅ Get data from session (already updated by API calls)
    final name = (user['name'] ?? 'Doctor').toString();
    final email = (user['email'] ?? '').toString();
    final specialization = (user['specialization'] ?? 'Not specified').toString();
    final experienceYears = (user['experience_years'] ?? 0);
    final about = (user['about'] ?? 'No bio available').toString();

    // ✅ Get hospital data
    final hospital = user['hospital'] as Map<String, dynamic>?;
    final hospitalName = hospital?['name'] ?? user['selected_hospital_name'] ?? 'No hospital assigned';
    final hospitalAddress = hospital?['address'] ?? '';

    final verified = (user['verified'] ?? false) as bool;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildHeader(name, specialization, experienceYears.toString(), verified),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hospital info
                _buildInfoCard(
                  icon: Icons.local_hospital,
                  label: 'Hospital',
                  value: hospitalName,
                  subtitle: hospitalAddress.isNotEmpty ? hospitalAddress : null,
                ),
                const SizedBox(height: 12),

                // Experience
                _buildInfoCard(
                  icon: Icons.work,
                  label: 'Experience',
                  value: '$experienceYears years',
                ),
                const SizedBox(height: 12),

                // Email
                _buildInfoCard(
                  icon: Icons.email,
                  label: 'Email',
                  value: email,
                ),
                const SizedBox(height: 12),

                // Specialization
                _buildInfoCard(
                  icon: Icons.medical_services,
                  label: 'Specialization',
                  value: specialization,
                ),
                const SizedBox(height: 24),

                // About section
                const Text(
                  'About',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    about,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),

                // Debug info (remove in production)
                if (true) ...[
                  const Divider(),
                  ExpansionTile(
                    title: const Text('Debug Info'),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey.shade100,
                        child: SelectableText(
                          'User Data:\n${user.toString()}',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String specialization, String exp, bool verified) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.red.shade300,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (verified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Dr. $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            specialization,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      exp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Years Experience',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Container(height: 40, width: 1, color: Colors.white30),
                GestureDetector(
                  onTap: verified ? null : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DoctorVerificationScreen()),
                    );
                  },
                  child: Column(
                    children: [
                      Icon(
                        verified ? Icons.verified : Icons.gpp_bad,
                        color: verified ? Colors.white : Colors.orangeAccent,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        verified ? 'Verified' : 'Verify Now',
                        style: TextStyle(
                            color: verified ? Colors.white70 : Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.red.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
