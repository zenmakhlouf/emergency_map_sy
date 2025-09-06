import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/assignments/cubit/assignments_cubit.dart';
import '../features/assignments/models/participation_request.dart' as assignments;
import '../features/assignments/screens/focus_mode_screen.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/models/user_type.dart';
import '../features/users_location/cubit/userslocation_cubit.dart';
import '../features/chat/cubit/chat_cubit.dart';
import '../features/reports/cubit/reports_cubit.dart';
import '../features/reports/models/report.dart';
import 'package:latlong2/latlong.dart';

class PersistentEmergencyFAB extends StatefulWidget {
  final Widget child;
  final UserType? userType;

  const PersistentEmergencyFAB({
    super.key,
    required this.child,
    this.userType,
  });

  @override
  State<PersistentEmergencyFAB> createState() => _PersistentEmergencyFABState();
}

class _PersistentEmergencyFABState extends State<PersistentEmergencyFAB>
    with TickerProviderStateMixin {
  
  assignments.ParticipationRequest? _activeAssignment;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  bool _isVisible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _handleAssignmentState(AssignmentsState state) {
    debugPrint('🚨 [EMERGENCY_FAB] Assignment state change: ${state.runtimeType}');
    
    if (state is AssignedMode && 
        widget.userType == UserType.responder) {
      debugPrint('🚨 [EMERGENCY_FAB] Showing persistent emergency FAB for assignment: ${state.activeAssignment.report.id}');
      
      setState(() {
        _activeAssignment = state.activeAssignment;
        _isVisible = true;
      });
      
      _scaleController.forward();
      
      // Cancel any existing hide timer - FAB should persist until assignment completed/rejected
      _hideTimer?.cancel();
      debugPrint('🚨 [EMERGENCY_FAB] FAB will persist until assignment is completed or rejected');
      
    } else if (state is AssignmentsLoaded || 
               state is AssignmentActionSuccess) {
      // Check if we should hide the FAB - only hide on explicit rejection or completion
      bool shouldHideFAB = false;
      
      if (state is AssignmentActionSuccess) {
        if (state.action == 'reject') {
          debugPrint('🚨 [EMERGENCY_FAB] Assignment rejected - hiding FAB');
          shouldHideFAB = true;
        }
        // Note: On 'accept', the FAB should remain visible as user transitions to focus mode
      } else if (state is AssignmentsLoaded) {
        // Keep FAB visible if there are still accepted assignments
        final hasAcceptedAssignments = state.acceptedRequests.isNotEmpty;
        if (!hasAcceptedAssignments && _isVisible) {
          debugPrint('🚨 [EMERGENCY_FAB] No accepted assignments found - checking if should hide');
          shouldHideFAB = true;
        }
      }
      
      if (shouldHideFAB) {
        debugPrint('🚨 [EMERGENCY_FAB] Hiding emergency FAB');
        _hideEmergencyFAB();
      }
    }
  }

  void _hideEmergencyFAB() {
    _scaleController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
          _activeAssignment = null;
        });
      }
    });
  }

  void _navigateToFocusMode() {
    if (_activeAssignment == null) {
      debugPrint('🚨 [EMERGENCY_FAB] No active assignment to navigate to');
      return;
    }

    debugPrint('🚨 [EMERGENCY_FAB] Navigating to focus mode from persistent FAB');
    debugPrint('🚨 [EMERGENCY_FAB] Assignment ID: ${_activeAssignment!.id}');
    debugPrint('🚨 [EMERGENCY_FAB] Report ID: ${_activeAssignment!.report.id}');

    // Try to get full report data from reports cubit
    ReportEntity? fullReport;
    try {
      final reportsCubit = context.read<ReportsCubit>();
      final reportsState = reportsCubit.state;
      
      if (reportsState is ReportsSuccess) {
        fullReport = reportsState.reports.where(
          (report) => report.id == _activeAssignment!.report.id,
        ).firstOrNull;
      }
    } catch (e) {
      debugPrint('🚨 [EMERGENCY_FAB] Could not access reports cubit: $e');
    }

    if (fullReport == null) {
      debugPrint('🚨 [EMERGENCY_FAB] ❌ Cannot navigate: full report data not found');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: لم يتم العثور على بيانات البلاغ كاملة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get current location from auth cubit or use fallback
    final currentPosition = const LatLng(33.5138, 36.2765); // Damascus fallback

    debugPrint('🚨 [EMERGENCY_FAB] ✅ Full report data retrieved for report ${fullReport.id}');
    debugPrint('🚨 [EMERGENCY_FAB] Report location: ${fullReport.latitude}, ${fullReport.longitude}');

    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<ChatCubit>()),
              BlocProvider.value(value: context.read<UsersLocationCubit>()),
              BlocProvider.value(value: context.read<AuthCubit>()),
            ],
            child: FocusModeScreen(
              activeAssignment: _activeAssignment!,
              fullReport: fullReport!,      // We know it's not null due to the check above
              currentPosition: currentPosition,
            ),
          ),
        ),
      );
      
      debugPrint('🚨 [EMERGENCY_FAB] ✅ Successfully navigated to focus mode with full report data');
      
      // Optionally hide the FAB after navigation
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) _hideEmergencyFAB();
      });
      
    } catch (e, stackTrace) {
      debugPrint('🚨 [EMERGENCY_FAB] Navigation error: $e');
      debugPrint('🚨 [EMERGENCY_FAB] Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssignmentsCubit, AssignmentsState>(
      listener: (context, state) => _handleAssignmentState(state),
      child: Scaffold(
        body: widget.child,
        floatingActionButton: _isVisible && _activeAssignment != null
            ? AnimatedBuilder(
                animation: _scaleController,
                builder: (context, child) => Transform.scale(
                  scale: _scaleController.value,
                  child: _buildEmergencyFAB(),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildEmergencyFAB() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 80), // Position above normal FAB area
          child: FloatingActionButton.extended(
            onPressed: () {
              HapticFeedback.heavyImpact(); // Strong haptic for emergency action
              _navigateToFocusMode();
            },
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            elevation: 8,
            icon: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3 + 0.3 * _pulseController.value),
                    blurRadius: 8 + 8 * _pulseController.value,
                    spreadRadius: 2 + 4 * _pulseController.value,
                  ),
                ],
              ),
              child: const Icon(Icons.emergency, size: 24),
            ),
            label: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مهمة نشطة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getReportDisplayName(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getReportDisplayName() {
    if (_activeAssignment == null) return 'مهمة طوارئ';
    
    try {
      // Try to find the full report data from the reports cubit
      final reportsCubit = context.read<ReportsCubit>();
      final reportsState = reportsCubit.state;
      
      if (reportsState is ReportsSuccess) {
        // Find the matching report by ID
        final fullReport = reportsState.reports.firstWhere(
          (report) => report.id == _activeAssignment!.report.id,
          orElse: () => throw StateError('Report not found'),
        );
        
        // Extract the report name from the state
        final reportName = fullReport.state?.report?.name;
        if (reportName != null && reportName.isNotEmpty) {
         // debugPrint('🚨 [EMERGENCY_FAB] Using report name: $reportName');
          return reportName;
        }
      }
      
      // Fallback to report ID format
      debugPrint('🚨 [EMERGENCY_FAB] Using fallback format for report ${_activeAssignment!.report.id}');
      return 'بلاغ #${_activeAssignment!.report.id}';
    } catch (e) {
      debugPrint('🚨 [EMERGENCY_FAB] Error getting report name: $e');
      return 'بلاغ #${_activeAssignment!.report.id}';
    }
  }
}

