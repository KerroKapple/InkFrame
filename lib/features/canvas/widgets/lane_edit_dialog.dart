// 泳道编辑框（Lanes 稿 03）：456 宽；38 标题栏（编辑泳道 | ✕）| 名称 / 风格提示词 / 底色 / 预览 |
// 底部条（「厚度不在此处调，拖分界线改」| 取消 | 保存）。
//
// 四项照现状还原（没有预设 chip、没有厚度滑块——PLAN §P1 明确不做）。唯一改动：色板直接读
// lane_tint 词表常量（改动 6，UI 层不再复刻五个色值），「自动」下面注明当前推断命中的词与色值。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
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

  /// 稿：对话框 456 宽（content-box）。
  static const double width = 456;

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

  void _save() => Navigator.of(context).pop(
        LaneEditResult(
          label: _labelCtrl.text.trim(),
          stylePrompt: _styleCtrl.text.trim(),
          tintColor: _selectedTint,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final isNew = widget.existing == null;
    final TextStyle label = typo.body.copyWith(color: colors.fg4);
    final TextStyle note = typo.micro.copyWith(color: colors.fg6, height: 1.5);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(InkSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _LaneEditDialog.width + 2),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface3,
            border: Border.all(color: colors.control),
            borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
            boxShadow: InkShadow.overlay,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 稿：38 高 + 1px 下沿，surface2。
              Container(
                height: 39,
                padding: const EdgeInsets.only(left: InkSpacing.s14, right: InkSpacing.s6),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  border: Border(bottom: BorderSide(color: colors.borderStrong)),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      isNew ? l10n.laneNewTitle : l10n.laneEditTitle,
                      style: typo.bodyStrong.copyWith(color: colors.fg1),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      icon: Icon(Icons.close, size: InkSpacing.md, color: colors.fg5),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14, vertical: InkSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 名称
                      Text(l10n.laneNameLabel, style: label),
                      const SizedBox(height: InkSpacing.s6),
                      InkInput(controller: _labelCtrl, hintText: l10n.laneNameHint),
                      const SizedBox(height: InkSpacing.md),

                      // 风格提示词（多行）+ 说明
                      Text(l10n.laneStyleLabel, style: label),
                      const SizedBox(height: InkSpacing.s6),
                      InkInput(
                        controller: _styleCtrl,
                        hintText: l10n.laneStyleHint,
                        minLines: 3,
                        maxLines: null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: InkSpacing.s6),
                      Text(l10n.laneStyleNote, style: note),
                      const SizedBox(height: InkSpacing.md),

                      // 底色：自动 + 词表五色 + 推断说明
                      Text(l10n.laneTintLabel, style: label),
                      const SizedBox(height: InkSpacing.sm),
                      _TintRow(
                        selected: _selectedTint,
                        onSelect: (hex) => setState(() => _selectedTint = hex),
                        autoLabel: l10n.laneTintAuto,
                      ),
                      if (_selectedTint == null) ...<Widget>[
                        const SizedBox(height: InkSpacing.sm),
                        Text(_autoNote(context), style: note),
                      ],
                      const SizedBox(height: InkSpacing.md),

                      // 实时预览
                      Text(l10n.lanePreviewLabel, style: label),
                      const SizedBox(height: InkSpacing.s6),
                      _PreviewBox(tintColor: _selectedTint, stylePrompt: _styleCtrl.text),
                    ],
                  ),
                ),
              ),
              // 稿：底部条 padding 12 14，surface2 + 上沿。
              Container(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14, vertical: InkSpacing.s12),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  border: Border(top: BorderSide(color: colors.borderStrong)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(l10n.laneDialogThicknessNote, style: typo.micro.copyWith(color: colors.fg6)),
                    ),
                    const SizedBox(width: InkSpacing.sm),
                    InkButton(
                      label: l10n.laneDialogCancel,
                      variant: InkButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                    const SizedBox(width: InkSpacing.sm),
                    InkButton(label: l10n.laneDialogSave, onPressed: _save),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 「自动」下面那行：命中了写「当前命中「neon / rain」→ #4A78C8」，没命中写不绘底色。
  String _autoNote(BuildContext context) {
    final String prompt = _styleCtrl.text;
    final String? hex = inferTintHex(prompt);
    if (hex == null) return context.l10n.laneTintAutoMiss;
    return context.l10n.laneTintAutoHit(matchedTintKeywords(prompt).join(' / '), hex);
  }
}

/// 色块行：「自动」chip + 词表五色（kLaneTintChoices）。
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
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 自动 chip：稿 24 高、surface4 底、control 边、圆角 4；选中时琥珀边。
        GestureDetector(
          onTap: () => onSelect(null),
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface4,
              border: Border.all(color: selected == null ? colors.accent : colors.control),
              borderRadius: BorderRadius.circular(InkRadius.sm),
            ),
            child: Text(
              autoLabel,
              style: typo.meta.copyWith(color: selected == null ? colors.fg1 : colors.fg5),
            ),
          ),
        ),
        // 词表五色：24×24 圆角 4；选中时琥珀边。
        for (final hex in kLaneTintChoices)
          GestureDetector(
            onTap: () => onSelect(hex),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: parseHexColor(hex) ?? colors.surface3,
                border: Border.all(color: selected == hex ? colors.accent : colors.control),
                borderRadius: BorderRadius.circular(InkRadius.sm),
              ),
            ),
          ),
      ],
    );
  }
}

/// 实时预览框：用 effectiveLaneTint 计算底色（稿：40 高、圆角 4、0.15 alpha）。
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
      height: 42,
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.15) ?? colors.surface3,
        borderRadius: BorderRadius.circular(InkRadius.sm),
        border: Border.all(color: colors.control),
      ),
    );
  }
}
