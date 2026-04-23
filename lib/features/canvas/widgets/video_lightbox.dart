// VideoLightbox：Dialog 形式全屏视频播放器。
//
// 入口：showVideoLightbox(context, videoPath: <绝对路径>)
// 内部：create VideoPlayerHandle → open → Video widget 渲染 → 底部控制条 →
//       关闭时 dispose。
//
// 测试：由于 media_kit 播放需 GPU / 原生层，widget test 里不真跑；用 Fake
// VideoPlayerService 替代 → 手动回归覆盖真实播放。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show Player;
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/di/video_player.dart';
import '../../../core/interfaces/video_player_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

Future<void> showVideoLightbox(
  BuildContext context, {
  required String videoPath,
}) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(InkSpacing.xl),
        backgroundColor: Colors.transparent,
        child: VideoLightboxContent(videoPath: videoPath),
      ),
    );

class VideoLightboxContent extends ConsumerStatefulWidget {
  const VideoLightboxContent({super.key, required this.videoPath});
  final String videoPath;

  @override
  ConsumerState<VideoLightboxContent> createState() =>
      _VideoLightboxState();
}

class _VideoLightboxState extends ConsumerState<VideoLightboxContent> {
  late final VideoPlayerHandle _handle;
  VideoController? _videoController;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _handle = ref.read(videoPlayerServiceProvider).create();
    final raw = _handle.rawPlayer;
    if (raw is Player) {
      _videoController = VideoController(raw);
    }
    _handle.open(widget.videoPath).then((_) {
      if (mounted) setState(() => _opened = true);
    });
  }

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: (_opened && _videoController != null)
                  ? Video(controller: _videoController!)
                  : Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
            ),
            _ControlsBar(handle: _handle),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            tooltip: context.l10n.lightboxClose,
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({required this.handle});
  final VideoPlayerHandle handle;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Container(
      color: colors.surface1.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.md,
        vertical: InkSpacing.sm,
      ),
      child: Row(
        children: [
          StreamBuilder<bool>(
            stream: handle.playingStream,
            builder: (context, snap) {
              final playing = snap.data ?? false;
              return IconButton(
                tooltip: context.l10n.lightboxPlayPause,
                icon: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: colors.fg1,
                ),
                onPressed: () =>
                    playing ? handle.pause() : handle.play(),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: handle.positionStream,
              builder: (context, posSnap) {
                return StreamBuilder<Duration?>(
                  stream: handle.durationStream,
                  builder: (context, durSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final dur = durSnap.data ?? Duration.zero;
                    final total =
                        dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
                    return Slider(
                      value: pos.inMilliseconds.clamp(0, total).toDouble(),
                      max: total.toDouble(),
                      onChanged: (v) =>
                          handle.seek(Duration(milliseconds: v.toInt())),
                    );
                  },
                );
              },
            ),
          ),
          StreamBuilder<Duration>(
            stream: handle.positionStream,
            builder: (context, posSnap) {
              return StreamBuilder<Duration?>(
                stream: handle.durationStream,
                builder: (context, durSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final dur = durSnap.data ?? Duration.zero;
                  return Text(
                    '${_fmt(pos)} / ${_fmt(dur)}',
                    style: TextStyle(color: colors.fg1),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
