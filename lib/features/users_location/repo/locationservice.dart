import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../features/chat/models/chat_models.dart';
import '../../../features/assignments/models/participation_request.dart'
    as assignments;

/// Service for handling location-related API operations
class LocationService {
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const int _maxRetries = 3;

  final Dio _dio;
  final String _baseUrl;

  LocationService({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add common headers
          options.headers["Content-Type"] = "application/x-www-form-urlencoded";
          options.headers["Accept"] = "application/json";

          // Add auth token if available
          // TODO: Add token from AuthCubit

          handler.next(options);
        },
        onError: (error, handler) {
          debugPrint("Location API Error: ${error.message}");
          handler.next(error);
        },
      ),
    );
  }

  /// Update user location to backend
  Future<LocationUpdateResponse> updateUserLocation({
    required double lat,
    required double lon,
    String? address,
  }) async {
    try {
      final formData = FormData.fromMap({
        "lat": lat,
        "lon": lon,
        if (address != null) "address": address,
        "_method": "PUT",
      });

      final response = await _dio.post(
        "$_baseUrl/users/location",
        data: formData,
        options: Options(
          sendTimeout: _defaultTimeout,
          receiveTimeout: _defaultTimeout,
        ),
      );

      return LocationUpdateResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw LocationServiceException(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw LocationServiceException("Failed to update location: $e");
    }
  }

  /// Get all users with their locations
  Future<UsersLocationResponse> getUsersLocations() async {
    try {
      // debugPrint("=== USERS LOCATION API REQUEST ===");
      // debugPrint("URL: $_baseUrl/users");
      
      final response = await _dio.get(
        "$_baseUrl/users",
        options: Options(
          sendTimeout: _defaultTimeout,
          receiveTimeout: _defaultTimeout,
        ),
      );

      // debugPrint("=== USERS LOCATION API RESPONSE ===");
      // debugPrint("Status Code: ${response.statusCode}");
      // debugPrint("Raw Response Data: ${response.data}");
      
      final parsedResponse = UsersLocationResponse.fromJson(response.data);
      // debugPrint("Parsed Response Success: ${parsedResponse.success}");
      // debugPrint("Parsed Users Count: ${parsedResponse.users.length}");
      
      return parsedResponse;
    } on DioException catch (e) {
      throw LocationServiceException(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw LocationServiceException("Failed to fetch users locations: $e");
    }
  }

  /// Update location with retry mechanism
  Future<LocationUpdateResponse> updateLocationWithRetry({
    required double lat,
    required double lon,
    String? address,
  }) async {
    int attempts = 0;
    LocationServiceException? lastError;

    while (attempts < _maxRetries) {
      try {
        return await updateUserLocation(lat: lat, lon: lon, address: address);
      } on DioException catch (e) {
        lastError = LocationServiceException(
          _handleDioError(e),
          statusCode: e.response?.statusCode,
        );
        attempts++;

        if (attempts < _maxRetries) {
          // Exponential backoff
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }

    throw lastError ?? LocationServiceException("Max retries exceeded");
  }

  String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Connection timeout. Please check your internet connection.";
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 401:
            return "Authentication required. Please log in again.";
          case 403:
            return "Permission denied.";
          case 404:
            return "Service not found.";
          case 500:
            return "Server error. Please try again later.";
          default:
            return "Request failed with status $statusCode";
        }
      case DioExceptionType.cancel:
        return "Request was cancelled";
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return "No internet connection";
        }
        return "Network error occurred";
      default:
        return "An unexpected error occurred";
    }
  }

  void dispose() {
    // No internal timers to dispose of anymore
  }
}

/// Response model for location update
class LocationUpdateResponse {
  final bool success;
  final String? message;
  final LocationData? data;

  LocationUpdateResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory LocationUpdateResponse.fromJson(Map<String, dynamic> json) {
    return LocationUpdateResponse(
      success: json["success"] ?? false,
      message: json["message"],
      data: json["data"] != null ? LocationData.fromJson(json["data"]) : null,
    );
  }
}

/// Response model for users locations
class UsersLocationResponse {
  final bool success;
  final String? message;
  final List<UserLocationEntity> users;

  UsersLocationResponse({
    required this.success,
    this.message,
    required this.users,
  });

  factory UsersLocationResponse.fromJson(Map<String, dynamic> json) {
    return UsersLocationResponse(
      success: json["success"] ?? false,
      message: json["message"],
      users: (json["data"]?["users"] as List<dynamic>?)
              ?.map((user) => UserLocationEntity.fromJson(user))
              .toList() ??
          [],
    );
  }
}

/// User location entity model
class UserLocationEntity {
  final int id;
  final String name;
  final String? authPhone;
  final ProfileImage? profileImage;
  final ResponderType? responderType;
  final List<UserRole> roles;
  final LocationData? location;
  final List<assignments.ParticipationRequest> participationRequests;

  UserLocationEntity({
    required this.id,
    required this.name,
    this.authPhone,
    this.profileImage,
    this.responderType,
    required this.roles,
    this.location,
    this.participationRequests = const [],
  });

  factory UserLocationEntity.fromJson(Map<String, dynamic> json) {
    // Parse profile_image safely
    ProfileImage? profileImage;
    if (json['profile_image'] is Map<String, dynamic>) {
      profileImage =
          ProfileImage.fromJson(json['profile_image'] as Map<String, dynamic>);
    }

    // Parse responder_type safely
    ResponderType? responderType;
    if (json['responder_type'] is Map<String, dynamic>) {
      responderType = ResponderType.fromJson(
          json['responder_type'] as Map<String, dynamic>);
    }

    // Parse participation_requests safely
    List<assignments.ParticipationRequest> participationRequests = [];
    if (json['participation_requests'] is List) {
      participationRequests = (json['participation_requests'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => assignments.ParticipationRequest.fromJson(item))
          .toList();
    }

    return UserLocationEntity(
      id: json["id"] ?? 0,
      name: json["name"] ?? "",
      authPhone: json["auth_phone"],
      profileImage: profileImage,
      responderType: responderType,
      roles: (json["roles"] as List<dynamic>?)
              ?.map((role) => UserRole.fromJson(role))
              .toList() ??
          [],
      location: json["location"] != null
          ? LocationData.fromJson(json["location"])
          : null,
      participationRequests: participationRequests,
    );
  }

  bool get isCoordinator => roles.any((role) => role.name == "coordinator");
  bool get isResponder => roles.any((role) => role.name == "responder");
  bool get isCitizen => roles.any((role) => role.name == "citizen");

  String get primaryRole {
    if (isCoordinator) return "coordinator";
    if (isResponder) return "responder";
    return "citizen";
  }

  bool get hasValidLocation =>
      location != null && location!.lat != 0 && location!.lon != 0;

  /// Get profile image URL (preferring medium size, fallback to public path)
  String? get profileImageUrl {
    if (profileImage == null) return null;
    return profileImage!.conversions?.medium ?? profileImage!.publicPath;
  }

  /// Get profile thumbnail URL
  String? get profileThumbnailUrl {
    if (profileImage == null) return null;
    return profileImage!.conversions?.thumb ?? profileImage!.publicPath;
  }

  /// Get responder emergency type name if available
  String? get responderEmergencyType {
    return responderType?.emergencyType?.name;
  }

  /// Get responder emergency type color if available
  String? get responderEmergencyTypeColor {
    return responderType?.emergencyType?.color;
  }

  /// Check if user has pending participation requests
  bool get hasPendingRequests =>
      participationRequests.any((request) => request.status == 'pending');
}

/// User role model
class UserRole {
  final int id;
  final String name;

  UserRole({
    required this.id,
    required this.name,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json["id"] ?? 0,
      name: json["name"] ?? "",
    );
  }
}

/// Location data model
class LocationData {
  final double lat;
  final double lon;
  final String? address;

  LocationData({
    required this.lat,
    required this.lon,
    this.address,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      lat: (json["lat"] as num?)?.toDouble() ?? 0.0,
      lon: (json["lon"] as num?)?.toDouble() ?? 0.0,
      address: json["address"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "lat": lat,
      "lon": lon,
      if (address != null) "address": address,
    };
  }
}

/// Custom exception for location service errors
class LocationServiceException implements Exception {
  final String message;
  final int? statusCode;

  LocationServiceException(this.message, {this.statusCode});

  @override
  String toString() => "LocationServiceException: $message";
}
