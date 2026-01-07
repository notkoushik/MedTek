// lib/src/patient_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // Import for ThemeNotifier
import 'auth_page.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

import 'profile_page.dart';
import 'triage_page.dart';
import 'hospital_detail_page.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  final _api = ApiService();

  List<Map<String, dynamic>> trendingDoctors = [];
  List<Map<String, dynamic>> trendingHospitals = [];
  bool isLoadingDoctors = true;
  bool isLoadingHospitals = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _fetchTrendingDoctors();
    _fetchTrendingHospitals();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrendingDoctors() async {
    try {
      final res = await _api.getTrendingDoctors();
      final list =
      (res['doctors'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        trendingDoctors = list;
        isLoadingDoctors = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        trendingDoctors = [];
        isLoadingDoctors = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load doctors: $e'),
        ),
      );
    }
  }

  Future<void> _fetchTrendingHospitals() async {
    try {
      final list = (await _api.getHospitals())
          .cast<Map<String, dynamic>>()
          .take(10)
          .toList();

      if (!mounted) return;
      setState(() {
        trendingHospitals = list;
        isLoadingHospitals = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        trendingHospitals = [];
        isLoadingHospitals = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load hospitals: $e'),
        ),
      );
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _signOut() async {
    final session = context.read<SessionService>();

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        await session.signOut();

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthPage()),
              (_) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
          ),
        );
      }
    }
  }

  void _navigateToSearch() {
    showSearch(
      context: context,
      delegate: HospitalSearchDelegate(api: _api),
    );
  }

  Widget _buildHomeScreen(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.user;
    final displayName =
        user?['name']?.toString() ?? user?['email']?.toString() ?? 'User';

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchTrendingDoctors();
        await _fetchTrendingHospitals();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Search bar
            InkWell(
              onTap: _navigateToSearch,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: isDark ? Colors.transparent : Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: colorScheme.primary, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Search hospitals...',
                        style: TextStyle(
                            fontSize: 16, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Icon(Icons.tune, color: colorScheme.primary, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Trending Doctors
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trending Doctors',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Hot',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (isLoadingDoctors)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (trendingDoctors.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 48, color: colorScheme.onSurface.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No doctors available',
                          style: TextStyle(
                              fontSize: 16, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: trendingDoctors.length,
                  itemBuilder: (context, index) {
                    final doctor = trendingDoctors[index];
                    return _DoctorCard(doctor: doctor);
                  },
                ),
              ),

            const SizedBox(height: 32),

            // Trending Hospitals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trending Hospitals',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.trending_up, color: Colors.blue, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Popular',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (isLoadingHospitals)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (trendingHospitals.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.domain_disabled_outlined,
                            size: 48, color: colorScheme.onSurface.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No hospitals available',
                          style: TextStyle(
                              fontSize: 16, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < trendingHospitals.length; i++)
                    _HospitalCard(
                      hospital: trendingHospitals[i],
                      index: i + 1,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.user;
    final userName = user?['name']?.toString() ?? 'User';
    final profilePic = user?['profile_picture']?.toString();

    // Access ThemeNotifier
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Page titles - show profile picture for Home tab
    Widget getAppBarTitle(int index) {
      if (index == 0) {
        // Home tab - show profile picture
        return GestureDetector(
          onTap: () {
            setState(() => _selectedIndex = 2);
            _pageController.animateToPage(
              2,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                ),
                child: ClipOval(
                  child: profilePic != null && profilePic.isNotEmpty
                      ? Image.network(
                    _api.getProfilePictureUrl(profilePic),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.red.shade200,
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                      : Container(
                    color: Colors.red.shade200,
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(userName),
            ],
          ),
        );
      } else if (index == 1) {
        return const Text('Triage');
      } else {
        return const Text('Profile');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: getAppBarTitle(_selectedIndex),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle theme',
            onPressed: () {
              // Toggle logic: If dark, go light. If light, go dark.
              // This overrides the system setting until the user manually changes it back or data is cleared.
              if (isDark) {
                themeNotifier.setMode(ThemeMode.light);
              } else {
                themeNotifier.setMode(ThemeMode.dark);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: [
          _buildHomeScreen(context),
          const TriagePage(),
          const PatientProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        animationDuration: const Duration(milliseconds: 400),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Triage',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Doctor Card Widget with Verified Badge
class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const _DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final name = doctor['name'] ?? 'Unknown Doctor';
    final specialty = doctor['specialty'] ?? 'General';
    final experience = doctor['experience'] ?? 'N/A';
    final rating = doctor['rating']?.toString() ?? '0.00';
    final verified = doctor['verified'] == true;

    return Card(
      margin: const EdgeInsets.only(right: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Viewing $name\'s profile')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.red.shade100,
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.red,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Doctor name with verified badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Verified Doctor',
                      child: Icon(
                        Icons.verified,
                        size: 18,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 4),
              Text(
                specialty,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$experience exp',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Hospital Card Widget
class _HospitalCard extends StatelessWidget {
  final Map<String, dynamic> hospital;
  final int index;

  const _HospitalCard({required this.hospital, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = hospital['name'] ?? 'Unknown Hospital';
    final address = hospital['address'] ?? 'Address not available';
    final phone = hospital['phone'] ?? 'N/A';
    final latitude = hospital['latitude']?.toString() ?? '';
    final longitude = hospital['longitude']?.toString() ?? '';
    final hospitalId = hospital['id']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (hospitalId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    HospitalDetailPage(hospitalId: hospitalId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '#$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (latitude.isNotEmpty && longitude.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle,
                                size: 12, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              'GPS available',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                onPressed: () {
                  if (hospitalId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            HospitalDetailPage(hospitalId: hospitalId),
                      ),
                    );
                  }
                },
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Hospital Search Delegate
class HospitalSearchDelegate extends SearchDelegate<String> {
  final ApiService api;

  HospitalSearchDelegate({required this.api});

  @override
  String get searchFieldLabel => 'Search hospitals...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for hospitals',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter hospital name or location',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: api.getHospitals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hospitals found'));
        }

        final all = snapshot.data!.cast<Map<String, dynamic>>();
        final q = query.toLowerCase();
        final filtered = all.where((h) {
          final name = (h['name'] ?? '').toString().toLowerCase();
          final addr = (h['address'] ?? '').toString().toLowerCase();
          return name.contains(q) || addr.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('No hospitals match your search'));
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final hospital = filtered[index];
            final name = hospital['name'] ?? 'Hospital';
            final address = hospital['address'] ?? '';
            final id = hospital['id']?.toString() ?? '';

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.local_hospital, color: Colors.white),
              ),
              title: Text(name.toString()),
              subtitle: Text(address.toString()),
              onTap: () {
                if (id.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HospitalDetailPage(hospitalId: id),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}
