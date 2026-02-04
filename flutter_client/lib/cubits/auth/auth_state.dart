part of 'auth_cubit.dart';

@immutable
sealed class AuthState {}

final class AuthInitial extends AuthState {}

final class AuthLoading extends AuthState {}

final class AuthSignupSuccess extends AuthState {
  final String message;
  AuthSignupSuccess(this.message);
}

final class AuthLoginSuccess extends AuthState {
  final String message;
  AuthLoginSuccess(this.message);
}

final class AuthConfirmSuccess extends AuthState {
  final String message;
  AuthConfirmSuccess(this.message);
}

final class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
