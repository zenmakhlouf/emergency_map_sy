import 'package:cloud_firestore/cloud_firestore.dart';

enum EmergencyType {
  burglary,
  lifeThreatening,
  suspicious,
  unusualSounds,
  nonEmergency,
}

class EmergencyReport {
  final String id;
  final String title;
  final String description;
  final EmergencyType type;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final int volunteersNeeded;
  final List<String> volunteers;
  final bool isActive;

  EmergencyReport({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.volunteersNeeded,
    required this.volunteers,
    required this.isActive,
  });

  factory EmergencyReport.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EmergencyReport(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: EmergencyType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => EmergencyType.nonEmergency,
      ),
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      volunteersNeeded: data['volunteersNeeded'] ?? 0,
      volunteers: List<String>.from(data['volunteers'] ?? []),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'volunteersNeeded': volunteersNeeded,
      'volunteers': volunteers,
      'isActive': isActive,
    };
  }

  String get formattedTime {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
