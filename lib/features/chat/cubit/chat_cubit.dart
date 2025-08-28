import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../repo/chat_repo.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repo) : super(ChatInitial());

  final ChatRepository _repo;

  Future<void> loadChats({required String bearer}) async {
    if (bearer.isEmpty) {
      emit(ChatError('Authentication token is required'));
      return;
    }

    emit(ChatLoading());
    try {
      final chats = await _repo.fetchChats(bearer: bearer);
      debugPrint('[ChatCubit] Loaded ${chats.length} chats');
      emit(ChatListLoaded(chats));
    } catch (e) {
      debugPrint('[ChatCubit] Error loading chats: $e');
      emit(ChatError('Failed to load chats: ${e.toString()}'));
    }
  }

  Future<void> loadMessages({
    required String bearer,
    required int chatId,
  }) async {
    if (bearer.isEmpty) {
      emit(ChatError('Authentication token is required'));
      return;
    }
    if (chatId <= 0) {
      emit(ChatError('Invalid chat ID'));
      return;
    }

    emit(ChatLoading());
    try {
      final messages =
          await _repo.fetchMessages(bearer: bearer, chatId: chatId);
      debugPrint(
          '[ChatCubit] Loaded ${messages.length} messages for chat $chatId');
      emit(ChatMessagesLoaded(chatId, messages));
    } catch (e) {
      debugPrint('[ChatCubit] Error loading messages for chat $chatId: $e');
      emit(ChatError('Failed to load messages: ${e.toString()}'));
    }
  }

  Future<void> sendMessage({
    required String bearer,
    int? chatId,
    required double lat,
    required double lon,
    required String address,
    required String text,
  }) async {
    if (bearer.isEmpty) {
      emit(ChatError('Authentication token is required'));
      return;
    }
    if (text.trim().isEmpty) {
      emit(ChatError('Message text cannot be empty'));
      return;
    }

    // Optimistically emit a sending state if needed in future
    // emit(ChatMessageSending());

    try {
      debugPrint('[ChatCubit] Sending message to chat ${chatId ?? 'new'}');
      final sentMessage = await _repo.sendMessage(
        bearer: bearer,
        chatId: chatId,
        lat: lat,
        lon: lon,
        address: address,
        text: text.trim(),
      );

      debugPrint('[ChatCubit] Message sent successfully: ${sentMessage.id}');

      // If this was a new chat, emit a special state so the UI can navigate
      if (chatId == null && sentMessage.conversationId != null) {
        emit(ChatNewConversationStarted(sentMessage));
        // Also refresh the main chat list in the background
        await loadChats(bearer: bearer);
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
          await loadMessages(bearer: bearer, chatId: chatId);
        }
      }
    } catch (e) {
      debugPrint('[ChatCubit] Error sending message: $e');
      emit(ChatError('Failed to send message: ${e.toString()}'));
    }
  }
}
