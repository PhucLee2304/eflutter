import 'package:eflutter/core/attempt_lock/attempt_integrity_reporter.dart';
import 'package:eflutter/core/attempt_lock/integrity_away_tracker.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sent {
  const _Sent(this.eventId, this.replayed);
  final String eventId;
  final bool replayed;
}

AttemptIntegrityEvent _event(
  AttemptIntegrityEventType type, {
  int attemptId = 1,
}) => AttemptIntegrityEvent(type: type, attemptId: attemptId);

void main() {
  group('SocketAttemptIntegrityReporter', () {
    late SocketAttemptIntegrityReporter reporter;
    late List<_Sent> sent;

    void bind([int attemptId = 1]) => reporter.bind(
      attemptId,
      (event, {required replayed}) => sent.add(_Sent(event.eventId, replayed)),
    );

    setUp(() {
      reporter = SocketAttemptIntegrityReporter();
      sent = [];
    });

    test('gửi trực tiếp khi đã bind, rời hàng khi ACK', () {
      bind();
      final event = _event(AttemptIntegrityEventType.awayStart);
      reporter.report(event);

      expect(sent.single.eventId, event.eventId);
      expect(sent.single.replayed, isFalse);
      reporter.acknowledge(1, event.eventId);
      expect(reporter.pending(1), isEmpty);
    });

    test('retry sau khi nối lại giữ eventId và đánh dấu replayed', () {
      bind();
      final event = _event(AttemptIntegrityEventType.awayEnd);
      reporter.report(event);
      reporter.unbind(1);
      bind();

      expect(sent.map((item) => item.eventId), [event.eventId, event.eventId]);
      expect(sent.last.replayed, isTrue);
    });

    test('event phát sinh khi chưa bind được gửi bù với replayed', () {
      final event = _event(AttemptIntegrityEventType.navigationBlocked);
      reporter.report(event);
      expect(sent, isEmpty);

      bind();
      expect(sent.single.eventId, event.eventId);
      expect(sent.single.replayed, isTrue);
    });

    test('clear (ATTEMPT_RESET) bỏ hàng đợi và gỡ sender', () {
      bind();
      reporter.report(_event(AttemptIntegrityEventType.copy));
      reporter.clear(1);
      reporter.report(_event(AttemptIntegrityEventType.paste));

      expect(sent, hasLength(1));
      expect(reporter.pending(1), hasLength(1));
      reporter.clear(1);
      expect(reporter.pending(1), isEmpty);
    });

    test('attempt không giám sát và event chỉ log thì không xếp hàng', () {
      reporter.ignore(2);
      reporter.report(
        _event(AttemptIntegrityEventType.backBlocked, attemptId: 2),
      );
      reporter.report(_event(AttemptIntegrityEventType.lifecycleChanged));

      expect(reporter.pending(2), isEmpty);
      expect(reporter.pending(1), isEmpty);
    });

    test('hàng đợi bị giới hạn', () {
      for (var i = 0; i < SocketAttemptIntegrityReporter.maxQueued + 5; i++) {
        reporter.report(_event(AttemptIntegrityEventType.copy));
      }
      expect(
        reporter.pending(1),
        hasLength(SocketAttemptIntegrityReporter.maxQueued),
      );
    });
  });

  group('IntegrityAwayTracker', () {
    late List<DateTime> starts;
    late List<AwayEpisode> ends;
    late IntegrityAwayTracker tracker;
    final t0 = DateTime(2026, 10, 27, 8);

    setUp(() {
      starts = [];
      ends = [];
      tracker = IntegrityAwayTracker(onStart: starts.add, onEnd: ends.add);
    });

    test('blur và hidden cùng lúc chỉ ra một episode', () {
      tracker.update(focused: false, at: t0);
      tracker.update(hidden: true, at: t0.add(const Duration(milliseconds: 5)));
      tracker.update(hidden: false, at: t0.add(const Duration(seconds: 4)));
      expect(ends, isEmpty, reason: 'vẫn còn mất focus');
      tracker.update(focused: true, at: t0.add(const Duration(seconds: 5)));

      expect(starts, [t0]);
      expect(ends.single.duration, const Duration(seconds: 5));
    });

    test('hai lần rời màn riêng biệt là hai episode', () {
      tracker.update(focused: false, at: t0);
      tracker.update(focused: true, at: t0.add(const Duration(seconds: 1)));
      tracker.update(hidden: true, at: t0.add(const Duration(seconds: 2)));
      tracker.update(hidden: false, at: t0.add(const Duration(seconds: 3)));

      expect(starts, hasLength(2));
      expect(ends, hasLength(2));
    });

    test('sự kiện lặp không đổi trạng thái thì không báo', () {
      tracker.update(focused: true);
      tracker.update(hidden: false);
      expect(starts, isEmpty);
      expect(tracker.isAway, isFalse);
    });

    test('focus giả nhấp nháy khi đang ở app khác vẫn là một episode', () {
      fakeAsync((async) {
        final starts = <DateTime>[];
        final ends = <AwayEpisode>[];
        final tracker = IntegrityAwayTracker(
          onStart: starts.add,
          onEnd: ends.add,
          settle: const Duration(milliseconds: 1500),
        );
        for (var i = 0; i < 6; i++) {
          tracker.update(
            focused: false,
            at: t0.add(Duration(milliseconds: i * 800)),
          );
          async.elapse(const Duration(milliseconds: 400));
          tracker.update(
            focused: true,
            at: t0.add(Duration(milliseconds: i * 800 + 400)),
          );
          async.elapse(const Duration(milliseconds: 400));
        }
        expect(ends, isEmpty);
        async.elapse(const Duration(seconds: 2));

        expect(starts, [t0]);
        expect(ends.single.endedAt, t0.add(const Duration(milliseconds: 4400)));
      });
    });
  });
}
