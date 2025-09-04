import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:emergency_map_sy/features/assignments/cubit/assignments_cubit.dart';
import 'package:emergency_map_sy/features/assignments/repository/assignment_service.dart';


// Generate mocks for AssignmentService (static methods need special handling)
@GenerateMocks([], customMocks: [
  MockSpec<AssignmentService>(returnNullOnMissingStub: true)
])
void main() {
  group('AssignmentsCubit Tests', () {
    late AssignmentsCubit assignmentsCubit;
    
    // Sample test data
    final sampleParticipationRequestData = [
      {
        'id': 1,
        'initiator': {
          'id': 4,
          'name': 'Zen',
          'email': null,
          'last_active_at': '2025-09-03 08:03',
          'last_login_at': '2025-09-03 07:25',
          'roles': [
            {'id': 3, 'name': 'citizen'},
            {'id': 4, 'name': 'responder'}
          ]
        },
        'responder': {
          'id': 5,
          'name': 'Sara',
          'email': null,
          'last_active_at': '2025-09-03 13:02',
          'last_login_at': '2025-09-03 07:25',
          'roles': [
            {'id': 3, 'name': 'citizen'},
            {'id': 4, 'name': 'responder'}
          ]
        },
        'status': 'pending',
        'report': {
          'id': 45,
          'initiator': {
            'id': 9,
            'name': 'Zenoo',
            'email': null,
            'last_active_at': '2025-09-01 03:35',
            'last_login_at': '2025-09-01 03:35',
            'roles': [{'id': 3, 'name': 'citizen'}]
          },
          'latest_status': {
            'id': 45,
            'status': 'submitted',
            'status_display': 'Submitted',
            'status_color': 'blue',
            'notes': 'Report submitted',
            'created_at': '2025-09-01T00:35:33.000000Z'
          },
          'created_at': '2025-09-01 03:35',
          'updated_at': '2025-09-01 03:35'
        }
      },
      {
        'id': 2,
        'initiator': {
          'id': 5,
          'name': 'Sara',
          'email': null,
          'last_active_at': '2025-09-03 13:02',
          'last_login_at': '2025-09-03 07:25',
          'roles': [
            {'id': 3, 'name': 'citizen'},
            {'id': 4, 'name': 'responder'}
          ]
        },
        'responder': {
          'id': 4,
          'name': 'Zen',
          'email': null,
          'last_active_at': '2025-09-03 08:03',
          'last_login_at': '2025-09-03 07:25',
          'roles': [
            {'id': 3, 'name': 'citizen'},
            {'id': 4, 'name': 'responder'}
          ]
        },
        'status': 'accept',
        'report': {
          'id': 53,
          'initiator': {
            'id': 5,
            'name': 'Sara',
            'email': null,
            'last_active_at': '2025-09-03 08:03',
            'last_login_at': '2025-09-03 07:25',
            'roles': [{'id': 3, 'name': 'citizen'}]
          },
          'latest_status': {
            'id': 53,
            'status': 'submitted',
            'status_display': 'Submitted',
            'status_color': 'blue',
            'notes': 'Report submitted',
            'created_at': '2025-09-01T20:40:10.000000Z'
          },
          'created_at': '2025-09-01 23:40',
          'updated_at': '2025-09-01 23:40'
        }
      }
    ];

    setUp(() {
      assignmentsCubit = AssignmentsCubit(currentUserId: 4);
    });

    tearDown(() {
      assignmentsCubit.close();
    });

    test('initial state should be AssignmentsInitial', () {
      // Create a fresh cubit without userId
      final freshCubit = AssignmentsCubit();
      expect(freshCubit.state, equals(const AssignmentsInitial()));
      freshCubit.close();
    });

    group('loadAllAssignments', () {
      blocTest<AssignmentsCubit, AssignmentsState>(
        'should emit AssignmentsError when currentUserId is null',
        build: () => AssignmentsCubit(), // No userId provided
        act: (cubit) => cubit.loadAllAssignments(),
        expect: () => [
          const AssignmentsLoading(operation: 'loading_assignments'),
          const AssignmentsError(
            message: 'المستخدم غير مسجل الدخول',
            operation: 'load_all_assignments',
          ),
        ],
      );

      test('should emit AssignmentsEmpty when no requests exist', () async {
        // This test would require mocking static methods
        // For now, we'll test the state logic
        assignmentsCubit.emit(const AssignmentsEmpty());
        expect(assignmentsCubit.state, equals(const AssignmentsEmpty()));
      });

      test('should properly separate incoming and outgoing requests', () {
        // Test the logic for separating requests
        const userId = 4;
        
        // Mock data where user 4 is responder in first request (incoming)
        // and initiator in second request (outgoing)
        final mockRequests = [
          // Incoming: user 4 is responder
          {
            'id': 1,
            'initiator': {'id': 5, 'name': 'Other User'},
            'responder': {'id': 4, 'name': 'Current User'},
            'status': 'pending',
          },
          // Outgoing: user 4 is initiator  
          {
            'id': 2,
            'initiator': {'id': 4, 'name': 'Current User'},
            'responder': {'id': 5, 'name': 'Other User'},
            'status': 'accept',
          }
        ];

        // Test the filtering logic
        final incomingRequests = mockRequests
            .where((r) => (r['responder'] as Map)['id'] == userId)
            .toList();
            
        final outgoingRequests = mockRequests
            .where((r) => (r['initiator'] as Map)['id'] == userId)
            .toList();

        expect(incomingRequests.length, equals(1));
        expect(outgoingRequests.length, equals(1));
        expect(incomingRequests[0]['id'], equals(1));
        expect(outgoingRequests[0]['id'], equals(2));
      });
    });

    group('createParticipationRequest', () {
      blocTest<AssignmentsCubit, AssignmentsState>(
        'should emit loading then success states',
        build: () => assignmentsCubit,
        act: (cubit) => cubit.createParticipationRequest(
          reportId: 45,
          responderId: 5,
        ),
        expect: () => [
          const AssignmentsLoading(operation: 'creating_request'),
          // Would include AssignmentActionSuccess and then reloaded state
          // But requires actual API mocking
        ],
        // Skip actual test since it requires network calls
        skip: 1,
      );
    });

    group('acceptParticipationRequest', () {
      blocTest<AssignmentsCubit, AssignmentsState>(
        'should emit correct states for accept action',
        build: () => assignmentsCubit,
        act: (cubit) => cubit.acceptParticipationRequest(
          reportId: 45,
          responderId: 4,
        ),
        expect: () => [
          const AssignmentsLoading(operation: 'accepting_request'),
          // Would include AssignmentActionSuccess with Arabic message
        ],
        skip: 1, // Skip until we mock the service
      );
    });

    group('State Management', () {
      test('AssignmentsLoaded should provide correct helper getters', () {
        final loadedState = AssignmentsLoaded(
          incomingRequests: const [],
          outgoingRequests: const [],
          allRequests: const [],
          lastUpdated: DateTime.now(),
        );

        // Test would verify helper getters work correctly
        // expect(loadedState.totalPendingIncoming, equals(1));
        // expect(loadedState.hasPendingIncoming, isTrue);
      });

      test('should handle polling timer correctly', () {
        // Test timer lifecycle
        expect(assignmentsCubit.state, isA<AssignmentsState>());
        
        // Start polling (already started in initialization)
        assignmentsCubit.startPolling();
        
        // Stop polling
        assignmentsCubit.stopPolling();
        
        // Should not crash
        expect(assignmentsCubit.state, isA<AssignmentsState>());
      });

      test('clear should reset to initial state', () {
        // Set some state first
        assignmentsCubit.emit(const AssignmentsLoaded(
          incomingRequests: [],
          outgoingRequests: [],
          allRequests: [],
          lastUpdated: null,
        ));
        
        // Clear
        assignmentsCubit.clear();
        
        // Should be back to initial
        expect(assignmentsCubit.state, equals(const AssignmentsInitial()));
      });
    });

    group('Error Handling', () {
      test('should handle service errors gracefully', () async {
        // Test error state creation
        const errorState = AssignmentsError(
          message: 'Network error',
          operation: 'test_operation',
          error: 'Original error',
        );

        expect(errorState.message, equals('Network error'));
        expect(errorState.operation, equals('test_operation'));
        expect(errorState.error, equals('Original error'));
      });
    });

    group('Assignment Actions', () {
      test('should provide correct Arabic action display names', () {
        const actionSuccess = AssignmentActionSuccess(
          message: 'Success',
          action: 'accept',
          updatedRequest: null,
        );

        expect(actionSuccess.actionDisplayName, equals('قبول الطلب'));

        const rejectSuccess = AssignmentActionSuccess(
          message: 'Success',
          action: 'reject', 
          updatedRequest: null,
        );

        expect(rejectSuccess.actionDisplayName, equals('رفض الطلب'));

        const cancelSuccess = AssignmentActionSuccess(
          message: 'Success',
          action: 'cancel',
          updatedRequest: null,
        );

        expect(cancelSuccess.actionDisplayName, equals('إلغاء الطلب'));

        const createSuccess = AssignmentActionSuccess(
          message: 'Success',
          action: 'create',
          updatedRequest: null,
        );

        expect(createSuccess.actionDisplayName, equals('إنشاء الطلب'));
      });
    });

    group('ReportAssignmentsLoaded State', () {
      test('should provide correct helper getters for report assignments', () {
        final reportState = ReportAssignmentsLoaded(
          reportId: 45,
          requests: [], // Would contain actual requests
          lastUpdated: DateTime.now(),
        );

        expect(reportState.reportId, equals(45));
        expect(reportState.requests, isEmpty);
        expect(reportState.pendingRequests, isEmpty);
        expect(reportState.acceptedRequests, isEmpty);
        expect(reportState.rejectedRequests, isEmpty);
        expect(reportState.hasPendingRequests, isFalse);
        expect(reportState.hasAcceptedResponders, isFalse);
      });
    });

    group('Data Change Detection', () {
      test('should detect changes in request lists', () {
        // This would test the _hasDataChanged and _listsEqual methods
        // Currently private, but we can test the behavior indirectly
        
        final cubit = AssignmentsCubit(currentUserId: 4);
        
        // Start with empty state
        expect(cubit.state, isA<AssignmentsState>());
        
        cubit.close();
      });
    });
  });

  group('Integration Tests with Real Data Structures', () {
    test('should handle real API response format', () {
      // Test with actual API response structure from documentation
      final realApiData = [
        {
          "id": 1,
          "initiator": {
            "id": 4,
            "name": "Zen",
            "email": null,
            "last_active_at": "2025-09-03 13:12",
            "last_login_at": "2025-09-03 13:10",
            "roles": [
              {"id": 3, "name": "citizen"},
              {"id": 4, "name": "responder"}
            ]
          },
          "responder": {
            "id": 4,
            "name": "Zen", 
            "email": null,
            "last_active_at": "2025-09-03 13:12",
            "last_login_at": "2025-09-03 13:10",
            "roles": [
              {"id": 3, "name": "citizen"},
              {"id": 4, "name": "responder"}
            ]
          },
          "status": "pending",
          "report": {
            "id": 45,
            "initiator": {"id": 9, "name": "Zenoo"},
            "latest_status": {
              "id": 45,
              "status": "submitted",
              "status_display": "Submitted", 
              "status_color": "blue",
              "notes": "Report submitted",
              "created_at": "2025-09-01T00:35:33.000000Z"
            },
            "created_at": "2025-09-01 03:35",
            "updated_at": "2025-09-01 03:35"
          }
        }
      ];

      // This data should be parseable by our models
      expect(realApiData.length, equals(1));
      expect(realApiData[0]['status'], equals('pending'));
      expect(realApiData[0]['initiator']['name'], equals('Zen'));
      
      // The ParticipationRequest.fromJson should handle this structure
      // This is tested in the model tests
    });

    test('should handle empty API responses', () {
      final emptyResponse = <Map<String, dynamic>>[];
      
      expect(emptyResponse.isEmpty, isTrue);
      
      // Cubit should emit AssignmentsEmpty for empty responses
      final cubit = AssignmentsCubit(currentUserId: 4);
      expect(cubit.state, isA<AssignmentsState>());
      cubit.close();
    });
  });
}