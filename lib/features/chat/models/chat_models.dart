import 'package:flutter/foundation.dart';

@immutable
class ChatUser {
  final int id;
  final String name;
  final String? email;
  final List<String> roles;

  const ChatUser({
    required this.id,
    required this.name,
    this.email,
    this.roles = const <String>[],
  });

  // Helper to get user initials for avatars
  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return parts
          .map((p) => p.isNotEmpty ? p[0] : '')
          .take(2)
          .join()
          .toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  factory ChatUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChatUser(id: 0, name: 'Unknown User');
    }
    int id = 0;
    if (json['id'] is num) {
      id = (json['id'] as num).toInt();
    } else if (json['id'] is String) {
      id = int.tryParse(json['id'] as String) ?? 0;
    }
    String name = 'Unknown User';
    if (json['name'] != null) {
      name = json['name'].toString().trim();
      if (name.isEmpty) name = 'Unknown User';
    }
    String? email;
    if (json['email'] != null && json['email'].toString().trim().isNotEmpty) {
      email = json['email'].toString().trim();
    }
    List<String> roles = const <String>[];
    if (json['roles'] is List) {
      roles = (json['roles'] as List)
          .map((e) => e?.toString())
          .where((e) => e != null && e.trim().isNotEmpty)
          .cast<String>()
          .toList();
    }
    return ChatUser(id: id, name: name, email: email, roles: roles);
  }

  @override
  String toString() => 'ChatUser(id: $id, name: $name)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatUser && runtimeType == other.runtimeType && id == other.id;
  @override
  int get hashCode => id.hashCode;
}

@immutable
class ChatParticipant {
  final int id;
  final String? type;
  final ChatUser user;

  const ChatParticipant({required this.id, this.type, required this.user});

  factory ChatParticipant.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChatParticipant(
          id: 0, user: ChatUser(id: 0, name: 'Unknown User'));
    }
    int id = 0;
    if (json['id'] is num) {
      id = (json['id'] as num).toInt();
    } else if (json['id'] is String) {
      id = int.tryParse(json['id'] as String) ?? 0;
    }
    String? type;
    if (json['type'] != null && json['type'].toString().trim().isNotEmpty) {
      type = json['type'].toString().trim();
    }
    ChatUser user;
    if (json['user'] is Map<String, dynamic>) {
      user = ChatUser.fromJson(json['user'] as Map<String, dynamic>);
    } else {
      user = const ChatUser(id: 0, name: 'Unknown User');
    }
    return ChatParticipant(id: id, type: type, user: user);
  }

  @override
  String toString() => 'ChatParticipant(id: $id, user: $user)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatParticipant &&
          runtimeType == other.runtimeType &&
          id == other.id;
  @override
  int get hashCode => id.hashCode;
}

@immutable
class ChatTopic {
  final int id;
  final int? initiatorId;
  final String? createdAt;
  final String? updatedAt;

  const ChatTopic(
      {required this.id, this.initiatorId, this.createdAt, this.updatedAt});

  factory ChatTopic.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChatTopic(id: 0);
    int id = 0;
    if (json['id'] is num) {
      id = (json['id'] as num).toInt();
    } else if (json['id'] is String) {
      id = int.tryParse(json['id'] as String) ?? 0;
    }
    int? initiatorId;
    if (json['initiator_id'] is num) {
      initiatorId = (json['initiator_id'] as num).toInt();
    } else if (json['initiator_id'] is String) {
      initiatorId = int.tryParse(json['initiator_id'] as String);
    }
    String? createdAt;
    if (json['created_at'] != null &&
        json['created_at'].toString().trim().isNotEmpty) {
      createdAt = json['created_at'].toString().trim();
    }
    String? updatedAt;
    if (json['updated_at'] != null &&
        json['updated_at'].toString().trim().isNotEmpty) {
      updatedAt = json['updated_at'].toString().trim();
    }
    return ChatTopic(
        id: id,
        initiatorId: initiatorId,
        createdAt: createdAt,
        updatedAt: updatedAt);
  }
}

@immutable
class ConversationSummary {
  final int id;
  final ChatTopic topic;
  final List<ChatParticipant> participants;
  final String? createdAt;
  final String? updatedAt;
  // Added for UI, though API does not yet provide it.
  final String? lastMessageText;

  const ConversationSummary({
    required this.id,
    required this.topic,
    this.participants = const <ChatParticipant>[],
    this.createdAt,
    this.updatedAt,
    this.lastMessageText,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ConversationSummary(id: 0, topic: ChatTopic(id: 0));
    }
    int id = 0;
    if (json['id'] is num) {
      id = (json['id'] as num).toInt();
    } else if (json['id'] is String) {
      id = int.tryParse(json['id'] as String) ?? 0;
    }
    ChatTopic topic;
    if (json['topic'] is Map<String, dynamic>) {
      topic = ChatTopic.fromJson(json['topic'] as Map<String, dynamic>);
    } else {
      topic = const ChatTopic(id: 0);
    }
    List<ChatParticipant> participants = const <ChatParticipant>[];
    if (json['participants'] is List) {
      final participantsList = json['participants'] as List;
      participants = participantsList
          .whereType<Map<String, dynamic>>()
          .map((e) {
            try {
              return ChatParticipant.fromJson(e);
            } catch (e) {
              return null;
            }
          })
          .where((e) => e != null)
          .cast<ChatParticipant>()
          .toList();
    }
    String? createdAt;
    if (json['created_at'] != null &&
        json['created_at'].toString().trim().isNotEmpty) {
      createdAt = json['created_at'].toString().trim();
    }
    String? updatedAt;
    if (json['updated_at'] != null &&
        json['updated_at'].toString().trim().isNotEmpty) {
      updatedAt = json['updated_at'].toString().trim();
    }
    // API does not provide this, so it will be null.
    String? lastMessageText = json['last_message']?['text']?.toString();

    return ConversationSummary(
      id: id,
      topic: topic,
      participants: participants,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageText: lastMessageText,
    );
  }

  // Helper to get the other participant in a 1-on-1 chat
  ChatParticipant? getOtherParticipant(int currentUserId) {
    if (participants.length != 2) return null;
    return participants.firstWhere((p) => p.user.id != currentUserId,
        orElse: () => participants.first);
  }

  String getChatTitle(int currentUserId) {
    final other = getOtherParticipant(currentUserId);
    if (other != null) return other.user.name;

    final names = participants
        .where((p) => p.user.id != currentUserId)
        .map((p) => p.user.name)
        .toList();
    if (names.isEmpty) return 'Chat #$id';
    return names.join(', ');
  }

  @override
  String toString() =>
      'ConversationSummary(id: $id, participants: ${participants.length})';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationSummary &&
          runtimeType == other.runtimeType &&
          id == other.id;
  @override
  int get hashCode => id.hashCode;
}

@immutable
class ChatMessageEntity {
  final int id;
  final String text;
  final ChatParticipant? sender;
  final String? createdAt;
  final int? conversationId;

  const ChatMessageEntity({
    required this.id,
    this.text = '',
    this.sender,
    this.createdAt,
    this.conversationId,
  });

  factory ChatMessageEntity.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChatMessageEntity(id: 0);
    int id = 0;
    if (json['id'] is num) {
      id = (json['id'] as num).toInt();
    } else if (json['id'] is String) {
      id = int.tryParse(json['id'] as String) ?? 0;
    }
    String text = '';
    if (json['text'] != null) {
      text = json['text'].toString().trim();
    }
    ChatParticipant? sender;
    if (json['sender'] is Map<String, dynamic>) {
      sender = ChatParticipant.fromJson(json['sender'] as Map<String, dynamic>);
    }
    String? createdAt;
    if (json['created_at'] != null &&
        json['created_at'].toString().trim().isNotEmpty) {
      createdAt = json['created_at'].toString().trim();
    }
    int? conversationId;
    if (json['conversation'] is Map<String, dynamic>) {
      final conv = json['conversation'] as Map<String, dynamic>;
      if (conv['id'] is num) {
        conversationId = (conv['id'] as num).toInt();
      } else if (conv['id'] is String) {
        conversationId = int.tryParse(conv['id'] as String);
      }
    }
    return ChatMessageEntity(
      id: id,
      text: text,
      sender: sender,
      createdAt: createdAt,
      conversationId: conversationId,
    );
  }

  String get senderName => sender?.user.name ?? 'Unknown';

  @override
  String toString() =>
      'ChatMessageEntity(id: $id, text: ${text.length > 50 ? '${text.substring(0, 50)}...' : text})';
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;
  @override
  int get hashCode => id.hashCode;
}
