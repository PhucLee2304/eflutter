import 'package:eflutter/presentation/classrooms/room_participants.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart'
    show VideoTrack, VideoTrackRenderer;

const _tileBackground = Color(0xff303134);
const _panelBackground = Color(0xff202124);

String roomParticipantLabel(RoomParticipantView participant) =>
    participant.isLocal
    ? '${participant.displayName} (You)'
    : participant.displayName;

String? roomConnectionLabel(RoomParticipantConnection connection) =>
    switch (connection) {
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
                    Center(
                      child: _Avatar(participant: participant, radius: 32),
                    ),
                  if (connectionLabel != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusChip(
                        icon:
                            participant.connection ==
                                RoomParticipantConnection.reconnecting
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      color: Colors.black54,
                      child: Row(
                        children: [
                          if (!participant.microphoneOn)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.mic_off,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              roomParticipantLabel(participant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          if (participant.isHost)
                            const _StatusChip(label: 'Teacher', dense: true),
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
  });

  final List<RoomParticipantView> participants;
  final VoidCallback onClose;

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
    return Material(
      color: _panelBackground,
      child: Theme(
        data: ThemeData.dark(useMaterial3: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'People (${widget.participants.length})',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close participants',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                controller: searchController,
                onChanged: (value) => setState(() => query = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search by name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            searchController.clear();
                            setState(() => query = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
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
                            _ParticipantRow(participant: p),
                        ],
                        if (students.isNotEmpty) ...[
                          _SectionHeader('Students (${students.length})'),
                          for (final p in students)
                            _ParticipantRow(participant: p),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
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
        title,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white70),
      ),
    ),
  );
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant});
  final RoomParticipantView participant;

  @override
  Widget build(BuildContext context) {
    final connectionLabel = roomConnectionLabel(participant.connection);
    final subtitle = [
      participant.isHost ? 'Teacher' : 'Student',
      ?connectionLabel,
    ].join(' · ');
    return ListTile(
      dense: true,
      leading: _Avatar(participant: participant, radius: 18),
      title: Text(
        roomParticipantLabel(participant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (participant.handRaisedAt != null)
            const _StateIcon(
              icon: Icons.back_hand,
              label: 'Hand raised',
              color: Color(0xfffdd663),
            ),
          _StateIcon(
            icon: participant.microphoneOn ? Icons.mic : Icons.mic_off,
            label: participant.microphoneOn
                ? 'Microphone on'
                : 'Microphone off',
          ),
          _StateIcon(
            icon: participant.cameraOn ? Icons.videocam : Icons.videocam_off,
            label: participant.cameraOn ? 'Camera on' : 'Camera off',
          ),
        ],
      ),
    );
  }
}

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
      child: Icon(
        icon,
        size: 18,
        color: color ?? Colors.white70,
        semanticLabel: label,
      ),
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
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(12),
    ),
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
