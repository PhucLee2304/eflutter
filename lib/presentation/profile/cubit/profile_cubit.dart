import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/models/user.dart';
import 'package:eflutter/data/repositories/user_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

class ProfileState {
  final User? user;
  final bool isLoading;
  final bool isSaving;
  final Failure? failure;
  final bool saved;

  const ProfileState({
    this.user,
    this.isLoading = false,
    this.isSaving = false,
    this.failure,
    this.saved = false,
  });

  ProfileState copyWith({
    Object? user = _sentinel,
    bool? isLoading,
    bool? isSaving,
    Object? failure = _sentinel,
    bool? saved,
  }) {
    return ProfileState(
      user: identical(user, _sentinel) ? this.user : user as User?,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      failure: identical(failure, _sentinel)
          ? this.failure
          : failure as Failure?,
      saved: saved ?? this.saved,
    );
  }
}

const _sentinel = Object();

@injectable
class ProfileCubit extends Cubit<ProfileState> {
  final UserRepository _userRepository;
  final AppCubit _appCubit;

  ProfileCubit(this._userRepository, this._appCubit)
    : super(const ProfileState());

  Future<void> getMe() async {
    emit(state.copyWith(isLoading: true, failure: null, saved: false));
    final result = await _userRepository.getMe().withLoading();
    switch (result) {
      case Success(data: final user):
        _appCubit.setUser(user);
        emit(state.copyWith(user: user, isLoading: false));
      case Failure():
        emit(state.copyWith(isLoading: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> updateMe({required String name, required String avatar}) async {
    final trimmedName = name.trim();
    final trimmedAvatar = avatar.trim();

    if (trimmedName.isEmpty && trimmedAvatar.isEmpty) {
      emit(
        state.copyWith(
          failure: const Failure(
            message: 'Please enter a display name or avatar URL.',
          ),
          saved: false,
        ),
      );
      emit(state.copyWith(failure: null));
      return;
    }

    emit(state.copyWith(isSaving: true, failure: null, saved: false));
    final result = await _userRepository
        .updateMe(
          name: trimmedName.isEmpty ? null : trimmedName,
          avatar: trimmedAvatar.isEmpty ? null : trimmedAvatar,
        )
        .withLoading();

    switch (result) {
      case Success(data: final user):
        _appCubit.setUser(user);
        emit(state.copyWith(user: user, isSaving: false, saved: true));
        emit(state.copyWith(saved: false));
      case Failure():
        emit(state.copyWith(isSaving: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isSaving: false));
    }
  }
}
