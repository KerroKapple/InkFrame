// SB-2 剧本导入对话框：粘贴 → 实时预览 → 一键建成镜头链。
//
// 预览是这张卡的定心丸。拆分规则（SB-1）再讲究也有猜错的时候，用户得先看见
// 「拆成了几镜、每镜叫什么」才敢按创建；策略切换后预览立刻重算，等于把规则
// 摊开给人验。真正落库的原子性在 ScriptImportController，本文件只管交互。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../providers/script_import_controller.dart';
import '../util/script_splitter.dart';

/// 打开剧本导入对话框。[origin] 是第一镜的左上角世界坐标（缺省世界原点）。
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
    // 文案 / navigator / 通知出口都在 await 前取好：成功要先关对话框再提示，
    // 那之后本 State 的 context 和 ref 已经不能用了。
    final String doneMsg = context.l10n.scriptImportDone(drafts.length);
    final String failMsg = context.l10n.scriptImportFailed;
    final ToastService toast = ref.read(toastServiceProvider);
    final NavigatorState navigator = Navigator.of(context);
    final ScriptImportController controller =
        ref.read(scriptImportControllerProvider(widget.canvasId));

    setState(() => _busy = true);
    try {
      await controller.importDrafts(drafts, origin: widget.origin);
      navigator.pop();
      // 建链是一次短事务、用户就等在对话框前——是即时回应，不是后台事件，不响。
      toast.show(doneMsg, kind: ToastKind.success);
    } on InkError catch (_) {
      // 事务已整体回滚，画布没有残留——对话框留着，用户改完还能再点一次。
      // 通知卡画在所有路由之上，对话框开着也看得见。
      if (mounted) setState(() => _busy = false);
      toast.show(failMsg, kind: ToastKind.error);
    }
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
                // 一打开就持焦：框常从画布开（空白处右键「导入剧本…」），按键不能穿到框后面的画布上。
                autofocus: true,
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
          // 写出数量，与预览头「N 镜」同一个 N；0 镜走 ARB 的 =0 分支「创建镜头」。
          // 忙碌中文本没动、N 也不变——按钮只置灰，不闪回 0。
          child: Text(l.scriptImportConfirm(drafts.length)),
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
        style: context.inkTypography.meta
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
                  style: typo.meta.copyWith(color: colors.fg2),
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
