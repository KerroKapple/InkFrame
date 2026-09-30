// 序列视图（P2，Timeline 稿 2026-09-25 版）：只读序列 lens。
//   上半：叙事链 320 | 节目监视器 | 交付占位 320（宽照稿，内容一行「交付随 P6 到来」+ 禁用分段）
//   下半：序列区 300——头 28 | 轨道头 96 + 轨道区（时间尺 26 / 标记 22 / V1 96）
// 只接已有后端的：链表（buildSequence）、监视器（Player 切走即停）、V1 只读轨、场次标记（由链推）、
// 播放头（可拖，只改 Player 位置不写库）、34px/s 可缩放（Ctrl + 滚轮）。
// 不接：拖拽排序（不画 ⠿ 拖柄）、裁切写回、A1 轨、交付面板。无字段不画：入出点 / 手柄 / 音轨 /
// 用户手打的标记 / 吸附 / 链接 V/A / 安全框 / 适合。裁切手柄的渲染支路在（trimmed），入出点字段来了即亮。
import 'dart:io';
import 'dart:ui' show PathMetric;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../storyboard/models/sequence_shot.dart';
import '../models/sequence_lens.dart';
import '../providers/sequence_lens_provider.dart';
import '../providers/sequence_playhead.dart';
import '../providers/sequence_zoom.dart';
import '../util/timecode.dart';
import 'sequence_monitor.dart';

class SequenceScreen extends ConsumerWidget {
  const SequenceScreen({super.key, required this.canvasId, required this.projectId, required this.isVisible});

  final String canvasId;
  final String projectId;
  final bool isVisible;

  /// 稿：两侧面板 320（+1 边）；序列区 300。
  static const double sideWidth = 320;
  static const double sequenceAreaHeight = 300;

  static const Key deliveryPlaceholderKey = Key('sequence.deliveryPlaceholder');
  static Key chainRowKey(int index) => Key('sequence.chainRow.$index');
  static Key clipKey(int index) => Key('sequence.clip.$index');
  static const Key tracksKey = Key('sequence.tracks');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SequenceLens lens = ref.watch(sequenceLensProvider(canvasId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ChainPanel(canvasId: canvasId, projectId: projectId, lens: lens),
              Expanded(
                child: SequenceMonitor(canvasId: canvasId, projectId: projectId, lens: lens, paused: !isVisible),
              ),
              const _DeliveryPlaceholder(),
            ],
          ),
        ),
        _SequenceArea(canvasId: canvasId, projectId: projectId, lens: lens),
      ],
    );
  }
}

File? _thumbFile(WidgetRef ref, String projectId, SequenceShot shot) {
  final String? rel = shot.thumbnailRelativePath;
  final String? canvasId = shot.canvasId;
  if (rel == null || canvasId == null) return null;
  try {
    return ref.read(fileResolverServiceProvider).resolve(projectId: projectId, canvasId: canvasId, relativePath: rel);
  } on PathSecurityError {
    return null;
  }
}

/// 稿：面板页签 28 + 1px 下沿；选中页 surface3 底 + 1px 琥珀上沿。第二项是计数标签，不可切。
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.trailingLabel});
  final String title;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 29,
      decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface3, border: Border(top: BorderSide(color: c.accent))),
            child: Text(title, style: t.bodyStrong.copyWith(color: c.fg1)),
          ),
          if (trailingLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              alignment: Alignment.center,
              child: Text(trailingLabel!, style: t.body.copyWith(color: c.fg5)),
            ),
        ],
      ),
    );
  }
}

/// 稿：320 宽 + 右沿 1，surface3；表头 24 | 行 32 | 底部说明。行点击 = 跳到该镜起点。不画 ⠿ 拖柄。
class _ChainPanel extends ConsumerWidget {
  const _ChainPanel({required this.canvasId, required this.projectId, required this.lens});
  final String canvasId;
  final String projectId;
  final SequenceLens lens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final TextStyle head = t.meta.copyWith(color: c.fg6);
    final int selected = ref.watch(sequencePlayheadProvider(canvasId).select((SequencePlayhead p) => p.index));
    return Container(
      width: SequenceScreen.sideWidth + 1,
      decoration: BoxDecoration(color: c.surface3, border: Border(right: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelHeader(title: l.sequenceChainTab, trailingLabel: l.sequenceUnchained(lens.unchainedCount)),
          Container(
            height: 25,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: _ChainGrid(
              a: Text(l.sequenceColumnShot, style: head),
              b: Text(l.sequenceColumnDuration, style: head),
              c: Text(l.sequenceColumnArtifact, style: head),
            ),
          ),
          Expanded(
            child: lens.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(InkSpacing.s12),
                    child: Text(l.sequencePreviewDisabledTooltip, style: t.meta.copyWith(color: c.fg5, height: 1.5)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: lens.shots.length,
                    itemBuilder: (BuildContext context, int i) => _ChainRow(
                      key: SequenceScreen.chainRowKey(i),
                      index: i,
                      shot: lens.shots[i],
                      selected: i == selected,
                      thumb: _thumbFile(ref, projectId, lens.shots[i]),
                      onTap: () => ref.read(sequencePlayheadProvider(canvasId).notifier).selectShot(i),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
            child: Text(l.sequenceChainNote, style: t.meta.copyWith(color: c.fg6, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// 稿：grid 1fr 56 40，gap 8。
class _ChainGrid extends StatelessWidget {
  const _ChainGrid({required this.a, required this.b, required this.c});
  final Widget a;
  final Widget b;
  final Widget c;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(child: a),
          const SizedBox(width: InkSpacing.sm),
          SizedBox(width: 56, child: b),
          const SizedBox(width: InkSpacing.sm),
          SizedBox(width: 40, child: c),
        ],
      );
}

/// 稿：行 32 + 下沿 1（surface1）；序号 monoSmall fg6 宽 20 | 28×16 缩略 | 名称；片长 mono fg4；产物 meta。
class _ChainRow extends StatelessWidget {
  const _ChainRow({
    super.key,
    required this.index,
    required this.shot,
    required this.selected,
    required this.thumb,
    required this.onTap,
  });
  final int index;
  final SequenceShot shot;
  final bool selected;
  final File? thumb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final bool placeholder = shot.kind == SequenceArtifactKind.none;
    final Color nameColor = placeholder ? c.fg5 : (selected ? c.fg1 : c.fg3);
    final String state = switch (shot.kind) {
      SequenceArtifactKind.video => l.sequenceArtifactVideo,
      SequenceArtifactKind.image => l.sequenceArtifactImage,
      SequenceArtifactKind.none => l.sequenceArtifactMissing,
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 33,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
          decoration: BoxDecoration(
            color: selected ? c.surface5 : null,
            border: Border(bottom: BorderSide(color: c.surface1)),
          ),
          child: _ChainGrid(
            a: Row(
              children: <Widget>[
                SizedBox(width: 20, child: Text((index + 1).toString().padLeft(3, '0'), style: t.monoSmall.copyWith(color: c.fg6))),
                const SizedBox(width: InkSpacing.sm),
                _Thumb(file: thumb, width: 28, height: 16, radius: InkRadius.xs),
                const SizedBox(width: InkSpacing.sm),
                Expanded(
                  child: Text(shot.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: nameColor)),
                ),
              ],
            ),
            b: Text(formatTimecodeShort(shot.durationMs), style: t.mono.copyWith(color: c.fg4)),
            c: Text(state, style: t.meta.copyWith(color: placeholder ? c.accent : c.fg5)),
          ),
        ),
      ),
    );
  }
}

/// 缩略：有文件按宽解码显示；没有则 laneDivider 纯色块。
class _Thumb extends StatelessWidget {
  const _Thumb({required this.file, this.width, this.height, required this.radius, this.opacity = 1});
  final File? file;
  final double? width;
  final double? height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: c.laneDivider, borderRadius: BorderRadius.circular(radius)),
      child: file == null
          ? null
          : Opacity(
              opacity: opacity,
              child: Image.file(
                file!,
                fit: BoxFit.cover,
                cacheWidth: 128,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
    );
  }
}

/// 拍板：交付面板位置的空态占位——页签 + 禁用的目标软件分段 + 「交付随 P6 到来」。
class _DeliveryPlaceholder extends StatelessWidget {
  const _DeliveryPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final List<String> targets = <String>[l.sequenceTargetResolve, l.sequenceTargetPremiere, l.sequenceTargetFinalCut, l.sequenceTargetJianying];
    return Container(
      key: SequenceScreen.deliveryPlaceholderKey,
      width: SequenceScreen.sideWidth + 1,
      decoration: BoxDecoration(color: c.surface3, border: Border(left: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelHeader(title: l.sequenceDeliveryTab),
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s14, InkSpacing.s12, InkSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.sequenceDeliveryTargets, style: t.body.copyWith(color: c.fg6)),
                const SizedBox(height: InkSpacing.s10),
                Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(border: Border.all(color: c.control), borderRadius: BorderRadius.circular(InkRadius.s3)),
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < targets.length; i++)
                        Expanded(
                          child: Container(
                            height: 26,
                            alignment: Alignment.center,
                            decoration: i == targets.length - 1 ? null : BoxDecoration(border: Border(right: BorderSide(color: c.control))),
                            child: Text(targets[i], style: t.body.copyWith(color: c.fg6)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s10),
                Text(l.sequenceDeliveryPlaceholder, style: t.meta.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 序列区

/// 稿：300 高 surface3；头 28（序列 | 播放头 tc | 竖线 | 总长 | N 镜 · M 占位）| 轨道头 96 + 轨道区。
class _SequenceArea extends ConsumerWidget {
  const _SequenceArea({required this.canvasId, required this.projectId, required this.lens});
  final String canvasId;
  final String projectId;
  final SequenceLens lens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final SequencePlayhead head = ref.watch(sequencePlayheadProvider(canvasId));
    final int globalMs = lens.globalMs(head.index, head.offsetMs);
    final TextStyle dim = t.body.copyWith(color: c.fg5);
    return Container(
      height: SequenceScreen.sequenceAreaHeight,
      decoration: BoxDecoration(color: c.surface3, border: Border(top: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 29,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(l.sequenceTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(width: InkSpacing.s12),
                Text(formatTimecode(globalMs), style: t.mono.copyWith(color: c.accent)),
                const Spacer(),
                Text(l.sequenceTotal, style: dim),
                Text(formatTimecode(lens.totalMs), style: t.mono.copyWith(color: c.fg2)),
                const SizedBox(width: InkSpacing.s12),
                Text(l.sequenceCountSummary(lens.shots.length, lens.placeholderCount), style: dim),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TrackHeads(lens: lens),
                Expanded(child: _Tracks(canvasId: canvasId, projectId: projectId, lens: lens, globalMs: globalMs)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 稿：96 宽 + 右沿 1，surface2；行 26 空 / 22 标记 / 96 V1（A1 不接，不画）。
class _TrackHeads extends StatelessWidget {
  const _TrackHeads({required this.lens});
  final SequenceLens lens;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    Widget row(double h, Widget child) => Container(
          height: h + 1,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
          child: child,
        );
    return Container(
      width: 97,
      decoration: BoxDecoration(color: c.surface2, border: Border(right: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          row(26, const SizedBox.shrink()),
          row(22, Align(alignment: Alignment.centerLeft, child: Text(l.sequenceMarkerTrack, style: t.meta.copyWith(color: c.fg5)))),
          row(
            96,
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.sequenceTrackV1, style: t.bodyStrong.copyWith(color: c.fg1)),
                const SizedBox(height: InkSpacing.xs),
                Text(l.sequenceTrackV1Meta(lens.shots.length), style: t.meta.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 轨道区：时间尺 26 | 标记轨 22 | V1 96 + 贯穿的播放头。横向可滚；Ctrl + 滚轮缩放；点 / 拖 = seek。
class _Tracks extends ConsumerStatefulWidget {
  const _Tracks({required this.canvasId, required this.projectId, required this.lens, required this.globalMs});
  final String canvasId;
  final String projectId;
  final SequenceLens lens;
  final int globalMs;

  @override
  ConsumerState<_Tracks> createState() => _TracksState();
}

class _TracksState extends ConsumerState<_Tracks> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _seekAt(double localX, double pxPerSec) {
    final double x = localX + (_scroll.hasClients ? _scroll.offset : 0);
    final int ms = (x / pxPerSec * 1000).round();
    ref.read(sequencePlayheadProvider(widget.canvasId).notifier).seekGlobal(ms.clamp(0, widget.lens.totalMs), widget.lens);
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    if (!HardwareKeyboard.instance.isControlPressed && !HardwareKeyboard.instance.isMetaPressed) return;
    final StateController<double> zoom = ref.read(sequenceZoomProvider(widget.canvasId).notifier);
    zoom.state = clampSequenceZoom(e.scrollDelta.dy < 0 ? zoom.state * kSequenceZoomStep : zoom.state / kSequenceZoomStep);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final double pxPerSec = ref.watch(sequenceZoomProvider(widget.canvasId));
    final SequenceLens lens = widget.lens;
    double px(int ms) => (ms / 1000 * pxPerSec).roundToDouble();
    final double contentWidth = px(lens.totalMs) + 200;
    // 刻度间隔随比例变：保证相邻标签至少 ~110px。
    final int tickSec = <int>[1, 2, 5, 10, 15, 30, 60].firstWhere((int s) => s * pxPerSec >= 110, orElse: () => 60);
    final int lastTickSec = (lens.totalMs / 1000).ceil();
    final double playheadX = px(widget.globalMs);

    // 点 / 拖 = seek 走原始指针事件（Listener），不进手势竞技场：里层横向滚动视图的拖动识别器
    // 不会把它抢走，按下即跳、移动即跟，没有 tap / drag 判定延迟。
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double width = contentWidth < box.maxWidth ? box.maxWidth : contentWidth;
          return ClipRect(
            child: Listener(
              key: SequenceScreen.tracksKey,
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent e) => _seekAt(e.localPosition.dx, pxPerSec),
              onPointerMove: (PointerMoveEvent e) {
                if (e.buttons & kPrimaryButton == 0 && e.kind == PointerDeviceKind.mouse) return;
                _seekAt(e.localPosition.dx, pxPerSec);
              },
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: width,
                  child: Stack(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // 时间尺：刻度 1×8 overlayBorder 贴底 + monoSmall 标签。
                          Container(
                            height: 27,
                            decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
                            child: Stack(
                              children: <Widget>[
                                for (int s = 0; s <= lastTickSec; s += tickSec) ...<Widget>[
                                  Positioned(left: px(s * 1000), bottom: 1, child: Container(width: 1, height: 8, color: c.overlayBorder)),
                                  Positioned(
                                    left: px(s * 1000) + InkSpacing.xs,
                                    top: 5,
                                    child: Text(formatTimecode(s * 1000), style: t.monoSmall.copyWith(color: c.fg6)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // 标记轨：场次标记（由链推）——8px 菱形 fg5 + 10px 标签。
                          Container(
                            height: 23,
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
                            child: Stack(
                              children: <Widget>[
                                for (final SceneMarker m in lens.markers)
                                  Positioned(
                                    left: px(m.atMs),
                                    top: 4,
                                    child: Row(
                                      children: <Widget>[
                                        Transform.rotate(angle: 0.7853981634, child: Container(width: 8, height: 8, color: c.fg5)),
                                        const SizedBox(width: 5),
                                        // 标记标签 = 节点名，可能很长；封顶 160 单行省略，别铺满整条轨。
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 160),
                                          child: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.micro.copyWith(color: c.fg3)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // V1：每 170px 一根 1px 竖线底纹 + 只读片段。
                          Container(
                            height: 97,
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
                            child: Stack(
                              children: <Widget>[
                                Positioned.fill(child: CustomPaint(painter: _RepeatLinesPainter(c.borderSubtle, period: 170))),
                                for (int i = 0; i < lens.shots.length; i++)
                                  Positioned(
                                    left: px(lens.startsMs[i]),
                                    top: 8,
                                    width: (px(lens.shots[i].durationMs) - 3).clamp(8.0, double.infinity),
                                    height: 80,
                                    child: _Clip(
                                      key: SequenceScreen.clipKey(i),
                                      index: i,
                                      shot: lens.shots[i],
                                      selected: ref.watch(sequencePlayheadProvider(widget.canvasId).select((SequencePlayhead p) => p.index)) == i,
                                      thumb: _thumbFile(ref, widget.projectId, lens.shots[i]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // 播放头：1px 琥珀竖线贯穿 + 顶部 13×9 三角。
                      Positioned(left: playheadX, top: 0, bottom: 0, width: 1, child: IgnorePointer(child: ColoredBox(color: c.accent))),
                      Positioned(
                        left: playheadX - 6,
                        top: 0,
                        width: 13,
                        height: 9,
                        child: IgnorePointer(child: CustomPaint(painter: _TrianglePainter(c.accent))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 单行文本在当前字体栈 / 文字缩放下的自然宽度（片段标签行按它决定画不画时码 / 标签）。
double _textWidth(BuildContext context, String text, TextStyle style) {
  final TextPainter tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final double w = tp.width;
  tp.dispose();
  return w;
}

/// 稿：片段 80 高圆角 3；三格缩略条（同图 1 / .85 / .7）+ 20 信息行；选中琥珀描边 + accentWash 底；
/// 占位透明 + overlayBorder 虚线；已裁切两端 4px 琥珀条（无入出点字段，恒 false）。
class _Clip extends StatelessWidget {
  const _Clip({super.key, required this.index, required this.shot, required this.selected, required this.thumb});
  final int index;
  final SequenceShot shot;
  final bool selected;
  final File? thumb;

  /// 标签至少要有这么宽才值得画（否则只剩省略号）；再窄只剩序号。34px/s 下 1s 镜 34 宽，只出序号。
  static const double minLabelWidth = 24;

  /// 三格缩略条的最小内容宽：3 格 × 4 + 2 缝 × 2。
  static const double minTripleThumbWidth = 16;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final bool placeholder = shot.kind == SequenceArtifactKind.none;
    final Color fg = placeholder ? c.fg6 : c.fg2;
    const bool trimmed = false; // 无入出点字段（PLAN §P2 无字段项）；字段来了这里接 shot 的裁切态。
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: placeholder ? null : (selected ? c.accentWash : c.laneDivider),
              borderRadius: BorderRadius.circular(InkRadius.s3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(InkSpacing.s3),
                    // 三格缩略条要装下两道 2px 缝 + 每格至少 4px；再窄（缩到最小的短镜）只画一格。
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) => box.maxWidth < _Clip.minTripleThumbWidth
                          ? _Thumb(file: placeholder ? null : thumb, radius: InkRadius.s1)
                          : Row(
                              children: <Widget>[
                                Expanded(child: _Thumb(file: placeholder ? null : thumb, radius: InkRadius.s1)),
                                const SizedBox(width: InkSpacing.s2),
                                Expanded(child: _Thumb(file: placeholder ? null : thumb, radius: InkRadius.s1, opacity: 0.85)),
                                const SizedBox(width: InkSpacing.s2),
                                Expanded(child: _Thumb(file: placeholder ? null : thumb, radius: InkRadius.s1, opacity: 0.7)),
                              ],
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s6),
                    // 短镜（1s = 34px）装不下三段：按可用宽度逐级舍弃时码、标签，序号最后走。
                    // 阈值按真实字宽量（字体栈不同宽度不同：CI 测试字体是等宽方块），不写死像素。
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) {
                        final TextStyle idxStyle = t.monoSmall.copyWith(color: fg);
                        final TextStyle tcStyle = t.monoSmall.copyWith(color: c.fg5);
                        final String idx = (index + 1).toString().padLeft(3, '0');
                        final String tc = formatTimecode(shot.durationMs);
                        final double idxW = _textWidth(context, idx, idxStyle);
                        final double tcW = _textWidth(context, tc, tcStyle);
                        final bool showLabel = box.maxWidth >= idxW + InkSpacing.s6 + _Clip.minLabelWidth;
                        final bool showTc = box.maxWidth >= idxW + InkSpacing.s6 + _Clip.minLabelWidth + InkSpacing.s6 + tcW;
                        return Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(idx, maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: idxStyle),
                            ),
                            if (showLabel) ...<Widget>[
                              const SizedBox(width: InkSpacing.s6),
                              Expanded(
                                child: Text(
                                  shot.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: t.micro.copyWith(color: fg),
                                ),
                              ),
                            ],
                            if (showTc) ...<Widget>[
                              const SizedBox(width: InkSpacing.s6),
                              Text(tc, maxLines: 1, softWrap: false, style: tcStyle),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: placeholder
                ? CustomPaint(painter: _DashedRectPainter(c.overlayBorder, radius: InkRadius.s3))
                : DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: selected ? c.accent : c.control),
                      borderRadius: BorderRadius.circular(InkRadius.s3),
                    ),
                  ),
          ),
        ),
        // ignore: dead_code
        if (trimmed) ...<Widget>[
          Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: c.accent)),
          Positioned(right: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: c.accent)),
        ],
      ],
    );
  }
}

/// 稿：repeating-linear-gradient(90deg, transparent 0 169px, #1F1F1F 169px 170px)。
class _RepeatLinesPainter extends CustomPainter {
  const _RepeatLinesPainter(this.color, {required this.period});
  final Color color;
  final double period;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    for (double x = period - 1; x < size.width; x += period) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_RepeatLinesPainter old) => old.color != color || old.period != period;
}

/// 1px 虚线圆角框（CSS outline: 1px dashed，offset −1）。
class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter(this.color, {required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1), Radius.circular(radius)));
    const double dash = 3;
    const double gap = 3;
    for (final PathMetric metric in path.computeMetrics()) {
      double t = 0;
      while (t < metric.length) {
        final double e = (t + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(t, e), p);
        t += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color || old.radius != radius;
}

/// 稿：clip-path polygon(0 0, 100% 0, 50% 100%) 的 13×9 三角。
class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
