import 'dart:async';

import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/attempt_page.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_navigator_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// [playing]: đang phát audio của trang; [gap]: hết audio, đếm ngược trước khi sang
/// trang; [advancing]: đã gửi ATTEMPT_LISTENING_ADVANCE, chờ ACK; [finished]: hết
/// phần nghe (stage READING).
enum ListeningPhase { idle, loading, playing, gap, advancing, finished }

class ListeningState {
  final ListeningPhase phase;
  final AttemptPage? page;

  /// Vị trí bắt đầu phát (elapsedMs của server) khi vào trang, để phát tiếp sau F5.
  final Duration startOffset;
  final Duration? gapRemaining;
  final Failure? failure;

  const ListeningState({
    this.phase = ListeningPhase.idle,
    this.page,
    this.startOffset = Duration.zero,
    this.gapRemaining,
    this.failure,
  });

  ListeningState copyWith({
    ListeningPhase? phase,
    Object? page = _sentinel,
    Duration? startOffset,
    Object? gapRemaining = _sentinel,
    Object? failure = _sentinel,
  }) => ListeningState(
    phase: phase ?? this.phase,
    page: identical(page, _sentinel) ? this.page : page as AttemptPage?,
    startOffset: startOffset ?? this.startOffset,
    gapRemaining: identical(gapRemaining, _sentinel)
        ? this.gapRemaining
        : gapRemaining as Duration?,
    failure: identical(failure, _sentinel) ? this.failure : failure as Failure?,
  );
}

const _sentinel = Object();

/// Con trỏ phần nghe phía client (PLAN_TOEIC_ATTEMPT.md T5): tải trang nghe hiện tại,
/// đếm ngược gapMs khi audio phát xong (widget gọi [audioCompleted]) rồi gửi advance.
/// Server là nguồn sự thật: lệch trang thì tải lại navigator và đi theo server.
class ListeningCubit extends Cubit<ListeningState> {
  ListeningCubit(
    this._repository,
    this._socket,
    this._navigator, {
    this.retryDelay = const Duration(seconds: 1),
    this.ackTimeout = const Duration(seconds: 10),
  }) : super(const ListeningState()) {
    _eventSubscription = _socket.events.listen(_handleSocketEvent);
  }

  final ExamRepository _repository;
  final AttemptSocketGateway _socket;
  final AttemptNavigatorCubit _navigator;
  final Duration retryDelay;
  final Duration ackTimeout;
  StreamSubscription<AttemptSocketEvent>? _eventSubscription;
  String? _pendingRequest;
  Timer? _gapTimer;
  Timer? _retryTimer;
  Timer? _ackTimer;

  int get _attemptId => _navigator.attemptId;

  /// Bắt đầu theo navigator đã tải: đang nghe thì vào trang hiện tại.
  Future<void> start() async {
    final nav = _navigator.state.navigator;
    if (nav == null || !nav.isListening || nav.currentPage == null) {
      _finish();
      return;
    }
    await _loadPage(nav.currentPage!);
  }

  /// Audio của trang đã phát xong (hoặc không phát được): đếm ngược gap rồi advance.
  void audioCompleted() {
    final page = state.page;
    if (state.phase != ListeningPhase.playing || page == null) return;
    _startGap(Duration(milliseconds: page.listening?.gapMs ?? 0));
  }

  Future<void> _loadPage(int index) async {
    _cancelTimers();
    emit(state.copyWith(phase: ListeningPhase.loading, failure: null));
    final result = await _repository.getAttemptPage(_attemptId, index);
    if (isClosed) return;
    switch (result) {
      case Success(data: final page):
        _navigator.registerPage(page);
        final elapsed = page.listening?.elapsedMs ?? 0;
        final audioMs = page.group?.audioDurationMs ?? 0;
        emit(
          state.copyWith(
            phase: ListeningPhase.playing,
            page: page,
            startOffset: Duration(milliseconds: elapsed),
            gapRemaining: null,
          ),
        );
        // F5 trong lúc đếm ngược: audio đã hết, chỉ còn phần gap.
        if (audioMs > 0 && elapsed >= audioMs) {
          final gap = (page.listening?.gapMs ?? 0) - (elapsed - audioMs);
          _startGap(Duration(milliseconds: gap < 0 ? 0 : gap));
        }
      case Failure():
        // 409: trang không còn mở (server đã tự tiến) → đi theo server.
        if (result.code == 409) {
          await _resync();
        } else {
          emit(state.copyWith(phase: ListeningPhase.idle, failure: result));
        }
      case Cancelled():
        emit(state.copyWith(phase: ListeningPhase.idle));
    }
  }

  void _startGap(Duration gap) {
    _gapTimer?.cancel();
    var remaining = gap;
    emit(state.copyWith(phase: ListeningPhase.gap, gapRemaining: remaining));
    if (remaining <= Duration.zero) {
      _advance();
      return;
    }
    // Tính theo đồng hồ thật: tab bị ẩn thì timer có thể bị trình duyệt gọi trễ.
    final deadline = DateTime.now().add(gap);
    _gapTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        timer.cancel();
        _advance();
      } else {
        emit(state.copyWith(gapRemaining: remaining));
      }
    });
  }

  void _advance() {
    final page = state.page;
    if (isClosed || page == null) return;
    emit(
      state.copyWith(
        phase: ListeningPhase.advancing,
        gapRemaining: Duration.zero,
      ),
    );
    try {
      _pendingRequest = _socket.sendListeningAdvance(
        attemptId: _attemptId,
        page: page.index,
      );
      _ackTimer?.cancel();
      _ackTimer = Timer(ackTimeout, () {
        _pendingRequest = null;
        unawaited(_resync());
      });
    } catch (_) {
      // Socket chưa kết nối: thử lại; quá lâu thì server cũng tự tiến trang.
      _retryTimer = Timer(retryDelay, _advance);
    }
  }

  void _handleSocketEvent(AttemptSocketEvent event) {
    if (event.requestId.isEmpty || event.requestId != _pendingRequest) return;
    _pendingRequest = null;
    _ackTimer?.cancel();
    if (event.success) {
      final payload = event.payload;
      if (payload == null) {
        unawaited(_resync());
        return;
      }
      final listening = AttemptListeningState.fromJson(payload);
      _navigator.applyListening(listening);
      if (listening.isListening && listening.currentPage != null) {
        unawaited(_loadPage(listening.currentPage!));
      } else {
        _finish();
      }
      return;
    }
    switch (event.code) {
      case AttemptSocketCode.listeningAdvanceTooEarly:
        _retryTimer = Timer(retryDelay, _advance);
      case AttemptSocketCode.attemptExpired:
      case AttemptSocketCode.attemptNotActive:
        // AttemptSessionCubit lo việc chờ nộp bài.
        _finish();
      default:
        unawaited(_resync());
    }
  }

  Future<void> _resync() async {
    _cancelTimers();
    final nav = await _navigator.refresh();
    if (isClosed) return;
    if (nav == null) {
      emit(state.copyWith(phase: ListeningPhase.idle));
      return;
    }
    if (nav.isListening && nav.currentPage != null) {
      await _loadPage(nav.currentPage!);
    } else {
      _finish();
    }
  }

  void _finish() {
    _cancelTimers();
    emit(
      state.copyWith(
        phase: ListeningPhase.finished,
        page: null,
        gapRemaining: null,
      ),
    );
  }

  void _cancelTimers() {
    _gapTimer?.cancel();
    _retryTimer?.cancel();
    _ackTimer?.cancel();
  }

  @override
  Future<void> close() async {
    _cancelTimers();
    await _eventSubscription?.cancel();
    return super.close();
  }
}
