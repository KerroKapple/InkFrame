// GalleryFilterPanel：稿的左栏四组（范围 / 类型 / 模型 / 标记），220 + 1px 右描边。
//
// 每组：26px 标题行（▼ + 标题）+ 24px 行（缩进 26，右侧等宽计数），分组底 1px 描边。
// 计数是**全量**产物按该项的命中数（稿上就是这么标的），不是当前筛选后的。
// 范围组的「本项目全部」= canvasId 为空；其余三组点已选中的行即取消（稿上没有「全部」行）。
// 「角色参考」类型与「收藏」标记无字段，不画。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/gallery_graph.dart';
import '../models/gallery_item.dart';
import '../providers/gallery_controller.dart';
import '../providers/gallery_filter.dart';
import '../providers/gallery_graph_provider.dart';
import '../providers/gallery_view.dart';
import '../util/gallery_meta.dart';

class GalleryFilterPanel extends ConsumerWidget {
  const GalleryFilterPanel({super.key, required this.projectId});

  final String projectId;

  /// 稿是 content-box：width 220 + border-right 1。
  static const double width = 221;

  static Key rowKey(String group, String value) => ValueKey<String>('gallery.filter.$group.$value');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final l = context.l10n;
    final List<GalleryItem> items =
        ref.watch(galleryControllerProvider(projectId)).valueOrNull ?? const <GalleryItem>[];
    final Map<String, GalleryItemMeta> meta = ref.watch(galleryMetaProvider(projectId));
    final GalleryGraph graph = ref.watch(galleryGraphProvider(projectId)).valueOrNull ?? GalleryGraph.empty;
    final GalleryFilter filter = ref.watch(galleryFilterProvider(projectId));
    final StateController<GalleryFilter> notifier = ref.read(galleryFilterProvider(projectId).notifier);
    final Map<String, String> providerNames = ref.watch(providerDisplayNamesProvider);

    int count(bool Function(GalleryItem i, GalleryItemMeta m) test) {
      int n = 0;
      for (final GalleryItem i in items) {
        if (test(i, meta[galleryItemKey(i)] ?? GalleryItemMeta.empty)) n++;
      }
      return n;
    }

    // 模型组：出现过的 providerId，按显示名排。
    final List<String> providerIds = <String>{
      for (final GalleryItem i in items)
        if (meta[galleryItemKey(i)]?.providerId != null) meta[galleryItemKey(i)]!.providerId!,
    }.toList()
      ..sort((a, b) => (providerNames[a] ?? a).compareTo(providerNames[b] ?? b));

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _Group(
            title: l.galleryFilterGroupScope,
            rows: <_RowSpec>[
              _RowSpec(
                key: rowKey('scope', 'all'),
                name: l.galleryFilterAllInProject,
                count: items.length,
                selected: filter.canvasId == null,
                onTap: () => notifier.state = filter.copyWith(canvasId: () => null),
              ),
              for (final GalleryCanvasInfo cv in graph.canvases)
                _RowSpec(
                  key: rowKey('scope', cv.id),
                  name: cv.name.isEmpty ? l.canvasDefaultName : cv.name,
                  count: count((GalleryItem i, _) => i.canvasId == cv.id),
                  selected: filter.canvasId == cv.id,
                  onTap: () => notifier.state = filter.copyWith(canvasId: () => cv.id),
                ),
            ],
          ),
          _Group(
            title: l.galleryFilterGroupType,
            rows: <_RowSpec>[
              for (final GalleryItemKind k in GalleryItemKind.values)
                _RowSpec(
                  key: rowKey('type', k.name),
                  name: switch (k) {
                    GalleryItemKind.image => l.galleryKindImage,
                    GalleryItemKind.video => l.galleryKindVideo,
                  },
                  count: count((GalleryItem i, _) => i.kind == k),
                  selected: filter.kind == k,
                  onTap: () => notifier.state = filter.copyWith(kind: () => filter.kind == k ? null : k),
                ),
            ],
          ),
          if (providerIds.isNotEmpty)
            _Group(
              title: l.galleryFilterGroupModel,
              rows: <_RowSpec>[
                for (final String p in providerIds)
                  _RowSpec(
                    key: rowKey('model', p),
                    name: providerNames[p] ?? p,
                    count: count((_, GalleryItemMeta m) => m.providerId == p),
                    selected: filter.providerId == p,
                    onTap: () => notifier.state =
                        filter.copyWith(providerId: () => filter.providerId == p ? null : p),
                  ),
              ],
            ),
          _Group(
            title: l.galleryFilterGroupMark,
            rows: <_RowSpec>[
              _RowSpec(
                key: rowKey('mark', GalleryMark.currentLine.name),
                name: l.galleryMarkCurrentLine,
                count: count((_, GalleryItemMeta m) => m.onNarrativeChain),
                selected: filter.mark == GalleryMark.currentLine,
                onTap: () => notifier.state = filter.copyWith(
                    mark: () => filter.mark == GalleryMark.currentLine ? null : GalleryMark.currentLine),
              ),
              _RowSpec(
                key: rowKey('mark', GalleryMark.inSequence.name),
                name: l.galleryMarkInSequence,
                count: count((_, GalleryItemMeta m) => m.sequenceIndex != null),
                selected: filter.mark == GalleryMark.inSequence,
                onTap: () => notifier.state = filter.copyWith(
                    mark: () => filter.mark == GalleryMark.inSequence ? null : GalleryMark.inSequence),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowSpec {
  const _RowSpec({
    required this.key,
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final Key key;
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<_RowSpec> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              children: <Widget>[
                Text('▼', style: t.micro.copyWith(color: c.fg5)),
                const SizedBox(width: InkSpacing.s6),
                Text(title, style: t.bodyStrong.copyWith(color: c.fg3)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: InkSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[for (final _RowSpec r in rows) _FilterRow(spec: r)],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.spec});
  final _RowSpec spec;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Semantics(
      button: true,
      selected: spec.selected,
      label: spec.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: spec.key,
          behavior: HitTestBehavior.opaque,
          onTap: spec.onTap,
          child: Container(
            height: 24,
            padding: const EdgeInsets.only(left: InkSpacing.s26, right: InkSpacing.s12),
            color: spec.selected ? c.surface5 : null,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    spec.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: spec.selected ? c.fg1 : c.fg3),
                  ),
                ),
                const SizedBox(width: InkSpacing.sm),
                Text('${spec.count}', style: t.monoSmall.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
