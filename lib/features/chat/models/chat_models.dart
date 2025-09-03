import 'package:flutter/foundation.dart';

// New models for API alignment

@immutable
class ProfileImage {
  final int id;
  final String name;
  final String mimeType;
  final String publicPath;
  final ProfileImageConversions? conversions;

  const ProfileImage({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.publicPath,
    this.conversions,
  });

  factory ProfileImage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ProfileImage(
        id: 0,
        name: '',
        mimeType: '',
        publicPath: '',
      );
    }
    return ProfileImage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      publicPath: json['public_path']?.toString() ?? '',
      conversions: json['conversions'] != null 
          ? ProfileImageConversions.fromJson(json['conversions']) 
          : null,
    );
  }
}

@immutable
class ProfileImageConversions {
  final String? thumb;
  final String? medium;

  const ProfileImageConversions({
    this.thumb,
    this.medium,
  });

  factory ProfileImageConversions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProfileImageConversions();
    return ProfileImageConversions(
      thumb: json['thumb']?.toString(),
      medium: json['medium']?.toString(),
    );
  }
}
@immutable
class AuthPhone {
  final int id;
  final String phoneNumber;
  final String rawNumber;
  final String codeNumber;
  final String type;
  final bool isPrimary;
  final String? verifiedAt;

  const AuthPhone({
    required this.id,
    required this.phoneNumber,
    required this.rawNumber,
    required this.codeNumber,
    required this.type,
    required this.isPrimary,
    this.verifiedAt,
  });

  /// Whether this phone number has been verified
  bool get isVerified => verifiedAt != null && verifiedAt!.trim().isNotEmpty;

  factory AuthPhone.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AuthPhone(
        id: 0,
        phoneNumber: '',
        rawNumber: '',
        codeNumber: '',
        type: 'auth',
        isPrimary: true,
      );
    }
    return AuthPhone(
      id: (json['id'] as num?)?.toInt() ?? 0,
      phoneNumber: json['phone_number']?.toString() ?? '',
      rawNumber: json['raw_number']?.toString() ?? '',
      codeNumber: json['code_number']?.toString() ?? '',
      type: json['type']?.toString() ?? 'auth',
      isPrimary: json['is_primary'] == true,
      verifiedAt: json['verified_at']?.toString(),
    );
  }
}

@immutable
class ResponderType {
  final int id;
  final String name;
  final String description;
  final EmergencyTypeInfo? emergencyType;
  final String? assignedAt;

  const ResponderType({
    required this.id,
    required this.name,
    required this.description,
    this.emergencyType,
    this.assignedAt,
  });

  factory ResponderType.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ResponderType(id: 0, name: '', description: '');
    return ResponderType(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      emergencyType: json['emergency_type'] != null 
          ? EmergencyTypeInfo.fromJson(json['emergency_type']) 
          : null,
      assignedAt: json['assigned_at']?.toString(),
    );
  }
}

@immutable
class EmergencyTypeInfo {
  final int id;
  final String name;
  final String description;
  final String color;

  const EmergencyTypeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
  });

  factory EmergencyTypeInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EmergencyTypeInfo(id: 0, name: '', description: '', color: '#1E40AF');
    return EmergencyTypeInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      color: json['color']?.toString() ?? '#1E40AF',
    );
  }
}

@immutable
class LocationData {
  final double lat;
  final double lon;
  final String address;

  const LocationData({
    required this.lat,
    required this.lon,
    required this.address,
  });

  factory LocationData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LocationData(lat: 0.0, lon: 0.0, address: '');
    return LocationData(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      address: json['address']?.toString() ?? '',
    );
  }
}

@immutable
class ChatStatus {
  final int id;
  final String status;
  final String statusDisplay;
  final String statusColor;
  final String? notes;
  final String createdAt;

  const ChatStatus({
    required this.id,
    required this.status,
    required this.statusDisplay,
    required this.statusColor,
    this.notes,
    required this.createdAt,
  });

  factory ChatStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChatStatus(
        id: 0,
        status: 'unknown',
        statusDisplay: 'Unknown',
        statusColor: 'gray',
        createdAt: '',
      );
    }
    return ChatStatus(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'unknown',
      statusDisplay: json['status_display']?.toString() ?? 'Unknown',
      statusColor: json['status_color']?.toString() ?? 'gray',
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  bool get isActive => status == 'submitted';
  bool get isCompleted => status == 'completed';
  bool get isDeleted => status == 'deleted';
}

@immutable
class EmergencyReport {
  final String name;
  final String description;
  final String text;

  const EmergencyReport({
    required this.name,
    required this.description,
    required this.text,
  });

  factory EmergencyReport.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EmergencyReport(
        name: '',
        description: '',
        text: '',
      );
    }
    return EmergencyReport(
      name: json['name']?.toString() ?? '',
      description: json['discription']?.toString() ?? '', // Note: API uses 'discription'
      text: json['text']?.toString() ?? '',
    );
  }

  bool get hasEmergencyData => name.isNotEmpty || description.isNotEmpty || text.isNotEmpty;
}

@immutable
class ParticipationRequest {
  final int id;
  final ChatUser initiator;
  final ChatUser responder;
  final String status;
  final ReportSummary? report;

  const ParticipationRequest({
    required this.id,
    required this.initiator,
    required this.responder,
    required this.status,
    this.report,
  });

  factory ParticipationRequest.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ParticipationRequest(
        id: 0,
        initiator: ChatUser(id: 0, name: 'Unknown'),
        responder: ChatUser(id: 0, name: 'Unknown'),
        status: 'unknown',
      );
    }
    return ParticipationRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      initiator: ChatUser.fromJson(json['initiator']),
      responder: ChatUser.fromJson(json['responder']),
      status: json['status']?.toString() ?? 'unknown',
      report: json['report'] != null ? ReportSummary.fromJson(json['report']) : null,
    );
  }
  
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}

@immutable
class ReportSummary {
  final int id;
  final ChatUser? initiator;
  final ChatStatus? latestStatus;
  final String? createdAt;
  final String? updatedAt;

  const ReportSummary({
    required this.id,
    this.initiator,
    this.latestStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory ReportSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReportSummary(id: 0);
    return ReportSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      initiator: json['initiator'] != null ? ChatUser.fromJson(json['initiator']) : null,
      latestStatus: json['latest_status'] != null ? ChatStatus.fromJson(json['latest_status']) : null,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

@immutable
class ChatUser {
  final int id;
  final String name;
  final String? email;
  final List<String> roles;
  final AuthPhone? authPhone;
  final ProfileImage? profileImage;
  final ResponderType? responderType;
  final LocationData? location;
  final List<ParticipationRequest> participationRequests;

  const ChatUser({
    required this.id,
    required this.name,
    this.email,
    this.roles = const <String>[],
    this.authPhone,
    this.profileImage,
    this.responderType,
    this.location,
    this.participationRequests = const <ParticipationRequest>[],
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
          .map((e) {
            // Handle both string roles and object roles
            if (e is String) return e;
            if (e is Map<String, dynamic> && e['name'] != null) return e['name'].toString();
            return e?.toString();
          })
          .where((e) => e != null && e.trim().isNotEmpty)
          .map((e) => e!)
          .toList();
    }
    
    // Parse auth_phone
    AuthPhone? authPhone;
    if (json['auth_phone'] is Map<String, dynamic>) {
      authPhone = AuthPhone.fromJson(json['auth_phone'] as Map<String, dynamic>);
    }
    
    // Parse profile_image
    ProfileImage? profileImage;
    if (json['profile_image'] is Map<String, dynamic>) {
      profileImage = ProfileImage.fromJson(json['profile_image'] as Map<String, dynamic>);
    }
    
    // Parse responder_type
    ResponderType? responderType;
    if (json['responder_type'] is Map<String, dynamic>) {
      responderType = ResponderType.fromJson(json['responder_type'] as Map<String, dynamic>);
    }
    
    // Parse location
    LocationData? location;
    if (json['location'] is Map<String, dynamic>) {
      location = LocationData.fromJson(json['location'] as Map<String, dynamic>);
    }
    
    // Parse participation_requests
    List<ParticipationRequest> participationRequests = const <ParticipationRequest>[];
    if (json['participation_requests'] is List) {
      participationRequests = (json['participation_requests'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) {
            try {
              return ParticipationRequest.fromJson(e);
            } catch (e) {
              debugPrint('[ChatUser] Failed to parse participation request: $e');
              return null;
            }
          })
          .where((e) => e != null)
          .cast<ParticipationRequest>()
          .toList();
    }
    
    return ChatUser(
      id: id,
      name: name,
      email: email,
      roles: roles,
      authPhone: authPhone,
      profileImage: profileImage,
      responderType: responderType,
      location: location,
      participationRequests: participationRequests,
    );
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
  final ChatUser? initiator;
  final String? createdAt;
  final String? updatedAt;
  final ChatStatus? latestStatus;
  final EmergencyReport? report;

  const ChatTopic({
    required this.id,
    this.initiatorId,
    this.initiator,
    this.createdAt,
    this.updatedAt,
    this.latestStatus,
    this.report,
  });

  factory ChatTopic.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChatTopic(id: 0);
    int id = 0;
    if (json['id'] is num) {
      id = (json['id'] as num).toInt();
    } else if (json['id'] is String) {
      id = int.tryParse(json['id'] as String) ?? 0;
    }
    
    // Parse initiator_id (legacy support)
    int? initiatorId;
    if (json['initiator_id'] is num) {
      initiatorId = (json['initiator_id'] as num).toInt();
    } else if (json['initiator_id'] is String) {
      initiatorId = int.tryParse(json['initiator_id'] as String);
    }
    
    // Parse initiator object (new API format)
    ChatUser? initiator;
    if (json['initiator'] is Map<String, dynamic>) {
      final initiatorData = json['initiator'] as Map<String, dynamic>;
      initiator = ChatUser.fromJson(initiatorData);
      initiatorId ??= initiator.id; // Set ID if not already set
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
    
    // Parse latest_status
    ChatStatus? latestStatus;
    if (json['latest_status'] is Map<String, dynamic>) {
      latestStatus = ChatStatus.fromJson(json['latest_status'] as Map<String, dynamic>);
    }
    
    // Parse report
    EmergencyReport? report;
    if (json['report'] is Map<String, dynamic>) {
      report = EmergencyReport.fromJson(json['report'] as Map<String, dynamic>);
    }
    
    return ChatTopic(
      id: id,
      initiatorId: initiatorId,
      initiator: initiator,
      createdAt: createdAt,
      updatedAt: updatedAt,
      latestStatus: latestStatus,
      report: report,
    );
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
  final String? voiceRecordText;
  final String? voiceRecord;
  final LocationData? location;

  const ChatMessageEntity({
    required this.id,
    this.text = '',
    this.sender,
    this.createdAt,
    this.conversationId,
    this.voiceRecordText,
    this.voiceRecord,
    this.location,
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
    
    // Parse voice record fields
    String? voiceRecordText;
    if (json['voice_record_text'] != null && json['voice_record_text'].toString().trim().isNotEmpty) {
      voiceRecordText = json['voice_record_text'].toString().trim();
    }
    
    String? voiceRecord;
    if (json['voice_record'] != null && json['voice_record'].toString().trim().isNotEmpty) {
      voiceRecord = json['voice_record'].toString().trim();
    }
    
    // Parse location
    LocationData? location;
    if (json['location'] is Map<String, dynamic>) {
      location = LocationData.fromJson(json['location'] as Map<String, dynamic>);
    }
    
    return ChatMessageEntity(
      id: id,
      text: text,
      sender: sender,
      createdAt: createdAt,
      conversationId: conversationId,
      voiceRecordText: voiceRecordText,
      voiceRecord: voiceRecord,
      location: location,
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
