// 泳道编辑弹窗：名称、风格描述、底色选择，实时预览。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../models/style_lane.dart';
import '../util/lane_tint.dart';

/// 用户选择后的结果；tintColor==null 表示"自动"。
class LaneEditResult {
  const LaneEditResult({
    required this.label,
    required this.stylePrompt,
    required this.tintColor,
  });

  final String label;
  final String stylePrompt;
  final String? tintColor;
}

/// 预设色板（与 lane_tint.dart 中 _kTintGroups 顺序一致，但在 UI 层独立声明）。
const _kLaneSwatches = [
  '#FF8A50',
  '#4A78C8',
  '#9AD8D8',
  '#3E7C5A',
  '#6A4C93',
];

/// 打开泳道编辑弹窗；existing==null 表示新建。
Future<LaneEditResult?> showLaneEditDialog(
  BuildContext context, {
  StyleLane? existing,
}) {
  return showDialog<LaneEditResult>(
    context: context,
    builder: (_) => _LaneEditDialog(existing: existing),
  );
}

class _LaneEditDialog extends StatefulWidget {
  const _LaneEditDialog({this.existing});

  final StyleLane? existing;

  @override
  State<_LaneEditDialog> createState() => _LaneEditDialogState();
}

class _LaneEditDialogState extends State<_LaneEditDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _styleCtrl;
  String? _selectedTint; // null = 自动

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.existing?.label ?? '');
    _styleCtrl =
        TextEditingController(text: widget.existing?.stylePrompt ?? '');
    _selectedTint = widget.existing?.tintColor;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _styleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final isNew = widget.existing == null;

    return AlertDialog(
      backgroundColor: colors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InkRadius.lg),
      ),
      title: Text(
        isNew ? l10n.laneNewTitle : l10n.laneEditTitle,
        style: typo.headline.copyWith(color: colors.fg1),
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称
              Text(
                l10n.laneNameLabel,
                style: typo.label.copyWith(color: colors.fg2),
              ),
              const SizedBox(height: InkSpacing.xs),
              InkInput(
                controller: _labelCtrl,
                hintText: l10n.laneNameHint,
              ),
              const SizedBox(height: InkSpacing.md),

              // 风格描述（多行）
              Text(
                l10n.laneStyleLabel,
                style: typo.label.copyWith(color: colors.fg2),
              ),
              const SizedBox(height: InkSpacing.xs),
              InkInput(
                controller: _styleCtrl,
                hintText: l10n.laneStyleHint,
                minLines: 3,
                maxLines: null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: InkSpacing.md),

              // 底色选择
              Text(
                l10n.laneTintLabel,
                style: typo.label.copyWith(color: colors.fg2),
              ),
              const SizedBox(height: InkSpacing.xs),
              _TintRow(
                selected: _selectedTint,
                onSelect: (hex) => setState(() => _selectedTint = hex),
                autoLabel: l10n.laneTintAuto,
              ),
              const SizedBox(height: InkSpacing.md),

              // 实时预览
              _PreviewBox(
                tintColor: _selectedTint,
                stylePrompt: _styleCtrl.text,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            l10n.laneDialogCancel,
            style: typo.body.copyWith(color: colors.fg2),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            LaneEditResult(
              label: _labelCtrl.text.trim(),
              stylePrompt: _styleCtrl.text.trim(),
              tintColor: _selectedTint,
            ),
          ),
          child: Text(
            l10n.laneDialogSave,
            style: typo.body.copyWith(color: colors.accent),
          ),
        ),
      ],
    );
  }
}

/// 色块行：预设色块 + "自动" 选项。
class _TintRow extends StatelessWidget {
  const _TintRow({
    required this.selected,
    required this.onSelect,
    required this.autoLabel,
  });

  final String? selected;
  final ValueChanged<String?> onSelect;
  final String autoLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;

    return Wrap(
      spacing: InkSpacing.sm,
      runSpacing: InkSpacing.sm,
      children: [
        // 自动 chip
        GestureDetector(
          onTap: () => onSelect(null),
          child: _SwatchChip(
            color: colors.surface3,
            isSelected: selected == null,
            label: Text(
              autoLabel,
              style: typo.label.copyWith(
                color: selected == null ? colors.fg1 : colors.fg3,
              ),
            ),
          ),
        ),
        // 预设色块
        for (final hex in _kLaneSwatches)
          GestureDetector(
            onTap: () => onSelect(hex),
            child: _SwatchChip(
              color: parseHexColor(hex) ?? colors.surface3,
              isSelected: selected == hex,
            ),
          ),
      ],
    );
  }
}

/// 单个色块（选中时显示外边框）。
class _SwatchChip extends StatelessWidget {
  const _SwatchChip({
    required this.color,
    required this.isSelected,
    this.label,
  });

  final Color color;
  final bool isSelected;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Container(
      padding: label != null
          ? const EdgeInsets.symmetric(
              horizontal: InkSpacing.sm,
              vertical: InkSpacing.xs,
            )
          : const EdgeInsets.all(InkSpacing.xs),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: isSelected
            ? Border.all(color: colors.accent, width: 2)
            : Border.all(color: colors.border),
      ),
      child: label ??
          const SizedBox(
            width: InkSpacing.lg,
            height: InkSpacing.lg,
          ),
    );
  }
}

/// 实时预览框：用 effectiveLaneTint 计算底色。
class _PreviewBox extends StatelessWidget {
  const _PreviewBox({
    required this.tintColor,
    required this.stylePrompt,
  });

  final String? tintColor;
  final String stylePrompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final tint = effectiveLaneTint(
      tintColor: tintColor,
      stylePrompt: stylePrompt,
    );

    return Container(
      height: InkSpacing.xxl,
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.15) ?? colors.surface3,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(color: colors.border),
      ),
    );
  }
}
