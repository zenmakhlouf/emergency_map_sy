import 'package:flutter/material.dart';
import '../../features/reports/models/report.dart';
import '../../features/users_location/repo/locationservice.dart';
import '../../features/assignments/cubit/assignments_cubit.dart';
import '../../features/auth/models/user_type.dart';
import '../../services/geocoding_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'helpers.dart';

// ============================================================================
// REPORT DETAILS SHEET
// ============================================================================

class ReportDetailsSheet extends StatefulWidget {
  final ReportEntity report;
  final LatLng currentPosition;
  final Function(ReportEntity) onLocateOnMap;
  final Function(ReportEntity) onAssignToSelf;
  final Function(ReportEntity) onGetDirections;
  final Function(ReportEntity)? onChat;
  final Function(ReportEntity)? onCloseReport;
  final Function(ReportEntity)? onDeleteReport;

  // New parameters for coordinator assignment functionality
  final UserType userType;
  final List<UserLocationEntity> availableResponders;
  final AssignmentsCubit? assignmentsCubit;
  final int? currentUserId;

  const ReportDetailsSheet({
    super.key,
    required this.report,
    required this.currentPosition,
    required this.onLocateOnMap,
    required this.onAssignToSelf,
    required this.onGetDirections,
    this.onChat,
    this.onCloseReport,
    this.onDeleteReport,
    required this.userType,
    this.availableResponders = const [],
    this.assignmentsCubit,
    this.currentUserId,
  });

  @override
  State<ReportDetailsSheet> createState() => _ReportDetailsSheetState();
}

class _ReportDetailsSheetState extends State<ReportDetailsSheet> {
  String? geocodedAddress;
  bool isGeocodingLoading = false;

  @override
  void initState() {
    super.initState();
    _geocodeAddress();
  }

  Future<void> _geocodeAddress() async {
    if (mounted) {
      setState(() => isGeocodingLoading = true);
    }

    try {
      final result = await GeocodingService.reverseGeocode(
        LatLng(widget.report.latitude, widget.report.longitude),
        language: 'ar',
      );

      if (mounted) {
        setState(() {
          geocodedAddress = result.mediumAddress;
          isGeocodingLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          geocodedAddress = 'موقع غير محدد';
          isGeocodingLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDragHandle(),
                _buildCompactHeader(),
                _buildContent(),
              ],
            ),
            // Position the options menu in the top-left (top-right in RTL)
            if (widget.userType == UserType.coordinator)
              Positioned(
                top: 12,
                left: 12,
                child: _buildOptionsMenu(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsMenu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'closed') {
          _confirmAndExecute(
            context: context,
            title: 'تأكيد الإغلاق',
            content: 'هل أنت متأكد من رغبتك في إغلاق هذا البلاغ؟',
            onConfirm: () {
              if (widget.onCloseReport != null) {
                widget.onCloseReport!(widget.report);
              }
            },
          );
        } else if (value == 'deleted') {
          _confirmAndExecute(
            context: context,
            title: 'تأكيد الحذف',
            content:
                'هل أنت متأكد من رغبتك في حذف هذا البلاغ نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
            confirmText: 'حذف',
            confirmColor: Colors.red,
            onConfirm: () {
              if (widget.onDeleteReport != null) {
                widget.onDeleteReport!(widget.report);
              }
            },
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'closed',
          child: ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('إغلاق البلاغ'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'deleted',
          child: ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text('حذف البلاغ', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
      icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _confirmAndExecute({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    String confirmText = 'تأكيد',
    Color confirmColor = Colors.blue,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: Text(confirmText),
            style: TextButton.styleFrom(
              foregroundColor: confirmColor,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close dialog
              Navigator.of(context).pop(); // Close sheet
              onConfirm();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCompactHeader() {
    final emergencyColor =
        getColorForEmergencyType(widget.report.state?.emergencyType);
    final severity = widget.report.state?.severity ?? 0.5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: emergencyColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: emergencyColor.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: emergencyColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              getIconForEmergencyType(widget.report.state?.emergencyType),
              color: emergencyColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.report.state?.report?.name ??
                      _getEmergencyTypeArabic(
                          widget.report.state?.emergencyType),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: emergencyColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${widget.report.formattedDate} • ${widget.report.formattedTime}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    _buildCompactSeverityBadge(severity),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSeverityBadge(double severity) {
    final color = _getSeverityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _getSeverityLabel(severity),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.report.state?.report?.description != null ||
                widget.report.state?.report?.text != null)
              _buildDescriptionSection(),
            const SizedBox(height: 16),
            _buildLocationSection(),
            const SizedBox(height: 16),
            _buildCompactStatusSection(),
            if (widget.userType == UserType.coordinator &&
                widget.report.participationRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildCompactParticipationSection(),
            ],
            const SizedBox(height: 20),
            _buildActionButtons(context, widget.report),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final reportDetails = widget.report.state?.report;
    if (reportDetails == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reportDetails.description != null &&
            reportDetails.description!.isNotEmpty) ...[
          Text(
            reportDetails.description!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.black87,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ] else if (reportDetails.text != null &&
            reportDetails.text!.isNotEmpty) ...[
          Text(
            reportDetails.text!
                .split('\n')
                .where((line) =>
                    line.trim().isNotEmpty &&
                    !line.startsWith('🚨') &&
                    !line.startsWith('⚠️'))
                .join('\n')
                .trim(),
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.black87,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildLocationSection() {
    final distance = calculateDistance(widget.currentPosition,
        LatLng(widget.report.latitude, widget.report.longitude));

    return Row(
      children: [
        Icon(Icons.location_on, color: Colors.blue.shade600, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGeocodingLoading)
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'جاري تحديد الموقع...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  geocodedAddress ?? 'موقع غير محدد',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'المسافة: ${distance.toStringAsFixed(1)} كم',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatusSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'حالة البلاغ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactInfoItem(
                  'النوع',
                  _getEmergencyTypeArabic(widget.report.state?.emergencyType),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactInfoItem(
                  'النوع الفرعي',
                  _getEmergencySubTypeArabic(
                      widget.report.state?.emergencySubType),
                ),
              ),
            ],
          ),
          if (widget.userType == UserType.coordinator ||
              widget.report.state?.assigned != null ||
              widget.report.participationRequests.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCompactInfoItem(
                    'المكلفون',
                    '${widget.report.state?.assigned ?? 0}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactInfoItem(
                    'طلبات الاستجابة',
                    '${widget.report.participationRequests.length}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactParticipationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.orange.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'طلبات الاستجابة (${widget.report.participationRequests.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.report.participationRequests
              .take(3)
              .map((request) => _buildCompactParticipationItem(request)),
          if (widget.report.participationRequests.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${widget.report.participationRequests.length - 3} طلبات أخرى',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactParticipationItem(ParticipationRequest request) {
    final statusColor = _getRequestStatusColor(request.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Colors.blue.shade600, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              request.responder.name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getRequestStatusArabic(request.status),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ReportEntity report) {
    // Check if current user is a citizen who owns this report
    final isOwnedByCitizen = widget.userType == UserType.citizen &&
        widget.currentUserId != null &&
        report.initiatorId == widget.currentUserId;

    return Column(
      children: [
        // Primary Actions Row
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.map_outlined,
                label: 'عرض على الخريطة',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onLocateOnMap(report);
                },
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 12),
            if (isOwnedByCitizen && widget.onChat != null)
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'الدردشة',
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onChat!(report);
                  },
                  isPrimary: true,
                  color: Colors.blue,
                ),
              )
            else if (widget.userType == UserType.coordinator)
              Expanded(
                child: _buildActionButton(
                  icon: Icons.assignment_ind,
                  label: 'تكليف مستجيب',
                  onPressed: () => _showResponderAssignmentModal(context),
                  isPrimary: true,
                  color: Colors.blue,
                ),
              )
            else if (widget.onChat != null)
              Expanded(
                child: _buildActionButton(
                  icon: Icons.assignment_turned_in,
                  label: 'الاستجابة',
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onAssignToSelf(report);
                  },
                  isPrimary: true,
                  color: Colors.green,
                ),
              ),
          ],
        ),

        // Secondary Actions Row (only for responders and coordinators)
        if (!isOwnedByCitizen && widget.userType != UserType.citizen) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.directions,
                  label: 'الاتجاهات',
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onGetDirections(report);
                  },
                  isPrimary: false,
                ),
              ),
              if (widget.onChat != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'الدردشة',
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onChat!(report);
                    },
                    isPrimary: false,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    Color? color,
  }) {
    // Get appropriate background color based on the provided color
    Color getBackgroundColor() {
      if (color == Colors.blue) return Colors.blue.shade600;
      if (color == Colors.green) return Colors.green.shade600;
      if (color == Colors.red) return Colors.red.shade600;
      if (color == Colors.orange) return Colors.orange.shade600;
      return Colors.blue.shade600; // default fallback
    }

    return isPrimary
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: getBackgroundColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          );
  }

  // Helper methods for UI elements
  Color _getSeverityColor(double severity) {
    if (severity >= 0.8) return Colors.red.shade600;
    if (severity >= 0.6) return Colors.orange.shade600;
    return Colors.yellow.shade700;
  }

  String _getSeverityLabel(double severity) {
    if (severity >= 0.8) return 'عالي';
    if (severity >= 0.6) return 'متوسط';
    return 'منخفض';
  }

  String _getEmergencyTypeArabic(String? type) {
    switch (type?.toUpperCase()) {
      case 'MEDICAL':
        return 'طبي';
      case 'FIRE':
        return 'حريق';
      case 'POLICE':
        return 'شرطة';
      case 'CIVIL':
        return 'مدني';
      case 'TRAFFIC':
        return 'مرور';
      default:
        return 'غير محدد';
    }
  }

  String _getEmergencySubTypeArabic(String? subType) {
    switch (subType?.toLowerCase()) {
      case 'theft':
        return 'سرقة';
      case 'murder':
        return 'قتل';
      case 'body':
        return 'جثة';
      case 'structure_fire':
        return 'حريق مبنى';
      case 'major_accident':
        return 'حادث كبير';
      case 'complaint':
        return 'شكوى';
      case 'warning':
        return 'تحذير';
      case 'explosion':
        return 'انفجار';
      default:
        return subType ?? 'غير محدد';
    }
  }

  Color _getRequestStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'accept':
        return Colors.green.shade600;
      case 'reject':
        return Colors.red.shade600;
      case 'cancelled':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getRequestStatusArabic(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'معلق';
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

  void _showResponderAssignmentModal(BuildContext context) {
    if (widget.assignmentsCubit == null) {
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
        report: widget.report,
        currentPosition: widget.currentPosition,
        availableResponders: widget.availableResponders,
        assignmentsCubit: widget.assignmentsCubit!,
      ),
    );
  }
}

// ============================================================================
// The rest of the file remains unchanged...
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
    print('👨‍💼 [COORDINATOR-UI] Starting assignment of ${responder.name} (ID: ${responder.id}) to report ${widget.report.id}');
    print('👨‍💼 [COORDINATOR-UI] Responder roles: ${responder.roles.map((r) => r.name).join(', ')}');
    
    // Defensive checks
    if (widget.assignmentsCubit == null) {
      print('❌ [COORDINATOR-UI] ERROR: assignmentsCubit is null!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: لا يمكن التكليف - المنطق غير مُهيّأ'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    if (widget.report.id <= 0) {
      print('❌ [COORDINATOR-UI] ERROR: Invalid report ID: ${widget.report.id}');
      return;
    }
    
    if (responder.id <= 0) {
      print('❌ [COORDINATOR-UI] ERROR: Invalid responder ID: ${responder.id}');
      return;
    }
    
    setState(() {
      _assigningResponderIds.add(responder.id);
    });

    try {
      print('👨‍💼 [COORDINATOR-UI] Calling cubit.createParticipationRequest...');
      await widget.assignmentsCubit!.createParticipationRequest(
        reportId: widget.report.id,
        responderId: responder.id,
      );

      print('✅ [COORDINATOR-UI] Assignment successful! Showing success message and closing modal');
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
      print('❌ [COORDINATOR-UI] Assignment failed: $e');
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
