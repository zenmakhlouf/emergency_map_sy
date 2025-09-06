import 'package:dio/dio.dart';
import '../../../apis/network.dart';
import '../../../utils/urls.dart';

class AssignmentService {
  /// Get all participation requests with optional filtering
  /// - Coordinators: Returns all requests in the system
  /// - Responders: Returns only requests where they are the responder
  /// - Citizens: Returns only requests they initiated
  /// Backend handles role-based filtering based on the bearer token
  /// Additional filters can be applied (e.g., responder_id)
  static Future<List<Map<String, dynamic>>>
      getAllParticipationRequests({Map<String, dynamic>? filters}) async {
    try {
      String url = '${Urls.baseUrl}/request-participation';
      
      // Add query parameters for filters
      if (filters != null && filters.isNotEmpty) {
        final queryParams = <String>[];
        filters.forEach((key, value) {
          if (value != null) {
            queryParams.add('filters[$key]=$value');
          }
        });
        if (queryParams.isNotEmpty) {
          url += '?' + queryParams.join('&');
        }
      }
      
      // print('🌐 [AssignmentService] API Call: GET $url');
      final response = await Network.getData(url: url);
      // print('🌐 [AssignmentService] API Response Status: ${response.statusCode}');

      // Handle different success response formats
      final responseData = response.data;
      if (responseData == null) {
        return []; // Return empty list if responseData is null
      }

      final data = responseData['data'];

      // More robust null and type checking
      if (data == null) {
        return []; // Return empty list if data is null
      }

      // Handle new API structure with 'participation_requests' array
      List<dynamic> requestsList;
      if (data is Map<String, dynamic> && data.containsKey('participation_requests')) {
        requestsList = data['participation_requests'] as List<dynamic>? ?? [];
        // print('🌐 [AssignmentService] Found participation_requests array with ${requestsList.length} items');
      } else if (data is List) {
        requestsList = data;
        // print('🌐 [AssignmentService] Data is direct list with ${requestsList.length} items');
      } else {
        // print('⚠️ [AssignmentService] Warning: Unexpected data structure: ${data.runtimeType}: $data');
        return [];
      }

      // Safe cast with additional null checking
      final result = List<Map<String, dynamic>>.from(
          requestsList.where((item) => item != null && item is Map<String, dynamic>));
      // print('🌐 [AssignmentService] Returning ${result.length} valid participation requests');
      return result;
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      print('Unexpected error in getAllParticipationRequests: $e');
      throw Exception('خطأ غير متوقع: ${e.toString()}');
    }
  }

  /// Get participation requests for specific report based on user role
  /// - Coordinators: See all requests for the report
  /// - Responders: See only their own requests for the report
  /// - Citizens: See only requests for reports they initiated
  /// Backend handles filtering based on the bearer token
  static Future<List<Map<String, dynamic>>> getParticipationRequestsForReport(
      int reportId) async {
    try {
      final response = await Network.getData(
        url: '${Urls.baseUrl}/request-participation/$reportId',
      );

      // Handle different success response formats
      final responseData = response.data;
      if (responseData == null) {
        return []; // Return empty list if responseData is null
      }

      final data = responseData['data'];

      // More robust null and type checking
      if (data == null) {
        return []; // Return empty list if data is null
      }

      // Check if data is actually a List
      if (data is! List) {
        print('Warning: Expected List but got ${data.runtimeType}: $data');
        return []; // Return empty list if data is not a List
      }

      // Safe cast with additional null checking
      return List<Map<String, dynamic>>.from(
          data.where((item) => item != null && item is Map<String, dynamic>));
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      print('Unexpected error in getParticipationRequestsForReport: $e');
      throw Exception('خطأ غير متوقع: ${e.toString()}');
    }
  }

  /// Create a new participation request
  /// For responders: request to respond to an emergency
  /// For coordinators: assign a responder to an emergency
  static Future<Map<String, dynamic>> createParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    try {
      final url = '${Urls.baseUrl}/request-participation/$reportId';
      final body = {'responder_id': responderId};
      print('📤 [COORDINATOR-CREATE] POST $url with body: $body');
      
      final response = await Network.postData(
        url: url,
        body: body,
      );
      
      print('📤 [COORDINATOR-CREATE] Response status: ${response.statusCode}');

      // Handle different success response formats
      final responseData = response.data;
      if (responseData == null) {
        throw Exception('No response data received from server');
      }

      final data = responseData['data'];
      if (data != null && data is Map<String, dynamic>) {
        // Handle new API response structure with participation_request wrapper
        if (data.containsKey('participation_request')) {
          final result = data['participation_request'] as Map<String, dynamic>;
          print('✅ [COORDINATOR-CREATE] Success! Created request ID: ${result['id']}, Status: ${result['status']}');
          print('📋 [COORDINATOR-CREATE] Request details: Report=${result['report_id']}, Responder=${result['responder_id']}');
          return result;
        } else {
          print('📋 [COORDINATOR-CREATE] Direct data response: ${data['id']}');
          return data;
        }
      } else {
        print('❌ [COORDINATOR-CREATE] Failed: ${responseData['message']} | Full response: $responseData');
        throw Exception(responseData['message'] ??
            'Failed to create participation request');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      print('Unexpected error in createParticipationRequest: $e');
      throw Exception('خطأ غير متوقع: ${e.toString()}');
    }
  }

  /// Update participation request status
  /// Status options: 'accept', 'reject', 'cancelled'
  static Future<Map<String, dynamic>> updateParticipationRequestStatus({
    required int reportId,
    required int responderId,
    required String status,
  }) async {
    try {
      if (!['accept', 'reject', 'cancelled'].contains(status)) {
        throw Exception('حالة غير صحيحة: $status');
      }

      final response = await Network.postData(
        url: '${Urls.baseUrl}/request-participation/$reportId',
        body: {
          'responder_id': responderId,
          'status': status,
        },
      );

      // Handle different success response formats
      final responseData = response.data;
      if (responseData == null) {
        throw Exception('No response data received from server');
      }

      final data = responseData['data'];
      if (data != null && data is Map<String, dynamic>) {
        // Handle new API response structure with participation_request wrapper
        if (data.containsKey('participation_request')) {
          return data['participation_request'] as Map<String, dynamic>;
        } else {
          return data;
        }
      } else {
        throw Exception(responseData['message'] ??
            'Failed to update participation request status');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      print('Unexpected error in updateParticipationRequestStatus: $e');
      throw Exception('خطأ غير متوقع: ${e.toString()}');
    }
  }

  /// Accept a participation request (shorthand method)
  static Future<Map<String, dynamic>> acceptParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    return await updateParticipationRequestStatus(
      reportId: reportId,
      responderId: responderId,
      status: 'accept',
    );
  }

  /// Reject a participation request (shorthand method)
  static Future<Map<String, dynamic>> rejectParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    return await updateParticipationRequestStatus(
      reportId: reportId,
      responderId: responderId,
      status: 'reject',
    );
  }

  /// Cancel a participation request (shorthand method)
  static Future<Map<String, dynamic>> cancelParticipationRequest({
    required int reportId,
    required int responderId,
  }) async {
    return await updateParticipationRequestStatus(
      reportId: reportId,
      responderId: responderId,
      status: 'cancelled',
    );
  }

  /// NEW API: Update participation request status using the new endpoint
  /// POST /request-participation/reports/{request_id}
  /// Status options: 'accept', 'reject', 'cancel'
  static Future<Map<String, dynamic>> updateRequestStatus({
    required int requestId,
    required String status,
  }) async {
    try {
      if (!['accept', 'reject', 'cancel'].contains(status)) {
        throw Exception('حالة غير صحيحة: $status');
      }

      final url = '${Urls.baseUrl}/request-participation/reports/$requestId';
      final body = {'status': status};
      print('🔄 [RESPONDER-STATUS] POST $url with body: $body');
      
      final response = await Network.postData(
        url: url,
        body: body,
      );
      
      print('🔄 [RESPONDER-STATUS] Response status: ${response.statusCode}');

      // Handle response
      final responseData = response.data;
      if (responseData == null) {
        throw Exception('No response data received from server');
      }

      final data = responseData['data'];
      if (data != null && data is Map<String, dynamic>) {
        // Handle new API response structure with participation_request wrapper
        if (data.containsKey('participation_request')) {
          final result = data['participation_request'] as Map<String, dynamic>;
          print('✅ [RESPONDER-STATUS] Status updated! Request ID: ${result['id']}, New Status: ${result['status']}');
          print('📋 [RESPONDER-STATUS] Report auto-updated to: ${result['report']['latest_status']['status_display']}');
          return result;
        } else if (data.containsKey('message')) {
          // Handle reject/delete response which returns just a message
          final message = data['message'];
          print('✅ [RESPONDER-STATUS] Request ${status}ed successfully: $message');
          // Return a minimal response for reject operations
          return {
            'id': requestId,
            'status': status,
            'message': message,
            'deleted': true,  // Mark as deleted for reject operations
          };
        } else {
          print('📋 [RESPONDER-STATUS] Direct data response: $data');
          return data;
        }
      } else {
        print('❌ [RESPONDER-STATUS] Status update failed: ${responseData['message']}');
        throw Exception(responseData['message'] ??
            'Failed to update participation request status');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      print('❌ [RESPONDER-STATUS] Unexpected error: $e');
      throw Exception('خطأ غير متوقع: ${e.toString()}');
    }
  }

  /// Accept a participation request using new API (shorthand method)
  static Future<Map<String, dynamic>> acceptRequestStatus({
    required int requestId,
  }) async {
    print('✅ [RESPONDER-STATUS] Accepting request ID: $requestId');
    return await updateRequestStatus(
      requestId: requestId,
      status: 'accept',
    );
  }

  /// Reject a participation request using new API (shorthand method)
  static Future<Map<String, dynamic>> rejectRequestStatus({
    required int requestId,
  }) async {
    print('❌ [RESPONDER-STATUS] Rejecting request ID: $requestId');
    return await updateRequestStatus(
      requestId: requestId,
      status: 'reject',
    );
  }

  /// Cancel a participation request using new API (shorthand method)
  static Future<Map<String, dynamic>> cancelRequestStatus({
    required int requestId,
  }) async {
    print('🚫 [RESPONDER-STATUS] Cancelling request ID: $requestId');
    return await updateRequestStatus(
      requestId: requestId,
      status: 'cancel',
    );
  }

  /// Handle Dio errors and return user-friendly Arabic messages
  static String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'انتهت مهلة الاتصال - تحقق من الإنترنت';
      case DioExceptionType.sendTimeout:
        return 'انتهت مهلة إرسال البيانات';
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة استقبال البيانات';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'غير مخول - الرجاء تسجيل الدخول مرة أخرى';
        } else if (statusCode == 403) {
          return 'ليس لديك صلاحية للوصول لهذا المورد';
        } else if (statusCode == 404) {
          return 'البيانات المطلوبة غير موجودة';
        } else if (statusCode == 422) {
          final message = e.response?.data['message'];
          return message ?? 'بيانات غير صحيحة';
        } else if (statusCode != null && statusCode >= 500) {
          return 'خطأ في الخادم - الرجاء المحاولة لاحقاً';
        }
        return e.response?.data['message'] ?? 'خطأ في الشبكة';
      case DioExceptionType.cancel:
        return 'تم إلغاء العملية';
      case DioExceptionType.connectionError:
        return 'خطأ في الاتصال - تحقق من الإنترنت';
      default:
        return 'خطأ غير متوقع في الشبكة';
    }
  }
}
