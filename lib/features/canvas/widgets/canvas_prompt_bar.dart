// CanvasPromptBar：画布底部悬浮提示词条（Workspace v2 稿）——640 content 宽（+26 内边距 +2 边 = 668），
// surface4 @0.96 底 + control 边 + 6px 圆角 + 0 10 30 阴影，两行：
//   行一 11px：6×6 琥珀方点 + 目标节点名 + 供应商 · 片长 · 运镜 | 右：基础风格 [prefix] 已附加
//   行二：提示词正文（12/1.5，最小高 40）+ 字数 + 「生成 ⌘↵」（Windows 显示 Ctrl+Enter）
//
// 只在恰好选中一个 image / video config 节点时出现。提示词经 savePromptDebounced 落库，
// ⌘↵ / 按钮走 InspectorSubmitController.submit({'prompt'})。
// 稿上的「≈ 0.42」预估费用：只有 image 供应商有 costModel，且稿未定义视频费用——本条先不画。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/shortcut_labels.dart';
import '../../../core/di/providers.dart';
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
import '../providers/canvas_selection_controller.dart';
import '../providers/inspector_submit_controller.dart';
import '../util/camera_labels.dart';
import 'base_style_action.dart';
import 'inspector_status_panel.dart';
import 'node_card.dart';

class CanvasPromptBar extends ConsumerWidget {
  const CanvasPromptBar({super.key, required this.canvasId});

  final String canvasId;

  /// content 640 + padding 14+12 + border 2。
  static const double width = 668;

  /// 「基础风格」入口的测试锚点。
  static const Key baseStyleKey = Key('canvas.promptBar.baseStyle');

  /// 「生成」按钮的测试锚点。挂在公开类上（而不是私有 `_GenerateButton` 的静态
  /// 常量上）才让可达性用例拿得到它——测试代码引用不到私有类的成员。
  static const Key generateKey = Key('canvas.promptBar.generate');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return _PromptBarBody(key: ValueKey<String>(node.id), canvasId: canvasId, node: node);
  }
}

class _PromptBarBody extends ConsumerStatefulWidget {
  const _PromptBarBody({super.key, required this.canvasId, required this.node});
  final String canvasId;
  final CanvasNode node;

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

  void _submit() {
    final String text = _prompt.text.trim();
    if (text.isEmpty) return;
    ref
        .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
        .submit(<String, Object?>{'prompt': text});
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

    return Container(
      width: CanvasPromptBar.width,
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
              const Spacer(),
              _BaseStyleChip(canvasId: widget.canvasId, prefix: prefix),
            ],
          ),
          const SizedBox(height: InkSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
                      const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
                    },
                    child: TextField(
                      controller: _prompt,
                      minLines: 1,
                      maxLines: 4,
                      style: t.body.copyWith(color: c.fg1, height: 1.5),
                      cursorColor: c.accent,
                      decoration: InputDecoration.collapsed(
                        hintText: l.inspectorPromptHint,
                        hintStyle: t.body.copyWith(color: c.fg6, height: 1.5),
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
              ),
              const SizedBox(width: InkSpacing.s10),
              Row(
                children: <Widget>[
                  Text(l.promptBarChars(_prompt.text.characters.length),
                      style: t.monoSmall.copyWith(color: c.fg6)),
                  const SizedBox(width: InkSpacing.sm),
                  if (submitState is InspectorSubmitFailure)
                    Padding(
                      padding: const EdgeInsets.only(right: InkSpacing.sm),
                      child: Text(
                        inspectorSubmitErrorText(context, submitState.error),
                        style: t.meta.copyWith(color: c.danger),
                      ),
                    ),
                  _GenerateButton(
                    enabled: !busy && _prompt.text.trim().isNotEmpty,
                    label: busy ? l.inspectorStatusSubmitting : l.inspectorGenerate,
                    onTap: _submit,
                  ),
                ],
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
  const _GenerateButton({required this.enabled, required this.label, required this.onTap});
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return InkActivatable(
      key: CanvasPromptBar.generateKey,
      semanticLabel: label,
      // 禁用（提示词为空 / 在途）时给 null 而不是空闭包 ⇒ 连焦点都到不了，
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
