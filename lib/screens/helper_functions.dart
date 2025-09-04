// HELPER METHODS

import 'package:flutter/material.dart';

Color getUserRoleColor(String? role) {
  switch (role) {
    case 'responder':
      return Colors.blue.shade600;
    case 'coordinator':
      return Colors.green.shade600;
    default:
      return Colors.teal.shade600;
  }
}

IconData getUserRoleIcon(String? role) {
  switch (role) {
    case 'responder':
      return Icons.emergency;
    case 'coordinator':
      return Icons.support_agent;
    default:
      return Icons.person;
  }
}

IconData getIconForEmergencyType(String? apiType) {
  switch ((apiType ?? '').toLowerCase()) {
    case 'fire':
      return Icons.local_fire_department;
    case 'police':
      return Icons.local_police;
    case 'medical':
      return Icons.medical_services;
    case 'rescue':
      return Icons.search;
    case 'natural_disaster':
      return Icons.warning;
    case 'traffic':
      return Icons.traffic;
    default:
      return Icons.report;
  }
}

Color getColorForEmergencyType(String? apiType) {
  switch ((apiType ?? '').toLowerCase()) {
    case 'fire':
      return Colors.deepOrange.shade600;
    case 'police':
      return Colors.blue.shade600;
    case 'medical':
      return Colors.purple.shade600;
    case 'rescue':
      return Colors.green.shade600;
    case 'natural_disaster':
      return Colors.brown.shade600;
    case 'traffic':
      return Colors.amber.shade700;
    default:
      return Colors.grey.shade600;
  }
}

String formatTime(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

String getLocationErrorMessage(dynamic error) {
  if (error is LocationException) {
    return error.message;
  }
  if (error.toString().contains('timeout')) {
    return 'Location request timed out';
  }
  return 'Unable to get location';
}
// ============================================================================
// HELPER CLASSES
// ============================================================================

/// Custom exception for location-related errors
class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}
