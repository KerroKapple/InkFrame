// SB-6 序列预览：按叙事链把整条分镜从头播一遍。
//
// 播放清单由 `util/sequence_builder.dart` 编译好后传入——本文件只负责
// 「放」与「推进」，不掺排序/查产物的逻辑。
//
// 推进规则（两套，按镜的类型走）：
//   - 图片 / 无产物占位：定时器，停留 shot.durationMs
//   - 视频：以真实播放进度推进（position ≥ duration 即换镜），另挂一个
//     **兜底定时器**——播放器打不开文件、进度流不动、时长拿不到时不至于
//     永远卡在这一镜。
//
// media_kit 生命周期：整个对话框只 create() 一个 handle，换镜靠 open()
// 换源，关闭时 dispose()。卡面点名此处泄漏高发——handle 的创建与释放都
// 收敛在本 State 的 initState / dispose，中途任何路径都不再 create。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show Player;
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/di/video_player.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/video_player_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/sequence_shot.dart';

Future<void> showSequencePreviewDialog(
  BuildContext context, {
  required String projectId,
  required List<SequenceShot> shots,
}) =>
    showDialog<void>(
      context: context,
      barrierColor: context.inkColors.scrim,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(InkSpacing.xl),
        backgroundColor: Colors.transparent,
        child: SequencePreviewContent(projectId: projectId, shots: shots),
      ),
    );

class SequencePreviewContent extends ConsumerStatefulWidget {
  const SequencePreviewContent({
    super.key,
    required this.projectId,
    required this.shots,
  });

  final String projectId;
  final List<SequenceShot> shots;

  @override
  ConsumerState<SequencePreviewContent> createState() =>
      _SequencePreviewState();
}

class _SequencePreviewState extends ConsumerState<SequencePreviewContent> {
  VideoPlayerHandle? _handle;
  VideoController? _videoController;

  int _index = 0;
  bool _playing = true;
  bool _videoReady = false;

  Timer? _advanceTimer;
  StreamSubscription<Duration>? _positionSub;
  Duration? _currentVideoDuration;

  /// 每次换镜自增——异步回调（open 完成、position 事件）拿它比对，
  /// 迟到的回调不会推进一个早已翻过去的镜。
  int _epoch = 0;

  List<SequenceShot> get _shots => widget.shots;
  SequenceShot? get _current =>
      _index >= 0 && _index < _shots.length ? _shots[_index] : null;

  @override
  void initState() {
    super.initState();
    // 只有真的有视频镜时才建 handle——纯图片序列不该唤起 media_kit。
    if (_shots.any((s) => s.kind == SequenceArtifactKind.video)) {
      final handle = ref.read(videoPlayerServiceProvider).create();
      _handle = handle;
      final raw = handle.rawPlayer;
      if (raw is Player) _videoController = VideoController(raw);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enterShot(0);
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    unawaited(_positionSub?.cancel());
    // 卡面点名：media_kit 泄漏高发。handle 只在 initState 建、只在这里放。
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

  /// 切到第 [i] 镜并按其类型安排推进。越界即收尾（停在末镜暂停态）。
  void _enterShot(int i) {
    _advanceTimer?.cancel();
    unawaited(_positionSub?.cancel());
    _positionSub = null;
    _currentVideoDuration = null;

    if (i >= _shots.length) {
      setState(() {
        _index = _shots.isEmpty ? 0 : _shots.length - 1;
        _playing = false;
        _videoReady = false;
      });
      return;
    }
    if (i < 0) i = 0;

    final epoch = ++_epoch;
    setState(() {
      _index = i;
      _videoReady = false;
    });

    final shot = _shots[i];
    if (shot.kind == SequenceArtifactKind.video) {
      _startVideoShot(shot, epoch);
    }
    if (_playing) _scheduleFallbackAdvance(shot, epoch);
  }

  /// 图片/占位镜：这就是唯一的推进器。视频镜：兜底，防播放器不推进。
  void _scheduleFallbackAdvance(SequenceShot shot, int epoch) {
    // 视频兜底给一点余量，正常播放应当先于它触发换镜。
    final ms = shot.kind == SequenceArtifactKind.video
        ? shot.durationMs + 1500
        : shot.durationMs;
    _advanceTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || epoch != _epoch) return;
      _enterShot(_index + 1);
    });
  }

  void _startVideoShot(SequenceShot shot, int epoch) {
    final handle = _handle;
    final file = _resolve(shot);
    if (handle == null || file == null) return;

    _positionSub = handle.positionStream.listen((pos) {
      if (!mounted || epoch != _epoch) return;
      final total = _currentVideoDuration;
      if (total == null || total <= Duration.zero) return;
      if (pos >= total) _enterShot(_index + 1);
    });

    unawaited(() async {
      await handle.open(file.path);
      if (!mounted || epoch != _epoch) return;
      // durationStream 首帧才有真值——拿一次即可，之后不再变。
      unawaited(
        handle.durationStream.firstWhere((d) => d != null && d > Duration.zero).then((d) {
          if (mounted && epoch == _epoch) _currentVideoDuration = d;
        }).catchError((Object _) {}),
      );
      if (!_playing) {
        await handle.pause();
      } else {
        await handle.play();
      }
      if (mounted && epoch == _epoch) setState(() => _videoReady = true);
    }());
  }

  void _togglePlay() {
    final next = !_playing;
    setState(() => _playing = next);
    final shot = _current;
    if (shot == null) return;

    if (next) {
      // 从暂停恢复：重新按当前镜安排推进（图片镜按整段时长重计时——
      // 记录"已过多久"对预览没有价值，反而是额外的状态面）。
      _scheduleFallbackAdvance(shot, _epoch);
      if (shot.kind == SequenceArtifactKind.video) {
        unawaited(_handle?.play());
      }
    } else {
      _advanceTimer?.cancel();
      if (shot.kind == SequenceArtifactKind.video) {
        unawaited(_handle?.pause());
      }
    }
  }

  void _step(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= _shots.length) return;
    _enterShot(target);
  }

  void _replay() {
    setState(() => _playing = true);
    _enterShot(0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final l = context.l10n;

    if (_shots.isEmpty) {
      return _Frame(
        child: Center(
          child: Text(
            l.sequencePreviewEmpty,
            style: context.inkTypography.body.copyWith(color: colors.fg2),
          ),
        ),
      );
    }

    return _Frame(
      child: Column(
        children: <Widget>[
          Expanded(child: _stage(context)),
          _ControlsBar(
            index: _index,
            total: _shots.length,
            playing: _playing,
            onPlayPause: _togglePlay,
            onPrevious: _index > 0 ? () => _step(-1) : null,
            onNext: _index < _shots.length - 1 ? () => _step(1) : null,
            onReplay: _replay,
            onClose: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _stage(BuildContext context) {
    final shot = _current;
    if (shot == null) return const SizedBox.shrink();

    switch (shot.kind) {
      case SequenceArtifactKind.none:
        return _NotesPlaceholder(shot: shot);
      case SequenceArtifactKind.video:
        return (_videoReady && _videoController != null)
            ? Video(controller: _videoController!)
            : _NotesPlaceholder(shot: shot, loading: true);
      case SequenceArtifactKind.image:
        final file = _resolve(shot);
        if (file == null) return _NotesPlaceholder(shot: shot, missing: true);
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              _NotesPlaceholder(shot: shot, missing: true),
        );
    }
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceCanvas,
        borderRadius: BorderRadius.circular(InkRadius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InkRadius.lg),
        child: child,
      ),
    );
  }
}

/// 没有产物（或产物读不到）时的画面：显示这一镜的备注，让预览仍然连贯。
class _NotesPlaceholder extends StatelessWidget {
  const _NotesPlaceholder({
    required this.shot,
    this.missing = false,
    this.loading = false,
  });

  final SequenceShot shot;
  final bool missing;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    return Container(
      color: colors.surface1,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(InkSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(
              missing ? Icons.broken_image_outlined : Icons.image_outlined,
              color: colors.fg4,
            ),
          const SizedBox(height: InkSpacing.md),
          Text(
            missing ? l.sequencePreviewMissingFile : l.sequencePreviewNoArtifact,
            style: typo.caption.copyWith(color: colors.fg3),
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
    );
  }
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.index,
    required this.total,
    required this.playing,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onReplay,
    required this.onClose,
  });

  final int index;
  final int total;
  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    return Container(
      color: colors.surface1,
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.md,
        vertical: InkSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: l.sequencePreviewPrevious,
            icon: Icon(Icons.skip_previous,
                color: onPrevious == null ? colors.fg4 : colors.fg1),
            onPressed: onPrevious,
          ),
          IconButton(
            tooltip: l.lightboxPlayPause,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                color: colors.fg1),
            onPressed: onPlayPause,
          ),
          IconButton(
            tooltip: l.sequencePreviewNext,
            icon: Icon(Icons.skip_next,
                color: onNext == null ? colors.fg4 : colors.fg1),
            onPressed: onNext,
          ),
          IconButton(
            tooltip: l.sequencePreviewReplay,
            icon: Icon(Icons.replay, color: colors.fg1),
            onPressed: onReplay,
          ),
          const SizedBox(width: InkSpacing.sm),
          // 进度点：一镜一点，当前镜实心。点数多时横向可滚，不挤压控件。
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < total; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: InkSpacing.xs,
                      ),
                      child: _Dot(active: i == index),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          Text(
            l.sequencePreviewShotCounter(index + 1, total),
            style: typo.caption.copyWith(color: colors.fg2),
          ),
          IconButton(
            tooltip: l.lightboxClose,
            icon: Icon(Icons.close, color: colors.fg1),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  static const double _size = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? colors.accent : colors.fg4,
      ),
    );
  }
}
