import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';
import 'chat_conversation_screen.dart';

class AIEmergencyChatScreen extends StatefulWidget {
  const AIEmergencyChatScreen({super.key});

  @override
  State<AIEmergencyChatScreen> createState() => _AIEmergencyChatScreenState();
}

class _AIEmergencyChatScreenState extends State<AIEmergencyChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _processingController;
  late AnimationController _countdownController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _processingAnimation;
  late Animation<double> _countdownAnimation;

  // State Management
  bool _isSubmitting = false;
  bool _isProcessing = false;
  bool _showConfirmDialog = false;
  Position? _currentPosition;
  String? _selectedPrompt;
  String? _pendingMessage;
  bool _hasText = false;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;

  // Speech-to-Text
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderReady = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _pathToAudioFile;
  static const String _sttApiUrl =
      "https://help-map.saadalabyad.com/api/v1/ai/test-speech-to-text";

  final List<ProcessingStage> _processingStages = [
    ProcessingStage(
      icon: Icons.analytics_outlined,
      title: 'Analyzing Emergency',
      subtitle: 'AI is categorizing your report...',
      duration: 1500,
    ),
    ProcessingStage(
      icon: Icons.location_searching_outlined,
      title: 'Writing Safety Tips',
      subtitle: 'Providing guidance to keep you safe...',
      duration: 1200,
    ),
    ProcessingStage(
      icon: Icons.groups_outlined,
      title: 'Detecting Missing Info',
      subtitle: 'Checking your report for important details...',
      duration: 1000,
    ),
    ProcessingStage(
      icon: Icons.check_circle_outline,
      title: 'Finalizing Report',
      subtitle: 'Your emergency help is on the way!',
      duration: 800,
    ),
  ];
  int _currentStageIndex = 0;

  // Emergency Prompt Categories
  final List<EmergencyPromptCategory> _categories = [
    EmergencyPromptCategory(
      title: 'Medical Emergency',
      icon: Icons.medical_services_outlined,
      color: Colors.red,
      prompts: [
        'Someone is unconscious and not breathing',
        'Severe chest pain or heart attack symptoms',
        'Major bleeding that won\'t stop',
        'Choking emergency',
        'Severe allergic reaction',
      ],
    ),
    EmergencyPromptCategory(
      title: 'Fire Emergency',
      icon: Icons.local_fire_department_outlined,
      color: Colors.orange,
      prompts: [
        'House fire - people trapped inside',
        'Vehicle fire on the road',
        'Wildfire approaching residential area',
        'Gas leak with fire risk',
        'Electrical fire in building',
      ],
    ),
    EmergencyPromptCategory(
      title: 'Crime & Safety',
      icon: Icons.security_outlined,
      color: Colors.blue,
      prompts: [
        'Break-in in progress',
        'Armed robbery happening now',
        'Domestic violence situation',
        'Suspicious person with weapon',
        'Assault in progress',
      ],
    ),
    EmergencyPromptCategory(
      title: 'Traffic & Accidents',
      icon: Icons.car_crash_outlined,
      color: Colors.purple,
      prompts: [
        'Multi-car accident with injuries',
        'Hit and run - pedestrian injured',
        'Vehicle blocking emergency route',
        'Drunk driver weaving dangerously',
        'Road hazard causing accidents',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupTextFieldListener();
    _getCurrentLocation();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _processingController.dispose();
    _countdownController.dispose();
    _countdownTimer?.cancel();
    _recorder.closeRecorder();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _processingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _countdownController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _processingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _processingController, curve: Curves.easeInOut),
    );
    _countdownAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.linear),
    );

    _processingController.repeat();
    _fadeController.forward();
    _slideController.forward();
  }

  void _setupTextFieldListener() {
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint("Failed to get location for AI chat: $e");
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
      final tempDir = await getTemporaryDirectory();
      final ext = 'wav';
      _pathToAudioFile = p.join(tempDir.path, 'emergency_record.$ext');
      await _recorder
          .setSubscriptionDuration(const Duration(milliseconds: 500));
      setState(() => _isRecorderReady = true);
    } catch (e) {
      debugPrint("Recorder initialization failed: $e");
      _showErrorMessage("Microphone access is required for voice messages.");
    }
  }

  void _startCountdown(String message) {
    setState(() {
      _showConfirmDialog = true;
      _pendingMessage = message;
      _countdownSeconds = 5;
    });

    _countdownController.reset();
    _countdownController.forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _confirmSendMessage();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownController.reset();
    setState(() {
      _showConfirmDialog = false;
      _pendingMessage = null;
      _countdownSeconds = 5;
    });
  }

  void _confirmSendMessage() async {
    if (_pendingMessage == null) return;

    _countdownTimer?.cancel();
    setState(() {
      _showConfirmDialog = false;
      _isSubmitting = true;
      _isProcessing = true;
      _currentStageIndex = 0;
    });

    HapticFeedback.mediumImpact();
    _startProcessingStages();

    try {
      final auth = context.read<ChatCubit>();
      final authCubit = context.read<AuthCubit>();
      final token = authCubit.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication error');
      }

      final lat = _currentPosition?.latitude ?? 33.49375;
      final lon = _currentPosition?.longitude ?? 36.32052;
      final address =
          _currentPosition != null ? 'Live Location' : 'Default Location';

      await auth.sendMessage(
        chatId: null,
        lat: lat,
        lon: lon,
        address: address,
        text: _pendingMessage!,
      );
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to send message: ${e.toString()}');
        setState(() {
          _isSubmitting = false;
          _isProcessing = false;
        });
        _messageController.text = _pendingMessage!;
      }
    }

    _pendingMessage = null;
  }

  void _startProcessingStages() async {
    for (int i = 0; i < _processingStages.length; i++) {
      if (!mounted || !_isProcessing) break;

      setState(() => _currentStageIndex = i);
      await Future.delayed(
          Duration(milliseconds: _processingStages[i].duration));
    }
  }

  Future<void> _handleSendMessage({String? promptText}) async {
    if (_isSubmitting) return;

    final message = promptText ?? _messageController.text.trim();
    if (message.isEmpty) return;

    if (promptText == null) {
      _messageController.clear();
    }

    setState(() => _selectedPrompt = promptText);
    _startCountdown(message);
  }

  Future<void> _toggleRecording() async {
    if (!_isRecorderReady) {
      _showErrorMessage("Recorder not ready.");
      return;
    }
    if (_isRecording) {
      await _stopRecordingAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final codec = Codec.pcm16WAV;
      await _recorder.startRecorder(
        toFile: _pathToAudioFile,
        codec: codec,
      );
      setState(() => _isRecording = true);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint("startRecorder failed: $e");
      try {
        final dir = await getTemporaryDirectory();
        _pathToAudioFile = p.join(dir.path, 'emergency_record.aac');
        await _recorder.startRecorder(
          toFile: _pathToAudioFile,
          codec: Codec.aacADTS,
        );
        setState(() => _isRecording = true);
        HapticFeedback.lightImpact();
      } catch (e2) {
        debugPrint("Fallback AAC startRecorder failed: $e2");
        _showErrorMessage("Could not start recording.");
      }
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
      HapticFeedback.lightImpact();
      await _transcribeAudio();
    } catch (e) {
      debugPrint("Error stopping recorder: $e");
      _showErrorMessage("Failed to process audio.");
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _transcribeAudio() async {
    if (_pathToAudioFile == null || !File(_pathToAudioFile!).existsSync()) {
      _showErrorMessage("Audio file not found.");
      return;
    }
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_sttApiUrl))
        ..files.add(
            await http.MultipartFile.fromPath('audio_file', _pathToAudioFile!));

      final response =
          await request.send().timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body);
        if (data['success'] == true && data['data']?['transcription'] != null) {
          final transcription = data['data']['transcription'] as String;
          _messageController.text = transcription;
          HapticFeedback.selectionClick();
        } else {
          throw Exception("API returned invalid data.");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Transcription failed: $e");
      _showErrorMessage("Speech-to-text failed.");
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCubit, ChatState>(
      listener: (context, state) {
        if (state is ChatNewConversationStarted) {
          final newConversationId = state.firstMessage.conversationId;
          final auth = context.read<AuthCubit>();

          if (newConversationId != null && auth.isAuthenticated) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    BlocProvider.value(
                  value: context.read<ChatCubit>(),
                  child: ChatConversationScreen(
                    chatId: newConversationId,
                    chatTitle: 'Emergency Response',
                    currentUserId: auth.userId!,
                    participants: [],
                  ),
                ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    )),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 350),
              ),
            );
          }
        } else if (state is ChatError) {
          if (mounted) {
            _showErrorMessage(state.message);
            setState(() {
              _isSubmitting = false;
              _isProcessing = false;
              _selectedPrompt = null;
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Stack(
          children: [
            _buildMainContent(),
            if (_showConfirmDialog) _buildConfirmDialog(),
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F9FA), Color(0xFFFFFFFF)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        _buildWelcomeSection(),
                        const SizedBox(height: 24),
                        _buildPromptCategoriesSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade600],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '🚨',
                style: TextStyle(
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency AI Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  '24/7 Emergency Response',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'How can I help you today?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'I\'m your AI emergency assistant. Describe your situation or choose from common scenarios below for faster response.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Common Emergencies',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_categories.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildCategoryCard(_categories[index]),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryCard(EmergencyPromptCategory category) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.color.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            category.icon,
            color: category.color,
            size: 24,
          ),
        ),
        title: Text(
          category.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Text(
          '${category.prompts.length} quick options',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        children: [
          ...category.prompts
              .map((prompt) => _buildPromptTile(prompt, category.color)),
        ],
      ),
    );
  }

  Widget _buildPromptTile(String prompt, MaterialColor categoryColor) {
    final isSelected = _selectedPrompt == prompt && _showConfirmDialog;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isSubmitting
              ? null
              : () => _handleSendMessage(promptText: prompt),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? categoryColor.shade50 : categoryColor.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? categoryColor : categoryColor.shade100,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    prompt,
                    style: TextStyle(
                      fontSize: 14,
                      color: categoryColor.shade700,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: categoryColor.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    enabled: !_isSubmitting,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isRecording
                          ? 'Recording audio...'
                          : 'Describe your emergency in detail...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildMicButton(),
              const SizedBox(width: 8),
              _buildSendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _isRecorderReady && !_isSubmitting ? _toggleRecording : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red.shade50 : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isRecording ? Colors.red.shade300 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: _isTranscribing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
              )
            : Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: _isRecording ? Colors.red : Colors.grey.shade600,
                size: 24,
              ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _hasText && !_isSubmitting ? _handleSendMessage : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _hasText && !_isSubmitting
                ? [Colors.red.shade400, Colors.red.shade600]
                : [Colors.grey.shade300, Colors.grey.shade400],
          ),
          shape: BoxShape.circle,
          boxShadow: _hasText && !_isSubmitting
              ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildConfirmDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _countdownAnimation,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: _countdownAnimation.value,
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.red.shade400),
                          backgroundColor: Colors.red.shade100,
                        );
                      },
                    ),
                    Text(
                      '$_countdownSeconds',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirm Emergency Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _pendingMessage ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'This will be sent to emergency responders in $_countdownSeconds seconds',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelCountdown,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmSendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Send Now'),
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

  Widget _buildProcessingOverlay() {
    final currentStage = _processingStages[_currentStageIndex];

    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade100, Colors.blue.shade50],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _processingAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade400),
                          backgroundColor: Colors.blue.shade100,
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      currentStage.icon,
                      size: 36,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                currentStage.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                currentStage.subtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_processingStages.length, (index) {
                  final isActive = index <= _currentStageIndex;
                  final isCurrent = index == _currentStageIndex;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isCurrent ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.blue.shade400
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Text(
                'Please wait while we process your emergency report',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ));
  }
}

class EmergencyPromptCategory {
  final String title;
  final IconData icon;
  final MaterialColor color;
  final List<String> prompts;

  EmergencyPromptCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.prompts,
  });
}

class ProcessingStage {
  final IconData icon;
  final String title;
  final String subtitle;
  final int duration;

  ProcessingStage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.duration,
  });
}
