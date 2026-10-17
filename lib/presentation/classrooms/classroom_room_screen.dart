import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/data_sources/room_socket_client.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:intl/intl.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/classrooms/room_connection_recovery.dart';
import 'package:eflutter/presentation/classrooms/room_device_settings.dart';
import 'package:eflutter/presentation/classrooms/room_join_control.dart';
import 'package:eflutter/presentation/classrooms/room_participant_widgets.dart';
import 'package:eflutter/presentation/classrooms/room_participants.dart';

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

class _RoomEntry {
  const _RoomEntry(this.view, this.video);
  final RoomParticipantView view;
  final VideoTrack? video;
}

class _ClassroomRoomScreenState extends State<ClassroomRoomScreen> {
  static const _reconnectTimeout = Duration(seconds: 45);
  static const _roomStatusRetryDelay = Duration(seconds: 5);
  static const _controlsHideDelay = Duration(seconds: 4);
  static const _controlsAnimation = Duration(milliseconds: 200);
  static const _controlBarHeight = 72.0;
  static const _sidePanelBreakpoint = 900.0;
  static const _sidePanelWidth = 320.0;

  late final ClassroomRepository repository = ClassroomRepository(getIt<Dio>());
  late final RoomSocketClient roomSocket = RoomSocketClient(
    getIt<LocalDataBase>(),
  );
  StreamSubscription<RoomActivitySocketEvent>? roomActivitySubscription;
  StreamSubscription<void>? roomSocketReconnectSubscription;
  StreamSubscription<List<MediaDevice>>? deviceChangeSubscription;
  EventsListener<RoomEvent>? liveRoomListener;
  ClassroomRoom? roomInfo;
  RoomActivity? roomActivity;
  Room? liveRoom;
  List<MediaDevice> cameras = const [];
  List<MediaDevice> microphones = const [];
  List<MediaDevice> speakers = const [];
  MediaDevice? camera;
  MediaDevice? microphone;
  MediaDevice? speaker;
  final deviceOptions = ValueNotifier(
    const RoomDeviceOptions(microphones: [], cameras: [], speakers: []),
  );
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
  bool participantsOpen = false;
  bool controlsVisible = true;
  bool deviceDialogOpen = false;
  Timer? controlsHideTimer;
  ConnectionState? lastConnectionState;
  final controlsFocus = FocusScopeNode(debugLabel: 'Room controls');

  @override
  void initState() {
    super.initState();
    roomActivitySubscription = roomSocket.activityEvents.listen((event) {
      if (event.roomId == widget.roomId) unawaited(_refreshActivity());
    });
    // Event phát ra trong lúc socket mất kết nối không được replay, nên tải
    // lại snapshot mỗi khi socket nối lại.
    roomSocketReconnectSubscription = roomSocket.reconnected.listen(
      (_) => unawaited(_refreshActivity()),
    );
    deviceChangeSubscription = Hardware.instance.onDeviceChange.stream.listen(
      (devices) => unawaited(_devicesChanged(devices)),
    );
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
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
    try {
      speakers = await Hardware.instance.audioOutputs();
      speaker = resolveRoomDevice(
        Hardware.instance.selectedAudioOutput,
        speakers,
      );
    } catch (_) {
      speakers = const [];
    }
    _syncDeviceOptions();
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

  void _syncDeviceOptions() {
    deviceOptions.value = RoomDeviceOptions(
      microphones: microphones,
      cameras: cameras,
      speakers: speakers,
      microphone: microphone,
      camera: camera,
      speaker: speaker,
    );
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
    // Chặn gọi chồng (bấm Join nhiều lần hoặc recovery trùng lúc) vì mỗi lần
    // sẽ tạo một Room và participant mới.
    if (connecting || leavingRoom) return;
    reconnectTimer?.cancel();
    setState(() {
      connecting = true;
      error = null;
    });
    final result = await repository.joinRoom(widget.classroomId, widget.roomId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final connection):
        // Thiết bị đã chọn nằm trong roomOptions để track tạo lại sau khi bật
        // lại camera/mic hoặc reconnect vẫn dùng đúng thiết bị.
        final mediaRoom = Room(
          roomOptions: RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
              deviceId: camera?.deviceId,
            ),
            defaultAudioCaptureOptions: AudioCaptureOptions(
              deviceId: microphone?.deviceId,
            ),
            defaultAudioOutputOptions: AudioOutputOptions(
              deviceId: speaker?.deviceId,
            ),
          ),
        );
        final listener = mediaRoom.createListener()
          ..on<RoomReconnectedEvent>((_) => unawaited(_refreshActivity()));
        try {
          await previewTrack?.stop();
          previewTrack = null;
          await mediaRoom.connect(connection.url, connection.token);
          final warnings = await _publishInitialMedia(mediaRoom);
          mediaRoom.addListener(_roomChanged);
          if (!mounted || leavingRoom) {
            mediaRoom.removeListener(_roomChanged);
            await listener.dispose();
            await mediaRoom.disconnect();
            await mediaRoom.dispose();
            return;
          }
          setState(() {
            liveRoom = mediaRoom;
            liveRoomListener = listener;
            lastConnectionState = mediaRoom.connectionState;
            roomInfo = connection.room;
            connecting = false;
            controlsVisible = true;
          });
          _scheduleControlsHide();
          if (warnings.isNotEmpty) _showRoomMessage(warnings.join(' '));
          await _refreshActivity();
        } catch (exception) {
          await listener.dispose();
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

  /// Bật mic/camera theo lựa chọn của người dùng. Lỗi thiết bị không làm hỏng
  /// cả kết nối: người dùng vẫn vào phòng với thiết bị đó tắt.
  Future<List<String>> _publishInitialMedia(Room room) async {
    final local = room.localParticipant;
    if (local == null) return const [];
    final warnings = <String>[];
    try {
      await local.setCameraEnabled(
        cameraEnabled,
        cameraCaptureOptions: CameraCaptureOptions(deviceId: camera?.deviceId),
      );
    } catch (_) {
      cameraEnabled = false;
      warnings.add('Camera is unavailable, joined with the camera off.');
    }
    try {
      await local.setMicrophoneEnabled(
        microphoneEnabled,
        audioCaptureOptions: AudioCaptureOptions(
          deviceId: microphone?.deviceId,
        ),
      );
    } catch (_) {
      microphoneEnabled = false;
      warnings.add(
        'Microphone is unavailable, joined with the microphone off.',
      );
    }
    return warnings;
  }

  Future<void> _disposeLiveRoom() async {
    final previousRoom = liveRoom;
    final previousListener = liveRoomListener;
    liveRoom = null;
    liveRoomListener = null;
    previousRoom?.removeListener(_roomChanged);
    await previousListener?.dispose();
    await previousRoom?.dispose();
  }

  void _roomChanged() {
    if (!mounted) return;
    // Room notify cả khi đổi người đang nói, nên chỉ xử lý khi trạng thái kết
    // nối thực sự thay đổi để không liên tục reset timer ẩn thanh điều khiển.
    final state = liveRoom?.connectionState;
    final changed = state != lastConnectionState;
    lastConnectionState = state;
    if (!changed) {
      setState(() {});
      return;
    }
    switch (state) {
      case ConnectionState.connected:
        reconnectTimer?.cancel();
        recoveringConnection = false;
        _scheduleControlsHide();
      case ConnectionState.reconnecting:
        controlsVisible = true;
        _scheduleConnectionRecovery(_reconnectTimeout);
      case ConnectionState.disconnected:
        controlsVisible = true;
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
        // Giải phóng hoàn toàn Room cũ (kể cả local track) trước khi tạo Room
        // mới để không có participant hay track trùng.
        await _disposeLiveRoom();
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
    await _disposeLiveRoom();
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

  Future<void> _toggleMicrophone() async {
    final local = liveRoom?.localParticipant;
    if (local == null) return;
    final enable = !local.isMicrophoneEnabled();
    try {
      await local.setMicrophoneEnabled(
        enable,
        audioCaptureOptions: AudioCaptureOptions(
          deviceId: microphone?.deviceId,
        ),
      );
    } catch (_) {
      _showRoomMessage(
        enable
            ? 'Could not turn on the microphone. Check the browser permission.'
            : 'Could not turn off the microphone.',
      );
    }
    if (!mounted) return;
    setState(() => microphoneEnabled = local.isMicrophoneEnabled());
  }

  Future<void> _toggleCamera() async {
    final local = liveRoom?.localParticipant;
    if (local == null) return;
    final enable = !local.isCameraEnabled();
    try {
      await local.setCameraEnabled(
        enable,
        cameraCaptureOptions: CameraCaptureOptions(deviceId: camera?.deviceId),
      );
    } catch (_) {
      _showRoomMessage(
        enable
            ? 'Could not turn on the camera. Check the browser permission.'
            : 'Could not turn off the camera.',
      );
    }
    if (mounted) setState(() => cameraEnabled = local.isCameraEnabled());
  }

  // LiveKit đổi thiết bị trên track đang có (setDeviceId/switchCamera) nên
  // không tạo track mới; khi thiết bị đang tắt chỉ cập nhật roomOptions.
  Future<void> _selectMicrophone(MediaDevice device) async {
    microphone = device;
    _syncDeviceOptions();
    try {
      await liveRoom?.setAudioInputDevice(device);
    } catch (_) {
      _showRoomMessage('Could not switch to ${_deviceName(device)}.');
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectCamera(MediaDevice device) async {
    camera = device;
    _syncDeviceOptions();
    final room = liveRoom;
    if (room == null) {
      await _startPreview();
      return;
    }
    try {
      await room.setVideoInputDevice(device);
    } catch (_) {
      _showRoomMessage('Could not switch to ${_deviceName(device)}.');
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectSpeaker(MediaDevice device) async {
    speaker = device;
    _syncDeviceOptions();
    try {
      await liveRoom?.setAudioOutputDevice(device);
    } catch (_) {
      _showRoomMessage('Could not switch to ${_deviceName(device)}.');
    }
    if (mounted) setState(() {});
  }

  String _deviceName(MediaDevice device) =>
      device.label.isEmpty ? 'the selected device' : device.label;

  /// Cập nhật danh sách khi thiết bị được cắm/rút; nếu thiết bị đang dùng biến
  /// mất thì chuyển sang thiết bị khả dụng đầu tiên và báo cho người dùng.
  Future<void> _devicesChanged(List<MediaDevice> devices) async {
    if (!mounted || leavingRoom) return;
    final nextMicrophones = devices
        .where((d) => d.kind == 'audioinput')
        .toList();
    final nextCameras = devices.where((d) => d.kind == 'videoinput').toList();
    final nextSpeakers = devices.where((d) => d.kind == 'audiooutput').toList();
    final nextMicrophone = resolveRoomDevice(microphone, nextMicrophones);
    final nextCamera = resolveRoomDevice(camera, nextCameras);
    final nextSpeaker = resolveRoomDevice(speaker, nextSpeakers);
    final microphoneLost =
        microphone != null && nextMicrophone?.deviceId != microphone!.deviceId;
    final cameraLost =
        camera != null && nextCamera?.deviceId != camera!.deviceId;
    final speakerLost =
        speaker != null && nextSpeaker?.deviceId != speaker!.deviceId;
    microphones = nextMicrophones;
    cameras = nextCameras;
    speakers = nextSpeakers;
    final messages = <String>[];

    if (microphoneLost && nextMicrophone != null) {
      messages.add(
        'Microphone disconnected. Switched to ${_deviceName(nextMicrophone)}.',
      );
      await _selectMicrophone(nextMicrophone);
    } else {
      microphone = nextMicrophone;
      if (microphoneLost) {
        messages.add('Microphone disconnected.');
        microphoneEnabled = false;
        try {
          await liveRoom?.localParticipant?.setMicrophoneEnabled(false);
        } catch (_) {}
      }
    }

    if (cameraLost && nextCamera != null) {
      messages.add(
        'Camera disconnected. Switched to ${_deviceName(nextCamera)}.',
      );
      await _selectCamera(nextCamera);
    } else {
      camera = nextCamera;
      if (cameraLost) {
        messages.add('Camera disconnected.');
        cameraEnabled = false;
        try {
          await liveRoom?.localParticipant?.setCameraEnabled(false);
        } catch (_) {}
        if (liveRoom == null) await _startPreview();
      }
    }

    if (speakerLost && nextSpeaker != null) {
      messages.add(
        'Speaker disconnected. Switched to ${_deviceName(nextSpeaker)}.',
      );
      await _selectSpeaker(nextSpeaker);
    } else {
      speaker = nextSpeaker;
    }

    _syncDeviceOptions();
    if (!mounted) return;
    if (messages.isNotEmpty) {
      if (liveRoom == null) {
        deviceWarning = messages.join(' ');
      } else {
        _showRoomMessage(messages.join(' '));
      }
    }
    setState(() {});
  }

  Future<void> _reloadDevices() async {
    try {
      await _devicesChanged(await Hardware.instance.enumerateDevices());
    } catch (_) {}
  }

  Future<void> _openDeviceSettings() async {
    deviceDialogOpen = true;
    _syncDeviceOptions();
    // Nhãn thiết bị có thể chỉ xuất hiện sau khi trình duyệt cấp quyền.
    unawaited(_reloadDevices());
    await showDialog<void>(
      context: context,
      builder: (_) => RoomDeviceSettingsDialog(
        options: deviceOptions,
        onMicrophoneChanged: _selectMicrophone,
        onCameraChanged: _selectCamera,
        onSpeakerChanged: _selectSpeaker,
      ),
    );
    deviceDialogOpen = false;
    if (mounted) _showControls();
  }

  void _showRoomMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, _controlBarHeight + 16),
          content: Text(message),
        ),
      );
  }

  bool get _canHideControls =>
      liveRoom?.connectionState == ConnectionState.connected &&
      !participantsOpen &&
      !deviceDialogOpen &&
      !controlsFocus.hasFocus;

  void _showControls() {
    if (!mounted || liveRoom == null) return;
    if (!controlsVisible) setState(() => controlsVisible = true);
    _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    controlsHideTimer?.cancel();
    controlsHideTimer = Timer(_controlsHideDelay, () {
      if (mounted && controlsVisible && _canHideControls) {
        setState(() => controlsVisible = false);
      }
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Chỉ hiện lại thanh điều khiển, không chặn phím để ô nhập và phím Tab
    // vẫn hoạt động bình thường.
    if (event is KeyDownEvent) _showControls();
    return false;
  }

  void _toggleParticipants() {
    setState(() {
      participantsOpen = !participantsOpen;
      controlsVisible = true;
    });
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    controlsHideTimer?.cancel();
    roomActivitySubscription?.cancel();
    roomSocketReconnectSubscription?.cancel();
    deviceChangeSubscription?.cancel();
    roomSocket.close();
    leavingRoom = true;
    reconnectTimer?.cancel();
    previewTrack?.stop();
    unawaited(_disposeLiveRoom());
    controlsFocus.dispose();
    deviceOptions.dispose();
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
      child: SingleChildScrollView(
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
                                semanticLabel: 'Camera preview is off',
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
                    key: ValueKey('prejoin_camera_${camera?.deviceId}'),
                    initialValue: camera,
                    isExpanded: true,
                    items: cameras
                        .map(
                          (device) => DropdownMenuItem(
                            value: device,
                            child: Text(
                              device.label.isEmpty ? 'Camera' : device.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _selectCamera(value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Camera device',
                    ),
                  ),
                SwitchListTile(
                  value: microphoneEnabled,
                  onChanged: (value) =>
                      setState(() => microphoneEnabled = value),
                  title: const Text('Microphone'),
                  secondary: const Icon(Icons.mic_outlined),
                ),
                if (microphoneEnabled && microphones.isNotEmpty)
                  DropdownButtonFormField<MediaDevice>(
                    key: ValueKey('prejoin_microphone_${microphone?.deviceId}'),
                    initialValue: microphone,
                    isExpanded: true,
                    items: microphones
                        .map(
                          (device) => DropdownMenuItem(
                            value: device,
                            child: Text(
                              device.label.isEmpty
                                  ? 'Microphone'
                                  : device.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _selectMicrophone(value);
                    },
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
    ),
  );

  List<_RoomEntry> _participantEntries(Room room) {
    final hands = {
      for (final state
          in roomActivity?.participants ?? const <RoomParticipantState>[])
        state.userId: state.handRaisedAt,
    };
    final reconnecting = room.connectionState == ConnectionState.reconnecting;
    final participants = <(Participant, bool)>[
      if (room.localParticipant case final local?) (local, true),
      for (final remote in room.remoteParticipants.values) (remote, false),
    ];
    final entries = [
      for (final (participant, isLocal) in participants)
        _RoomEntry(
          roomParticipantViewFrom(
            participant,
            isLocal: isLocal,
            isHost:
                participant.metadata == roomHostMetadata ||
                (isLocal && roomInfo?.isHost == true),
            roomReconnecting: reconnecting,
            handRaisedAt: hands[participant.identity],
          ),
          _cameraTrack(participant),
        ),
    ];
    return dedupeRoomParticipants(entries, (entry) => entry.view.identity)
      ..sort((a, b) => compareRoomParticipants(a.view, b.view, byHand: false));
  }

  VideoTrack? _cameraTrack(Participant participant) {
    final publication = participant.getTrackPublicationBySource(
      TrackSource.camera,
    );
    final track = publication?.track;
    if (publication == null || publication.muted || track is! VideoTrack) {
      return null;
    }
    return track;
  }

  Widget _conference(BuildContext context) {
    final room = liveRoom!;
    final entries = _participantEntries(room);
    final views = [for (final entry in entries) entry.view];
    final showControls =
        controlsVisible ||
        participantsOpen ||
        room.connectionState != ConnectionState.connected;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barHeight = _controlBarHeight + bottomInset;
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
      body: MouseRegion(
        onHover: (_) => _showControls(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _showControls(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidePanel =
                  participantsOpen &&
                  constraints.maxWidth >= _sidePanelBreakpoint;
              final panel = participantsOpen
                  ? RoomParticipantPanel(
                      participants: views,
                      onClose: _toggleParticipants,
                    )
                  : null;
              return Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedPadding(
                      duration: _controlsAnimation,
                      padding: EdgeInsets.only(
                        bottom: showControls ? barHeight : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _participantGrid(entries)),
                          if (sidePanel)
                            SizedBox(width: _sidePanelWidth, child: panel),
                        ],
                      ),
                    ),
                  ),
                  // Trên màn hình hẹp panel phủ vùng video nhưng dừng phía trên
                  // thanh điều khiển để không che các nút.
                  if (panel != null && !sidePanel)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      bottom: barHeight,
                      child: panel,
                    ),
                  if (room.connectionState == ConnectionState.reconnecting)
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _controlBar(
                      room,
                      visible: showControls,
                      participantCount: views.length,
                      bottomInset: bottomInset,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _participantGrid(List<_RoomEntry> entries) => LayoutBuilder(
    builder: (context, constraints) {
      const padding = 12.0;
      const spacing = 10.0;
      final area = Size(
        math.max(0, constraints.maxWidth - padding * 2),
        math.max(0, constraints.maxHeight - padding * 2),
      );
      final tile = roomTileSize(area, entries.length, spacing: spacing);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: area.height),
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final entry in entries)
                  SizedBox.fromSize(
                    key: ValueKey(entry.view.identity),
                    size: tile,
                    child: RoomParticipantTile(
                      participant: entry.view,
                      video: entry.video,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _controlBar(
    Room room, {
    required bool visible,
    required int participantCount,
    required double bottomInset,
  }) {
    final local = room.localParticipant;
    final microphoneOn = local?.isMicrophoneEnabled() ?? false;
    final cameraOn = local?.isCameraEnabled() ?? false;
    final offStyle = IconButton.styleFrom(
      backgroundColor: Colors.red.shade400,
      foregroundColor: Colors.white,
    );
    final onStyle = IconButton.styleFrom(
      backgroundColor: const Color(0xff3c4043),
      foregroundColor: Colors.white,
    );
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: _controlsAnimation,
        offset: visible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: _controlsAnimation,
          opacity: visible ? 1 : 0,
          child: FocusScope(
            node: controlsFocus,
            child: Material(
              color: const Color(0xff202124),
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
                child: SizedBox(
                  height: _controlBarHeight - 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        isSelected: microphoneOn,
                        tooltip: microphoneOn
                            ? 'Turn off microphone'
                            : 'Turn on microphone',
                        style: microphoneOn ? onStyle : offStyle,
                        onPressed: _toggleMicrophone,
                        icon: const Icon(Icons.mic_off),
                        selectedIcon: const Icon(Icons.mic),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        isSelected: cameraOn,
                        tooltip: cameraOn
                            ? 'Turn off camera'
                            : 'Turn on camera',
                        style: cameraOn ? onStyle : offStyle,
                        onPressed: _toggleCamera,
                        icon: const Icon(Icons.videocam_off),
                        selectedIcon: const Icon(Icons.videocam),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        isSelected: participantsOpen,
                        tooltip: participantsOpen
                            ? 'Hide participants'
                            : 'Show participants ($participantCount)',
                        style: onStyle,
                        onPressed: _toggleParticipants,
                        icon: Badge(
                          label: Text('$participantCount'),
                          child: const Icon(Icons.people_outline),
                        ),
                        selectedIcon: Badge(
                          label: Text('$participantCount'),
                          child: const Icon(Icons.people),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        tooltip: 'Audio and video settings',
                        style: onStyle,
                        onPressed: _openDeviceSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        tooltip: 'Leave',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _leave,
                        icon: const Icon(Icons.call_end),
                      ),
                    ],
                  ),
                ),
              ),
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
