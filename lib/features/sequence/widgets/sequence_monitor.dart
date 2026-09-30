// 节目监视器（P2，Timeline 稿上半中栏）：按叙事链播放整条分镜。播放 / 推进逻辑从原
// storyboard/widgets/sequence_preview_dialog.dart 搬来，三条改动是拍板：
//   ① 不自动播放；
//   ② [paused] 变 true（序列标签离台 / 被浮层盖住）时立刻 pause，回来【不】续播；
//   ③ 播放头是共享态（sequencePlayheadProvider）：监视器 report 进度，链表 / 轨道 seek 它。
//      seek 只改 Player 位置，不写库。
//
// 推进规则（两套，按镜的类型走）：
//   - 图片 / 无产物占位：100ms 计时器推进偏移，到 durationMs 换镜
//   - 视频：以真实播放进度推进（position ≥ duration 即换镜），另挂一个兜底定时器——
//     播放器打不开文件、进度流不动、时长拿不到时不至于永远卡在这一镜。
//
// media_kit 生命周期：整个监视器只 create() 一个 handle，换镜靠 open() 换源，dispose 时释放。
// 纯图片序列不唤起 media_kit（不 create handle）。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show Player;
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/video_player.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/video_player_service.dart';
import '../../../core/models/provider_capabilities.dart' show CameraMovement;
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../canvas/util/camera_labels.dart';
import '../../storyboard/models/sequence_shot.dart';
import '../models/sequence_lens.dart';
import '../providers/sequence_playhead.dart';
import '../util/timecode.dart';

class SequenceMonitor extends ConsumerStatefulWidget {
  const SequenceMonitor({
    super.key,
    required this.canvasId,
    required this.projectId,
    required this.lens,
    required this.paused,
  });

  final String canvasId;
  final String projectId;
  final SequenceLens lens;

  /// true = 序列标签不可见（离台 / 被浮层盖住）：正在播就停，回来不续播。
  final bool paused;

  static const Key playPauseKey = Key('sequence.monitor.playPause');
  static const Key prevKey = Key('sequence.monitor.prev');
  static const Key nextKey = Key('sequence.monitor.next');

  @override
  ConsumerState<SequenceMonitor> createState() => _SequenceMonitorState();
}

class _SequenceMonitorState extends ConsumerState<SequenceMonitor> {
  VideoPlayerHandle? _handle;
  VideoController? _videoController;

  int _index = 0;
  int _offsetMs = 0;
  bool _playing = false;
  bool _videoReady = false;

  Timer? _advanceTimer;
  Timer? _tick;
  StreamSubscription<Duration>? _positionSub;
  Duration? _currentVideoDuration;

  /// 每次换镜自增——异步回调（open 完成、position 事件）拿它比对，
  /// 迟到的回调不会推进一个早已翻过去的镜。
  int _epoch = 0;
  int _appliedSeekToken = 0;

  List<SequenceShot> get _shots => widget.lens.shots;
  SequenceShot? get _current => _index >= 0 && _index < _shots.length ? _shots[_index] : null;

  @override
  void initState() {
    super.initState();
    if (_shots.any((s) => s.kind == SequenceArtifactKind.video)) {
      final handle = ref.read(videoPlayerServiceProvider).create();
      _handle = handle;
      final raw = handle.rawPlayer;
      if (raw is Player) _videoController = VideoController(raw);
    }
    final SequencePlayhead head = ref.read(sequencePlayheadProvider(widget.canvasId));
    _appliedSeekToken = head.seekToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enterShot(head.index, offsetMs: head.offsetMs);
    });
  }

  @override
  void didUpdateWidget(SequenceMonitor old) {
    super.didUpdateWidget(old);
    // 拍板：离台即停，回来不续播。
    if (widget.paused && !old.paused && _playing) _pause();
    // 链变了（节点 / 边改动）：当前镜越界就夹回末镜。
    if (!identical(old.lens, widget.lens) && _index >= _shots.length) {
      _enterShot(_shots.isEmpty ? 0 : _shots.length - 1);
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _tick?.cancel();
    unawaited(_positionSub?.cancel());
    // media_kit 泄漏高发：handle 只在 initState 建、只在这里放。
    unawaited(_handle?.dispose());
    super.dispose();
  }

  File? _resolve(SequenceShot shot) {
    final rel = shot.relativePath;
    final canvasId = shot.canvasId;
    if (rel == null || canvasId == null) return null;
    try {
      return ref.read(fileResolverServiceProvider).resolve(
            projectId: widget.projectId,
            canvasId: canvasId,
            relativePath: rel,
          );
    } on PathSecurityError {
      return null;
    }
  }

  void _report() {
    if (!mounted) return;
    ref.read(sequencePlayheadProvider(widget.canvasId).notifier).report(_index, _offsetMs);
  }

  /// 切到第 [i] 镜并按其类型安排推进。越界即收尾（停在末镜暂停态）。
  void _enterShot(int i, {int offsetMs = 0}) {
    _advanceTimer?.cancel();
    _tick?.cancel();
    unawaited(_positionSub?.cancel());
    _positionSub = null;
    _currentVideoDuration = null;

    if (_shots.isEmpty) {
      setState(() {
        _index = 0;
        _offsetMs = 0;
        _playing = false;
        _videoReady = false;
      });
      return;
    }
    if (i >= _shots.length) {
      setState(() {
        _index = _shots.length - 1;
        _offsetMs = _shots[_index].durationMs;
        _playing = false;
        _videoReady = false;
      });
      _report();
      return;
    }
    if (i < 0) i = 0;

    final epoch = ++_epoch;
    final SequenceShot shot = _shots[i];
    setState(() {
      _index = i;
      _offsetMs = offsetMs.clamp(0, shot.durationMs);
      _videoReady = false;
    });
    _report();

    if (shot.kind == SequenceArtifactKind.video) {
      _startVideoShot(shot, epoch, seekTo: Duration(milliseconds: _offsetMs));
    }
    if (_playing) _startAdvance(shot, epoch);
  }

  /// 图片 / 占位镜：100ms 一跳推进偏移，到时长换镜。视频镜：兜底定时器（正常由进度流换镜）。
  void _startAdvance(SequenceShot shot, int epoch) {
    if (shot.kind == SequenceArtifactKind.video) {
      final ms = shot.durationMs - _offsetMs + 1500;
      _advanceTimer = Timer(Duration(milliseconds: ms), () {
        if (!mounted || epoch != _epoch) return;
        _enterShot(_index + 1);
      });
      return;
    }
    _tick = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
      if (!mounted || epoch != _epoch) {
        t.cancel();
        return;
      }
      _offsetMs += 100;
      if (_offsetMs >= shot.durationMs) {
        t.cancel();
        _enterShot(_index + 1);
        return;
      }
      _report();
      setState(() {});
    });
  }

  void _startVideoShot(SequenceShot shot, int epoch, {required Duration seekTo}) {
    final handle = _handle;
    final file = _resolve(shot);
    if (handle == null || file == null) return;

    _positionSub = handle.positionStream.listen((pos) {
      if (!mounted || epoch != _epoch) return;
      _offsetMs = pos.inMilliseconds;
      _report();
      final total = _currentVideoDuration;
      if (total == null || total <= Duration.zero) {
        setState(() {});
        return;
      }
      if (pos >= total) {
        _enterShot(_index + 1);
      } else {
        setState(() {});
      }
    });

    unawaited(() async {
      await handle.open(file.path);
      if (!mounted || epoch != _epoch) return;
      unawaited(
        handle.durationStream.firstWhere((d) => d != null && d > Duration.zero).then((d) {
          if (mounted && epoch == _epoch) _currentVideoDuration = d;
        }).catchError((Object _) {}),
      );
      if (seekTo > Duration.zero) await handle.seek(seekTo);
      if (!_playing) {
        await handle.pause();
      } else {
        await handle.play();
      }
      if (mounted && epoch == _epoch) setState(() => _videoReady = true);
    }());
  }

  void _pause() {
    setState(() => _playing = false);
    _advanceTimer?.cancel();
    _tick?.cancel();
    if (_current?.kind == SequenceArtifactKind.video) unawaited(_handle?.pause());
  }

  void _play() {
    final shot = _current;
    if (shot == null) return;
    // 停在末尾再按播放：从头来。
    if (_index == _shots.length - 1 && _offsetMs >= shot.durationMs) {
      setState(() => _playing = true);
      _enterShot(0);
      return;
    }
    setState(() => _playing = true);
    _startAdvance(shot, _epoch);
    if (shot.kind == SequenceArtifactKind.video) unawaited(_handle?.play());
  }

  void _togglePlay() => _playing ? _pause() : _play();

  void _step(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= _shots.length) return;
    ref.read(sequencePlayheadProvider(widget.canvasId).notifier).selectShot(target);
  }

  /// 外部 seek（链表行 / 轨道）：token 变了才动播放器；自己 report 的进度不回环。
  void _onPlayheadChanged(SequencePlayhead? prev, SequencePlayhead next) {
    if (next.seekToken == _appliedSeekToken) return;
    _appliedSeekToken = next.seekToken;
    final SequenceShot? shot = next.index < _shots.length ? _shots[next.index] : null;
    if (shot != null && next.index == _index && shot.kind == SequenceArtifactKind.video && _videoReady) {
      // 同一镜内 seek：只动播放器位置。
      _offsetMs = next.offsetMs;
      unawaited(_handle?.seek(Duration(milliseconds: next.offsetMs)));
      setState(() {});
      return;
    }
    _enterShot(next.index, offsetMs: next.offsetMs);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SequencePlayhead>(sequencePlayheadProvider(widget.canvasId), _onPlayheadChanged);
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final SequenceShot? shot = _current;
    final int globalMs = widget.lens.globalMs(_index, _offsetMs);

    return ColoredBox(
      color: c.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 稿：头 28 + 1px 下沿：节目监视器 | 竖线 | 当前镜名。
          Container(
            height: 29,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: Row(
              children: <Widget>[
                Text(l.sequenceMonitorTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                if (shot != null) ...<Widget>[
                  const SizedBox(width: InkSpacing.s12),
                  Container(width: 1, height: 12, color: c.control),
                  const SizedBox(width: InkSpacing.s12),
                  Flexible(
                    child: Text(shot.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(color: c.fg5)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(InkSpacing.lg, InkSpacing.md, InkSpacing.lg, InkSpacing.sm),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: shot == null
                      ? _Frame(child: Center(child: Text(l.sequencePreviewEmpty, style: t.body.copyWith(color: c.fg2))))
                      : _Frame(
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              _stage(shot),
                              _Overlay(
                                canvasId: widget.canvasId,
                                index: _index,
                                shot: shot,
                                offsetMs: _offsetMs,
                                sourceMs: _currentVideoDuration?.inMilliseconds ?? shot.durationMs,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
          // 稿：播放条 3px + 传输控件行。I / O 入出点、单帧步进无字段，不画。
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.lg, InkSpacing.xs, InkSpacing.lg, InkSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ScrubBar(
                  fraction: widget.lens.totalMs == 0 ? 0 : globalMs / widget.lens.totalMs,
                  onSeek: (double f) => ref
                      .read(sequencePlayheadProvider(widget.canvasId).notifier)
                      .seekGlobal((f * widget.lens.totalMs).round(), widget.lens),
                ),
                const SizedBox(height: InkSpacing.sm),
                // 两侧时码各占一半余量（Expanded），传输键居中定宽。别用 Flexible + Spacer：
                // Flexible 与 Spacer 平分 flex，最小窗口下时码只分到 ~50px 就被裁掉。
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        formatTimecode(globalMs),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: t.mono.copyWith(color: c.fg1, height: 1.2),
                      ),
                    ),
                    _TransportKey(
                      key: SequenceMonitor.prevKey,
                      icon: Icons.skip_previous,
                      tooltip: l.sequencePreviewPrevious,
                      onTap: _index > 0 ? () => _step(-1) : null,
                    ),
                    const SizedBox(width: InkSpacing.s14),
                    _TransportKey(
                      key: SequenceMonitor.playPauseKey,
                      icon: _playing ? Icons.pause : Icons.play_arrow,
                      tooltip: l.lightboxPlayPause,
                      onTap: shot == null ? null : _togglePlay,
                      emphasized: true,
                    ),
                    const SizedBox(width: InkSpacing.s14),
                    _TransportKey(
                      key: SequenceMonitor.nextKey,
                      icon: Icons.skip_next,
                      tooltip: l.sequencePreviewNext,
                      onTap: _index < _shots.length - 1 ? () => _step(1) : null,
                    ),
                    Expanded(
                      child: Text(
                        formatTimecode(widget.lens.totalMs),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: t.mono.copyWith(color: c.fg4, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage(SequenceShot shot) {
    switch (shot.kind) {
      case SequenceArtifactKind.none:
        return _NotesPlaceholder(shot: shot);
      case SequenceArtifactKind.video:
        return (_videoReady && _videoController != null)
            ? Video(controller: _videoController!, controls: (_) => const SizedBox.shrink())
            : _NotesPlaceholder(shot: shot, loading: true);
      case SequenceArtifactKind.image:
        final file = _resolve(shot);
        if (file == null) return _NotesPlaceholder(shot: shot, missing: true);
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _NotesPlaceholder(shot: shot, missing: true),
        );
    }
  }
}

/// 稿：16:9 画面圆角 2 描边 outline；黑底。
class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surface0,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(InkRadius.xs),
      ),
      child: child,
    );
  }
}

/// 稿：底部叠字（mono 11 fg1@.75）：左「003 · 推镜 · Kling v3」（景别等 P3，先三段）；右「src 镜内位置 / 源长」。
class _Overlay extends ConsumerWidget {
  const _Overlay({
    required this.canvasId,
    required this.index,
    required this.shot,
    required this.offsetMs,
    required this.sourceMs,
  });

  /// 叠字行至少这么宽才画右段「src 时码 / 源长」（左段序号 + 右段 ~30 个等宽字符）。
  static const double minWidthForSource = 320;

  final String canvasId;
  final int index;
  final SequenceShot shot;
  final int offsetMs;
  final int sourceMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
    CanvasNode? node;
    for (final CanvasNode n in nodes) {
      if (n.id == shot.nodeId) node = n;
    }
    final List<String> parts = <String>[(index + 1).toString().padLeft(3, '0')];
    if (node != null) {
      final String? cam = node.cameraName;
      if (cam != null) {
        for (final CameraMovement m in CameraMovement.values) {
          if (m.name == cam) parts.add(cameraMovementLabel(context, m));
        }
      }
      final String? providerId = node.typeConfig['provider_id'] as String?;
      if (providerId != null) parts.add(ref.watch(providerDisplayNamesProvider)[providerId] ?? providerId);
    }
    final TextStyle s = t.mono.copyWith(color: c.fg1.withValues(alpha: 0.75));
    final String src = 'src ${formatTimecode(offsetMs)} / ${formatTimecode(sourceMs)}';
    return Positioned(
      left: InkSpacing.s12,
      right: InkSpacing.s12,
      bottom: InkSpacing.s10,
      // 画面很窄时（最小窗口下 16:9 框只有 ~180 宽）右段装不下就整段不画，别裁成半截时码。
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final bool showSrc = box.maxWidth >= _Overlay.minWidthForSource;
          return Row(
            children: <Widget>[
              Expanded(child: Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: s)),
              if (showSrc) ...<Widget>[
                const SizedBox(width: InkSpacing.sm),
                Text(src, maxLines: 1, softWrap: false, style: s),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 没有产物（或产物读不到）时的画面：显示这一镜的备注，让预览仍然连贯。
class _NotesPlaceholder extends StatelessWidget {
  const _NotesPlaceholder({required this.shot, this.missing = false, this.loading = false});

  final SequenceShot shot;
  final bool missing;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    // 画面随监视器宽度走 16:9，最小窗口（960×600）下只有 ~160 高：内容按自然尺寸排，
    // 装不下时整体等比缩小（FittedBox.scaleDown），装得下时 1:1，不溢出也不裁字。
    return Container(
      color: colors.surface1,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(InkSpacing.lg),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (loading)
                  const CircularProgressIndicator()
                else
                  Icon(missing ? Icons.broken_image_outlined : Icons.image_outlined, color: colors.fg4),
                const SizedBox(height: InkSpacing.md),
                Text(
                  missing ? l.sequencePreviewMissingFile : l.sequencePreviewNoArtifact,
                  style: typo.meta.copyWith(color: colors.fg3),
                ),
                if (shot.notes != null) ...<Widget>[
                  const SizedBox(height: InkSpacing.md),
                  Text(
                    shot.notes!,
                    textAlign: TextAlign.center,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: typo.body.copyWith(color: colors.fg1),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 稿：3px 轨 control 圆角 2；已播段 fg6；播放头 2×13 accent。点 / 拖 = seek。
class _ScrubBar extends StatelessWidget {
  const _ScrubBar({required this.fraction, required this.onSeek});
  final double fraction;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double x = box.maxWidth * fraction.clamp(0.0, 1.0);
        void seekAt(double dx) => onSeek((dx / box.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => seekAt(d.localPosition.dx),
          onHorizontalDragUpdate: (DragUpdateDetails d) => seekAt(d.localPosition.dx),
          child: SizedBox(
            height: 13,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  top: 5,
                  height: 3,
                  child: DecoratedBox(decoration: BoxDecoration(color: c.control, borderRadius: BorderRadius.circular(InkRadius.xs))),
                ),
                Positioned(
                  left: 0,
                  top: 5,
                  height: 3,
                  width: x,
                  child: DecoratedBox(decoration: BoxDecoration(color: c.fg6, borderRadius: BorderRadius.circular(InkRadius.xs))),
                ),
                Positioned(left: x - 1, top: 0, width: 2, height: 13, child: ColoredBox(color: c.accent)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 传输键：图标 + tooltip，禁用时 fg4。
class _TransportKey extends StatelessWidget {
  const _TransportKey({super.key, required this.icon, required this.tooltip, required this.onTap, this.emphasized = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: MouseRegion(
          cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: 20,
              height: 20,
              child: Icon(
                icon,
                size: emphasized ? InkSpacing.s18 : InkSpacing.md,
                color: onTap == null ? c.fg6 : (emphasized ? c.fg1 : c.fg4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
