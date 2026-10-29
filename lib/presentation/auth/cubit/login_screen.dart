import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/generated/assets.gen.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Màn đăng nhập: màn rộng chia đôi (panel giới thiệu + thẻ đăng nhập), màn hẹp chỉ hiện thẻ.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const _wideBreakpoint = 1000.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.failure != null) {
            context.handleFailure(state.failure);
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final authPanel = Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: const _LoginCard(),
              ),
            );
            if (constraints.maxWidth < _wideBreakpoint) return SafeArea(child: authPanel);
            return Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(child: authPanel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _features = [
    (
      Icons.videocam_outlined,
      'Live classrooms',
      'Join real-time video lessons, raise your hand and interact with teachers and classmates.',
    ),
    (
      Icons.menu_book_outlined,
      'Structured lectures',
      'Watch recorded lessons organized by topic and learn at your own pace.',
    ),
    (
      Icons.assignment_turned_in_outlined,
      'Online exams',
      'Take practice tests and exams with instant results to track your progress.',
    ),
    (
      Icons.forum_outlined,
      'Class discussions',
      'Share posts, ask questions and stay updated with notifications.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorName.primary, ColorName.cyan],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 80),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 160),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Assets.images.logo.image(width: 44, height: 44),
                    ),
                    const Text(
                      'Ego',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Learn online,\nanytime, anywhere.',
                        style: TextStyle(
                          fontSize: 56,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Text(
                          'Ego brings your classes, lectures and exams together in one '
                          'place — so you can focus on learning, not juggling tools.',
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 768),
                        child: _FeatureGrid(features: _features),
                      ),
                    ],
                  ),
                ),
                Text(
                  '© 2026 Ego',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.features});

  final List<(IconData, String, String)> features;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < features.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              for (final f in features.skip(i).take(2))
                Expanded(child: _FeatureCard(icon: f.$1, title: f.$2, description: f.$3)),
            ],
          ),
        ),
      );
    }
    return Column(spacing: 16, children: rows);
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorName.gray5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 8),
            blurRadius: 32,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 32,
        children: [
          const Column(
            spacing: 8,
            children: [
              Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ColorName.labelPrimary,
                ),
              ),
              Text(
                'Sign in to continue learning with Ego',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: ColorName.labelSecondary),
              ),
            ],
          ),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.read<AuthCubit>().signInWithGoogle(),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ColorName.labelPrimary,
                side: const BorderSide(color: ColorName.gray4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  Assets.images.google.image(width: 24, height: 24),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12, color: ColorName.gray1),
                children: [
                  TextSpan(text: 'By signing in, you agree to our '),
                  TextSpan(
                    text: 'Terms of Service and Privacy Policy',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: ColorName.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: ColorName.primary,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
