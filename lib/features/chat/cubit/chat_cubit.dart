import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../repo/chat_repo.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repo) : super(ChatInitial());

  final ChatRepository _repo;
  
  // Track conversations to prevent duplicates
  final Map<int, bool> _pendingConversations = {}; // userId -> isPending
  int? _activeEmergencyConversationId; // Track active emergency conversation

  Future<void> loadChats() async {
    emit(ChatLoading());
    try {
      final chats = await _repo.fetchChats();
      
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
      // Look for conversations with active emergency status and reports
      final activeEmergencies = chats.where((chat) {
        // Must have a topic with status and report
        if (chat.topic.latestStatus == null || chat.topic.report == null) return false;
        
        // Must be an active emergency status
        if (!chat.topic.latestStatus!.isActive) return false;
        
        // Must have emergency report data
        if (!chat.topic.report!.hasEmergencyData) return false;
        
        // Must be recent (within 24 hours)
        if (chat.createdAt != null) {
          try {
            final createdAt = DateTime.parse(chat.createdAt!);
            final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
            return createdAt.isAfter(oneDayAgo);
          } catch (e) {
            return false;
          }
        }
        
        return false;
      }).toList();
      
      if (activeEmergencies.isNotEmpty) {
        // Sort by creation date and return the most recent one
        activeEmergencies.sort((a, b) => 
          DateTime.parse(b.createdAt ?? '').compareTo(
            DateTime.parse(a.createdAt ?? '')
          )
        );
        final activeChat = activeEmergencies.first;
        debugPrint('[ChatCubit] Found active emergency conversation: ${activeChat.id} with status: ${activeChat.topic.latestStatus?.status}');
        return activeChat.id;
      }
      
      // Fallback: Look for any recent conversations with reports (less strict)
      final emergencyChats = chats.where((chat) {
        if (chat.topic.report == null || !chat.topic.report!.hasEmergencyData) return false;
        
        if (chat.createdAt != null) {
          try {
            final createdAt = DateTime.parse(chat.createdAt!);
            final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
            return createdAt.isAfter(oneDayAgo);
          } catch (e) {
            return false;
          }
        }
        
        return false;
      }).toList();
      
      if (emergencyChats.isNotEmpty) {
        emergencyChats.sort((a, b) => 
          DateTime.parse(b.createdAt ?? '').compareTo(
            DateTime.parse(a.createdAt ?? '')
          )
        );
        final emergencyChat = emergencyChats.first;
        debugPrint('[ChatCubit] Found emergency conversation (fallback): ${emergencyChat.id}');
        return emergencyChat.id;
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
