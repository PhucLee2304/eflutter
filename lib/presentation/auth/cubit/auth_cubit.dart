import 'package:eflutter/core/auth/auth_cubit_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/repositories/auth_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'auth_cubit.freezed.dart';

@freezed
abstract class AuthState extends AuthStateBase with _$AuthState {
  const AuthState._({super.isAuthenticated = false}) : super();
  const factory AuthState({
    @Default(false) bool isAuthenticated,
    Failure? failure,
  }) = _AuthState;
}

@singleton
class AuthCubit extends AuthCubitBase<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthState());

  Future<void> init() async {
    final isAuthenticated = await _authRepository.initAuthenticated;
    emit(AuthState(isAuthenticated: isAuthenticated));
  }

  @override
  void logout() async {
    await _authRepository.logout().withLoading();
    emit(const AuthState(isAuthenticated: false));
  }

  void signInWithGoogle() async {
    _handleSignIn(_authRepository.login);
  }

  void _handleSignIn(Future Function() function) async {
    final result = await function().withLoading();
    switch (result) {
      case Success():
        emit(const AuthState(isAuthenticated: true));
      case Cancelled():
        break;
      case Failure():
        emit(AuthState(failure: result));
        emit(const AuthState(failure: null));
    }
  }
}
