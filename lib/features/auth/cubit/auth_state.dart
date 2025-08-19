part of 'auth_cubit.dart';

@immutable
sealed class AuthState {}

final class AuthInitial extends AuthState {}

// Send
final class SendCodeLoading extends AuthState {}

final class SendCodeSuccess extends AuthState {}

final class SendCodeError extends AuthState {
  final String message;

  SendCodeError({required this.message});
}

// Verify
final class VerifyCodeLoading extends AuthState {}

final class VerifyCodeSuccess extends AuthState {}

final class VerifyCodeError extends AuthState {
  final String message;

  VerifyCodeError({required this.message});
}

// Login
final class AuthLoading extends AuthState {}

final class AuthSuccess extends AuthState {}

final class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});
}
