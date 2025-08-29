import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';

class ChatConversationScreen extends StatefulWidget {
  final int chatId;
  final String chatTitle;
  final int currentUserId;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.currentUserId,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Duration _pollInterval = const Duration(seconds: 8);
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (mounted) {
      await context.read<ChatCubit>().loadMessages(
            chatId: widget.chatId,
          );
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) => _loadMessages());
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final tempControllerValue = _controller.text;
    _controller.clear();

    // --- NEW: Get current location before sending ---
    Position? position;
    try {
      // You can add a loading indicator here if getting location is slow
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint("Could not get location for chat message: $e");
      // Silently fail or show a snackbar, but still send the message
    }
    // --- END NEW ---

    try {
      await context.read<ChatCubit>().sendMessage(
            chatId: widget.chatId,
            // Pass the location data, with fallbacks
            lat: position?.latitude ?? 0.0,
            lon: position?.longitude ?? 0.0,
            address: position != null ? 'Live Location' : '',
            text: text,
          );
      _scrollToBottom();
    } catch (e) {
      // If sending fails, restore the text
      _controller.text = tempControllerValue;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatTitle)),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<ChatCubit, ChatState>(
              listener: (context, state) {
                if (state is ChatMessagesLoaded &&
                    state.chatId == widget.chatId) {
                  _scrollToBottom();
                }
              },
              builder: (context, state) {
                if (state is ChatLoading &&
                    (state is! ChatMessagesLoaded ||
                        (state as ChatMessagesLoaded).messages.isEmpty)) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ChatError &&
                    (state is! ChatMessagesLoaded ||
                        (state as ChatMessagesLoaded).messages.isEmpty)) {
                  return Center(child: Text('Error: ${state.message}'));
                }

                if (state is ChatMessagesLoaded &&
                    state.chatId == widget.chatId) {
                  final messages = state.messages;
                  if (messages.isEmpty) {
                    return const Center(child: Text('No messages yet.'));
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isCurrentUser =
                          msg.sender?.user.id == widget.currentUserId;
                      return _MessageBubble(
                        message: msg,
                        isCurrentUser: isCurrentUser,
                      );
                    },
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final bool isCurrentUser;

  const _MessageBubble({required this.message, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isCurrentUser ? Colors.red : Colors.grey.shade200;
    final textColor = isCurrentUser ? Colors.white : Colors.black87;
    final borderRadius = isCurrentUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topLeft: Radius.circular(16),
          );

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Text(
                message.senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: textColor.withOpacity(0.8),
                ),
              ),
            const SizedBox(height: 2),
            Text(
              message.text,
              style: TextStyle(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
