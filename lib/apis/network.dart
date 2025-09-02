import 'dart:io';

import 'package:dio/io.dart';
import 'package:dio/dio.dart';

import 'server_exception.dart';

class Network {
  static late Dio dio;

  static init() {
    dio = Dio(
      BaseOptions(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Accept-Charset': 'application/json',
          'locale': 'ar',
        },
      ),
    );

   // Debugging interceptor (optional, enable for dev builds only)
    // dio.interceptors.add(
    //   PrettyDioLogger(
    //     requestHeader: false,
    //     requestBody: true,
    //     responseBody: true,
    //     responseHeader: false,
    //     error: true,
    //     request: true,
    //     compact: true,
    //     maxWidth: 1000,
    //   ),
    // );

    // Global error interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if ((error.response?.statusCode ?? 500) >= 500) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error:
                    ServerException('خطأ في الخادم - الرجاء المحاولة لاحقاً'),
              ),
            );
          } else {
            handler.next(error);
          }
        },
      ),
    );

    // Allow self-signed SSL certs (for dev/testing)
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    };
  }

  /// Set global Bearer token
  static void setBearer(String? token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear Bearer token (use in logout)
  static void clearBearer() {
    dio.options.headers.remove('Authorization');
  }

  /// GET request
  static Future<Response> getData({
    required String url,
    Map<String, dynamic>? queryParams,
  }) async {
    return await dio.get(url, queryParameters: queryParams);
  }

  /// POST request
  static Future<Response> postData({
    required String url,
    dynamic body,
  }) async {
    return await dio.post(url, data: body);
  }

  /// PUT request
  static Future<Response> putData({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    return await dio.put(url, data: data);
  }

  /// DELETE request
  static Future<Response> deleteData({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    return await dio.delete(url, data: data);
  }
}
