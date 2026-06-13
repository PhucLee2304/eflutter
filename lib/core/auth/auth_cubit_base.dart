import 'package:flutter_bloc/flutter_bloc.dart';

class AuthStateBase {
  const AuthStateBase({required this.isAuthenticated});
  final bool isAuthenticated;
}

abstract class AuthCubitBase<T extends AuthStateBase> extends Cubit<T> {
  AuthCubitBase(super.initialState);

  void logout();
}
