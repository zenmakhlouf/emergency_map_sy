import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emergency_map_sy/features/auth/cubit/auth_cubit.dart';
import 'package:emergency_map_sy/features/chat/cubit/chat_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'chat_conversation_screen.dart';

// --- MAIN WIDGET ---

class AIEmergencyChatScreen extends StatefulWidget {
  const AIEmergencyChatScreen({super.key});

  @override
  State<AIEmergencyChatScreen> createState() => _AIEmergencyChatScreenState();
}

class _AIEmergencyChatScreenState extends State<AIEmergencyChatScreen>
    with TickerProviderStateMixin {
  // --- STATE MANAGEMENT ---
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final MapController _mapController = MapController();

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _processingController;
  late AnimationController _countdownController;
  late AnimationController _markerPulseController;

  // UI State
  bool _isSubmitting = false;
  bool _isProcessing = false;
  bool _showConfirmDialog = false;
  bool _showLocationSelector = false;
  bool _hasText = false;

  // Data State
  Position? _currentPosition;
  LatLng? _selectedLocation;
  String? _pendingMessage;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;
  int _currentStageIndex = 0;

  // Speech-to-Text State
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderReady = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _pathToAudioFile;
  static const String _sttApiUrl =
      "https://help-map.saadalabyad.com/api/v1/ai/test-speech-to-text";

  // --- CONFIGURATION ---
  final List<ProcessingStage> _processingStages = [
    ProcessingStage(
        icon: Icons.analytics_outlined,
        title: 'Analyzing Emergency',
        subtitle: 'AI is categorizing your report...',
        duration: 1500),
    ProcessingStage(
        icon: Icons.health_and_safety_outlined,
        title: 'Writing Safety Tips',
        subtitle: 'Generating immediate safety instructions...',
        duration: 1200),
    ProcessingStage(
        icon: Icons.rule_folder_outlined,
        title: 'Detecting Missing Info',
        subtitle: 'Checking for critical details...',
        duration: 1000),
    ProcessingStage(
        icon: Icons.check_circle_outline,
        title: 'Finalizing Report',
        subtitle: 'Connecting you to responders...',
        duration: 800),
  ];

  final List<EmergencyPromptCategory> _categories = [
    EmergencyPromptCategory(
        title: 'Medical Emergency',
        icon: Icons.medical_services_outlined,
        color: Colors.red,
        prompts: [
          'Someone is unconscious and not breathing',
          'Severe chest pain or heart attack symptoms',
          'Major bleeding that won\'t stop'
        ]),
    EmergencyPromptCategory(
        title: 'Fire Emergency',
        icon: Icons.local_fire_department_outlined,
        color: Colors.orange,
        prompts: [
          'House fire - people trapped inside',
          'Vehicle fire on the road',
          'Wildfire approaching residential area'
        ]),
    EmergencyPromptCategory(
        title: 'Crime & Safety',
        icon: Icons.security_outlined,
        color: Colors.blue,
        prompts: [
          'Break-in in progress',
          'Armed robbery happening now',
          'Domestic violence situation'
        ]),
  ];

  // --- LIFECYCLE METHODS ---
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _messageController.addListener(_onTextChanged);
    _getCurrentLocation();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _processingController.dispose();
    _countdownController.dispose();
    _markerPulseController.dispose();
    _countdownTimer?.cancel();
    _recorder.closeRecorder();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- INITIALIZATION ---
  void _initializeAnimations() {
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _processingController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _countdownController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _markerPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint("Failed to get location: $e");
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
      final tempDir = await getTemporaryDirectory();
      _pathToAudioFile = p.join(tempDir.path, 'emergency_record.wav');
      setState(() => _isRecorderReady = true);
    } catch (e) {
      debugPrint("Recorder initialization failed: $e");
      _showErrorMessage("Microphone access is required for voice messages.");
    }
  }

  // --- UI EVENT HANDLERS ---
  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }

  Future<void> _handleSendMessage({String? promptText}) async {
    if (_isSubmitting) return;
    final message = promptText ?? _messageController.text.trim();
    if (message.isEmpty) return;

    if (promptText == null) _messageController.clear();
    _startCountdown(message);
  }

  // --- COUNTDOWN & SUBMISSION LOGIC ---
  void _startCountdown(String message) {
    setState(() {
      _showConfirmDialog = true;
      _pendingMessage = message;
      _countdownSeconds = 5;
      _selectedLocation = _currentPosition != null
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : null;
    });

    _countdownController.reset();
    _countdownController.forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdownSeconds--);
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _confirmSendMessage();
      }
    });
  }

  void _confirmSendMessage() async {
    if (_pendingMessage == null || !mounted) return;
    _countdownTimer?.cancel();

    setState(() {
      _showConfirmDialog = false;
      _showLocationSelector = false;
      _isSubmitting = true;
      _isProcessing = true;
      _currentStageIndex = 0;
    });

    HapticFeedback.mediumImpact();
    _startProcessingStages();

    try {
      final authCubit = context.read<AuthCubit>();
      if (!authCubit.isAuthenticated) throw Exception('Authentication error');

      final lat = _selectedLocation?.latitude ?? _currentPosition?.latitude;
      final lon = _selectedLocation?.longitude ?? _currentPosition?.longitude;

      if (lat == null || lon == null) {
        throw Exception("Location is required but couldn't be determined.");
      }

      await context.read<ChatCubit>().sendMessage(
            chatId: null,
            lat: lat,
            lon: lon,
            address:
                _selectedLocation != null ? 'Custom Location' : 'Live Location',
            text: _pendingMessage!,
          );
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to send report: ${e.toString()}');
        setState(() {
          _isSubmitting = false;
          _isProcessing = false;
        });
        _messageController.text = _pendingMessage!;
      }
    } finally {
      if (mounted) {
        _pendingMessage = null;
        _selectedLocation = null;
      }
    }
  }

  void _startProcessingStages() async {
    for (int i = 0; i < _processingStages.length; i++) {
      if (!mounted || !_isProcessing) break;
      setState(() => _currentStageIndex = i);
      await Future.delayed(
          Duration(milliseconds: _processingStages[i].duration));
    }
  }

  // --- BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCubit, ChatState>(
      listener: (context, state) {
        if (state is ChatNewConversationStarted) {
          final newConversationId = state.firstMessage.conversationId;
          final auth = context.read<AuthCubit>();
          if (newConversationId != null && auth.isAuthenticated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ChatCubit>(),
                  child: ChatConversationScreen(
                    chatId: newConversationId,
                    currentUserId: auth.userId!,
                    chatTitle: 'Emergency Response',
                  ),
                ),
              ),
            );
          }
        } else if (state is ChatError) {
          if (mounted) {
            _showErrorMessage(state.message);
            setState(() {
              _isSubmitting = false;
              _isProcessing = false;
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Stack(
          children: [
            _buildMainContent(),
            if (_showConfirmDialog && !_showLocationSelector)
              _buildConfirmDialog(),
            if (_showLocationSelector) _buildLocationSelector(),
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
                  opacity: _fadeController,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: _slideController, curve: Curves.easeOut)),
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
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emergency, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency AI Assistant',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('24/7 Emergency Response',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
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
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Online',
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
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
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2)
              ],
            ),
            child: const Icon(Icons.smart_toy_outlined,
                size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text('How can I help you today?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
              'I\'m your AI emergency assistant. Describe your situation or choose a scenario below for a faster response.',
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPromptCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Common Emergencies',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._categories.map((category) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCategoryCard(category),
            )),
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
              offset: const Offset(0, 2))
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: category.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(category.icon, color: category.color, size: 24)),
        title: Text(category.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text('${category.prompts.length} quick options',
            style: const TextStyle(fontSize: 14, color: Colors.grey)),
        children: category.prompts
            .map((prompt) => _buildPromptTile(prompt, category.color))
            .toList(),
      ),
    );
  }

  Widget _buildPromptTile(String prompt, Color categoryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isSubmitting
              ? null
              : () => _handleSendMessage(promptText: prompt),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: categoryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(prompt,
                        style: TextStyle(
                            fontSize: 14,
                            color: categoryColor.withOpacity(0.9)))),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: categoryColor.withOpacity(0.5)),
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
              offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  enabled: !_isSubmitting,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _isRecording
                        ? 'Recording audio...'
                        : 'Or describe your emergency in detail...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.red.shade300)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
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
              color: _isRecording ? Colors.red.shade300 : Colors.grey.shade300),
        ),
        child: _isTranscribing
            ? const Padding(
                padding: EdgeInsets.all(14.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_isRecording ? Icons.stop : Icons.mic,
                color: _isRecording ? Colors.red : Colors.grey.shade600,
                size: 24),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _hasText && !_isSubmitting ? _handleSendMessage : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
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
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _countdownController,
                      builder: (context, child) => CircularProgressIndicator(
                          value: _countdownController.value,
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.red.shade400),
                          backgroundColor: Colors.red.shade100),
                    ),
                    Text('$_countdownSeconds',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Confirm Emergency Report',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_pendingMessage ?? '',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 16),
              // Location info with change option
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          _selectedLocation != null
                              ? 'Custom location selected'
                              : (_currentPosition != null
                                  ? 'Using current location'
                                  : 'Location not set'),
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue.shade700)),
                    ),
                    TextButton(
                        onPressed: _showLocationSelector1,
                        child: Text('Change',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: _cancelCountdown,
                          child: const Text('Cancel'))),
                  const SizedBox(width: 16),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: _confirmSendMessage,
                          child: const Text('Send Now'))),
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
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                        backgroundColor: Colors.blue.shade100),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Icon(currentStage.icon,
                        size: 36, color: Colors.blue.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(currentStage.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(currentStage.subtitle,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    _processingStages.length,
                    (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == _currentStageIndex ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: index <= _currentStageIndex
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4)),
                        )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FIXED & ENHANCED LOCATION SELECTOR ---
  Widget _buildLocationSelector() {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(children: [
                IconButton(
                    onPressed: _hideLocationSelector,
                    icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Emergency Location',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Tap on the map to set the precise location',
                            style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ]),
                )
              ]),
            ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLocation ??
                      (_currentPosition != null
                          ? LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude)
                          : const LatLng(33.49375, 36.32052)),
                  initialZoom: 16.0,
                  onTap: (tapPosition, point) {
                    _updateSelectedLocation(point);
                    HapticFeedback.selectionClick();
                  },
                ),
                children: [
                  TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 80,
                          height: 80,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.7, end: 1.0)
                                .animate(_markerPulseController),
                            child: Icon(Icons.location_on,
                                color: Colors.red.withOpacity(0.9), size: 60),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_currentPosition != null) {
                          _updateSelectedLocation(LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude));
                          HapticFeedback.selectionClick();
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use Current'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _selectedLocation != null
                          ? _hideLocationSelector
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm Location'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER METHODS ---
  void _updateSelectedLocation(LatLng location) {
    setState(() => _selectedLocation = location);
    _mapController.move(location, _mapController.camera.zoom);
    _markerPulseController.forward(from: 0);
  }

  void _showLocationSelector1() {
    _pauseCountdown();
    setState(() => _showLocationSelector = true);
  }

  void _hideLocationSelector() {
    setState(() => _showLocationSelector = false);
    _resumeCountdown();
  }

  void _pauseCountdown() {
    _countdownTimer?.cancel();
    _countdownController.stop();
  }

  void _resumeCountdown() {
    if (_countdownSeconds > 0) {
      _countdownController.forward(from: _countdownController.value);
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _countdownSeconds--);
        if (_countdownSeconds <= 0) {
          timer.cancel();
          _confirmSendMessage();
        }
      });
    }
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownController.reset();
    setState(() {
      _showConfirmDialog = false;
      _showLocationSelector = false;
      _pendingMessage = null;
      _selectedLocation = null;
      _countdownSeconds = 5;
    });
  }

  Future<void> _toggleRecording() async {
    if (!_isRecorderReady) return;
    if (_isRecording) {
      await _stopRecordingAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.startRecorder(
          toFile: _pathToAudioFile, codec: Codec.pcm16WAV);
      setState(() => _isRecording = true);
    } catch (e) {
      _showErrorMessage("Could not start recording.");
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
      await _transcribeAudio();
    } catch (e) {
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
      final response = await request.send();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body);
        if (data['success'] == true && data['data']?['transcription'] != null) {
          _messageController.text = data['data']['transcription'];
        } else {
          throw Exception("API returned invalid data.");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorMessage("Speech-to-text failed.");
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
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

// --- DATA MODELS ---

class EmergencyPromptCategory {
  final String title;
  final IconData icon;
  final Color color;
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
