import 'package:dio/dio.dart';
import '../../../apis/network.dart';
import '../../../utils/urls.dart';

class AssignmentService {
  /// Get all participation requests based on user role and token
  /// - Coordinators: Returns all requests in the system
  /// - Responders: Returns only requests where they are the responder
  /// - Citizens: Returns only requests they initiated
  /// Backend handles filtering based on the bearer token
  static Future<List<Map<String, dynamic>>>
      getAllParticipationRequests() async {
    try {
      final response = await Network.getData(
        url: '${Urls.baseUrl}/request-participation',
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
      final response = await Network.postData(
        url: '${Urls.baseUrl}/request-participation/$reportId',
        body: {
          'responder_id': responderId,
        },
      );

      // Handle different success response formats
      final responseData = response.data;
      if (responseData == null) {
        throw Exception('No response data received from server');
      }

      final data = responseData['data'];
      if (data != null && data is Map<String, dynamic>) {
        return data;
      } else {
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
        return data;
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
