import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../apis/exceptions_handler.dart';
import '../../../apis/network.dart';
import '../../../utils/urls.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial()) {
    _loadStoredData();
  }

  final otpController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  String? _token;
  int? _userId;
  bool _isAuthenticated = false;

  String? get token => _token;
  int? get userId => _userId;
  bool get isAuthenticated =>
      _isAuthenticated && _token != null && _token!.isNotEmpty;

  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      final storedUserId = prefs.getInt('user_id');

      if (storedToken != null &&
          storedToken.isNotEmpty &&
          storedUserId != null) {
        _setAuthData(
          token: storedToken,
          userId: storedUserId,
          persist: false,
        );
        emit(AuthSuccess());
        debugPrint(
            '[AuthCubit] Loaded stored session: Token ${_tokenDebugString()}, UserID $_userId');
      }
    } catch (e) {
      debugPrint('[AuthCubit] Failed to load stored session: $e');
    }
  }

  Future<void> _storeAuthData(String token, int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setInt('user_id', userId);
    } catch (e) {
      debugPrint('[AuthCubit] Failed to store session data: $e');
    }
  }

  Future<void> _clearStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      Network.clearBearer();
    } catch (e) {
      debugPrint('[AuthCubit] Failed to clear stored session data: $e');
    }
  }

  void _setAuthData({String? token, int? userId, bool persist = true}) {
    _token = token;
    _userId = userId;
    _isAuthenticated = token != null && token.isNotEmpty && userId != null;
    Network.setBearer(token);
    print("i have set bearer token gloablly");

    if (persist && token != null && userId != null) {
      _storeAuthData(token, userId);
    }
    debugPrint(
        '[AuthCubit] Session set: Token ${_tokenDebugString()}, UserID $_userId');
  }

  String _tokenDebugString() {
    if (_token == null || _token!.isEmpty) return 'EMPTY';
    return '${_token!.substring(0, (_token!.length > 8 ? 8 : _token!.length))}...';
  }

  // --- MISSING METHODS NOW RESTORED ---

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
    } catch (e) {
      emit(SendCodeError(message: e.toString()));
    }
  }

  void checkOtp(String type) async {
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
      // NOTE: The checkOtp endpoint in your original code extracts a token.
      // We will handle it similarly to login/register.
      _handleAuthResponse(response);
    } catch (e) {
      emit(VerifyCodeError(message: e.toString()));
    }
  }

  // --- END OF RESTORED METHODS ---

  void _handleAuthResponse(Response response) {
    String? extractedToken;
    int? extractedUserId;

    try {
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          extractedToken = data['token']?.toString();
          if (data['user'] is Map<String, dynamic> &&
              data['user']['id'] != null) {
            extractedUserId = int.tryParse(data['user']['id'].toString());
          }
        }
        // Fallback for token directly in body
        extractedToken ??= body['token']?.toString();
      }
    } catch (e) {
      debugPrint('[AuthCubit] Token/User extraction error: $e');
    }

    // MOCK USER ID IF NOT PROVIDED BY API:
    // If your login/register API response doesn't include the user's ID,
    // you will need another way to get it. For now, we'll use a placeholder.
    extractedUserId ??= 1; // Replace with real ID when API provides it.

    if (extractedToken != null &&
        extractedToken.isNotEmpty &&
        extractedUserId != null) {
      _setAuthData(token: extractedToken, userId: extractedUserId);
      emit(AuthSuccess());
    } else {
      emit(
          AuthError(message: 'Authentication failed: Invalid server response'));
    }
  }

  void login() async {
    emit(AuthLoading());
    try {
      final response = await Network.postData(
        url: Urls.login,
        body: {
          'phone_number': '+963${phoneController.text}',
          'code': otpController.text,
        },
      );
      _handleAuthResponse(response);
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  void register() async {
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
      _handleAuthResponse(response);
    } on DioException catch (e) {
      final message = exceptionHandler(error: e);
      emit(AuthError(message: message));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  void logout() async {
    _setAuthData(token: null, userId: null, persist: false);
    await _clearStoredData();
    emit(AuthInitial());
    debugPrint('[AuthCubit] User logged out');
  }

  @override
  Future<void> close() {
    otpController.dispose();
    nameController.dispose();
    phoneController.dispose();
    return super.close();
  }
}
