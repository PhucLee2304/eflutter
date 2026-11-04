import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';

/// Màu và khối giao diện dùng chung cho gradebook bài và gradebook lớp (Figma 15:341, 15:881).
abstract final class Gb {
  static const border = Color(0xFFE4E6EB);
  static const muted = Color(0xFF65676B);
  static const faint = Color(0xFF8A8D91);
  static const text = Color(0xFF1C1E21);
  static const soft = Color(0xFFF7F8FA);
  static const field = Color(0xFFF0F2F5);
  static const green = Color(0xFF1E8E3E);
  static const greenBg = Color(0xFFE7F6EC);
  static const orange = Color(0xFFB26A00);
  static const orangeBg = Color(0xFFFFF4E5);
  static const red = Color(0xFFD93025);
  static const redBg = Color(0xFFFDECEA);

  /// Màu điểm (thang 10): ≥ 8 xanh, < 5 đỏ.
  static Color score(double? value) => value == null
      ? faint
      : value >= 8
      ? green
      : value < 5
      ? red
      : text;

  static (Color, Color) status(String status) => switch (status) {
    'SUBMITTED' => (greenBg, green),
    'LATE' => (orangeBg, orange),
    'IN_PROGRESS' => (AppButtonStyles.tint, ColorName.primary),
    _ => (field, muted),
  };

  static String statusLabel(String status) {
    final words = status.trim().split('_').where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return '-';
    final label = words.map((word) => word.toLowerCase()).join(' ');
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  static String scoreText(double? value) => value == null ? '—' : value.toStringAsFixed(1);
}

class GbCard extends StatelessWidget {
  const GbCard({super.key, required this.children, this.padding = const EdgeInsets.all(20)});
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Gb.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

class GbCardHead extends StatelessWidget {
  const GbCardHead(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 2,
    children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: Gb.muted)),
    ],
  );
}

class GbStat extends StatelessWidget {
  const GbStat({super.key, required this.label, required this.value, this.sub, this.color});
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: Gb.soft, borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Gb.muted),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color ?? Gb.text),
        ),
        if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: Gb.faint)),
      ],
    ),
  );
}

/// Hàng ô số liệu: chia đều khi đủ rộng, xuống dòng (2 cột) khi hẹp.
class GbStats extends StatelessWidget {
  const GbStats({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 640) {
        // Các ô cao bằng ô cao nhất.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [for (final child in children) Expanded(child: child)],
          ),
        );
      }
      final width = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

class GbPill extends StatelessWidget {
  const GbPill(this.label, {super.key, required this.background, required this.foreground});
  GbPill.status(String status, {super.key})
    : label = Gb.statusLabel(status),
      background = Gb.status(status).$1,
      foreground = Gb.status(status).$2;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: foreground),
    ),
  );
}

/// Thanh trên của màn con trong tab Classwork: Back bên trái, thao tác bên phải.
class GbHeader extends StatelessWidget {
  const GbHeader({super.key, required this.onBack, this.actions = const []});
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 10,
    children: [
      TextButton.icon(
        onPressed: onBack,
        style: TextButton.styleFrom(foregroundColor: ColorName.primary),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Back'),
      ),
      const Spacer(),
      ...actions,
    ],
  );
}

class GbSearchField extends StatelessWidget {
  const GbSearchField({
    super.key,
    required this.onChanged,
    this.width = 220,
    this.hint = 'Search students',
  });
  final ValueChanged<String> onChanged;
  final double width;
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 38,
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Gb.faint),
        prefixIcon: const Icon(Icons.search, size: 18, color: Gb.faint),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        filled: true,
        fillColor: Gb.field,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ColorName.primary),
        ),
      ),
    ),
  );
}

class GbAvatar extends StatelessWidget {
  const GbAvatar({super.key, required this.name, this.url, this.size = 32});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = url;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFD8E9F5),
      backgroundImage: image == null || image.isEmpty ? null : NetworkImage(image),
      child: image == null || image.isEmpty
          ? Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w600,
                color: ColorName.primary,
              ),
            )
          : null,
    );
  }
}

/// Lỗi tải dữ liệu: thông báo kèm nút thử lại.
class GbError extends StatelessWidget {
  const GbError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      spacing: 8,
      children: [
        Text(message, style: const TextStyle(color: Gb.muted)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
