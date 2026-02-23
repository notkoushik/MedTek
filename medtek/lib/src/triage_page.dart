// lib/src/triage_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'hospital_selection_page.dart';

// ─── Language Config ──────────────────────────────────────────────────────────
class _Lang {
  final String code;
  final String localeId; // For Speech-to-Text & TTS
  final String label;
  final String flag;
  final String welcomeText;
  final String hintText;
  final String listeningText;
  final String completedText;
  final List<String> suggestions;

  const _Lang({
    required this.code,
    required this.localeId,
    required this.label,
    required this.flag,
    required this.welcomeText,
    required this.hintText,
    required this.listeningText,
    required this.completedText,
    required this.suggestions,
  });
}

const List<_Lang> _languages = [
  _Lang(
    code: 'en',
    localeId: 'en_US',
    label: 'EN',
    flag: '🇬🇧',
    welcomeText: "Hi! 👋 I'm your Medical Assistant. Tell me what symptoms you're experiencing today.",
    hintText: 'Describe your symptoms...',
    listeningText: 'Listening...',
    completedText: 'Consultation complete',
    suggestions: ['🤒 Fever & headache', '😷 Cough & cold', '🤕 Body pain', '💊 Stomach pain', '😰 Chest pain'],
  ),
  _Lang(
    code: 'hi',
    localeId: 'hi_IN',
    label: 'हिं',
    flag: '🇮🇳',
    welcomeText: 'नमस्ते! 👋 मैं आपका मेडिकल असिस्टेंट हूँ। आज आप कौन से लक्षण महसूस कर रहे हैं?',
    hintText: 'अपने लक्षण बताएं...',
    listeningText: 'सुन रहा हूँ...',
    completedText: 'परामर्श पूर्ण',
    suggestions: ['🤒 बुखार और सिरदर्द', '😷 खांसी और जुकाम', '🤕 शरीर में दर्द', '💊 पेट दर्द', '😰 सीने में दर्द'],
  ),
  _Lang(
    code: 'te',
    localeId: 'te_IN',
    label: 'తె',
    flag: '🇮🇳',
    welcomeText: 'నమస్కారం! 👋 నేను మీ వైద్య సహాయకుడిని. ఈరోజు మీకు ఏ లక్షణాలు ఉన్నాయో చెప్పండి.',
    hintText: 'మీ లక్షణాలు వివరించండి...',
    listeningText: 'వింటున్నాను...',
    completedText: 'సంప్రదింపు పూర్తయింది',
    suggestions: ['🤒 జ్వరం & తలనొప్పి', '😷 దగ్గు & జలుబు', '🤕 శరీర నొప్పి', '💊 కడుపు నొప్పి', '😰 ఛాతీ నొప్పి'],
  ),
  _Lang(
    code: 'ta',
    localeId: 'ta_IN',
    label: 'த',
    flag: '🇮🇳',
    welcomeText: 'வணக்கம்! 👋 நான் உங்கள் மருத்துவ உதவியாளர். இன்று உங்களுக்கு என்ன அறிகுறிகள் உள்ளன என்று சொல்லுங்கள்.',
    hintText: 'உங்கள் அறிகுறிகளை விவரிக்கவும்...',
    listeningText: 'கேட்கிறேன்...',
    completedText: 'ஆலோசனை முடிந்தது',
    suggestions: ['🤒 காய்ச்சல் & தலைவலி', '😷 இருமல் & சளி', '🤕 உடல் வலி', '💊 வயிற்று வலி', '😰 மார்பு வலி'],
  ),
  _Lang(
    code: 'ar',
    localeId: 'ar_SA',
    label: 'عر',
    flag: '🇸🇦',
    welcomeText: 'مرحباً! 👋 أنا مساعدك الطبي. أخبرني ما هي الأعراض التي تعاني منها اليوم.',
    hintText: 'صف أعراضك...',
    listeningText: 'أستمع...',
    completedText: 'اكتملت الاستشارة',
    suggestions: ['🤒 حمى وصداع', '😷 سعال ونزلة برد', '🤕 ألم في الجسم', '💊 ألم في المعدة', '😰 ألم في الصدر'],
  ),
];

// ─── Widget ───────────────────────────────────────────────────────────────────
class TriagePage extends StatefulWidget {
  const TriagePage({Key? key}) : super(key: key);

  @override
  State<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends State<TriagePage> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  int _questionCount = 0;
  final int _maxQuestions = 3;
  bool _reportGenerated = false;
  bool _flowSelected = false;

  // Language
  int _selectedLangIndex = 0;
  _Lang get _lang => _languages[_selectedLangIndex];

  // Voice assistant
  late stt.SpeechToText _speechToText;
  late FlutterTts _flutterTts;
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _currentWords = '';

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
    _initTts();
    // _addWelcomeMessage(); // Called later when flow is selected
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Language Switch ─────────────────────────────────────────────────────
  void _switchLanguage(int index) {
    if (index == _selectedLangIndex) return;
    setState(() {
      _selectedLangIndex = index;
      // Reset chat with new language welcome
      _messages.clear();
      _questionCount = 0;
      _reportGenerated = false;
    });
    _addWelcomeMessage();
  }

  // ─── Speech ──────────────────────────────────────────────────────────────
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
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
        );
        setState(() {});
      }
    } catch (e) {
      print('Speech init failed: $e');
      _speechEnabled = false;
    }
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setStartHandler(() => setState(() => _isSpeaking = true));
      _flutterTts.setCompletionHandler(() => setState(() => _isSpeaking = false));
      _flutterTts.setCancelHandler(() => setState(() => _isSpeaking = false));
      _flutterTts.setErrorHandler((msg) => setState(() => _isSpeaking = false));
    } catch (e) {
      print('TTS init failed: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled || _isTyping || _reportGenerated || _isListening) return;
    await _stopSpeaking();
    try {
      // ✅ Start listening in the selected language locale (e.g. te_IN)
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _currentWords = result.recognizedWords;
            _messageController.text = _currentWords;
          });
          if (result.finalResult && _currentWords.trim().isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !_isTyping) {
                _stopListening();
                _sendMessage();
              }
            });
          }
        },
        localeId: _lang.localeId, // <--- Using the selected language locale
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

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } catch (e) {
      print('Stop listening error: $e');
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final bool audioEnabled = prefs.getBool('audio_greetings_enabled') ?? true;
    if (!audioEnabled) return;
    try {
      // ✅ Speak in the selected language locale
      await _flutterTts.setLanguage(_lang.localeId);
      await _flutterTts.speak(text);
    } catch (e) {
      print('Speak error: $e');
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } catch (e) {
      print('Stop speaking error: $e');
    }
  }

  // ─── Chat Logic ───────────────────────────────────────────────────────────
  void _addWelcomeMessage() {
    final welcomeText = _lang.welcomeText;
    setState(() {
      _messages.add(ChatMessage(
        text: welcomeText,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    Future.delayed(const Duration(milliseconds: 500), () => _speak(welcomeText));
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isTyping) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();
    _currentWords = '';

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
      final List<Map<String, String>> history = _messages.map((m) {
        return {'role': m.isUser ? 'user' : 'bot', 'content': m.text};
      }).toList();

      String prompt = userMessage;
      if (_questionCount >= _maxQuestions) {
        prompt += "\n\n(Generate a final medical triage report with: 1. Symptoms, 2. Possible Condition, 3. Recommended Specialist)";
      }

      final session = context.read<SessionService>();
      final user = session.user;

      final Map<String, dynamic> userProfile = {
        'name': user?['name'] ?? 'Patient',
        'age': '30',
        'gender': 'Unknown',
        'allergies': 'None',
        'conditions': 'None',
        'language': _lang.code,
      };

      // ✅ Use Ollama (OptGPT-4:latest) for triage chat
      final reply = await ApiService().sendChatMessageOllama(prompt, history, userProfile: userProfile);

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
        if (_questionCount >= _maxQuestions) {
          setState(() => _reportGenerated = true);
        }
      }
    } catch (e) {
      print('Chat Error: $e');
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "I'm having trouble connecting. Please try again.",
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
          _isTyping = false;
        });
      }
    }
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

  void _navigateToHospitalSelection() async {
    _stopSpeaking();
    final report = _messages.lastWhere((m) => !m.isUser).text;

    // Show a loading dialog while saving
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final session = context.read<SessionService>();
      final user = session.user;
      final userId = user?['id']?.toString() ?? 'anonymous';
      final conversation = _messages.map((m) => m.toJson()).toList();
      
      final userProfile = {
        'name': user?['name'] ?? 'Patient',
        'age': '30',
        'gender': 'Unknown',
        'allergies': 'None',
        'conditions': 'None',
        'language': _lang.code,
      };

      // Save to JSON on backend
      final savedData = await ApiService().saveTriageReport(
        userId: userId,
        report: report,
        conversation: conversation,
        userProfile: userProfile,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HospitalSelectionPage(
              triageResult: {
                'report': report,
                'conversation': conversation,
                'savedData': savedData,
              },
              recommendedSpecialties: ['General Physician'],
              nearbyDoctors: [],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      print('Error saving triage json: $e');
      // Still navigate even if saving fails
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HospitalSelectionPage(
              triageResult: {
                'report': report,
                'conversation': _messages.map((m) => m.toJson()).toList(),
              },
              recommendedSpecialties: ['General Physician'],
              nearbyDoctors: [],
            ),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_flowSelected) {
      return _buildOptionSelection();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildHeader(),
          _buildLanguageSelector(),
          if (_messages.length <= 1) _buildQuickSuggestions(),
          if (_isListening || _isSpeaking) _buildVoiceStatusBanner(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
            ),
          ),
          if (_isTyping) _buildTypingIndicator(),
          if (_reportGenerated) _buildReportButton(),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildOptionSelection() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('New Consultation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How would you like to proceed?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose an option below to get the best care.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildOptionCard(
              title: 'Direct Appointment',
              description: 'Book a diagnosis appointment with a doctor directly without AI triage.',
              icon: Icons.calendar_month_rounded,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HospitalSelectionPage(
                      triageResult: {
                        'report': 'Direct Appointment',
                        'conversation': [],
                      },
                      recommendedSpecialties: ['General Physician'],
                      nearbyDoctors: [],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildOptionCard(
              title: 'AI Custom Diagnosis',
              description: 'Complete a custom diagnosis using advanced OptGPT-4.0 for better understanding.',
              icon: Icons.psychology_rounded,
              color: Colors.red,
              onTap: () {
                setState(() {
                  _flowSelected = true;
                });
                _addWelcomeMessage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: color.shade100, width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // AI Avatar with pulse
          ScaleTransition(
            scale: _isTyping ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MedTek Triage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isTyping ? Colors.orangeAccent : Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isTyping ? Colors.orange : Colors.green).withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isTyping
                          ? 'Analyzing...'
                          : 'OptGPT-4 • ${_questionCount}/$_maxQuestions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.volume_off_rounded, color: Colors.white, size: 22),
              onPressed: _stopSpeaking,
              tooltip: 'Stop Speaking',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: () => _showResetDialog(),
            tooltip: 'New Chat',
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start New Consultation?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This will clear the current chat and start fresh.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _stopSpeaking();
              _stopListening();
              setState(() {
                _messages.clear();
                _questionCount = 0;
                _reportGenerated = false;
              });
              _addWelcomeMessage();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear Chat'),
          ),
        ],
      ),
    );
  }

  // ─── Language Selector ────────────────────────────────────────────────────
  Widget _buildLanguageSelector() {
    return Container(
      color: const Color(0xFFB71C1C),
      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_languages.length, (i) {
            final lang = _languages[i];
            final isSelected = i == _selectedLangIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => _switchLanguage(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lang.flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 1),
                      Text(
                        lang.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFFB71C1C) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Quick Suggestions ────────────────────────────────────────────────────
  Widget _buildQuickSuggestions() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Quick symptoms',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _lang.suggestions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      _messageController.text = s.replaceAll(RegExp(r'[^\w\s\u0900-\u097F\u0C00-\u0C7F\u0B80-\u0BFF\u0600-\u06FF]'), '').trim();
                      _sendMessage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.25)),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB71C1C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Voice Status Banner ──────────────────────────────────────────────────
  Widget _buildVoiceStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: _isListening ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isListening ? Icons.mic_rounded : Icons.volume_up_rounded,
            size: 16,
            color: _isListening ? Colors.green.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            _isListening ? _lang.listeningText : 'Speaking...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isListening ? Colors.green.shade800 : Colors.blue.shade800,
            ),
          ),
          if (_isListening) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Message Bubble ───────────────────────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.74,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : message.isError
                            ? const Color(0xFFFEE2E2)
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFFE53935).withOpacity(0.2)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: !isUser && !message.isError
                        ? Border.all(color: const Color(0xFFEEEEEE), width: 1)
                        : null,
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : message.isError
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF1F2937),
                      fontSize: 14.5,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: isUser ? 0 : 4,
                    right: isUser ? 4 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.done_all_rounded, size: 13, color: Colors.grey[400]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Typing Indicator ─────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Analyzing',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                ...List.generate(3, (i) => Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 3 : 0),
                  child: _buildDot(i),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 150)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -3 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  // ─── Report Button ────────────────────────────────────────────────────────
  Widget _buildReportButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToHospitalSelection,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.assignment_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'View Report & Find Hospitals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Input Field ──────────────────────────────────────────────────────────
  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Mic button
            _buildCircleButton(
              icon: _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              colors: _isListening
                  ? [Colors.green.shade400, Colors.green.shade700]
                  : _speechEnabled && !_reportGenerated
                      ? [const Color(0xFFE53935), const Color(0xFFB71C1C)]
                      : [Colors.grey.shade300, Colors.grey.shade400],
              glowColor: _isListening ? Colors.green : null,
              onTap: _speechEnabled && !_reportGenerated && !_isTyping
                  ? (_isListening ? _stopListening : _startListening)
                  : null,
            ),
            const SizedBox(width: 10),
            // Text field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isListening
                        ? Colors.green.shade400
                        : const Color(0xFFE8E8E8),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: !_reportGenerated && !_isListening && !_isTyping,
                  style: const TextStyle(fontSize: 14.5, color: Color(0xFF1F2937)),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? _lang.listeningText
                        : _reportGenerated
                            ? _lang.completedText
                            : _lang.hintText,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: _isListening ? Colors.green.shade600 : Colors.grey.shade500,
                      fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Send button
            _buildCircleButton(
              icon: Icons.send_rounded,
              colors: _reportGenerated || _isTyping || _isListening
                  ? [Colors.grey.shade300, Colors.grey.shade400]
                  : [const Color(0xFFE53935), const Color(0xFFB71C1C)],
              glowColor: _reportGenerated || _isTyping || _isListening
                  ? null
                  : const Color(0xFFE53935),
              onTap: !_reportGenerated && !_isTyping && !_isListening ? _sendMessage : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required List<Color> colors,
    Color? glowColor,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

// ─── ChatMessage Model ────────────────────────────────────────────────────────
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
