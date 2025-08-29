import 'package:dio/dio.dart';

String exceptionHandler({required DioException error}) {
  String? message;
  if (error.response?.data['message'] != null) {
    message = error.response?.data['message'];
  } else {
    switch (error.type) {
    case DioExceptionType.connectionTimeout:
      message = 'Server not reachable';
      break;

    case DioExceptionType.sendTimeout:
      message = 'Send Time out';
      break;
    case DioExceptionType.receiveTimeout:
      message = 'Server not reachable';
      break;
    case DioExceptionType.badResponse:
      message = error.response!.data['message'];
      break;
    case DioExceptionType.cancel:
      message = 'Request is cancelled';
      break;
    case DioExceptionType.unknown:
      error.message!.contains('SocketException')
          ? message = 'check your internet connection'
          : message = error.message!;
      break;
    case DioExceptionType.badCertificate:
      message = 'Bad Certificate';

      break;
    case DioExceptionType.connectionError:
      message = 'Connection Error';
      break;
  }
  }
  return message!;
}
