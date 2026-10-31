import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/classrooms/classroom_detail_header.dart';
import 'package:eflutter/presentation/classrooms/room_connection_recovery.dart';
import 'package:eflutter/presentation/classrooms/room_device_preferences.dart';
import 'package:eflutter/presentation/classrooms/room_device_settings.dart';
import 'package:eflutter/presentation/classrooms/room_join_control.dart';
import 'package:eflutter/presentation/classrooms/room_participant_widgets.dart';
import 'package:eflutter/presentation/classrooms/room_participants.dart';
import 'package:eflutter/presentation/classrooms/room_reactions.dart';
import 'package:eflutter/presentation/classrooms/room_screen_share.dart';
import 'package:eflutter/presentation/classrooms/room_shortcuts.dart';

class ClassroomRoomScreen extends StatefulWidget {
  const ClassroomRoomScreen({super.key, required this.classroomId, required this.roomId});
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

const _roomText = Color(0xFF1C1E21);
const _roomMuted = Color(0xFF65676B);
const _roomFaint = Color(0xFF8A8D91);
const _roomBorder = Color(0xFFE4E6EB);
const _stageColor = Color(0xFF16181D);

class _ClassroomRoomScreenState extends State<ClassroomRoomScreen> {
  static const _reconnectTimeout = Duration(seconds: 45);
  static const _roomStatusRetryDelay = Duration(seconds: 5);
  static const _controlsHideDelay = Duration(seconds: 4);
  static const _controlsAnimation = Duration(milliseconds: 200);
  static const _controlBarHeight = 92.0;
  static const _sidePanelBreakpoint = 900.0;
  static const _sidePanelWidth = 320.0;

  late final ClassroomRepository repository = ClassroomRepository(getIt<Dio>());
  late final RoomSocketClient roomSocket = RoomSocketClient(getIt<LocalDataBase>());
  late final RoomDevicePreferences devicePreferences = RoomDevicePreferences(
    getIt<SharedPreferencesAsync>(),
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
  // Ngữ cảnh hiển thị: banner lớp ở màn chuẩn bị và tên buổi học.
  Classroom? classroom;
  String? sessionTitle;
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
  bool confirmDialogOpen = false;

  /// Khác null khi học sinh bị giáo viên xóa khỏi phòng; màn hình chỉ hiện
  /// thông báo và không thử kết nối lại.
  String? removedNotice;

  /// LiveKit báo bị xóa khỏi phòng; tạm dừng tự kết nối lại cho đến khi biết
  /// lý do từ backend.
  bool mediaRemovalPending = false;
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
      devicePreferences.load(),
    ]);
    final result = results[0] as Result<ClassroomRoom>;
    final activityResult = results[1] as Result<RoomActivity>;
    final savedDevices = results[2] as RoomDeviceChoice;
    try {
      await _startPreview();
      cameras = await Hardware.instance.videoInputs();
      camera = preferredRoomDevice(savedDevices.cameraId, cameras);
      // Danh sách camera chỉ có sau khi được cấp quyền nên preview đầu tiên
      // dùng camera mặc định; mở lại nếu camera đã lưu là thiết bị khác.
      if (previewTrack != null && camera != null && _previewDeviceId() != camera!.deviceId) {
        await _startPreview();
      }
    } catch (_) {
      cameraEnabled = false;
      deviceWarning = 'Camera permission was denied. You can still join with the camera off.';
    }
    try {
      final audioTrack = await LocalAudioTrack.create();
      await audioTrack.stop();
      microphones = await Hardware.instance.audioInputs();
      microphone = preferredRoomDevice(savedDevices.microphoneId, microphones);
    } catch (_) {
      microphoneEnabled = false;
      deviceWarning = cameraEnabled
          ? 'Microphone permission was denied. You can still join in listen-only mode.'
          : 'Camera and microphone permissions were denied. You can still join in listen-only mode.';
    }
    try {
      speakers = await Hardware.instance.audioOutputs();
      speaker = preferredRoomDevice(
        savedDevices.speakerId,
        speakers,
        fallback: Hardware.instance.selectedAudioOutput,
      );
    } catch (_) {
      speakers = const [];
    }
    _syncDeviceOptions();
    if (!mounted) return;
    if (activityResult case Success(data: final activity)) {
      roomActivity = activity;
      final own = _ownActivityState;
      if (own?.removedAt != null) removedNotice = _removedMessage;
      // Quyền do giáo viên đặt áp dụng ngay từ màn hình chuẩn bị.
      if (own?.microphoneAllowed == false) microphoneEnabled = false;
      if (own?.cameraAllowed == false && cameraEnabled) {
        cameraEnabled = false;
        await previewTrack?.stop();
        previewTrack = null;
      }
    }
    if (!mounted) return;
    switch (result) {
      case Success(data: final value):
        setState(() {
          roomInfo = value;
          loading = false;
        });
        unawaited(_loadContext(value));
      case Failure(message: final message):
        setState(() {
          error = message ?? 'Could not load the room';
          loading = false;
        });
      case Cancelled():
        setState(() => loading = false);
    }
  }

  /// Lớp (cho banner) và tên buổi học (từ lịch); thiếu thì vẫn vào phòng bình thường.
  Future<void> _loadContext(ClassroomRoom room) async {
    final results = await Future.wait([
      repository.get(widget.classroomId),
      repository.getCalendar(
        classroomId: widget.classroomId,
        from: room.startsAt.subtract(const Duration(minutes: 1)),
        to: room.endsAt.add(const Duration(minutes: 1)),
      ),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0] case Success(data: final Classroom value)) classroom = value;
      if (results[1] case Success(data: final List<CalendarEntry> entries)) {
        sessionTitle = entries.where((entry) => entry.room?.id == widget.roomId).firstOrNull?.title;
      }
    });
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

  String? _previewDeviceId() {
    try {
      return previewTrack?.mediaStreamTrack.getSettings()['deviceId'] as String?;
    } catch (_) {
      return null;
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
            defaultCameraCaptureOptions: CameraCaptureOptions(deviceId: camera?.deviceId),
            defaultAudioCaptureOptions: AudioCaptureOptions(deviceId: microphone?.deviceId),
            defaultAudioOutputOptions: AudioOutputOptions(deviceId: speaker?.deviceId),
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
          ..on<RoomDisconnectedEvent>((event) {
            if (event.reason == DisconnectReason.participantRemoved) {
              mediaRemovalPending = true;
              unawaited(_handleMediaRemoval());
            } else if (event.reason == DisconnectReason.roomDeleted && roomInfo?.isHost != true) {
              // Giáo viên kết thúc lớp: không reconnect, về lịch.
              _showRoomMessage('The teacher ended this class.');
              unawaited(_exitClosedRoom());
            }
          })
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
        audioCaptureOptions: AudioCaptureOptions(deviceId: microphone?.deviceId),
      );
    } catch (_) {
      microphoneEnabled = false;
      warnings.add('Microphone is unavailable, joined with the microphone off.');
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
        mediaRemovalPending ||
        removedNotice != null ||
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
            mediaConnected: liveRoom?.connectionState == ConnectionState.connected,
            roomRequestSucceeded: true,
            roomStatus: room.status,
          ),
        );
      case Failure():
      case Cancelled():
        await _applyRecoveryAction(
          decideRoomConnectionRecovery(
            mediaConnected: liveRoom?.connectionState == ConnectionState.connected,
            roomRequestSucceeded: false,
          ),
        );
    }
  }

  Future<void> _refreshActivity() async {
    final result = await repository.getRoomActivity(widget.classroomId, widget.roomId);
    if (!mounted) return;
    if (result case Success(data: final activity)) {
      final before = _ownActivityState;
      setState(() => roomActivity = activity);
      _applyOwnPermissions(before, _ownActivityState);
    }
  }

  static const _removedMessage =
      'You were removed from this session by the teacher. You can join again when the next session starts.';

  /// Áp dụng quyền giáo viên đặt cho chính mình: thiết bị bị tắt thì tắt ở
  /// client (LiveKit đã chặn ở server), được cho phép lại thì chỉ báo để học
  /// sinh tự bật.
  void _applyOwnPermissions(RoomParticipantState? before, RoomParticipantState? after) {
    if (after == null || roomInfo?.isHost == true) return;
    if (after.removedAt != null) {
      unawaited(_exitRemoved());
      return;
    }
    final local = liveRoom?.localParticipant;
    if (local == null || before == null) return;
    final messages = <String>[];
    if (!after.microphoneAllowed) {
      microphoneEnabled = false;
      if (local.isMicrophoneEnabled()) {
        unawaited(_disableLocalSource(TrackSource.microphone));
      }
      if (before.microphoneAllowed) {
        messages.add('The teacher turned off your microphone.');
      }
    } else if (!before.microphoneAllowed) {
      messages.add(
        'The teacher allowed you to use your microphone. Turn it on when you are ready.',
      );
    }
    if (!after.cameraAllowed) {
      cameraEnabled = false;
      if (local.isCameraEnabled()) {
        unawaited(_disableLocalSource(TrackSource.camera));
      }
      if (before.cameraAllowed) {
        messages.add('The teacher turned off your camera.');
      }
    } else if (!before.cameraAllowed) {
      messages.add('The teacher allowed you to use your camera again.');
    }
    if (messages.isNotEmpty) _showRoomMessage(messages.join(' '));
  }

  Future<void> _disableLocalSource(TrackSource source) async {
    final local = liveRoom?.localParticipant;
    try {
      if (source == TrackSource.microphone) {
        await local?.setMicrophoneEnabled(false);
      } else {
        await local?.setCameraEnabled(false);
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  /// LiveKit ngắt kết nối với lý do bị xóa: hỏi backend xem là bị xóa khỏi
  /// phòng (không được vào lại) hay đã không còn là thành viên của lớp.
  Future<void> _handleMediaRemoval() async {
    final result = await repository.getRoomActivity(widget.classroomId, widget.roomId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final activity):
        setState(() => roomActivity = activity);
        if (_ownActivityState?.removedAt != null) {
          await _exitRemoved();
          return;
        }
        mediaRemovalPending = false;
        _scheduleConnectionRecovery(Duration.zero);
      case Failure():
        await _exitRemoved(
          notice: 'You can no longer join this session. You may have been removed from the class.',
        );
      case Cancelled():
        mediaRemovalPending = false;
    }
  }

  Future<void> _exitRemoved({String notice = _removedMessage}) async {
    if (removedNotice != null && liveRoom == null) return;
    leavingRoom = true;
    reconnectTimer?.cancel();
    await _disposeLiveRoom();
    if (mounted) setState(() => removedNotice = notice);
  }

  Future<void> _moderate(String userId, RoomParticipantAction action) async {
    final name = _participantName(userId);
    final Result<RoomParticipantState> result;
    switch (action) {
      case RoomParticipantAction.remove:
        confirmDialogOpen = true;
        final reason = await showDialog<String>(
          context: context,
          builder: (_) => _RemoveParticipantDialog(name: name),
        );
        confirmDialogOpen = false;
        _showControls();
        if (reason == null || !mounted) return;
        result = await repository.removeParticipant(
          widget.classroomId,
          widget.roomId,
          userId,
          reason: reason,
        );
      case RoomParticipantAction.mute:
        result = await repository.moderateParticipantDevice(
          widget.classroomId,
          widget.roomId,
          userId,
          RoomDeviceModeration.mute,
        );
      case RoomParticipantAction.allowMicrophone:
        result = await repository.moderateParticipantDevice(
          widget.classroomId,
          widget.roomId,
          userId,
          RoomDeviceModeration.allowMicrophone,
        );
      case RoomParticipantAction.disableCamera:
        result = await repository.moderateParticipantDevice(
          widget.classroomId,
          widget.roomId,
          userId,
          RoomDeviceModeration.disableCamera,
        );
      case RoomParticipantAction.allowCamera:
        result = await repository.moderateParticipantDevice(
          widget.classroomId,
          widget.roomId,
          userId,
          RoomDeviceModeration.allowCamera,
        );
    }
    if (!mounted) return;
    switch (result) {
      case Success():
        _showRoomMessage(switch (action) {
          RoomParticipantAction.mute => '$name was muted.',
          RoomParticipantAction.allowMicrophone => '$name can turn on their microphone again.',
          RoomParticipantAction.disableCamera => "$name's camera was turned off.",
          RoomParticipantAction.allowCamera => '$name can turn on their camera again.',
          RoomParticipantAction.remove => '$name was removed from this session.',
        });
      case Failure(message: final message):
        _showRoomMessage(message ?? 'Could not update $name.');
      case Cancelled():
        break;
    }
    await _refreshActivity();
  }

  Future<void> _muteAll() async {
    final result = await repository.muteAllParticipants(widget.classroomId, widget.roomId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final userIds):
        _showRoomMessage(
          userIds.isEmpty
              ? 'Every student is already muted.'
              : 'Muted ${userIds.length} student${userIds.length == 1 ? '' : 's'}.',
        );
      case Failure(message: final message):
        _showRoomMessage(message ?? 'Could not mute everyone.');
      case Cancelled():
        break;
    }
    await _refreshActivity();
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
    if (mounted) _backToCalendar();
  }

  Future<void> _leave({bool end = false}) async {
    if (end) {
      final result = await repository.endRoom(widget.classroomId, widget.roomId);
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
    if (mounted) _backToCalendar();
  }

  Future<void> _toggleMicrophone() async {
    final local = liveRoom?.localParticipant;
    if (local == null) return;
    final enable = !local.isMicrophoneEnabled();
    if (enable && _ownActivityState?.microphoneAllowed == false) {
      _showRoomMessage('The teacher turned off your microphone.');
      return;
    }
    try {
      await local.setMicrophoneEnabled(
        enable,
        audioCaptureOptions: AudioCaptureOptions(deviceId: microphone?.deviceId),
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
    if (enable && _ownActivityState?.cameraAllowed == false) {
      _showRoomMessage('The teacher turned off your camera.');
      return;
    }
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
  // Chỉ lựa chọn của người dùng được ghi nhớ; chuyển tự động khi rút thiết bị
  // thì không, để lần sau cắm lại vẫn chọn thiết bị cũ.
  Future<void> _selectMicrophone(MediaDevice device, {bool remember = true}) async {
    microphone = device;
    _syncDeviceOptions();
    if (remember) {
      unawaited(devicePreferences.save(RoomDeviceKind.microphone, device));
    }
    try {
      await liveRoom?.setAudioInputDevice(device);
    } catch (_) {
      _showRoomMessage('Could not switch to ${_deviceName(device)}.');
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectCamera(MediaDevice device, {bool remember = true}) async {
    camera = device;
    _syncDeviceOptions();
    if (remember) {
      unawaited(devicePreferences.save(RoomDeviceKind.camera, device));
    }
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

  Future<void> _selectSpeaker(MediaDevice device, {bool remember = true}) async {
    speaker = device;
    _syncDeviceOptions();
    if (remember) {
      unawaited(devicePreferences.save(RoomDeviceKind.speaker, device));
    }
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
    final nextMicrophones = devices.where((d) => d.kind == 'audioinput').toList();
    final nextCameras = devices.where((d) => d.kind == 'videoinput').toList();
    final nextSpeakers = devices.where((d) => d.kind == 'audiooutput').toList();
    final nextMicrophone = resolveRoomDevice(microphone, nextMicrophones);
    final nextCamera = resolveRoomDevice(camera, nextCameras);
    final nextSpeaker = resolveRoomDevice(speaker, nextSpeakers);
    final microphoneLost = microphone != null && nextMicrophone?.deviceId != microphone!.deviceId;
    final cameraLost = camera != null && nextCamera?.deviceId != camera!.deviceId;
    final speakerLost = speaker != null && nextSpeaker?.deviceId != speaker!.deviceId;
    microphones = nextMicrophones;
    cameras = nextCameras;
    speakers = nextSpeakers;
    final messages = <String>[];

    if (microphoneLost && nextMicrophone != null) {
      messages.add('Microphone disconnected. Switched to ${_deviceName(nextMicrophone)}.');
      await _selectMicrophone(nextMicrophone, remember: false);
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
      messages.add('Camera disconnected. Switched to ${_deviceName(nextCamera)}.');
      await _selectCamera(nextCamera, remember: false);
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
      messages.add('Speaker disconnected. Switched to ${_deviceName(nextSpeaker)}.');
      await _selectSpeaker(nextSpeaker, remember: false);
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
    // Thông báo trong phòng là info, câu "Could not…" là lỗi.
    context.showToast(
      message,
      type: message.startsWith('Could not') ? ToastType.error : ToastType.info,
    );
  }

  bool get _canHideControls =>
      liveRoom?.connectionState == ConnectionState.connected &&
      !participantsOpen &&
      !deviceDialogOpen &&
      !confirmDialogOpen &&
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

  bool get _appleKeyboard =>
      const {TargetPlatform.macOS, TargetPlatform.iOS}.contains(defaultTargetPlatform);

  String _withShortcut(String label, RoomShortcut shortcut) =>
      '$label (${roomShortcutLabel(shortcut, apple: _appleKeyboard)})';

  bool _handleKeyEvent(KeyEvent event) {
    // Phím thường chỉ hiện lại thanh điều khiển, không bị chặn để ô nhập và
    // phím Tab vẫn hoạt động bình thường. Bỏ qua phím giữ lặp lại để không
    // bật/tắt liên tục.
    if (event is! KeyDownEvent) return false;
    _showControls();
    final keyboard = HardwareKeyboard.instance;
    final shortcut = roomShortcutFor(
      logicalKey: event.logicalKey,
      physicalKey: event.physicalKey,
      control: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
      apple: _appleKeyboard,
    );
    final local = liveRoom?.localParticipant;
    if (shortcut == null || local == null || !mounted) return false;
    final ownState = _ownActivityState;
    final decision = roomShortcutDecision(
      shortcut,
      // Dialog hoặc menu đang mở thì route phòng không còn ở trên cùng.
      roomActive:
          liveRoom?.connectionState == ConnectionState.connected &&
          removedNotice == null &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      editingText: roomTextInputFocused(),
      isHost: roomInfo?.isHost == true,
      microphoneOn: local.isMicrophoneEnabled(),
      microphoneAllowed: ownState?.microphoneAllowed ?? true,
      cameraOn: local.isCameraEnabled(),
      cameraAllowed: ownState?.cameraAllowed ?? true,
    );
    switch (decision) {
      case RoomShortcutDecision.ignore:
        return false;
      case RoomShortcutDecision.locked:
        _showRoomMessage(
          shortcut == RoomShortcut.toggleMicrophone
              ? 'The teacher turned off your microphone.'
              : 'The teacher turned off your camera.',
        );
      case RoomShortcutDecision.run:
        unawaited(switch (shortcut) {
          RoomShortcut.toggleMicrophone => _toggleMicrophone(),
          RoomShortcut.toggleCamera => _toggleCamera(),
          RoomShortcut.toggleHand => _toggleHand(),
        });
    }
    // Đã xử lý: chặn hành vi mặc định của trình duyệt (Ctrl+D đánh dấu trang,
    // Ctrl+E ô tìm kiếm).
    return true;
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
    final activity = roomActivity;
    if (activity == null) return null;
    final identity = liveRoom?.localParticipant?.identity;
    // Trước khi vào phòng chưa có identity; snapshot của học sinh chỉ chứa
    // state của chính mình.
    if (identity == null) {
      return activity.isHost ? null : activity.participants.firstOrNull;
    }
    for (final state in activity.participants) {
      if (state.userId == identity) return state;
    }
    return null;
  }

  String _participantName(String identity) {
    final room = liveRoom;
    final Participant? participant = room?.localParticipant?.identity == identity
        ? room?.localParticipant
        : room?.remoteParticipants.values.where((p) => p.identity == identity).firstOrNull;
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
    final result = await repository.setHandRaised(widget.classroomId, widget.roomId, raised: raise);
    if (!mounted) return;
    switch (result) {
      case Success(data: final state):
        _replaceOwnState(state);
      case Failure(message: final message):
        _showRoomMessage(
          message ?? (raise ? 'Could not raise your hand.' : 'Could not lower your hand.'),
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
    final result = await repository.lowerHands(widget.classroomId, widget.roomId, userId: userId);
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
    setState(() => reactionBubbles = addRoomReactionBubble(reactionBubbles, bubble));
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
    final result = await repository.requestScreenShare(widget.classroomId, widget.roomId);
    if (!mounted) return;
    switch (result) {
      case Success():
        _showRoomMessage('Request sent. You can present after the teacher allows it.');
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
        track = await LocalVideoTrack.createScreenShareTrack(const ScreenShareCaptureOptions());
      } catch (_) {
        _showRoomMessage(
          'Screen sharing was cancelled or blocked. To present, allow screen sharing in your browser or system settings and try again.',
        );
        return;
      }
      final result = await repository.startScreenShare(widget.classroomId, widget.roomId);
      if (result is! Success) {
        await track.stop();
        _showRoomMessage(
          (result is Failure ? result.message : null) ?? 'Could not start presenting.',
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
        _showRoomMessage('Could not start presenting. Ask the teacher to allow it again.');
        unawaited(_refreshActivity());
      }
    } finally {
      if (mounted) setState(() => screenShareBusy = false);
    }
  }

  Future<void> _unpublishOwnScreenShare() async {
    final local = liveRoom?.localParticipant;
    if (local?.getTrackPublicationBySource(TrackSource.screenShareVideo) == null) {
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
    await repository.stopScreenShare(widget.classroomId, widget.roomId, identity);
    await _refreshActivity();
  }

  Future<void> _stopStudentScreenShare(String userId) async {
    final result = await repository.stopScreenShare(widget.classroomId, widget.roomId, userId);
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
      return const Scaffold(body: AppLoader());
    }
    if (removedNotice != null) return _removedView(context);
    if (liveRoom == null) return _prejoin(context);
    return _conference(context);
  }

  Widget _removedView(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Online classroom')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                removedNotice!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _backToCalendar, child: const Text('Back to class')),
            ],
          ),
        ),
      ),
    ),
  );

  /// Màn chuẩn bị (Figma 26:1861): nằm trong tab Calendar của lớp — banner, tab, rồi
  /// xem trước camera + chọn thiết bị bên trái, trạng thái phòng và nút vào bên phải.
  Widget _prejoin(BuildContext context) {
    final item = classroom;
    final cameraLocked = _ownActivityState?.cameraAllowed == false;
    final microphoneLocked = _ownActivityState?.microphoneAllowed == false;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: ClassroomTopBar(onBack: _backToCalendar),
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1128),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item != null) ...[
                      ClassroomBanner(
                        classroom: item,
                        canManage: false,
                        busy: false,
                        onEdit: () {},
                        onArchive: () {},
                      ),
                      ClassroomTabs(
                        selected: 2,
                        onSelected: (tab) => context.go(classroomTabPath(widget.classroomId, tab)),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _sessionHeader(),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 860;
                        final preview = _preview(
                          cameraLocked: cameraLocked,
                          microphoneLocked: microphoneLocked,
                        );
                        final panel = _joinPanel();
                        if (!wide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [preview, const SizedBox(height: 24), panel],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: preview),
                            const SizedBox(width: 32),
                            SizedBox(width: 340, child: panel),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionHeader() {
    final info = roomInfo;
    final time = info == null
        ? ''
        : '${DateFormat('EEE, MMM d · HH:mm').format(info.startsAt)} – ${DateFormat('HH:mm').format(info.endsAt)}';
    return Row(
      spacing: 14,
      children: [
        SizedBox.square(
          dimension: 32,
          child: OutlinedButton(
            onPressed: _backToCalendar,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: _roomText,
              side: const BorderSide(color: _roomBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Tooltip(
              message: 'Back to calendar',
              child: Icon(Icons.arrow_back, size: 18),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                sessionTitle ?? 'Online class',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _roomText),
              ),
              Text(
                'Class session · $time',
                style: const TextStyle(fontSize: 12, color: _roomMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _preview({required bool cameraLocked, required bool microphoneLocked}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const Color(0xFF2A2F37),
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
              Positioned(left: 14, top: 14, child: _videoTag(const Text('You'))),
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 14,
                  children: [
                    _previewToggle(
                      on: microphoneEnabled,
                      locked: microphoneLocked,
                      onIcon: Icons.mic,
                      offIcon: Icons.mic_off,
                      label: 'microphone',
                      onPressed: () => setState(() => microphoneEnabled = !microphoneEnabled),
                    ),
                    _previewToggle(
                      on: cameraEnabled,
                      locked: cameraLocked,
                      onIcon: Icons.videocam,
                      offIcon: Icons.videocam_off,
                      label: 'camera',
                      onPressed: () async {
                        setState(() => cameraEnabled = !cameraEnabled);
                        await _startPreview();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (deviceWarning != null || cameraLocked || microphoneLocked)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            deviceWarning ??
                'The teacher turned off your ${cameraLocked && microphoneLocked
                    ? 'camera and microphone'
                    : cameraLocked
                    ? 'camera'
                    : 'microphone'}.',
            style: const TextStyle(fontSize: 13, color: Color(0xFFD93025)),
          ),
        ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            _deviceField(
              'Camera',
              Icons.videocam_outlined,
              cameras,
              camera,
              (device) => _selectCamera(device),
            ),
            _deviceField(
              'Microphone',
              Icons.mic_none,
              microphones,
              microphone,
              (device) => _selectMicrophone(device),
            ),
            _deviceField(
              'Speaker',
              Icons.volume_up_outlined,
              speakers,
              speaker,
              (device) => _selectSpeaker(device),
            ),
          ];
          if (constraints.maxWidth < 560) {
            return Column(spacing: 12, children: fields);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [for (final field in fields) Expanded(child: field)],
          );
        },
      ),
    ],
  );

  Widget _previewToggle({
    required bool on,
    required bool locked,
    required IconData onIcon,
    required IconData offIcon,
    required String label,
    required VoidCallback onPressed,
  }) => Tooltip(
    message: locked
        ? 'The teacher turned off your $label'
        : on
        ? 'Turn off $label'
        : 'Turn on $label',
    child: Material(
      color: on ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFD93025),
      shape: CircleBorder(
        side: on ? BorderSide(color: Colors.white.withValues(alpha: 0.35)) : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: locked ? null : onPressed,
        child: SizedBox.square(
          dimension: 52,
          child: Icon(on ? onIcon : offIcon, color: locked ? Colors.white54 : Colors.white),
        ),
      ),
    ),
  );

  /// Ô chọn thiết bị: menu xổ ngay dưới ô, cùng kiểu menu Sort (nền trắng, viền, mục đang chọn có ✓).
  Widget _deviceField(
    String label,
    IconData icon,
    List<MediaDevice> devices,
    MediaDevice? value,
    ValueChanged<MediaDevice> onChanged,
  ) {
    String name(MediaDevice device, int index) =>
        device.label.isEmpty ? '$label ${index + 1}' : device.label;
    final selectedIndex = value == null
        ? -1
        : devices.indexWhere((device) => device.deviceId == value.deviceId);
    final text = selectedIndex < 0
        ? 'No ${label.toLowerCase()} found'
        : name(devices[selectedIndex], selectedIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _roomMuted),
        ),
        LayoutBuilder(
          builder: (context, constraints) => PopupMenuButton<MediaDevice>(
            tooltip: 'Choose ${label.toLowerCase()}',
            enabled: devices.isNotEmpty,
            onSelected: onChanged,
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 6,
            shadowColor: Colors.black26,
            menuPadding: const EdgeInsets.all(6),
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: math.max(constraints.maxWidth, 320),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: _roomBorder),
            ),
            itemBuilder: (context) => [
              for (final (index, device) in devices.indexed)
                PopupMenuItem(
                  value: device,
                  height: 38,
                  padding: EdgeInsets.zero,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: index == selectedIndex ? AppButtonStyles.tint : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        Expanded(
                          child: Text(
                            name(device, index),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: index == selectedIndex
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: index == selectedIndex ? ColorName.primary : _roomText,
                            ),
                          ),
                        ),
                        if (index == selectedIndex)
                          const Icon(Icons.check, size: 16, color: ColorName.primary),
                      ],
                    ),
                  ),
                ),
            ],
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _roomBorder),
              ),
              child: Row(
                spacing: 10,
                children: [
                  Icon(icon, size: 18, color: _roomMuted),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: selectedIndex < 0 ? _roomFaint : _roomText,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18, color: _roomMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _joinPanel() {
    final info = roomInfo;
    final (label, foreground, background) = switch (info?.status) {
      'LIVE' => (
        info?.startedAt == null ? 'Live now' : 'Live now · started ${_ago(info!.startedAt!)}',
        const Color(0xFF1E8E3E),
        const Color(0xFFE7F6EC),
      ),
      'ENDED' => ('This class has ended', _roomMuted, const Color(0xFFF0F2F5)),
      _ => ('Waiting for the teacher to start', const Color(0xFFB26A00), const Color(0xFFFFF4E5)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ready to join?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: _roomText),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: foreground),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButtonTheme(
          data: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          child: RoomJoinControl(
            status: info?.status,
            connecting: connecting,
            error: error,
            onJoin: _connect,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          switch (info?.status) {
            'LIVE' =>
              'Your device choices are kept for next time. Attendance is recorded when you join.',
            'ENDED' => 'Go back to the calendar to see the next sessions.',
            _ => 'This page updates automatically when the class starts.',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _roomFaint),
        ),
      ],
    );
  }

  /// Rời màn phòng: luôn về tab Calendar của lớp.
  void _backToCalendar() => context.go(classroomTabPath(widget.classroomId, 2));

  static String _ago(DateTime value) {
    final minutes = DateTime.now().difference(value).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min ago';
    return '${minutes ~/ 60} h ${minutes % 60} min ago';
  }

  Widget _videoTag(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DefaultTextStyle(
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
      child: child,
    ),
  );

  List<_RoomEntry> _participantEntries(Room room) {
    final states = {
      for (final state in roomActivity?.participants ?? const <RoomParticipantState>[])
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
                participant.metadata == roomHostMetadata || (isLocal && roomInfo?.isHost == true),
            roomReconnecting: reconnecting,
            handRaisedAt: states[participant.identity]?.handRaisedAt,
            screenShareRequested:
                states[participant.identity]?.screenShareRequestedAt != null &&
                states[participant.identity]?.screenShareApprovedAt == null,
            microphoneAllowed: states[participant.identity]?.microphoneAllowed ?? true,
            cameraAllowed: states[participant.identity]?.cameraAllowed ?? true,
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
      if (room.localParticipant case final local? when local.isScreenShareEnabled())
        _Presenter(local, isLocal: true),
      for (final remote in room.remoteParticipants.values)
        if (remote.getTrackPublicationBySource(TrackSource.screenShareVideo) case final publication?
            when !publication.muted)
          _Presenter(
            remote,
            isLocal: false,
            track: publication.track is VideoTrack ? publication.track as VideoTrack : null,
          ),
    ];
    return pickRoomPresenter(presenters, (presenter) => _isHostParticipant(presenter.participant));
  }

  VideoTrack? _cameraTrack(Participant participant) {
    final publication = participant.getTrackPublicationBySource(TrackSource.camera);
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
        controlsVisible || participantsOpen || room.connectionState != ConnectionState.connected;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barHeight = _controlBarHeight + bottomInset;
    // Phòng phủ kín vùng nội dung (Figma 26:2183): bỏ banner lớp, chỉ còn thanh trên của phòng.
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: _stageColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _roomTopBar(views.length),
                Expanded(
                  child: MouseRegion(
                    onHover: (_) => _showControls(),
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => _showControls(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final sidePanel =
                              participantsOpen && constraints.maxWidth >= _sidePanelBreakpoint;
                          final panel = participantsOpen
                              ? RoomParticipantPanel(
                                  participants: views,
                                  onClose: _toggleParticipants,
                                  onLowerHand: isHost
                                      ? (userId) => _lowerHands(userId: userId)
                                      : null,
                                  onLowerAllHands: isHost ? _lowerHands : null,
                                  onModerate: isHost ? _moderate : null,
                                  onMuteAll: isHost ? _muteAll : null,
                                )
                              : null;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: AnimatedPadding(
                                  duration: _controlsAnimation,
                                  padding: EdgeInsets.only(bottom: showControls ? barHeight : 0),
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
                                      if (sidePanel) SizedBox(width: _sidePanelWidth, child: panel),
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
                                      avatar: SizedBox.square(dimension: 14, child: AppLoader()),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomTopBar(int participantCount) {
    final info = roomInfo;
    final isHost = info?.isHost == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        spacing: 12,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD93025),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(Icons.circle, size: 7, color: Colors.white),
                Text(
                  'LIVE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          if (info?.startedAt case final startedAt?) _ElapsedTime(since: startedAt),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionTitle ?? 'Online class',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  [
                    ?classroom?.name,
                    '$participantCount ${participantCount == 1 ? 'participant' : 'participants'}',
                  ].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9AA0A6)),
                ),
              ],
            ),
          ),
          if (isHost)
            TextButton.icon(
              onPressed: () => _leave(end: true),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('End class for all'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF8A80),
                backgroundColor: const Color(0xFFD93025).withValues(alpha: 0.16),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
        ],
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
      // Màn rộng có từ 2 người: một ô lớn (người đang nói, mặc định giáo viên) + dải bên phải.
      if (entries.length > 1 && constraints.maxWidth >= 900 && constraints.maxHeight >= 360) {
        return _speakerLayout(entries);
      }
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
                    child: RoomParticipantTile(participant: entry.view, video: entry.video),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _speakerLayout(List<_RoomEntry> entries) {
    final main =
        entries.where((entry) => entry.view.isSpeaking && !entry.view.isLocal).firstOrNull ??
        entries.where((entry) => entry.view.isHost).firstOrNull ??
        entries.first;
    final others = [
      for (final entry in entries)
        if (entry.view.identity != main.view.identity) entry,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RoomParticipantTile(
              key: ValueKey(main.view.identity),
              participant: main.view,
              video: main.video,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 280,
            child: ListView.separated(
              itemCount: others.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => AspectRatio(
                key: ValueKey(others[index].view.identity),
                aspectRatio: 16 / 9,
                child: RoomParticipantTile(
                  participant: others[index].view,
                  video: others[index].video,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nút trên thanh điều khiển kèm nhãn chữ bên dưới.
  Widget _labeled(String label, Widget button) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 4,
    children: [
      button,
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9AA0A6))),
    ],
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
      disabledBackgroundColor: Colors.red.shade900,
      disabledForegroundColor: Colors.white60,
    );
    // Thiết bị bị giáo viên tắt: khóa nút bật, nhưng vẫn cho tắt nếu đang bật.
    final ownState = _ownActivityState;
    final microphoneLocked = ownState?.microphoneAllowed == false && !microphoneOn;
    final cameraLocked = ownState?.cameraAllowed == false && !cameraOn;
    final onStyle = IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
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
              color: _stageColor,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
                child: SizedBox(
                  height: _controlBarHeight - 24,
                  // Cuộn ngang khi nút không vừa màn hình hẹp, căn giữa khi vừa.
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _labeled(
                              'Mic',
                              IconButton.filled(
                                isSelected: microphoneOn,
                                tooltip: microphoneLocked
                                    ? 'The teacher turned off your microphone'
                                    : _withShortcut(
                                        microphoneOn ? 'Turn off microphone' : 'Turn on microphone',
                                        RoomShortcut.toggleMicrophone,
                                      ),
                                style: microphoneOn ? onStyle : offStyle,
                                onPressed: microphoneLocked ? null : _toggleMicrophone,
                                icon: const Icon(Icons.mic_off),
                                selectedIcon: const Icon(Icons.mic),
                              ),
                            ),
                            gapBox,
                            _labeled(
                              'Camera',
                              IconButton.filled(
                                isSelected: cameraOn,
                                tooltip: cameraLocked
                                    ? 'The teacher turned off your camera'
                                    : _withShortcut(
                                        cameraOn ? 'Turn off camera' : 'Turn on camera',
                                        RoomShortcut.toggleCamera,
                                      ),
                                style: cameraOn ? onStyle : offStyle,
                                onPressed: cameraLocked ? null : _toggleCamera,
                                icon: const Icon(Icons.videocam_off),
                                selectedIcon: const Icon(Icons.videocam),
                              ),
                            ),
                            gapBox,
                            if (shareControl != RoomScreenShareControl.unavailable) ...[
                              _labeled('Share', _screenShareButton(shareControl, onStyle)),
                              gapBox,
                            ],
                            if (!isHost) ...[
                              _labeled(
                                'Raise hand',
                                IconButton.filled(
                                  isSelected: handRaised,
                                  tooltip: _withShortcut(
                                    handRaised ? 'Lower hand' : 'Raise hand',
                                    RoomShortcut.toggleHand,
                                  ),
                                  style: handRaised
                                      ? IconButton.styleFrom(
                                          backgroundColor: const Color(0xfffdd663),
                                          foregroundColor: Colors.black,
                                        )
                                      : onStyle,
                                  onPressed: handBusy ? null : _toggleHand,
                                  icon: const Icon(Icons.back_hand_outlined),
                                  selectedIcon: const Icon(Icons.back_hand),
                                ),
                              ),
                              gapBox,
                            ],
                            _labeled('React', _reactionButton(onStyle)),
                            gapBox,
                            _labeled(
                              'People',
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
                            ),
                            gapBox,
                            _labeled(
                              'Settings',
                              IconButton.filled(
                                tooltip: 'Audio and video settings',
                                style: onStyle,
                                onPressed: _openDeviceSettings,
                                icon: const Icon(Icons.settings_outlined),
                              ),
                            ),
                            gapBox,
                            _labeled(
                              'Leave',
                              IconButton.filled(
                                tooltip: 'Leave',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _leave,
                                icon: const Icon(Icons.call_end),
                              ),
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
          leadingIcon: Text(reaction.emoji, style: const TextStyle(fontSize: 20)),
          child: Text(reaction.label),
        ),
    ],
    builder: (context, controller, _) => IconButton.filled(
      tooltip: 'Send a reaction',
      style: style,
      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
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

class _RemoveParticipantDialog extends StatefulWidget {
  const _RemoveParticipantDialog({required this.name});
  final String name;

  @override
  State<_RemoveParticipantDialog> createState() => _RemoveParticipantDialogState();
}

/// Trả về lý do (có thể rỗng) khi xác nhận, null khi hủy.
class _RemoveParticipantDialogState extends State<_RemoveParticipantDialog> {
  final reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Remove ${widget.name}?'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.name} will leave this session and cannot rejoin until it ends. They stay in the class.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reason,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: () => Navigator.of(context).pop(reason.text),
        child: const Text('Remove'),
      ),
    ],
  );
}

class RoomAttendanceScreen extends StatefulWidget {
  const RoomAttendanceScreen({super.key, required this.classroomId, required this.roomId});
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
    final result = await repository.getRoomAttendance(widget.classroomId, widget.roomId);
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
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: error != null
          ? Center(child: Text(error!))
          : sessions == null
          ? const AppLoader()
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
                  leading: CircleAvatar(child: Text(name.characters.first.toUpperCase())),
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
                          title: Text(DateFormat('MMM d, HH:mm:ss').format(session.joinedAt)),
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

/// Đồng hồ thời gian đã live, tự cập nhật mỗi giây mà không dựng lại cả phòng.
class _ElapsedTime extends StatefulWidget {
  const _ElapsedTime({required this.since});
  final DateTime since;

  @override
  State<_ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends State<_ElapsedTime> {
  late final Timer timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    timer;
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    final safe = elapsed.isNegative ? Duration.zero : elapsed;
    String two(int value) => value.toString().padLeft(2, '0');
    final text = safe.inHours > 0
        ? '${safe.inHours}:${two(safe.inMinutes % 60)}:${two(safe.inSeconds % 60)}'
        : '${two(safe.inMinutes)}:${two(safe.inSeconds % 60)}';
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFFC9CDD4),
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
