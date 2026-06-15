import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/generated/colors.gen.dart';
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
  bool _isEditingName = false;

  bool get _hasChanges =>
      _nameController.text.trim() != _initialName.trim() ||
      _draftAvatar.trim() != _initialAvatar.trim();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleDraftChanged);
    context.read<ProfileCubit>().getMe();
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleDraftChanged)
      ..dispose();
    super.dispose();
  }

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _syncDraft(ProfileState state) {
    final user = state.user;
    if (user == null) return;

    final currentAvatar = user.avatar ?? '';
    final shouldSync =
        _syncedUserId != user.id ||
        (!_isEditingName &&
            (_initialName != user.name || _initialAvatar != currentAvatar));

    if (!shouldSync) return;

    _syncedUserId = user.id;
    _initialName = user.name;
    _initialAvatar = currentAvatar;
    _draftAvatar = currentAvatar;
    _nameController.text = user.name;
  }

  void _cancelChanges() {
    setState(() {
      _nameController.text = _initialName;
      _draftAvatar = _initialAvatar;
      _isEditingName = false;
    });
  }

  void _startNameEdit() {
    setState(() {
      _isEditingName = true;
    });
  }

  void _openAvatarPicker() {
    // Upload wiring will be added later. This keeps the intended control in place.
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
                                isEditingName: _isEditingName,
                                onEditName: _startNameEdit,
                                onChangeAvatar: _openAvatarPicker,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _hasChanges && !state.isSaving
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
                                                  .updateMe(
                                                    name: _nameController.text,
                                                    avatar: _draftAvatar,
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
    required this.isEditingName,
    required this.onEditName,
    required this.onChangeAvatar,
  });

  final TextEditingController nameController;
  final String email;
  final String role;
  final String avatar;
  final bool isEditingName;
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
          _EditableAvatar(avatarUrl: avatarUrl, onPressed: onChangeAvatar),
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
  const _EditableAvatar({required this.avatarUrl, required this.onPressed});

  final String avatarUrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: ColorName.primary.withValues(alpha: 0.12),
            foregroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
            child: avatarUrl.isEmpty
                ? const Icon(
                    SolarIconsBold.user,
                    color: ColorName.primary,
                    size: 34,
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: 32,
              height: 32,
              child: IconButton.filled(
                tooltip: 'Change avatar',
                onPressed: onPressed,
                padding: EdgeInsets.zero,
                icon: const Icon(SolarIconsOutline.camera, size: 18),
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
