// CanvasPromptBar：画布底部悬浮提示词条（Workspace v2 稿；宽度与字号按「提示词条与节点文字」稿）。
//
// 宽度跟着舞台走（util/prompt_bar_width.dart）：舞台宽 × 0.6，夹在 480–880；舞台窄于 512 时
// 取舞台宽减两侧 16。可用宽度从 LayoutBuilder 读——canvas_screen 把条子挂在
// Positioned(left: 0, right: 0, bottom: 16) 下，最大宽度就是舞台宽。水平位置照常居中，居中会压到左下
// 缩放条 / 泳道工具栏时改在右边那段里居中（promptBarPlacement）。
// surface4 @0.96 底 + control 边 + 6px 圆角 + 0 10 30 阴影，两行：
//   行一 11px：6×6 琥珀方点 + 目标节点名 + 供应商 · 片长 · 运镜 | 右：基础风格 [prefix] 已附加
//   行二：提示词正文（prompt 档 13/1.6，最小高 40）+ 字数 + 「生成 ⌘↵」（Windows 显示 Ctrl+Enter）
// 提示词框 1 行起、随内容长到 8 行，再多就在框内滚动。条子底边贴舞台底（bottom 16），
// 内容变多只会往上长。回车 = 换行；⌘↵ / Ctrl+↵ = 生成。
//
// 条子把自己画出来的高度报给 canvasPromptBarHeightProvider（不显示时报 0），「适应全部 / 适应选中」据此在底部
// 让出它（canvas_tool_actions.canvasFitInsets）。
//
// 只在恰好选中一个 image / video config 节点时出现。提示词经 savePromptDebounced 落库，
// ⌘↵ / 按钮走 InspectorSubmitController.submit({'prompt'})。
//
// 「生成」能不能点与检查器的生成按钮同一个判据（util/generate_gate.dart）：提示词非空 + 供应商配了 Key，
// 供应商按检查器同一条链取（节点已存 > 上次使用 > 第一个）；点不动时 tooltip 给检查器同一句原因。
// ⌘↵ 也过这道闸——没配 Key 时按下去什么都不发，而不是发出去再报「生成失败」。节点还没存过供应商时，
// 终稿把判 Key 的那个供应商一并写进去：不然生成路径会落回默认供应商，判的和用的不是同一个。
// 稿上的「≈ 0.42」预估费用：只有 image 供应商有 costModel，且稿未定义视频费用——本条先不画。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/shortcut_labels.dart';
import '../../../core/di/preferences.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/app_preferences.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../core/models/shot_language.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_primitives.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_base_style.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_prompt_bar_height.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/inspector_submit_controller.dart';
import '../util/camera_labels.dart';
import '../util/generate_gate.dart';
import '../util/prompt_bar_width.dart';
import 'base_style_action.dart';
import 'inspector_status_panel.dart';
import 'node_card.dart';

class CanvasPromptBar extends ConsumerWidget {
  const CanvasPromptBar({super.key, required this.canvasId});

  final String canvasId;

  /// 条子本体（带底色 / 边框的那只盒子）的测试锚点：宽度量的是它——外层的对齐壳
  /// 会撑满父级给的宽度，量外层量不出条子多宽。
  static const Key surfaceKey = Key('canvas.promptBar.surface');

  /// 「基础风格」入口的测试锚点。
  static const Key baseStyleKey = Key('canvas.promptBar.baseStyle');

  /// 「生成」按钮的测试锚点。挂在公开类上（而不是私有 `_GenerateButton` 的静态
  /// 常量上）才让可达性用例拿得到它——测试代码引用不到私有类的成员。
  static const Key generateKey = Key('canvas.promptBar.generate');

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _HeightReporter(canvasId: canvasId, child: _bar(ref));

  Widget _bar(WidgetRef ref) {
    final Set<String> selected = ref.watch(canvasSelectionControllerProvider(canvasId));
    if (selected.length != 1) return const SizedBox.shrink();
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
    CanvasNode? node;
    for (final CanvasNode n in nodes) {
      if (n.id == selected.first) node = n;
    }
    if (node == null ||
        node.role != NodeRole.config ||
        (node.type != CanvasNodeType.image && node.type != CanvasNodeType.video)) {
      return const SizedBox.shrink();
    }
    final CanvasNode target = node;
    // 最大可用宽度 = 舞台宽（见头注）。对齐壳自己居中、高度只包内容：父级给紧约束
    // （比如直接塞进定宽盒）也不会把条子撑满，父级多给的高度也不吃。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget body = _PromptBarBody(
          key: ValueKey<String>(target.id),
          canvasId: canvasId,
          node: target,
          width: promptBarPlacement(constraints.maxWidth).width,
        );
        if (!constraints.maxWidth.isFinite) {
          return Align(alignment: Alignment.bottomCenter, heightFactor: 1, child: body);
        }
        return Align(
          alignment: Alignment.bottomLeft,
          heightFactor: 1,
          child: Padding(
            padding: EdgeInsets.only(left: promptBarPlacement(constraints.maxWidth).left),
            child: body,
          ),
        );
      },
    );
  }
}

/// 把 [child] 此刻画出来的高度报给 canvasPromptBarHeightProvider（条子不显示时 child 是 0 高的空盒，报 0）。
class _HeightReporter extends ConsumerStatefulWidget {
  const _HeightReporter({required this.canvasId, required this.child});

  final String canvasId;
  final Widget child;

  @override
  ConsumerState<_HeightReporter> createState() => _HeightReporterState();
}

class _HeightReporterState extends ConsumerState<_HeightReporter> {
  void _report(double height) {
    if (!mounted) return;
    ref.read(canvasPromptBarHeightProvider(widget.canvasId).notifier).report(height);
  }

  @override
  Widget build(BuildContext context) {
    // 订阅着它：provider 是 autoDispose，没人订阅时报进去的值会在帧末被回收，「适应」读到的永远是 0。
    ref.listen<double>(canvasPromptBarHeightProvider(widget.canvasId), (_, _) {});
    return _HeightObserver(onHeight: _report, child: widget.child);
  }
}

/// 排版后高度变了就在帧后回调一次（排版期间不能改 provider）。
class _HeightObserver extends SingleChildRenderObjectWidget {
  const _HeightObserver({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeightObserver(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderHeightObserver renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderHeightObserver extends RenderProxyBox {
  _RenderHeightObserver(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final double height = size.height;
    if (height == _reported) return;
    _reported = height;
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}

class _PromptBarBody extends ConsumerStatefulWidget {
  const _PromptBarBody({
    super.key,
    required this.canvasId,
    required this.node,
    required this.width,
  });
  final String canvasId;
  final CanvasNode node;

  /// 条子本体宽度：[promptBarWidth] 按舞台宽算好传进来。
  final double width;

  @override
  ConsumerState<_PromptBarBody> createState() => _PromptBarBodyState();
}

class _PromptBarBodyState extends ConsumerState<_PromptBarBody> {
  late final TextEditingController _prompt =
      TextEditingController(text: widget.node.promptText ?? '');

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  /// 判 Key / 写进终稿的供应商：与检查器同一条链（util/generate_gate.dart）。
  String? _resolveProviderId(List<ProviderCapabilities> all) {
    final CanvasNode node = widget.node;
    final AppPreferences prefs = ref.read(preferencesServiceProvider).current;
    return resolveConfigProviderId(
      savedProviderId: node.typeConfig['provider_id'] as String?,
      lastUsedProviderId: node.type == CanvasNodeType.video
          ? prefs.lastVideoProviderId
          : prefs.lastImageProviderId,
      candidates: configProviderCandidates(node.type, all),
    );
  }

  /// [providerId] 配没配 Key（检查器同一个缓存 provider）。供应商解析不出来 ⇒ 当作没配。
  bool _hasApiKey(String? providerId, {required bool watch}) {
    if (providerId == null) return false;
    final AsyncValue<bool> v = watch
        ? ref.watch(inspectorHasApiKeyProvider(providerId))
        : ref.read(inspectorHasApiKeyProvider(providerId));
    return v.valueOrNull ?? false;
  }

  void _submit() {
    final String text = _prompt.text.trim();
    final String? providerId = _resolveProviderId(ref.read(providerCapabilitiesListProvider));
    final GenerateBlockReason? block = generateBlockReason(
      promptEmpty: text.isEmpty,
      hasApiKey: _hasApiKey(providerId, watch: false),
    );
    if (block != null) return;
    ref
        .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
        .submit(<String, Object?>{
      'prompt': text,
      // 节点还没存过供应商：把判 Key 的那个写进终稿（见头注）；存过的不动，库里那一份才是检查器最后选的。
      if (widget.node.typeConfig['provider_id'] == null) 'provider_id': providerId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final CanvasNode node = widget.node;
    final String? providerId = node.typeConfig['provider_id'] as String?;
    final String providerName =
        providerId == null ? '' : (ref.watch(providerDisplayNamesProvider)[providerId] ?? providerId);
    final int? durationMs = node.durationMs;
    final CameraMovement? camera = parseCameraMovement(node.cameraName);
    final ShotLanguage lang = node.shotLanguage;
    // 摘要顺序：服务商 · 片长 · 运镜 · 景别 · 焦段（机位角度 / 幅度只在检查器里看）。
    final List<String> summary = <String>[
      if (providerName.isNotEmpty) providerName,
      if (durationMs != null) '${(durationMs / 1000).round()}s',
      if (camera != null) cameraMovementLabel(context, camera),
      if (lang.shotSize != null) shotSizeLabel(context, lang.shotSize!),
      if (lang.focalLengthMm != null) focalLengthLabel(context, lang.focalLengthMm!),
    ];
    final String prefix =
        ref.watch(canvasBaseStyleProvider(widget.canvasId)).valueOrNull?.prefix.trim() ?? '';
    final InspectorSubmitState submitState = ref.watch(inspectorSubmitControllerProvider(node.id));
    final bool busy = submitState is InspectorSubmitSubmitting || submitState is InspectorSubmitRunning;
    final String? gateProviderId = _resolveProviderId(ref.watch(providerCapabilitiesListProvider));
    final GenerateBlockReason? block = generateBlockReason(
      promptEmpty: _prompt.text.trim().isEmpty,
      hasApiKey: _hasApiKey(gateProviderId, watch: true),
    );
    final bool isVideo = node.type == CanvasNodeType.video;
    // 点不动的原因：与检查器同一组文案（图像 / 视频各一组）。
    final String? blockedText = switch (block) {
      GenerateBlockReason.emptyPrompt =>
        isVideo ? l.inspectorVideoGenerateDisabledEmptyPrompt : l.inspectorGenerateDisabledEmptyPrompt,
      GenerateBlockReason.missingApiKey =>
        isVideo ? l.inspectorVideoGenerateDisabledNoKey : l.inspectorGenerateDisabledNoKey,
      null => null,
    };

    return Container(
      key: CanvasPromptBar.surfaceKey,
      width: widget.width,
      padding: const EdgeInsets.fromLTRB(InkSpacing.s14, InkSpacing.s10, InkSpacing.s12, InkSpacing.s10),
      decoration: BoxDecoration(
        color: c.surface4.withValues(alpha: 0.96),
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              InkSquareDot(size: 6, color: c.accent),
              const SizedBox(width: InkSpacing.sm),
              // 名字 + 摘要整组吃掉剩余宽度，基础风格贴右。原来名字是 Flexible、后面跟 Spacer：
              // 两个 flex 1 平分剩余空间，基础风格就被推到条子中间。
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(nodeDisplayName(context, node),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: t.meta.copyWith(color: c.fg2)),
                    ),
                    if (summary.isNotEmpty) ...<Widget>[
                      const SizedBox(width: InkSpacing.sm),
                      Text('·', style: t.meta.copyWith(color: c.fg5)),
                      const SizedBox(width: InkSpacing.sm),
                      Flexible(
                        child: Text(summary.join(' · '),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: t.meta.copyWith(color: c.fg5)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: InkSpacing.sm),
              _BaseStyleChip(canvasId: widget.canvasId, prefix: prefix),
            ],
          ),
          const SizedBox(height: InkSpacing.sm),
          // 提示词占满整条宽度（不再和字数 / 生成挤一行——窄条子上一段话会被折成五六行）；
          // 字数、失败原因、生成按钮放到下面一行（提示词条与节点文字稿）。
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
                const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
              },
              child: TextField(
                controller: _prompt,
                // 1 行起、随内容长到 8 行，再多就在框内滚动；条子底边不动，只往上长。
                // 多行框里回车是换行，生成走上面那两条 ⌘↵ / Ctrl+↵。
                minLines: 1,
                maxLines: 8,
                style: t.prompt.copyWith(color: c.fg1),
                cursorColor: c.accent,
                decoration: InputDecoration.collapsed(
                  hintText: l.inspectorPromptHint,
                  hintStyle: t.prompt.copyWith(color: c.fg6),
                ),
                onChanged: (String v) {
                  setState(() {});
                  ref
                      .read(inspectorSubmitControllerProvider(node.id).notifier)
                      .savePromptDebounced(v);
                },
              ),
            ),
          ),
          const SizedBox(height: InkSpacing.sm),
          Row(
            children: <Widget>[
              if (submitState is InspectorSubmitFailure)
                Expanded(
                  child: Text(
                    inspectorSubmitErrorText(context, submitState.error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.meta.copyWith(color: c.danger),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: InkSpacing.sm),
              Text(l.promptBarChars(_prompt.text.characters.length),
                  style: t.monoSmall.copyWith(color: c.fg6)),
              const SizedBox(width: InkSpacing.sm),
              _GenerateButton(
                enabled: !busy && block == null,
                label: busy ? l.inspectorStatusSubmitting : l.inspectorGenerate,
                // 在途时按钮写着「提交中」，不再挂原因。
                tooltip: busy ? null : blockedText,
                onTap: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }

}

/// 「基础风格：{prefix} 已附加」——点击打开基底风格编辑器；无前缀时只显示标签。
class _BaseStyleChip extends ConsumerWidget {
  const _BaseStyleChip({required this.canvasId, required this.prefix});
  final String canvasId;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    return Semantics(
      button: true,
      label: l.baseStyleEditTooltip,
      child: Tooltip(
        message: l.baseStyleEditTooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: CanvasPromptBar.baseStyleKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => openBaseStyleEditor(context, ref, canvasId),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  prefix.isEmpty ? l.promptBarBaseStyle : '${l.promptBarBaseStyle}：$prefix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.meta.copyWith(color: c.fg5),
                ),
                if (prefix.isNotEmpty) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  Text(l.promptBarAttached, style: t.meta.copyWith(color: c.accent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 画布唯一的生成入口。
///
/// 点击壳走 theme 层的 [InkActivatable]（与标签 chip / InkGhostButton 同一件）：
/// 可 Tab 聚焦、Enter / Space 与鼠标走同一条回调、聚焦画一圈 accent 环。此前是
/// 手搓的 Semantics + MouseRegion + GestureDetector——⌘↵ 之外键盘到不了它
/// （BOARD 214）。
class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.enabled,
    required this.label,
    required this.onTap,
    this.tooltip,
  });
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  /// 点不动时的原因（检查器同一句）；可点时为 null。
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return InkActivatable(
      key: CanvasPromptBar.generateKey,
      semanticLabel: label,
      tooltip: tooltip,
      // 禁用（提示词为空 / 没配 Key / 在途）时给 null 而不是空闭包 ⇒ 连焦点都到不了，
      // 不会出现"聚焦上去按回车什么都不发生"的假可达。
      onTap: enabled ? onTap : null,
      // 子件是 3px 圆角的主按钮；环走前景装饰，不参与布局 ⇒ 不撑宽提示词条。
      focusRingRadius: BorderRadius.circular(InkRadius.s3),
      builder: (BuildContext context, bool hovered, bool focused) => Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkPrimaryButton(
          label,
          height: 28,
          horizontalPadding: InkSpacing.s14,
          bordered: false,
          trailing: Opacity(
            opacity: 0.7,
            child: Text(submitShortcutLabel(), style: t.monoSmall.copyWith(color: c.onAccent)),
          ),
        ),
      ),
    );
  }
}
