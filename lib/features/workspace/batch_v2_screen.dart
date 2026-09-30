// 批量结果 + 角色静态复刻页（B 路径，Batch and Characters 稿）。
//
// 稿是一张规格书长图，四个 UI 块散落其上。本屏把四块摆在【稿上的绝对坐标】，
// 好让参考图与复刻图用同一组 (x,y,w,h) 裁剪比对：
//   01 检查器内联 · 批量结果 (48,211) 302×406
//   02 对比浮层            (374,210) 1082×321
//   03b 角色库             (374,696) 262×310
//   03c 编辑角色框          (660,695) 562×542
// 稿的 03a「检查器 · 角色区」是【现状】展板（CharactersSection 已实现），不复刻。
//
// 尺寸全部按稿的 CSS content-box 折算（盒 = content + border）。slot 的描边在稿上是
// outline + offset −1（画在盒内、不占布局），所以一律用 foregroundDecoration，
// 不能用 Container(border:)——那会把图缩小。
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/components/ws_primitives.dart';
import '../../theme/tokens.dart';
import 'models/batch_fixture.dart';

class BatchV2Screen extends StatelessWidget {
  const BatchV2Screen({super.key});

  static const Size designSize = BatchFixture.designSize;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return DefaultTextStyle(
      style: context.inkTypography.body.copyWith(color: c.fg2),
      child: Container(
        width: designSize.width,
        height: designSize.height,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: c.surface0),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: BatchFixture.inspectorAt.dx,
              top: BatchFixture.inspectorAt.dy,
              child: const _InspectorBlock(),
            ),
            Positioned(
              left: BatchFixture.overlayAt.dx,
              top: BatchFixture.overlayAt.dy,
              child: const _CompareOverlay(),
            ),
            Positioned(
              left: BatchFixture.libraryAt.dx,
              top: BatchFixture.libraryAt.dy,
              child: const _LibraryPanel(),
            ),
            Positioned(
              left: BatchFixture.editorAt.dx,
              top: BatchFixture.editorAt.dy,
              child: const _EditorDialog(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ 共用：缩略图

/// slot / 参考图的缩略底：成功走 thumbPlaceholderGradients，失败与生成中走纯 thumbFill。
/// [ring] 是稿的 outline（offset −1 ⇒ 画在盒内），用 foregroundDecoration 保证不占布局。
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.radius,
    this.gradient,
    this.ringColor,
    this.ringWidth = 1,
    this.child,
  });

  final double radius;
  final int? gradient;
  final Color? ringColor;
  final double ringWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final (Color, Color)? g = gradient == null
        ? null
        : InkPalette.thumbPlaceholderGradients[gradient! % InkPalette.thumbPlaceholderGradients.length];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: g == null ? c.thumbFill : null,
        // 稿 160deg ≈ 上→下偏右；仓库既有复刻屏一律 topLeft→bottomRight。
        gradient: g == null
            ? null
            : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[g.$1, g.$2]),
        borderRadius: BorderRadius.circular(radius),
      ),
      foregroundDecoration: ringColor == null
          ? null
          : BoxDecoration(
              border: Border.all(color: ringColor!, width: ringWidth),
              borderRadius: BorderRadius.circular(radius),
            ),
      child: child,
    );
  }
}

/// 虚线框（Chromium dashed ≈ dash 3 / gap 3）。InkDashedSlot 的边色写死 outline，
/// 稿这两处要 controlStrong，所以本屏自带一个painter。
class _DashedRect extends StatelessWidget {
  const _DashedRect({required this.color, required this.radius, required this.child});
  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashedRectPainter(color, radius), child: child);
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ).deflate(0.5));
    const double dash = 3;
    const double gap = 3;
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash > m.length ? m.length : d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color || old.radius != radius;
}

// ============================================================ 01 检查器内联

class _InspectorBlock extends StatelessWidget {
  const _InspectorBlock();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: BatchFixture.inspectorSize.width,
      height: BatchFixture.inspectorSize.height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: c.surface3, border: Border.all(color: c.borderStrong)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WsPanelTabs(tabs: BatchFixture.inspectorTabs, active: BatchFixture.inspectorActiveTab),
          // 节点头：padding 12 + 1px 下沿；方点 8×8 圆角 1 + gap 10 + 两行。
          Container(
            padding: const EdgeInsets.all(InkSpacing.s12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: InkSpacing.s3),
                  child: WsSquareDot(size: 8, color: c.accent),
                ),
                const SizedBox(width: InkSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(BatchFixture.nodeTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                      const SizedBox(height: InkSpacing.s2),
                      Text(BatchFixture.nodeSubtitle, style: t.meta.copyWith(color: c.fg5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(InkSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(BatchFixture.gridTitle, style: t.body.copyWith(color: c.fg4)),
                      const SizedBox(width: InkSpacing.sm),
                      Text(BatchFixture.gridCount, style: t.monoSmall.copyWith(color: c.fg6)),
                      const Spacer(),
                      Text(BatchFixture.gridCompare, style: t.meta.copyWith(color: c.accent)),
                    ],
                  ),
                  const SizedBox(height: InkSpacing.sm),
                  // 稿：grid 1fr 1fr / gap 6 —— 内容宽 276 ⇒ 列宽 135。
                  for (int row = 0; row < 2; row++) ...<Widget>[
                    if (row > 0) const SizedBox(height: InkSpacing.s6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: _InspectorSlot(slot: BatchFixture.slots[row * 2])),
                        const SizedBox(width: InkSpacing.s6),
                        Expanded(child: _InspectorSlot(slot: BatchFixture.slots[row * 2 + 1])),
                      ],
                    ),
                  ],
                  const SizedBox(height: InkSpacing.s12),
                  const Row(
                    children: <Widget>[
                      Expanded(child: WsSecondaryButton(BatchFixture.btnRerunFailed)),
                      SizedBox(width: InkSpacing.sm),
                      Expanded(child: WsSecondaryButton(BatchFixture.btnDeriveAll)),
                    ],
                  ),
                  const SizedBox(height: InkSpacing.sm),
                  // 用 Expanded 吃掉余量：内容自然高与面板 408 之间有不到 1px 的舍入差，
                  // 不吃掉就会溢出被 clip（面板是 hardEdge），按钮与脚注会整条不见。
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        BatchFixture.inspectorFootnote,
                        style: t.micro.copyWith(color: c.fg6, height: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 检查器格：图区 135×75.94（16:9）+ gap 4 + 元信息行（9px mono）。
class _InspectorSlot extends StatelessWidget {
  const _InspectorSlot({required this.slot});
  final BcSlot slot;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final bool promoted = slot.state == BcSlotState.promoted;
    final (String, Color) action = switch (slot.state) {
      BcSlotState.promoted => (BatchFixture.actionCurrent, c.accent),
      BcSlotState.success => (BatchFixture.actionPromote, c.fg4),
      BcSlotState.error => (BatchFixture.actionRerun, c.danger),
      BcSlotState.generating => (BatchFixture.actionCancel, c.fg4),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _Thumb(
            radius: InkRadius.s3,
            gradient: slot.gradient,
            ringColor: promoted ? c.accent : c.outline,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: InkSpacing.xs,
                  top: InkSpacing.s3,
                  child: Text('#${slot.index}',
                      style: t.monoNano.copyWith(color: c.fg1.withValues(alpha: 0.8))),
                ),
                if (promoted)
                  Positioned(
                    right: InkSpacing.xs,
                    top: InkSpacing.s3,
                    // 稿 padding 1px 5px：竖向 1px 不设档，用固定高 14 的盒子等效。
                    child: Container(
                      height: 14,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s5),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(InkRadius.xs),
                      ),
                      child: Text(BatchFixture.badgeChosen, style: t.nano.copyWith(color: c.onAccent)),
                    ),
                  ),
                if (slot.state == BcSlotState.generating)
                  Positioned.fill(
                    child: Center(
                      child: Text(BatchFixture.overlayGenerating, style: t.micro.copyWith(color: c.fg6)),
                    ),
                  ),
                if (slot.state == BcSlotState.error)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text('✕', style: t.meta.copyWith(color: c.danger)),
                          const SizedBox(height: InkSpacing.s3),
                          Text(
                            BatchFixture.overlayBlocked,
                            textAlign: TextAlign.center,
                            style: t.nano.copyWith(color: c.danger, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.xs),
        // 稿的元信息行实测 13 高（9px mono 的行盒），钉死它——不钉的话两行网格会整体上移，
        // 底下的按钮行与脚注跟着错位。
        SizedBox(
          height: 13,
          child: Row(
            children: <Widget>[
              Text(slot.seed, style: t.monoNano.copyWith(color: c.fg6)),
              const Spacer(),
              Text(action.$1, style: t.monoNano.copyWith(color: action.$2)),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================ 02 对比浮层

class _CompareOverlay extends StatelessWidget {
  const _CompareOverlay();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: BatchFixture.overlaySize.width,
      height: BatchFixture.overlaySize.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.overlay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 头：38 content + 1px 下沿。
          Container(
            height: 39,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(bottom: BorderSide(color: c.borderStrong)),
            ),
            child: Row(
              children: <Widget>[
                Text(BatchFixture.overlayTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s12),
                Text(BatchFixture.overlayMeta, style: t.mono.copyWith(color: c.fg5)),
                const Spacer(),
                // 稿上这两格没有分段控件的壳，只有两个裸文字，靠 gap 12 隔开。
                Text(BatchFixture.overlayModeSideBySide, style: t.body.copyWith(color: c.fg5)),
                const SizedBox(width: InkSpacing.s12),
                Text(BatchFixture.overlayModeStacked, style: t.body.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s12),
                Text(BatchFixture.overlayEsc, style: t.monoSmall.copyWith(color: c.fg6)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(InkSpacing.s14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < BatchFixture.slots.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: InkSpacing.s12),
                    Expanded(child: _OverlaySlot(slot: BatchFixture.slots[i])),
                  ],
                ],
              ),
            ),
          ),
          // 脚：1px 上沿 + padding 12/14 + 行高 28。
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14, vertical: InkSpacing.s12),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(top: BorderSide(color: c.borderStrong)),
            ),
            child: Row(
              children: <Widget>[
                Text(BatchFixture.overlayHint, style: t.meta.copyWith(color: c.fg6)),
                const Spacer(),
                const WsSecondaryButton(BatchFixture.btnSaveAllToGallery, height: 26),
                const SizedBox(width: InkSpacing.s10),
                const WsPrimaryButton(
                  BatchFixture.btnDone,
                  height: 26,
                  horizontalPadding: InkSpacing.s14,
                  bordered: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 浮层格：图区 254×142.875（16:9）+ gap 8 + 种子行 + gap 4 + 按钮行。
class _OverlaySlot extends StatelessWidget {
  const _OverlaySlot({required this.slot});
  final BcSlot slot;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final bool promoted = slot.state == BcSlotState.promoted;
    final bool generating = slot.state == BcSlotState.generating;
    final String mainLabel = switch (slot.state) {
      BcSlotState.promoted => BatchFixture.badgeCurrentArtifact,
      BcSlotState.success => BatchFixture.btnSetArtifact,
      BcSlotState.error => BatchFixture.btnRerunSlot,
      BcSlotState.generating => BatchFixture.actionCancel,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _Thumb(
            radius: InkRadius.sm,
            gradient: slot.gradient,
            ringColor: promoted ? c.accent : c.outline,
            // 稿 2px + offset −1 ⇒ 1px 在盒外；Flutter 前景描边只能在盒内，≤1px 近似。
            ringWidth: promoted ? 2 : 1,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: InkSpacing.sm,
                  top: InkSpacing.s6,
                  child: Text('${BatchFixture.slotPrefix}#${slot.index}',
                      style: t.monoSmall.copyWith(color: c.fg1.withValues(alpha: 0.85))),
                ),
                if (promoted)
                  Positioned(
                    right: InkSpacing.sm,
                    top: InkSpacing.s6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s7, vertical: InkSpacing.s2),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(InkRadius.xs),
                      ),
                      child: Text(BatchFixture.badgeCurrentArtifact, style: t.micro.copyWith(color: c.onAccent)),
                    ),
                  ),
                if (generating)
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 60,
                          height: 3,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: c.control,
                                    borderRadius: BorderRadius.circular(InkRadius.xs),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: 60 * BatchFixture.overlayProgress,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: c.accent,
                                    borderRadius: BorderRadius.circular(InkRadius.xs),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: InkSpacing.s6),
                        Text(BatchFixture.overlayGeneratingPct, style: t.meta.copyWith(color: c.fg5)),
                      ],
                    ),
                  ),
                if (slot.state == BcSlotState.error)
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // 稿是 16px；排版档没有 16，取 sectionTitle(15) + 400 字重，≤1px 近似。
                        Text('✕', style: t.sectionTitle.copyWith(color: c.danger, fontWeight: FontWeight.w400)),
                        const SizedBox(height: InkSpacing.s6),
                        Text(BatchFixture.overlayBlocked, style: t.meta.copyWith(color: c.danger)),
                        const SizedBox(height: InkSpacing.s6),
                        // 稿这行是 sans 不是 mono（不是 errorCode 就反射性上等宽）。
                        Text(BatchFixture.errorCode, style: t.micro.copyWith(color: c.fg6)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(BatchFixture.seedLabel, style: t.meta.copyWith(color: c.fg4)),
            const SizedBox(width: InkSpacing.sm),
            Text(slot.seed, style: t.mono.copyWith(color: c.fg2)),
          ],
        ),
        const SizedBox(height: InkSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: promoted
                  ? Container(
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.accentWash,
                        border: Border.all(color: c.accent),
                        borderRadius: BorderRadius.circular(InkRadius.s3),
                      ),
                      // 稿这格的字是一档暖白，色板里没有；取 fg1（只差蓝通道 8，低于比对容差 24）。
                      child: Text(mainLabel, style: t.bodyStrong.copyWith(color: c.fg1)),
                    )
                  : WsSecondaryButton(mainLabel, height: 26),
            ),
            const SizedBox(width: InkSpacing.s6),
            Container(
              width: 32,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: generating ? c.outline : c.controlStrong),
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              child: Text(
                BatchFixture.btnRerunSeedGlyph,
                // 置灰前景稿上是 #4A4A4A，前景槽位里没有这档；overlayBorder 恰为该值，借槽。
                style: t.body.copyWith(color: generating ? c.overlayBorder : c.fg4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================ 03b 角色库

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: BatchFixture.librarySize.width,
      height: BatchFixture.librarySize.height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: c.surface3, border: Border.all(color: c.borderStrong)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WsPanelTabs(
            tabs: BatchFixture.libraryTabs,
            active: BatchFixture.libraryActiveTab,
            trailing: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
              child: Text(BatchFixture.libraryTabsTrailing, style: t.micro.copyWith(color: c.accent)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.s10, InkSpacing.sm, InkSpacing.s10, InkSpacing.xs),
            child: Text(BatchFixture.libraryHint, style: t.micro.copyWith(color: c.fg6, height: 1.5)),
          ),
          for (final BcCharacter ch in BatchFixture.characters) _LibraryRow(character: ch),
          Padding(
            padding: const EdgeInsets.all(InkSpacing.s10),
            child: _DashedRect(
              color: c.controlStrong,
              radius: InkRadius.s3,
              child: SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('+', style: t.body.copyWith(color: c.fg5)),
                    const SizedBox(width: InkSpacing.s6),
                    Text(BatchFixture.libraryNewCharacter, style: t.meta.copyWith(color: c.fg5)),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.s10, 0, InkSpacing.s10, InkSpacing.s10),
            child: Text(BatchFixture.libraryFootnote, style: t.micro.copyWith(color: c.fg6, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// 稿：行 8/10 内边距 + 36 缩略 + 1px 下沿 = 53 高；缩略↔文字↔⋯ 两处 gap 9。
class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.character});
  final BcCharacter character;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10, vertical: InkSpacing.sm),
      decoration: BoxDecoration(
        color: character.selected ? c.surface5 : null,
        border: Border(bottom: BorderSide(color: c.surface1)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 36,
            height: 36,
            child: _Thumb(radius: InkRadius.s3, gradient: character.gradient, ringColor: c.outline),
          ),
          const SizedBox(width: InkSpacing.s9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  character.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.copyWith(color: character.selected ? c.fg1 : c.fg3),
                ),
                const SizedBox(height: InkSpacing.s2),
                Text(
                  character.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.micro.copyWith(color: c.fg5),
                ),
              ],
            ),
          ),
          const SizedBox(width: InkSpacing.s9),
          Text(BatchFixture.libraryMenuGlyph, style: t.meta.copyWith(color: c.fg6)),
        ],
      ),
    );
  }
}

// ============================================================ 03c 编辑角色框

class _EditorDialog extends StatelessWidget {
  const _EditorDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: BatchFixture.editorSize.width,
      height: BatchFixture.editorSize.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.overlay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 标题栏 38 content + 1px 下沿。标题是 12/500（不是 dialogTitle 的 17）。
          Container(
            height: 39,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(bottom: BorderSide(color: c.borderStrong)),
            ),
            child: Row(
              children: <Widget>[
                Text(BatchFixture.editorTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s10),
                Text(BatchFixture.editorBadge, style: t.micro.copyWith(color: c.accent)),
                const Spacer(),
                Text(BatchFixture.editorClose, style: t.body.copyWith(color: c.fg5)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14, vertical: InkSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _EditorLabel(BatchFixture.fieldName),
                  const SizedBox(height: InkSpacing.s6),
                  // 名称字段 24 content + 1px 底线；值后跟一根 1×13 琥珀假光标。
                  Container(
                    height: 25,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
                    child: Row(
                      children: <Widget>[
                        Text(BatchFixture.fieldNameValue, style: t.body.copyWith(color: c.fg1)),
                        const SizedBox(width: InkSpacing.s2),
                        Container(width: 1, height: 13, color: c.accent),
                      ],
                    ),
                  ),
                  const SizedBox(height: InkSpacing.md),
                  const _EditorLabel(BatchFixture.fieldDescription),
                  const SizedBox(height: InkSpacing.s6),
                  // 稿：min-height 48（content）+ padding 6×2 + 1px 底线 = 实高 61。
                  // Container 的 constraints 作用在【含 padding 的整盒】上，所以这里写 61 不是 48。
                  Container(
                    constraints: const BoxConstraints(minHeight: 61),
                    padding: const EdgeInsets.symmetric(vertical: InkSpacing.s6),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.control))),
                    child: Text(
                      BatchFixture.fieldDescriptionValue,
                      style: t.body.copyWith(color: c.fg2, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: InkSpacing.s6),
                  Text(BatchFixture.descriptionHint, style: t.micro.copyWith(color: c.fg6, height: 1.5)),
                  const SizedBox(height: InkSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      const _EditorLabel(BatchFixture.fieldReferences),
                      const SizedBox(width: InkSpacing.sm),
                      Text(BatchFixture.referencesHint, style: t.micro.copyWith(color: c.fg6)),
                      const Spacer(),
                      Text(BatchFixture.referencesCount, style: t.monoSmall.copyWith(color: c.fg6)),
                    ],
                  ),
                  const SizedBox(height: InkSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final BcReference r in BatchFixture.references) ...<Widget>[
                        _ReferenceTile(reference: r),
                        const SizedBox(width: InkSpacing.sm),
                      ],
                      _DashedRect(
                        color: c.controlStrong,
                        radius: InkRadius.sm,
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text('+', style: t.body.copyWith(color: c.fg6)),
                              const SizedBox(height: InkSpacing.xs),
                              Text(BatchFixture.referencesAdd, style: t.micro.copyWith(color: c.fg6)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: InkSpacing.s6),
                  Text(BatchFixture.referencesPathHint, style: t.micro.copyWith(color: c.fg6, height: 1.5)),
                  const SizedBox(height: InkSpacing.md),
                  const _EditorLabel(BatchFixture.fieldReferencedBy),
                  const SizedBox(height: InkSpacing.sm),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < BatchFixture.referencedBy.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: InkSpacing.s6),
                        _ReferencedChip(
                          label: BatchFixture.referencedBy[i],
                          gradient: BatchFixture.referencedByGradients[i],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 底部条：1px 上沿 + padding 12/14 + 行高 28。
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s14, vertical: InkSpacing.s12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(BatchFixture.editorFootnote, style: t.micro.copyWith(color: c.fg6)),
                const Spacer(),
                const WsSecondaryButton(BatchFixture.btnCancel, height: 26),
                const SizedBox(width: InkSpacing.sm),
                const WsPrimaryButton(
                  BatchFixture.btnSave,
                  height: 26,
                  horizontalPadding: InkSpacing.s14,
                  bordered: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorLabel extends StatelessWidget {
  const _EditorLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.inkTypography.body.copyWith(color: context.inkColors.fg4));
}

/// 参考图格：96×96 图 + gap 4 + meta 行（序号徽标 14×14 / 备注 / ✕）。
class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({required this.reference});
  final BcReference reference;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 96,
            child: _Thumb(radius: InkRadius.sm, gradient: reference.gradient, ringColor: c.outline),
          ),
          const SizedBox(height: InkSpacing.xs),
          Row(
            children: <Widget>[
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.control,
                  borderRadius: BorderRadius.circular(InkRadius.xs),
                ),
                child: Text('${reference.index}', style: t.monoNano.copyWith(color: c.fg2)),
              ),
              const SizedBox(width: InkSpacing.s5),
              Expanded(
                child: Text(
                  reference.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.micro.copyWith(color: c.fg5),
                ),
              ),
              const SizedBox(width: InkSpacing.s5),
              Text(BatchFixture.editorClose, style: t.micro.copyWith(color: c.fg6)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 被引用 chip：22 content + 2px 边 = 24 高；内含 16×10 色块 + 11px 文字。
class _ReferencedChip extends StatelessWidget {
  const _ReferencedChip({required this.label, required this.gradient});
  final String label;
  final int gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 10,
            child: _Thumb(radius: InkRadius.s1, gradient: gradient),
          ),
          const SizedBox(width: InkSpacing.s6),
          Text(label, style: t.meta.copyWith(color: c.fg3)),
        ],
      ),
    );
  }
}
