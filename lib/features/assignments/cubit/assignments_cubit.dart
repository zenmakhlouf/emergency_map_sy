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
  static const Duration _pollingInterval = Duration(seconds: 5);
  
  // Track assigned mode state
  bool _isAssigned = false;
  ParticipationRequest? _activeAssignment;
  
  // Getters for assigned mode state
  bool get isAssigned => _isAssigned;
  ParticipationRequest? get activeAssignment => _activeAssignment;

  /// Initialize cubit and start polling
  void _initialize() {
    // Backend handles filtering based on bearer token
    // Start polling immediately since auth is handled at network level
    // print('🔄 [AssignmentsCubit] Initializing - loading assignments and starting polling');
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

    print('📥 [AssignmentsCubit] Loading all assignments...');
    _safeEmit(const AssignmentsLoading(operation: 'loading_assignments'));

    try {
      final allRequestsData =
          await AssignmentService.getAllParticipationRequests();

      if (isClosed) return; // Check again after async operation

      print('📊 [AssignmentsCubit] Received ${allRequestsData.length} raw participation requests from API');

      // Handle empty response gracefully
      if (allRequestsData.isEmpty) {
        print('📭 [AssignmentsCubit] No participation requests found - emitting empty state');
        _safeEmit(const AssignmentsEmpty());
        return;
      }

      final allRequests = allRequestsData
          .map((json) => ParticipationRequest.fromJson(json))
          .toList();

      if (isClosed) return; // Check again after processing

      // HIGH PRIORITY: Check for assigned mode FIRST - before any other state emissions
      _checkAssignedMode(allRequests);

      if (allRequests.isEmpty) {
        print('📭 [AssignmentsCubit] All requests failed to parse - emitting empty state');
        _safeEmit(const AssignmentsEmpty());
      } else {
        // Backend has already filtered based on user role and token
        // For coordinators: all requests in system
        // For responders: only requests where they are responder
        // For citizens: only requests they initiated
        print('✅ [AssignmentsCubit] Successfully loaded ${allRequests.length} participation requests');
        for (var request in allRequests) {
          print('   📋 Request ID: ${request.id}, Status: ${request.status}, Report: ${request.report.id}, Responder: ${request.responder.name}');
        }
        
        _safeEmit(AssignmentsLoaded(
          incomingRequests: allRequests, // Backend filtered
          outgoingRequests: allRequests, // Backend filtered
          allRequests: allRequests,
          lastUpdated: DateTime.now(),
        ));
      }
    } catch (e) {
      print('❌ [AssignmentsCubit] Error loading assignments: $e');
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'load_all_assignments',
          error: e,
        ));
      }
    }
  }

  /// Load participation requests filtered by responder ID
  /// Useful for getting specific responder's requests
  Future<void> loadAssignmentsForResponder(int responderId) async {
    if (isClosed) return;

    _safeEmit(const AssignmentsLoading(operation: 'loading_responder_assignments'));

    try {
      final requestsData = await AssignmentService.getAllParticipationRequests(
        filters: {'responder_id': responderId},
      );

      if (isClosed) return;

      final requests = requestsData.isEmpty
          ? <ParticipationRequest>[]
          : requestsData
              .map((json) => ParticipationRequest.fromJson(json))
              .toList();

      _safeEmit(AssignmentsLoaded(
        incomingRequests: requests,
        outgoingRequests: requests,
        allRequests: requests,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'load_responder_assignments',
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

    print('📤 [COORDINATOR-CUBIT] Creating participation request - Report: $reportId, Responder: $responderId');
    _safeEmit(const AssignmentsLoading(operation: 'creating_request'));

    try {
      print('📤 [COORDINATOR-CUBIT] Calling AssignmentService.createParticipationRequest...');
      final requestData = await AssignmentService.createParticipationRequest(
        reportId: reportId,
        responderId: responderId,
      );
      print('📤 [COORDINATOR-CUBIT] Received response data, parsing...');

      if (isClosed) return;

      final newRequest = ParticipationRequest.fromJson(requestData);
      print('✅ [COORDINATOR-CUBIT] Created request successfully - ID: ${newRequest.id}, Status: ${newRequest.status}');

      _safeEmit(AssignmentActionSuccess(
        message: 'تم إنشاء طلب المشاركة بنجاح',
        action: 'create',
        updatedRequest: newRequest,
      ));

      // Reload assignments to get updated state - but only if cubit is still active
      if (!isClosed) {
        print('🔄 [COORDINATOR-CUBIT] Reloading assignments after creation');
        await loadAllAssignments();
      }
    } catch (e) {
      print('❌ [COORDINATOR-CUBIT] Failed to create participation request: $e');
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'create_request',
          error: e,
        ));
      }
    }
  }

  /// Accept a participation request using new API
  Future<void> acceptParticipationRequest({
    int? reportId, // Keep for backward compatibility  
    int? responderId, // Keep for backward compatibility
    int? requestId, // New parameter for new API
  }) async {
    if (isClosed) return;

    print('✅ [RESPONDER-CUBIT] Accepting participation request - Request ID: $requestId');
    _safeEmit(const AssignmentsLoading(operation: 'accepting_request'));

    try {
      if (requestId == null) {
        throw Exception('Accept: Request ID is required for the new API - reportId: $reportId, responderId: $responderId');
      }

      print('✅ [RESPONDER-CUBIT] Calling AssignmentService.acceptRequestStatus...');
      final requestData = await AssignmentService.acceptRequestStatus(
        requestId: requestId,
      );

      if (isClosed) return;

      print('✅ [RESPONDER-CUBIT] Parsing response data...');
      final updatedRequest = ParticipationRequest.fromJson(requestData);
      print('✅ [RESPONDER-CUBIT] Accepted request successfully - ID: ${updatedRequest.id}, Status: ${updatedRequest.status}');

      _safeEmit(AssignmentActionSuccess(
        message: 'تم قبول طلب المشاركة بنجاح',
        action: 'accept',
        updatedRequest: updatedRequest,
      ));

      // Reload assignments to get updated state - but only if cubit is still active
      // Note: This might not execute if navigation happens immediately after success
      if (!isClosed) {
        print('🔄 [RESPONDER-CUBIT] Reloading assignments after acceptance');
        await loadAllAssignments();
      }
    } catch (e) {
      print('❌ [RESPONDER-CUBIT] Failed to accept participation request: $e');
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'accept_request',
          error: e,
        ));
      }
    }
  }

  /// Reject a participation request using new API
  Future<void> rejectParticipationRequest({
    int? reportId, // Keep for backward compatibility
    int? responderId, // Keep for backward compatibility 
    int? requestId, // New parameter for new API
  }) async {
    if (isClosed) return;

    print('❌ [RESPONDER-CUBIT] Rejecting participation request - Request ID: $requestId');
    _safeEmit(const AssignmentsLoading(operation: 'rejecting_request'));

    try {
      if (requestId == null) {
        throw Exception('Reject: Request ID is required for the new API - reportId: $reportId, responderId: $responderId');
      }

      print('❌ [RESPONDER-CUBIT] Calling AssignmentService.rejectRequestStatus...');
      final requestData = await AssignmentService.rejectRequestStatus(
        requestId: requestId,
      );

      if (isClosed) return;

      print('❌ [RESPONDER-CUBIT] Parsing response data...');
      
      // Handle reject response which might be different structure
      if (requestData.containsKey('deleted') && requestData['deleted'] == true) {
        print('❌ [RESPONDER-CUBIT] Rejected request successfully - ID: ${requestData['id']}, Status: ${requestData['status']}');
        print('❌ [RESPONDER-CUBIT] Request deleted from backend: ${requestData['message']}');
        
        // For reject, create a minimal success response since request is deleted
        _safeEmit(AssignmentActionSuccess(
          message: 'تم رفض طلب المشاركة وحذفه بنجاح',
          action: 'reject',
          updatedRequest: null, // No request object since it's deleted
        ));
      } else {
        // Handle normal response with full request object
        final updatedRequest = ParticipationRequest.fromJson(requestData);
        print('❌ [RESPONDER-CUBIT] Rejected request successfully - ID: ${updatedRequest.id}, Status: ${updatedRequest.status}');

        _safeEmit(AssignmentActionSuccess(
          message: 'تم رفض طلب المشاركة',
          action: 'reject',
          updatedRequest: updatedRequest,
        ));
      }

      // Reload assignments to get updated state
      if (!isClosed) {
        print('🔄 [RESPONDER-CUBIT] Reloading assignments after rejection');
        await loadAllAssignments();
      }
    } catch (e) {
      print('❌ [RESPONDER-CUBIT] Failed to reject participation request: $e');
      if (!isClosed) {
        _safeEmit(AssignmentsError(
          message: e.toString(),
          operation: 'reject_request',
          error: e,
        ));
      }
    }
  }

  /// Cancel a participation request using new API
  Future<void> cancelParticipationRequest({
    int? reportId, // Keep for backward compatibility
    int? responderId, // Keep for backward compatibility
    int? requestId, // New parameter for new API
  }) async {
    if (isClosed) return;

    print('🚫 [RESPONDER-CUBIT] Cancelling participation request - Request ID: $requestId');
    _safeEmit(const AssignmentsLoading(operation: 'cancelling_request'));

    try {
      if (requestId == null) {
        throw Exception('Cancel: Request ID is required for the new API - reportId: $reportId, responderId: $responderId');
      }

      print('🚫 [RESPONDER-CUBIT] Calling AssignmentService.cancelRequestStatus...');
      final requestData = await AssignmentService.cancelRequestStatus(
        requestId: requestId,
      );

      if (isClosed) return;

      print('🚫 [RESPONDER-CUBIT] Parsing response data...');
      final updatedRequest = ParticipationRequest.fromJson(requestData);
      print('🚫 [RESPONDER-CUBIT] Cancelled request successfully - ID: ${updatedRequest.id}, Status: ${updatedRequest.status}');

      _safeEmit(AssignmentActionSuccess(
        message: 'تم إلغاء طلب المشاركة',
        action: 'cancel',
        updatedRequest: updatedRequest,
      ));

      // Reload assignments to get updated state
      if (!isClosed) {
        print('🔄 [RESPONDER-CUBIT] Reloading assignments after cancellation');
        await loadAllAssignments();
      }
    } catch (e) {
      print('❌ [RESPONDER-CUBIT] Failed to cancel participation request: $e');
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

    print('🔄 [AssignmentsCubit] Starting polling every ${_pollingInterval.inSeconds} seconds');
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      // Only poll if not currently loading to avoid conflicts and cubit is not closed
      if (state is! AssignmentsLoading && !isClosed) {
        print('🔄 [AssignmentsCubit] Polling tick ${timer.tick} - triggering silent refresh');
        _silentRefresh();
      } else {
        print('⏸️ [AssignmentsCubit] Polling tick ${timer.tick} - skipping (loading: ${state is AssignmentsLoading}, closed: $isClosed)');
      }
    });
  }

  /// Stop polling
  void stopPolling() {
    if (_pollingTimer != null) {
      print('⏹️ [AssignmentsCubit] Stopping polling timer');
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  /// Silent refresh without emitting loading state
  Future<void> _silentRefresh() async {
    if (isClosed) return; // Don't proceed if cubit is closed

    print('🔄 [AssignmentsCubit] Silent refresh started at ${DateTime.now()}');
    try {
      final allRequestsData =
          await AssignmentService.getAllParticipationRequests();

      if (isClosed) return; // Check again after async operation

      print('🔄 [AssignmentsCubit] Silent refresh received ${allRequestsData.length} requests');

      // Handle null or empty response gracefully
      if (allRequestsData.isEmpty) {
        print('🔄 [AssignmentsCubit] Empty response received');
        // If we currently have data loaded and now get empty, emit empty state
        if (state is AssignmentsLoaded) {
          final currentState = state as AssignmentsLoaded;
          if (currentState.allRequests.isNotEmpty) {
            print('📭 [AssignmentsCubit] Data changed from loaded to empty - emitting empty state');
            _safeEmit(const AssignmentsEmpty());
          }
        }
        return;
      }

      final allRequests = allRequestsData
          .map((json) => ParticipationRequest.fromJson(json))
          .toList();

      if (isClosed) return; // Check again after processing

      // HIGH PRIORITY: Check for assigned mode FIRST - before any other processing  
      _checkAssignedMode(allRequests);

      // print('🔄 [AssignmentsCubit] Parsed ${allRequests.length} requests successfully');

      // Only emit if data has changed and we're in a loaded state
      if (state is AssignmentsLoaded) {
        final currentState = state as AssignmentsLoaded;
        // print('🔄 [AssignmentsCubit] Current state has ${currentState.allRequests.length} requests');

        // Simple check for changes
        if (_hasDataChanged(currentState, allRequests)) {
          // print('🆕 [AssignmentsCubit] Data changed detected! Emitting updated state');
          // print('   📊 Previous count: ${currentState.allRequests.length}, New count: ${allRequests.length}');
          // for (var request in allRequests) {
          //   print('   🆕 Updated Request ID: ${request.id}, Status: ${request.status}, Report: ${request.report.id}');
          // }
          _safeEmit(AssignmentsLoaded(
            incomingRequests: allRequests, // Backend filtered
            outgoingRequests: allRequests, // Backend filtered
            allRequests: allRequests,
            lastUpdated: DateTime.now(),
          ));
        } else {
          print('🔄 [AssignmentsCubit] No changes detected - skipping update');
        }
      } else if (state is AssignmentsEmpty && allRequests.isNotEmpty) {
        print('🆕 [AssignmentsCubit] State changed from empty to loaded - emitting data');
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
      print('❌ [AssignmentsCubit] Silent refresh failed: $e');
      debugPrint('[AssignmentsCubit] Silent refresh failed: $e');
    }
  }

  /// Check for assigned mode - if responder has accepted participation request
  void _checkAssignedMode(List<ParticipationRequest> allRequests) {
    print('🔍 [AssignmentsCubit] Checking assigned mode for ${allRequests.length} requests');
    for (var request in allRequests) {
      print('   📋 Request ID: ${request.id}, Status: "${request.status}", IsAccepted: ${request.isAccepted}');
    }
    
    // Look for accepted participation request where current user is the responder
    ParticipationRequest? acceptedRequest;
    try {
      acceptedRequest = allRequests.firstWhere(
        (request) => request.isAccepted,
      );
      print('✅ [AssignmentsCubit] Found accepted request: ${acceptedRequest.id}');
    } catch (e) {
      // No accepted request found
      print('❌ [AssignmentsCubit] No accepted request found');
      acceptedRequest = null;
    }

    final wasAssigned = _isAssigned;
    final previousAssignment = _activeAssignment;
    
    if (acceptedRequest != null) {
      // Found accepted request - enter assigned mode
      if (!_isAssigned || _activeAssignment?.id != acceptedRequest.id) {
        _isAssigned = true;
        _activeAssignment = acceptedRequest;
        print('🎯 [AssignmentsCubit] ASSIGNED MODE ACTIVATED!');
        print('   📋 Report ID: ${acceptedRequest.report.id}');
        print('   👨‍🚒 Responder: ${acceptedRequest.responder.name} (ID: ${acceptedRequest.responder.id})');
        
        final isFirstTime = !wasAssigned;
        if (isFirstTime) {
          print('🆕 [AssignmentsCubit] First time entering assigned mode');
        } else {
          print('🔄 [AssignmentsCubit] Assignment changed from report ${previousAssignment?.report.id} to ${acceptedRequest.report.id}');
        }
        
        // Emit dedicated AssignedMode state for guaranteed UI response
        print('🚀 [AssignmentsCubit] Emitting AssignedMode state for UI response');
        _safeEmit(AssignedMode(
          activeAssignment: acceptedRequest,
          isFirstTime: isFirstTime,
        ));
      }
    } else {
      // No accepted request - exit assigned mode
      if (_isAssigned) {
        _isAssigned = false;
        _activeAssignment = null;
        print('🚫 [AssignmentsCubit] ASSIGNED MODE DEACTIVATED');
        print('   Previous assignment: Report ${previousAssignment?.report.id}');
        
        // Note: For deactivation, we'll handle this through normal state management
      }
    }
  }

  /// Check if assignment data has changed
  bool _hasDataChanged(
    AssignmentsLoaded currentState,
    List<ParticipationRequest> newRequests,
  ) {
    final lengthChanged = currentState.allRequests.length != newRequests.length;
    final contentChanged = !_listsEqual(currentState.allRequests, newRequests);
    
    if (lengthChanged || contentChanged) {
      print('📊 [AssignmentsCubit] Data change analysis:');
      print('   Length changed: $lengthChanged (${currentState.allRequests.length} -> ${newRequests.length})');
      print('   Content changed: $contentChanged');
      return true;
    }
    return false;
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
