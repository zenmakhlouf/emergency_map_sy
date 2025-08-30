import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

// Local imports from your project structure
import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';

// A unique identifier generator for pending messages
const uuid = Uuid();

/// Represents the state of a message being sent.
enum MessageStatus { pending, sent, failed }

/// A local message model that includes a sending status for optimistic UI.
class PendingMessage {
  final ChatMessageEntity message;
  final MessageStatus status;

  PendingMessage({required this.message, this.status = MessageStatus.pending});

  PendingMessage copyWith({MessageStatus? status}) {
    return PendingMessage(
      message: message,
      status: status ?? this.status,
    );
  }
}

/// An enterprise-grade, real-time chat screen for critical emergency communications.
/// Features a complete UI/UX overhaul, role-specific participant styling, optimistic
/// message sending, and enhanced reliability mechanisms.
class ChatConversationScreen extends StatefulWidget {
  final int chatId;
  final String chatTitle;
  final int currentUserId;
  final List<ChatParticipant> participants;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.currentUserId,
    this.participants = const [],
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // --- STATE & CONTROLLERS ---
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _sendButtonAnimationController;

  // --- NETWORKING & POLLING ---
  Timer? _messagePoller;
  List<ChatMessageEntity> _confirmedMessages = [];
  Map<int, PendingMessage> _pendingMessages = {};
  List<ChatParticipant> _filteredParticipants = [];
  DateTime? _lastSuccessfulRefresh;

  // --- UI & UX STATE ---
  bool _isInitializing = true;
  bool _isRefreshing = false;
  bool _hasText = false;
  String? _networkError;

  // --- SPEECH-TO-TEXT (STT) STATE ---
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderReady = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _pathToAudioFile;

  // --- CONFIGURATION ---
  static const Duration _pollInterval = Duration(seconds: 5);
  static const Duration _networkTimeout = Duration(seconds: 15);
  static const Duration _locationTimeout = Duration(seconds: 7);
  static const String _sttApiUrl =
      "https://help-map.saadalabyad.com/api/v1/ai/test-speech-to-text";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Filter out "ghost" participants from the backend immediately.
    _filteredParticipants = widget.participants
        .where((p) => p.user.name.isNotEmpty && p.user.name != 'Unknown User')
        .toList();

    _initializeAnimations();
    _setupTextFieldListener();
    _initializeChat();
    _initializeRecorder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _loadMessages(showError: false);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopPolling();
    }
  }

  // ============================================================================
  // INITIALIZATION & SETUP
  // ============================================================================

  void _initializeAnimations() {
    _sendButtonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  void _setupTextFieldListener() {
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() => _hasText = hasText);
        if (hasText)
          _sendButtonAnimationController.forward();
        else
          _sendButtonAnimationController.reverse();
      }
    });
  }

  Future<void> _initializeChat() async {
    await _loadMessages(showError: false);
    if (mounted) setState(() => _isInitializing = false);
    _startPolling();
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();

      final tempDir = await getTemporaryDirectory();
      final isIOS = Platform.isIOS;

      // Use a container iOS actually supports
      final ext = 'wav';
      _pathToAudioFile = p.join(tempDir.path, 'emergency_record.$ext');

      await _recorder
          .setSubscriptionDuration(const Duration(milliseconds: 500));
      setState(() => _isRecorderReady = true);
    } catch (e, st) {
      debugPrint("Recorder initialization failed: $e\n$st");
      _showErrorMessage("Microphone access is required for voice messages.");
    }
  }

  // ============================================================================
  // MESSAGE DATA HANDLING (POLLING & STATE)
  // ============================================================================

  Future<void> _loadMessages({bool showError = true}) async {
    if (!mounted) return;
    try {
      await context
          .read<ChatCubit>()
          .loadMessages(chatId: widget.chatId)
          .timeout(_networkTimeout);
      if (mounted) {
        setState(() {
          _networkError = null;
          _lastSuccessfulRefresh = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint("Failed to load messages: $e");
      if (mounted && showError) {
        setState(() => _networkError = "Connection unstable");
      }
    }
  }

  void _handleChatStateChange(BuildContext context, ChatState state) {
    if (!mounted) return;

    if (state is ChatMessagesLoaded && state.chatId == widget.chatId) {
      setState(() {
        _confirmedMessages = state.messages;
        _networkError = null;
        _lastSuccessfulRefresh = DateTime.now();

        // Reconcile pending messages: remove any that have now been confirmed by the server.
        final confirmedIds = _confirmedMessages.map((m) => m.id).toSet();
        _pendingMessages.removeWhere((key, pending) {
          // This is a simple reconciliation. A more robust way would be matching a unique ID.
          // For now, we assume if a message with the same text from the user appears, it's ours.
          final isConfirmed = _confirmedMessages.any((confirmed) =>
              confirmed.sender?.user.id == widget.currentUserId &&
              confirmed.text == pending.message.text);
          return isConfirmed;
        });
      });
      _scrollToBottom(isNewMessage: true);
    } else if (state is ChatError) {
      setState(() => _networkError = state.message ?? "An error occurred");
    }
  }

  Future<void> _handleManualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _loadMessages();
      _showSuccessMessage("Chat updated");
    } catch (e) {
      _showErrorMessage("Failed to refresh");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _startPolling() {
    _stopPolling();
    _messagePoller =
        Timer.periodic(_pollInterval, (_) => _loadMessages(showError: false));
  }

  void _stopPolling() => _messagePoller?.cancel();

  // ============================================================================
  // MESSAGE SENDING & STT
  // ============================================================================

  Future<void> _sendMessage({String? textOverride}) async {
    final text = textOverride ?? _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();

    // --- OPTIMISTIC UI ---
    // 1. Create a temporary message with a unique local ID.
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final pending = PendingMessage(
      message: ChatMessageEntity(
        id: tempId,
        text: text,
        createdAt: DateTime.now().toIso8601String(),
        sender: _getSelfParticipant(),
        conversationId: widget.chatId,
      ),
    );

    // 2. Add it to the local state to display it immediately.
    setState(() {
      _pendingMessages[tempId] = pending;
    });
    _scrollToBottom(isNewMessage: true);

    // 3. Attempt to send the message to the server.
    try {
      Position? position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _locationTimeout,
      );
      await context
          .read<ChatCubit>()
          .sendMessage(
            chatId: widget.chatId,
            text: text,
            lat: position.latitude,
            lon: position.longitude,
            address: "Location",
          )
          .timeout(_networkTimeout);
      // On success, the next poll will pick it up and reconcile the state.
    } catch (e) {
      // 4. If sending fails, update the message state to 'failed'.
      debugPrint("Send message error: $e");
      setState(() {
        _pendingMessages[tempId] =
            pending.copyWith(status: MessageStatus.failed);
      });
    }
  }

  // ============================================================================
  // RECORDING & TRANSCRIPTION
  // ============================================================================

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
        // (optional) sampleRate/bitRate if you need them
      );
      setState(() => _isRecording = true);
    } catch (e, st) {
      debugPrint("startRecorder failed (primary codec): $e\n$st");

      // 🔁 Fallback to AAC to force a clean permission path & confirm it’s not a codec issue
      try {
        final dir = await getTemporaryDirectory();
        _pathToAudioFile = p.join(dir.path, 'emergency_record.aac');
        await _recorder.startRecorder(
          toFile: _pathToAudioFile,
          codec: Codec.aacADTS,
        );
        setState(() => _isRecording = true);
        _showSuccessMessage(
            "Using AAC fallback (Opus container unsupported on this platform).");
      } catch (e2, st2) {
        debugPrint("Fallback AAC startRecorder failed: $e2\n$st2");
        if (Platform.isIOS) {
          _showErrorMessage(
              "Could not access the microphone. If you previously denied it, enable it in Settings → Privacy → Microphone → (Your App), or reinstall the app.");
        } else {
          _showErrorMessage("Could not start recording.");
        }
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
      //final respStr = await response.stream.bytesToString();

      print("Status code: ${response.statusCode}");
      // print("Response body: $respStr");
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body);
        if (data['success'] == true && data['data']?['transcription'] != null) {
          final transcription = data['data']['transcription'] as String;
          // Send the transcribed text as a message
          //_sendMessage(textOverride: transcription);

          _messageController.text = transcription;
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

  // ============================================================================
  // BUILD METHODS: Main Scaffold & AppBar
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          //_buildHighPriorityHeader(),
          Expanded(child: _buildMessagesSection()),
          _buildMessageInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.chatTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      centerTitle: true,
    );
  }

  Widget _buildHighPriorityHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFFEF3F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200)),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("High Priority Emergency",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900)),
                  Text("Response time: 2 min • 123 Main St",
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("ACTIVE",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // BUILD METHODS: Message Display
  // ============================================================================

  Widget _buildMessagesSection() {
    return BlocConsumer<ChatCubit, ChatState>(
      listener: _handleChatStateChange,
      builder: (context, state) {
        if (_isInitializing && _confirmedMessages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final allMessages = [
          ..._confirmedMessages,
          ..._pendingMessages.values.map((p) => p.message)
        ];
        // Sort by date to ensure proper order
        allMessages.sort((a, b) => DateTime.parse(a.createdAt!)
            .compareTo(DateTime.parse(b.createdAt!)));

        if (allMessages.isEmpty) return _buildEmptyState();

        return RefreshIndicator(
          onRefresh: _handleManualRefresh,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: allMessages.length,
            itemBuilder: (context, index) {
              final message = allMessages[index];
              final participant = _findParticipant(message.sender?.user.id);
              final status = _pendingMessages[message.id]?.status;

              final previousMessage = index > 0 ? allMessages[index - 1] : null;
              final showHeader = _shouldShowHeader(message, previousMessage);
              final isCurrentUser =
                  message.sender?.user.id == widget.currentUserId;

              return _MessageBubble(
                key: ValueKey(message.id),
                message: message,
                participant: participant,
                isCurrentUser: isCurrentUser,
                showHeader: showHeader,
                status: status,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child:
          Text("Start the conversation.", style: TextStyle(color: Colors.grey)),
    );
  }

  // ============================================================================
  // BUILD METHODS: Message Input Bar
  // ============================================================================

  Widget _buildMessageInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border:
            Border(top: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _buildTextInputField()),
                  const SizedBox(width: 8),
                  _buildSendOrRecordButton(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Emergency chat is monitored 24/7",
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600])),
                    Row(
                      children: [
                        Icon(Icons.circle,
                            size: 8,
                            color: _networkError == null
                                ? Colors.green
                                : Colors.orange),
                        const SizedBox(width: 4),
                        Text("Active",
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputField() {
    return TextField(
      controller: _messageController,
      focusNode: _focusNode,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _sendMessage(),
      decoration: InputDecoration(
        hintText: _isRecording ? 'Recording audio...' : 'Type your message...',
        fillColor: const Color(0xFFF8F9FA),
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildSendOrRecordButton() {
    final showSendButton = _hasText && !_isRecording;
    return GestureDetector(
      onTap: showSendButton ? _sendMessage : _toggleRecording,
      child: CircleAvatar(
        radius: 24,
        backgroundColor:
            showSendButton ? Colors.red.shade600 : Colors.grey.shade200,
        child: _isTranscribing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                showSendButton ? Icons.send : Icons.mic,
                color: showSendButton
                    ? Colors.white
                    : (_isRecording ? Colors.red.shade600 : Colors.black54),
                size: 24,
              ),
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  ChatParticipant _findParticipant(int? userId) {
    if (userId == null)
      return const ChatParticipant(
          id: -1, user: ChatUser(id: -1, name: 'Unknown'));
    return _filteredParticipants.firstWhere(
      (p) => p.user.id == userId,
      orElse: () {
        // Fallback for cases where participant list might be stale
        final confirmedSender = _confirmedMessages
            .firstWhere((m) => m.sender?.user.id == userId,
                orElse: () => const ChatMessageEntity(id: -1))
            .sender;
        return confirmedSender ??
            const ChatParticipant(
                id: -1, user: ChatUser(id: -1, name: 'Unknown'));
      },
    );
  }

  ChatParticipant _getSelfParticipant() {
    return widget.participants.firstWhere(
      (p) => p.user.id == widget.currentUserId,
      orElse: () => ChatParticipant(
          id: -1, user: ChatUser(id: widget.currentUserId, name: 'You')),
    );
  }

  bool _shouldShowHeader(
      ChatMessageEntity current, ChatMessageEntity? previous) {
    if (previous == null) return true;
    if (current.sender?.user.id != previous.sender?.user.id) return true;
    final currentTime = DateTime.tryParse(current.createdAt ?? '');
    final prevTime = DateTime.tryParse(previous.createdAt ?? '');
    if (currentTime == null || prevTime == null) return true;
    return currentTime.difference(prevTime).inMinutes >= 3;
  }

  void _scrollToBottom({bool isNewMessage = false}) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      // Only auto-scroll if user is near the bottom, unless it's their own new message
      if (position.maxScrollExtent - position.pixels < 100 || isNewMessage) {
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorMessage(String message) {
    if (!mounted || !ScaffoldMessenger.of(context).mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ));
  }

  void _showSuccessMessage(String message) {
    if (!mounted || !ScaffoldMessenger.of(context).mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
      ));
  }

  void _cleanup() {
    _stopPolling();
    _recorder.closeRecorder();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendButtonAnimationController.dispose();
  }
}

// ============================================================================
// WIDGET: Message Bubble & Avatar
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final ChatParticipant participant;
  final bool isCurrentUser;
  final bool showHeader;
  final MessageStatus? status;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.participant,
    required this.isCurrentUser,
    required this.showHeader,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final participantType = participant.type?.toLowerCase() ?? 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) _UserAvatar(participant: participant),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showHeader && !isCurrentUser)
                  _buildSenderHeader(participantType),
                _buildMessageContent(context),
                _buildMessageFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderHeader(String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
      child: Text(
        participant.user.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _getColorForType(type).shade900,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final bubbleColor = isCurrentUser ? Colors.red.shade600 : Colors.white;
    final textColor = isCurrentUser ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border:
              isCurrentUser ? null : Border.all(color: Colors.grey.shade300)),
      child: Text(message.text,
          style: TextStyle(color: textColor, fontSize: 16, height: 1.4)),
    );
  }

  Widget _buildMessageFooter() {
    final createdAt = DateTime.tryParse(message.createdAt ?? '')?.toLocal();
    if (createdAt == null) return const SizedBox.shrink();

    String hour =
        (createdAt.hour % 12 == 0 ? 12 : createdAt.hour % 12).toString();
    String minute = createdAt.minute.toString().padLeft(2, '0');
    final timeString = '$hour:$minute';

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(timeString,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          if (isCurrentUser && status != null) ...[
            const SizedBox(width: 4),
            Icon(
              status == MessageStatus.pending
                  ? Icons.access_time_rounded
                  : Icons.error_outline,
              size: 12,
              color: status == MessageStatus.pending
                  ? Colors.grey.shade500
                  : Colors.red.shade400,
            ),
          ],
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final ChatParticipant participant;
  const _UserAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final name = participant.user.name.toLowerCase();
    final type = participant.type?.toLowerCase() ?? 'user';

    // Default to a user icon
    IconData iconData = Icons.person;
    Color color = _getColorForType(type);

    if (name.contains('ai') || name.contains('assistant')) {
      iconData = Icons.smart_toy_outlined;
      color = Colors.blueGrey;
    } else if (type.contains('police')) {
      iconData = Icons.local_police;
    } else if (type.contains('fire')) {
      iconData = Icons.local_fire_department;
    } else if (type.contains('medical')) {
      iconData = Icons.medical_services;
    } else if (type.contains('traffic')) {
      iconData = Icons.traffic;
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Icon(iconData, color: Colors.white, size: 22),
    );
  }
}

// Helper function to assign consistent colors to responder types
MaterialColor _getColorForType(String type) {
  switch (type) {
    case 'police':
      return Colors.blue;
    case 'fire_department':
    case 'fire':
      return Colors.orange;
    case 'medical':
      return Colors.green;
    case 'traffic':
      return Colors.purple;
    case 'civil_defense':
      return Colors.cyan;
    default:
      return Colors.grey;
  }
}
