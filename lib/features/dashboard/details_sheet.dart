import 'package:flutter/material.dart';
import '../../features/reports/models/report.dart';
import '../../features/users_location/repo/locationservice.dart';
import '../../features/assignments/cubit/assignments_cubit.dart';
import '../../features/auth/models/user_type.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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

  // New parameters for coordinator assignment functionality
  final UserType userType;
  final List<UserLocationEntity> availableResponders;
  final AssignmentsCubit? assignmentsCubit;

  const ReportDetailsSheet({
    super.key,
    required this.report,
    required this.currentPosition,
    required this.onLocateOnMap,
    required this.onAssignToSelf,
    required this.onGetDirections,
    this.onChat,
    required this.userType,
    this.availableResponders = const [],
    this.assignmentsCubit,
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
      // Different action based on user type
      if (userType == UserType.coordinator) {
        // Coordinators get "Assign Responders" button
        firstRow.addAll([
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showResponderAssignmentModal(context),
              icon: const Icon(Icons.assignment_ind),
              label: const Text('Assign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ]);
      } else {
        // Responders get regular "Respond" button
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

  void _showResponderAssignmentModal(BuildContext context) {
    if (assignmentsCubit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment functionality not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResponderAssignmentModal(
        report: report,
        currentPosition: currentPosition,
        availableResponders: availableResponders,
        assignmentsCubit: assignmentsCubit!,
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

// ============================================================================
// RESPONDER ASSIGNMENT MODAL
// ============================================================================

class ResponderAssignmentModal extends StatefulWidget {
  final ReportEntity report;
  final LatLng currentPosition;
  final List<UserLocationEntity> availableResponders;
  final AssignmentsCubit assignmentsCubit;

  const ResponderAssignmentModal({
    super.key,
    required this.report,
    required this.currentPosition,
    required this.availableResponders,
    required this.assignmentsCubit,
  });

  @override
  State<ResponderAssignmentModal> createState() =>
      _ResponderAssignmentModalState();
}

class _ResponderAssignmentModalState extends State<ResponderAssignmentModal> {
  String _searchQuery = '';
  String _sortBy = 'distance'; // distance, name, role
  bool _isAssigning = false;
  Set<int> _assigningResponderIds = {};

  List<UserLocationEntity> get _filteredResponders {
    var responders =
        widget.availableResponders.where((user) => user.isResponder).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      responders = responders
          .where((user) =>
              user.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort responders
    switch (_sortBy) {
      case 'distance':
        responders.sort((a, b) {
          final distanceA = _calculateDistance(a);
          final distanceB = _calculateDistance(b);
          return distanceA.compareTo(distanceB);
        });
        break;
      case 'name':
        responders.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'role':
        responders.sort((a, b) => a.primaryRole.compareTo(b.primaryRole));
        break;
    }

    return responders;
  }

  double _calculateDistance(UserLocationEntity user) {
    if (user.location == null) return double.infinity;

    return Geolocator.distanceBetween(
          widget.report.latitude,
          widget.report.longitude,
          user.location!.lat,
          user.location!.lon,
        ) /
        1000; // Convert to kilometers
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          _buildSearchAndFilters(),
          _buildRespondersList(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_ind,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تكليف مستجيب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بلاغ طوارئ #${widget.report.id}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'البحث عن مستجيب...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),

          const SizedBox(height: 12),

          // Sort options
          Row(
            children: [
              const Text(
                'ترتيب حسب:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('المسافة', 'distance'),
                      const SizedBox(width: 8),
                      _buildSortChip('الاسم', 'name'),
                      const SizedBox(width: 8),
                      _buildSortChip('الدور', 'role'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _sortBy = value),
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildRespondersList() {
    final responders = _filteredResponders;

    if (responders.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_search,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'لا يوجد مستجيبين متاحين',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'جرب تغيير معايير البحث',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: responders.length,
        itemBuilder: (context, index) {
          final responder = responders[index];
          return _buildResponderCard(responder);
        },
      ),
    );
  }

  Widget _buildResponderCard(UserLocationEntity responder) {
    final distance = _calculateDistance(responder);
    final isAssigning = _assigningResponderIds.contains(responder.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with profile info and online status
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.blue.shade600,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              responder.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'متصل',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        responder.primaryRole.toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Location and distance info
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    responder.location?.address ?? 'موقع غير متوفر',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.social_distance,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  distance == double.infinity
                      ? 'مسافة غير معروفة'
                      : '${distance.toStringAsFixed(1)} كم',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getDistanceColor(distance).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getDistanceColor(distance).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getDistanceLabel(distance),
                    style: TextStyle(
                      color: _getDistanceColor(distance),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Assignment button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    isAssigning ? null : () => _assignResponder(responder),
                icon: isAssigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.assignment_turned_in),
                label: Text(
                  isAssigning ? 'جاري التكليف...' : 'تكليف بالمهمة',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDistanceColor(double distance) {
    if (distance == double.infinity) return Colors.grey;
    if (distance < 1) return Colors.green;
    if (distance < 5) return Colors.orange;
    return Colors.red;
  }

  String _getDistanceLabel(double distance) {
    if (distance == double.infinity) return 'غير معروف';
    if (distance < 1) return 'قريب جداً';
    if (distance < 5) return 'قريب';
    return 'بعيد';
  }

  Future<void> _assignResponder(UserLocationEntity responder) async {
    setState(() {
      _assigningResponderIds.add(responder.id);
    });

    try {
      await widget.assignmentsCubit.createParticipationRequest(
        reportId: widget.report.id,
        responderId: responder.id,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تكليف ${responder.name} بالمهمة بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _assigningResponderIds.remove(responder.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تكليف ${responder.name}: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
