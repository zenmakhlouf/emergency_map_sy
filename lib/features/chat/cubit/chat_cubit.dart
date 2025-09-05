import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../repo/chat_repo.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repo) : super(ChatInitial());

  final ChatRepository _repo;

  final Map<int, bool> _pendingConversations = {};
  int? _activeEmergencyConversationId;

  Future<void> loadChats() async {
    emit(ChatLoading());
    try {
      final chats = await _repo.fetchChats();
      _activeEmergencyConversationId = _findActiveEmergencyConversation(chats);
      debugPrint('[ChatCubit] Loaded ${chats.length} chats');
      emit(ChatListLoaded(chats));
    } catch (e) {
      debugPrint('[ChatCubit] Error loading chats: $e');
      emit(ChatError('Failed to load chats: ${e.toString()}'));
    }
  }

  Future<void> loadMessages({required int chatId}) async {
    if (chatId <= 0) {
      emit(ChatError('Invalid chat ID'));
      return;
    }

    emit(ChatLoading());
    try {
      final messages = await _repo.fetchMessages(chatId: chatId);
      debugPrint(
          '[ChatCubit] Loaded ${messages.length} messages for chat $chatId');
      emit(ChatMessagesLoaded(chatId, messages));
    } catch (e) {
      debugPrint('[ChatCubit] Error loading messages for chat $chatId: $e');
      emit(ChatError('Failed to load messages: ${e.toString()}'));
    }
  }

  /// Starts a new emergency conversation. Called from the new message screen.
  Future<void> startEmergencyConversation({
    required double lat,
    required double lon,
    required String address,
    required String text,
    required int currentUserId,
  }) async {
    if (text.trim().isEmpty) {
      emit(ChatError('Message text cannot be empty'));
      return;
    }

    if (_pendingConversations[currentUserId] == true) {
      debugPrint(
          '[ChatCubit] Ignoring duplicate conversation creation for user $currentUserId');
      emit(ChatError('Please wait, your emergency report is being processed'));
      return;
    }

    _pendingConversations[currentUserId] = true;

    try {
      debugPrint('[ChatCubit] Starting new emergency conversation');
      final sentMessage = await _repo.sendMessage(
        chatId: null, // Explicitly null to create a new conversation
        lat: lat,
        lon: lon,
        address: address,
        text: text.trim(),
      );

      _pendingConversations.remove(currentUserId);
      debugPrint(
          '[ChatCubit] New conversation started: ${sentMessage.conversationId}');

      _activeEmergencyConversationId = sentMessage.conversationId;
      emit(ChatNewConversationStarted(sentMessage));

      // Refresh the main chat list in the background
      await loadChats();
    } catch (e) {
      _pendingConversations.remove(currentUserId);
      debugPrint('[ChatCubit] Error starting conversation: $e');
      emit(ChatError('Failed to send message: ${e.toString()}'));
    }
  }

  /// Sends a message to an already existing conversation.
  Future<void> sendMessageToConversation({
    required int chatId,
    required double lat,
    required double lon,
    required String address,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    try {
      debugPrint('[ChatCubit] Sending message to existing chat $chatId');
      final sentMessage = await _repo.sendMessage(
        chatId: chatId,
        lat: lat,
        lon: lon,
        address: address,
        text: text.trim(),
      );
      debugPrint('[ChatCubit] Message sent successfully: ${sentMessage.id}');

      // Update the message list if it's currently loaded
      if (state is ChatMessagesLoaded &&
          (state as ChatMessagesLoaded).chatId == chatId) {
        final currentState = state as ChatMessagesLoaded;
        final updatedMessages = [...currentState.messages, sentMessage];
        emit(ChatMessagesLoaded(chatId, updatedMessages));
      }
    } catch (e) {
      debugPrint('[ChatCubit] Error sending message to chat $chatId: $e');
      emit(ChatError('Failed to send message: ${e.toString()}'));
    }
  }

  int? _findActiveEmergencyConversation(List<ConversationSummary> chats) {
    try {
      final activeEmergencies = chats.where((chat) {
        if (chat.topic.latestStatus == null || chat.topic.report == null)
          return false;
        if (!chat.topic.latestStatus!.isActive) return false;
        if (!chat.topic.report!.hasEmergencyData) return false;

        if (chat.createdAt != null) {
          try {
            final createdAt = DateTime.parse(chat.createdAt!);
            return createdAt
                .isAfter(DateTime.now().subtract(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        }
        return false;
      }).toList();

      if (activeEmergencies.isNotEmpty) {
        activeEmergencies.sort((a, b) => DateTime.parse(b.createdAt ?? '')
            .compareTo(DateTime.parse(a.createdAt ?? '')));
        return activeEmergencies.first.id;
      }
    } catch (e) {
      debugPrint('[ChatCubit] Error finding active emergency conversation: $e');
    }
    return null;
  }

  int? get activeEmergencyConversationId => _activeEmergencyConversationId;
}
