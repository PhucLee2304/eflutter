import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:flutter/material.dart';

class RoomJoinControl extends StatelessWidget {
  const RoomJoinControl({
    super.key,
    required this.status,
    required this.connecting,
    required this.onJoin,
    this.error,
  });

  final String? status;
  final bool connecting;
  final VoidCallback onJoin;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      FilledButton.icon(
        onPressed: connecting || status != 'LIVE' ? null : onJoin,
        icon: connecting
            ? const SizedBox.square(
                dimension: 18,
                child: AppLoader(),
              )
            : const Icon(Icons.login),
        label: Text(
          status == 'LIVE'
              ? 'Join classroom'
              : status == 'ENDED'
              ? 'Class has ended'
              : 'Waiting for the teacher to start',
        ),
      ),
    ],
  );
}
