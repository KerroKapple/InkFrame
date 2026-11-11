// 剧本导入对话框里「AI 拆分」那一格的预览区：开始 / 拆分中（可停）/ 失败重试 /
// 提案（识别出的语言与设定可改、每镜一行、过期提示、驳回意见 + 重新拆分、本次用量）。
//
// 只管呈现与收集输入：状态来自 DirectorSessionState，动作经回调交给对话框转给
// DirectorSessionController——本文件不读写仓储、不调模型。
import 'package:flutter/material.dart';

import '../../../core/models/director.dart';
import '../../../l10n/duration_format.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../../canvas/util/camera_labels.dart';
import '../../generation/services/cost_estimator.dart';
import '../providers/director_session_state.dart';
import '../steps/storyboard/storyboard_proposal.dart';

/// 测试锚点。
abstract final class AiStoryboardPanelKeys {
  static const Key start = ValueKey<String>('aiStoryboard.start');
  static const Key stop = ValueKey<String>('aiStoryboard.stop');
  static const Key retry = ValueKey<String>('aiStoryboard.retry');
  static const Key resplit = ValueKey<String>('aiStoryboard.resplit');
  static const Key feedback = ValueKey<String>('aiStoryboard.feedback');
  static const Key language = ValueKey<String>('aiStoryboard.language');
  static const Key era = ValueKey<String>('aiStoryboard.era');
  static const Key region = ValueKey<String>('aiStoryboard.region');
  static const Key culture = ValueKey<String>('aiStoryboard.culture');
  static const Key artStyle = ValueKey<String>('aiStoryboard.artStyle');
  static const Key stale = ValueKey<String>('aiStoryboard.stale');
  static const Key usage = ValueKey<String>('aiStoryboard.usage');
}

class AiStoryboardPanel extends StatefulWidget {
  const AiStoryboardPanel({
    super.key,
    required this.state,
    required this.script,
    required this.busy,
    required this.onSplit,
    required this.onStop,
    required this.onEdit,
  });

  /// null = 还没开会话（还没点过「开始拆分」）。
  final DirectorSessionState? state;

  /// 框里现在的剧本。
  final String script;

  /// 正在建会话 / 正在落画布：按钮都置灰。
  final bool busy;

  /// 拆（或重拆），带驳回意见（可空）。
  final ValueChanged<String> onSplit;
  final VoidCallback onStop;
  final void Function(String contentLanguage, DirectorSetting setting) onEdit;

  @override
  State<AiStoryboardPanel> createState() => _AiStoryboardPanelState();
}

class _AiStoryboardPanelState extends State<AiStoryboardPanel> {
  final TextEditingController _feedback = TextEditingController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  bool get _hasScript => widget.script.trim().isNotEmpty;

  void _split() {
    final String note = _feedback.text;
    _feedback.clear();
    widget.onSplit(note);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final DirectorSessionState? s = widget.state;
    final DirectorPhase phase = s?.phase ?? DirectorPhase.idle;
    final bool canSplit = _hasScript && !widget.busy;
    return switch (phase) {
      DirectorPhase.running => _Box(children: <Widget>[
          const LinearProgressIndicator(),
          const SizedBox(height: InkSpacing.sm),
          _Meta(text: l.scriptImportAiRunning),
          const SizedBox(height: InkSpacing.sm),
          TextButton(
            key: AiStoryboardPanelKeys.stop,
            onPressed: widget.onStop,
            child: Text(l.scriptImportAiStop),
          ),
        ]),
      DirectorPhase.failed => _Box(children: <Widget>[
          _Meta(
            text: l.scriptImportAiFailed(l10nErrorCode(context, s!.errorCode!)),
            error: true,
          ),
          const SizedBox(height: InkSpacing.sm),
          TextButton(
            key: AiStoryboardPanelKeys.retry,
            onPressed: canSplit ? () => widget.onSplit('') : null,
            child: Text(l.scriptImportAiRetry),
          ),
          if (s.log.events.isNotEmpty) _Usage(state: s),
        ]),
      DirectorPhase.proposed => _proposed(context, s!, canSplit),
      DirectorPhase.idle || DirectorPhase.applied => _Box(children: <Widget>[
          _Meta(text: l.scriptImportAiIntro),
          const SizedBox(height: InkSpacing.sm),
          FilledButton.tonal(
            key: AiStoryboardPanelKeys.start,
            onPressed: canSplit ? () => widget.onSplit('') : null,
            child: Text(l.scriptImportAiStart),
          ),
          if (s != null && s.log.events.isNotEmpty) _Usage(state: s),
        ]),
    };
  }

  Widget _proposed(BuildContext context, DirectorSessionState s, bool canSplit) {
    final l = context.l10n;
    final StoryboardProposal p = s.proposal!;
    final bool stale = s.isStaleFor(widget.script);
    void edit({String? lang, String? era, String? region, String? culture, String? artStyle}) =>
        widget.onEdit(
          lang ?? p.contentLanguage,
          p.setting.copyWith(era: era, region: region, culture: culture, artStyle: artStyle),
        );
    // 按提案 seq 换 key：重拆后各框回到新提案的值。
    final String k = '${s.proposalSeq}';
    return _Box(children: <Widget>[
      if (stale) ...<Widget>[
        _Meta(key: AiStoryboardPanelKeys.stale, text: l.scriptImportAiStale, error: true),
        const SizedBox(height: InkSpacing.sm),
      ],
      _Meta(text: l.scriptImportAiSettingLabel),
      const SizedBox(height: InkSpacing.xs),
      Wrap(
        spacing: InkSpacing.sm,
        runSpacing: InkSpacing.sm,
        children: <Widget>[
          _CommitField(
            key: ValueKey<String>('lang$k'),
            fieldKey: AiStoryboardPanelKeys.language,
            label: l.scriptImportAiLanguage,
            value: p.contentLanguage,
            onCommit: (String v) => edit(lang: v),
          ),
          _CommitField(
            key: ValueKey<String>('era$k'),
            fieldKey: AiStoryboardPanelKeys.era,
            label: l.scriptImportAiEra,
            value: p.setting.era,
            onCommit: (String v) => edit(era: v),
          ),
          _CommitField(
            key: ValueKey<String>('region$k'),
            fieldKey: AiStoryboardPanelKeys.region,
            label: l.scriptImportAiRegion,
            value: p.setting.region,
            onCommit: (String v) => edit(region: v),
          ),
          _CommitField(
            key: ValueKey<String>('culture$k'),
            fieldKey: AiStoryboardPanelKeys.culture,
            label: l.scriptImportAiCulture,
            value: p.setting.culture,
            onCommit: (String v) => edit(culture: v),
          ),
          _CommitField(
            key: ValueKey<String>('art$k'),
            fieldKey: AiStoryboardPanelKeys.artStyle,
            label: l.scriptImportAiArtStyle,
            value: p.setting.artStyle,
            onCommit: (String v) => edit(artStyle: v),
          ),
        ],
      ),
      const SizedBox(height: InkSpacing.sm),
      _Meta(text: l.scriptImportShotCount(p.shots.length)),
      const SizedBox(height: InkSpacing.xs),
      for (int i = 0; i < p.shots.length; i++) _ShotRow(index: i, shot: p.shots[i]),
      const SizedBox(height: InkSpacing.sm),
      InkInput(
        key: AiStoryboardPanelKeys.feedback,
        controller: _feedback,
        hintText: l.scriptImportAiFeedbackHint,
      ),
      const SizedBox(height: InkSpacing.xs),
      Row(
        children: <Widget>[
          TextButton(
            key: AiStoryboardPanelKeys.resplit,
            onPressed: canSplit ? _split : null,
            child: Text(l.scriptImportAiResplit),
          ),
          const Spacer(),
          _Usage(state: s),
        ],
      ),
    ]);
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(InkSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: context.inkTypography.meta.copyWith(
          color: error ? context.inkColors.danger : context.inkColors.fg2,
        ),
      );
}

class _ShotRow extends StatelessWidget {
  const _ShotRow({required this.index, required this.shot});

  final int index;
  final StoryboardShot shot;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = <String>[
      shot.label,
      if (shot.shotSize case final size?) shotSizeLabel(context, size),
      if (shot.camera case final camera?) cameraMovementLabel(context, camera),
      formatDurationLabel(context.l10n, shot.durationMs),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.xs),
      child: Text(
        '${index + 1}. ${parts.join(' · ')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.inkTypography.body.copyWith(color: context.inkColors.fg2),
      ),
    );
  }
}

class _Usage extends StatelessWidget {
  const _Usage({required this.state});

  final DirectorSessionState state;

  @override
  Widget build(BuildContext context) {
    final ledger = state.ledger;
    final u = ledger.totalUsage;
    final int tokens = u.inputTokens +
        u.outputTokens +
        u.cacheCreationInputTokens +
        u.cacheReadInputTokens;
    return Text(
      context.l10n.scriptImportAiUsage(tokens, formatCostUsd(ledger.totalCostUsd)),
      key: AiStoryboardPanelKeys.usage,
      style: context.inkTypography.meta.copyWith(color: context.inkColors.fg3),
    );
  }
}

/// 失焦（或回车）才提交的小输入框——改一个字不记一件事件。
class _CommitField extends StatefulWidget {
  const _CommitField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onCommit,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final ValueChanged<String> onCommit;

  @override
  State<_CommitField> createState() => _CommitFieldState();
}

class _CommitFieldState extends State<_CommitField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus && _ctrl.text.trim() != widget.value) {
      widget.onCommit(_ctrl.text.trim());
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: InkSpacing.xxl * 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.label,
              style: context.inkTypography.meta.copyWith(color: context.inkColors.fg3),
            ),
            InkInput(key: widget.fieldKey, controller: _ctrl, focusNode: _focus),
          ],
        ),
      );
}
