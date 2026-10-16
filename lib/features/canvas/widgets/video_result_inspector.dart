// VideoResultInspector：单选 video result 节点时的结果面板（演示里的 F2：此前检查器对视频产物整块留空）。
//
// 与 ImageResultInspector 同构，三段共用件都在 result_inspector_parts.dart：
//   1. 16:9 预览：首帧缩略图（type_config.thumbnail_url，落盘时由抽帧探针写）+ 居中播放浮标；
//      还没出片 ⇒「等待生成」；有片没抽到首帧 ⇒ 只画播放图标。文件在的话点预览 = 播放。
//   2. 「生成参数」组（来源 config 的供应商 / 运镜 / 镜头语言 / 提示词 + 产物探针的尺寸 / 时长）。
//   3. 动作行：播放 / 定位来源节点 / 在序列中定位。
//
// 「能不能播」只认 playableVideoPathProvider（与画布上点视频卡开灯箱同一个判据，IO 不进 build）；
// 播放走 showVideoLightbox，与画布同一个灯箱。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../models/canvas_node.dart';
import '../providers/playable_video_path.dart';
import 'result_inspector_parts.dart';
import 'video_lightbox.dart';

class VideoResultInspector extends ConsumerWidget {
  const VideoResultInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? playable = ref.watch(playableVideoPathProvider(node));
    final VoidCallback? play =
        playable == null ? null : () => showVideoLightbox(context, videoPath: playable);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ResultPreviewFrame(
          onTap: play,
          semanticLabel: context.l10n.inspectorResultPlay,
          child: _preview(context),
        ),
        ResultParamsGroup(node: node),
        ResultActions(node: node, showPlay: true, onPlay: play),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    final l = context.l10n;
    if (node.videoUrl == null) {
      return ResultPreviewPlaceholder(icon: Icons.hourglass_empty_outlined, text: l.resultNodePending);
    }
    final String? thumb = node.thumbnailUrl;
    if (thumb == null) return const ResultPreviewPlaceholder(icon: Icons.play_circle_outline);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ResultFileImage(node: node, relativePath: thumb),
        Center(child: Icon(Icons.play_circle_outline, size: 40, color: context.inkColors.fg1)),
      ],
    );
  }
}
