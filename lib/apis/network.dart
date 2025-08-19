import 'dart:io';

import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'server_exception.dart';

class Network {
  static late Dio dio;

  static init() {
    dio = Dio(
      BaseOptions(
        headers: {
          // 'Authorization': "Bearer ${AppSharedPreferences.getToken}",
          'Content-Type': 'application/json',
          "Accept": 'application/json',
          "Accept-Charset": "application/json",
          "locale": "ar",
        },
      ),
    );

    dio.interceptors.add(PrettyDioLogger(
      requestHeader: false,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      request: true,
      compact: true,
      maxWidth: 1000,
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if ((error.response?.statusCode ?? 500) >= 500) {
            // You can show a global error dialog here
            // or throw a custom exception
            throw ServerException('خطأ في الخادم');
          }
          handler.next(error);
        },
      ),
    );

    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      HttpClient client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

      return client;
    };
  }

  static Future<Response> getData({
    required String url,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await dio.get(url, queryParameters: queryParams);

      return response;
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 500) >= 500) {
        throw ServerException('خطأ في الخادم - الرجاء المحاولة لاحقاً');
      }
      rethrow;
    }
  }

  static Future<Response> postData({
    required String url,
    dynamic body,
  }) async {
    try {
      final response = await dio.post(
        url,
        data: body,
      );

      if ((response.statusCode ?? 500) >= 500) {
        throw ServerException('خطأ في الخادم - الرجاء المحاولة لاحقاً');
      }
      return response;
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 500) >= 500) {
        throw ServerException('خطأ في الخادم - الرجاء المحاولة لاحقاً');
      }
      rethrow;
    }
  }

  static Future<Response> putData({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await dio.put(url, data: data);

      if ((response.statusCode ?? 500) >= 500) {
        throw ServerException('خطأ في الخادم - الرجاء المحاولة لاحقاً');
      }

      return response;
    } on DioException catch (e) {
    if ((e.response?.statusCode ?? 500) >= 500) {
    throw ServerException('خطأ في الخادم - الرجاء المحاولة لاحقاً');
    }
    rethrow;
    }
  }

  static Future<Response> deleteData({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await dio.delete(url, data: data);

      if ((response.statusCode ?? 500) >= 500) {
        throw ServerException('خطأ في الخادم - الرجاء المحاولة لاحقاً');
      }

      return response;
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 500) >= 500) {
        throw ServerException('خطأ في الخادم - الرجاء المحاولة لاحقاً');
      }
      rethrow;
    }
  }
}
