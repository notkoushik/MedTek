import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'src/auth_page.dart';
import 'src/patient_dashboard.dart';
import 'src/doctor_dashboard.dart';
import 'src/lab_dashboard.dart';
import 'theme/app_theme.dart';

import 'providers/ride_provider.dart';
import 'providers/location_provider.dart';
import 'screens/rider/ride_booking_screen.dart';
import 'screens/rider/ride_success_page.dart';
import 'screens/rider/ride_tracking_screen.dart';
import 'screens/activities/my_activities_page.dart';
import 'widgets/finding_driver_screen.dart';

import 'services/api_service.dart';
import 'services/session_service.dart';
import 'config/env_config.dart';


class ThemeNotifier extends ChangeNotifier {
  static const _prefKey = 'themeMode';
  ThemeMode _mode = ThemeMode.system;

  ThemeNotifier._();

  ThemeMode get mode => _mode;

  static Future<ThemeNotifier> create() async {
    final t = ThemeNotifier._();
    await t._load();
    return t;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefKey) ?? 'system';
      _mode = _fromString(s);
    } catch (_) {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _toString(m));
    } catch (_) {}
  }

  String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Mapbox access token from environment config
  MapboxOptions.setAccessToken(EnvConfig.mapboxAccessToken);

  final themeNotifier = await ThemeNotifier.create();
  final session = SessionService.instance;
  await session.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
        ChangeNotifierProvider(
          create: (_) => RideProvider(
            googleApiKey: 'AIzaSyDZkvVC-1kwBR5_GwiBRiUEjNclpu0W9KY',
          ),
        ),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider<SessionService>.value(value: session),
      ],
      child: const Medtek(),
    ),
  );
}

class Medtek extends StatelessWidget {
  const Medtek({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, theme, child) {
        return MaterialApp(
          title: 'Triage App',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.mode,
          debugShowCheckedModeBanner: false,
          home: const EntryGate(),
          routes: {
            '/login': (context) => const AuthPage(), 
            '/home': (context) => const PatientDashboard(),
            '/lab-dashboard': (context) => const LabDashboard(), 

            // Ride booking: uses doubles passed via arguments map
            '/ride-booking': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map<String, dynamic>) {
                return RideBookingPage(
                  pickupLat: args['pickupLat'] as double,
                  pickupLng: args['pickupLng'] as double,
                  dropoffLat: args['dropoffLat'] as double,
                  dropoffLng: args['dropoffLng'] as double,
                  hospitalName: args['hospitalName'] as String,
                );
              }
              // Fallback (should rarely be used)
              return const RideBookingPage(
                pickupLat: 0,
                pickupLng: 0,
                dropoffLat: 0,
                dropoffLng: 0,
                hospitalName: 'Unknown',
              );
            },

            '/finding-driver': (context) {
              final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>;
              return FindingDriverScreen(
                rideId: args['rideId'] as String,
                pickupLocation: args['pickupLocation'],
                mode: args['mode'],
              );
            },

            '/ride-tracking': (context) {
              final rideId =
              ModalRoute.of(context)!.settings.arguments as String;
              return RideTrackingScreen(rideId: rideId);
            },

            '/ride-success': (context) {
              final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return RideSuccessPage(
                rideId: args['rideId'],
                hospitalName: args['hospitalName'],
                estimatedFare: args['estimatedFare'],
                estimatedDistance: args['estimatedDistance'],
              );
            },

            '/activities': (context) => const MyActivitiesPage(),
          },
        );
      },
    );
  }
}

class EntryGate extends StatefulWidget {
  const EntryGate({Key? key}) : super(key: key);

  @override
  State<EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends State<EntryGate> {
  final api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final session = context.read<SessionService>();
    final token = session.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _user = null;
      });
      return;
    }

    try {
      final me = await session.fetchMe(api);
      setState(() {
        _user = me;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Session expired, please log in again.';
        _user = null;
        _loading = false;
      });
      await session.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_user == null) {
      return const AuthPage();
    }

    final role = (_user!['role'] ?? 'patient')
        .toString()
        .trim()
        .toLowerCase();

    if (role == 'doctor') {
      return const DoctorDashboard();
    } else if (role == 'lab_assistant') {
      return const LabDashboard();
    } else {
      return const PatientDashboard();
    }
  }
}
