// 产物检查器（image / video result）共用的三段：预览框、「生成参数」组、动作行。
//
// ImageResultInspector 与 VideoResultInspector 都由这三段拼出来，不各写一份：
//   - [ResultPreviewFrame]  16:9 预览框（thumbFill 底 + outline 边 + 3px 圆角），内容由调用方给；
//     [ResultFileImage] 把产物的相对路径解析成图，[ResultPreviewPlaceholder] 是没有图时的占位。
//   - [ResultParamsGroup]   「生成参数」：取值走 util/result_params.dart（与画廊信息面板同一口径）。
//   - [ResultActions]       「设为当前」（排最前；已是当前打勾置灰，没有来源置灰）/「定位来源节点」/
//                           「在序列中定位」，video 再多一个「播放」（排在「设为当前」之后）。
//
// 没有 canvasId 的节点（单测里的裸节点）找不到来源、也谈不上定位：参数组只剩产物自己那几项，
// 动作行不画——不为此去读任何仓储。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/di/providers.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_primitives.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../gallery/util/gallery_time.dart';
import '../../sequence/providers/sequence_lens_provider.dart';
import '../../sequence/util/shot_index.dart';
import '../../sequence/util/view_in_sequence.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/current_take_controller.dart';
import '../util/camera_labels.dart';
import '../util/result_params.dart';
import '../util/take_status.dart';
import 'image_config_inspector.dart' show aspectRatioLabel;
import 'inspector_rows.dart';
import 'left_rail/left_rail_actions.dart';

/// 产物检查器的测试锚点。
abstract final class ResultInspectorKeys {
  static const Key preview = Key('inspector.result.preview');
  static const Key params = Key('inspector.result.params');
  static const Key prompt = Key('inspector.result.params.prompt');
  static const Key locateSource = Key('inspector.result.locateSource');
  static const Key viewInSequence = Key('inspector.result.viewInSequence');
  static const Key play = Key('inspector.result.play');
  static const Key setCurrent = Key('inspector.result.setCurrent');
}

/// 某个画布此刻的节点表；没有 canvasId 就是空表（不读仓储）。
List<CanvasNode> _canvasNodesOf(WidgetRef ref, CanvasNode node) {
  final String? canvasId = node.canvasId;
  if (canvasId == null) return const <CanvasNode>[];
  return ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
}

/// 16:9 预览框。[onTap] 非空时整框可点（可聚焦、回车同效），[semanticLabel] 是它的无障碍标签。
class ResultPreviewFrame extends StatelessWidget {
  const ResultPreviewFrame({super.key, required this.child, this.onTap, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final Widget frame = AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.thumbFill,
          border: Border.all(color: c.outline),
          borderRadius: BorderRadius.circular(InkRadius.s3),
        ),
        child: child,
      ),
    );
    return Padding(
      key: ResultInspectorKeys.preview,
      padding: const EdgeInsets.all(InkSpacing.s12),
      child: onTap == null
          ? frame
          : InkActivatable(
              onTap: onTap,
              semanticLabel: semanticLabel,
              focusRingRadius: BorderRadius.circular(InkRadius.s3),
              builder: (BuildContext context, bool hovered, bool focused) => frame,
            ),
    );
  }
}

/// 预览框里「没有图」时的占位：居中图标 + 可选一行说明。
class ResultPreviewPlaceholder extends StatelessWidget {
  const ResultPreviewPlaceholder({super.key, required this.icon, this.text});

  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final String? caption = text;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: c.fg5, size: InkSpacing.s20),
          if (caption != null) ...<Widget>[
            const SizedBox(height: InkSpacing.xs),
            Text(caption, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: t.meta.copyWith(color: c.fg5)),
          ],
        ],
      ),
    );
  }
}

/// 产物 [node] 名下一张相对路径 [relativePath] 的图（image 产物本身 / video 产物的首帧缩略）。
/// 缺 projectId / canvasId、越权路径、文件坏了 ⇒ 坏图占位，预览框绝不因此崩。
class ResultFileImage extends ConsumerWidget {
  const ResultFileImage({super.key, required this.node, required this.relativePath});

  final CanvasNode node;
  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? projectId = node.projectId;
    final String? canvasId = node.canvasId;
    final Widget broken =
        ResultPreviewPlaceholder(icon: Icons.broken_image_outlined, text: context.l10n.resultNodeImageMissing);
    if (projectId == null || canvasId == null) return broken;
    try {
      final file = ref.read(fileResolverServiceProvider).resolve(
            projectId: projectId,
            canvasId: canvasId,
            relativePath: relativePath,
          );
      // LB-23：按预览框实际宽度解码，不把原图全尺寸塞进 image cache。
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double w = constraints.maxWidth.isFinite ? constraints.maxWidth : kNodeCardSize.width;
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, _, _) => broken,
          );
        },
      );
    } on PathSecurityError {
      return broken;
    }
  }
}

/// 「生成参数」组：供应商 / 分辨率 / 画幅 / 尺寸 / 时长 / 运镜 / 镜头语言 / 种子 / 提示词，有哪项画哪项；
/// 一项都没有就不占位。
class ResultParamsGroup extends ConsumerWidget {
  const ResultParamsGroup({super.key, required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.inkColors;
    final t = context.inkTypography;
    final CanvasNode? source = resultSourceNode(node, _canvasNodesOf(ref, node));
    final ResultParams p = resultParamsOf(node, source);
    final Map<String, String> providerNames = ref.watch(providerDisplayNamesProvider);
    final String shotLanguage = p.shotLanguage.isEmpty ? '' : shotLanguageSummary(context, p.shotLanguage);
    final String? prompt = p.prompt;
    final List<Widget> rows = <Widget>[
      if (p.providerId != null)
        InspectorRow(
          label: l.inspectorProviderLabel,
          child: InspectorValue(providerNames[p.providerId!] ?? p.providerId!),
        ),
      if (p.resolution != null)
        InspectorRow(label: l.inspectorResolutionLabel, child: InspectorValue(p.resolution!, mono: true)),
      if (p.aspectRatio != null)
        InspectorRow(
          label: l.inspectorAspectRatioLabel,
          child: InspectorValue(aspectRatioLabel(p.aspectRatio!), mono: true),
        ),
      if (p.hasDimensions)
        InspectorRow(
          label: l.inspectorResultDimensionsLabel,
          // 「宽×高」是格式量，不是散文，不入 ARB（与画幅 "16:9" 同一口径）。
          child: InspectorValue('${p.width}×${p.height}', mono: true),
        ),
      if (p.durationMs != null)
        InspectorRow(
          label: l.galleryParamDuration,
          child: InspectorValue(galleryFormatDuration(p.durationMs!), mono: true),
        ),
      if (p.camera != null)
        InspectorRow(label: l.galleryParamCamera, child: InspectorValue(cameraMovementLabel(context, p.camera!))),
      if (shotLanguage.isNotEmpty)
        InspectorRow(label: l.galleryParamShotLanguage, child: InspectorValue(shotLanguage)),
      if (p.seed != null)
        InspectorRow(label: l.inspectorSeedLabel, child: InspectorValue('${p.seed}', mono: true)),
      if (prompt != null)
        InspectorRow(
          label: l.inspectorPromptLabel,
          height: null,
          child: Padding(
            padding: const EdgeInsets.only(top: InkSpacing.xs),
            child: Text(
              prompt,
              key: ResultInspectorKeys.prompt,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: c.fg2),
            ),
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return InspectorGroup(key: ResultInspectorKeys.params, title: l.galleryGroupParams, children: rows);
  }
}

/// 动作行：「设为当前」（排最前；已是当前 ⇒ 打勾置灰；孤儿 / 来源已删 ⇒ 置灰；走 currentTakeControllerProvider）
/// /「定位来源节点」（来源 config 还在才可点）/「在序列中定位」（产物落在叙事链某一镜上才可点）
/// / [onPlay] 非空时多一个「播放」。不可用的置灰不隐藏，与节点右键菜单同一口径。
class ResultActions extends ConsumerWidget {
  const ResultActions({super.key, required this.node, this.onPlay, this.showPlay = false});

  final CanvasNode node;

  /// 是否画「播放」（video 产物）；画了但 [onPlay] 为 null ⇒ 置灰（文件不在）。
  final bool showPlay;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? canvasId = node.canvasId;
    if (canvasId == null) return const SizedBox.shrink();
    final l = context.l10n;
    final List<CanvasNode> nodes = _canvasNodesOf(ref, node);
    final CanvasNode? source = resultSourceNode(node, nodes);
    final Set<String> self = <String>{node.id};
    final bool inSequence =
        shotIndexForSelection(ref.watch(sequenceLensProvider(canvasId)), selection: self, nodes: nodes) >= 0;
    // 来源配置不在（孤儿 / 已删）⇒ status 为 null，置灰不打勾；已是当前 ⇒ 打勾置灰。
    final ResultTakeStatus? take = source == null ? null : resultTakeStatusOf(node, nodes);
    final bool isCurrent = take?.current ?? false;
    return Padding(
      padding: const EdgeInsets.all(InkSpacing.s12),
      child: Wrap(
        spacing: InkSpacing.sm,
        runSpacing: InkSpacing.sm,
        children: <Widget>[
          _ActionButton(
            key: ResultInspectorKeys.setCurrent,
            label: l.takeSetCurrent,
            glyph: isCurrent ? InkGlyph.success : InkGlyph.pin,
            checked: isCurrent,
            onTap: take == null || isCurrent
                ? null
                : () => ref.read(currentTakeControllerProvider(canvasId)).setCurrent(node.id, l: l).ignore(),
          ),
          if (showPlay)
            _ActionButton(
              key: ResultInspectorKeys.play,
              label: l.inspectorResultPlay,
              glyph: InkGlyph.run,
              onTap: onPlay,
            ),
          _ActionButton(
            key: ResultInspectorKeys.locateSource,
            label: l.inspectorResultLocateSource,
            onTap: source == null ? null : () => focusNodeOnCanvas(ref, canvasId: canvasId, node: source),
          ),
          _ActionButton(
            key: ResultInspectorKeys.viewInSequence,
            label: l.canvasNodeMenuLocateInSequence,
            glyph: InkGlyph.sequence,
            onTap: inSequence ? () => viewInSequence(ref, canvasId: canvasId, nodeIds: self) : null,
          ),
        ],
      ),
    );
  }
}

/// 次级按钮 + InkActivatable 点击壳（可 Tab 聚焦、回车同效）；[onTap] 为 null ⇒ 置灰、不可点也不可聚焦。
/// [checked]：「现在就是这样」（如「设为当前」时它已是当前）——调用方把 [glyph] 换成打勾（InkGlyph.success，与
/// InkMenuPanel 的打勾行同一个图标；图标集 v1 没有 check）并给 null 的 [onTap]，整颗置灰。
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.glyph,
    this.checked = false,
  });

  final String label;
  final InkGlyph? glyph;
  final VoidCallback? onTap;
  final bool checked;

  @override
  Widget build(BuildContext context) => InkActivatable(
        onTap: checked ? null : onTap,
        semanticLabel: label,
        selected: checked ? true : null,
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) => Opacity(
          opacity: onTap == null || checked ? 0.5 : 1,
          child: InkSecondaryButton(label, leading: glyph),
        ),
      );
}
