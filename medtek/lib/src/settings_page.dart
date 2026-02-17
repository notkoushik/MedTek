import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _audioGreetingsEnabled = true; // Default to true
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _audioGreetingsEnabled = prefs.getBool('audio_greetings_enabled') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleAudioGreetings(bool value) async {
    setState(() {
      _audioGreetingsEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_greetings_enabled', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Triage Voice Greetings'),
                  subtitle: const Text('Enable audio greetings and responses in Triage'),
                  value: _audioGreetingsEnabled,
                  onChanged: _toggleAudioGreetings,
                  secondary: Icon(
                    Icons.record_voice_over,
                    color: _audioGreetingsEnabled ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
    );
  }
}
