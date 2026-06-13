import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AuthNotifier extends ChangeNotifier {
  final AuthCubit _authCubit;

  AuthNotifier(this._authCubit) {
    _authCubit.stream.listen((_) => notifyListeners());
  }

  bool get isAuthenticated => _authCubit.state.isAuthenticated;
}
