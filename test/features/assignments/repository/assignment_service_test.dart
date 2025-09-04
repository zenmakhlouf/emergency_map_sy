import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:emergency_map_sy/features/assignments/repository/assignment_service.dart';
import 'package:emergency_map_sy/apis/network.dart';

import 'assignment_service_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  group('AssignmentService Tests', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      Network.dio = mockDio;
    });

    group('getAllParticipationRequests', () {
      test('should return backend-filtered participation requests on success', () async {
        // Arrange
        final mockResponse = Response(
          requestOptions: RequestOptions(path: '/request-participation'),
          data: {
            'success': true,
            'message': null,
            'data': [
              {
                'id': 1,
                'initiator': {'id': 4, 'name': 'Zen'},
                'responder': {'id': 5, 'name': 'Sara'},
                'status': 'pending',
                'report': {'id': 45, 'initiator': {'name': 'Zenoo'}}
              },
              {
                'id': 2,
                'initiator': {'id': 5, 'name': 'Sara'},
                'responder': {'id': 4, 'name': 'Zen'},
                'status': 'accept',
                'report': {'id': 53, 'initiator': {'name': 'Ahmed'}}
              }
            ]
          },
          statusCode: 200,
        );

        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await AssignmentService.getAllParticipationRequests();

        // Assert
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(result.length, equals(2));
        expect(result[0]['id'], equals(1));
        expect(result[0]['status'], equals('pending'));
        expect(result[1]['id'], equals(2));
        expect(result[1]['status'], equals('accept'));
        
        verify(mockDio.get('https://help-map.saadalabyad.com/api/v1/request-participation')).called(1);
      });

      test('should throw exception when success is false', () async {
        // Arrange
        final mockResponse = Response(
          requestOptions: RequestOptions(path: '/request-participation'),
          data: {
            'success': false,
            'message': 'Unauthorized access',
            'data': null
          },
          statusCode: 200,
        );

        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => AssignmentService.getAllParticipationRequests(),
          throwsA(predicate((e) => e.toString().contains('Unauthorized access'))),
        );
      });

      test('should handle DioException with 401 status code', () async {
        // Arrange
        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/request-participation'),
              response: Response(
                requestOptions: RequestOptions(path: '/request-participation'),
                statusCode: 401,
                data: {'message': 'Unauthorized'},
              ),
              type: DioExceptionType.badResponse,
            ));

        // Act & Assert
        expect(
          () => AssignmentService.getAllParticipationRequests(),
          throwsA(predicate((e) => e.toString().contains('غير مخول - الرجاء تسجيل الدخول مرة أخرى'))),
        );
      });

      test('should handle connection timeout', () async {
        // Arrange
        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/request-participation'),
              type: DioExceptionType.connectionTimeout,
            ));

        // Act & Assert
        expect(
          () => AssignmentService.getAllParticipationRequests(),
          throwsA(predicate((e) => e.toString().contains('انتهت مهلة الاتصال - تحقق من الإنترنت'))),
        );
      });
    });

    group('getParticipationRequestsForReport', () {
      test('should return backend-filtered requests for specific report', () async {
        // Arrange
        const reportId = 45;
        final mockResponse = Response(
          requestOptions: RequestOptions(path: '/request-participation/45'),
          data: {
            'success': true,
            'message': null,
            'data': [
              {
                'id': 1,
                'initiator': {'id': 4, 'name': 'Zen'},
                'responder': {'id': 5, 'name': 'Sara'},
                'status': 'pending',
                'report': {'id': 45, 'initiator': {'name': 'Zenoo'}}
              }
            ]
          },
          statusCode: 200,
        );

        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await AssignmentService.getParticipationRequestsForReport(reportId);

        // Assert
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(result.length, equals(1));
        expect(result[0]['report']['id'], equals(45));
        
        verify(mockDio.get('https://help-map.saadalabyad.com/api/v1/request-participation/45')).called(1);
      });

      test('should handle 404 error for non-existent report', () async {
        // Arrange
        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/request-participation/999'),
              response: Response(
                requestOptions: RequestOptions(path: '/request-participation/999'),
                statusCode: 404,
                data: {'message': 'Report not found'},
              ),
              type: DioExceptionType.badResponse,
            ));

        // Act & Assert
        expect(
          () => AssignmentService.getParticipationRequestsForReport(999),
          throwsA(predicate((e) => e.toString().contains('البيانات المطلوبة غير موجودة'))),
        );
      });
    });

    group('createParticipationRequest', () {
      test('should create participation request successfully', () async {
        // Arrange
        const reportId = 45;
        const responderId = 5;
        final mockResponse = Response(
          requestOptions: RequestOptions(path: '/request-participation/45'),
          data: {
            'message': 'request processed successfully',
            'data': {
              'id': 1,
              'initiator': {'id': 4, 'name': 'Zen'},
              'responder': {'id': 5, 'name': 'Sara'},
              'status': 'pending',
              'report': {'id': 45, 'initiator': {'name': 'Zenoo'}}
            }
          },
          statusCode: 200,
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await AssignmentService.createParticipationRequest(
          reportId: reportId,
          responderId: responderId,
        );

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result['id'], equals(1));
        expect(result['status'], equals('pending'));
        
        verify(mockDio.post(
          'https://help-map.saadalabyad.com/api/v1/request-participation/45',
          data: {'responder_id': 5}
        )).called(1);
      });

      test('should handle server error when creating request', () async {
        // Arrange
        when(mockDio.post(any, data: anyNamed('data')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/request-participation/45'),
              response: Response(
                requestOptions: RequestOptions(path: '/request-participation/45'),
                statusCode: 500,
                data: {'message': 'Internal server error'},
              ),
              type: DioExceptionType.badResponse,
            ));

        // Act & Assert
        expect(
          () => AssignmentService.createParticipationRequest(
            reportId: 45,
            responderId: 5,
          ),
          throwsA(predicate((e) => e.toString().contains('خطأ في الخادم - الرجاء المحاولة لاحقاً'))),
        );
      });
    });

    group('updateParticipationRequestStatus', () {
      test('should update status to accept successfully', () async {
        // Arrange
        const reportId = 45;
        const responderId = 5;
        const status = 'accept';
        final mockResponse = Response(
          requestOptions: RequestOptions(path: '/request-participation/45'),
          data: {
            'message': 'request processed successfully',
            'data': {
              'id': 1,
              'initiator': {'id': 4, 'name': 'Zen'},
              'responder': {'id': 5, 'name': 'Sara'},
              'status': 'accept',
              'report': {'id': 45, 'initiator': {'name': 'Zenoo'}}
            }
          },
          statusCode: 200,
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await AssignmentService.updateParticipationRequestStatus(
          reportId: reportId,
          responderId: responderId,
          status: status,
        );

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result['status'], equals('accept'));
        
        verify(mockDio.post(
          'https://help-map.saadalabyad.com/api/v1/request-participation/45',
          data: {'responder_id': 5, 'status': 'accept'}
        )).called(1);
      });

      test('should throw exception for invalid status', () async {
        // Act & Assert
        expect(
          () => AssignmentService.updateParticipationRequestStatus(
            reportId: 45,
            responderId: 5,
            status: 'invalid_status',
          ),
          throwsA(predicate((e) => e.toString().contains('حالة غير صحيحة: invalid_status'))),
        );
      });

      test('should handle 422 validation error', () async {
        // Arrange
        when(mockDio.post(any, data: anyNamed('data')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/request-participation/45'),
              response: Response(
                requestOptions: RequestOptions(path: '/request-participation/45'),
                statusCode: 422,
                data: {'message': 'Validation failed'},
              ),
              type: DioExceptionType.badResponse,
            ));

        // Act & Assert
        expect(
          () => AssignmentService.updateParticipationRequestStatus(
            reportId: 45,
            responderId: 5,
            status: 'accept',
          ),
          throwsA(predicate((e) => e.toString().contains('Validation failed'))),
        );
      });
    });

    group('shorthand methods', () {
      test('acceptParticipationRequest should call updateParticipationRequestStatus with accept', () async {
        // Arrange
        final mockResponse = Response(
          requestOptions: RequestOptions(path: '/request-participation/45'),
          data: {
            'data': {'id': 1, 'status': 'accept'}
          },
          statusCode: 200,
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await AssignmentService.acceptParticipationRequest(
          reportId: 45,
          responderId: 5,
        );

        // Assert
        expect(result['status'], equals('accept'));
        verify(mockDio.post(
          'https://help-map.saadalabyad.com/api/v1/request-participation/45',
          data: {'responder_id': 5, 'status': 'accept'}
        )).called(1);
      });

      test('rejectParticipationRequest should call updateParticipationRequestStatus with reject', () async {
        // Arrange
        final mockResponse = Response(
          requestOptions: RequestOptions(path: '/request-participation/45'),
          data: {
            'data': {'id': 1, 'status': 'reject'}
          },
          statusCode: 200,
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await AssignmentService.rejectParticipationRequest(
          reportId: 45,
          responderId: 5,
        );

        // Assert
        expect(result['status'], equals('reject'));
        verify(mockDio.post(
          'https://help-map.saadalabyad.com/api/v1/request-participation/45',
          data: {'responder_id': 5, 'status': 'reject'}
        )).called(1);
      });

      test('cancelParticipationRequest should call updateParticipationRequestStatus with cancelled', () async {
        // Arrange
        final mockResponse = Response(
          requestOptions: RequestOptions(path: '/request-participation/45'),
          data: {
            'data': {'id': 1, 'status': 'cancelled'}
          },
          statusCode: 200,
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await AssignmentService.cancelParticipationRequest(
          reportId: 45,
          responderId: 5,
        );

        // Assert
        expect(result['status'], equals('cancelled'));
        verify(mockDio.post(
          'https://help-map.saadalabyad.com/api/v1/request-participation/45',
          data: {'responder_id': 5, 'status': 'cancelled'}
        )).called(1);
      });
    });

    group('error handling', () {
      test('should handle connection error', () async {
        // Arrange
        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/request-participation'),
              type: DioExceptionType.connectionError,
            ));

        // Act & Assert
        expect(
          () => AssignmentService.getAllParticipationRequests(),
          throwsA(predicate((e) => e.toString().contains('خطأ في الاتصال - تحقق من الإنترنت'))),
        );
      });

      test('should handle 403 forbidden error', () async {
        // Arrange
        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/request-participation'),
              response: Response(
                requestOptions: RequestOptions(path: '/request-participation'),
                statusCode: 403,
                data: {'message': 'Forbidden'},
              ),
              type: DioExceptionType.badResponse,
            ));

        // Act & Assert
        expect(
          () => AssignmentService.getAllParticipationRequests(),
          throwsA(predicate((e) => e.toString().contains('ليس لديك صلاحية للوصول لهذا المورد'))),
        );
      });

      test('should handle generic exception', () async {
        // Arrange
        when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
            .thenThrow(Exception('Something went wrong'));

        // Act & Assert
        expect(
          () => AssignmentService.getAllParticipationRequests(),
          throwsA(predicate((e) => e.toString().contains('خطأ غير متوقع: Exception: Something went wrong'))),
        );
      });
    });
  });
}