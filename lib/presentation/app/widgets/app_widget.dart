import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key, required this.child});
  final Widget child;

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthCubit>().state;
      if (authState.isAuthenticated) {
        context.read<AppCubit>().load();
      } else {
        context.read<AppCubit>().clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isAuthenticated) {
          context.read<AppCubit>().load();
        } else {
          context.read<AppCubit>().clear();
        }
      },
      child: BlocListener<AppCubit, AppState>(
        listener: (context, state) => context.handleFailure(state.failure),
        child: widget.child,
      ),
    );
  }
}
