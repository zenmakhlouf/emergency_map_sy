import 'dart:math';
import 'package:emergency_map_sy/features/assignments/cubit/assignments_cubit.dart';
import 'package:emergency_map_sy/features/assignments/models/participation_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Add this to your ResponderAssignmentScreen or create a separate widget

class MockRequestGenerator {
  static final Random _random = Random();

  /// Generates mock participation request data that mimics real backend response
  static Map<String, dynamic> generateMockRequest() {
    final requestId = _random.nextInt(9999) + 1000;
    final reportId = _random.nextInt(999) + 100;
    final coordinatorId = _random.nextInt(50) + 1;
    final responderId = _random.nextInt(50) + 1;

    final now = DateTime.now();
    final reportCreatedAt =
        now.subtract(Duration(minutes: _random.nextInt(120)));

    return {
      "id": requestId,
      "initiator": {
        "id": coordinatorId,
        "name": _getRandomCoordinatorName(),
        "email": "coordinator$coordinatorId@emergency.sy",
        "password": null,
        "last_active_at":
            now.subtract(Duration(minutes: _random.nextInt(30))).toString(),
        "last_login_at":
            now.subtract(Duration(hours: _random.nextInt(8))).toString(),
        "created_at": "2025-08-30 19:54",
        "updated_at": now.toString(),
        "roles": [
          {
            "id": 5,
            "name": "coordinator",
            "guard_name": "web",
            "created_at": "2025-08-30T19:43:08.000000Z",
            "updated_at": "2025-08-30T19:43:08.000000Z",
            "pivot": {
              "model_type": "App\\Models\\User",
              "model_id": coordinatorId,
              "role_id": 5
            }
          }
        ]
      },
      "responder": {
        "id": responderId,
        "name": _getRandomResponderName(),
        "email": "responder$responderId@emergency.sy",
        "password": null,
        "last_active_at": now.toString(),
        "last_login_at":
            now.subtract(Duration(minutes: _random.nextInt(60))).toString(),
        "created_at": "2025-08-31 11:07",
        "updated_at": now.toString(),
        "roles": [
          {
            "id": 4,
            "name": "responder",
            "guard_name": "web",
            "created_at": "2025-08-30T19:43:08.000000Z",
            "updated_at": "2025-08-30T19:43:08.000000Z",
            "pivot": {
              "model_type": "App\\Models\\User",
              "model_id": responderId,
              "role_id": 4
            }
          }
        ]
      },
      "status": "pending",
      "report": {
        "id": reportId,
        "initiator": {
          "id": _random.nextInt(100) + 1,
          "name": _getRandomCitizenName(),
          "email": null,
          "password": null,
          "last_active_at": reportCreatedAt
              .add(Duration(minutes: _random.nextInt(30)))
              .toString(),
          "last_login_at": reportCreatedAt.toString(),
          "created_at": "2025-08-29 15:20",
          "updated_at": reportCreatedAt.toString(),
          "roles": [
            {
              "id": 3,
              "name": "citizen",
              "guard_name": "web",
              "created_at": "2025-08-30T19:43:08.000000Z",
              "updated_at": "2025-08-30T19:43:08.000000Z",
              "pivot": {
                "model_type": "App\\Models\\User",
                "model_id": _random.nextInt(100) + 1,
                "role_id": 3
              }
            }
          ]
        },
        "latest_status": {
          "id": _random.nextInt(1000),
          "status": _getRandomReportStatus(),
          "status_display": _getRandomReportStatusDisplay(),
          "status_color": _getRandomReportStatusColor(),
          "notes": _getRandomReportNotes(),
          "created_at": reportCreatedAt.toIso8601String()
        },
        "created_at": reportCreatedAt.toIso8601String(),
        "updated_at": reportCreatedAt
            .add(Duration(minutes: _random.nextInt(15)))
            .toIso8601String()
      },
      "created_at": now.toIso8601String(),
      "updated_at": now.toIso8601String()
    };
  }

  static String _getRandomCoordinatorName() {
    final names = [
      'منسق أحمد',
      'منسقة فاطمة',
      'د. محمد المنسق',
      'أ. سارة التنسيق',
      'منسق عمر',
      'منسقة زينب'
    ];
    return names[_random.nextInt(names.length)];
  }

  static String _getRandomResponderName() {
    final names = [
      'مستجيب خالد',
      'مستجيبة نور',
      'طارق المسعف',
      'ليلى الإطفاء',
      'مستجيب يوسف',
      'مستجيبة رنا'
    ];
    return names[_random.nextInt(names.length)];
  }

  static String _getRandomCitizenName() {
    final names = [
      'أحمد محمد',
      'فاطمة علي',
      'عمر الأحمد',
      'زينب حسن',
      'محمد العلي',
      'سارة محمود',
      'طارق الشام',
      'نور الدين'
    ];
    return names[_random.nextInt(names.length)];
  }

  static String _getRandomReportStatus() {
    final statuses = ['reported', 'investigating', 'in_progress', 'urgent'];
    return statuses[_random.nextInt(statuses.length)];
  }

  static String _getRandomReportStatusDisplay() {
    final displays = ['تم الإبلاغ', 'قيد التحقق', 'جارٍ التعامل', 'حالة طارئة'];
    return displays[_random.nextInt(displays.length)];
  }

  static String _getRandomReportStatusColor() {
    final colors = ['blue', 'orange', 'red', 'green'];
    return colors[_random.nextInt(colors.length)];
  }

  static String _getRandomReportNotes() {
    final notes = [
      'حادث مروري في منطقة مزدحمة',
      'حريق في مبنى سكني',
      'حالة طبية طارئة',
      'انقطاع كهرباء في الحي',
      'تسرب غاز في المنطقة',
      'حادث سقوط من مبنى',
      'حالة اختناق',
      'طلب إسعاف عاجل'
    ];
    return notes[_random.nextInt(notes.length)];
  }
}

// Mock Assignment Service for testing
class MockAssignmentService {
  static final List<Map<String, dynamic>> _mockRequests = [];

  /// Simulates creating a participation request
  static Future<Map<String, dynamic>> createMockParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1000)));

    // Generate mock request data
    final mockRequest = MockRequestGenerator.generateMockRequest();

    // Override with provided IDs
    mockRequest['report']['id'] = reportId;
    mockRequest['responder']['id'] = responderId;

    // Store in mock database
    _mockRequests.add(mockRequest);

    return mockRequest;
  }

  /// Get all mock requests (for testing the polling)
  static Future<List<Map<String, dynamic>>> getAllMockRequests() async {
    await Future.delayed(Duration(milliseconds: 200 + Random().nextInt(300)));
    return List<Map<String, dynamic>>.from(_mockRequests);
  }

  /// Update mock request status
  static Future<Map<String, dynamic>> updateMockRequestStatus({
    required int requestId,
    required String status,
  }) async {
    await Future.delayed(Duration(milliseconds: 300 + Random().nextInt(500)));

    final requestIndex =
        _mockRequests.indexWhere((req) => req['id'] == requestId);
    if (requestIndex != -1) {
      _mockRequests[requestIndex]['status'] = status;
      _mockRequests[requestIndex]['updated_at'] =
          DateTime.now().toIso8601String();
      return _mockRequests[requestIndex];
    }

    throw Exception('Request not found');
  }

  /// Clear all mock data
  static void clearMockData() {
    _mockRequests.clear();
  }
}

// Widget to add to your screen
class MockRequestButton extends StatelessWidget {
  const MockRequestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bug_report),
      tooltip: 'إرسال طلب تجريبي',
      onPressed: () => _sendMockRequest(context),
    );
  }

  void _sendMockRequest(BuildContext context) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري إرسال طلب تجريبي...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Generate random IDs for the mock request
      final reportId = Random().nextInt(999) + 100;
      final responderId = Random().nextInt(50) + 1;

      // Create mock request via the service
      final mockRequestData =
          await MockAssignmentService.createMockParticipationRequest(
        reportId: reportId,
        responderId: responderId,
      );

      // Parse the mock data into your model
      final mockRequest = ParticipationRequest.fromJson(mockRequestData);

      // Manually add it to the cubit state (simulating real-time update)
      final cubit = context.read<AssignmentsCubit>();
      final currentState = cubit.state;

      if (currentState is AssignmentsLoaded) {
        final updatedRequests = [...currentState.allRequests, mockRequest];
        cubit.emit(AssignmentsLoaded(
          incomingRequests: updatedRequests,
          outgoingRequests: updatedRequests,
          allRequests: updatedRequests,
          lastUpdated: DateTime.now(),
        ));
      } else if (currentState is AssignmentsEmpty) {
        cubit.emit(AssignmentsLoaded(
          incomingRequests: [mockRequest],
          outgoingRequests: [mockRequest],
          allRequests: [mockRequest],
          lastUpdated: DateTime.now(),
        ));
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال طلب تجريبي #${mockRequest.id}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إرسال الطلب التجريبي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
