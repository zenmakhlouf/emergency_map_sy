import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';

/// Enhanced chat conversation screen with enterprise-grade reliability
/// Provides real-time messaging for emergency communications
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

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Controllers and state management
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Animation controllers
  late AnimationController _sendButtonAnimationController;
  late Animation<double> _sendButtonScaleAnimation;

  // Polling and network state
  Timer? _messagePoller;
  List<ChatMessageEntity> _cachedMessages = <ChatMessageEntity>[];
  DateTime? _lastSuccessfulRefresh;

  // UI state management
  bool _isInitializing = true;
  bool _isSending = false;
  bool _isRefreshing = false;
  bool _hasText = false;
  String? _networkError;
  String? _locationError;

  // Configuration constants
  static const Duration _pollInterval = Duration(seconds: 8);
  static const Duration _networkTimeout = Duration(seconds: 10);
  static const Duration _locationTimeout = Duration(seconds: 5);
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _setupTextFieldListener();
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startPolling();
        _loadMessages(showError: false);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _stopPolling();
        break;
      default:
        break;
    }
  }

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================

  void _initializeAnimations() {
    _sendButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _sendButtonScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sendButtonAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  void _setupTextFieldListener() {
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() => _hasText = hasText);
        if (hasText) {
          _sendButtonAnimationController.forward();
        } else {
          _sendButtonAnimationController.reverse();
        }
      }
    });
  }

  Future<void> _initializeChat() async {
    try {
      await _loadInitialMessages();
      _startPolling();
    } catch (e) {
      debugPrint("Chat initialization error: $e");
      _handleInitializationError(e);
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _loadInitialMessages() async {
    await _loadMessages(showError: false);
  }

  // ============================================================================
  // MESSAGE LOADING AND POLLING
  // ============================================================================

  Future<void> _loadMessages({bool showError = true}) async {
    if (!mounted) return;

    try {
      await context
          .read<ChatCubit>()
          .loadMessages(
            chatId: widget.chatId,
          )
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
        setState(() {
          _networkError = "Unable to load messages";
        });
      }
    }
  }

  Future<void> _handleManualRefresh() async {
    if (!mounted || _isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _loadMessages();
      _showSuccessMessage("Messages updated");
    } catch (e) {
      _showErrorMessage("Failed to refresh messages");
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _startPolling() {
    _stopPolling();
    _messagePoller = Timer.periodic(_pollInterval, (_) {
      if (mounted) _loadMessages(showError: false);
    });
  }

  void _stopPolling() {
    _messagePoller?.cancel();
    _messagePoller = null;
  }

  // ============================================================================
  // MESSAGE SENDING
  // ============================================================================

  Future<void> _sendMessage() async {
    if (_isSending || !_hasText) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Provide haptic feedback
    HapticFeedback.lightImpact();

    setState(() => _isSending = true);
    final originalText = _messageController.text;
    _messageController.clear();

    try {
      // Get location with timeout
      Position? position = await _getCurrentLocation();

      // Send message
      await context
          .read<ChatCubit>()
          .sendMessage(
            chatId: widget.chatId,
            lat: position?.latitude ?? 0.0,
            lon: position?.longitude ?? 0.0,
            address: "Current location",
            text: text,
          )
          .timeout(_networkTimeout);

      // Immediate refresh to show sent message
      await _loadMessages(showError: false);
    } catch (e) {
      // Restore message on failure
      _messageController.text = originalText;
      _showErrorMessage("Failed to send message");
      debugPrint("Send message error: $e");
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      setState(() => _locationError = null);

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _locationTimeout,
      );

      return position;
    } catch (e) {
      debugPrint("Location error: $e");
      setState(() => _locationError = "Location unavailable");
      return null; // Continue without location
    }
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _handleInitializationError(dynamic error) {
    debugPrint("Chat initialization failed: $error");
    if (mounted) {
      setState(() {
        _networkError = "Failed to load chat";
      });
    }
  }

  // ============================================================================
  // BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesSection()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.chatTitle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          _buildConnectionStatus(),
        ],
      ),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      actions: [
        if (_networkError != null)
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.orange[700]),
            onPressed: _handleManualRefresh,
            tooltip: 'Retry Connection',
          ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    if (_isRefreshing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.green[600],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Updating...',
            style: TextStyle(fontSize: 11, color: Colors.green[600]),
          ),
        ],
      );
    }

    if (_networkError != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_wifi_off, size: 10, color: Colors.orange[700]),
          const SizedBox(width: 4),
          Text(
            'Connection Issues',
            style: TextStyle(fontSize: 11, color: Colors.orange[700]),
          ),
        ],
      );
    }

    if (_lastSuccessfulRefresh != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Colors.green[600]),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(fontSize: 11, color: Colors.green[600]),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessagesSection() {
    return BlocConsumer<ChatCubit, ChatState>(
      listener: _handleChatStateChange,
      builder: (context, state) {
        if (_isInitializing) {
          return _buildInitializationScreen();
        }

        if (state is ChatMessagesLoaded && state.chatId == widget.chatId) {
          return _buildMessagesList(state.messages);
        }

        if (state is ChatError && _cachedMessages.isEmpty) {
          return _buildErrorState(state.message);
        }

        // Show cached messages while loading/error
        if (_cachedMessages.isNotEmpty) {
          return _buildMessagesList(_cachedMessages);
        }

        return _buildEmptyState();
      },
    );
  }

  Widget _buildInitializationScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading conversation...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessageEntity> messages) {
    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final previousMessage = index > 0 ? messages[index - 1] : null;
          final showSenderInfo =
              _shouldShowSenderInfo(message, previousMessage);
          final isCurrentUser = message.sender?.user.id == widget.currentUserId;

          return _MessageBubble(
              key: ValueKey(message.id ?? index),
              message: message,
              isCurrentUser: isCurrentUser,
              showSenderInfo: showSenderInfo,
              onTap: () => {} //_onMessageTap(message),
              );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send your first message to begin chatting',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleManualRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildTextInput()),
              const SizedBox(width: 12),
              _buildSendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _messageController,
        focusNode: _focusNode,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.send,
        enabled: !_isSending,
        decoration: InputDecoration(
          hintText: 'Type a message...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: _locationError != null
              ? Tooltip(
                  message: _locationError!,
                  child: Icon(
                    Icons.location_off,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                )
              : null,
        ),
        onSubmitted: _isSending ? null : (_) => _sendMessage(),
      ),
    );
  }

  Widget _buildSendButton() {
    if (_isSending) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _sendButtonScaleAnimation,
      child: GestureDetector(
        onTap: _hasText ? _sendMessage : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _hasText ? Colors.red.shade600 : Colors.grey[400],
            shape: BoxShape.circle,
            boxShadow: _hasText
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
            Icons.send,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  void _handleChatStateChange(BuildContext context, ChatState state) {
    if (!mounted) return;

    if (state is ChatMessagesLoaded && state.chatId == widget.chatId) {
      setState(() {
        _cachedMessages = state.messages;
        _networkError = null;
        _lastSuccessfulRefresh = DateTime.now();
      });
      _scrollToBottom();
    } else if (state is ChatError) {
      setState(() {
        _networkError = state.message ?? "Chat error occurred";
      });
    }
  }

  bool _shouldShowSenderInfo(
    ChatMessageEntity current,
    ChatMessageEntity? previous,
  ) {
    if (previous == null) return true;
    if (current.sender?.user.id != previous.sender?.user.id) return true;

    // Parse to DateTime
    final currentTime =
        DateTime.tryParse(current.createdAt ?? '') ?? DateTime.now();
    final previousTime =
        DateTime.tryParse(previous.createdAt ?? '') ?? DateTime.now();

    final timeDiff = currentTime.difference(previousTime);

    return timeDiff.inMinutes >= 5;
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  void _cleanup() {
    _stopPolling();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendButtonAnimationController.dispose();
  }
}

// ============================================================================
// ENHANCED MESSAGE BUBBLE WIDGET
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final bool isCurrentUser;
  final bool showSenderInfo;
  final VoidCallback? onTap;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.showSenderInfo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final alignment =
        isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!isCurrentUser && showSenderInfo) _buildSenderHeader(),
          _buildMessageBubble(context),
          _buildMessageFooter(),
        ],
      ),
    );
  }

  Widget _buildSenderHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4, top: 8),
      child: Text(
        message.senderName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    final bubbleColor =
        isCurrentUser ? Colors.red.shade600 : Colors.grey.shade200;
    final textColor = isCurrentUser ? Colors.white : Colors.black87;

    final borderRadius = _getBorderRadius();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
          minWidth: 48,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                height: 1.3,
              ),
            ),
            if (message.hasLocation) _buildLocationIndicator(textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageFooter() {
    if (message.createdAt == null) return const SizedBox.shrink();
    final createdAt = DateTime.tryParse(message.createdAt.toString());

    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        left: isCurrentUser ? 0 : 12,
        right: isCurrentUser ? 12 : 0,
      ),
      child: Text(
        _formatMessageTime(createdAt!),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildLocationIndicator(Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 12,
            color: textColor.withOpacity(0.7),
          ),
          const SizedBox(width: 4),
          Text(
            'Location shared',
            style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  BorderRadius _getBorderRadius() {
    const radius = Radius.circular(18);
    const smallRadius = Radius.circular(4);

    if (isCurrentUser) {
      return const BorderRadius.only(
        topLeft: radius,
        bottomLeft: radius,
        bottomRight: smallRadius,
        topRight: radius,
      );
    } else {
      return const BorderRadius.only(
        topRight: radius,
        bottomRight: radius,
        bottomLeft: smallRadius,
        topLeft: radius,
      );
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month} ${_formatTime(dateTime)}';
    } else {
      return _formatTime(dateTime);
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// EXTENSION METHODS
// ============================================================================

extension ChatMessageExtensions on ChatMessageEntity {
  bool get hasLocation {
    // Implement based on your message model
    // return lat != null && lon != null && lat != 0.0 && lon != 0.0;
    return false; // Placeholder - adjust based on your model
  }
}
