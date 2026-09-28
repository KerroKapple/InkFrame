// 命令面板的跨实体搜索（IA 断点 B5）：
//   镜头 · 当前画布   只搜当前画布里【已加载】的 config 节点（不为搜索去读库；跨画布搜索记 BOARD）
//   产物             当前项目的画廊产物（galleryController：项目级一次聚合，不是全量索引）
//   动作             原来的上下文动作（buildCommandActions 的 ≤6 条，原样并入）
// 查询为空时只列动作（与旧面板一致）；镜头 / 产物是搜索结果，要有查询词才出现。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_x.dart';
import '../canvas/models/canvas_edge.dart';
import '../canvas/models/canvas_node.dart';
import '../canvas/providers/canvas_edges_controller.dart';
import '../canvas/providers/canvas_nodes_controller.dart';
import '../canvas/providers/canvas_selection_controller.dart';
import '../canvas/providers/current_canvas_name.dart';
import '../canvas/util/narrative_order.dart';
import '../canvas/util/node_artifacts.dart';
import '../canvas/widgets/node_card.dart' show nodeDisplayName, nodeTypeLabel;
import '../gallery/models/gallery_item.dart';
import '../gallery/models/gallery_selection.dart';
import '../gallery/providers/gallery_controller.dart';
import '../gallery/providers/gallery_selection.dart';
import '../gallery/providers/gallery_view.dart';
import '../gallery/util/gallery_meta.dart';
import '../gallery/widgets/gallery_actions.dart';
import '../shell/models/shell_state.dart';
import '../shell/providers/shell_controller.dart';
import 'command_actions.dart';
import 'palette_entry.dart';

/// 在面板 build 里调用（用 ref.watch：产物聚合就绪时结果跟着刷新）。
List<PaletteEntry> buildPaletteEntries(BuildContext context, WidgetRef ref, String query) {
  final String q = query.trim().toLowerCase();
  final AppLocalizations l = context.l10n;
  final ShellState s = ref.watch(shellControllerProvider);
  final List<PaletteEntry> out = <PaletteEntry>[];

  if (q.isNotEmpty && s.overlay == null) {
    out.addAll(_shotEntries(context, ref, l, s, q));
    out.addAll(_artifactEntries(context, ref, l, s, q));
  }

  for (final CommandAction a in buildCommandActions(context, ref)) {
    if (q.isNotEmpty && !a.label.toLowerCase().contains(q)) continue;
    out.add(PaletteEntry(
      group: PaletteGroup.actions,
      id: 'action:${a.id}',
      name: a.label,
      path: _tabLabel(l, s),
      icon: a.icon,
      run: a.run,
    ));
  }
  return out;
}

String _tabLabel(AppLocalizations l, ShellState s) => switch (s.overlay) {
      ShellOverlay.settings => l.settingsTitle,
      ShellOverlay.showcase => l.showcaseEntryLabel,
      null => switch (s.tab) {
          ShellTab.studio => l.shellTabStudio,
          ShellTab.canvas => l.shellTabCanvas,
          ShellTab.sequence => l.shellTabSequence,
          ShellTab.gallery => l.shellTabGallery,
          ShellTab.export => l.shellTabExport,
        },
    };

List<PaletteEntry> _shotEntries(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
  ShellState s,
  String q,
) {
  final String? canvasId = s.canvasId;
  if (s.tab != ShellTab.canvas || canvasId == null) return const <PaletteEntry>[];
  // 只用已加载的：valueOrNull 为 null（还没进过画布）就不出这一组，不为搜索去读库。
  final List<CanvasNode>? nodes = ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull;
  if (nodes == null) return const <PaletteEntry>[];
  final String canvasName = ref.watch(currentCanvasNameProvider).valueOrNull ?? l.canvasDefaultName;
  final String project = s.project?.name ?? l.shellBreadcrumbNoProject;
  // 路径第三段：在叙事链上的镜写「序列 003」（与画廊「已入序列」同一判据：narrative 边两端
  // 都在场的节点才算链上），其余写节点类型。边也是画布已加载的，只遍历内存，不读库。
  final List<CanvasEdge> edges = ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ?? const <CanvasEdge>[];
  final Map<String, int> sequenceIndex = _sequenceIndexByNode(nodes, edges);
  final List<PaletteEntry> out = <PaletteEntry>[];
  for (final CanvasNode n in nodes) {
    if (n.role != NodeRole.config) continue;
    final String name = nodeDisplayName(context, n);
    if (!name.toLowerCase().contains(q)) continue;
    final int? seq = sequenceIndex[n.id];
    final String third = seq == null
        ? nodeTypeLabel(context, n.type)
        : l.commandPaletteSequenceSegment(seq.toString().padLeft(3, '0'));
    final CanvasNode? latest = latestResultFor(sourceNodeId: n.id, nodes: nodes);
    final String? thumbRel = latest?.thumbnailUrl ?? latest?.imageUrl;
    final File? thumb = thumbRel == null || s.project == null
        ? null
        : galleryResolveFile(ref, projectId: s.project!.id, canvasId: canvasId, relativePath: thumbRel);
    Future<void> select(BuildContext _, WidgetRef ref) async {
      ref.read(canvasSelectionControllerProvider(canvasId).notifier).select(n.id);
    }

    out.add(PaletteEntry(
      group: PaletteGroup.shots,
      id: 'shot:${n.id}',
      name: name,
      path: l.commandPaletteShotPath(project, canvasName, third),
      thumbFile: thumb,
      run: select,
      locate: select,
    ));
  }
  return out;
}

/// 链上节点 → 1 起的序列号。链成员 = narrative 边两端都在 [nodes] 里的节点；顺序 = 叙事链序。
Map<String, int> _sequenceIndexByNode(List<CanvasNode> nodes, List<CanvasEdge> edges) {
  final Set<String> ids = <String>{for (final CanvasNode n in nodes) n.id};
  final Set<String> members = <String>{};
  for (final CanvasEdge e in edges) {
    if (e.edgeType != EdgeType.narrative) continue;
    if (!ids.contains(e.sourceNodeId) || !ids.contains(e.targetNodeId)) continue;
    members..add(e.sourceNodeId)..add(e.targetNodeId);
  }
  if (members.isEmpty) return const <String, int>{};
  final List<CanvasNode> ordered = orderByNarrativeChain(
    nodes: nodes,
    edges: edges,
    include: (CanvasNode n) => members.contains(n.id),
  );
  return <String, int>{for (int i = 0; i < ordered.length; i++) ordered[i].id: i + 1};
}

List<PaletteEntry> _artifactEntries(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
  ShellState s,
  String q,
) {
  final ProjectRef? project = s.project;
  if (project == null) return const <PaletteEntry>[];
  final List<GalleryItem>? items = ref.watch(galleryControllerProvider(project.id)).valueOrNull;
  if (items == null) return const <PaletteEntry>[];
  final Map<String, GalleryItemMeta> meta = ref.watch(galleryMetaProvider(project.id));
  final Map<String, String> providerNames = ref.watch(providerDisplayNamesProvider);
  final List<PaletteEntry> out = <PaletteEntry>[];
  for (final GalleryItem item in items) {
    final String key = galleryItemKey(item);
    final GalleryItemMeta m = meta[key] ?? GalleryItemMeta.empty;
    final String name = m.label.isNotEmpty ? m.label : item.relativePath;
    if (!name.toLowerCase().contains(q)) continue;
    final String kind = switch (item.kind) {
      GalleryItemKind.image => l.galleryKindImage,
      GalleryItemKind.video => l.galleryKindVideo,
    };
    final String provider = m.providerId == null ? '—' : (providerNames[m.providerId!] ?? m.providerId!);
    final String? thumbRel = item.kind == GalleryItemKind.video ? item.thumbnailRelativePath : item.relativePath;
    final File? thumb = thumbRel == null
        ? null
        : galleryResolveFile(ref, projectId: project.id, canvasId: item.canvasId, relativePath: thumbRel);
    out.add(PaletteEntry(
      group: PaletteGroup.artifacts,
      id: 'artifact:$key',
      name: name,
      path: l.commandPaletteArtifactPath(kind, provider),
      thumbFile: thumb,
      // ↵ 打开：到画廊并选中它。
      run: (BuildContext _, WidgetRef ref) async => _openInGallery(ref, project: project, key: key),
      // ⌘↵：打开它所在的画布并选中节点。
      locate: (BuildContext _, WidgetRef ref) async => galleryLocateInCanvas(ref, project: project, item: item),
    ));
  }
  return out;
}

void _openInGallery(WidgetRef ref, {required ProjectRef project, required String key}) {
  ref.read(shellControllerProvider.notifier).openGallery(project);
  ref.read(gallerySelectionProvider(project.id).notifier).state = GallerySelection.none.select(key);
}
