import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_client/services/auth_service.dart';
part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());
  final _authService = AuthService();

  void signup({
    required String name,
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    //perform signup
    await _authService
        .signupuser(name: name, email: email, password: password)
        .then((message) {
          emit(AuthSignupSuccess(message));
        })
        .catchError((error) {
          emit(AuthError(error.toString()));
          debugPrint(error.toString());
        });
  }

  void confirmSignUp({required String email, required String otp}) async {
    emit(AuthLoading());
    await _authService
        .confirmSignup(email: email, otp: otp)
        .then((message) {
          emit(AuthConfirmSuccess(message));
        })
        .catchError((error) {
          emit(AuthError(error));

          debugPrint(error.toString());
        });
  }

  void loginUser({required String email, required String password}) async {
    emit(AuthLoading());
    //perform signup
    await _authService
        .loginuser(email: email, password: password)
        .then((message) {
          emit(AuthSignupSuccess(message));
        })
        .catchError((error) {
          emit(AuthError(error.toString()));
          debugPrint(error.toString());
        });
  }

  void isAuthenticated() async {
    emit(AuthLoading());
    await _authService.isAuthenticated().then((isAuth) {
      if (isAuth) {
        emit(AuthLoginSuccess('Logged in!'));
      } else {
        emit(AuthInitial());
      }
    }).catchError((error) {
      emit(AuthError(error.toString()));
      debugPrint(error.toString());
    });
  }
}
