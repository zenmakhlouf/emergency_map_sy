import 'package:dio/dio.dart';
import 'package:emergency_map_sy/features/auth/models/user_type.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../apis/exceptions_handler.dart';
import '../../../apis/network.dart';
import '../../../utils/urls.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthLoading()) {
    _initialize();
  }

  // Controllers
  final otpController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  // Private auth state
  String? _token;
  int? _userId;
  UserType? _userType;
  bool _isInitialized = false;

  // Public getters
  String? get token => _token;
  int? get userId => _userId;
  UserType? get userType => _userType;
  bool get isAuthenticated =>
      _isInitialized && _token != null && _token!.isNotEmpty && _userId != null;

  /// Initialize the auth cubit and load stored session
  Future<void> _initialize() async {
    try {
      await _loadStoredSession();
    } catch (e) {
      debugPrint('[AuthCubit] Initialization error: $e');
      emit(AuthInitial());
    } finally {
      _isInitialized = true;
    }
  }

  /// Load stored authentication data and set up network bearer token
  Future<void> _loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      final storedUserId = prefs.getInt('user_id');
      final storedUserType = prefs.getString('user_type');

      debugPrint('[AuthCubit] Loading stored session...');
      debugPrint('[AuthCubit] Token exists: ${storedToken != null}');
      debugPrint('[AuthCubit] UserID exists: ${storedUserId != null}');
      debugPrint('[AuthCubit] UserType: $storedUserType');

      if (storedToken != null &&
          storedToken.isNotEmpty &&
          storedUserId != null &&
          storedUserType != null) {
        // Parse user type
        UserType? userType;
        try {
          userType =
              UserType.values.firstWhere((e) => e.name == storedUserType);
        } catch (e) {
          debugPrint('[AuthCubit] Invalid stored user type: $storedUserType');
          await _clearStoredData();
          emit(AuthInitial());
          return;
        }

        // Set authentication data
        _setAuthData(
          token: storedToken,
          userId: storedUserId,
          userType: userType,
          persist: false, // Don't re-persist what we just loaded
        );

        emit(AuthSuccess());
        debugPrint('[AuthCubit] Session restored successfully');
        debugPrint('[AuthCubit] Bearer token set: ${_tokenDebugString()}');
      } else {
        debugPrint('[AuthCubit] No valid stored session found');
        emit(AuthInitial());
      }
    } catch (e) {
      debugPrint('[AuthCubit] Failed to load stored session: $e');
      emit(AuthInitial());
    }
  }

  /// Send OTP to phone number
  void sendOtp(String type) async {
    emit(SendCodeLoading());
    try {
      await Network.postData(
        url: Urls.sendOTP,
        body: {
          'phone_number': '+963${phoneController.text}',
          'type': type,
        },
      );
      emit(SendCodeSuccess());
      debugPrint('[AuthCubit] OTP sent successfully');
    } catch (e) {
      debugPrint('[AuthCubit] Failed to send OTP: $e');
      emit(SendCodeError(message: e.toString()));
    }
  }

  /// Verify OTP code
  void checkOtp(String type, {required UserType userType}) async {
    emit(VerifyCodeLoading());
    try {
      final response = await Network.postData(
        url: Urls.checkOTP,
        body: {
          'phone_number': '+963${phoneController.text}',
          'type': type,
          'code': otpController.text,
        },
      );

      await _handleAuthResponse(response, userType: userType);
    } catch (e) {
      debugPrint('[AuthCubit] OTP verification failed: $e');
      emit(VerifyCodeError(message: e.toString()));
    }
  }

  /// Login with existing account
  void login(UserType userType) async {
    emit(AuthLoading());
    try {
      final response = await Network.postData(
        url: Urls.login,
        body: {
          'phone_number': '+963${phoneController.text}',
          'code': otpController.text,
        },
      );
      await _handleAuthResponse(response, userType: userType);
    } catch (e) {
      debugPrint('[AuthCubit] Login failed: $e');
      emit(AuthError(message: e.toString()));
    }
  }

  /// Register new account
  void register(UserType userType) async {
    emit(AuthLoading());
    try {
      final response = await Network.postData(
        url: Urls.register,
        body: {
          'name': nameController.text,
          'phone_number': '+963${phoneController.text}',
          'code': otpController.text,
        },
      );
      await _handleAuthResponse(response, userType: userType);
    } on DioException catch (e) {
      final message = exceptionHandler(error: e);
      debugPrint('[AuthCubit] Registration failed: $message');
      emit(AuthError(message: message));
    } catch (e) {
      debugPrint('[AuthCubit] Registration failed: $e');
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle authentication response from server
  Future<void> _handleAuthResponse(Response response,
      {required UserType userType}) async {
    try {
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] as Map<String, dynamic>?;

        if (data != null) {
          final token = data['token']?.toString();
          final userId = int.tryParse(data['user']?['id']?.toString() ?? '');

          if (token != null && token.isNotEmpty && userId != null) {
            debugPrint(
                '[AuthCubit] Auth response valid - Token: ${token.substring(0, 8)}..., UserID: $userId');

            // Set authentication data and persist it
            _setAuthData(
              token: token,
              userId: userId,
              userType: userType,
              persist: true,
            );

            emit(AuthSuccess());
            debugPrint('[AuthCubit] Authentication successful');
            return;
          }
        }
      }

      debugPrint('[AuthCubit] Invalid auth response structure');
      emit(
          AuthError(message: 'Authentication failed: Invalid server response'));
    } catch (e) {
      debugPrint('[AuthCubit] Error handling auth response: $e');
      emit(AuthError(message: 'Authentication failed: $e'));
    }
  }

  /// Set authentication data and configure network bearer token
  void _setAuthData({
    String? token,
    int? userId,
    UserType? userType,
    bool persist = true,
  }) {
    // Update internal state
    _token = token;
    _userId = userId;
    _userType = userType;

    // Update authentication status

    // Set network bearer token IMMEDIATELY
    if (token != null && token.isNotEmpty) {
      Network.setBearer(token);
      debugPrint(
          '[AuthCubit] Bearer token set globally: ${_tokenDebugString()}');
    } else {
      Network.clearBearer();
      debugPrint('[AuthCubit] Bearer token cleared');
    }

    // Persist to storage if requested
    if (persist && token != null && userId != null && userType != null) {
      _storeAuthData(token, userId, userType);
    }

    debugPrint(
        '[AuthCubit] Auth data updated - Authenticated: $isAuthenticated');
  }

  /// Store authentication data to SharedPreferences
  Future<void> _storeAuthData(
      String token, int userId, UserType userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('auth_token', token),
        prefs.setInt('user_id', userId),
        prefs.setString('user_type', userType.name),
      ]);
      debugPrint('[AuthCubit] Auth data stored successfully');
    } catch (e) {
      debugPrint('[AuthCubit] Failed to store auth data: $e');
    }
  }

  /// Clear stored authentication data
  Future<void> _clearStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('auth_token'),
        prefs.remove('user_id'),
        prefs.remove('user_type'),
      ]);
      Network.clearBearer();
      debugPrint('[AuthCubit] Stored auth data cleared');
    } catch (e) {
      debugPrint('[AuthCubit] Failed to clear stored data: $e');
    }
  }

  /// Logout and clear all session data
  void logout() async {
    debugPrint('[AuthCubit] Logging out...');

    // Clear internal state
    _setAuthData(
      token: null,
      userId: null,
      userType: null,
      persist: false,
    );

    // Clear stored data
    await _clearStoredData();

    // Reset to initial state
    emit(AuthInitial());
    debugPrint('[AuthCubit] Logout completed');
  }

  /// Get debug-safe token string
  String _tokenDebugString() {
    if (_token == null || _token!.isEmpty) return 'EMPTY';
    return '${_token!.substring(0, (_token!.length > 8 ? 8 : _token!.length))}...';
  }

  /// Wait for authentication to be fully initialized
  Future<void> waitForInitialization() async {
    int attempts = 0;
    const maxAttempts = 20; // 2 seconds max wait

    while (!_isInitialized && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    debugPrint('[AuthCubit] Initialization completed in ${attempts * 100}ms');
  }

  @override
  Future<void> close() {
    otpController.dispose();
    nameController.dispose();
    phoneController.dispose();
    return super.close();
  }
}
