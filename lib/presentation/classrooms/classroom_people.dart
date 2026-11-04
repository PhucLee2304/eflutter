import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/classrooms/gradebook_widgets.dart';
import 'package:flutter/material.dart';

/// Tab People (Figma 23:996): bảng học sinh lọc tại chỗ, khung yêu cầu tham gia cho giáo viên.
/// Không có yêu cầu hoặc không có quyền duyệt thì bảng giãn hết chiều rộng.
class ClassroomPeopleView extends StatefulWidget {
  const ClassroomPeopleView({
    super.key,
    required this.members,
    required this.requests,
    required this.canManage,
    required this.busy,
    required this.onRemove,
    required this.onReview,
    required this.onApproveAll,
  });

  final List<ClassroomMember> members;
  final List<ClassroomMember> requests;
  final bool canManage;
  final bool busy;
  final ValueChanged<ClassroomMember> onRemove;
  final void Function(ClassroomMember member, bool approve) onReview;
  final VoidCallback onApproveAll;

  @override
  State<ClassroomPeopleView> createState() => _ClassroomPeopleViewState();
}

class _ClassroomPeopleViewState extends State<ClassroomPeopleView> {
  String query = '';

  List<ClassroomMember> get filtered {
    final value = query.trim().toLowerCase();
    final members = [...widget.members]
      ..sort(
        (a, b) => (a.user?.name ?? '').toLowerCase().compareTo((b.user?.name ?? '').toLowerCase()),
      );
    if (value.isEmpty) return members;
    return members.where((member) {
      final user = member.user;
      return user != null &&
          (user.name.toLowerCase().contains(value) || user.email.toLowerCase().contains(value));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final showRequests = widget.canManage && widget.requests.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final compact = constraints.maxWidth < 640;
        final students = _students(compact: compact);
        if (!showRequests) return students;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_requests(), const SizedBox(height: 16), students],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: students),
            const SizedBox(width: 20),
            SizedBox(width: 320, child: _requests()),
          ],
        );
      },
    );
  }

  Widget _students({required bool compact}) {
    final rows = filtered;
    final count = widget.members.length;
    return GbCard(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
            spacing: 12,
            children: [
              if (compact)
                GbCardHead(
                  'Students',
                  '$count ${count == 1 ? 'student' : 'students'} in this class',
                )
              else
                Expanded(
                  child: GbCardHead(
                    'Students',
                    '$count ${count == 1 ? 'student' : 'students'} in this class',
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) => GbSearchField(
                  width: compact ? constraints.maxWidth : 240,
                  hint: 'Search by name or email',
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: const BoxDecoration(
            color: Gb.soft,
            border: Border.symmetric(horizontal: BorderSide(color: Gb.border)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 36, child: _HeadText('#')),
              const Expanded(child: _HeadText('STUDENT')),
              if (!compact) const SizedBox(width: 260, child: _HeadText('EMAIL')),
              if (widget.canManage) const SizedBox(width: 32),
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              count == 0 ? 'No students yet' : 'No students match "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Gb.muted),
            ),
          ),
        for (final (index, member) in rows.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: index == rows.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: Gb.field)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Gb.faint,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    spacing: 12,
                    children: [
                      GbAvatar(name: member.user?.name ?? '?', url: member.user?.avatar, size: 36),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.user?.name ?? 'User no longer available',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Gb.text,
                              ),
                            ),
                            if (compact)
                              Text(
                                member.user?.email ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Gb.muted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  SizedBox(
                    width: 260,
                    child: Text(
                      member.user?.email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Gb.muted),
                    ),
                  ),
                if (widget.canManage)
                  SizedBox(
                    width: 32,
                    child: PopupMenuButton<void>(
                      tooltip: 'More actions',
                      enabled: !widget.busy,
                      position: PopupMenuPosition.under,
                      offset: const Offset(0, 6),
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 6,
                      shadowColor: Colors.black26,
                      menuPadding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 190),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Gb.border),
                      ),
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(30),
                        minimumSize: const Size.square(30),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.more_horiz, size: 18, color: Gb.muted),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          height: 36,
                          padding: EdgeInsets.zero,
                          onTap: () => widget.onRemove(member),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: const Row(
                              spacing: 10,
                              children: [
                                Icon(Icons.person_remove_outlined, size: 17, color: Gb.red),
                                Text(
                                  'Remove from class',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Gb.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _requests() => GbCard(
    padding: const EdgeInsets.all(18),
    children: [
      Row(
        spacing: 8,
        children: [
          const Text(
            'Join requests',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Gb.text),
          ),
          GbPill('${widget.requests.length}', background: Gb.orangeBg, foreground: Gb.orange),
          const Spacer(),
          if (widget.requests.length > 1)
            TextButton(
              onPressed: widget.busy ? null : widget.onApproveAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              child: const Text('Approve all'),
            ),
        ],
      ),
      const SizedBox(height: 8),
      for (final member in widget.requests)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            spacing: 10,
            children: [
              GbAvatar(name: member.user?.name ?? '?', url: member.user?.avatar),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.user?.name ?? 'Student',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Gb.text,
                      ),
                    ),
                    Text(
                      member.user?.email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Gb.muted),
                    ),
                  ],
                ),
              ),
              _squareButton(
                tooltip: 'Reject',
                icon: Icons.close,
                onPressed: () => widget.onReview(member, false),
              ),
              _squareButton(
                tooltip: 'Approve',
                icon: Icons.check,
                primary: true,
                onPressed: () => widget.onReview(member, true),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _squareButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool primary = false,
  }) => SizedBox.square(
    dimension: 30,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: primary ? ColorName.primary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: primary ? BorderSide.none : const BorderSide(color: Gb.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.busy ? null : onPressed,
          child: Icon(icon, size: 16, color: primary ? Colors.white : Gb.muted),
        ),
      ),
    ),
  );
}

class _HeadText extends StatelessWidget {
  const _HeadText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Gb.muted),
  );
}
