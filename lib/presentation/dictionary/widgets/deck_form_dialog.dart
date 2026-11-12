import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:flutter/material.dart';

class DeckFormDialog extends StatefulWidget {
  final FlashcardDeck? existingDeck;
  final FlashcardCubit cubit;

  const DeckFormDialog({
    super.key,
    this.existingDeck,
    required this.cubit,
  });

  static Future<bool?> show(
    BuildContext context, {
    FlashcardDeck? existingDeck,
    required FlashcardCubit cubit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeckFormDialog(
        existingDeck: existingDeck,
        cubit: cubit,
      ),
    );
  }

  @override
  State<DeckFormDialog> createState() => _DeckFormDialogState();
}

class _DeckFormDialogState extends State<DeckFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late String _selectedColorHex;
  bool _isSubmitting = false;

  final List<String> _palette = [
    '#6366F1', // Indigo
    '#3B82F6', // Blue
    '#0EA5E9', // Sky
    '#10B981', // Emerald
    '#14B8A6', // Teal
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#EC4899', // Pink
    '#8B5CF6', // Purple
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingDeck?.name ?? '');
    _descController = TextEditingController(text: widget.existingDeck?.description ?? '');
    _selectedColorHex = widget.existingDeck?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      String clean = hex.replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên bộ thẻ')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final desc = _descController.text.trim();
    bool success;

    if (widget.existingDeck != null) {
      success = await widget.cubit.updateDeck(
        widget.existingDeck!.id,
        name: name,
        description: desc.isNotEmpty ? desc : null,
        color: _selectedColorHex,
      );
    } else {
      final newDeck = await widget.cubit.createDeck(
        name,
        description: desc.isNotEmpty ? desc : null,
        color: _selectedColorHex,
      );
      success = newDeck != null;
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thao tác không thành công. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.existingDeck != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _parseColor(_selectedColorHex).withOpacity(0.15),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.create_new_folder,
                      color: _parseColor(_selectedColorHex),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isEditing ? 'Sửa bộ thẻ' : 'Tạo bộ thẻ mới',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tên bộ thẻ
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Tên bộ thẻ *',
                  hintText: 'Vd: Từ vựng IELTS, Giao tiếp hằng ngày...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 14),

              // Mô tả
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Mô tả (tuỳ chọn)',
                  hintText: 'Ghi chú mục tiêu hoặc chủ đề của bộ thẻ...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Chọn màu
              Text(
                'Màu đại diện:',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _palette.map((hex) {
                  final color = _parseColor(hex);
                  final isSelected = _selectedColorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: colorScheme.onSurface, width: 2.5)
                            : null,
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _parseColor(_selectedColorHex),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(isEditing ? Icons.save : Icons.add, size: 18),
                    label: Text(
                      _isSubmitting
                          ? 'Đang lưu...'
                          : isEditing
                              ? 'Cập nhật'
                              : 'Tạo bộ thẻ',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

