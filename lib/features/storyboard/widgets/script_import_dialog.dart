// SB-2 剧本导入对话框：粘贴 → 实时预览 → 一键建成镜头链。
//
// 预览是这张卡的定心丸。拆分规则（SB-1）再讲究也有猜错的时候，用户得先看见
// 「拆成了几镜、每镜叫什么」才敢按创建；策略切换后预览立刻重算，等于把规则
// 摊开给人验。真正落库的原子性在 ScriptImportController，本文件只管交互。
//
// 第三段策略「AI 拆分」（A2）：没填 Claude Key 时置灰。预览区换成 AiStoryboardPanel，
// 第一次「开始拆分」才建导演会话；之后拆分 / 停止 / 改设定 / 重拆 / 创建全部经
// DirectorSessionController（创建 = human_confirmed + 同一个 importDrafts）。
// 拆完又改了剧本 ⇒ 提案过期，创建置灰，要重新拆分。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/anthropic.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../core/models/director.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../../director/providers/director_session_controller.dart';
import '../../director/providers/director_session_state.dart';
import '../../director/widgets/ai_storyboard_panel.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../models/shot_draft.dart';
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

/// 拆分方式：两种规则 + AI。
enum ScriptImportMode { blankLine, perLine, ai }

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
  ScriptImportMode _mode = ScriptImportMode.blankLine;
  bool _busy = false;

  /// AI 拆分的会话；第一次「开始拆分」时才建。
  String? _sessionId;

  /// 提交那一刻拆出来的镜头（#14）。忙碌中预览与按钮都画它，不画框里现在的文字：粘贴框
  /// 忙碌中仍可编辑（不禁用——禁用会丢焦点，失败后还得手动把焦点要回来），而在提交的
  /// 始终是这一份。
  List<ShotDraft> _submitted = const <ShotDraft>[];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ScriptSplitStrategy get _strategy => _mode == ScriptImportMode.perLine
      ? ScriptSplitStrategy.perLine
      : ScriptSplitStrategy.blankLine;

  /// 每帧现算——粘贴级文本量下拆分是纯字符串处理，没必要缓存出一份会过期的状态。
  List<ShotDraft> get _drafts => splitScript(_ctrl.text, strategy: _strategy);

  DirectorSessionState? _aiState() {
    final String? id = _sessionId;
    if (id == null) return null;
    return ref.watch(directorSessionControllerProvider(id)).valueOrNull;
  }

  DirectorSessionController _ai() =>
      ref.read(directorSessionControllerProvider(_sessionId!).notifier);

  Future<void> _split(String feedback) async {
    final String text = _ctrl.text;
    if (_sessionId == null) {
      final String failMsg = context.l10n.scriptImportFailed;
      final ToastService toast = ref.read(toastServiceProvider);
      setState(() => _busy = true);
      try {
        final String id = await ref.read(directorSessionStarterProvider).start(widget.canvasId);
        if (!mounted) return;
        // 会话控制器 autoDispose：对话框活多久就订阅多久（切回规则拆分也不丢），
        // 否则 read 与下一帧 watch 之间它会被回收重建，在跑的那一轮就落在了旧实例上。
        ref.listenManual(directorSessionControllerProvider(id), (_, _) {});
        setState(() {
          _sessionId = id;
          _busy = false;
        });
        await ref.read(directorSessionControllerProvider(id).future);
      } on InkError catch (_) {
        if (mounted) setState(() => _busy = false);
        toast.show(failMsg, kind: ToastKind.error);
        return;
      }
    }
    if (!mounted) return;
    await _ai().split(text, feedback: feedback);
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final bool ai = _mode == ScriptImportMode.ai;
    final int count = ai ? (_aiState()?.proposal?.shots.length ?? 0) : _drafts.length;
    if (count == 0) return;
    // 文案 / navigator / 通知出口都在 await 前取好：成功要先关对话框再提示，
    // 那之后本 State 的 context 和 ref 已经不能用了。
    final String doneMsg = context.l10n.scriptImportDone(count);
    final String failMsg = context.l10n.scriptImportFailed;
    final ToastService toast = ref.read(toastServiceProvider);
    final NavigatorState navigator = Navigator.of(context);

    setState(() {
      _busy = true;
      if (!ai) _submitted = _drafts;
    });
    try {
      if (ai) {
        await _ai().confirm(origin: widget.origin);
      } else {
        await ref
            .read(scriptImportControllerProvider(widget.canvasId))
            .importDrafts(_submitted, origin: widget.origin);
      }
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
    final bool keyReady = ref.watch(claudeKeyConfiguredProvider).valueOrNull ?? false;
    final bool ai = _mode == ScriptImportMode.ai;
    final DirectorSessionState? aiState = ai ? _aiState() : null;

    // 忙碌中画提交时的那一份：用户在途中改框 / 清空，预览头「N 镜」与按钮的 N 都不跟着变、
    // 不闪回 0；失败复位后回到框里现在的文字。
    final List<ShotDraft> drafts = _busy && !ai ? _submitted : _drafts;
    final int count = ai ? (aiState?.proposal?.shots.length ?? 0) : drafts.length;
    final bool canCreate = !_busy &&
        (ai
            ? aiState != null &&
                aiState.phase == DirectorPhase.proposed &&
                !aiState.isStaleFor(_ctrl.text) &&
                count > 0
            : drafts.isNotEmpty);
    final bool running = aiState?.phase == DirectorPhase.running;

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
              SegmentedButton<ScriptImportMode>(
                segments: <ButtonSegment<ScriptImportMode>>[
                  ButtonSegment<ScriptImportMode>(
                    value: ScriptImportMode.blankLine,
                    label: Text(l.scriptImportStrategyBlankLine),
                  ),
                  ButtonSegment<ScriptImportMode>(
                    value: ScriptImportMode.perLine,
                    label: Text(l.scriptImportStrategyPerLine),
                  ),
                  ButtonSegment<ScriptImportMode>(
                    value: ScriptImportMode.ai,
                    label: Text(l.scriptImportStrategyAi),
                    enabled: keyReady,
                    tooltip: keyReady ? null : l.scriptImportAiNeedsKey,
                  ),
                ],
                selected: <ScriptImportMode>{_mode},
                onSelectionChanged: (_busy || running)
                    ? null
                    : (sel) => setState(() => _mode = sel.first),
              ),
              const SizedBox(height: InkSpacing.md),
              _Label(text: l.scriptImportPreviewLabel),
              const SizedBox(height: InkSpacing.xs),
              if (ai)
                AiStoryboardPanel(
                  state: aiState,
                  script: _ctrl.text,
                  busy: _busy,
                  onSplit: _split,
                  onStop: () => _ai().cancel(),
                  onEdit: (String lang, DirectorSetting setting) =>
                      _ai().edit(contentLanguage: lang, setting: setting),
                )
              else
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
          onPressed: canCreate ? _confirm : null,
          // 写出数量，与预览头「N 镜」同一个 N；0 镜走 ARB 的 =0 分支「创建镜头」。
          // 忙碌中按钮只置灰，N 是提交时记下的那一份（[_submitted]）——框里的文字
          // 这时可能已经被改了，但在提交的不是它。
          child: Text(l.scriptImportConfirm(count)),
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
