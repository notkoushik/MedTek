// lib/pages/speak.dart - Voice-Assisted Medical Triage
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MedicalTriageAssistant extends StatefulWidget {
  const MedicalTriageAssistant({Key? key}) : super(key: key);

  @override
  State<MedicalTriageAssistant> createState() => _MedicalTriageAssistantState();
}

class _MedicalTriageAssistantState extends State<MedicalTriageAssistant>
    with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  late AnimationController _animationController;
  late AnimationController _pulseController;

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  bool _speechEnabled = false;
  String _recognizedText = '';

  final List<Map<String, String>> _conversationHistory = [];
  String _lastBotMessage = '';

  final String _ollamaEndpoint = 'http://192.168.1.102:8006/api/generate';
  final String _modelName = 'OPTGPT-4:latest';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initializeSpeech();
    _initializeTts();
    _requestPermissions();
    _sendWelcomeMessage();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.microphone.request();
    if (status.isDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice input'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _initializeSpeech() async {
    _speech = stt.SpeechToText();
    _speechEnabled = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech Status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        debugPrint('Speech Error: ${error.errorMsg}');
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (_speechEnabled) {
      debugPrint('✅ Speech recognition initialized');
    }
  }

  void _initializeTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        // Auto-start listening after bot finishes speaking
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isListening) {
            _startListening();
          }
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
      debugPrint('TTS Error: $msg');
    });

    debugPrint('✅ Text-to-Speech initialized');
  }

  void _sendWelcomeMessage() async {
    await Future.delayed(const Duration(milliseconds: 500));
    String welcomeMsg = "Hi! I'm your medical assistant. Tell me what you're feeling today.";

    if (mounted) {
      setState(() => _lastBotMessage = welcomeMsg);
      await _speak(welcomeMsg);
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.speak(text);
  }

  void _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    if (!_isListening && !_isSpeaking) {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _recognizedText = result.recognizedWords);

            if (result.finalResult && _recognizedText.trim().isNotEmpty) {
              _processUserInput(_recognizedText);
              setState(() => _isListening = false);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  void _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  // Clean bot response to remove system text
  String _cleanBotResponse(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'.*?(?:Engage conversationally|ask follow-up|Dont generate).*?(?=\d+\.|\n)', caseSensitive: false, dotAll: true), '');
    s = s.replaceAll(RegExp(r'You are a medical.*?(?=\n|$)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'(assistant|user|Patient|Doctor):', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1');
    s = s.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Extract first question if multiple
    if (s.contains(RegExp(r'\?.*\?'))) {
      final sentences = s.split('?');
      if (sentences.isNotEmpty) {
        s = sentences.first.trim() + '?';
      }
    }

    if (s.length > 300) {
      final sentences = s.split(RegExp(r'[.!?]'));
      for (final sent in sentences) {
        if (sent.trim().length > 15) {
          s = sent.trim();
          if (!s.endsWith('?') && (s.contains('how') || s.contains('what'))) {
            s += '?';
          }
          break;
        }
      }
    }

    if (s.isEmpty || s.length > 400) {
      s = 'Could you tell me more about your symptoms?';
    }

    return s.trim();
  }

  void _processUserInput(String input) async {
    if (input.trim().isEmpty) return;

    await _flutterTts.stop();

    if (mounted) {
      setState(() => _isProcessing = true);
    }

    _conversationHistory.add({'role': 'user', 'content': input});

    // Get response from model
    String response = await _getTriageResponse(input);
    String cleanResponse = _cleanBotResponse(response);

    _conversationHistory.add({'role': 'assistant', 'content': cleanResponse});

    if (mounted) {
      setState(() {
        _lastBotMessage = cleanResponse;
        _isProcessing = false;
        _recognizedText = '';
      });

      // Speak the response
      await _speak(cleanResponse);
    }
  }

  Future<String> _getTriageResponse(String userInput) async {
    try {
      // Keep only last 4 messages for context
      final recent = _conversationHistory.length > 4
          ? _conversationHistory.sublist(_conversationHistory.length - 4)
          : _conversationHistory;

      final conversation = recent
          .map((m) => '${m['role'] == 'user' ? 'Patient' : 'Doctor'}: ${m['content']}')
          .join('\n');

      final prompt = '''You are a friendly medical assistant. Ask ONE short question about symptoms. Reply in 1-2 sentences max.

$conversation

Doctor:''';

      final body = jsonEncode({
        'model': _modelName,
        'prompt': prompt,
        'max_tokens': 150,
        'temperature': 0.6,
        'stream': false,
        'stop': ['\n\n', 'Patient:'],
      });

      final resp = await http.post(
        Uri.parse(_ollamaEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['response'] ?? data['text'] ?? '').toString().trim();
      } else {
        return "Sorry, I didn't catch that. Could you repeat?";
      }
    } catch (e) {
      debugPrint('Model error: $e');
      return "I'm having trouble connecting. Could you try again?";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Voice Assistant',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main animated circle visualization
          Center(
            child: GestureDetector(
              onTap: () {
                if (_isListening) {
                  _stopListening();
                } else if (!_isSpeaking && !_isProcessing) {
                  _startListening();
                }
              },
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height * 0.7,
                    ),
                    painter: VoiceWavePainter(
                      animation: _animationController.value,
                      isActive: _isListening || _isSpeaking,
                      pulseAnimation: _pulseController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // Display last bot message
          if (_lastBotMessage.isNotEmpty)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _lastBotMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pause button
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else if (_isSpeaking) {
                      _flutterTts.stop();
                    }
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                // End button
                GestureDetector(
                  onTap: () {
                    _stopListening();
                    _flutterTts.stop();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status text at bottom
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    _isListening
                        ? 'Listening...'
                        : _isProcessing
                        ? 'Processing...'
                        : _isSpeaking
                        ? 'Speaking...'
                        : 'Tap to speak',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_recognizedText.isNotEmpty && _isListening)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _recognizedText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }
}

// Custom painter for animated voice waves
class VoiceWavePainter extends CustomPainter {
  final double animation;
  final bool isActive;
  final double pulseAnimation;

  VoiceWavePainter({
    required this.animation,
    required this.isActive,
    required this.pulseAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (isActive) {
      // Draw multiple animated wave circles
      for (int i = 0; i < 3; i++) {
        final double waveOffset = (animation + (i * 0.3)) % 1.0;
        final double radius = 80 + (waveOffset * 120);
        final double opacity = 1.0 - waveOffset;

        final paint = Paint()
          ..color = Colors.blue.withOpacity(opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

        canvas.drawCircle(center, radius, paint);
      }

      // Draw pulsing inner circle
      final innerPaint = Paint()
        ..color = Colors.blue.withOpacity(0.6 + (pulseAnimation * 0.4))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        center,
        60 + (pulseAnimation * 20),
        innerPaint,
      );
    } else {
      // Draw static circle when inactive
      final paint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, 80, paint);
    }

    // Draw center circle
    final centerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 50, centerPaint);

    // Draw microphone icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.mic.codePoint),
        style: TextStyle(
          fontSize: 40,
          fontFamily: Icons.mic.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(VoiceWavePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.isActive != isActive ||
        oldDelegate.pulseAnimation != pulseAnimation;
  }
}
