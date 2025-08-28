part of 'chat_cubit.dart';

@immutable
abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
}

class ChatListLoaded extends ChatState {
  final List<ConversationSummary> chats;
  ChatListLoaded(this.chats);
}

class ChatMessagesLoaded extends ChatState {
  final int chatId;
  final List<ChatMessageEntity> messages;
  ChatMessagesLoaded(this.chatId, this.messages);
}

// New state for when a new conversation is created via sending a message
class ChatNewConversationStarted extends ChatState {
  final ChatMessageEntity firstMessage;
  ChatNewConversationStarted(this.firstMessage);
}
