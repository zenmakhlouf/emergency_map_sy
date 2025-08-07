import 'package:flutter/material.dart';
import '../models/user_type.dart';

class EmergencyChatScreen extends StatefulWidget {
  final String incidentTitle;
  final UserType userType;

  const EmergencyChatScreen({
    super.key,
    required this.incidentTitle,
    required this.userType,
  });

  @override
  State<EmergencyChatScreen> createState() => _EmergencyChatScreenState();
}

class _EmergencyChatScreenState extends State<EmergencyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeMessages() {
    _messages.addAll([
      ChatMessage(
        id: '1',
        type: MessageType.system,
        content: 'Emergency responders have been notified and are en route.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        sender: 'System',
      ),
      ChatMessage(
        id: '2',
        type: MessageType.responder,
        content: 'This is Officer Johnson. We are 3 minutes away. Can you confirm the situation?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        sender: 'Officer Johnson',
      ),
      ChatMessage(
        id: '3',
        type: MessageType.citizen,
        content: 'Yes, there\'s smoke coming from the building. I can see flames on the second floor.',
        timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
        sender: 'You',
      ),
    ]);
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

  void _handleSendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().toString(),
          type: widget.userType == UserType.citizen 
              ? MessageType.citizen 
              : MessageType.responder,
          content: message,
          timestamp: DateTime.now(),
          sender: widget.userType == UserType.citizen ? 'You' : 'You',
        ),
      );
    });

    _scrollToBottom();

    // Simulate response from responder
    if (widget.userType == UserType.citizen) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
                type: MessageType.responder,
                content: 'Understood. Fire department is also on the way. Please stay at a safe distance.',
                timestamp: DateTime.now(),
                sender: 'Officer Johnson',
              ),
            );
          });
          _scrollToBottom();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.incidentTitle),
            Text(
              'Active Chat',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Messages
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

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
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
    );
  }

  Widget _buildMessageWidget(ChatMessage message) {
    final isUser = message.type == MessageType.citizen && widget.userType == UserType.citizen ||
                   message.type == MessageType.responder && widget.userType == UserType.responder;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: _getMessageColor(message.type, isUser),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getMessageIcon(message.type),
                      size: 16,
                      color: _getMessageIconColor(message.type, isUser),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.sender,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getMessageTextColor(message.type, isUser),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.content,
                  style: TextStyle(
                    color: _getMessageTextColor(message.type, isUser),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getMessageTimeColor(message.type, isUser),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getMessageColor(MessageType type, bool isUser) {
    switch (type) {
      case MessageType.citizen:
        return isUser ? Colors.red : Colors.grey.shade100;
      case MessageType.responder:
        return isUser ? Colors.blue : Colors.blue.shade50;
      case MessageType.system:
        return Colors.green.shade50;
    }
  }

  IconData _getMessageIcon(MessageType type) {
    switch (type) {
      case MessageType.citizen:
        return Icons.person;
      case MessageType.responder:
        return Icons.security;
      case MessageType.system:
        return Icons.info;
    }
  }

  Color _getMessageIconColor(MessageType type, bool isUser) {
    switch (type) {
      case MessageType.citizen:
        return isUser ? Colors.white : Colors.grey;
      case MessageType.responder:
        return isUser ? Colors.white : Colors.blue;
      case MessageType.system:
        return Colors.green;
    }
  }

  Color _getMessageTextColor(MessageType type, bool isUser) {
    switch (type) {
      case MessageType.citizen:
        return isUser ? Colors.white : Colors.black;
      case MessageType.responder:
        return isUser ? Colors.white : Colors.black;
      case MessageType.system:
        return Colors.green.shade800;
    }
  }

  Color _getMessageTimeColor(MessageType type, bool isUser) {
    switch (type) {
      case MessageType.citizen:
        return isUser ? Colors.white70 : Colors.grey;
      case MessageType.responder:
        return isUser ? Colors.white70 : Colors.grey;
      case MessageType.system:
        return Colors.green.shade600;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

enum MessageType { citizen, responder, system }

class ChatMessage {
  final String id;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final String sender;

  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    required this.sender,
  });
} 