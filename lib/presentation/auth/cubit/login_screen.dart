import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/generated/assets.gen.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state.failure != null) {
              context.handleFailure(state.failure);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  spacing: 32,
                  children: [
                    Assets.images.logo.image(height: 84),
                    const Text(
                      'Welcome to EFlutter',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: ColorName.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () => context.read<AuthCubit>().signInWithGoogle(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4285F4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 2,
                        shadowColor: ColorName.primary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 12,
                        children: [
                          Assets.images.google.image(width: 24, height: 24),
                          const Text(
                            'Tiếp tục với Google',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
