import 'package:flutter/foundation.dart';

enum EmergencyTypeApi {
  fire,
  police,
  medical,
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

class ReportStateApi {
  final String? report;
  final int? severity; // desired int in frontend
  final String? emergencyType; // raw string from backend, may be upper/lower
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

    int? parsedSeverity;
    final dynamic rawSeverity = json['severity'];
    if (rawSeverity == null) {
      parsedSeverity = null;
    } else if (rawSeverity is num) {
      parsedSeverity = rawSeverity.round();
    } else {
      final String s = rawSeverity.toString().trim().toLowerCase();
      // Map common words to numeric scale temporarily until backend fixes to int
      switch (s) {
        case 'critical':
          parsedSeverity = 9;
          break;
        case 'high':
          parsedSeverity = 7;
          break;
        case 'medium':
          parsedSeverity = 5;
          break;
        case 'low':
          parsedSeverity = 3;
          break;
        default:
          parsedSeverity = double.tryParse(s)?.round();
          if (parsedSeverity == null) {
            debugPrint(
                '[reports] Bad severity value "$rawSeverity"; storing null and surfacing in UI');
          }
      }
    }

    return ReportStateApi(
      report: json['report']?.toString(),
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

class ReportEntity {
  final int id;
  final int initiatorId;
  final DateTime createdAt;
  final ReportLocation location;
  final ReportStateApi? state;
  final String? distance;

  // Convenience properties for UI
  String get title => state?.emergencyType ?? 'Emergency';
  String get description {
    final String? raw = state?.report ?? location.address;
    if (raw == null || raw.trim().isEmpty) return 'No description';
    return raw;
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
    required this.location,
    required this.state,
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
      location:
          ReportLocation.fromJson(json['location'] as Map<String, dynamic>?),
      state: ReportStateApi.fromJson(json['state'] as Map<String, dynamic>?),
      distance: json['distance']?.toString(),
    );
  }
}
