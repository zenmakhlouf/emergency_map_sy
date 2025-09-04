import 'package:flutter/material.dart';
import '../../features/reports/models/report.dart';
import '../../features/users_location/repo/locationservice.dart';
import 'package:latlong2/latlong.dart';

import 'helpers.dart';

// ============================================================================
// REPORT DETAILS SHEET
// ============================================================================

class ReportDetailsSheet extends StatelessWidget {
  final ReportEntity report;
  final LatLng currentPosition;
  final Function(ReportEntity) onLocateOnMap;
  final Function(ReportEntity) onAssignToSelf;
  final Function(ReportEntity) onGetDirections;
  final Function(ReportEntity)?
      onChat; // Nullable for when chat is not available

  const ReportDetailsSheet({
    super.key,
    required this.report,
    required this.currentPosition,
    required this.onLocateOnMap,
    required this.onAssignToSelf,
    required this.onGetDirections,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(report),
                  const Divider(height: 32),
                  _buildDescription(report),
                  const SizedBox(height: 24),
                  _buildLocationSection(report),
                  const SizedBox(height: 24),
                  _buildActionButtons(context, report),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ReportEntity report) {
    return Row(
      children: [
        _buildIncidentIcon(
          report.state?.emergencyType,
          report.state?.severity ?? 0.5,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${report.formattedDate} at ${report.formattedTime}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Distance: ${calculateDistance(currentPosition, LatLng(report.latitude, report.longitude)).toStringAsFixed(1)} km',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
        _buildSeverityIndicator(report.state?.severity ?? 0.5),
      ],
    );
  }

  Widget _buildDescription(ReportEntity report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          report.description,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildLocationSection(ReportEntity report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Location',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.fullAddress,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ReportEntity report) {
    List<Widget> firstRow = [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onLocateOnMap(report);
          },
          icon: const Icon(Icons.map_outlined),
          label: const Text('View on Map'),
        ),
      ),
    ];

    if (onChat != null) {
      // A simple check to decide if this user can take action
      firstRow.addAll([
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onAssignToSelf(report);
            },
            icon: const Icon(Icons.assignment_turned_in),
            label: const Text('Respond'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ]);
    }

    List<Widget> secondRow = [];
    if (onChat != null) {
      secondRow.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onGetDirections(report);
            },
            icon: const Icon(Icons.directions),
            label: const Text('Directions'),
          ),
        ),
      );

      if (onChat != null) {
        secondRow.add(const SizedBox(width: 12));
        secondRow.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onChat!(report);
              },
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Chat'),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        Row(children: firstRow),
        if (secondRow.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: secondRow),
        ],
      ],
    );
  }

  // Helper widgets also used on cards, duplicated here for encapsulation
  Widget _buildIncidentIcon(String? emergencyType, double severity) {
    final color = getColorForEmergencyType(emergencyType);
    final icon = getIconForEmergencyType(emergencyType);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildSeverityIndicator(double severity) {
    Color color;
    String label;
    if (severity >= 0.8) {
      color = Colors.red;
      label = 'HIGH';
    } else if (severity >= 0.6) {
      color = Colors.orange;
      label = 'MED';
    } else {
      color = Colors.yellow.shade700;
      label = 'LOW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ============================================================================
// USER DETAILS SHEET
// ============================================================================

class UserDetailsSheet extends StatelessWidget {
  final UserLocationEntity user;

  const UserDetailsSheet({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const Divider(height: 32),
                _buildLocationInfo(),
                const SizedBox(height: 24),
                _buildActions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: getUserRoleColor(user.primaryRole).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            getUserRoleIcon(user.primaryRole),
            color: getUserRoleColor(user.primaryRole),
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                user.primaryRole.toUpperCase(),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last Known Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          user.location?.address ?? 'Address not available',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // TODO: Implement contact functionality
          Navigator.pop(context);
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Contact User'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
