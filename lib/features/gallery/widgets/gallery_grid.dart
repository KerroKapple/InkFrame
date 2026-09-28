// GalleryGrid：中央网格（surface1）——32px 工具行 + padding 16 的 N 列网格，gap 12。
//
// 工具行：范围名 + 「N 项」+ 撑开 + 中 / 大 / 特大（只改列数）。稿上的「悬停自动播」无后端不画。
// 交互：单击选中（⌘/Ctrl 切换），双击 / 空格 预览，↑↓←→ 移锚点（稿状态栏的提示三条全接）。
// 滚动位置：PageStorageKey 按项目分键——切标签 / 切项目再回来仍在原位（用户点名要验）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../canvas/widgets/video_lightbox.dart';
import '../models/gallery_graph.dart';
import '../models/gallery_item.dart';
import '../models/gallery_selection.dart';
import '../providers/gallery_filter.dart';
import '../providers/gallery_graph_provider.dart';
import '../providers/gallery_selection.dart';
import '../providers/gallery_view.dart';
import '../util/gallery_meta.dart';
import 'gallery_actions.dart';
import 'gallery_image_lightbox.dart';
import 'gallery_screen.dart';
import 'gallery_tile.dart';

class GalleryGrid extends ConsumerStatefulWidget {
  const GalleryGrid({super.key, required this.projectId});

  final String projectId;

  static Key sizeKey(GalleryThumbSize s) => ValueKey<String>('gallery.thumbSize.${s.name}');

  @override
  ConsumerState<GalleryGrid> createState() => _GalleryGridState();
}

class _GalleryGridState extends ConsumerState<GalleryGrid> {
  final FocusNode _focus = FocusNode(debugLabel: 'gallery-grid');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String get projectId => widget.projectId;

  void _select(GalleryItem item, {bool toggle = false}) {
    final StateController<GallerySelection> sel = ref.read(gallerySelectionProvider(projectId).notifier);
    final String key = galleryItemKey(item);
    sel.state = toggle ? sel.state.toggle(key) : sel.state.select(key);
    _focus.requestFocus();
  }

  Future<void> _preview(GalleryItem item) async {
    final File? file = galleryResolveFile(ref,
        projectId: projectId, canvasId: item.canvasId, relativePath: item.relativePath);
    if (file == null || !file.existsSync()) return;
    if (item.kind == GalleryItemKind.video) {
      await showVideoLightbox(context, videoPath: file.path);
    } else {
      await showGalleryImageLightbox(context, imageFile: file);
    }
  }

  /// ↑↓←→ 在筛选后的列表里移锚点；空格预览锚点。
  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<GalleryItem> items, int columns) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final GalleryItem? anchor = ref.read(galleryAnchorItemProvider(projectId));
    final int at = anchor == null ? -1 : items.indexWhere((i) => galleryItemKey(i) == galleryItemKey(anchor));
    final int? delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowDown => columns,
      LogicalKeyboardKey.arrowUp => -columns,
      _ => null,
    };
    if (delta != null) {
      if (items.isEmpty) return KeyEventResult.handled;
      final int next = (at < 0 ? 0 : at + delta).clamp(0, items.length - 1);
      _select(items[next]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space && anchor != null && event is KeyDownEvent) {
      _preview(anchor);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final List<GalleryItem> items = ref.watch(galleryFilteredItemsProvider(projectId));
    final Map<String, GalleryItemMeta> meta = ref.watch(galleryMetaProvider(projectId));
    final GallerySelection selection = ref.watch(gallerySelectionProvider(projectId));
    final GalleryThumbSize size = ref.watch(galleryThumbSizeProvider);
    final GalleryFilter filter = ref.watch(galleryFilterProvider(projectId));
    final GalleryGraph graph = ref.watch(galleryGraphProvider(projectId)).valueOrNull ?? GalleryGraph.empty;
    final String scopeName = filter.canvasId == null
        ? l.galleryFilterAllInProject
        : (graph.canvas(filter.canvasId!)?.name ?? l.canvasDefaultName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 33, // content 32 + border-bottom 1
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(scopeName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: c.fg1)),
              ),
              const SizedBox(width: InkSpacing.s14),
              Text(l.galleryItemsShort(items.length), style: t.mono.copyWith(color: c.fg5)),
              const Spacer(),
              for (final GalleryThumbSize s in GalleryThumbSize.values) ...<Widget>[
                const SizedBox(width: InkSpacing.s14),
                Semantics(
                  button: true,
                  selected: s == size,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: GalleryGrid.sizeKey(s),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => ref.read(galleryThumbSizeProvider.notifier).state = s,
                      child: Text(
                        switch (s) {
                          GalleryThumbSize.medium => l.galleryThumbMedium,
                          GalleryThumbSize.large => l.galleryThumbLarge,
                          GalleryThumbSize.xlarge => l.galleryThumbXLarge,
                        },
                        style: t.body.copyWith(color: s == size ? c.fg1 : c.fg5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? GalleryNoMatchState(projectId: projectId)
              : Focus(
                  focusNode: _focus,
                  onKeyEvent: (FocusNode n, KeyEvent e) => _onKey(n, e, items, size.columns),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      final int cols = size.columns;
                      final double w = (box.maxWidth - InkSpacing.md * 2 - InkSpacing.s12 * (cols - 1)) / cols;
                      // 图区 16:9 + 6 间距 + 一行 11px 说明（行高 1.45 ≈ 16）。
                      final double h = w * 9 / 16 + InkSpacing.s6 + GalleryTile.captionHeight;
                      return GridView.builder(
                        key: PageStorageKey<String>('gallery-grid-$projectId'),
                        padding: const EdgeInsets.all(InkSpacing.md),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: InkSpacing.s12,
                          crossAxisSpacing: InkSpacing.s12,
                          childAspectRatio: w / h,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, int i) {
                          final GalleryItem item = items[i];
                          final String key = galleryItemKey(item);
                          return GalleryTile(
                            key: ValueKey<String>(key),
                            projectId: projectId,
                            item: item,
                            meta: meta[key] ?? GalleryItemMeta.empty,
                            index: i + 1,
                            selected: selection.contains(key),
                            onTap: (bool toggle) => _select(item, toggle: toggle),
                            onPreview: () => _preview(item),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
