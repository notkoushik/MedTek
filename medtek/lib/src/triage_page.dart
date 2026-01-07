// lib/src/triage_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'hospital_selection_page.dart';

class TriagePage extends StatefulWidget {
  const TriagePage({Key? key}) : super(key: key);

  @override
  State<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends State<TriagePage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  int _questionCount = 0;
  final int _maxQuestions = 3;
  bool _reportGenerated = false;

  // Use dynamic endpoint from ApiService
  String get _ollamaEndpoint => ApiService.ollamaBaseUrl;
  final String _modelName = 'OPTGPT-4:latest';

  // Voice assistant variables
  late stt.SpeechToText _speechToText;
  late FlutterTts _flutterTts;
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _currentWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Initialize Speech-to-Text
  Future<void> _initSpeech() async {
    _speechToText = stt.SpeechToText();

    try {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _speechEnabled = await _speechToText.initialize(
          onError: (error) {
            print('STT Error: ${error.errorMsg}');
            setState(() => _isListening = false);
          },
          onStatus: (status) {
            print('STT Status: $status');
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
        );
        setState(() {});
      } else {
        print('Microphone permission denied');
      }
    } catch (e) {
      print('Speech recognition initialization failed: $e');
      _speechEnabled = false;
    }
  }

  // Initialize Text-to-Speech
  Future<void> _initTts() async {
    _flutterTts = FlutterTts();

    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set handlers
      _flutterTts.setStartHandler(() {
        setState(() => _isSpeaking = true);
      });

      _flutterTts.setCompletionHandler(() {
        setState(() => _isSpeaking = false);
      });

      _flutterTts.setCancelHandler(() {
        setState(() => _isSpeaking = false);
      });

      _flutterTts.setErrorHandler((msg) {
        print('TTS Error: $msg');
        setState(() => _isSpeaking = false);
      });
    } catch (e) {
      print('TTS initialization failed: $e');
    }
  }

  // Start listening to user's voice
  Future<void> _startListening() async {
    if (!_speechEnabled || _isTyping || _reportGenerated || _isListening) return;

    // Stop any ongoing speech
    await _stopSpeaking();

    try {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _currentWords = result.recognizedWords;
            _messageController.text = _currentWords;
          });

          // Auto-send when speech finishes
          if (result.finalResult && _currentWords.trim().isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !_isTyping) {
                _stopListening();
                _sendMessage();
              }
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      setState(() => _isListening = true);
    } catch (e) {
      print('Start listening error: $e');
      setState(() => _isListening = false);
    }
  }

  // Stop listening
  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } catch (e) {
      print('Stop listening error: $e');
    }
  }

  // Speak the assistant's response
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('Speak error: $e');
    }
  }

  // Stop speaking
  Future<void> _stopSpeaking() async {
    try {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } catch (e) {
      print('Stop speaking error: $e');
    }
  }

  void _addWelcomeMessage() {
    final welcomeText = "Hi! 👋 I'm your Medical Assistant. Tell me what symptoms you're experiencing today.";
    setState(() {
      _messages.add(ChatMessage(
        text: welcomeText,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    // Speak welcome message
    Future.delayed(const Duration(milliseconds: 500), () {
      _speak(welcomeText);
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isTyping) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();
    _currentWords = '';

    // Stop any ongoing speech
    await _stopSpeaking();

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
      _questionCount++;
    });

    _scrollToBottom();

    try {
      // ✅ Build context for API (Gemini)
      final List<Map<String, String>> history = _messages.map((m) {
        return {
          'role': m.isUser ? 'user' : 'bot', 
          'content': m.text
        };
      }).toList();

      String prompt = userMessage;
      
      // If closing conversation, append instruction
      if (_questionCount >= _maxQuestions) {
        prompt += "\n\n(Generate a final medical triage report with: 1. Symptoms, 2. Possible Condition, 3. Recommended Specialist)";
      }

      // ✅ Use Backend API (Gemini)
      final reply = await ApiService().sendChatMessage(prompt, history);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isTyping = false;
        });
        
        _speak(reply);
        _scrollToBottom();

        // If this was the final report, show button
        if (_questionCount >= _maxQuestions) {
            setState(() => _reportGenerated = true);
        }
      }
    } catch (e) {
      print('Chat Error: $e');
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "I'm having trouble connecting to the brain. Please try again.",
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isTyping = false;
        });
      }
    }
  }

  String _cleanResponse(String raw) {
    var s = raw;

    // Remove system instructions and metadata
    s = s.replaceAll(RegExp(r'(Doctor|Assistant|Patient):\s*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1');
    s = s.replaceAll(RegExp(r'``````', dotAll: true), '');

    // Extract first meaningful sentence
    if (s.contains('.')) {
      final sentences = s.split('.');
      for (final sent in sentences) {
        final clean = sent.trim();
        if (clean.length > 15 &&
            !clean.toLowerCase().contains('triage') &&
            !clean.toLowerCase().contains('provide')) {
          s = clean;
          if (!s.endsWith('?')) s += sent.contains(RegExp(r'\b(how|what|when|where)\b')) ? '?' : '.';
          break;
        }
      }
    }

    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (s.isEmpty || s.length > 300) {
      s = 'Could you tell me more about your symptoms?';
    }

    return s;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }





















































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































  void _navigateToHospitalSelection() {
    // Stop any ongoing speech
    _stopSpeaking();

    // Extract report from last message
    final report = _messages.lastWhere((m) => !m.isUser).text;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalSelectionPage(
          triageResult: {'report': report, 'conversation': _messages.map((m) => m.toJson()).toList()},
          recommendedSpecialties: ['General Physician'],
          nearbyDoctors: [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFF0000),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_hospital, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medical Assistant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_questionCount}/$_maxQuestions questions',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Speaker control button
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.volume_off),
              tooltip: 'Stop Speaking',
              onPressed: _stopSpeaking,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Chat',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat'),
                  content: const Text('Start a new consultation?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _stopSpeaking();
                        _stopListening();
                        setState(() {
                          _messages.clear();
                          _questionCount = 0;
                          _reportGenerated = false;
                          _addWelcomeMessage();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick suggestions (only show at start)
          if (_messages.length <= 1) _buildQuickSuggestions(),

          // Voice status indicator
          if (_isListening || _isSpeaking) _buildVoiceStatusBanner(),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Typing indicator
          if (_isTyping) _buildTypingIndicator(),

          // Report ready button
          if (_reportGenerated)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: FilledButton.icon(
                onPressed: _navigateToHospitalSelection,
                icon: const Icon(Icons.description, size: 20),
                label: const Text('View Report & Find Hospitals'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.red,
                ),
              ),
            ),

          // Input field
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildVoiceStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: _isListening ? Colors.green.shade50 : Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.volume_up,
            size: 16,
            color: _isListening ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            _isListening ? 'Listening...' : 'Speaking...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _isListening ? Colors.green.shade900 : Colors.blue.shade900,
            ),
          ),
          if (_isListening) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.green.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final suggestions = [
      '🤒 I have a fever',
      '😷 Cough and cold',
      '🤕 Headache',
      '💊 Stomach pain',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: suggestions.map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(suggestion, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _messageController.text = suggestion.replaceAll(RegExp(r'[^\w\s]'), '').trim();
                  _sendMessage();
                },
                backgroundColor: const Color(0xFFFF0000).withOpacity(0.1),
                side: BorderSide(color: const Color(0xFFFF0000).withOpacity(0.3)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFF0000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_hospital, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? const Color(0xFFFF0000)
                        : message.isError
                        ? Colors.red.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 20),
                    ),
                    border: !message.isUser ? Border.all(color: Colors.grey[200]!) : null,
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : message.isError
                          ? Colors.red.shade900
                          : Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.black54, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFF0000),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_hospital, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: List.generate(3, (index) => Padding(
                padding: EdgeInsets.only(right: index < 2 ? 4 : 0),
                child: _buildDot(index),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Microphone button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isListening
                      ? [Colors.green, Colors.green.shade700]
                      : _speechEnabled && !_reportGenerated
                      ? [const Color(0xFFFF0000).withOpacity(0.8), const Color(0xFFCC0000)]
                      : [Colors.grey.shade300, Colors.grey.shade400],
                ),
                shape: BoxShape.circle,
                boxShadow: _isListening ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ] : [],
              ),
              child: IconButton(
                onPressed: _speechEnabled && !_reportGenerated && !_isTyping
                    ? (_isListening ? _stopListening : _startListening)
                    : null,
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListening || (_speechEnabled && !_reportGenerated)
                      ? Colors.white
                      : Colors.grey.shade600,
                ),
                tooltip: _isListening
                    ? 'Stop listening'
                    : _speechEnabled
                    ? 'Voice input'
                    : 'Microphone unavailable',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                  border: _isListening
                      ? Border.all(color: Colors.green, width: 2)
                      : null,
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: !_reportGenerated && !_isListening && !_isTyping,
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Listening...'
                        : _reportGenerated
                        ? 'Consultation complete'
                        : 'Describe your symptoms...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: _isListening ? Colors.green : Colors.grey,
                      fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _reportGenerated || _isTyping || _isListening
                      ? [Colors.grey, Colors.grey.shade400]
                      : [const Color(0xFFFF0000), const Color(0xFFCC0000)],
                ),
                shape: BoxShape.circle,
                boxShadow: _reportGenerated || _isTyping || _isListening ? [] : [
                  BoxShadow(
                    color: const Color(0xFFFF0000).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: (_isTyping || _reportGenerated || _isListening) ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
  };
}
