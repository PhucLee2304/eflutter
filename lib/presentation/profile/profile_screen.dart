import 'dart:typed_data';

import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/utils/helpers/file_picker/file_picker_helper.dart';
import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:eflutter/presentation/profile/cubit/profile_cubit.dart';
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

  bool get _hasChanges =>
      _nameController.text.trim() != _initialName.trim() ||
      _draftAvatarFile != null;

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
    if (!isNewUser &&
        _initialName == user.name &&
        _initialAvatar == currentAvatar) {
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
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => context.read<AuthCubit>().logout(),
                icon: const Icon(SolarIconsOutline.exit),
              ),
            ],
          ),
          body: SafeArea(
            child: state.isLoading && state.user == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 16,
                            children: [
                              _ProfileHeader(
                                nameController: _nameController,
                                email: state.user?.email ?? '',
                                role: state.user?.role ?? '',
                                avatar: _draftAvatar,
                                avatarBytes: _draftAvatarBytes,
                                isEditingName: _isEditingName,
                                isBusy: state.isSaving,
                                onEditName: _startNameEdit,
                                onChangeAvatar: _openAvatarPicker,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _canCancel && !state.isSaving
                                          ? _cancelChanges
                                          : null,
                                      icon: const Icon(
                                        SolarIconsOutline.closeCircle,
                                      ),
                                      label: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _hasChanges && !state.isSaving
                                          ? () {
                                              if (!_formKey.currentState!
                                                  .validate()) {
                                                return;
                                              }
                                              context
                                                  .read<ProfileCubit>()
                                                  .saveProfile(
                                                    name:
                                                        _nameController.text
                                                                    .trim() !=
                                                                _initialName
                                                                    .trim()
                                                            ? _nameController
                                                                  .text
                                                            : null,
                                                    avatarFile:
                                                        _draftAvatarFile,
                                                  );
                                            }
                                          : null,
                                      icon: state.isSaving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              SolarIconsOutline.diskette,
                                            ),
                                      label: const Text('Save changes'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.nameController,
    required this.email,
    required this.role,
    required this.avatar,
    required this.avatarBytes,
    required this.isEditingName,
    required this.isBusy,
    required this.onEditName,
    required this.onChangeAvatar,
  });

  final TextEditingController nameController;
  final String email;
  final String role;
  final String avatar;
  final Uint8List? avatarBytes;
  final bool isEditingName;
  final bool isBusy;
  final VoidCallback onEditName;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = avatar.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditableAvatar(
            avatarUrl: avatarUrl,
            avatarBytes: avatarBytes,
            isBusy: isBusy,
            onPressed: onChangeAvatar,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isEditingName
                    ? TextFormField(
                        controller: nameController,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
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
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              nameController.text.trim().isEmpty
                                  ? 'User'
                                  : nameController.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit display name',
                            onPressed: onEditName,
                            icon: const Icon(SolarIconsOutline.pen),
                          ),
                        ],
                      ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColorName.labelSecondary),
                ),
                const SizedBox(height: 8),
                _RoleBadge(role: role),
              ],
            ),
          ),
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
      width: 82,
      height: 82,
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
                radius: 40,
                backgroundColor: ColorName.primary.withValues(alpha: 0.12),
                foregroundImage: imageProvider,
                child: imageProvider == null
                    ? const Icon(
                        SolarIconsBold.user,
                        color: ColorName.primary,
                        size: 34,
                      )
                    : null,
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(SolarIconsOutline.camera, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final label = role.trim().isEmpty ? 'Unknown' : role.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColorName.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          'Role: $label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ColorName.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
