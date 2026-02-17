// lib/screens/activities/my_activities_page.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'package:provider/provider.dart';

class MyActivitiesPage extends StatefulWidget {
  const MyActivitiesPage({Key? key}) : super(key: key);

  @override
  State<MyActivitiesPage> createState() => _MyActivitiesPageState();
}

class _MyActivitiesPageState extends State<MyActivitiesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final api = ApiService();

  String get userId {
    final session = context.read<SessionService>();
    return session.user?['id']?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _parseDateTime(dynamic value) {
    try {
      if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (value is String) {
        return DateTime.tryParse(value) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDateTime(dynamic date) {
    if (date == null) return '';
    final dt = _parseDateTime(date);
    if (dt.millisecondsSinceEpoch == 0) return '';
    return "${dt.year}-${_two(dt.month)}-${_two(dt.day)} "
        "${_two(dt.hour)}:${_two(dt.minute)}";
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      appBar: AppBar(
        title: const Text(
          'My Activities',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.red,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.event_note), text: 'Appointments'),
            Tab(icon: Icon(Icons.local_taxi), text: 'Rides'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSection(isRides: false),
          _buildSection(isRides: true),
        ],
      ),
    );
  }

  Widget _buildSection({required bool isRides}) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.red,
            indicatorColor: Colors.red,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Completed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildList(isRides: isRides, status: 'pending'),
                _buildList(isRides: isRides, status: 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList({required bool isRides, required String status}) {
    if (userId.isEmpty) {
      return const Center(child: Text('Please sign in to see activities.'));
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: api.getActivities(
        type: isRides ? 'rides' : 'appointments',
        userId: userId,
        status: status,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final items = (snapshot.data?['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRides ? Icons.local_taxi_outlined : Icons.event_busy,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No records found',
                  style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        items.sort((a, b) {
          final ta = _parseDateTime(a['created_at'] ?? a['date']);
          final tb = _parseDateTime(b['created_at'] ?? b['date']);
          return tb.compareTo(ta);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final data = items[i];
            final actualStatus = data['status']?.toString() ?? status;
            final queueNumber = data['queue_number'];

            String title = '';
            String subtitle = '';

            if (isRides) {
              title = (data['destination'] ??
                  data['dropoff_address'] ??
                  'Unknown Destination')
                  .toString();
              subtitle = _formatDateTime(data['created_at'] ?? data['date']);
            } else {
              final doctorName =
              (data['doctor_name'] ?? data['doctor'] ?? '').toString();
              final hospName =
              (data['hospital_name'] ?? data['hospital'] ?? '').toString();

              title = doctorName.isNotEmpty
                  ? doctorName
                  : (hospName.isNotEmpty
                  ? hospName
                  : (data['title'] ?? 'Appointment').toString());
              subtitle =
                  (data['datetime'] ?? _formatDateTime(data['date'])).toString();
            }

            // Determine status color
            Color statusColor;
            String statusText = actualStatus.toUpperCase();
            switch (actualStatus) {
              case 'confirmed':
                statusColor = Colors.green;
                break;
              case 'declined':
                statusColor = Colors.red;
                break;
              case 'pending':
              default:
                statusColor = Colors.orange;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Stack(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor:
                      isRides ? Colors.blue[100] : Colors.green[100],
                      child: Icon(
                        isRides ? Icons.local_taxi : Icons.event,
                        color: isRides ? Colors.blue : Colors.green,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitle.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14),
                                const SizedBox(width: 4),
                                Expanded(child: Text(subtitle)),
                              ],
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    isThreeLine: true,
                    onTap: () {
                      // TODO: navigate to details if you add endpoints
                    },
                  ),
                  // OP Number Badge - only show if confirmed and has queue number
                  if (!isRides && queueNumber != null && actualStatus == 'confirmed')
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.confirmation_number, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'OP #$queueNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
