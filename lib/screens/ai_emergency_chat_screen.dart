import 'package:flutter/material.dart';
import '../features/auth/models/user_type.dart';
import 'emergency_chat_screen.dart';
import 'emergency_report_form_screen.dart';

class AIEmergencyChatScreen extends StatefulWidget {
  const AIEmergencyChatScreen({super.key});

  @override
  State<AIEmergencyChatScreen> createState() => _AIEmergencyChatScreenState();
}

class _AIEmergencyChatScreenState extends State<AIEmergencyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _reportClassified = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        id: '1',
        type: MessageType.ai,
        content:
            "🚨 Emergency AI Assistant activated. I'm here to help you report your emergency quickly and accurately. Please describe what's happening in your own words - I'll handle the details.",
        timestamp: DateTime.now(),
      ),
    );
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

  Map<String, dynamic> _simulateAIClassification(String userMessage) {
    // Simulate AI classification based on keywords
    String category = 'general';
    String subcategory = 'other';
    String severity = 'medium';

    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('fire') ||
        lowerMessage.contains('smoke') ||
        lowerMessage.contains('burning')) {
      category = 'fire';
      subcategory = 'building_fire';
      severity = lowerMessage.contains('apartment') ||
              lowerMessage.contains('building')
          ? 'high'
          : 'medium';
    } else if (lowerMessage.contains('accident') ||
        lowerMessage.contains('crash') ||
        lowerMessage.contains('collision')) {
      category = 'traffic';
      subcategory = 'vehicle_accident';
      severity = lowerMessage.contains('injured') ? 'high' : 'medium';
    } else if (lowerMessage.contains('heart') ||
        lowerMessage.contains('chest') ||
        lowerMessage.contains('breathing')) {
      category = 'medical';
      subcategory = 'cardiac_emergency';
      severity = 'critical';
    } else if (lowerMessage.contains('robbery') ||
        lowerMessage.contains('theft') ||
        lowerMessage.contains('stolen')) {
      category = 'crime';
      subcategory = 'theft';
      severity = 'medium';
    }

    return {
      'category': category,
      'subcategory': subcategory,
      'severity': severity,
      'confidence': 0.7 +
          (DateTime.now().millisecondsSinceEpoch % 300) /
              1000, // 70-100% confidence
    };
  }

  void _handleSendMessage() async {
    if (_messageController.text.trim().isEmpty || _isProcessing) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    // Add user message
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().toString(),
          type: MessageType.user,
          content: userMessage,
          timestamp: DateTime.now(),
        ),
      );
      _isProcessing = true;
    });

    _scrollToBottom();

    // Simulate AI processing delay
    await Future.delayed(const Duration(milliseconds: 1500));

    // Simulate AI classification
    final classification = _simulateAIClassification(userMessage);

    String aiResponse =
        "I've classified this as a ${classification['category'].toUpperCase()} emergency (${(classification['confidence'] * 100).round()}% confidence). ";

    if (classification['severity'] == 'critical') {
      aiResponse +=
          "🚨 This appears to be CRITICAL - dispatching immediate response!";
    } else if (classification['severity'] == 'high') {
      aiResponse +=
          "⚠️ High priority incident detected - emergency services notified.";
    } else {
      aiResponse += "Emergency services have been notified.";
    }

    aiResponse +=
        "\n\nCan you provide your exact location? I'm detecting you may be near your registered address.";

    setState(() {
      _messages.add(
        ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          type: MessageType.ai,
          content: aiResponse,
          timestamp: DateTime.now(),
          classification: classification,
        ),
      );
      _reportClassified = true;
      _isProcessing = false;
    });

    _scrollToBottom();
  }

  void _handleLocationConfirm() async {
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().toString(),
          type: MessageType.system,
          content:
              '📍 Location confirmed: 123 Main Street, Downtown. Emergency responders have been notified and are en route.',
          timestamp: DateTime.now(),
        ),
      );
    });

    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      _messages.add(
        ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          type: MessageType.ai,
          content:
              '✅ Your emergency report has been successfully submitted and classified. You\'ll now be connected to the incident chat where you can communicate with responders. Stay safe!',
          timestamp: DateTime.now(),
        ),
      );
    });

    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 2000));

    if (mounted) {
      final lastClassification = _messages
          .where((m) => m.classification != null)
          .lastOrNull
          ?.classification;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyChatScreen(
            incidentTitle: lastClassification != null
                ? '${lastClassification['category'].toUpperCase()} Emergency'
                : 'Emergency Report',
            userType: UserType.citizen,
          ),
        ),
      );
    }
  }

  void _switchToManualForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyReportFormScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency AI Assistant'),
            Text(
              'Active',
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
          TextButton(
            onPressed: _switchToManualForm,
            child: const Text(
              'Manual Form',
              style: TextStyle(color: Colors.white),
            ),
          ),
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

          // Location confirmation card
          if (_reportClassified)
            Card(
              margin: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.warning, color: Colors.blue, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Confirm Your Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'To complete your emergency report, please confirm your location',
                      style: TextStyle(fontSize: 14, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleLocationConfirm,
                        icon: const Icon(Icons.location_on),
                        label: const Text('Confirm Location: 123 Main Street'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
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
                      hintText: 'Describe your emergency...',
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
    final isUser = message.type == MessageType.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: isUser ? Colors.red : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      message.type == MessageType.ai
                          ? Icons.smart_toy
                          : message.type == MessageType.system
                              ? Icons.check_circle
                              : Icons.person,
                      size: 16,
                      color: isUser ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.type == MessageType.ai
                          ? 'AI Assistant'
                          : message.type == MessageType.system
                              ? 'System'
                              : 'You',
                      style: TextStyle(
                        fontSize: 12,
                        color: isUser ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.content,
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.black,
                  ),
                ),
                if (message.classification != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      Chip(
                        label: Text(
                          message.classification!['category']
                              .toString()
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                      Chip(
                        label: Text(
                          message.classification!['severity']
                              .toString()
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

enum MessageType { user, ai, system }

class ChatMessage {
  final String id;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? classification;

  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.classification,
  });
}
