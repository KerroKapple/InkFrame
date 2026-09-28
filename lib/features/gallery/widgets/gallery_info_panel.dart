// GalleryInfoPanel：稿的右栏 320 + 1px 左描边——「信息 / 血缘」两个标签 + 内容 + 底部动作条。
//
// 信息：16:9 预览、名称与来源、「生成参数」「提示词」两组（只列仓库有的字段）、血缘列表。
// 血缘：只有血缘列表。底部：「在画布中定位」（次级）。「派生新节点」无后端不画。
// 仓库没有的字段（模型名 / 帧率 / 画幅 / 镜头语言 / 费用 / 裁切）不画——见 PR #235。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/provider_capabilities.dart' show CameraMovement;
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_edge.dart';
import '../../canvas/util/camera_labels.dart';
import '../../shell/models/shell_state.dart';
import '../models/gallery_graph.dart';
import '../models/gallery_item.dart';
import '../providers/gallery_graph_provider.dart';
import '../providers/gallery_view.dart';
import '../util/gallery_meta.dart';
import '../util/gallery_time.dart';
import 'gallery_actions.dart';

class GalleryInfoPanel extends ConsumerStatefulWidget {
  const GalleryInfoPanel({super.key, required this.projectId, required this.projectName});

  final String projectId;
  final String projectName;

  /// 稿是 content-box：width 320 + border-left 1。
  static const double width = 321;

  static const Key locateKey = Key('gallery.info.locate');
  static const Key infoTabKey = Key('gallery.info.tab.info');
  static const Key lineageTabKey = Key('gallery.info.tab.lineage');

  @override
  ConsumerState<GalleryInfoPanel> createState() => _GalleryInfoPanelState();
}

class _GalleryInfoPanelState extends ConsumerState<GalleryInfoPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String projectId = widget.projectId;
    final GalleryItem? item = ref.watch(galleryAnchorItemProvider(projectId));
    final Map<String, GalleryItemMeta> metaMap = ref.watch(galleryMetaProvider(projectId));
    final GalleryItemMeta meta = item == null ? GalleryItemMeta.empty : (metaMap[galleryItemKey(item)] ?? GalleryItemMeta.empty);

    return Container(
      width: GalleryInfoPanel.width,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(left: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Tabs(
            active: _tab,
            labels: <String>[l.galleryPanelInfo, l.galleryPanelLineage],
            keys: const <Key>[GalleryInfoPanel.infoTabKey, GalleryInfoPanel.lineageTabKey],
            onTap: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: item == null
                ? Padding(
                    padding: const EdgeInsets.all(InkSpacing.s12),
                    child: Text(l.galleryNoSelection, style: t.meta.copyWith(color: c.fg6)),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      if (_tab == 0) ...<Widget>[
                        _Preview(projectId: projectId, item: item),
                        _Heading(projectId: projectId, item: item, meta: meta),
                        _ParamsGroup(item: item, meta: meta),
                        _PromptGroup(meta: meta),
                      ],
                      _LineageBlock(projectId: projectId, item: item),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s10),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(top: BorderSide(color: c.borderStrong)),
            ),
            child: Row(
              children: <Widget>[
                Semantics(
                  button: true,
                  enabled: item != null,
                  label: l.galleryLocateInCanvas,
                  child: MouseRegion(
                    cursor: item == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
                    child: GestureDetector(
                      key: GalleryInfoPanel.locateKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: item == null
                          ? null
                          : () => galleryLocateInCanvas(
                                ref,
                                project: ProjectRef(id: projectId, name: widget.projectName),
                                item: item,
                              ),
                      child: Opacity(
                        opacity: item == null ? 0.5 : 1,
                        child: WsSecondaryButton(l.galleryLocateInCanvas, height: 26),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 28px 标签条：选中项 surface3 底 + 1px 琥珀上沿（与 WsPanelTabs 同形，多了点击）。
class _Tabs extends StatelessWidget {
  const _Tabs({required this.active, required this.labels, required this.keys, required this.onTap});
  final int active;
  final List<String> labels;
  final List<Key> keys;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: WsPanelTabs.height,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            Semantics(
              button: true,
              selected: i == active,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: keys[i],
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                    alignment: Alignment.center,
                    decoration: i == active
                        ? BoxDecoration(color: c.surface3, border: Border(top: BorderSide(color: c.accent)))
                        : null,
                    child: Text(
                      labels[i],
                      style: i == active ? t.bodyStrong.copyWith(color: c.fg1) : t.body.copyWith(color: c.fg5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.projectId, required this.item});
  final String projectId;
  final GalleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final String? rel = item.kind == GalleryItemKind.video ? item.thumbnailRelativePath : item.relativePath;
    final File? file = rel == null
        ? null
        : galleryResolveFile(ref, projectId: projectId, canvasId: item.canvasId, relativePath: rel);
    return Padding(
      padding: const EdgeInsets.all(InkSpacing.s12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.thumbFill,
            border: Border.all(color: c.outline),
            borderRadius: BorderRadius.circular(InkRadius.s3),
          ),
          child: file == null
              ? Center(child: Icon(Icons.videocam_outlined, color: c.fg5, size: 20))
              : Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(child: Icon(Icons.broken_image_outlined, color: c.fg5, size: 20)),
                ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.projectId, required this.item, required this.meta});
  final String projectId;
  final GalleryItem item;
  final GalleryItemMeta meta;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String name = meta.label.isNotEmpty ? meta.label : item.relativePath;
    return Padding(
      padding: const EdgeInsets.fromLTRB(InkSpacing.s12, 0, InkSpacing.s12, InkSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg1)),
          const SizedBox(height: InkSpacing.xs),
          Text(
            l.gallerySourceLine(item.canvasName, galleryTimeAgo(l, item.createdAt, DateTime.now().toUtc())),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.meta.copyWith(color: c.fg6),
          ),
        ],
      ),
    );
  }
}

/// 26px 组标题（▼ + 标题），上沿 1px 描边。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      child: Row(
        children: <Widget>[
          Text('▼', style: t.micro.copyWith(color: c.fg5)),
          const SizedBox(width: InkSpacing.s6),
          Text(title, style: t.bodyStrong.copyWith(color: c.fg3)),
        ],
      ),
    );
  }
}

/// 稿：grid 84px 1fr，gap 8，min-height 24 + padding 2 12（content-box ⇒ 外框最小 28）。
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          SizedBox(width: 84, child: Text(label, style: t.body.copyWith(color: c.fg4))),
          const SizedBox(width: InkSpacing.sm),
          Expanded(child: Text(value, style: t.body.copyWith(color: c.fg2))),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _GroupHeader(title: title),
          Padding(
            padding: const EdgeInsets.only(top: InkSpacing.s2, bottom: InkSpacing.s10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
          ),
        ],
      ),
    );
  }
}

String galleryRoleLabel(AppLocalizations l, EdgeRole role) => switch (role) {
      EdgeRole.firstFrame => l.inspectorRoleFirstFrame,
      EdgeRole.lastFrame => l.inspectorRoleLastFrame,
      EdgeRole.reference => l.inspectorRoleReference,
    };

class _ParamsGroup extends ConsumerWidget {
  const _ParamsGroup({required this.item, required this.meta});
  final GalleryItem item;
  final GalleryItemMeta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final Map<String, String> providerNames = ref.watch(providerDisplayNamesProvider);
    final CameraMovement? camera = meta.cameraName == null ? null : _parseCamera(meta.cameraName!);
    final List<Widget> rows = <Widget>[
      if (meta.providerId != null)
        _MetaRow(label: l.galleryParamProvider, value: providerNames[meta.providerId!] ?? meta.providerId!),
      if (item.durationMs != null)
        _MetaRow(label: l.galleryParamDuration, value: galleryFormatDuration(item.durationMs!)),
      if (camera != null) _MetaRow(label: l.galleryParamCamera, value: cameraMovementLabel(context, camera)),
      if (meta.keyframes.isNotEmpty)
        _MetaRow(
          label: l.galleryParamKeyframes,
          value: meta.keyframes
              .map((GalleryKeyframeRef k) => l.galleryKeyframeRef(galleryRoleLabel(l, k.role), k.sourceLabel))
              .join(' · '),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Group(title: l.galleryGroupParams, rows: rows);
  }

  static CameraMovement? _parseCamera(String raw) {
    for (final CameraMovement c in CameraMovement.values) {
      if (c.name == raw) return c;
    }
    return null;
  }
}

class _PromptGroup extends StatelessWidget {
  const _PromptGroup({required this.meta});
  final GalleryItemMeta meta;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final String? prompt = meta.prompt;
    final List<Widget> rows = <Widget>[
      if (prompt != null && prompt.trim().isNotEmpty) _MetaRow(label: l.galleryParamPrompt, value: prompt),
      if (meta.baseStylePrefix.trim().isNotEmpty) _MetaRow(label: l.galleryParamBaseStyle, value: meta.baseStylePrefix),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Group(title: l.galleryGroupPrompt, rows: rows);
  }
}

/// 血缘 · 当前线：padding 12、行距 10；行 = 40×24 缩略图 + 名称 11px / 关系 10px + 右侧分支数。
class _LineageBlock extends ConsumerWidget {
  const _LineageBlock({required this.projectId, required this.item});
  final String projectId;
  final GalleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final GalleryGraph graph = ref.watch(galleryGraphProvider(projectId)).valueOrNull ?? GalleryGraph.empty;
    final GalleryIndex index = ref.watch(galleryIndexProvider(projectId));
    final List<GalleryLineageRow> rows = galleryLineageFor(graph, index, item);
    return Container(
      padding: const EdgeInsets.all(InkSpacing.s12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.galleryLineageTitle, style: t.body.copyWith(color: c.fg4)),
          for (final GalleryLineageRow r in rows) ...<Widget>[
            const SizedBox(height: InkSpacing.s10),
            _LineageRowView(projectId: projectId, row: r),
          ],
        ],
      ),
    );
  }
}

class _LineageRowView extends ConsumerWidget {
  const _LineageRowView({required this.projectId, required this.row});
  final String projectId;
  final GalleryLineageRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final bool current = row.kind == GalleryLineageKind.current;
    final String rel = switch (row.kind) {
      GalleryLineageKind.shotText => l.galleryLineageShotText,
      GalleryLineageKind.input => <String>[
          galleryRoleLabel(l, row.role ?? EdgeRole.reference),
          if (row.resultCount > 1) l.galleryLineageChosenOf(row.resultCount),
        ].join(' · '),
      GalleryLineageKind.current => <String>[
          l.galleryLineageCurrent,
          if (row.sequenceIndex != null) l.galleryLineageInSequence(row.sequenceIndex!.toString().padLeft(3, '0')),
        ].join(' · '),
    };
    final File? file = row.thumbRelativePath == null || row.thumbCanvasId == null
        ? null
        : galleryResolveFile(ref, projectId: projectId, canvasId: row.thumbCanvasId!, relativePath: row.thumbRelativePath!);
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 24,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface4,
            border: Border.all(color: current ? c.accent : c.outline),
            borderRadius: BorderRadius.circular(InkRadius.xs),
          ),
          child: file == null
              ? null
              : Image.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        ),
        const SizedBox(width: InkSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.meta.copyWith(color: current ? c.fg1 : c.fg4)),
              // 稿里这行 10px 继承 1.45 行高（实测行距 16 / 15），不是 micro 的 1.3。
              Text(rel, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.micro.copyWith(color: c.fg6, height: 1.45)),
            ],
          ),
        ),
        if (row.branches > 0) ...<Widget>[
          const SizedBox(width: InkSpacing.s10),
          Text(l.galleryLineageBranches(row.branches), style: t.micro.copyWith(color: c.fg5)),
        ],
      ],
    );
  }
}
