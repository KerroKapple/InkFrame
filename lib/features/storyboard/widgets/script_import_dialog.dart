// SB-2 脚本导入对话框：粘贴 → 实时预览 → 一键建成分镜链。
//
// 预览是这张卡的定心丸。拆分规则（SB-1）再讲究也有猜错的时候，用户得先看见
// 「拆成了几镜、每镜叫什么」才敢按创建；策略切换后预览立刻重算，等于把规则
// 摊开给人验。真正落库的原子性在 ScriptImportController，本文件只管交互。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../providers/script_import_controller.dart';
import '../util/script_splitter.dart';

/// 打开脚本导入对话框。[origin] 是第一镜的左上角世界坐标（缺省世界原点）。
Future<void> showScriptImportDialog(
  BuildContext context, {
  required String canvasId,
  Offset origin = Offset.zero,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => ScriptImportDialog(canvasId: canvasId, origin: origin),
    );

class ScriptImportDialog extends ConsumerStatefulWidget {
  const ScriptImportDialog({
    super.key,
    required this.canvasId,
    this.origin = Offset.zero,
  });

  final String canvasId;

  /// 第一镜落点；后续各镜沿 x 轴排开。
  final Offset origin;

  @override
  ConsumerState<ScriptImportDialog> createState() => _ScriptImportDialogState();
}

class _ScriptImportDialogState extends ConsumerState<ScriptImportDialog> {
  final TextEditingController _ctrl = TextEditingController();
  ScriptSplitStrategy _strategy = ScriptSplitStrategy.blankLine;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 每帧现算——粘贴级文本量下拆分是纯字符串处理，没必要缓存出一份会过期的状态。
  List<ShotDraft> get _drafts =>
      splitScript(_ctrl.text, strategy: _strategy);

  Future<void> _confirm() async {
    final List<ShotDraft> drafts = _drafts;
    if (drafts.isEmpty || _busy) return;
    // 文案 / navigator / messenger 都在 await 前取好：成功要先关对话框再提示，
    // 那之后本 State 的 context 已经不能用了。
    final String doneMsg = context.l10n.scriptImportDone(drafts.length);
    final String failMsg = context.l10n.scriptImportFailed;
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScriptImportController controller =
        ref.read(scriptImportControllerProvider(widget.canvasId));

    setState(() => _busy = true);
    try {
      await controller.importDrafts(drafts, origin: widget.origin);
      navigator.pop();
      _showSnack(messenger, doneMsg);
    } on InkError catch (_) {
      // 事务已整体回滚，画布没有残留——对话框留着，用户改完还能再点一次。
      if (mounted) setState(() => _busy = false);
      _showSnack(messenger, failMsg);
    }
  }

  void _showSnack(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final List<ShotDraft> drafts = _drafts;
    return AlertDialog(
      title: Text(l.scriptImportTitle),
      // 内容整体可滚：AlertDialog 在小窗口下只给几百像素高，粘贴框+预览很容易顶满。
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InkInput(
                controller: _ctrl,
                hintText: l.scriptImportHint,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: InkSpacing.md),
              _Label(text: l.scriptImportStrategyLabel),
              const SizedBox(height: InkSpacing.xs),
              SegmentedButton<ScriptSplitStrategy>(
                segments: <ButtonSegment<ScriptSplitStrategy>>[
                  ButtonSegment<ScriptSplitStrategy>(
                    value: ScriptSplitStrategy.blankLine,
                    label: Text(l.scriptImportStrategyBlankLine),
                  ),
                  ButtonSegment<ScriptSplitStrategy>(
                    value: ScriptSplitStrategy.perLine,
                    label: Text(l.scriptImportStrategyPerLine),
                  ),
                ],
                selected: <ScriptSplitStrategy>{_strategy},
                onSelectionChanged: _busy
                    ? null
                    : (sel) => setState(() => _strategy = sel.first),
              ),
              const SizedBox(height: InkSpacing.md),
              _Label(text: l.scriptImportPreviewLabel),
              const SizedBox(height: InkSpacing.xs),
              _Preview(drafts: drafts),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: (_busy || drafts.isEmpty) ? null : _confirm,
          child: Text(l.scriptImportConfirm),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: context.inkTypography.caption
            .copyWith(color: context.inkColors.fg3),
      );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.drafts});

  final List<ShotDraft> drafts;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    return Container(
      width: double.infinity,
      height: 148,
      padding: const EdgeInsets.all(InkSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: drafts.isEmpty
          ? Text(
              l.scriptImportPreviewEmpty,
              style: typo.body.copyWith(color: colors.fg4),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.scriptImportShotCount(drafts.length),
                  style: typo.caption.copyWith(color: colors.fg2),
                ),
                const SizedBox(height: InkSpacing.xs),
                Expanded(
                  child: ListView.builder(
                    itemCount: drafts.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: InkSpacing.xs),
                      child: Text(
                        '${i + 1}. ${drafts[i].label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.body.copyWith(color: colors.fg2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
