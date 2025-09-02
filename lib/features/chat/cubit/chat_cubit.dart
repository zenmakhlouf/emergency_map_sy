import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../repo/chat_repo.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repo) : super(ChatInitial());

  final ChatRepository _repo;
  
  // Track conversations to prevent duplicates
  List<ConversationSummary> _cachedChats = [];
  Map<int, bool> _pendingConversations = {}; // userId -> isPending
  int? _activeEmergencyConversationId; // Track active emergency conversation

  Future<void> loadChats() async {
    emit(ChatLoading());
    try {
      final chats = await _repo.fetchChats();
      _cachedChats = chats;
      
      // Find active emergency conversation (most recent with submitted status)
      _activeEmergencyConversationId = _findActiveEmergencyConversation(chats);
      
      debugPrint('[ChatCubit] Loaded ${chats.length} chats');
      debugPrint('[ChatCubit] Active emergency conversation: $_activeEmergencyConversationId');
      emit(ChatListLoaded(chats));
    } catch (e) {
      debugPrint('[ChatCubit] Error loading chats: $e');
      emit(ChatError('Failed to load chats: ${e.toString()}'));
    }
  }

  Future<void> loadMessages({
    required int chatId,
  }) async {
    
    if (chatId <= 0) {
      emit(ChatError('Invalid chat ID'));
      return;
    }

    emit(ChatLoading());
    try {
      final messages =
          await _repo.fetchMessages( chatId: chatId);
      debugPrint(
          '[ChatCubit] Loaded ${messages.length} messages for chat $chatId');
      emit(ChatMessagesLoaded(chatId, messages));
    } catch (e) {
      debugPrint('[ChatCubit] Error loading messages for chat $chatId: $e');
      emit(ChatError('Failed to load messages: ${e.toString()}'));
    }
  }

  /// Send a message with duplicate prevention for emergency conversations
  Future<void> sendMessage({
    int? chatId,
    required double lat,
    required double lon,
    required String address,
    required String text,
    int? currentUserId, // Add userId to track conversation ownership
  }) async {
    if (text.trim().isEmpty) {
      emit(ChatError('Message text cannot be empty'));
      return;
    }

    // Check for duplicate conversation creation
    if (chatId == null && currentUserId != null) {
      // Check if there's already a pending conversation creation
      if (_pendingConversations[currentUserId] == true) {
        debugPrint('[ChatCubit] Ignoring duplicate conversation creation for user $currentUserId');
        emit(ChatError('Please wait, your emergency report is being processed'));
        return;
      }

      // Check if there's already an active emergency conversation
      if (_activeEmergencyConversationId != null) {
        debugPrint('[ChatCubit] Using existing emergency conversation: $_activeEmergencyConversationId');
        // Send message to existing conversation instead of creating new one
        return sendMessage(
          chatId: _activeEmergencyConversationId,
          lat: lat,
          lon: lon,
          address: address,
          text: text,
          currentUserId: currentUserId,
        );
      }

      // Mark this user as having a pending conversation
      _pendingConversations[currentUserId] = true;
    }

    try {
      debugPrint('[ChatCubit] Sending message to chat ${chatId ?? 'new'}');
      final sentMessage = await _repo.sendMessage(
        chatId: chatId,
        lat: lat,
        lon: lon,
        address: address,
        text: text.trim(),
      );

      // Clear pending flag for this user
      if (currentUserId != null) {
        _pendingConversations.remove(currentUserId);
      }

      debugPrint('[ChatCubit] Message sent successfully: ${sentMessage.id}');

      // If this was a new chat, emit a special state so the UI can navigate
      if (chatId == null && sentMessage.conversationId != null) {
        _activeEmergencyConversationId = sentMessage.conversationId;
        emit(ChatNewConversationStarted(sentMessage));
        // Also refresh the main chat list in the background
        await loadChats();
        return;
      }

      // Otherwise, update the existing message list
      if (chatId != null) {
        if (state is ChatMessagesLoaded &&
            (state as ChatMessagesLoaded).chatId == chatId) {
          final currentState = state as ChatMessagesLoaded;
          final updatedMessages = [...currentState.messages, sentMessage];
          emit(ChatMessagesLoaded(chatId, updatedMessages));
        } else {
          await loadMessages(chatId: chatId);
        }
      }
    } catch (e) {
      // Clear pending flag on error
      if (currentUserId != null) {
        _pendingConversations.remove(currentUserId);
      }
      debugPrint('[ChatCubit] Error sending message: $e');
      emit(ChatError('Failed to send message: ${e.toString()}'));
    }
  }

  /// Find the most recent active emergency conversation for the current user
  int? _findActiveEmergencyConversation(List<ConversationSummary> chats) {
    try {
      // Look for recent conversations that could be active emergencies
      // Since the ChatTopic model doesn't include status/report, we'll look for recent chats
      // that are likely to be emergency conversations (created within last 24 hours)
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(days: 1));
      
      final recentChats = chats.where((chat) {
        if (chat.createdAt == null) return false;
        try {
          final createdAt = DateTime.parse(chat.createdAt!);
          return createdAt.isAfter(oneDayAgo);
        } catch (e) {
          return false;
        }
      }).toList();
      
      if (recentChats.isNotEmpty) {
        // Sort by creation date and return the most recent one
        recentChats.sort((a, b) => 
          DateTime.parse(b.createdAt ?? '').compareTo(
            DateTime.parse(a.createdAt ?? '')
          )
        );
        debugPrint('[ChatCubit] Found recent conversation: ${recentChats.first.id}');
        return recentChats.first.id;
      }
    } catch (e) {
      debugPrint('[ChatCubit] Error finding active emergency conversation: $e');
    }
    return null;
  }
  
  /// Clear the active emergency conversation (e.g., when it's resolved)
  void clearActiveEmergencyConversation() {
    _activeEmergencyConversationId = null;
    debugPrint('[ChatCubit] Cleared active emergency conversation');
  }
  
  /// Get the current active emergency conversation ID
  int? get activeEmergencyConversationId => _activeEmergencyConversationId;
  
  /// Check if user has pending conversation creation
  bool isConversationPending(int userId) {
    return _pendingConversations[userId] == true;
  }
}
