import 'package:emergency_map_sy/screens/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ============================================================================
// COLOR & ICON HELPERS
// ============================================================================

Color getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'medical':
      return Colors.red;
    case 'fire':
      return Colors.deepOrange;
    case 'police':
      return Colors.blue;
    case 'accident':
      return Colors.purple;
    case 'natural disaster':
      return Colors.brown;
    default:
      return Colors.grey;
  }
}

Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'active':
    case 'in_progress':
      return Colors.blue;
    case 'resolved':
      return Colors.green;
    case 'closed':
    case 'cancelled':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

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

// ============================================================================
// DATA FORMATTING & CALCULATION HELPERS
// ============================================================================

double calculateDistance(LatLng pos1, LatLng pos2) {
  return Geolocator.distanceBetween(
        pos1.latitude,
        pos1.longitude,
        pos2.latitude,
        pos2.longitude,
      ) /
      1000;
}

String formatTime(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

String formatShortAddress(String fullAddress) {
  if (fullAddress.isEmpty ||
      fullAddress.toLowerCase().contains('live location') ||
      fullAddress.contains('موقع')) {
    return 'موقع مباشر'; // "Live Location" in Arabic
  }

  final parts = fullAddress
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'موقع غير محدد';

  final filteredParts = parts
      .where((part) =>
          !part.toLowerCase().contains('syria') &&
          !part.toLowerCase().contains('سوريا') &&
          !part.toLowerCase().contains('syrian arab republic') &&
          !part.contains('محافظة') &&
          part.length > 2)
      .take(2)
      .toList();

  return filteredParts.isEmpty
      ? (parts.isNotEmpty ? parts[0] : 'موقع غير محدد')
      : filteredParts.join(' - ');
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
