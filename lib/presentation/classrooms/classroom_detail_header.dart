import 'dart:async';

import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _muted = Color(0xFF65676B);
const _border = Color(0xFFE4E6EB);

/// Thanh trên cùng chỉ có nút Back (giống trang chi tiết bài viết), căn theo khung nội dung.
class ClassroomTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ClassroomTopBar({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF7F9FB),
    child: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1128),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Banner đầu trang chi tiết lớp: avatar, tên, giáo viên, mã lớp và thao tác của giáo viên.
class ClassroomBanner extends StatefulWidget {
  const ClassroomBanner({
    super.key,
    required this.classroom,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onArchive,
  });

  final Classroom classroom;
  final bool canManage, busy;
  final VoidCallback onEdit, onArchive;

  @override
  State<ClassroomBanner> createState() => _ClassroomBannerState();
}

class _ClassroomBannerState extends State<ClassroomBanner> {
  Timer? _copyResetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.classroom.code));
    if (!mounted) return;
    _copyResetTimer?.cancel();
    setState(() => _copied = true);
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Widget _ghost(IconData icon, String label, VoidCallback? onPressed) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.16),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    icon: Icon(icon, size: 16),
    label: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final item = widget.classroom;
    final avatar = item.avatar;
    final hasAvatar = avatar != null && avatar.isNotEmpty;
    final cover = item.active ? const Color(0xFF4F6D8A) : const Color(0xFF8A8D91);
    final students = item.countApprovedMembers ?? item.members.length;
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [Color.lerp(cover, Colors.black, 0.12)!, cover]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              if (!item.active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Archived',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
                  ),
                ),
              if (widget.canManage) ...[
                _ghost(Icons.edit_outlined, 'Edit', widget.busy ? null : widget.onEdit),
                _ghost(Icons.archive_outlined, 'Archive', widget.busy ? null : widget.onArchive),
              ],
              // Giữ chiều cao hàng khi không có nút nào.
              const SizedBox(height: 40),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            runSpacing: 16,
            spacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      image: hasAvatar
                          ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                          : null,
                    ),
                    child: hasAvatar
                        ? null
                        : Text(
                            item.name.isEmpty ? '?' : item.name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              color: cover,
                            ),
                          ),
                  ),
                  const SizedBox(width: 20),
                  // Flexible để tên/dòng phụ co lại trên màn hẹp thay vì tràn ngang.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${item.teacher?.name ?? 'Teacher unavailable'}  ·  $students students',
                            style: const TextStyle(fontSize: 14, color: Color(0xFFDCE6EF)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _copy,
                  child: Tooltip(
                    message: _copied ? 'Copied' : 'Copy class code',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          const Text(
                            'Class code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                          Text(
                            item.code,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          Icon(
                            _copied ? Icons.check : Icons.copy_outlined,
                            size: 16,
                            color: ColorName.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tab dạng chữ gạch chân xanh: Announcements / Classwork / Calendar / People.
class ClassroomTabs extends StatelessWidget {
  const ClassroomTabs({super.key, required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const labels = ['Announcements', 'Classwork', 'Calendar', 'People'];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (index, label) in labels.indexed)
            InkWell(
              onTap: () => onSelected(index),
              child: Container(
                // Chữ nằm giữa ô (cả vùng hover): đệm đều hai bên, trên/dưới bù viền gạch chân 3px.
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 13),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: index == selected ? ColorName.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: index == selected ? FontWeight.w600 : FontWeight.w500,
                    color: index == selected ? ColorName.primary : _muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Cột trái của tab Announcements: bài tập sắp đến hạn và mô tả lớp.
class ClassroomStreamAside extends StatelessWidget {
  const ClassroomStreamAside({
    super.key,
    required this.classroom,
    required this.assignments,
    required this.onOpenAssignment,
    required this.onViewAll,
  });

  final Classroom classroom;
  final List<ClassroomAssignment> assignments;
  final ValueChanged<ClassroomAssignment> onOpenAssignment;
  final VoidCallback onViewAll;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _due(DateTime value) {
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Due ${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day} · '
        '${two(d.hour)}:${two(d.minute)}';
  }

  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ...children,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = assignments.where((a) => a.active && a.dueAt.isAfter(now)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final description = classroom.description?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _card('Upcoming', [
          if (upcoming.isEmpty)
            const Text('No work due soon', style: TextStyle(fontSize: 13, color: _muted)),
          for (final a in upcoming.take(3))
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onOpenAssignment(a),
              child: Row(
                spacing: 10,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppButtonStyles.tint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 18,
                      color: ColorName.primary,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(_due(a.dueAt), style: const TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          InkWell(
            onTap: onViewAll,
            child: const Text(
              'View all classwork',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorName.primary),
            ),
          ),
        ]),
        if (description.isNotEmpty) _AboutCard(description: description, card: _card),
      ],
    );
  }
}

/// Mô tả lớp gọn 6 dòng, bấm "See more" để xem hết.
class _AboutCard extends StatefulWidget {
  const _AboutCard({required this.description, required this.card});

  final String description;
  final Widget Function(String title, List<Widget> children) card;

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  static const _maxLines = 6;
  static const _style = TextStyle(fontSize: 13, height: 1.45, color: _muted);
  bool expanded = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final overflows = (TextPainter(
        text: TextSpan(text: widget.description, style: _style),
        maxLines: _maxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth - 40)).didExceedMaxLines;
      return widget.card('About', [
        Text(
          widget.description,
          maxLines: expanded ? null : _maxLines,
          overflow: expanded ? null : TextOverflow.ellipsis,
          style: _style,
        ),
        if (overflows)
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Text(
              expanded ? 'See less' : 'See more',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorName.primary,
              ),
            ),
          ),
      ]);
    },
  );
}
