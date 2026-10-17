import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/data_sources/room_socket_client.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
import 'package:eflutter/presentation/classrooms/room_reactions.dart';
import 'package:eflutter/presentation/classrooms/room_screen_share.dart';

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

class _Presenter {
  const _Presenter(this.participant, {required this.isLocal, this.track});
  final Participant participant;
  final bool isLocal;
  final VideoTrack? track;
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
  bool screenShareBusy = false;
  final reviewingScreenShares = <String>{};
  bool handBusy = false;
  bool loweringOwnHand = false;
  bool reactionMenuOpen = false;
  final reactionSendLimiter = RoomReactionLimiter();
  final reactionReceiveLimiter = RoomReactionLimiter();
  List<RoomReactionBubble> reactionBubbles = const [];
  int nextReactionId = 0;
  final reactionTimers = <Timer>{};
  final controlsFocus = FocusScopeNode(debugLabel: 'Room controls');

  @override
  void initState() {
    super.initState();
    roomActivitySubscription = roomSocket.activityEvents.listen((event) {
      if (event.roomId != widget.roomId) return;
      unawaited(_refreshActivity());
      _handleOwnActivityEvent(event);
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
          ..on<RoomReconnectedEvent>((_) => unawaited(_refreshActivity()))
          // Track screen share của mình bị gỡ vì bất kỳ lý do gì (tự dừng, nút
          // dừng của trình duyệt, bị thay thế): báo backend xóa phê duyệt.
          ..on<LocalTrackUnpublishedEvent>((event) {
            if (event.publication.source == TrackSource.screenShareVideo) {
              unawaited(_ownScreenShareEnded());
            }
          })
          // Backend server-mute track khi giáo viên dừng hoặc có lượt chia sẻ
          // mới; gỡ hẳn track thay vì giữ track bị mute.
          ..on<DataReceivedEvent>(_receiveReaction)
          ..on<TrackMutedEvent>((event) {
            if (event.participant is LocalParticipant &&
                event.publication.source == TrackSource.screenShareVideo) {
              _showRoomMessage(
                roomInfo?.isHost == true
                    ? 'Your presentation ended because a student started presenting.'
                    : 'Your presentation was stopped.',
              );
              unawaited(_unpublishOwnScreenShare());
            }
          });
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
      !reactionMenuOpen &&
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

  bool get _screenShareSupported => const {
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  }.contains(defaultTargetPlatform);

  RoomParticipantState? get _ownActivityState {
    final identity = liveRoom?.localParticipant?.identity;
    for (final state
        in roomActivity?.participants ?? const <RoomParticipantState>[]) {
      if (state.userId == identity) return state;
    }
    return null;
  }

  String _participantName(String identity) {
    final room = liveRoom;
    final Participant? participant =
        room?.localParticipant?.identity == identity
        ? room?.localParticipant
        : room?.remoteParticipants.values
              .where((p) => p.identity == identity)
              .firstOrNull;
    final name = participant?.name.trim() ?? '';
    return name.isEmpty ? 'A student' : name;
  }

  void _handleOwnActivityEvent(RoomActivitySocketEvent event) {
    final identity = liveRoom?.localParticipant?.identity;
    if (identity == null || event.userId != identity) return;
    switch (event.type) {
      case 'SCREEN_SHARE_APPROVED':
        _showRoomMessage(
          'The teacher allowed you to present. Select Present to share your screen.',
        );
      case 'SCREEN_SHARE_REJECTED':
        unawaited(_unpublishOwnScreenShare());
        _showRoomMessage('The teacher declined your request to present.');
      case 'SCREEN_SHARE_STOPPED':
        // Dự phòng khi không nhận được server mute: không giữ track đã bị
        // backend dừng.
        unawaited(_unpublishOwnScreenShare());
      case 'HAND_LOWERED':
        // Tay vẫn đang giơ ở snapshot hiện tại và mình không tự hạ: giáo viên
        // đã hạ tay giúp.
        if (!loweringOwnHand && _ownActivityState?.handRaisedAt != null) {
          _showRoomMessage('The teacher lowered your hand.');
        }
    }
  }

  void _replaceOwnState(RoomParticipantState state) {
    final activity = roomActivity;
    if (activity == null) return;
    roomActivity = RoomActivity(
      roomId: activity.roomId,
      classroomId: activity.classroomId,
      status: activity.status,
      isHost: activity.isHost,
      updatedAt: activity.updatedAt,
      participants: [
        for (final participant in activity.participants)
          if (participant.userId != state.userId) participant,
        state,
      ],
    );
  }

  Future<void> _toggleHand() async {
    if (handBusy) return;
    final raise = _ownActivityState?.handRaisedAt == null;
    setState(() {
      handBusy = true;
      loweringOwnHand = !raise;
    });
    final result = await repository.setHandRaised(
      widget.classroomId,
      widget.roomId,
      raised: raise,
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final state):
        _replaceOwnState(state);
      case Failure(message: final message):
        _showRoomMessage(
          message ??
              (raise
                  ? 'Could not raise your hand.'
                  : 'Could not lower your hand.'),
        );
      case Cancelled():
        break;
    }
    setState(() {
      handBusy = false;
      loweringOwnHand = false;
    });
  }

  Future<void> _lowerHands({String? userId}) async {
    final result = await repository.lowerHands(
      widget.classroomId,
      widget.roomId,
      userId: userId,
    );
    if (result case Failure(message: final message)) {
      _showRoomMessage(message ?? 'Could not lower hands.');
    }
    await _refreshActivity();
  }

  Future<void> _sendReaction(RoomReaction reaction) async {
    final local = liveRoom?.localParticipant;
    if (local == null) return;
    if (!reactionSendLimiter.allow('self', DateTime.now())) {
      _showRoomMessage('You can send a few reactions every few seconds.');
      return;
    }
    // Data packet không quay về người gửi nên tự hiển thị reaction của mình.
    _showReaction('You', reaction);
    try {
      await local.publishData(
        encodeRoomReaction(reaction),
        reliable: false,
        topic: roomReactionTopic,
      );
    } catch (_) {
      // Mất reaction khi mạng yếu là chấp nhận được.
    }
  }

  void _receiveReaction(DataReceivedEvent event) {
    final sender = event.participant;
    if (event.topic != roomReactionTopic || sender == null) return;
    final reaction = decodeRoomReaction(event.data);
    if (reaction == null) return;
    if (!reactionReceiveLimiter.allow(sender.identity, DateTime.now())) return;
    final name = sender.name.trim();
    _showReaction(name.isEmpty ? sender.identity : name, reaction);
  }

  void _showReaction(String senderName, RoomReaction reaction) {
    if (!mounted) return;
    final bubble = RoomReactionBubble(
      id: nextReactionId++,
      reaction: reaction,
      senderName: senderName,
    );
    setState(
      () => reactionBubbles = addRoomReactionBubble(reactionBubbles, bubble),
    );
    late final Timer timer;
    timer = Timer(roomReactionDisplayDuration, () {
      reactionTimers.remove(timer);
      if (!mounted) return;
      setState(
        () => reactionBubbles = [
          for (final item in reactionBubbles)
            if (item.id != bubble.id) item,
        ],
      );
    });
    reactionTimers.add(timer);
  }

  Future<void> _requestScreenShare() async {
    if (screenShareBusy) return;
    setState(() => screenShareBusy = true);
    final result = await repository.requestScreenShare(
      widget.classroomId,
      widget.roomId,
    );
    if (!mounted) return;
    switch (result) {
      case Success():
        _showRoomMessage(
          'Request sent. You can present after the teacher allows it.',
        );
      case Failure(message: final message):
        _showRoomMessage(message ?? 'Could not send the request to present.');
      case Cancelled():
        break;
    }
    setState(() => screenShareBusy = false);
    await _refreshActivity();
  }

  /// Chọn nguồn trước (trong lúc còn thao tác của người dùng, trình duyệt mới
  /// cho mở hộp chọn), sau đó xin backend dừng lượt khác rồi mới publish.
  Future<void> _startScreenShare() async {
    final room = liveRoom;
    final local = room?.localParticipant;
    if (room == null || local == null || screenShareBusy) return;
    setState(() => screenShareBusy = true);
    try {
      await _unpublishOwnScreenShare();
      final LocalVideoTrack track;
      try {
        track = await LocalVideoTrack.createScreenShareTrack(
          const ScreenShareCaptureOptions(),
        );
      } catch (_) {
        _showRoomMessage(
          'Screen sharing was cancelled or blocked. To present, allow screen sharing in your browser or system settings and try again.',
        );
        return;
      }
      final result = await repository.startScreenShare(
        widget.classroomId,
        widget.roomId,
      );
      if (result is! Success) {
        await track.stop();
        _showRoomMessage(
          (result is Failure ? result.message : null) ??
              'Could not start presenting.',
        );
        unawaited(_refreshActivity());
        return;
      }
      if (!mounted || liveRoom != room) {
        await track.stop();
        return;
      }
      try {
        await local.publishVideoTrack(track);
      } catch (_) {
        await track.stop();
        _showRoomMessage(
          'Could not start presenting. Ask the teacher to allow it again.',
        );
        unawaited(_refreshActivity());
      }
    } finally {
      if (mounted) setState(() => screenShareBusy = false);
    }
  }

  Future<void> _unpublishOwnScreenShare() async {
    final local = liveRoom?.localParticipant;
    if (local?.getTrackPublicationBySource(TrackSource.screenShareVideo) ==
        null) {
      return;
    }
    try {
      await local!.setScreenShareEnabled(false);
    } catch (_) {}
  }

  Future<void> _ownScreenShareEnded() async {
    final identity = liveRoom?.localParticipant?.identity;
    if (mounted) setState(() {});
    if (identity == null || leavingRoom) return;
    await repository.stopScreenShare(
      widget.classroomId,
      widget.roomId,
      identity,
    );
    await _refreshActivity();
  }

  Future<void> _stopStudentScreenShare(String userId) async {
    final result = await repository.stopScreenShare(
      widget.classroomId,
      widget.roomId,
      userId,
    );
    if (result case Failure(message: final message)) {
      _showRoomMessage(message ?? 'Could not stop the presentation.');
    }
    await _refreshActivity();
  }

  Future<void> _reviewScreenShare(String userId, bool approve) async {
    if (!reviewingScreenShares.add(userId)) return;
    setState(() {});
    final result = await repository.reviewScreenShare(
      widget.classroomId,
      widget.roomId,
      userId,
      approve: approve,
    );
    reviewingScreenShares.remove(userId);
    if (result case Failure(message: final message)) {
      _showRoomMessage(
        message ??
            (approve
                ? 'Could not allow ${_participantName(userId)} to present.'
                : 'Could not decline the request.'),
      );
    }
    await _refreshActivity();
  }

  @override
  void dispose() {
    for (final timer in reactionTimers) {
      timer.cancel();
    }
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
    final states = {
      for (final state
          in roomActivity?.participants ?? const <RoomParticipantState>[])
        state.userId: state,
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
            handRaisedAt: states[participant.identity]?.handRaisedAt,
            screenShareRequested:
                states[participant.identity]?.screenShareRequestedAt != null &&
                states[participant.identity]?.screenShareApprovedAt == null,
          ),
          _cameraTrack(participant),
        ),
    ];
    return dedupeRoomParticipants(entries, (entry) => entry.view.identity)
      ..sort((a, b) => compareRoomParticipants(a.view, b.view, byHand: false));
  }

  bool _isHostParticipant(Participant participant) =>
      participant.metadata == roomHostMetadata ||
      (participant is LocalParticipant && roomInfo?.isHost == true);

  /// Người đang chia sẻ lấy trực tiếp từ track LiveKit, nên mọi client tự
  /// chuyển bố cục khi share bắt đầu, kết thúc hoặc người chia sẻ mất mạng.
  _Presenter? _presenter(Room room) {
    final presenters = <_Presenter>[
      if (room.localParticipant case final local?
          when local.isScreenShareEnabled())
        _Presenter(local, isLocal: true),
      for (final remote in room.remoteParticipants.values)
        if (remote.getTrackPublicationBySource(TrackSource.screenShareVideo)
            case final publication? when !publication.muted)
          _Presenter(
            remote,
            isLocal: false,
            track: publication.track is VideoTrack
                ? publication.track as VideoTrack
                : null,
          ),
    ];
    return pickRoomPresenter(
      presenters,
      (presenter) => _isHostParticipant(presenter.participant),
    );
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
    final presenter = _presenter(room);
    final isHost = roomInfo?.isHost == true;
    final requests = isHost
        ? pendingScreenShareRequests(roomActivity)
        : const <RoomParticipantState>[];
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
                      onLowerHand: isHost
                          ? (userId) => _lowerHands(userId: userId)
                          : null,
                      onLowerAllHands: isHost ? _lowerHands : null,
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
                          Expanded(
                            child: presenter == null
                                ? _participantGrid(entries)
                                : _presentationLayout(
                                    presenter,
                                    entries,
                                    canStop: presenter.isLocal || isHost,
                                  ),
                          ),
                          if (sidePanel)
                            SizedBox(width: _sidePanelWidth, child: panel),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: (showControls ? barHeight : 0) + 16,
                    child: RoomReactionOverlay(bubbles: reactionBubbles),
                  ),
                  if (requests.isNotEmpty)
                    Positioned(
                      top: room.connectionState == ConnectionState.reconnecting
                          ? 56
                          : 12,
                      left: 12,
                      right: sidePanel ? _sidePanelWidth + 12 : 12,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: RoomScreenShareRequests(
                            requests: requests,
                            nameOf: _participantName,
                            reviewing: reviewingScreenShares,
                            onReview: _reviewScreenShare,
                          ),
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

  /// Screen share ở vùng chính, video người tham gia thành dải thu nhỏ bên
  /// dưới; dải bị ẩn khi màn hình quá thấp để vùng chia sẻ vẫn đọc được.
  Widget _presentationLayout(
    _Presenter presenter,
    List<_RoomEntry> entries, {
    required bool canStop,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      const padding = 12.0;
      const stripHeight = 104.0;
      final showStrip = constraints.maxHeight >= 320;
      final identity = presenter.participant.identity;
      return Padding(
        padding: const EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RoomScreenShareStage(
                presenterName: _participantName(identity),
                isLocal: presenter.isLocal,
                track: presenter.track,
                onStop: !canStop
                    ? null
                    : presenter.isLocal
                    ? _unpublishOwnScreenShare
                    : () => _stopStudentScreenShare(identity),
              ),
            ),
            if (showStrip) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: stripHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => SizedBox(
                    key: ValueKey(entries[index].view.identity),
                    width: stripHeight * 16 / 10,
                    child: RoomParticipantTile(
                      participant: entries[index].view,
                      video: entries[index].video,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

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
      disabledBackgroundColor: const Color(0xff3c4043),
      disabledForegroundColor: Colors.white54,
    );
    final shareControl = roomScreenShareControl(
      supported: _screenShareSupported,
      isHost: roomInfo?.isHost == true,
      sharing: local?.isScreenShareEnabled() ?? false,
      ownState: _ownActivityState,
    );
    // Sáu nút phải vừa màn hình điện thoại 320px.
    final gap = MediaQuery.sizeOf(context).width < 400 ? 6.0 : 12.0;
    final gapBox = SizedBox(width: gap);
    final isHost = roomInfo?.isHost == true;
    final handRaised = _ownActivityState?.handRaisedAt != null;
    final raisedHands = isHost
        ? (roomActivity?.participants ?? const <RoomParticipantState>[])
              .where((state) => state.handRaisedAt != null)
              .length
        : 0;
    Widget peopleBadge(IconData icon) => Badge(
      label: Text(raisedHands > 0 ? '✋$raisedHands' : '$participantCount'),
      backgroundColor: raisedHands > 0 ? const Color(0xfffdd663) : null,
      textColor: raisedHands > 0 ? Colors.black : null,
      child: Icon(icon),
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
                  // Cuộn ngang khi nút không vừa màn hình hẹp, căn giữa khi vừa.
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
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
                            gapBox,
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
                            gapBox,
                            if (shareControl !=
                                RoomScreenShareControl.unavailable) ...[
                              _screenShareButton(shareControl, onStyle),
                              gapBox,
                            ],
                            if (!isHost) ...[
                              IconButton.filled(
                                isSelected: handRaised,
                                tooltip: handRaised
                                    ? 'Lower hand'
                                    : 'Raise hand',
                                style: handRaised
                                    ? IconButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xfffdd663,
                                        ),
                                        foregroundColor: Colors.black,
                                      )
                                    : onStyle,
                                onPressed: handBusy ? null : _toggleHand,
                                icon: const Icon(Icons.back_hand_outlined),
                                selectedIcon: const Icon(Icons.back_hand),
                              ),
                              gapBox,
                            ],
                            _reactionButton(onStyle),
                            gapBox,
                            IconButton.filled(
                              isSelected: participantsOpen,
                              tooltip: participantsOpen
                                  ? 'Hide participants'
                                  : raisedHands > 0
                                  ? 'Show participants ($raisedHands hands raised)'
                                  : 'Show participants ($participantCount)',
                              style: onStyle,
                              onPressed: _toggleParticipants,
                              icon: peopleBadge(Icons.people_outline),
                              selectedIcon: peopleBadge(Icons.people),
                            ),
                            gapBox,
                            IconButton.filled(
                              tooltip: 'Audio and video settings',
                              style: onStyle,
                              onPressed: _openDeviceSettings,
                              icon: const Icon(Icons.settings_outlined),
                            ),
                            gapBox,
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
          ),
        ),
      ),
    );
  }

  Widget _reactionButton(ButtonStyle style) => MenuAnchor(
    onOpen: () => setState(() => reactionMenuOpen = true),
    onClose: () {
      reactionMenuOpen = false;
      _showControls();
    },
    menuChildren: [
      for (final reaction in RoomReaction.values)
        MenuItemButton(
          onPressed: () => _sendReaction(reaction),
          leadingIcon: Text(
            reaction.emoji,
            style: const TextStyle(fontSize: 20),
          ),
          child: Text(reaction.label),
        ),
    ],
    builder: (context, controller, _) => IconButton.filled(
      tooltip: 'Send a reaction',
      style: style,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Icons.add_reaction_outlined),
    ),
  );

  Widget _screenShareButton(RoomScreenShareControl control, ButtonStyle style) {
    final busy = screenShareBusy;
    return switch (control) {
      RoomScreenShareControl.stop => IconButton.filled(
        isSelected: true,
        tooltip: 'Stop presenting',
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xff8ab4f8),
          foregroundColor: Colors.black,
        ),
        onPressed: busy ? null : _unpublishOwnScreenShare,
        icon: const Icon(Icons.stop_screen_share),
      ),
      RoomScreenShareControl.start => IconButton.filled(
        tooltip: 'Present your screen',
        style: style,
        onPressed: busy ? null : _startScreenShare,
        icon: const Icon(Icons.present_to_all),
      ),
      RoomScreenShareControl.request => IconButton.filled(
        tooltip: 'Ask the teacher to present',
        style: style,
        onPressed: busy ? null : _requestScreenShare,
        icon: const Icon(Icons.screen_share_outlined),
      ),
      RoomScreenShareControl.waiting => IconButton.filled(
        tooltip: 'Waiting for the teacher to allow presenting',
        style: style,
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
      ),
      RoomScreenShareControl.unavailable => const SizedBox.shrink(),
    };
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
