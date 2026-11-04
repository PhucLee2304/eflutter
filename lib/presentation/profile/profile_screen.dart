import 'package:eflutter/core/loading/loading_widget.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:eflutter/core/utils/helpers/file_picker/file_picker_helper.dart';
import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:eflutter/presentation/profile/cubit/profile_cubit.dart';
import 'package:eflutter/presentation/posts/post_list.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solar_icons/solar_icons.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  int? _syncedUserId;
  String _initialName = '';
  String _initialAvatar = '';
  String _draftAvatar = '';
  Uint8List? _draftAvatarBytes;
  LocalPickedFile? _draftAvatarFile;
  bool _isEditingName = false;
  bool _isSyncingDraft = false;
  late final Future<_ProfileStats> _stats = _loadStats();

  bool get _hasChanges =>
      _nameController.text.trim() != _initialName.trim() || _draftAvatarFile != null;

  bool get _canCancel => _isEditingName || _hasChanges;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleDraftChanged);
    final profileCubit = context.read<ProfileCubit>();
    final appUser = context.read<AppCubit>().state.user;
    profileCubit.hydrate(appUser);
    if (appUser == null) {
      profileCubit.getMe();
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleDraftChanged)
      ..dispose();
    super.dispose();
  }

  // Lỗi từng API thì ô đó hiện "–", không chặn cả trang.
  Future<_ProfileStats> _loadStats() async {
    final dio = getIt<Dio>();
    final (posts, classrooms, exams) = await (
      PostRepository(
        dio,
      ).getPosts(page: 1, mine: true).then<int?>((p) => p.total, onError: (_) => null),
      ClassroomRepository(dio).getMine().then((r) => r.dataOrNull?.total),
      ExamRepository(
        getIt<RemoteDataBase>(),
      ).getAttempts(status: 'SUBMITTED', page: 1, pageSize: 1).then((r) => r.dataOrNull?.total),
    ).wait;
    return (posts: posts, classrooms: classrooms, exams: exams);
  }

  void _handleDraftChanged() {
    if (mounted && !_isSyncingDraft) {
      setState(() {});
    }
  }

  void _syncDraft(ProfileState state) {
    final user = state.user;
    if (user == null) return;

    final currentAvatar = user.avatar ?? '';
    final isNewUser = _syncedUserId != user.id;
    if (!isNewUser && _initialName == user.name && _initialAvatar == currentAvatar) {
      return;
    }

    _syncedUserId = user.id;

    _isSyncingDraft = true;
    try {
      if (isNewUser || !_isEditingName) {
        _initialName = user.name;
        _nameController.text = user.name;
      }

      _initialAvatar = currentAvatar;
      _draftAvatar = currentAvatar;
      _draftAvatarBytes = null;
      _draftAvatarFile = null;
    } finally {
      _isSyncingDraft = false;
    }
  }

  void _cancelChanges() {
    setState(() {
      _nameController.text = _initialName;
      _draftAvatar = _initialAvatar;
      _draftAvatarBytes = null;
      _draftAvatarFile = null;
      _isEditingName = false;
    });
  }

  void _startNameEdit() {
    setState(() {
      _isEditingName = true;
    });
  }

  Future<void> _openAvatarPicker() async {
    if (context.read<ProfileCubit>().state.isSaving) {
      return;
    }

    final file = await pickImageFile();
    if (file == null || !mounted) {
      return;
    }

    _previewAvatar(file);
  }

  void _previewAvatar(LocalPickedFile file) {
    setState(() {
      _draftAvatarFile = file;
      _draftAvatarBytes = file.bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.failure != null) {
          context.handleFailure(state.failure);
        }
        if (state.saved) {
          setState(() {
            _isEditingName = false;
          });
          context.showToast('Profile updated.', type: ToastType.success);
        }
      },
      builder: (context, state) {
        _syncDraft(state);
        return Scaffold(
          backgroundColor: const Color(0xFFF5F6F8),
          body: SafeArea(
            child: state.isLoading && state.user == null
                ? const AppLoader()
                : PostList(
                    mine: true,
                    aside: Form(
                      key: _formKey,
                      child: _ProfileCard(
                        nameController: _nameController,
                        email: state.user?.email ?? '',
                        avatar: _draftAvatar,
                        avatarBytes: _draftAvatarBytes,
                        isEditing: _canCancel,
                        isEditingName: _isEditingName,
                        canSave: _hasChanges,
                        isBusy: state.isSaving,
                        onEdit: _startNameEdit,
                        onChangeAvatar: _openAvatarPicker,
                        onCancel: _cancelChanges,
                        onSave: () {
                          if (!_formKey.currentState!.validate()) return;
                          context.read<ProfileCubit>().saveProfile(
                            name: _nameController.text.trim() != _initialName.trim()
                                ? _nameController.text
                                : null,
                            avatarFile: _draftAvatarFile,
                          );
                        },
                        stats: _stats,
                        onSignOut: () => context.read<AuthCubit>().logout(),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.nameController,
    required this.email,
    required this.avatar,
    required this.avatarBytes,
    required this.isEditing,
    required this.isEditingName,
    required this.canSave,
    required this.isBusy,
    required this.onEdit,
    required this.onChangeAvatar,
    required this.onCancel,
    required this.onSave,
    required this.stats,
    required this.onSignOut,
  });

  final TextEditingController nameController;
  final String email;
  final String avatar;
  final Uint8List? avatarBytes;
  final bool isEditing, isEditingName, canSave, isBusy;
  final VoidCallback onEdit, onChangeAvatar, onCancel, onSave, onSignOut;
  final Future<_ProfileStats> stats;

  @override
  Widget build(BuildContext context) {
    final name = nameController.text.trim();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ảnh bìa + avatar đè lên mép dưới.
          SizedBox(
            height: 166,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  height: 110,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [ColorName.primary, ColorName.cyan]),
                  ),
                ),
                Positioned(
                  top: 54,
                  child: _EditableAvatar(
                    avatarUrl: avatar.trim(),
                    avatarBytes: avatarBytes,
                    isBusy: isBusy,
                    onPressed: onChangeAvatar,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                if (isEditingName)
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => canSave && !isBusy ? onSave() : null,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Display name',
                      prefixIcon: Icon(SolarIconsOutline.user),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Please enter your display name';
                      }
                      return null;
                    },
                  )
                else
                  Text(
                    name.isEmpty ? 'User' : name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColorName.labelSecondary),
                ),
                const SizedBox(height: 8),
                FutureBuilder(
                  future: stats,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return Row(
                      children: [
                        _Stat(value: data?.posts, label: 'Posts', loaded: snapshot.hasData),
                        _Stat(
                          value: data?.classrooms,
                          label: 'Classrooms',
                          loaded: snapshot.hasData,
                        ),
                        _Stat(value: data?.exams, label: 'Exams taken', loaded: snapshot.hasData),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (isEditing)
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: isBusy ? null : onCancel,
                          style: AppButtonStyles.secondary,
                          child: const Text('Cancel'),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(
                          onPressed: canSave && !isBusy ? onSave : null,
                          style: AppButtonStyles.primary,
                          child: isBusy
                              ? const SizedBox(width: 18, height: 18, child: AppLoader())
                              : const Text('Save changes'),
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: onEdit,
                    style: AppButtonStyles.secondary,
                    icon: const Icon(SolarIconsOutline.pen, size: 18),
                    label: const Text(
                      'Edit profile',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: onSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorName.red,
                    side: BorderSide(color: ColorName.red.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(SolarIconsOutline.exit, size: 18),
                  label: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _ProfileStats = ({int? posts, int? classrooms, int? exams});

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.loaded});

  final int? value;
  final String label;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        spacing: 2,
        children: [
          Text(
            loaded ? (value?.toString() ?? '–') : '…',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: ColorName.gray1)),
        ],
      ),
    );
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.avatarUrl,
    required this.avatarBytes,
    required this.isBusy,
    required this.onPressed,
  });

  final String avatarUrl;
  final Uint8List? avatarBytes;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Builder(
            builder: (context) {
              ImageProvider<Object>? imageProvider;
              if (avatarBytes != null) {
                imageProvider = MemoryImage(avatarBytes!);
              } else if (avatarUrl.isNotEmpty) {
                imageProvider = NetworkImage(avatarUrl);
              }
              return CircleAvatar(
                radius: 56,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: ColorName.primary.withValues(alpha: 0.12),
                  foregroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(SolarIconsBold.user, color: ColorName.primary, size: 44)
                      : null,
                ),
              );
            },
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: 32,
              height: 32,
              child: IconButton.filled(
                tooltip: 'Change avatar',
                onPressed: isBusy ? null : onPressed,
                padding: EdgeInsets.zero,
                icon: isBusy
                    ? const SizedBox(width: 16, height: 16, child: AppLoader())
                    : const Icon(SolarIconsOutline.camera, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
