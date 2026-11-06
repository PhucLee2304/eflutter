import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/user.dart';
import 'package:eflutter/data/repositories/admin_user_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

const _text = Color(0xFF1F1F1F);
const _muted = Color(0xFF6B6B6B);
const _border = Color(0xFFE3E3E3);
const _red = Color(0xFFD93025);
const _primary = Color(0xFF1A73C9);

/// `/admin/users`: danh sách người dùng, tìm/lọc, khoá và mở khoá tài khoản CLIENT.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late final repository = AdminUserRepository(getIt<Dio>());
  final search = TextEditingController();
  Timer? searchDebounce;
  List<User> users = [];
  UsersSummary summary = const UsersSummary();
  int page = 1;
  static const pageSize = 20;
  int pageCounts = 1;
  int total = 0;
  String? role;
  bool? blocked;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
    loadSummary();
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load({int toPage = 1}) async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await repository.getUsers(
      page: toPage,
      pageSize: pageSize,
      query: search.text.trim(),
      role: role,
      blocked: blocked,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      switch (result) {
        case Success(data: final data):
          users = data.items;
          page = toPage;
          pageCounts = data.pageCounts;
          total = data.total;
        case Failure(message: final message):
          error = message ?? 'Could not load users.';
        case Cancelled():
          break;
      }
    });
  }

  Future<void> loadSummary() async {
    final result = await repository.getSummary();
    if (!mounted) return;
    if (result case Success(data: final data)) setState(() => summary = data);
  }

  Future<void> toggleBlocked(User user) async {
    final block = user.blockedAt == null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _BlockDialog(user: user, block: block),
    );
    if (confirmed != true || !mounted) return;
    final result = await repository.setBlocked(user.id, blocked: block).withLoading();
    if (!mounted) return;
    switch (result) {
      case Success(data: final updated):
        // Đang lọc theo trạng thái thì dòng vừa đổi không còn khớp bộ lọc: tải lại trang hiện tại.
        if (blocked == null) {
          setState(() => users = [for (final u in users) u.id == updated.id ? updated : u]);
        } else {
          load(toPage: page);
        }
        loadSummary();
        context.showToast(
          '${user.name} has been ${block ? 'blocked' : 'unblocked'}.',
          type: ToastType.success,
        );
      case Failure(message: final message):
        context.showToast(
          message ?? 'Could not ${block ? 'block' : 'unblock'} this account. Please try again.',
          type: ToastType.error,
        );
      case Cancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mở thẳng URL lúc user chưa tải xong thì router chưa chặn được; chặn lại ở đây.
    final role = context.select<AppCubit, String?>((cubit) => cubit.state.user?.role);
    if (role != null && role.toUpperCase() != 'ADMIN') {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FB),
        body: Center(
          child: Text('You do not have access to this page.', style: TextStyle(color: _muted)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1368),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [_titleCard(), _toolbar(), _table()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleCard() => Container(
    padding: const EdgeInsets.fromLTRB(17, 22, 24, 22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      spacing: 12,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(SolarIconsOutline.usersGroupRounded, color: _primary),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            const Text('Users', style: TextStyle(fontSize: 22, color: _text)),
            Text(
              '${summary.total} ${summary.total == 1 ? 'user' : 'users'} · '
              '${summary.admins} ${summary.admins == 1 ? 'admin' : 'admins'} · '
              '${summary.blocked} blocked',
              style: const TextStyle(fontSize: 15, color: _muted),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _toolbar() {
    const outline = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _border),
    );
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: TextField(
            controller: search,
            onChanged: (_) {
              searchDebounce?.cancel();
              searchDebounce = Timer(const Duration(milliseconds: 400), load);
            },
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(SolarIconsOutline.magnifier, size: 18, color: _muted),
              hintText: 'Search by name or email',
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9A9A9A)),
              border: outline,
              enabledBorder: outline,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        PopupMenuButton<String?>(
          tooltip: 'Filter by role',
          position: PopupMenuPosition.under,
          onSelected: (value) {
            setState(() => role = value);
            load();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: null, child: Text('All roles')),
            PopupMenuItem(value: 'ADMIN', child: Text('Admin')),
            PopupMenuItem(value: 'CLIENT', child: Text('Client')),
          ],
          child: Container(
            height: 46,
            padding: const EdgeInsets.only(left: 14, right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              spacing: 8,
              children: [
                const Text('Role:', style: TextStyle(fontSize: 14, color: _muted)),
                Text(switch (role) {
                  'ADMIN' => 'Admin',
                  'CLIENT' => 'Client',
                  _ => 'All roles',
                }, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _text)),
                const Icon(SolarIconsOutline.altArrowDown, size: 14, color: _muted),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1F4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              for (final (value, label) in const [
                (null, 'All'),
                (false, 'Active'),
                (true, 'Blocked'),
              ])
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    if (blocked == value) return;
                    setState(() => blocked = value);
                    load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: blocked == value ? Colors.white : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: blocked == value ? FontWeight.w500 : FontWeight.w400,
                        color: blocked == value ? _primary : const Color(0xFF4A4A4A),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _table() {
    const header = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _muted);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 44,
            color: const Color(0xFFF7F9FB),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Row(
              children: [
                Expanded(flex: 23, child: Text('USER', style: header)),
                Expanded(flex: 10, child: Text('ROLE', style: header)),
                Expanded(flex: 10, child: Text('STATUS', style: header)),
                Expanded(flex: 15, child: Text('JOINED', style: header)),
                Expanded(flex: 8, child: SizedBox()),
              ],
            ),
          ),
          if (loading)
            const Padding(padding: EdgeInsets.all(48), child: AppLoader())
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                spacing: 12,
                children: [
                  Text(error!, style: const TextStyle(color: _muted)),
                  OutlinedButton(
                    onPressed: () => load(toPage: page),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No users found',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
            )
          else
            for (final user in users) _row(user),
          _footer(),
        ],
      ),
    );
  }

  Widget _row(User user) {
    final isAdmin = user.role.toUpperCase() == 'ADMIN';
    final blockedAt = user.blockedAt;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 23,
            child: Row(
              spacing: 12,
              children: [
                PostAvatar(url: user.avatar, name: user.name, radius: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _text,
                        ),
                      ),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerLeft,
              child: isAdmin
                  ? _badge('Admin', const Color(0xFFF1E9FB), const Color(0xFF7B3FC4))
                  : _badge('Client', const Color(0xFFF0F1F3), const Color(0xFF4A4A4A)),
            ),
          ),
          Expanded(
            flex: 10,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: blockedAt == null
                  ? [_badge('Active', const Color(0xFFE6F4EA), const Color(0xFF1E8E3E))]
                  : [
                      _badge('Blocked', const Color(0xFFFDECEA), _red),
                      Text(
                        'since ${DateFormat('dd MMM yyyy').format(blockedAt.toLocal())}',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
            ),
          ),
          Expanded(
            flex: 15,
            child: Text(
              user.createdAt == null
                  ? ''
                  : DateFormat('dd MMM yyyy').format(user.createdAt!.toLocal()),
              style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A4A)),
            ),
          ),
          Expanded(
            flex: 8,
            child: Align(
              alignment: Alignment.centerRight,
              child: isAdmin
                  ? null
                  : OutlinedButton.icon(
                      onPressed: () => toggleBlocked(user),
                      icon: Icon(
                        blockedAt == null
                            ? SolarIconsOutline.lockKeyholeMinimalistic
                            : SolarIconsOutline.lockKeyholeMinimalisticUnlocked,
                        size: 16,
                      ),
                      label: Text(blockedAt == null ? 'Block' : 'Unblock'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: foreground),
    ),
  );

  Widget _footer() {
    final from = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final to = (from + users.length - 1).clamp(0, total);
    // Trang đầu, trang cuối và các trang quanh trang hiện tại; khoảng trống thành "…".
    final pages = <int?>[];
    for (var p = 1; p <= pageCounts; p++) {
      if (p == 1 || p == pageCounts || (p - page).abs() <= 1) {
        pages.add(p);
      } else if (pages.last != null) {
        pages.add(null);
      }
    }
    Widget pageButton(Widget child, {int? toPage, bool active = false}) => SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: active ? _primary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: active ? BorderSide.none : const BorderSide(color: _border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: toPage == null || active || loading ? null : () => load(toPage: toPage),
          child: Center(child: child),
        ),
      ),
    );
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            child: Text(
              'Showing $from–$to of $total',
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
          Row(
            spacing: 4,
            children: [
              pageButton(
                Icon(SolarIconsOutline.altArrowLeft, size: 14, color: page > 1 ? _text : _border),
                toPage: page > 1 ? page - 1 : null,
              ),
              for (final p in pages)
                p == null
                    ? pageButton(const Text('…', style: TextStyle(fontSize: 13)))
                    : pageButton(
                        Text(
                          '$p',
                          style: TextStyle(fontSize: 13, color: p == page ? Colors.white : _text),
                        ),
                        toPage: p,
                        active: p == page,
                      ),
              pageButton(
                Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 14,
                  color: page < pageCounts ? _text : _border,
                ),
                toPage: page < pageCounts ? page + 1 : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Xác nhận khoá hoặc mở khoá, nút xác nhận màu đỏ (Figma P1·2, P1·3).
class _BlockDialog extends StatelessWidget {
  const _BlockDialog({required this.user, required this.block});
  final User user;
  final bool block;

  @override
  Widget build(BuildContext context) {
    final blockedAt = user.blockedAt;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: block ? 440 : 400,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: block ? const Color(0xFFFFF4E5) : const Color(0xFFEAF4FD),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  block
                      ? SolarIconsOutline.lockKeyholeMinimalistic
                      : SolarIconsOutline.lockKeyholeMinimalisticUnlocked,
                  size: 22,
                  color: block ? const Color(0xFFB26A00) : _primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${block ? 'Block' : 'Unblock'} ${user.name}?',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1E21),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                block
                    ? '${user.name} (${user.email}) will not be able to sign in to Ego. If they are '
                          'signed in now, they are signed out within 15 minutes. You can unblock them '
                          'at any time.'
                    : '${user.name} can sign in to Ego again.'
                          '${blockedAt == null ? '' : ' They have been blocked since '
                                    '${DateFormat('dd MMM yyyy').format(blockedAt.toLocal())}.'}',
                style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF65676B)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1C1E21),
                      side: const BorderSide(color: Color(0xFFE4E6EB)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(block ? 'Block account' : 'Unblock'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
