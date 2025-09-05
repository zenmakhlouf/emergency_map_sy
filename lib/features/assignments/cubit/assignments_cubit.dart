import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../models/participation_request.dart';
import '../repository/assignment_service.dart';

part 'assignments_state.dart';

class AssignmentsCubit extends Cubit<AssignmentsState> {
  AssignmentsCubit() : super(const AssignmentsInitial()) {
    _initialize();
  }
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 20);

  /// Initialize cubit and start polling
  void _initialize() {
    // Backend handles filtering based on bearer token
    // Start polling immediately since auth is handled at network level
    loadAllAssignments();
    startPolling();
  }

  /// Safe emit that checks if cubit is not closed
  void _safeEmit(AssignmentsState state) {
    if (!isClosed) {
      emit(state);
    }
  }

  /// Load all participation requests (filtered by backend based on user role)
  /// - Coordinators get all requests in system
  /// - Responders get only requests where they are the responder
  /// - Citizens get only requests they initiated
  Future<void> loadAllAssignments() async {
    if (isClosed) return; // Don't proceed if cubit is closed

    _safeEmit(const AssignmentsLoading(operation: 'loading_assignments'));

    try {
      final allRequestsData =
          await AssignmentService.getAllParticipationRequests();

      if (isClosed) return; // Check again after async operation

      // Handle empty response gracefully
      if (allRequestsData.isEmpty) {
        _safeEmit(const AssignmentsEmpty());
        return;
      }

      final allRequests = allRequestsData
          .map((json) => ParticipationRequest.fromJson(json))
          .toList();

      if (isClosed) return; // Check again after processing

      if (allRequests.isEmpty) {
        _safeEmit(const AssignmentsEmpty());
      } else {
        // Backend has already filtered based on user role and token
        // For coordinators: all requests in system
        // For responders: only requests where they are responder
        // For citizens: only requests they initiated
        _safeEmit(AssignmentsLoaded(
          incomingRequests: allRequests, // Backend filtered
          outgoingRequests: allRequests, // Backend filtered
          allRequests: allRequests,
          lastUpdated: DateTime.now(),
        ));
      }
    } catch (e) {
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'load_all_assignments',
          error: e,
        ));
      }
    }
  }

  /// Load participation requests for specific report (for coordinators)
  Future<void> loadAssignmentsForReport(int reportId) async {
    if (isClosed) return;

    _safeEmit(
        const AssignmentsLoading(operation: 'loading_report_assignments'));

    try {
      final requestsData =
          await AssignmentService.getParticipationRequestsForReport(reportId);

      if (isClosed) return;

      // Handle empty response gracefully
      final requests = requestsData.isEmpty
          ? <ParticipationRequest>[]
          : requestsData
              .map((json) => ParticipationRequest.fromJson(json))
              .toList();

      _safeEmit(ReportAssignmentsLoaded(
        reportId: reportId,
        requests: requests,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'load_report_assignments',
          error: e,
        ));
      }
    }
  }

  /// Create a new participation request (responder requesting or coordinator assigning)
  Future<void> createParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    if (isClosed) return;

    _safeEmit(const AssignmentsLoading(operation: 'creating_request'));

    try {
      final requestData = await AssignmentService.createParticipationRequest(
        reportId: reportId,
        responderId: responderId,
      );

      if (isClosed) return;

      final newRequest = ParticipationRequest.fromJson(requestData);

      _safeEmit(AssignmentActionSuccess(
        message: 'تم إنشاء طلب المشاركة بنجاح',
        action: 'create',
        updatedRequest: newRequest,
      ));

      // Reload assignments to get updated state - but only if cubit is still active
      if (!isClosed) {
        await loadAllAssignments();
      }
    } catch (e) {
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'create_request',
          error: e,
        ));
      }
    }
  }

  /// Accept a participation request
  Future<void> acceptParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    if (isClosed) return;

    _safeEmit(const AssignmentsLoading(operation: 'accepting_request'));

    try {
      final requestData = await AssignmentService.acceptParticipationRequest(
        reportId: reportId,
        responderId: responderId,
      );

      if (isClosed) return;

      final updatedRequest = ParticipationRequest.fromJson(requestData);

      _safeEmit(AssignmentActionSuccess(
        message: 'تم قبول طلب المشاركة بنجاح',
        action: 'accept',
        updatedRequest: updatedRequest,
      ));

      // Reload assignments to get updated state - but only if cubit is still active
      // Note: This might not execute if navigation happens immediately after success
      if (!isClosed) {
        await loadAllAssignments();
      }
    } catch (e) {
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'accept_request',
          error: e,
        ));
      }
    }
  }

  /// Reject a participation request
  Future<void> rejectParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    if (isClosed) return;

    _safeEmit(const AssignmentsLoading(operation: 'rejecting_request'));

    try {
      final requestData = await AssignmentService.rejectParticipationRequest(
        reportId: reportId,
        responderId: responderId,
      );

      if (isClosed) return;

      final updatedRequest = ParticipationRequest.fromJson(requestData);

      _safeEmit(AssignmentActionSuccess(
        message: 'تم رفض طلب المشاركة',
        action: 'reject',
        updatedRequest: updatedRequest,
      ));

      // Reload assignments to get updated state
      if (!isClosed) {
        await loadAllAssignments();
      }
    } catch (e) {
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'reject_request',
          error: e,
        ));
      }
    }
  }

  /// Cancel a participation request
  Future<void> cancelParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    if (isClosed) return;

    _safeEmit(const AssignmentsLoading(operation: 'cancelling_request'));

    try {
      final requestData = await AssignmentService.cancelParticipationRequest(
        reportId: reportId,
        responderId: responderId,
      );

      if (isClosed) return;

      final updatedRequest = ParticipationRequest.fromJson(requestData);

      _safeEmit(AssignmentActionSuccess(
        message: 'تم إلغاء طلب المشاركة',
        action: 'cancel',
        updatedRequest: updatedRequest,
      ));

      // Reload assignments to get updated state
      if (!isClosed) {
        await loadAllAssignments();
      }
    } catch (e) {
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'cancel_request',
          error: e,
        ));
      }
    }
  }

  /// Start polling for assignment updates
  void startPolling() {
    stopPolling(); // Ensure no duplicate timers

    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      // Only poll if not currently loading to avoid conflicts and cubit is not closed
      if (state is! AssignmentsLoading && !isClosed) {
        _silentRefresh();
      }
    });
  }

  /// Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Silent refresh without emitting loading state
  Future<void> _silentRefresh() async {
    if (isClosed) return; // Don't proceed if cubit is closed

    try {
      final allRequestsData =
          await AssignmentService.getAllParticipationRequests();

      if (isClosed) return; // Check again after async operation

      // Handle null or empty response gracefully
      if (allRequestsData.isEmpty) {
        // If we currently have data loaded and now get empty, emit empty state
        if (state is AssignmentsLoaded) {
          final currentState = state as AssignmentsLoaded;
          if (currentState.allRequests.isNotEmpty) {
            _safeEmit(const AssignmentsEmpty());
          }
        }
        return;
      }

      final allRequests = allRequestsData
          .map((json) => ParticipationRequest.fromJson(json))
          .toList();

      if (isClosed) return; // Check again after processing

      // Only emit if data has changed and we're in a loaded state
      if (state is AssignmentsLoaded) {
        final currentState = state as AssignmentsLoaded;

        // Simple check for changes
        if (_hasDataChanged(currentState, allRequests)) {
          _safeEmit(AssignmentsLoaded(
            incomingRequests: allRequests, // Backend filtered
            outgoingRequests: allRequests, // Backend filtered
            allRequests: allRequests,
            lastUpdated: DateTime.now(),
          ));
        }
      } else if (state is AssignmentsEmpty && allRequests.isNotEmpty) {
        // If we were in empty state but now have data, emit loaded state
        _safeEmit(AssignmentsLoaded(
          incomingRequests: allRequests, // Backend filtered
          outgoingRequests: allRequests, // Backend filtered
          allRequests: allRequests,
          lastUpdated: DateTime.now(),
        ));
      }
    } catch (e) {
      // Silent failure - don't emit error during background refresh
      // Only log for debugging
      debugPrint('[AssignmentsCubit] Silent refresh failed: $e');
    }
  }

  /// Check if assignment data has changed
  bool _hasDataChanged(
    AssignmentsLoaded currentState,
    List<ParticipationRequest> newRequests,
  ) {
    return currentState.allRequests.length != newRequests.length ||
        !_listsEqual(currentState.allRequests, newRequests);
  }

  /// Helper to compare two lists of participation requests
  bool _listsEqual(
      List<ParticipationRequest> list1, List<ParticipationRequest> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || list1[i].status != list2[i].status) {
        return false;
      }
    }
    return true;
  }

  /// Refresh assignments manually
  Future<void> refresh() async {
    await loadAllAssignments();
  }

  /// Clear all data (for logout)
  void clear() {
    stopPolling();
    if (!isClosed) {
      _safeEmit(const AssignmentsInitial());
    }
  }

  @override
  Future<void> close() {
    stopPolling();
    return super.close();
  }
}
