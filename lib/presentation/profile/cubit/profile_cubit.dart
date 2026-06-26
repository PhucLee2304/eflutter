import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';
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

  void hydrate(User? user) {
    if (user == null) return;
    emit(state.copyWith(user: user, failure: null));
  }

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

  Future<void> saveProfile({String? name, LocalPickedFile? avatarFile}) async {
    final trimmedName = name?.trim();
    final hasNameChange = trimmedName != null && trimmedName.isNotEmpty;
    final hasAvatarChange = avatarFile != null;

    if (!hasNameChange && !hasAvatarChange) {
      return;
    }

    emit(state.copyWith(isSaving: true, failure: null, saved: false));

    String? avatarFileName;
    if (avatarFile != null) {
      avatarFileName = _normalizeUploadFileName(avatarFile.name);
      final presignResult = await _userRepository
          .getPresignedUploadUrl(
            fileName: avatarFileName,
            contentType: avatarFile.contentType,
            folder: 'avatars',
          )
          .withLoading();

      switch (presignResult) {
        case Failure():
          emit(state.copyWith(isSaving: false, failure: presignResult));
          emit(state.copyWith(failure: null));
          return;
        case Cancelled():
          emit(state.copyWith(isSaving: false));
          return;
        case Success(data: final presignedUrl):
          final uploadResult = await _userRepository
              .uploadBinaryToUrl(
                url: presignedUrl,
                bytes: avatarFile.bytes,
                contentType: avatarFile.contentType,
              )
              .withLoading();

          switch (uploadResult) {
            case Failure():
              emit(state.copyWith(isSaving: false, failure: uploadResult));
              emit(state.copyWith(failure: null));
              return;
            case Cancelled():
              emit(state.copyWith(isSaving: false));
              return;
            case Success():
              break;
          }
      }
    }

    final result = await _userRepository
        .updateMe(
          name: hasNameChange ? trimmedName : null,
          avatar: avatarFileName,
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

  String _normalizeUploadFileName(String originalName) {
    final trimmed = originalName.trim();
    final dotIndex = trimmed.lastIndexOf('.');
    final extension = dotIndex > -1 ? trimmed.substring(dotIndex) : '';
    final sanitizedBase = (dotIndex > -1 ? trimmed.substring(0, dotIndex) : trimmed)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final safeBase = sanitizedBase.isEmpty ? 'avatar' : sanitizedBase;
    return '${DateTime.now().millisecondsSinceEpoch}-$safeBase$extension';
  }
}
