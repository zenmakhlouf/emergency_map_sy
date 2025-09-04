import 'package:flutter_test/flutter_test.dart';
import 'package:emergency_map_sy/features/assignments/models/participation_request.dart';

void main() {
  group('ParticipationRequest Model Tests', () {
    // Sample JSON data based on API documentation
    final sampleJson = {
      'id': 1,
      'initiator': {
        'id': 4,
        'name': 'Zen',
        'email': null,
        'last_active_at': '2025-09-03 08:03',
        'last_login_at': '2025-09-03 07:25',
        'roles': [
          {
            'id': 3,
            'name': 'citizen',
            'pivot': {
              'model_type': 'App\\Models\\User',
              'model_id': 4,
              'role_id': 3
            }
          },
          {
            'id': 4,
            'name': 'responder',
            'pivot': {
              'model_type': 'App\\Models\\User',
              'model_id': 4,
              'role_id': 4
            }
          }
        ]
      },
      'responder': {
        'id': 5,
        'name': 'Sara',
        'email': null,
        'last_active_at': '2025-09-03 13:02',
        'last_login_at': '2025-09-03 07:25',
        'roles': [
          {
            'id': 3,
            'name': 'citizen'
          },
          {
            'id': 4,
            'name': 'responder'
          }
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
          'roles': [
            {
              'id': 3,
              'name': 'citizen'
            }
          ]
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
      },
      'created_at': '2025-09-03T08:00:00.000000Z',
      'updated_at': '2025-09-03T08:00:00.000000Z'
    };

    test('should create ParticipationRequest from JSON correctly', () {
      // Act
      final participationRequest = ParticipationRequest.fromJson(sampleJson);

      // Assert
      expect(participationRequest.id, equals(1));
      expect(participationRequest.status, equals('pending'));
      expect(participationRequest.initiator.id, equals(4));
      expect(participationRequest.initiator.name, equals('Zen'));
      expect(participationRequest.responder.id, equals(5));
      expect(participationRequest.responder.name, equals('Sara'));
      expect(participationRequest.report.id, equals(45));
      expect(participationRequest.createdAt, isA<DateTime>());
      expect(participationRequest.updatedAt, isA<DateTime>());
    });

    test('should convert ParticipationRequest to JSON correctly', () {
      // Arrange
      final participationRequest = ParticipationRequest.fromJson(sampleJson);

      // Act
      final json = participationRequest.toJson();

      // Assert
      expect(json['id'], equals(1));
      expect(json['status'], equals('pending'));
      expect(json['initiator']['id'], equals(4));
      expect(json['responder']['id'], equals(5));
      expect(json['report']['id'], equals(45));
    });

    test('should handle null created_at and updated_at', () {
      // Arrange
      final jsonWithNulls = Map<String, dynamic>.from(sampleJson);
      jsonWithNulls['created_at'] = null;
      jsonWithNulls['updated_at'] = null;

      // Act
      final participationRequest = ParticipationRequest.fromJson(jsonWithNulls);

      // Assert
      expect(participationRequest.createdAt, isNull);
      expect(participationRequest.updatedAt, isNull);
    });

    test('should provide correct status helper getters', () {
      // Test pending status
      final pendingRequest = ParticipationRequest.fromJson(sampleJson);
      expect(pendingRequest.isPending, isTrue);
      expect(pendingRequest.isAccepted, isFalse);
      expect(pendingRequest.isRejected, isFalse);
      expect(pendingRequest.isCancelled, isFalse);

      // Test accept status
      final acceptJson = Map<String, dynamic>.from(sampleJson);
      acceptJson['status'] = 'accept';
      final acceptedRequest = ParticipationRequest.fromJson(acceptJson);
      expect(acceptedRequest.isPending, isFalse);
      expect(acceptedRequest.isAccepted, isTrue);
      expect(acceptedRequest.isRejected, isFalse);
      expect(acceptedRequest.isCancelled, isFalse);

      // Test reject status
      final rejectJson = Map<String, dynamic>.from(sampleJson);
      rejectJson['status'] = 'reject';
      final rejectedRequest = ParticipationRequest.fromJson(rejectJson);
      expect(rejectedRequest.isPending, isFalse);
      expect(rejectedRequest.isAccepted, isFalse);
      expect(rejectedRequest.isRejected, isTrue);
      expect(rejectedRequest.isCancelled, isFalse);

      // Test cancelled status
      final cancelJson = Map<String, dynamic>.from(sampleJson);
      cancelJson['status'] = 'cancelled';
      final cancelledRequest = ParticipationRequest.fromJson(cancelJson);
      expect(cancelledRequest.isPending, isFalse);
      expect(cancelledRequest.isAccepted, isFalse);
      expect(cancelledRequest.isRejected, isFalse);
      expect(cancelledRequest.isCancelled, isTrue);
    });

    test('should provide correct Arabic status display names', () {
      final testCases = [
        {'status': 'pending', 'expected': 'قيد الانتظار'},
        {'status': 'accept', 'expected': 'مقبول'},
        {'status': 'reject', 'expected': 'مرفوض'},
        {'status': 'cancelled', 'expected': 'ملغى'},
        {'status': 'unknown', 'expected': 'unknown'},
      ];

      for (final testCase in testCases) {
        final json = Map<String, dynamic>.from(sampleJson);
        json['status'] = testCase['status'];
        final request = ParticipationRequest.fromJson(json);
        
        expect(request.statusDisplayName, equals(testCase['expected']));
      }
    });

    test('should provide correct status colors', () {
      final testCases = [
        {'status': 'pending', 'expected': '#FFA500'},
        {'status': 'accept', 'expected': '#4CAF50'},
        {'status': 'reject', 'expected': '#F44336'},
        {'status': 'cancelled', 'expected': '#9E9E9E'},
        {'status': 'unknown', 'expected': '#000000'},
      ];

      for (final testCase in testCases) {
        final json = Map<String, dynamic>.from(sampleJson);
        json['status'] = testCase['status'];
        final request = ParticipationRequest.fromJson(json);
        
        expect(request.statusColor, equals(testCase['expected']));
      }
    });

    test('should support copyWith method', () {
      // Arrange
      final originalRequest = ParticipationRequest.fromJson(sampleJson);

      // Act
      final updatedRequest = originalRequest.copyWith(
        status: 'accept',
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(updatedRequest.id, equals(originalRequest.id));
      expect(updatedRequest.initiator, equals(originalRequest.initiator));
      expect(updatedRequest.responder, equals(originalRequest.responder));
      expect(updatedRequest.report, equals(originalRequest.report));
      expect(updatedRequest.status, equals('accept'));
      expect(updatedRequest.updatedAt, isNot(equals(originalRequest.updatedAt)));
    });

    test('should implement Equatable correctly', () {
      // Arrange
      final request1 = ParticipationRequest.fromJson(sampleJson);
      final request2 = ParticipationRequest.fromJson(sampleJson);
      final request3 = ParticipationRequest.fromJson(sampleJson).copyWith(status: 'accept');

      // Assert
      expect(request1, equals(request2));
      expect(request1, isNot(equals(request3)));
      expect(request1.hashCode, equals(request2.hashCode));
      expect(request1.hashCode, isNot(equals(request3.hashCode)));
    });
  });

  group('User Model Tests', () {
    final userJson = {
      'id': 4,
      'name': 'Zen',
      'email': 'zen@example.com',
      'last_active_at': '2025-09-03 08:03',
      'last_login_at': '2025-09-03 07:25',
      'roles': [
        {'id': 3, 'name': 'citizen'},
        {'id': 4, 'name': 'responder'},
        {'id': 5, 'name': 'coordinator'}
      ]
    };

    test('should create User from JSON correctly', () {
      // Act
      final user = User.fromJson(userJson);

      // Assert
      expect(user.id, equals(4));
      expect(user.name, equals('Zen'));
      expect(user.email, equals('zen@example.com'));
      expect(user.roles.length, equals(3));
      expect(user.roles[0].name, equals('citizen'));
    });

    test('should provide correct role helper methods', () {
      // Act
      final user = User.fromJson(userJson);

      // Assert
      expect(user.hasRole('citizen'), isTrue);
      expect(user.hasRole('responder'), isTrue);
      expect(user.hasRole('coordinator'), isTrue);
      expect(user.hasRole('admin'), isFalse);

      expect(user.isCitizen, isTrue);
      expect(user.isResponder, isTrue);
      expect(user.isCoordinator, isTrue);
    });

    test('should handle user with single role', () {
      // Arrange
      final citizenJson = {
        'id': 1,
        'name': 'Citizen User',
        'email': null,
        'last_active_at': null,
        'last_login_at': null,
        'roles': [
          {'id': 3, 'name': 'citizen'}
        ]
      };

      // Act
      final user = User.fromJson(citizenJson);

      // Assert
      expect(user.isCitizen, isTrue);
      expect(user.isResponder, isFalse);
      expect(user.isCoordinator, isFalse);
    });
  });

  group('EmergencyReport Model Tests', () {
    final reportJson = {
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
    };

    test('should create EmergencyReport from JSON correctly', () {
      // Act
      final report = EmergencyReport.fromJson(reportJson);

      // Assert
      expect(report.id, equals(45));
      expect(report.initiator.id, equals(9));
      expect(report.initiator.name, equals('Zenoo'));
      expect(report.latestStatus.status, equals('submitted'));
      expect(report.latestStatus.statusDisplay, equals('Submitted'));
      expect(report.latestStatus.statusColor, equals('blue'));
    });

    test('should parse datetime fields correctly', () {
      // Act
      final report = EmergencyReport.fromJson(reportJson);

      // Assert
      expect(report.createdAt, isA<DateTime>());
      expect(report.updatedAt, isA<DateTime>());
      expect(report.latestStatus.createdAt, isA<DateTime>());
    });
  });

  group('Real API Data Test', () {
    // This test uses actual API response structure from the documentation
    final realApiResponse = {
      "message": "request processed successfully",
      "data": {
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
      }
    };

    test('should parse real API response data correctly', () {
      // Act
      final participationRequest = ParticipationRequest.fromJson(
        realApiResponse['data'] as Map<String, dynamic>
      );

      // Assert
      expect(participationRequest.id, equals(4));
      expect(participationRequest.status, equals('pending'));
      expect(participationRequest.isPending, isTrue);
      
      // Check initiator
      expect(participationRequest.initiator.id, equals(4));
      expect(participationRequest.initiator.name, equals('Zen'));
      expect(participationRequest.initiator.hasRole('citizen'), isTrue);
      expect(participationRequest.initiator.hasRole('responder'), isTrue);
      
      // Check responder
      expect(participationRequest.responder.id, equals(4));
      expect(participationRequest.responder.name, equals('Zen'));
      
      // Check report
      expect(participationRequest.report.id, equals(53));
      expect(participationRequest.report.initiator.name, equals('Sara'));
      expect(participationRequest.report.latestStatus.status, equals('submitted'));
      expect(participationRequest.report.latestStatus.statusColor, equals('blue'));
    });

    test('should handle API response list format', () {
      // Simulate GET /request-participation response
      final apiListResponse = {
        "message": "success",
        "data": [
          realApiResponse['data'],
          {
            "id": 2,
            "initiator": (realApiResponse['data']! as Map<String, dynamic>)['initiator'],
            "responder": (realApiResponse['data']! as Map<String, dynamic>)['responder'],
            "status": "accept",
            "report": (realApiResponse['data']! as Map<String, dynamic>)['report']
          }
        ]
      };

      // Act
      final requestsList = (apiListResponse['data'] as List)
          .map((json) => ParticipationRequest.fromJson(json as Map<String, dynamic>))
          .toList();

      // Assert
      expect(requestsList.length, equals(2));
      expect(requestsList[0].status, equals('pending'));
      expect(requestsList[1].status, equals('accept'));
      expect(requestsList[0].isPending, isTrue);
      expect(requestsList[1].isAccepted, isTrue);
    });
  });
}