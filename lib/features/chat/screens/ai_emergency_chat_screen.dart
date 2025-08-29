import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';
import 'chat_conversation_screen.dart';

class AIEmergencyChatScreen extends StatefulWidget {
  const AIEmergencyChatScreen({super.key});

  @override
  State<AIEmergencyChatScreen> createState() => _AIEmergencyChatScreenState();
}

class _AIEmergencyChatScreenState extends State<AIEmergencyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_AIChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _reportClassified = false;
  bool _isSubmitting = false; // To prevent double submission
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _messages.add(
      _AIChatMessage(
        id: '1',
        type: _MessageType.ai,
        content:
            "🚨 Emergency AI Assistant activated. I'm here to help you report your emergency quickly and accurately. Please describe what's happening.",
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Permissions are likely handled on the dashboard, but we can check again.
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint("Failed to get location for AI chat: $e");
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() async {
    if (_messageController.text.trim().isEmpty || _isProcessing) return;
    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(_AIChatMessage(
          id: DateTime.now().toString(),
          type: _MessageType.user,
          content: userMessage,
          timestamp: DateTime.now()));
      _isProcessing = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _messages.add(_AIChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          type: _MessageType.ai,
          content:
              "Thank you. I've processed your report. To dispatch help to the right place, please confirm your current location.",
          timestamp: DateTime.now()));
      _reportClassified = true;
      _isProcessing = false;
    });
    _scrollToBottom();
  }

  Future<void> _handleLocationConfirm() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _messages.add(_AIChatMessage(
          id: DateTime.now().toString(),
          type: _MessageType.system,
          content:
              '📍 Location confirmed. Submitting your report to the emergency network...',
          timestamp: DateTime.now()));
    });
    _scrollToBottom();

    final auth = context.read<AuthCubit>();
    final token = auth.token;
    final firstMessage = _messages.firstWhere(
      (m) => m.type == _MessageType.user,
      orElse: () => _AIChatMessage(
          content: 'Emergency reported via AI',
          id: '',
          timestamp: DateTime.now(),
          type: _MessageType.system),
    );

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Authentication error.')));
      setState(() => _isSubmitting = false);
      return;
    }

    // Use live location if available, otherwise use default
    final lat = _currentPosition?.latitude ?? 33.49375;
    final lon = _currentPosition?.longitude ?? 36.32052;
    final address = _currentPosition != null
        ? 'Live Location'
        : 'ناحية الهمك'; // Geocoding could be added here

    await context.read<ChatCubit>().sendMessage(
          chatId: null, // This indicates a new conversation
          lat: lat,
          lon: lon,
          address: address,
          text: firstMessage.content,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCubit, ChatState>(
      listener: (context, state) {
        // When the new conversation is created, navigate to it
        if (state is ChatNewConversationStarted) {
          final newConversationId = state.firstMessage.conversationId;
          final auth = context.read<AuthCubit>();

          if (newConversationId != null && auth.isAuthenticated) {
            // Show a success message before navigating
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Emergency reported! Connecting you now...')));

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ChatCubit>(),
                  child: ChatConversationScreen(
                    chatId: newConversationId,
                    chatTitle: 'Emergency Chat',
                    currentUserId: auth.userId!,
                  ),
                ),
              ),
              (route) => route.isFirst, // Removes all previous routes
            );
          }
        } else if (state is ChatError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
          setState(() => _isSubmitting = false); // Re-enable button on error
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('AI Emergency Assistant')),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageWidget(message);
                },
              ),
            ),
            if (_isSubmitting) const LinearProgressIndicator(),
            if (_reportClassified && !_isSubmitting)
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Confirm Your Location',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _handleLocationConfirm,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Use Current Location & Submit'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                          hintText: 'Describe your emergency...'),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: _handleSendMessage,
                    icon: const Icon(Icons.send),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageWidget(_AIChatMessage message) {
    final isUser = message.type == _MessageType.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        color: isUser ? Colors.red : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message.content,
            style: TextStyle(color: isUser ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }
}

enum _MessageType { user, ai, system }

class _AIChatMessage {
  final String id;
  final _MessageType type;
  final String content;
  final DateTime timestamp;

  _AIChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
  });
}
