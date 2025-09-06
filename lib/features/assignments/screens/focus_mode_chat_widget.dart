import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

import '../../chat/cubit/chat_cubit.dart';
import '../../chat/models/chat_models.dart';

class FocusModeChatWidget extends StatefulWidget {
  final int conversationId;
  final String chatTitle;
  final int currentUserId;

  const FocusModeChatWidget({
    super.key,
    required this.conversationId,
    required this.chatTitle,
    required this.currentUserId,
  });

  @override
  State<FocusModeChatWidget> createState() => _FocusModeChatWidgetState();
}

class _FocusModeChatWidgetState extends State<FocusModeChatWidget>
    with SingleTickerProviderStateMixin {
  
  final DraggableScrollableController _dragController = DraggableScrollableController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  final FocusNode _messageInputFocus = FocusNode();
  
  List<ChatMessageEntity> _messages = [];
  final bool _isExpanded = false;
  bool _isLoading = true;
  Timer? _messagePoller;
  
  // Speech-to-text variables - copied from working chat_conversation_screen.dart
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderReady = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _pathToAudioFile;
  
  // STT API URL - using the working URL from chat_conversation_screen.dart
  static const String _sttApiUrl = "https://help-map.saadalabyad.com/api/v1/ai/test-speech-to-text";

  // Quick reply options in Arabic
  final List<QuickReply> _quickReplies = [
    QuickReply(text: 'في الطريق 🚗', icon: Icons.directions_car),
    QuickReply(text: '2 دقيقتين ⏱️', icon: Icons.timer),
    QuickReply(text: 'وصلت 📍', icon: Icons.location_on),
    QuickReply(text: 'احتاج دعم 🆘', icon: Icons.support_agent),
    QuickReply(text: 'بدأت الاستجابة ⚡', icon: Icons.flash_on),
    QuickReply(text: 'تحت السيطرة ✅', icon: Icons.check_circle),
  ];

  @override
  void initState() {
    super.initState();
    
    debugPrint('🎯 [FOCUS_CHAT] ========== INITIALIZING FOCUS CHAT ==========');
    debugPrint('🎯 [FOCUS_CHAT] Conversation ID: ${widget.conversationId}');
    debugPrint('🎯 [FOCUS_CHAT] Chat Title: ${widget.chatTitle}');
    debugPrint('🎯 [FOCUS_CHAT] Current User ID: ${widget.currentUserId}');
    debugPrint('🎯 [FOCUS_CHAT] STT API URL: $_sttApiUrl');
    
    // Add listener to track drag state
    _dragController.addListener(_onDragChange);
    
    // Add listener to track text changes for send button animation
    _messageController.addListener(() {
      setState(() {}); // Trigger rebuild for send button animation
    });
    
    _initializeChat();
    _startMessagePolling();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _messagePoller?.cancel();
    _messageController.dispose();
    _messagesScrollController.dispose();
    _messageInputFocus.dispose();
    _dragController.removeListener(_onDragChange);
    _dragController.dispose();
    
    // Clean up recorder - copied from working implementation
    if (_isRecorderReady) {
      debugPrint('🎯 [FOCUS_CHAT] 🎙️ Disposing recorder...');
      _recorder.closeRecorder();
    }
    
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      debugPrint('🎯 [FOCUS_CHAT] Loading messages for chat ${widget.conversationId}...');
      await context.read<ChatCubit>().loadMessages(chatId: widget.conversationId);
      debugPrint('🎯 [FOCUS_CHAT] ✅ Messages loaded successfully');
    } catch (e, stackTrace) {
      debugPrint('🚨 [FOCUS_CHAT] Error loading chat: $e');
      debugPrint('🚨 [FOCUS_CHAT] Chat loading stack trace: $stackTrace');
    }
    setState(() => _isLoading = false);
    debugPrint('🎯 [FOCUS_CHAT] Loading flag set to false');
  }

  void _startMessagePolling() {
    _messagePoller = Timer.periodic(const Duration(seconds: 3), (_) {
      context.read<ChatCubit>().loadMessages(chatId: widget.conversationId);
    });
  }

  void _onDragChange() {
    final currentSize = _dragController.size;
    debugPrint('🎯 [FOCUS_CHAT] Drag size changed: ${(currentSize * 100).round()}%');
    
    // Auto-scroll to bottom when expanding
    if (currentSize > 0.6 && _messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }
  }

  void _handleChatStateChange(ChatState state) {
    debugPrint('🎯 [FOCUS_CHAT] Chat state change: ${state.runtimeType}');
    
    if (state is ChatMessagesLoaded && state.chatId == widget.conversationId) {
      debugPrint('🎯 [FOCUS_CHAT] Messages loaded for chat ${state.chatId}');
      debugPrint('🎯 [FOCUS_CHAT] Message count: ${state.messages.length}');
      
      setState(() {
        _messages = state.messages;
      });
      _scrollToBottom();
      debugPrint('🎯 [FOCUS_CHAT] ✅ Messages state updated and scrolled to bottom');
    } else if (state is ChatError) {
      debugPrint('🚨 [FOCUS_CHAT] Chat error: ${state.message}');
    } else if (state is ChatMessagesLoaded) {
      debugPrint('🎯 [FOCUS_CHAT] Messages loaded for different chat: ${state.chatId} (expected: ${widget.conversationId})');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messagesScrollController.hasClients) {
        _messagesScrollController.animateTo(
          _messagesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) {
      debugPrint('🎯 [FOCUS_CHAT] ⚠️ Attempted to send empty message');
      return;
    }

    debugPrint('🎯 [FOCUS_CHAT] 📤 Sending message: "${text.length > 50 ? "${text.substring(0, 50)}..." : text}"');
    _messageController.clear();
    
    // Dismiss keyboard after sending
    _messageInputFocus.unfocus();
    debugPrint('🎯 [FOCUS_CHAT] ⌨️ Keyboard dismissed after sending message');

    try {
      debugPrint('🎯 [FOCUS_CHAT] 📍 Getting current location for message...');
      // Get current location for the message
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      debugPrint('🎯 [FOCUS_CHAT] 📍 Location obtained: ${position.latitude}, ${position.longitude}');
      debugPrint('🎯 [FOCUS_CHAT] 📤 Sending message with location to ChatCubit...');

      await context.read<ChatCubit>().sendMessageToConversation(
        chatId: widget.conversationId,
        text: text,
        lat: position.latitude,
        lon: position.longitude,
        address: "Current Location",
      );
      
      debugPrint('🎯 [FOCUS_CHAT] ✅ Message sent successfully with location');
    } catch (e) {
      debugPrint('🚨 [FOCUS_CHAT] GPS failed, sending with default location: $e');
      
      try {
        // Send with default location if GPS fails
        await context.read<ChatCubit>().sendMessageToConversation(
          chatId: widget.conversationId,
          text: text,
          lat: 33.5138, // Damascus default
          lon: 36.2765,
          address: "Location not available",
        );
        debugPrint('🎯 [FOCUS_CHAT] ✅ Message sent successfully with default location');
      } catch (e2) {
        debugPrint('🚨 [FOCUS_CHAT] Failed to send message: $e2');
      }
    }
  }

  // ============================================================================
  // SPEECH-TO-TEXT IMPLEMENTATION - COPIED FROM WORKING chat_conversation_screen.dart
  // ============================================================================

  Future<void> _initializeRecorder() async {
    try {
      debugPrint('🎯 [FOCUS_CHAT] 🎙️ Initializing speech recorder...');
      await _recorder.openRecorder();

      final tempDir = await getTemporaryDirectory();

      // Use a container iOS actually supports
      const ext = 'wav';
      _pathToAudioFile = p.join(tempDir.path, 'focus_chat_record.$ext');

      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
      setState(() => _isRecorderReady = true);
      debugPrint('🎯 [FOCUS_CHAT] ✅ Speech recorder initialized successfully');
    } catch (e, st) {
      debugPrint('🚨 [FOCUS_CHAT] 🎙️ Recorder initialization failed: $e\n$st');
      setState(() => _isRecorderReady = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isRecorderReady) {
      debugPrint('🚨 [FOCUS_CHAT] 🎙️ Recorder not ready');
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
      debugPrint('🎯 [FOCUS_CHAT] 🎙️ Starting voice recording...');
      const codec = Codec.pcm16WAV;
      await _recorder.startRecorder(
        toFile: _pathToAudioFile,
        codec: codec,
      );
      setState(() => _isRecording = true);
      debugPrint('🎯 [FOCUS_CHAT] ✅ Voice recording started');
    } catch (e, st) {
      debugPrint('🚨 [FOCUS_CHAT] 🎙️ startRecorder failed (primary codec): $e\n$st');

      // Fallback to AAC
      try {
        final dir = await getTemporaryDirectory();
        _pathToAudioFile = p.join(dir.path, 'focus_chat_record.aac');
        await _recorder.startRecorder(
          toFile: _pathToAudioFile,
          codec: Codec.aacADTS,
        );
        setState(() => _isRecording = true);
        debugPrint('🎯 [FOCUS_CHAT] ✅ Using AAC fallback recording started');
      } catch (e2, st2) {
        debugPrint('🚨 [FOCUS_CHAT] 🎙️ Fallback AAC startRecorder failed: $e2\n$st2');
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    try {
      debugPrint('🎯 [FOCUS_CHAT] 🎙️ Stopping recording and starting transcription...');
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
      await _transcribeAndSend();
    } catch (e) {
      debugPrint('🚨 [FOCUS_CHAT] 🎙️ Error stopping recorder: $e');
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
    }
  }

  Future<void> _transcribeAndSend() async {
    if (_pathToAudioFile == null || !File(_pathToAudioFile!).existsSync()) {
      debugPrint('🚨 [FOCUS_CHAT] 🎙️ Audio file not found at: $_pathToAudioFile');
      setState(() => _isTranscribing = false);
      return;
    }
    
    try {
      debugPrint('🎯 [FOCUS_CHAT] 🎙️ Transcribing audio file...');
      final request = http.MultipartRequest('POST', Uri.parse(_sttApiUrl))
        ..files.add(await http.MultipartFile.fromPath('audio_file', _pathToAudioFile!));
      
      final response = await request.send().timeout(const Duration(seconds: 20));
      debugPrint('🎯 [FOCUS_CHAT] 🎙️ STT API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body);
        
        if (data['success'] == true && data['data']?['transcription'] != null) {
          final transcription = data['data']['transcription'] as String;
          debugPrint('🎯 [FOCUS_CHAT] ✅ Transcription successful: "$transcription"');
          
          // Auto-send the transcribed text
          setState(() => _isTranscribing = false);
          await _sendMessage(transcription);
        } else {
          throw Exception('API returned invalid transcription data');
        }
      } else {
        throw Exception('STT API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🚨 [FOCUS_CHAT] 🎙️ Transcription failed: $e');
      setState(() => _isTranscribing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحويل الصوت إلى نص')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside input
        _messageInputFocus.unfocus();
        debugPrint('🎯 [FOCUS_CHAT] ⌨️ Keyboard dismissed by tap outside');
      },
      child: BlocListener<ChatCubit, ChatState>(
        listener: (context, state) => _handleChatStateChange(state),
        child: DraggableScrollableSheet(
          controller: _dragController,
          initialChildSize: 0.3, // 30% of screen
          minChildSize: 0.2,     // Minimum 20%
          maxChildSize: 0.8,     // Maximum 80%
          snap: true,
          snapSizes: const [0.3, 0.8], // Snap to these sizes
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDragHandle(),
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _buildScrollableContent(scrollController),
                  ),
                  _buildMessageInput(),
                  if (!_isExpanded) _buildQuickReplyChips(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: () {
        debugPrint('🎯 [FOCUS_CHAT] Drag handle tapped');
        HapticFeedback.lightImpact(); // Haptic feedback for handle tap
        
        // Toggle between expanded and collapsed states
        if (_dragController.size < 0.5) {
          _dragController.animateTo(
            0.8, 
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          debugPrint('🎯 [FOCUS_CHAT] Expanding to 80%');
        } else {
          _dragController.animateTo(
            0.3,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          debugPrint('🎯 [FOCUS_CHAT] Collapsing to 30%');
        }
      },
      child: Container(
        width: double.infinity, // Full width for better touch target
        padding: const EdgeInsets.symmetric(vertical: 12), // Larger touch area
        child: Center(
          child: Container(
            width: 60, // Wider handle
            height: 6,  // Thicker handle
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.chatTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'مباشر',
                  style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(ScrollController scrollController) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // Chat header as a sliver (scrollable)
        SliverToBoxAdapter(
          child: _buildChatHeader(),
        ),
        
        // Quick reply chips when expanded
        if (_isExpanded)
          SliverToBoxAdapter(
            child: _buildQuickReplyChips(),
          ),
        
        // Messages list
        _messages.isEmpty 
          ? SliverFillRemaining(
              hasScrollBody: false,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'ابدأ المحادثة',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final message = _messages[index];
                  final isCurrentUser = message.sender?.user.id == widget.currentUserId;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _buildMessageBubble(message, isCurrentUser),
                  );
                },
                childCount: _messages.length,
              ),
            ),
      ],
    );
  }


  Widget _buildMessageBubble(ChatMessageEntity message, bool isCurrentUser) {
    final senderName = message.sender?.user.name ?? 'مستخدم مجهول';
    
    debugPrint('🎯 [FOCUS_CHAT] 💬 Building message bubble - Sender: $senderName, Current user: $isCurrentUser');
    
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name (only for other users)
          if (!isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.grey.shade400,
                    child: Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : 'م',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          // Message bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.red.shade600 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.location != null) ...[
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: isCurrentUser ? Colors.white70 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      _formatMessageTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isCurrentUser ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(String? createdAt) {
    if (createdAt == null) return '';
    
    try {
      final dateTime = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'الآن';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}د';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}س';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildQuickReplyChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickReplies.length,
        itemBuilder: (context, index) {
          final quickReply = _quickReplies[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              onPressed: () {
                HapticFeedback.selectionClick(); // Haptic feedback for quick reply
                debugPrint('🎯 [FOCUS_CHAT] 🚀 Quick reply tapped: ${quickReply.text}');
                _sendMessage(quickReply.text);
              },
              label: Text(
                quickReply.text,
                style: const TextStyle(fontSize: 12),
              ),
              avatar: Icon(quickReply.icon, size: 16),
              backgroundColor: Colors.red.shade50,
              side: BorderSide(color: Colors.red.shade200),
              labelStyle: TextStyle(color: Colors.red.shade700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageInputFocus,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب رسالة...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.red.shade400),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                debugPrint('🎯 [FOCUS_CHAT] ⌨️ Message submitted via keyboard');
                _sendMessage(text);
              },
              onTap: () {
                debugPrint('🎯 [FOCUS_CHAT] ⌨️ Text input tapped - focusing');
                // Expand chat when user starts typing
                if (_dragController.size < 0.5) {
                  _dragController.animateTo(
                    0.8,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  debugPrint('🎯 [FOCUS_CHAT] 📈 Auto-expanding chat for input');
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          _buildSmartInputButton(),
        ],
      ),
    );
  }

  Widget _buildSmartInputButton() {
    final hasText = _messageController.text.trim().isNotEmpty;
    
    return GestureDetector(
      onLongPress: !hasText && _isRecorderReady ? _startRecording : null,
      onLongPressEnd: (details) {
        if (_isRecording) {
          _stopRecordingAndTranscribe();
        }
      },
      onTap: () {
        HapticFeedback.mediumImpact();
        
        if (hasText) {
          // Send button behavior
          debugPrint('🎯 [FOCUS_CHAT] 📤 Send button tapped');
          _sendMessage(_messageController.text);
        } else if (_isRecorderReady) {
          // Toggle recording behavior - simpler and more reliable
          debugPrint('🎯 [FOCUS_CHAT] 🎙️ Voice button tapped - toggling recording');
          _toggleRecording();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _isRecording 
            ? Colors.orange.shade600
            : _isTranscribing 
              ? Colors.blue.shade600
              : hasText 
                ? Colors.red.shade600 
                : Colors.red.shade400,
          shape: BoxShape.circle,
          boxShadow: [
            if (hasText || _isRecording || _isTranscribing)
              BoxShadow(
                color: (_isRecording ? Colors.orange : _isTranscribing ? Colors.blue : Colors.red).withValues(alpha: 0.3),
                blurRadius: _isRecording ? 8 : 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: _isTranscribing
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Icon(
              _isRecording 
                ? Icons.stop 
                : hasText 
                  ? Icons.send 
                  : Icons.mic,
              color: Colors.white,
              size: 20,
            ),
      ),
    );
  }
}

class QuickReply {
  final String text;
  final IconData icon;

  const QuickReply({
    required this.text,
    required this.icon,
  });
}