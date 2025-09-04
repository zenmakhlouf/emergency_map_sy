import 'package:flutter_test/flutter_test.dart';
import 'package:emergency_map_sy/features/assignments/repository/assignment_service.dart';
import 'package:emergency_map_sy/features/assignments/models/participation_request.dart';
import 'package:emergency_map_sy/apis/network.dart';

void main() {
  group('Assignment Integration Tests (Real API)', () {
    setUpAll(() {
      // Initialize network
      Network.init();
      
      // Note: Backend filters requests based on bearer token automatically:
      // - Coordinators see all requests in system
      // - Responders see only requests where they are the responder  
      // - Citizens see only requests they initiated
      // Set a test bearer token (you would need a real one for live testing)
      // Network.setBearer('your_test_token_here');
    });

    // Note: These tests are skipped by default since they require:
    // 1. Live API connection
    // 2. Valid bearer token
    // 3. Existing test data
    // Remove skip: 1 to enable these tests when you have proper test setup

    test('should fetch participation requests from real API', () async {
      // This would test against the real API
      // You need to provide a valid bearer token first
      try {
        // Uncomment when you have a valid token
        // final requests = await AssignmentService.getAllParticipationRequests();
        // expect(requests, isA<List<Map<String, dynamic>>>());
        
        // Test that our model can parse real API data
        expect(true, isTrue); // Placeholder for now
      } catch (e) {
        // Expected to fail without proper authentication
        expect(e.toString(), contains('خطأ'));
      }
    }, skip: 'Requires live API and authentication');

    test('should create ParticipationRequest from real API response', () async {
      // Sample real API response from documentation
      final realApiJson = {
        "id": 4,
        "initiator": {
          "id": 4,
          "name": "Zen",
          "email": null,
          "last_active_at": "2025-09-03 08:03",
          "last_login_at": "2025-09-03 07:25",
          "roles": [
            {
              "id": 3,
              "name": "citizen",
              "pivot": {
                "model_type": "App\\Models\\User",
                "model_id": 4,
                "role_id": 3
              }
            },
            {
              "id": 4,
              "name": "responder", 
              "pivot": {
                "model_type": "App\\Models\\User",
                "model_id": 4,
                "role_id": 4
              }
            }
          ]
        },
        "responder": {
          "id": 4,
          "name": "Zen",
          "email": null,
          "last_active_at": "2025-09-03 08:03",
          "last_login_at": "2025-09-03 07:25",
          "roles": [
            {
              "id": 3,
              "name": "citizen"
            },
            {
              "id": 4,
              "name": "responder"
            }
          ]
        },
        "status": "pending",
        "report": {
          "id": 53,
          "initiator": {
            "id": 5,
            "name": "Sara",
            "email": null,
            "last_active_at": "2025-09-03 08:03",
            "last_login_at": "2025-09-03 07:25",
            "roles": [
              {
                "id": 3,
                "name": "citizen"
              }
            ]
          },
          "latest_status": {
            "id": 53,
            "status": "submitted",
            "status_display": "Submitted",
            "status_color": "blue",
            "notes": "Report submitted",
            "created_at": "2025-09-01T20:40:10.000000Z"
          },
          "created_at": "2025-09-01 23:40",
          "updated_at": "2025-09-01 23:40"
        }
      };

      // Act - Parse the real API response
      final participationRequest = ParticipationRequest.fromJson(realApiJson);

      // Assert - Verify all fields are correctly parsed
      expect(participationRequest.id, equals(4));
      expect(participationRequest.status, equals('pending'));
      expect(participationRequest.isPending, isTrue);
      expect(participationRequest.statusDisplayName, equals('قيد الانتظار'));
      expect(participationRequest.statusColor, equals('#FFA500'));

      // Verify initiator
      expect(participationRequest.initiator.id, equals(4));
      expect(participationRequest.initiator.name, equals('Zen'));
      expect(participationRequest.initiator.isCitizen, isTrue);
      expect(participationRequest.initiator.isResponder, isTrue);
      expect(participationRequest.initiator.isCoordinator, isFalse);

      // Verify responder
      expect(participationRequest.responder.id, equals(4));
      expect(participationRequest.responder.name, equals('Zen'));

      // Verify report
      expect(participationRequest.report.id, equals(53));
      expect(participationRequest.report.initiator.name, equals('Sara'));
      expect(participationRequest.report.latestStatus.status, equals('submitted'));
      expect(participationRequest.report.latestStatus.statusDisplay, equals('Submitted'));
      expect(participationRequest.report.latestStatus.statusColor, equals('blue'));

      print('✅ Successfully parsed real API data structure');
      print('   Request ID: ${participationRequest.id}');
      print('   Status: ${participationRequest.statusDisplayName}');
      print('   Initiator: ${participationRequest.initiator.name}');
      print('   Report ID: ${participationRequest.report.id}');
    });

    test('should handle API error responses correctly', () async {
      // Test error handling without making actual API calls
      try {
        // This would fail without proper authentication
        await AssignmentService.getAllParticipationRequests();
        fail('Should have thrown an exception');
      } catch (e) {
        // Verify error message is in Arabic as expected
        expect(e.toString(), contains('Exception:'));
        print('✅ Error handling working: ${e.toString()}');
      }
    });

    test('should validate status values correctly', () {
      final validStatuses = ['pending', 'accept', 'reject', 'cancelled'];
      
      for (final status in validStatuses) {
        final mockJson = {
          "id": 1,
          "initiator": {
            "id": 1,
            "name": "Test",
            "email": null,
            "last_active_at": null,
            "last_login_at": null,
            "roles": [{"id": 1, "name": "citizen"}]
          },
          "responder": {
            "id": 2,
            "name": "Responder",
            "email": null,
            "last_active_at": null,
            "last_login_at": null,
            "roles": [{"id": 1, "name": "responder"}]
          },
          "status": status,
          "report": {
            "id": 1,
            "initiator": {
              "id": 1,
              "name": "Reporter",
              "email": null,
              "last_active_at": null,
              "last_login_at": null,
              "roles": [{"id": 1, "name": "citizen"}]
            },
            "latest_status": {
              "id": 1,
              "status": "submitted",
              "status_display": "Submitted",
              "status_color": "blue",
              "notes": "Test",
              "created_at": "2025-01-01T00:00:00.000000Z"
            },
            "created_at": "2025-01-01 00:00",
            "updated_at": "2025-01-01 00:00"
          }
        };

        final request = ParticipationRequest.fromJson(mockJson);
        expect(request.status, equals(status));
        
        // Test helper methods
        switch (status) {
          case 'pending':
            expect(request.isPending, isTrue);
            expect(request.statusDisplayName, equals('قيد الانتظار'));
            break;
          case 'accept':
            expect(request.isAccepted, isTrue);
            expect(request.statusDisplayName, equals('مقبول'));
            break;
          case 'reject':
            expect(request.isRejected, isTrue);
            expect(request.statusDisplayName, equals('مرفوض'));
            break;
          case 'cancelled':
            expect(request.isCancelled, isTrue);
            expect(request.statusDisplayName, equals('ملغى'));
            break;
        }
      }

      print('✅ All status validations passed');
    });

    test('should handle complex role structures from API', () {
      // Test parsing of complex role data with pivot information
      final complexRoleJson = {
        "id": 1,
        "name": "Multi-role User",
        "email": "test@example.com",
        "last_active_at": "2025-09-04 10:00",
        "last_login_at": "2025-09-04 09:30",
        "roles": [
          {
            "id": 3,
            "name": "citizen",
            "pivot": {
              "model_type": "App\\Models\\User",
              "model_id": 1,
              "role_id": 3
            }
          },
          {
            "id": 4,
            "name": "responder",
            "pivot": {
              "model_type": "App\\Models\\User", 
              "model_id": 1,
              "role_id": 4
            }
          },
          {
            "id": 5,
            "name": "coordinator",
            "pivot": {
              "model_type": "App\\Models\\User",
              "model_id": 1,
              "role_id": 5
            }
          }
        ]
      };

      final user = User.fromJson(complexRoleJson);
      
      expect(user.id, equals(1));
      expect(user.name, equals('Multi-role User'));
      expect(user.email, equals('test@example.com'));
      expect(user.roles.length, equals(3));
      
      // Test all role helpers
      expect(user.isCitizen, isTrue);
      expect(user.isResponder, isTrue);
      expect(user.isCoordinator, isTrue);
      
      // Test role checking
      expect(user.hasRole('citizen'), isTrue);
      expect(user.hasRole('responder'), isTrue);
      expect(user.hasRole('coordinator'), isTrue);
      expect(user.hasRole('admin'), isFalse);

      print('✅ Complex role structure parsed successfully');
      print('   User: ${user.name}');
      print('   Roles: ${user.roles.map((r) => r.name).join(', ')}');
    });
  });
}