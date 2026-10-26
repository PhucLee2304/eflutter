import 'package:eflutter/presentation/exams/attempt/listening_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('không có audio thì báo xong khi hết thời lượng còn lại', (
    tester,
  ) async {
    var completed = 0;
    final preloader = ListeningAudioPreloader();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListeningAudio(
            url: null,
            durationMs: 3000,
            startOffset: const Duration(seconds: 1),
            onCompleted: () => completed++,
            preloader: preloader,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1500));
    expect(completed, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(completed, 1);
    expect(find.byKey(const ValueKey('listening-resume')), findsNothing);
  });
}
