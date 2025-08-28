import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../apis/network.dart';
import '../../../utils/urls.dart';
import '../models/chat_models.dart';

class ChatRepository {
  Future<List<ConversationSummary>> fetchChats({required String bearer}) async {
    if (bearer.isEmpty) {
      throw Exception('Bearer token is required');
    }

    try {
      final Response res =
          await Network.getData(url: Urls.chats, bearerToken: bearer);
      final dynamic body = res.data;
      List<dynamic> items = <dynamic>[];

      // Defensive parsing of nested API response structure
      if (body is Map<String, dynamic>) {
        final dynamic data = body['data'];
        if (data is Map<String, dynamic>) {
          final dynamic conversations = data['conversations'];
          if (conversations is Map<String, dynamic>) {
            final dynamic conversationsData = conversations['data'];
            if (conversationsData is List) {
              items = conversationsData;
            } else if (conversationsData is Map) {
              items = conversationsData.values.toList();
            }
          } else if (conversations is List) {
            items = conversations;
          }
        } else if (body['conversations'] is Map<String, dynamic>) {
          final conversationsData =
              (body['conversations'] as Map<String, dynamic>)['data'];
          if (conversationsData is List) {
            items = conversationsData;
          }
        } else if (body['conversations'] is List) {
          items = body['conversations'] as List;
        }
      } else if (body is List) {
        items = body;
      }

      debugPrint('[ChatRepository] Raw items count: ${items.length}');

      final conversations = items
          .whereType<Map<String, dynamic>>()
          .map((e) {
            try {
              return ConversationSummary.fromJson(e);
            } catch (parseError) {
              debugPrint(
                  '[ChatRepository] Failed to parse conversation: $parseError');
              debugPrint('[ChatRepository] Raw data: $e');
              return null;
            }
          })
          .where((e) => e != null)
          .cast<ConversationSummary>()
          .toList();

      debugPrint(
          '[ChatRepository] Successfully parsed ${conversations.length} conversations');
      return conversations;
    } catch (e) {
      debugPrint('[ChatRepository] Error fetching chats: $e');
      rethrow;
    }
  }

  Future<List<ChatMessageEntity>> fetchMessages({
    required String bearer,
    required int chatId,
  }) async {
    if (bearer.isEmpty) {
      throw Exception('Bearer token is required');
    }

    if (chatId <= 0) {
      throw Exception('Invalid chat ID');
    }

    try {
      final Response res = await Network.getData(
        url: Urls.chatMessages(chatId),
        bearerToken: bearer,
      );
      final dynamic body = res.data;
      List<dynamic> items = <dynamic>[];

      // Defensive parsing of nested API response structure
      if (body is Map<String, dynamic>) {
        final dynamic data = body['data'];
        if (data is Map<String, dynamic>) {
          final dynamic messages = data['messages'];
          if (messages is Map<String, dynamic>) {
            final dynamic messagesData = messages['data'];
            if (messagesData is List) {
              items = messagesData;
            }
          } else if (messages is List) {
            items = messages;
          }
        } else if (body['messages'] is Map<String, dynamic>) {
          final messagesData =
              (body['messages'] as Map<String, dynamic>)['data'];
          if (messagesData is List) {
            items = messagesData;
          }
        } else if (body['messages'] is List) {
          items = body['messages'] as List;
        }
      } else if (body is List) {
        items = body;
      }

      debugPrint(
          '[ChatRepository] Raw messages count for chat $chatId: ${items.length}');

      final messages = items
          .whereType<Map<String, dynamic>>()
          .map((e) {
            try {
              return ChatMessageEntity.fromJson(e);
            } catch (parseError) {
              debugPrint(
                  '[ChatRepository] Failed to parse message: $parseError');
              debugPrint('[ChatRepository] Raw data: $e');
              return null;
            }
          })
          .where((e) => e != null)
          .cast<ChatMessageEntity>()
          .toList();

      // Sort messages by timestamp/ID for proper order
      messages.sort((a, b) => a.id.compareTo(b.id));

      debugPrint(
          '[ChatRepository] Successfully parsed ${messages.length} messages for chat $chatId');
      return messages;
    } catch (e) {
      debugPrint(
          '[ChatRepository] Error fetching messages for chat $chatId: $e');
      rethrow;
    }
  }

  Future<ChatMessageEntity> sendMessage({
    required String bearer,
    int? chatId,
    required double lat,
    required double lon,
    required String address,
    required String text,
  }) async {
    if (bearer.isEmpty) {
      throw Exception('Bearer token is required');
    }

    if (text.trim().isEmpty) {
      throw Exception('Message text cannot be empty');
    }

    try {
      final Map<String, dynamic> formData = {
        'location[lat]': lat,
        'location[lon]': lon,
        'location[address]': address.trim(),
        'text': text.trim(),
      };

      final String url =
          chatId == null ? Urls.newChatMessage : Urls.sendChatMessage(chatId);

      debugPrint(
          '[ChatRepository] Sending message to ${chatId == null ? 'new chat' : 'chat $chatId'}');
      debugPrint('[ChatRepository] Form data: $formData');

      final Response res = await Network.postData(
        url: url,
        body: FormData.fromMap(formData),
        bearerToken: bearer,
      );

      final dynamic body = res.data;
      Map<String, dynamic>? messageData;

      // Defensive parsing of response
      if (body is Map<String, dynamic>) {
        final dynamic data = body['data'];
        if (data is Map<String, dynamic>) {
          messageData = data['message'] as Map<String, dynamic>?;
        } else {
          messageData = body['message'] as Map<String, dynamic>?;
        }
      }

      if (messageData == null) {
        debugPrint('[ChatRepository] No message data in response: $body');
        throw Exception('Invalid response format: no message data');
      }

      debugPrint('[ChatRepository] Message sent successfully');
      return ChatMessageEntity.fromJson(messageData);
    } catch (e) {
      debugPrint('[ChatRepository] Error sending message: $e');
      rethrow;
    }
  }
}
