// CanvasTopChrome：Canvas 顶栏 —— 复用 InkWindowChrome，三槽位
// leading=Ink/Frame 小 logo，center=breadcrumb，trailing=导出+调色板+⌘K。
// ▶（序列预览占位）与 avatar 已随 CV-1 裁撤（D-7 d5）；⌘K chip 为真实入口（PL-1）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/tokens.dart';
import '../../command_palette/widgets/command_palette_chip.dart';
import '../../export/widgets/export_video_dialog.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_base_style.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/current_canvas_id.dart';
import 'base_style_editor_dialog.dart';

class CanvasTopChrome extends ConsumerWidget implements PreferredSizeWidget {
  const CanvasTopChrome({super.key, required this.canvasName});

  final String canvasName;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWindowChrome(
      leading: _LeadingRow(
        onBack: () {
          ref.read(currentCanvasIdProvider.notifier).state = null;
          // 主动回首页 = 下次启动停留 Studio（fire-and-forget 清会话记录）。
          ref.read(preferencesServiceProvider).update(
                (p) => p.copyWith(clearLastCanvas: true),
              );
        },
      ),
      center: _Breadcrumb(canvasName: canvasName),
      trailing: const _Trailing(),
    );
  }
}

class _LeadingRow extends StatelessWidget {
  const _LeadingRow({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final base = typo.headlineXs.copyWith(color: colors.fg1);
    return Padding(
      padding: const EdgeInsets.only(right: InkSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _BackToStudioButton(onBack: onBack),
          const SizedBox(width: InkSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('Ink', style: base),
              Text('/', style: base.copyWith(color: colors.accent)),
              Text('Frame', style: base),
            ],
          ),
        ],
      ),
    );
  }
}

/// 顶栏左上角"回 Studio"入口：箭头 + 文案 chip，悬停 surface3，可键盘聚焦。
class _BackToStudioButton extends StatefulWidget {
  const _BackToStudioButton({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_BackToStudioButton> createState() => _BackToStudioButtonState();
}

class _BackToStudioButtonState extends State<_BackToStudioButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final label = l.canvasBackToStudio;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onBack();
                return null;
              },
            ),
          },
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBack,
              child: AnimatedContainer(
                duration: InkMotion.fast,
                height: 28,
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: _hover ? colors.surface3 : colors.surface2,
                  borderRadius: BorderRadius.circular(InkRadius.sm),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.arrow_back, size: 14, color: colors.fg2),
                    const SizedBox(width: InkSpacing.xs),
                    Text(
                      label,
                      style: typo.caption.copyWith(color: colors.fg2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.canvasName});
  final String canvasName;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final base = typo.body.copyWith(color: colors.fg2);
    final accent = typo.body.copyWith(color: colors.fg1);
    final chev = typo.body.copyWith(color: colors.fg4);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l.canvasBreadcrumbProject, style: base),
          _chev(chev),
          Text(canvasName, style: base),
          _chev(chev),
          Text(l.canvasBreadcrumbCanvas, style: accent),
        ],
      ),
    );
  }

  Widget _chev(TextStyle s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
        child: Text('›', style: s),
      );
}

class _Trailing extends ConsumerWidget {
  const _Trailing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (canvasId != null) ...<Widget>[
          _ExportVideoButton(canvasId: canvasId),
          const SizedBox(width: InkSpacing.sm),
          _BaseStyleButton(canvasId: canvasId),
          const SizedBox(width: InkSpacing.sm),
        ],
        const CommandPaletteChip(),
      ],
    );
  }
}

/// 「导出视频」入口：画布无可导出的 video result 时禁用。
/// watch 用 select 收窄为可用性布尔，节点全量列表按压时再 read + 过滤，
/// 避免任意节点变化（拖动等）触发顶栏重建。
class _ExportVideoButton extends ConsumerWidget {
  const _ExportVideoButton({required this.canvasId});

  final String canvasId;

  static bool _canExport(AsyncValue<List<CanvasNode>> async) {
    final videoNodes =
        exportableVideoNodes(async.valueOrNull ?? const <CanvasNode>[]);
    return videoNodes.isNotEmpty && videoNodes.first.projectId != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final l = context.l10n;
    final enabled = ref.watch(
      canvasNodesControllerProvider(canvasId).select(_canExport),
    );
    return Tooltip(
      message: enabled ? l.exportVideoTooltip : l.exportVideoDisabledTooltip,
      child: IconButton(
        icon: Icon(
          Icons.movie_outlined,
          size: 18,
          color: enabled ? colors.fg2 : colors.fg4,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        splashRadius: 16,
        onPressed: enabled ? () => _open(context, ref) : null,
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    final videoNodes = exportableVideoNodes(
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[],
    );
    final projectId =
        videoNodes.isEmpty ? null : videoNodes.first.projectId;
    if (projectId == null) return; // 按压瞬间节点已变化：静默不弹
    showExportVideoDialog(
      context,
      projectId: projectId,
      videoNodes: videoNodes,
    );
  }
}

class _BaseStyleButton extends ConsumerWidget {
  const _BaseStyleButton({required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final l = context.l10n;
    return Tooltip(
      message: l.baseStyleEditTooltip,
      child: IconButton(
        icon: Icon(Icons.palette_outlined, size: 18, color: colors.fg2),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        splashRadius: 16,
        onPressed: () => _openEditor(context, ref),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    // 必须 await 真实加载：provider 是 autoDispose，未被 inspector watch 时
    // .valueOrNull 为 null，会用空值预填覆盖已存基底风格（数据丢失）。
    ({String prefix, String suffix}) cur;
    try {
      cur = await ref.read(canvasBaseStyleProvider(canvasId).future);
    } on InkError catch (_) {
      cur = (prefix: '', suffix: '');
    }
    if (!context.mounted) return;
    final r = await showBaseStyleEditorDialog(
      context,
      prefix: cur.prefix,
      suffix: cur.suffix,
    );
    if (!context.mounted) return;
    if (r == null) return;
    try {
      await setBaseStyle(ref, canvasId, prefix: r.prefix, suffix: r.suffix);
    } on InkError catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.baseStyleUpdateFailed)),
      );
    }
  }
}
