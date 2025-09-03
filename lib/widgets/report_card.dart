import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/chat/models/chat_models.dart';
import '../features/auth/models/user_type.dart';
import '../services/geocoding_service.dart';
import 'package:latlong2/latlong.dart';

class ReportCard extends StatefulWidget {
  final EmergencyReport report;
  final ChatStatus? status;
  final UserType? userType;
  final LatLng? location;
  final LatLng? userLocation;
  final VoidCallback? onViewOnMap;
  final VoidCallback? onGetDirections;
  final VoidCallback? onAssignToMe;
  final VoidCallback? onStartChat;
  final VoidCallback? onClose;

  const ReportCard({
    super.key,
    required this.report,
    this.status,
    this.userType,
    this.location,
    this.userLocation,
    this.onViewOnMap,
    this.onGetDirections,
    this.onAssignToMe,
    this.onStartChat,
    this.onClose,
  });

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  GeocodingResult? _geocodingResult;
  bool _isLoadingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
    _loadGeocodingData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGeocodingData() async {
    if (widget.location == null) return;
    
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final result = await GeocodingService.reverseGeocode(
        widget.location!,
        language: 'ar,en',
      );
      
      if (mounted) {
        setState(() {
          _geocodingResult = result;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to load location details';
          _isLoadingLocation = false;
        });
      }
    }
  }

  double? _calculateDistance() {
    if (widget.location == null || widget.userLocation == null) return null;
    
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, widget.userLocation!, widget.location!);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 700),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReportContent(),
                              const SizedBox(height: 20),
                              _buildLocationSection(),
                              const SizedBox(height: 24),
                              _buildUserSpecificInfo(),
                              const SizedBox(height: 24),
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getStatusColor().withOpacity(0.1),
            _getStatusColor().withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.status!.statusDisplay.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'EMERGENCY REPORT',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              onPressed: widget.onClose,
              icon: Icon(
                Icons.close,
                color: Colors.grey.shade600,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                padding: const EdgeInsets.all(8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Report Name (Title)
        if (widget.report.name.isNotEmpty) ...[
          Text(
            widget.report.name.trim(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Report Description
        if (widget.report.description.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.report.description.trim(),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Emergency Details Text
        if (widget.report.text.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.shade50,
                  Colors.orange.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade100.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Emergency Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.report.text.trim(),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLocationSection() {
    final distance = _calculateDistance();
    
    return Container(
      width: double.infinity,
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
              Icon(
                Icons.location_on,
                color: Colors.red.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Location',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  fontSize: 14,
                ),
              ),
              if (distance != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${distance.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingLocation)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text('Loading location details...'),
              ],
            )
          else if (_locationError != null)
            Text(
              _locationError!,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 14,
              ),
            )
          else if (_geocodingResult != null)
            Text(
              _geocodingResult!.shortAddress,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            )
          else if (widget.location != null)
            Text(
              '${widget.location!.latitude.toStringAsFixed(4)}, ${widget.location!.longitude.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserSpecificInfo() {
    final userType = widget.userType;
    if (userType == null) return const SizedBox.shrink();

    switch (userType) {
      case UserType.citizen:
        return _buildCitizenInfo();
      case UserType.responder:
        return _buildResponderInfo();
      case UserType.coordinator:
        return _buildCoordinatorInfo();
    }
  }

  Widget _buildCitizenInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Citizen View',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This emergency report is visible to emergency responders in your area. Help is on the way.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponderInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_services,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Responder Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Evaluate the situation and take appropriate action. Coordinate with other responders if needed.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: Colors.purple.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Coordination Center',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor response progress and coordinate resources. Assign responders and manage communication.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final userType = widget.userType;
    
    return Column(
      children: [
        // Primary action row
        Row(
          children: [
            if (widget.onViewOnMap != null) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onViewOnMap,
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('View on Map'),
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
              const SizedBox(width: 12),
            ],
            
            // Responder/Coordinator specific assign button
            if (userType != UserType.citizen && widget.onAssignToMe != null) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onAssignToMe,
                  icon: const Icon(Icons.assignment_turned_in, size: 18),
                  label: Text(userType == UserType.responder ? 'Respond' : 'Assign to Me'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ],
        ),
        
        // Secondary action row for responders/coordinators
        if (userType != UserType.citizen) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.onGetDirections != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onGetDirections,
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Directions'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              if (widget.onStartChat != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onStartChat,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Copy report details to clipboard
                    final details = [
                      if (widget.report.name.isNotEmpty) widget.report.name,
                      if (widget.report.description.isNotEmpty) widget.report.description,
                      if (widget.report.text.isNotEmpty) widget.report.text,
                      if (_geocodingResult != null) _geocodingResult!.shortAddress,
                    ].join('\n\n');
                    
                    Clipboard.setData(ClipboardData(text: details));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report details copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getStatusColor() {
    if (widget.status == null) return Colors.red;
    return _getColorFromString(widget.status!.statusColor);
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow.shade700;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.red;
    }
  }
}

// Helper function to show report card
void showReportCard(
  BuildContext context, {
  required EmergencyReport report,
  ChatStatus? status,
  UserType? userType,
  LatLng? location,
  LatLng? userLocation,
  VoidCallback? onViewOnMap,
  VoidCallback? onGetDirections,
  VoidCallback? onAssignToMe,
  VoidCallback? onStartChat,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => ReportCard(
      report: report,
      status: status,
      userType: userType,
      location: location,
      userLocation: userLocation,
      onViewOnMap: onViewOnMap,
      onGetDirections: onGetDirections,
      onAssignToMe: onAssignToMe,
      onStartChat: onStartChat,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}