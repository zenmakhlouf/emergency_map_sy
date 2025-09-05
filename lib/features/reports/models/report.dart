import 'package:flutter/foundation.dart';

enum EmergencyTypeApi {
  fire,
  police,
  medical,
  civil,
  traffic,
  other,
}

class ReportLocation {
  final double latitude;
  final double longitude;
  final String? address;

  const ReportLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory ReportLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ReportLocation(latitude: 0, longitude: 0, address: null);
    }
    final dynamic lat = json['lat'];
    final dynamic lon = json['lon'];
    return ReportLocation(
      latitude: (lat is num) ? lat.toDouble() : double.tryParse('$lat') ?? 0,
      longitude: (lon is num) ? lon.toDouble() : double.tryParse('$lon') ?? 0,
      address: json['address']?.toString(),
    );
  }
}

class UserRole {
  final int id;
  final String name;
  final String guardName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserRole({
    required this.id,
    required this.name,
    required this.guardName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] as int,
      name: json['name'] as String,
      guardName: json['guard_name'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class User {
  final int id;
  final String name;
  final String? email;
  final String? password;
  final String? lastActiveAt;
  final String? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<UserRole> roles;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.password,
    this.lastActiveAt,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
    required this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String?,
      password: json['password'] as String?,
      lastActiveAt: json['last_active_at'] as String?,
      lastLoginAt: json['last_login_at'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      roles: (json['roles'] as List<dynamic>?)
              ?.map((role) => UserRole.fromJson(role))
              .toList() ??
          [],
    );
  }
}

class ParticipationRequest {
  final int id;
  final User initiator;
  final User responder;
  final String status;
  final dynamic report; // Can be null or ReportEntity

  const ParticipationRequest({
    required this.id,
    required this.initiator,
    required this.responder,
    required this.status,
    this.report,
  });

  factory ParticipationRequest.fromJson(Map<String, dynamic> json) {
    return ParticipationRequest(
      id: json['id'] as int,
      initiator: User.fromJson(json['initiator']),
      responder: User.fromJson(json['responder']),
      status: json['status'] as String,
      report: json['report'], // Keep as dynamic for now
    );
  }
}

class ReportDetails {
  final String? name;
  final String? description;
  final String? text;

  const ReportDetails({
    this.name,
    this.description,
    this.text,
  });

  factory ReportDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReportDetails();
    return ReportDetails(
      name: json['name']?.toString(),
      description: json['discription']?.toString(), // Note: API uses "discription"
      text: json['text']?.toString(),
    );
  }
}

class ReportStateApi {
  final ReportDetails? report;
  final double? severity;
  final String? emergencyType;
  final String? emergencySubType;
  final String? status;
  final String? priority;
  final int? assigned;

  const ReportStateApi({
    this.report,
    this.severity,
    this.emergencyType,
    this.emergencySubType,
    this.status,
    this.priority,
    this.assigned,
  });

  factory ReportStateApi.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReportStateApi();

    double? parsedSeverity;
    final dynamic rawSeverity = json['severity'];
    if (rawSeverity == null) {
      parsedSeverity = null;
    } else if (rawSeverity is num) {
      parsedSeverity = rawSeverity.toDouble();
    } else {
      final String s = rawSeverity.toString().trim();
      parsedSeverity = double.tryParse(s);
      if (parsedSeverity == null) {
        debugPrint(
            '[reports] Bad severity value "$rawSeverity"; storing null');
      }
    }

    return ReportStateApi(
      report: ReportDetails.fromJson(json['report'] as Map<String, dynamic>?),
      severity: parsedSeverity,
      emergencyType: json['emergency_type']?.toString(),
      emergencySubType: json['emergency_sub_type']?.toString(),
      status: json['status']?.toString(),
      priority: json['priority']?.toString(),
      assigned: (json['assigned'] is num)
          ? (json['assigned'] as num).toInt()
          : int.tryParse('${json['assigned']}'),
    );
  }
}

class ReportConversation {
  final int id;

  const ReportConversation({required this.id});

  factory ReportConversation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReportConversation(id: 0);
    final dynamic id = json['id'];
    return ReportConversation(
      id: (id is num) ? id.toInt() : int.tryParse('$id') ?? 0,
    );
  }
}

class ReportEntity {
  final int id;
  final int initiatorId;
  final DateTime createdAt;
  final ReportConversation? conversation;
  final ReportLocation location;
  final ReportStateApi? state;
  final List<ParticipationRequest> participationRequests;
  final String? distance;

  // Convenience properties for UI
  String get title => state?.emergencyType ?? 'Emergency';
  String get description {
    final String? raw = state?.report?.description ?? 
                        state?.report?.name ?? 
                        state?.report?.text ?? 
                        location.address;
    if (raw == null || raw.trim().isEmpty) return 'No description';
    return raw;
  }

  // Add fullAddress getter to fix linter errors
  String get fullAddress {
    final address = location.address;
    if (address == null || address.trim().isEmpty) {
      return 'موقع غير محدد'; // "Unknown location" in Arabic
    }
    // If address contains "Live Location" in English, replace with Arabic
    if (address.toLowerCase().contains('live location')) {
      return 'موقع مباشر';
    }
    return address;
  }

  double get latitude => location.latitude;
  double get longitude => location.longitude;

  String get formattedTime =>
      '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  String get formattedDate =>
      '${createdAt.day}/${createdAt.month}/${createdAt.year}';

  const ReportEntity({
    required this.id,
    required this.initiatorId,
    required this.createdAt,
    this.conversation,
    required this.location,
    required this.state,
    required this.participationRequests,
    required this.distance,
  });

  factory ReportEntity.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at']?.toString();
    DateTime created;
    try {
      created = DateTime.parse(createdAtStr!.replaceFirst(' ', 'T'));
    } catch (_) {
      debugPrint('[reports] Bad created_at "$createdAtStr"; defaulting to now');
      created = DateTime.now();
    }

    return ReportEntity(
      id: (json['id'] is num)
          ? (json['id'] as num).toInt()
          : int.tryParse('${json['id']}') ?? 0,
      initiatorId: (json['initiator_id'] is num)
          ? (json['initiator_id'] as num).toInt()
          : int.tryParse('${json['initiator_id']}') ?? 0,
      createdAt: created,
      conversation: ReportConversation.fromJson(
          json['conversation'] as Map<String, dynamic>?),
      location:
          ReportLocation.fromJson(json['location'] as Map<String, dynamic>?),
      state: ReportStateApi.fromJson(json['state'] as Map<String, dynamic>?),
      participationRequests: (json['participation_requests'] as List<dynamic>?)
              ?.map((req) => ParticipationRequest.fromJson(req))
              .toList() ??
          [],
      distance: json['distance']?.toString(),
    );
  }
}
