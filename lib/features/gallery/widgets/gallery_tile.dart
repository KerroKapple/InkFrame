// GalleryTile：画廊网格单元——图片缩略 / 视频缩略图+播放（GA-1/2）+ 类型/画布名 caption。
//
// 图片经 fileResolverServiceProvider 解析后 Image.file 渲染（同 BatchResultsGrid），
// 点击开图片 lightbox；视频有已落库缩略图（thumbnail_url）则渲染缩略图 +
// 播放/时长角标，点击经 existsSync 守卫开 video_lightbox，文件缺失显 broken 态
//（可点重试）。播放 happy path（真开 lightbox）无自动化覆盖——media_kit 不进
// 单测环境，由手工回归兜底；单测覆盖到 existsSync 守卫两侧分支为止。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart'
    show CharacterAssetError;
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../../canvas/providers/characters_controller.dart';
import '../../canvas/widgets/video_lightbox.dart';
import '../models/gallery_item.dart';
import 'gallery_image_lightbox.dart';

class GalleryTile extends ConsumerStatefulWidget {
  const GalleryTile({super.key, required this.projectId, required this.item});

  final String projectId;
  final GalleryItem item;

  @override
  ConsumerState<GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends ConsumerState<GalleryTile> {
  /// 点击时视频文件缺失 → broken 态（预览区替换为 broken 图标，可点重试）。
  bool _videoBroken = false;

  GalleryItem get item => widget.item;

  @override
  void didUpdateWidget(covariant GalleryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Element 复用换 item 即复位（评审 F2；对齐 video_node_body 的 ME-25 约定）。
    if (oldWidget.item != widget.item) _videoBroken = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InkRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _preview(context)),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InkSpacing.sm,
                vertical: InkSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    switch (item.kind) {
                      GalleryItemKind.image => context.l10n.galleryKindImage,
                      GalleryItemKind.video => context.l10n.galleryKindVideo,
                    },
                    style: typo.caption.copyWith(color: colors.fg2),
                  ),
                  const SizedBox(width: InkSpacing.sm),
                  Expanded(
                    child: Text(
                      item.canvasName,
                      style: typo.caption.copyWith(color: colors.fg3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  // GA-4：仅 image 项出「存为角色」菜单（复用点见 README）。
                  // child: 形态（非 icon:）——否则 IconButton 默认 48×48 点击区
                  // 把 caption 行撑高 2.4 倍且图/视频 tile 不齐（评审 nit）。
                  if (item.kind == GalleryItemKind.image)
                    PopupMenuButton<String>(
                      tooltip: context.l10n.gallerySaveAsCharacter,
                      padding: EdgeInsets.zero,
                      itemBuilder: (menuCtx) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'saveCharacter',
                          child: Text(menuCtx.l10n.gallerySaveAsCharacter),
                        ),
                      ],
                      onSelected: (_) => _saveAsCharacter(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: InkSpacing.xs,
                        ),
                        child: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: colors.fg3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// canvas 双参根解析；非法路径 → null（渲染 broken 占位）。
  File? _resolve(String relativePath) {
    try {
      return ref.read(fileResolverServiceProvider).resolve(
            projectId: widget.projectId,
            canvasId: item.canvasId,
            relativePath: relativePath,
          );
    } on PathSecurityError {
      return null;
    }
  }

  Widget _preview(BuildContext context) {
    final colors = context.inkColors;
    if (item.kind == GalleryItemKind.video) {
      return _videoPreview(context, colors);
    }
    final file = _resolve(item.relativePath);
    if (file == null) {
      return _iconPlaceholder(colors, Icons.broken_image_outlined);
    }
    return GestureDetector(
      onTap: () => showGalleryImageLightbox(context, imageFile: file),
      child: Image.file(
        file,
        fit: BoxFit.cover,
        // LB-23：按 tile 上限缩略解码，禁原图全解码
        //（220 = gallery_screen._tileMaxExtent，逻辑px × dpr）。
        cacheWidth: (220 * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) =>
            _iconPlaceholder(colors, Icons.broken_image_outlined),
      ),
    );
  }

  Widget _videoPreview(BuildContext context, InkColors colors) {
    if (_videoBroken) {
      // broken 态保留点击：文件恢复后一击回到正常播放（评审 F3）。
      return GestureDetector(
        onTap: _playVideo,
        child: _iconPlaceholder(colors, Icons.broken_image_outlined),
      );
    }
    final thumbRel = item.thumbnailRelativePath;
    final thumb = thumbRel == null ? null : _resolve(thumbRel);
    return GestureDetector(
      onTap: _playVideo,
      child: thumb == null
          ? _videoPlaceholder(context, colors)
          : Image.file(
              thumb,
              fit: BoxFit.cover,
              // LB-23：视频缩略图同按 tile 上限缩略解码。
              cacheWidth:
                  (220 * MediaQuery.devicePixelRatioOf(context)).round(),
              // 播放/时长角标经 frameBuilder 挂在图内：缩略图缺失/解码失败时
              // errorBuilder 整体接管，不残留兄弟浮标叠影（评审 F1）。
              frameBuilder: (context, child, frame, wasSync) => Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  child,
                  Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: colors.fg1,
                      size: 36,
                    ),
                  ),
                  if (item.durationMs != null)
                    Positioned(
                      right: InkSpacing.xs,
                      bottom: InkSpacing.xs,
                      child:
                          _durationBadge(context, colors, item.durationMs!),
                    ),
                ],
              ),
              errorBuilder: (_, _, _) => _videoPlaceholder(context, colors),
            ),
    );
  }

  /// GA-2：existsSync 守卫 → video_lightbox（绝对路径一次性使用，不落状态）。
  Future<void> _playVideo() async {
    final file = _resolve(item.relativePath);
    if (file == null || !file.existsSync()) {
      setState(() => _videoBroken = true);
      return;
    }
    if (_videoBroken) setState(() => _videoBroken = false);
    await showVideoLightbox(context, videoPath: file.path);
  }

  Widget _durationBadge(BuildContext context, InkColors colors, int ms) {
    final typo = context.inkTypography;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.xs),
        child: Text(
          _fmtDuration(ms),
          style: typo.caption.copyWith(color: colors.fg1),
        ),
      ),
    );
  }

  Widget _videoPlaceholder(BuildContext context, InkColors colors) {
    final typo = context.inkTypography;
    final durationMs = item.durationMs;
    return ColoredBox(
      color: colors.surface3,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.videocam_outlined, color: colors.fg3, size: 28),
            if (durationMs != null) ...<Widget>[
              const SizedBox(height: InkSpacing.xs),
              Text(
                _fmtDuration(durationMs),
                style: typo.caption.copyWith(color: colors.fg3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconPlaceholder(InkColors colors, IconData icon) =>
      Center(child: Icon(icon, color: colors.fg3, size: 20));

  /// GA-4 in-flight 防重（PLAYBOOK §5.2）：串行队列只保证不并发、不保证不重复。
  bool _savingCharacter = false;

  /// GA-4：命名 → charactersController.createFromImage（补偿逻辑在控制器内）。
  ///
  /// 抛出集与控制器注释对齐（评审 P1-2）：InkError / CharacterAssetError /
  /// FileSystemException 三类全捕——漏一类=静默失败+假崩溃文件。
  Future<void> _saveAsCharacter() async {
    if (_savingCharacter) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CharacterNameDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    if (_savingCharacter) return; // 对话框期二开菜单的窗口
    _savingCharacter = true;
    // await 前预取（PLAYBOOK §5.1：跨异步边界不再碰 context）。
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final file = _resolve(item.relativePath);
    try {
      // existsSync 守卫：tile 显示 broken 占位时菜单照样可点（评审 P1-2）。
      if (file == null || !file.existsSync()) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l.inspectorCharactersImportFailed)),
        );
        return;
      }
      // listenManual 保活 autoDispose family 至操作完成；先 await build
      //（repo future 就绪）再调 createFromImage，避免冷读竞态。
      final sub = ref.listenManual(
        charactersControllerProvider(widget.projectId),
        (_, _) {},
      );
      try {
        await ref.read(charactersControllerProvider(widget.projectId).future);
        // 冷建含真 DB 往返;期间 tile 可能被 GridView 回收——ref 已死,
        // 操作尚未开写,放弃即无半状态（评审 P1-3）。
        if (!mounted) return;
        await ref
            .read(charactersControllerProvider(widget.projectId).notifier)
            .createFromImage(name: name.trim(), sourceAbsolutePath: file.path);
        messenger?.showSnackBar(
          SnackBar(content: Text(l.gallerySavedAsCharacter)),
        );
      } on InkError catch (_) {
        // 控制器已补偿（清记录+清落盘图）；此处只负责提示，不吞成假成功。
        messenger?.showSnackBar(
          SnackBar(content: Text(l.inspectorCharactersImportFailed)),
        );
      } on CharacterAssetError catch (_) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l.inspectorCharactersImportFailed)),
        );
      } on FileSystemException catch (_) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l.inspectorCharactersImportFailed)),
        );
      } finally {
        sub.close();
      }
    } finally {
      _savingCharacter = false;
    }
  }
}

/// 角色命名对话框（复用 inspector 的 ARB 键；返回名字或 null=取消）。
class _CharacterNameDialog extends StatefulWidget {
  const _CharacterNameDialog();

  @override
  State<_CharacterNameDialog> createState() => _CharacterNameDialogState();
}

class _CharacterNameDialogState extends State<_CharacterNameDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.inkColors;
    return AlertDialog(
      backgroundColor: colors.surface1,
      title: Text(l.inspectorCharactersDialogTitle),
      content: InkInput(
        controller: _ctrl,
        hintText: l.inspectorCharactersNameHint,
        onChanged: (_) => setState(() {}),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _ctrl.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_ctrl.text),
          child: Text(l.inspectorCharactersSave),
        ),
      ],
    );
  }
}

String _fmtDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
