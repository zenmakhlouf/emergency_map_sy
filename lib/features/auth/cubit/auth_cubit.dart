import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../apis/exceptions_handler.dart';
import '../../../apis/network.dart';
import '../../../utils/urls.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  final otpController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  void sendOtp(String type) async {
    emit(SendCodeLoading());
    try {
      final response = await Network.postData(
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

      emit(VerifyCodeSuccess());
    } catch (e) {
      emit(VerifyCodeError(message: e.toString()));
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

      emit(AuthSuccess());
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

      emit(AuthSuccess());
    } on DioException catch (e) {
      final message = exceptionHandler(error: e);
      emit(AuthError(message: message));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
}
