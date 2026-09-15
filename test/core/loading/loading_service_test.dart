import 'package:eflutter/core/loading/loading_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('show during descendant initState does not notify during build', (
    tester,
  ) async {
    final service = LoadingService();

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: service.isLoading,
          builder: (_, loading, _) =>
              _ShowLoadingOnMount(service: service, loading: loading),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(service.isLoading.value, isTrue);

    service.hide();
    expect(service.isLoading.value, isFalse);
    service.dispose();
  });
}

class _ShowLoadingOnMount extends StatefulWidget {
  const _ShowLoadingOnMount({required this.service, required this.loading});
  final LoadingService service;
  final bool loading;

  @override
  State<_ShowLoadingOnMount> createState() => _ShowLoadingOnMountState();
}

class _ShowLoadingOnMountState extends State<_ShowLoadingOnMount> {
  @override
  void initState() {
    super.initState();
    widget.service.show();
  }

  @override
  Widget build(BuildContext context) => Text('${widget.loading}');
}
