part of 'assignments_cubit.dart';

abstract class AssignmentsState extends Equatable {
  const AssignmentsState();

  @override
  List<Object?> get props => [];
}

class AssignmentsInitial extends AssignmentsState {
  const AssignmentsInitial();
}

class AssignmentsLoading extends AssignmentsState {
  final String operation;

  const AssignmentsLoading({required this.operation});

  @override
  List<Object?> get props => [operation];
}

class AssignmentsEmpty extends AssignmentsState {
  const AssignmentsEmpty();
}

class AssignmentsLoaded extends AssignmentsState {
  final List<ParticipationRequest> incomingRequests;
  final List<ParticipationRequest> outgoingRequests;
  final List<ParticipationRequest> allRequests;
  final DateTime lastUpdated;

  const AssignmentsLoaded({
    required this.incomingRequests,
    required this.outgoingRequests,
    required this.allRequests,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props =>
      [incomingRequests, outgoingRequests, allRequests, lastUpdated];

  // Helper getters for filtered requests
  List<ParticipationRequest> get pendingRequests => allRequests
      .where((request) =>
              request.isPending &&
              request.initiator.id !=
                  request.responder.id // Filter out self-assignments
          )
      .toList();

  List<ParticipationRequest> get acceptedRequests => allRequests
      .where((request) =>
              request.isAccepted &&
              request.initiator.id !=
                  request.responder.id // Filter out self-assignments
          )
      .toList();

  List<ParticipationRequest> get rejectedRequests => allRequests
      .where((request) =>
              request.isRejected &&
              request.initiator.id !=
                  request.responder.id // Filter out self-assignments
          )
      .toList();

  List<ParticipationRequest> get cancelledRequests => allRequests
      .where((request) =>
              request.isCancelled &&
              request.initiator.id !=
                  request.responder.id // Filter out self-assignments
          )
      .toList();
}

class ReportAssignmentsLoaded extends AssignmentsState {
  final int reportId;
  final List<ParticipationRequest> requests;
  final DateTime lastUpdated;

  const ReportAssignmentsLoaded({
    required this.reportId,
    required this.requests,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [reportId, requests, lastUpdated];

  // Helper getters for filtered requests (also filter out self-assignments)
  List<ParticipationRequest> get pendingRequests => requests
      .where((request) =>
          request.isPending && request.initiator.id != request.responder.id)
      .toList();

  List<ParticipationRequest> get acceptedRequests => requests
      .where((request) =>
          request.isAccepted && request.initiator.id != request.responder.id)
      .toList();

  List<ParticipationRequest> get rejectedRequests => requests
      .where((request) =>
          request.isRejected && request.initiator.id != request.responder.id)
      .toList();

  List<ParticipationRequest> get cancelledRequests => requests
      .where((request) =>
          request.isCancelled && request.initiator.id != request.responder.id)
      .toList();
}

class AssignmentActionSuccess extends AssignmentsState {
  final String message;
  final String action;
  final ParticipationRequest? updatedRequest;

  const AssignmentActionSuccess({
    required this.message,
    required this.action,
    this.updatedRequest,
  });

  @override
  List<Object?> get props => [message, action, updatedRequest];
}

class AssignedMode extends AssignmentsState {
  final ParticipationRequest activeAssignment;
  final bool isFirstTime;

  const AssignedMode({
    required this.activeAssignment,
    required this.isFirstTime,
  });

  @override
  List<Object?> get props => [activeAssignment, isFirstTime];
}

class AssignmentsError extends AssignmentsState {
  final String message;
  final String operation;
  final dynamic error;

  const AssignmentsError({
    required this.message,
    required this.operation,
    this.error,
  });

  @override
  List<Object?> get props => [message, operation, error];
}
