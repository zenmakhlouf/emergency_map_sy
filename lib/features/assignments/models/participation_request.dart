import 'package:equatable/equatable.dart';

class ParticipationRequest extends Equatable {
  final int id;
  final User initiator;
  final User responder;
  final String status; // pending, accept, reject, cancelled
  final EmergencyReport report;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ParticipationRequest({
    required this.id,
    required this.initiator,
    required this.responder,
    required this.status,
    required this.report,
    this.createdAt,
    this.updatedAt,
  });

  factory ParticipationRequest.fromJson(Map<String, dynamic> json) {
    try {
     // print('Parsing ParticipationRequest with ID: ${json['id']}');

      return ParticipationRequest(
        id: _parseInt(json['id']),
        initiator: User.fromJson(_getMapValue(json, 'initiator')),
        responder: User.fromJson(_getMapValue(json, 'responder')),
        status: _getStringValue(json, 'status', defaultValue: 'pending'),
        report: EmergencyReport.fromJson(_getMapValue(json, 'report')),
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
      );
    } catch (e, stackTrace) {
      // print('❌ Error parsing ParticipationRequest: $e');
      // print('Stack trace: $stackTrace');
      // print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'initiator': initiator.toJson(),
      'responder': responder.toJson(),
      'status': status,
      'report': report.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ParticipationRequest copyWith({
    int? id,
    User? initiator,
    User? responder,
    String? status,
    EmergencyReport? report,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ParticipationRequest(
      id: id ?? this.id,
      initiator: initiator ?? this.initiator,
      responder: responder ?? this.responder,
      status: status ?? this.status,
      report: report ?? this.report,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        initiator,
        responder,
        status,
        report,
        createdAt,
        updatedAt,
      ];

  // Helper getters
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accept';
  bool get isRejected => status == 'reject';
  bool get isCancelled => status == 'cancelled';

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accept':
        return 'مقبول';
      case 'reject':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  String get statusColor {
    switch (status) {
      case 'pending':
        return '#FFA500'; // Orange
      case 'accept':
        return '#4CAF50'; // Green
      case 'reject':
        return '#F44336'; // Red
      case 'cancelled':
        return '#9E9E9E'; // Grey
      default:
        return '#000000'; // Black
    }
  }
}

class User extends Equatable {
  final int id;
  final String name;
  final String? email;
  final String? lastActiveAt;
  final String? lastLoginAt;
  final List<UserRole> roles;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.lastActiveAt,
    this.lastLoginAt,
    required this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      //print('Parsing User with ID: ${json['id']}');

      // Handle roles with comprehensive error checking
      List<UserRole> userRoles = [];

      final rolesData = json['roles'];
      if (rolesData != null && rolesData is List) {
        for (int i = 0; i < rolesData.length; i++) {
          try {
            final roleData = rolesData[i];
            if (roleData != null && roleData is Map<String, dynamic>) {
              userRoles.add(UserRole.fromJson(roleData));
            } else {
              print('Skipping invalid role at index $i: $roleData');
            }
          } catch (e) {
            print('Failed to parse role at index $i: $e');
            print('Role data: ${rolesData[i]}');
            // Continue with other roles instead of failing completely
          }
        }
      } else {
        print('No valid roles found for user, rolesData: $rolesData');
      }

      return User(
        id: _parseInt(json['id']),
        name: _getStringValue(json, 'name', defaultValue: 'Unknown User'),
        email: _getStringValueNullable(json, 'email'),
        lastActiveAt: _getStringValueNullable(json, 'last_active_at'),
        lastLoginAt: _getStringValueNullable(json, 'last_login_at'),
        roles: userRoles,
      );
    } catch (e, stackTrace) {
        // print('❌ Error parsing User: $e');
        // print('Stack trace: $stackTrace');
        // print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'last_active_at': lastActiveAt,
      'last_login_at': lastLoginAt,
      'roles': roles.map((role) => role.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props =>
      [id, name, email, lastActiveAt, lastLoginAt, roles];

  // Helper methods
  bool hasRole(String roleName) {
    return roles.any((role) => role.name == roleName);
  }

  bool get isCitizen => hasRole('citizen');
  bool get isResponder => hasRole('responder');
  bool get isCoordinator => hasRole('coordinator');
}

class UserRole extends Equatable {
  final int id;
  final String name;
  final String? guardName;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? pivot;

  const UserRole({
    required this.id,
    required this.name,
    this.guardName,
    this.createdAt,
    this.updatedAt,
    this.pivot,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    try {
    //  print('Parsing UserRole with ID: ${json['id']}');

      return UserRole(
        id: _parseInt(json['id']),
        name: _getStringValue(json, 'name', defaultValue: 'unknown_role'),
        guardName: _getStringValueNullable(json, 'guard_name'),
        createdAt: _getStringValueNullable(json, 'created_at'),
        updatedAt: _getStringValueNullable(json, 'updated_at'),
        pivot: _getMapValueNullable(json, 'pivot'),
      );
    } catch (e, stackTrace) {
      // print('❌ Error parsing UserRole: $e');
      // print('Stack trace: $stackTrace');
      // print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (guardName != null) 'guard_name': guardName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pivot != null) 'pivot': pivot,
    };
  }

  @override
  List<Object?> get props => [id, name, guardName, createdAt, updatedAt, pivot];
}

class EmergencyReport extends Equatable {
  final int id;
  final User initiator;
  final ReportStatus latestStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmergencyReport({
    required this.id,
    required this.initiator,
    required this.latestStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmergencyReport.fromJson(Map<String, dynamic> json) {
    try {
      //print('Parsing EmergencyReport with ID: ${json['id']}');

      return EmergencyReport(
        id: _parseInt(json['id']),
        initiator: User.fromJson(_getMapValue(json, 'initiator')),
        latestStatus:
            ReportStatus.fromJson(_getMapValue(json, 'latest_status')),
        createdAt: _parseDateTimeRequired(json['created_at']),
        updatedAt: _parseDateTimeRequired(json['updated_at']),
      );
    } catch (e, stackTrace) {
      // print('❌ Error parsing EmergencyReport: $e');
      // print('Stack trace: $stackTrace');
      // print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'initiator': initiator.toJson(),
      'latest_status': latestStatus.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props =>
      [id, initiator, latestStatus, createdAt, updatedAt];
}

class ReportStatus extends Equatable {
  final int id;
  final String status;
  final String statusDisplay;
  final String statusColor;
  final String notes;
  final DateTime createdAt;

  const ReportStatus({
    required this.id,
    required this.status,
    required this.statusDisplay,
    required this.statusColor,
    required this.notes,
    required this.createdAt,
  });

  factory ReportStatus.fromJson(Map<String, dynamic> json) {
    try {
      //print('Parsing ReportStatus with ID: ${json['id']}');

      return ReportStatus(
        id: _parseInt(json['id']),
        status: _getStringValue(json, 'status', defaultValue: 'unknown'),
        statusDisplay: _getStringValue(json, 'status_display',
            defaultValue: 'Unknown Status'),
        statusColor:
            _getStringValue(json, 'status_color', defaultValue: '#000000'),
        notes: _getStringValue(json, 'notes', defaultValue: ''),
        createdAt: _parseDateTimeRequired(json['created_at']),
      );
    } catch (e, stackTrace) {
      // print('❌ Error parsing ReportStatus: $e');
      // print('Stack trace: $stackTrace');
      // print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'status_display': statusDisplay,
      'status_color': statusColor,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props =>
      [id, status, statusDisplay, statusColor, notes, createdAt];
}

// Helper functions for safe parsing
int _parseInt(dynamic value) {
  if (value == null) {
    throw ArgumentError('Required int value is null');
  }
  if (value is int) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw ArgumentError('Cannot parse int from: $value (${value.runtimeType})');
}

String _getStringValue(Map<String, dynamic> json, String key,
    {required String defaultValue}) {
  final value = json[key];
  if (value == null) return defaultValue;
  if (value is String) return value;
  return value.toString();
}

String? _getStringValueNullable(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

Map<String, dynamic> _getMapValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw ArgumentError('Required map value "$key" is null');
  }
  if (value is Map<String, dynamic>) return value;
  throw ArgumentError(
      'Value "$key" is not a Map: $value (${value.runtimeType})');
}

Map<String, dynamic>? _getMapValueNullable(
    Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  return null; // Return null if it's not a proper map
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

DateTime _parseDateTimeRequired(dynamic value) {
  if (value == null) {
    throw ArgumentError('Required DateTime value is null');
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw ArgumentError(
      'Cannot parse DateTime from: $value (${value.runtimeType})');
}
