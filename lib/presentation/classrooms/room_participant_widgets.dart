import 'package:eflutter/presentation/classrooms/room_participants.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' show VideoTrack, VideoTrackRenderer;

const _tileBackground = Color(0xff303134);
const _panelBackground = Color(0xff22252B);

String roomParticipantLabel(RoomParticipantView participant) =>
    participant.isLocal ? '${participant.displayName} (You)' : participant.displayName;

String? roomConnectionLabel(RoomParticipantConnection connection) => switch (connection) {
  RoomParticipantConnection.good => null,
  RoomParticipantConnection.weak => 'Weak connection',
  RoomParticipantConnection.reconnecting => 'Reconnecting',
};

class RoomParticipantTile extends StatelessWidget {
  const RoomParticipantTile({super.key, required this.participant, this.video});

  final RoomParticipantView participant;
  final VideoTrack? video;

  @override
  Widget build(BuildContext context) {
    final connectionLabel = roomConnectionLabel(participant.connection);
    final semantics = [
      roomParticipantLabel(participant),
      if (participant.isHost) 'teacher',
      participant.microphoneOn ? 'microphone on' : 'microphone off',
      participant.cameraOn ? 'camera on' : 'camera off',
      if (participant.isSpeaking) 'speaking',
      if (participant.handRaisedAt != null) 'hand raised',
      ?connectionLabel,
    ].join(', ');
    return Semantics(
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: participant.isSpeaking
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: ColoredBox(
              color: _tileBackground,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video != null && participant.cameraOn)
                    VideoTrackRenderer(video!)
                  else
                    Center(child: _Avatar(participant: participant, radius: 32)),
                  if (participant.handRaisedAt != null)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: _StatusChip(icon: Icons.back_hand, label: 'Hand raised', dense: true),
                    ),
                  if (connectionLabel != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusChip(
                        icon: participant.connection == RoomParticipantConnection.reconnecting
                            ? Icons.sync
                            : Icons.signal_cellular_alt_1_bar,
                        label: connectionLabel,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      color: Colors.black54,
                      child: Row(
                        children: [
                          if (!participant.microphoneOn)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.mic_off, size: 16, color: Colors.white),
                            ),
                          Expanded(
                            child: Text(
                              roomParticipantLabel(participant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          if (participant.isHost) const _StatusChip(label: 'Teacher', dense: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoomParticipantPanel extends StatefulWidget {
  const RoomParticipantPanel({
    super.key,
    required this.participants,
    required this.onClose,
    this.onLowerHand,
    this.onLowerAllHands,
    this.onModerate,
    this.onMuteAll,
  });

  final List<RoomParticipantView> participants;
  final VoidCallback onClose;

  /// Chỉ giáo viên có các thao tác hạ tay; null thì chỉ hiển thị trạng thái.
  final ValueChanged<String>? onLowerHand;
  final VoidCallback? onLowerAllHands;

  /// Thao tác quản trị chỉ có ở giáo viên.
  final void Function(String identity, RoomParticipantAction action)? onModerate;
  final VoidCallback? onMuteAll;

  @override
  State<RoomParticipantPanel> createState() => _RoomParticipantPanelState();
}

class _RoomParticipantPanelState extends State<RoomParticipantPanel> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = filterRoomParticipants(widget.participants, query)
      ..sort(compareRoomParticipants);
    final hosts = visible.where((p) => p.isHost).toList();
    final students = visible.where((p) => !p.isHost).toList();
    // Ô video có viền trong suốt 3px, nên lề và bo góc ở đây lệch 3px để mép trùng nhau.
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 7, 19, 11),
      child: Material(
        color: _panelBackground,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: const BorderSide(color: Color(0x14FFFFFF)),
        ),
        child: Theme(
          data: ThemeData.dark(useMaterial3: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(
                  spacing: 8,
                  children: [
                    Semantics(
                      header: true,
                      child: const Text(
                        'People',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.participants.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close participants',
                      onPressed: widget.onClose,
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => setState(() => query = value),
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0x0FFFFFFF),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintText: 'Search by name',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              iconSize: 16,
                              onPressed: () {
                                searchController.clear();
                                setState(() => query = '');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              // Thao tác cho cả lớp nằm ở hàng riêng để vừa panel trên màn hình hẹp.
              if (_bulkActions case final actions when actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                  child: Wrap(spacing: 4, children: actions),
                ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text(
                          'No participants found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView(
                        children: [
                          if (hosts.isNotEmpty) ...[
                            const _SectionHeader('Teacher'),
                            for (final p in hosts)
                              _ParticipantRow(
                                participant: p,
                                onLowerHand: widget.onLowerHand,
                                onModerate: widget.onModerate,
                              ),
                          ],
                          if (students.isNotEmpty) ...[
                            _SectionHeader('Students · ${students.length}'),
                            for (final p in students)
                              _ParticipantRow(
                                participant: p,
                                onLowerHand: widget.onLowerHand,
                                onModerate: widget.onModerate,
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on _RoomParticipantPanelState {
  List<Widget> get _bulkActions => [
    if (widget.onLowerAllHands != null && widget.participants.any((p) => p.handRaisedAt != null))
      TextButton.icon(
        onPressed: widget.onLowerAllHands,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xfffdd663),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        icon: const Icon(Icons.back_hand_outlined, size: 16),
        label: const Text('Lower all'),
      ),
    if (widget.onMuteAll != null &&
        widget.participants.any((p) => !p.isHost && !p.isLocal && p.microphoneAllowed))
      TextButton.icon(
        onPressed: widget.onMuteAll,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        icon: const Icon(Icons.mic_off_outlined, size: 16),
        label: const Text('Mute all'),
      ),
  ];
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Semantics(
      header: true,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Colors.white54,
        ),
      ),
    ),
  );
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant, this.onLowerHand, this.onModerate});
  final RoomParticipantView participant;
  final ValueChanged<String>? onLowerHand;
  final void Function(String identity, RoomParticipantAction action)? onModerate;

  @override
  Widget build(BuildContext context) {
    final connectionLabel = roomConnectionLabel(participant.connection);
    final subtitle = [
      participant.isHost ? 'Teacher' : 'Student',
      if (participant.presenting)
        'Presenting'
      else if (participant.screenShareRequested)
        'Wants to present',
      if (!participant.microphoneAllowed) 'Muted by teacher',
      if (!participant.cameraAllowed) 'Camera off by teacher',
      ?connectionLabel,
    ].join(' · ');
    final moderate = onModerate;
    final canModerate = moderate != null && !participant.isHost && !participant.isLocal;
    return ListTile(
      dense: true,
      leading: _Avatar(participant: participant, radius: 18),
      title: Text(
        roomParticipantLabel(participant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Colors.white54),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (participant.presenting)
            const _StateIcon(
              icon: Icons.present_to_all,
              label: 'Presenting',
              color: Color(0xff8ab4f8),
            ),
          if (participant.handRaisedAt != null && onLowerHand != null)
            IconButton(
              tooltip: 'Lower ${participant.displayName}\'s hand',
              visualDensity: VisualDensity.compact,
              onPressed: () => onLowerHand!(participant.identity),
              icon: const Icon(Icons.back_hand, size: 18, color: Color(0xfffdd663)),
            )
          else if (participant.handRaisedAt != null)
            const _StateIcon(icon: Icons.back_hand, label: 'Hand raised', color: Color(0xfffdd663)),
          _StateIcon(
            icon: participant.microphoneOn ? Icons.mic : Icons.mic_off,
            label: participant.microphoneOn ? 'Microphone on' : 'Microphone off',
          ),
          _StateIcon(
            icon: participant.cameraOn ? Icons.videocam : Icons.videocam_off,
            label: participant.cameraOn ? 'Camera on' : 'Camera off',
          ),
          if (canModerate)
            PopupMenuButton<RoomParticipantAction>(
              tooltip: 'More actions for ${participant.displayName}',
              iconSize: 18,
              icon: const Icon(Icons.more_horiz, color: Colors.white70),
              onSelected: (action) => moderate(participant.identity, action),
              position: PopupMenuPosition.under,
              offset: const Offset(0, 6),
              color: const Color(0xff2A2D34),
              surfaceTintColor: Colors.transparent,
              elevation: 8,
              shadowColor: Colors.black54,
              menuPadding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0x1FFFFFFF)),
              ),
              itemBuilder: (context) => [
                participant.microphoneAllowed
                    ? _menuItem(
                        RoomParticipantAction.mute,
                        Icons.mic_off_outlined,
                        'Mute microphone',
                      )
                    : _menuItem(
                        RoomParticipantAction.allowMicrophone,
                        Icons.mic_none,
                        'Allow microphone',
                      ),
                participant.cameraAllowed
                    ? _menuItem(
                        RoomParticipantAction.disableCamera,
                        Icons.videocam_off_outlined,
                        'Turn off camera',
                      )
                    : _menuItem(
                        RoomParticipantAction.allowCamera,
                        Icons.videocam_outlined,
                        'Allow camera',
                      ),
                const PopupMenuDivider(height: 9, thickness: 1, color: Color(0x1AFFFFFF)),
                _menuItem(
                  RoomParticipantAction.remove,
                  Icons.person_remove_outlined,
                  'Remove from session',
                  color: const Color(0xffF28B82),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

PopupMenuItem<RoomParticipantAction> _menuItem(
  RoomParticipantAction value,
  IconData icon,
  String label, {
  Color color = Colors.white,
}) => PopupMenuItem(
  value: value,
  height: 36,
  padding: const EdgeInsets.symmetric(horizontal: 10),
  child: Row(
    spacing: 10,
    children: [
      Icon(icon, size: 17, color: color.withValues(alpha: 0.85)),
      Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
      ),
    ],
  ),
);

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, size: 18, color: color ?? Colors.white70, semanticLabel: label),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.icon, this.dense = false});
  final String label;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.amber.shade200),
          const SizedBox(width: 4),
        ],
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.participant, required this.radius});
  final RoomParticipantView participant;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xff5f6368),
    child: Text(
      participant.displayName.characters.first.toUpperCase(),
      style: TextStyle(color: Colors.white, fontSize: radius * 0.8),
    ),
  );
}
