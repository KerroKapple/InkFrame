// CanvasZoomBar：舞台左下的浮动缩放条（缩小 / % / 放大 / 适应），绑定 canvasTransformController。
//
// 原来和画布头（CanvasHeaderBar）住在同一个文件。PR-6 页签去重把画布头整条删了（画布名在面包屑里，
// 泳道名写在泳道上，缩放比例就在这条上），缩放条搬到自己的文件，内容不变。
//
// 缩小 / 放大画图标集 v1 的 zoomOut / zoomIn（原来是「−」「+」两个字符）；四格都走
// InkActivatable——Tab 可达、Enter / Space 激活，图标格的名字由 semanticLabel + tooltip 说出。
//
// 「适应」= 适应全部（PR-8b）：把画布上所有卡片框进视口（只缩小、不放大），与 Shift+1、空白处右键菜单
// 「适应视图」同一个动作（canvas_tool_actions.dart 的 fitAllNodes）。原来它只是把相机复位——复位留给 ⌘0。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../providers/canvas_transform_controller.dart';
import '../util/canvas_tool_actions.dart';
import '../util/canvas_zoom.dart';

class CanvasZoomBar extends ConsumerWidget {
  const CanvasZoomBar({super.key, required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final TransformationController transform = ref.watch(canvasTransformControllerProvider(canvasId));

    void zoom(double factor) {
      transform.value = zoomedTransform(
        current: transform.value,
        factor: factor,
        viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ZoomCell(width: 27, label: l.canvasZoomOut, onTap: () => zoom(1 / kCanvasZoomStep), borderRight: true,
              child: InkIcon(InkGlyph.zoomOut, size: InkIconSize.sm, color: c.fg3)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
            child: ValueListenableBuilder<Matrix4>(
              valueListenable: transform,
              builder: (BuildContext context, Matrix4 m, _) =>
                  Text('${(scaleOf(m) * 100).round()}%', style: t.mono.copyWith(color: c.fg3)),
            ),
          ),
          _ZoomCell(width: 27, label: l.canvasZoomIn, onTap: () => zoom(kCanvasZoomStep), borderLeft: true,
              child: InkIcon(InkGlyph.zoomIn, size: InkIconSize.sm, color: c.fg3)),
          // 「适应」格本身有字，读屏读这行字即可，不再另给标签（否则会念两遍）。
          _ZoomCell(width: 41, onTap: () => fitAllNodes(ref, canvasId: canvasId), borderLeft: true,
              child: Text(l.canvasZoomFit, style: t.meta.copyWith(color: c.fg3))),
        ],
      ),
    );
  }
}

class _ZoomCell extends StatelessWidget {
  const _ZoomCell({
    required this.width,
    required this.onTap,
    required this.child,
    this.label,
    this.borderLeft = false,
    this.borderRight = false,
  });
  final double width;
  final VoidCallback onTap;
  final Widget child;

  /// 只有图标的格必须给：图标对读屏透明，不给就是一颗没有名字的按钮。
  /// 同一句也当 tooltip——光看图标认不出时，悬停能看到字。
  final String? label;
  final bool borderLeft;
  final bool borderRight;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return InkActivatable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        width: width,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            left: borderLeft ? BorderSide(color: c.control) : BorderSide.none,
            right: borderRight ? BorderSide(color: c.control) : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }
}
