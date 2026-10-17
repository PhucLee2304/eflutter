import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/data_sources/room_socket_client.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:intl/intl.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/classrooms/room_connection_recovery.dart';
import 'package:eflutter/presentation/classrooms/room_join_control.dart';

class ClassroomRoomScreen extends StatefulWidget {
  const ClassroomRoomScreen({
    super.key,
    required this.classroomId,
    required this.roomId,
  });
  final int classroomId;
  final int roomId;

  @override
  State<ClassroomRoomScreen> createState() => _ClassroomRoomScreenState();
}

class _ClassroomRoomScreenState extends State<ClassroomRoomScreen> {
  static const _reconnectTimeout = Duration(seconds: 45);
  static const _roomStatusRetryDelay = Duration(seconds: 5);

  late final ClassroomRepository repository = ClassroomRepository(getIt<Dio>());
  late final RoomSocketClient roomSocket = RoomSocketClient(
    getIt<LocalDataBase>(),
  );
  StreamSubscription<RoomActivitySocketEvent>? roomActivitySubscription;
  ClassroomRoom? roomInfo;
  RoomActivity? roomActivity;
  Room? liveRoom;
  List<MediaDevice> cameras = const [];
  List<MediaDevice> microphones = const [];
  MediaDevice? camera;
  MediaDevice? microphone;
  LocalVideoTrack? previewTrack;
  bool cameraEnabled = true;
  bool microphoneEnabled = true;
  bool loading = true;
  bool connecting = false;
  String? error;
  String? deviceWarning;
  Timer? reconnectTimer;
  bool recoveringConnection = false;
  bool leavingRoom = false;

  @override
  void initState() {
    super.initState();
    roomActivitySubscription = roomSocket.activityEvents.listen((event) {
      if (event.roomId == widget.roomId) unawaited(_refreshActivity());
    });
    unawaited(roomSocket.connect());
    _prepare();
  }

  Future<void> _prepare() async {
    final results = await Future.wait([
      repository.getRoom(widget.classroomId, widget.roomId),
      repository.getRoomActivity(widget.classroomId, widget.roomId),
    ]);
    final result = results[0] as Result<ClassroomRoom>;
    final activityResult = results[1] as Result<RoomActivity>;
    try {
      await _startPreview();
      cameras = await Hardware.instance.videoInputs();
      camera = cameras.firstOrNull;
    } catch (_) {
      cameraEnabled = false;
      deviceWarning =
          'Camera permission was denied. You can still join with the camera off.';
    }
    try {
      final audioTrack = await LocalAudioTrack.create();
      await audioTrack.stop();
      microphones = await Hardware.instance.audioInputs();
      microphone = microphones.firstOrNull;
    } catch (_) {
      microphoneEnabled = false;
      deviceWarning = cameraEnabled
          ? 'Microphone permission was denied. You can still join in listen-only mode.'
          : 'Camera and microphone permissions were denied. You can still join in listen-only mode.';
    }
    if (!mounted) return;
    if (activityResult case Success(data: final activity)) {
      roomActivity = activity;
    }
    switch (result) {
      case Success(data: final value):
        setState(() {
          roomInfo = value;
          loading = false;
        });
      case Failure(message: final message):
        setState(() {
          error = message ?? 'Could not load the room';
          loading = false;
        });
      case Cancelled():
        setState(() => loading = false);
    }
  }

  Future<void> _startPreview() async {
    await previewTrack?.stop();
    previewTrack = null;
    if (!cameraEnabled) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final track = await LocalVideoTrack.createCameraTrack(
        CameraCaptureOptions(deviceId: camera?.deviceId),
      );
      previewTrack = track;
      if (mounted) setState(() => deviceWarning = null);
    } catch (_) {
      cameraEnabled = false;
      deviceWarning =
          'Camera permission is unavailable. Join with the camera off or allow access in your browser settings.';
      if (mounted) setState(() {});
    }
  }

  Future<void> _connect() async {
    reconnectTimer?.cancel();
    setState(() {
      connecting = true;
      error = null;
    });
    final result = await repository.joinRoom(widget.classroomId, widget.roomId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final connection):
        final mediaRoom = Room();
        try {
          await previewTrack?.stop();
          previewTrack = null;
          await mediaRoom.connect(connection.url, connection.token);
          await mediaRoom.localParticipant?.setCameraEnabled(
            cameraEnabled,
            cameraCaptureOptions: CameraCaptureOptions(
              deviceId: camera?.deviceId,
            ),
          );
          await mediaRoom.localParticipant?.setMicrophoneEnabled(
            microphoneEnabled,
            audioCaptureOptions: AudioCaptureOptions(
              deviceId: microphone?.deviceId,
            ),
          );
          mediaRoom.addListener(_roomChanged);
          if (!mounted) {
            await mediaRoom.disconnect();
            return;
          }
          setState(() {
            liveRoom = mediaRoom;
            roomInfo = connection.room;
            connecting = false;
          });
          await _refreshActivity();
        } catch (exception) {
          await mediaRoom.dispose();
          if (mounted) {
            setState(() {
              error = 'Could not connect to the classroom: $exception';
              connecting = false;
            });
          }
        }
      case Failure(message: final message):
        setState(() {
          error = message ?? 'Could not join the room';
          connecting = false;
        });
      case Cancelled():
        setState(() => connecting = false);
    }
  }

  void _roomChanged() {
    if (!mounted) return;
    switch (liveRoom?.connectionState) {
      case ConnectionState.connected:
        reconnectTimer?.cancel();
        recoveringConnection = false;
      case ConnectionState.reconnecting:
        _scheduleConnectionRecovery(_reconnectTimeout);
      case ConnectionState.disconnected:
        _scheduleConnectionRecovery(Duration.zero);
      default:
        break;
    }
    setState(() {});
  }

  void _scheduleConnectionRecovery(Duration delay) {
    if (leavingRoom ||
        recoveringConnection ||
        reconnectTimer?.isActive == true) {
      return;
    }
    reconnectTimer = Timer(delay, _recoverConnection);
  }

  Future<void> _recoverConnection() async {
    if (!mounted || leavingRoom || recoveringConnection) return;
    recoveringConnection = true;

    final result = await repository.getRoom(widget.classroomId, widget.roomId);
    if (!mounted || leavingRoom) return;

    // LiveKit có thể đã tự reconnect trong lúc request kiểm tra trạng thái
    // phòng đang chạy. Khi đó giữ nguyên kết nối hiện tại, không xin token mới.
    switch (result) {
      case Success(data: final room):
        roomInfo = room;
        await _refreshActivity();
        await _applyRecoveryAction(
          decideRoomConnectionRecovery(
            mediaConnected:
                liveRoom?.connectionState == ConnectionState.connected,
            roomRequestSucceeded: true,
            roomStatus: room.status,
          ),
        );
      case Failure():
      case Cancelled():
        await _applyRecoveryAction(
          decideRoomConnectionRecovery(
            mediaConnected:
                liveRoom?.connectionState == ConnectionState.connected,
            roomRequestSucceeded: false,
          ),
        );
    }
  }

  Future<void> _refreshActivity() async {
    final result = await repository.getRoomActivity(
      widget.classroomId,
      widget.roomId,
    );
    if (!mounted) return;
    if (result case Success(data: final activity)) {
      setState(() => roomActivity = activity);
    }
  }

  Future<void> _applyRecoveryAction(RoomConnectionRecoveryAction action) async {
    switch (action) {
      case RoomConnectionRecoveryAction.keepConnection:
        recoveringConnection = false;
        reconnectTimer?.cancel();
        setState(() {});
      case RoomConnectionRecoveryAction.exitRoom:
        await _exitClosedRoom();
      case RoomConnectionRecoveryAction.reconnect:
        final previousRoom = liveRoom;
        liveRoom = null;
        previousRoom?.removeListener(_roomChanged);
        await previousRoom?.dispose();
        recoveringConnection = false;
        if (mounted) {
          setState(() {});
          await _connect();
          if (mounted && liveRoom == null && !leavingRoom) {
            _scheduleConnectionRecovery(_roomStatusRetryDelay);
          }
        }
      case RoomConnectionRecoveryAction.retry:
        // Khi mạng vẫn mất, giữ màn hình và thử lại cho đến khi có thể xác
        // nhận trạng thái phòng từ backend.
        recoveringConnection = false;
        _scheduleConnectionRecovery(_roomStatusRetryDelay);
        setState(() {});
    }
  }

  Future<void> _exitClosedRoom() async {
    if (leavingRoom) return;
    leavingRoom = true;
    reconnectTimer?.cancel();
    final previousRoom = liveRoom;
    liveRoom = null;
    previousRoom?.removeListener(_roomChanged);
    await previousRoom?.dispose();
    if (mounted) context.pop();
  }

  Future<void> _leave({bool end = false}) async {
    if (end) {
      final result = await repository.endRoom(
        widget.classroomId,
        widget.roomId,
      );
      if (result case Failure(message: final message)) {
        if (mounted) {
          setState(() => error = message ?? 'Could not end the room');
        }
        return;
      }
    }
    leavingRoom = true;
    reconnectTimer?.cancel();
    await liveRoom?.disconnect();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    roomActivitySubscription?.cancel();
    roomSocket.close();
    leavingRoom = true;
    reconnectTimer?.cancel();
    previewTrack?.stop();
    liveRoom?.removeListener(_roomChanged);
    liveRoom?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (liveRoom == null) return _prejoin(context);
    return _conference(context);
  }

  Widget _prejoin(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Online classroom')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ready to join?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: const Color(0xff303134),
                    child: previewTrack == null
                        ? const Center(
                            child: Icon(
                              Icons.videocam_off,
                              size: 56,
                              color: Colors.white54,
                            ),
                          )
                        : VideoTrackRenderer(previewTrack!),
                  ),
                ),
              ),
              if (deviceWarning != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    deviceWarning!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: cameraEnabled,
                onChanged: (value) async {
                  setState(() => cameraEnabled = value);
                  await _startPreview();
                },
                title: const Text('Camera'),
                secondary: const Icon(Icons.videocam_outlined),
              ),
              if (cameraEnabled && cameras.isNotEmpty)
                DropdownButtonFormField<MediaDevice>(
                  initialValue: camera,
                  items: cameras
                      .map(
                        (device) => DropdownMenuItem(
                          value: device,
                          child: Text(
                            device.label.isEmpty ? 'Camera' : device.label,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    setState(() => camera = value);
                    await _startPreview();
                  },
                  decoration: const InputDecoration(labelText: 'Camera device'),
                ),
              SwitchListTile(
                value: microphoneEnabled,
                onChanged: (value) => setState(() => microphoneEnabled = value),
                title: const Text('Microphone'),
                secondary: const Icon(Icons.mic_outlined),
              ),
              if (microphoneEnabled && microphones.isNotEmpty)
                DropdownButtonFormField<MediaDevice>(
                  initialValue: microphone,
                  items: microphones
                      .map(
                        (device) => DropdownMenuItem(
                          value: device,
                          child: Text(
                            device.label.isEmpty ? 'Microphone' : device.label,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => microphone = value),
                  decoration: const InputDecoration(
                    labelText: 'Microphone device',
                  ),
                ),
              const SizedBox(height: 24),
              RoomJoinControl(
                status: roomInfo?.status,
                connecting: connecting,
                error: error,
                onJoin: _connect,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _conference(BuildContext context) {
    final participants = <Participant>[
      ?liveRoom?.localParticipant,
      ...?liveRoom?.remoteParticipants.values,
    ];
    return Scaffold(
      backgroundColor: const Color(0xff151719),
      appBar: AppBar(
        backgroundColor: const Color(0xff202124),
        foregroundColor: Colors.white,
        title: const Text('Online classroom'),
        actions: [
          IconButton(
            tooltip: roomInfo?.isHost == true ? 'Attendance' : 'My attendance',
            onPressed: () => context.push(
              roomAttendancePath(widget.classroomId, widget.roomId),
            ),
            icon: const Icon(Icons.fact_check_outlined),
          ),
          if (roomInfo?.isHost == true)
            TextButton.icon(
              onPressed: () => _leave(end: true),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End class'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade200),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = roomGridColumnCount(constraints.maxWidth);
          return Stack(
            children: [
              GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 16 / 10,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: participants.length,
                itemBuilder: (context, index) =>
                    _ParticipantTile(participant: participants[index]),
              ),
              if (liveRoom?.connectionState == ConnectionState.reconnecting)
                const Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Chip(
                      avatar: SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: Text('Reconnecting...'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: ColoredBox(
          color: const Color(0xff202124),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  tooltip: microphoneEnabled
                      ? 'Turn off microphone'
                      : 'Turn on microphone',
                  onPressed: () async {
                    microphoneEnabled = !microphoneEnabled;
                    await liveRoom?.localParticipant?.setMicrophoneEnabled(
                      microphoneEnabled,
                    );
                    if (mounted) setState(() {});
                  },
                  icon: Icon(microphoneEnabled ? Icons.mic : Icons.mic_off),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  tooltip: cameraEnabled ? 'Turn off camera' : 'Turn on camera',
                  onPressed: () async {
                    cameraEnabled = !cameraEnabled;
                    await liveRoom?.localParticipant?.setCameraEnabled(
                      cameraEnabled,
                    );
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    cameraEnabled ? Icons.videocam : Icons.videocam_off,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  tooltip: 'Leave',
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _leave,
                  icon: const Icon(Icons.call_end),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoomAttendanceScreen extends StatefulWidget {
  const RoomAttendanceScreen({
    super.key,
    required this.classroomId,
    required this.roomId,
  });
  final int classroomId;
  final int roomId;

  @override
  State<RoomAttendanceScreen> createState() => _RoomAttendanceScreenState();
}

class _RoomAttendanceScreenState extends State<RoomAttendanceScreen> {
  late final ClassroomRepository repository = ClassroomRepository(getIt<Dio>());
  List<RoomAttendanceSession>? sessions;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await repository.getRoomAttendance(
      widget.classroomId,
      widget.roomId,
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final value):
        setState(() {
          sessions = value;
          error = null;
        });
      case Failure(message: final message):
        setState(() => error = message ?? 'Could not load attendance');
      case Cancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<RoomAttendanceSession>>{};
    for (final session in sessions ?? const <RoomAttendanceSession>[]) {
      final key = session.user?.id ?? 'unknown-${session.id}';
      grouped.putIfAbsent(key, () => []).add(session);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: error != null
          ? Center(child: Text(error!))
          : sessions == null
          ? const Center(child: CircularProgressIndicator())
          : sessions!.isEmpty
          ? const Center(child: Text('No attendance sessions yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final userSessions = grouped.values.elementAt(index)
                  ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
                final first = userSessions.first;
                final name = first.user?.name ?? 'Unknown user';
                return ExpansionTile(
                  leading: CircleAvatar(
                    child: Text(name.characters.first.toUpperCase()),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    '${userSessions.length} session${userSessions.length == 1 ? '' : 's'}',
                  ),
                  trailing: Text(first.role),
                  children: userSessions
                      .map(
                        (session) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.login, size: 18),
                          title: Text(
                            DateFormat(
                              'MMM d, HH:mm:ss',
                            ).format(session.joinedAt),
                          ),
                          trailing: Text(
                            session.leftAt == null
                                ? 'Present'
                                : 'Left ${DateFormat('HH:mm:ss').format(session.leftAt!)}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});
  final Participant participant;

  @override
  Widget build(BuildContext context) {
    VideoTrack? video;
    for (final publication in participant.videoTrackPublications) {
      if (publication.track case final VideoTrack track) {
        video = track;
        break;
      }
    }
    return AnimatedContainer(
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
          color: const Color(0xff303134),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (video != null)
                VideoTrackRenderer(video)
              else
                const Icon(Icons.person, size: 64, color: Colors.white54),
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  color: Colors.black54,
                  child: Text(
                    participant.name.isEmpty
                        ? participant.identity
                        : participant.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
