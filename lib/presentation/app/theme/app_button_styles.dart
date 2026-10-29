import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';

/// Kiểu nút dùng chung theo thiết kế mới (classrooms, profile, post).
abstract final class AppButtonStyles {
  /// Nền xanh nhạt (primary 10% trên nền trắng, đục để vẫn rõ trên nền tối).
  static const tint = Color(0xFFE6F3FA);

  static final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  static const _padding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  static const _text = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  /// Nút chính: nền xanh, chữ trắng. Dùng với [FilledButton].
  static final primary = FilledButton.styleFrom(
    backgroundColor: ColorName.primary,
    foregroundColor: Colors.white,
    padding: _padding,
    shape: _shape,
    textStyle: _text,
  );

  /// Nút phụ (Cancel, Edit…): nền xanh nhạt, chữ xanh. Dùng với [FilledButton].
  static final secondary = FilledButton.styleFrom(
    backgroundColor: tint,
    foregroundColor: ColorName.primary,
    padding: _padding,
    shape: _shape,
    textStyle: _text,
  );

  /// Nút X tròn 36px ở góc popup. Dùng với [IconButton].
  static final close = IconButton.styleFrom(
    backgroundColor: tint,
    foregroundColor: ColorName.primary,
    fixedSize: const Size(36, 36),
    minimumSize: const Size(36, 36),
  );
}
