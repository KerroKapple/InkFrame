// CharacterLibraryPanel：左栏「角色」页的 body（P4）。
//
// 几何照搬静态复刻件 lib/features/workspace/batch_v2_screen.dart 的 03b 块：
// 说明行 10/8/4 内边距 → 行高 53（8 + 36 缩略 + 8 + 1px 下沿）→ 底部虚线「新建角色」格
// （四边 margin 10，盒高 32 = 30 content + 上下各 1px 边）。复刻卡是 260 content，
// 真实左栏是 240（241 − 1px 右沿），横向数字按 240 折算，纵向不变。
//
// 稿上第一行画成选中态（surface5 + fg1）——真实左栏没有"当前角色"这个概念，
// 所以这里只保留 hover 态（laneDivider），名称恒 fg3。
//
// 三个动作直接接 CharactersController 上已有的方法：
// 编辑 → CharacterEditDialog / 改名 → rename / 删除 → 二次确认后 softDelete。
import 'dart:io';
import 'dart:ui' show PathMetric;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/character_assets.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../models/character.dart';
import '../providers/character_usage.dart';
import '../providers/characters_controller.dart';
import 'character_edit_dialog.dart';
import 'characters_section.dart';

/// 行内缩略图边长（稿：36×36，1px 内沿 outline）。
const double _kRowThumb = 36;

/// 稿：虚线格 content 高 30 + 上下各 1px 边 = 32。
const double _kNewSlotHeight = 32;

/// ⋯ 的点击区（稿上是裸字形；project_card.dart 已确立 24×24 的放大点击区）。
const double _kMenuHit = 24;

/// ⋯ 菜单项高。稿注没给菜单几何，取本稿最常见的交互行高 26
/// （Material 默认 48 与本稿密度差一倍，必须显式压）。
const double _kMenuItemHeight = 26;

/// ⋯ 菜单三项。顺序照稿注「编辑、改名、删除」。
enum _CharacterAction { edit, rename, delete }

class CharacterLibraryPanel extends ConsumerWidget {
  const CharacterLibraryPanel({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final AsyncValue<List<Character>> charactersAsync = ref.watch(
      charactersControllerProvider(projectId),
    );
    final List<Character> characters =
        charactersAsync.valueOrNull ?? const <Character>[];
    // 引用计数读的是全项目投影，慢一拍；未就绪时按 0 显示，不把整页卡在 loading。
    final Map<String, List<CanvasNode>> usages =
        ref.watch(characterUsageProvider(projectId)).valueOrNull ??
        const <String, List<CanvasNode>>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            InkSpacing.s10,
            InkSpacing.sm,
            InkSpacing.s10,
            InkSpacing.xs,
          ),
          child: Text(
            l.characterLibraryHint,
            style: t.micro.copyWith(color: c.fg6, height: 1.5),
          ),
        ),
        Expanded(
          // 读库失败必须显性报错：静默降级成空列表 = 谎报「还没有角色」。
          child: charactersAsync.hasError
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: InkSpacing.s10,
                  ),
                  child: InkErrorBanner(
                    message: l10nAsyncError(context, charactersAsync.error!),
                  ),
                )
              : characters.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    InkSpacing.s10,
                    InkSpacing.lg,
                    InkSpacing.s10,
                    0,
                  ),
                  child: Text(
                    l.characterLibraryEmpty,
                    textAlign: TextAlign.center,
                    style: t.meta.copyWith(color: c.fg6),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    for (final Character ch in characters)
                      CharacterLibraryRow(
                        key: ValueKey<String>('character-row-${ch.id}'),
                        projectId: projectId,
                        character: ch,
                        usageCount: usages[ch.id]?.length ?? 0,
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(InkSpacing.s10),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const ValueKey<String>('character-new'),
              behavior: HitTestBehavior.opaque,
              onTap: () => createCharacterFromFile(context, ref, projectId),
              child: CharacterDashedBox(
                radius: InkRadius.s3,
                child: SizedBox(
                  height: _kNewSlotHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text('+', style: t.body.copyWith(color: c.fg5)),
                      const SizedBox(width: InkSpacing.s6),
                      Text(
                        l.characterNew,
                        style: t.meta.copyWith(color: c.fg5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 一行角色：36 缩略 + 名称 + 「N 张参考图 · M 处引用」+ ⋯ 菜单。
/// 整行可点 = 编辑（与 ⋯ 菜单第一项同语义）。
class CharacterLibraryRow extends ConsumerStatefulWidget {
  const CharacterLibraryRow({
    super.key,
    required this.projectId,
    required this.character,
    required this.usageCount,
  });

  final String projectId;
  final Character character;
  final int usageCount;

  @override
  ConsumerState<CharacterLibraryRow> createState() =>
      _CharacterLibraryRowState();
}

class _CharacterLibraryRowState extends ConsumerState<CharacterLibraryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final Character ch = widget.character;
    final int refs = ch.referenceImagePaths.length;
    final String meta = widget.usageCount > 0
        ? l.characterRefAndUsage(refs, widget.usageCount)
        : l.characterRefAndUsageNone(refs);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _edit,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.s10,
            vertical: InkSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _hover ? c.laneDivider : null,
            border: Border(bottom: BorderSide(color: c.surface1)),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: _kRowThumb,
                height: _kRowThumb,
                child: _RowThumb(
                  projectId: widget.projectId,
                  relativePath: ch.referenceImagePaths.firstOrNull,
                ),
              ),
              const SizedBox(width: InkSpacing.s9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      ch.name.isNotEmpty ? ch.name : ch.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(color: c.fg3),
                    ),
                    const SizedBox(height: InkSpacing.s2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.micro.copyWith(color: c.fg5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: InkSpacing.s9),
              // PopupMenuButton 的 InkResponse 要 Material 祖先（project_card.dart 同因）。
              Material(
                type: MaterialType.transparency,
                child: PopupMenuButton<_CharacterAction>(
                  key: ValueKey<String>('character-menu-${ch.id}'),
                  // 不设 tooltip：按钮的 tooltip 说的是「点了会怎样」，填角色名会把
                  // 提示当正文用。留空走 MaterialLocalizations 的「显示菜单」。
                  tooltip: null,
                  color: c.surface2,
                  padding: EdgeInsets.zero,
                  onSelected: (_CharacterAction a) => switch (a) {
                    _CharacterAction.edit => _edit(),
                    _CharacterAction.rename => _rename(),
                    _CharacterAction.delete => _confirmDelete(),
                  },
                  itemBuilder: (BuildContext ctx) =>
                      <PopupMenuEntry<_CharacterAction>>[
                        _item(ctx, _CharacterAction.edit, l.characterMenuEdit),
                        _item(
                          ctx,
                          _CharacterAction.rename,
                          l.characterMenuRename,
                        ),
                        _item(
                          ctx,
                          _CharacterAction.delete,
                          l.characterMenuDelete,
                          danger: true,
                        ),
                      ],
                  child: SizedBox(
                    width: _kMenuHit,
                    height: _kMenuHit,
                    child: Center(
                      child: Text('⋯', style: t.meta.copyWith(color: c.fg6)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 危险项（删除）用 danger——该 hex 在同一份稿的失败 slot 有实据。
  PopupMenuItem<_CharacterAction> _item(
    BuildContext ctx,
    _CharacterAction value,
    String label, {
    bool danger = false,
  }) {
    final c = ctx.inkColors;
    return PopupMenuItem<_CharacterAction>(
      value: value,
      height: _kMenuItemHeight,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      child: Text(
        label,
        style: ctx.inkTypography.body.copyWith(color: danger ? c.danger : c.fg2),
      ),
    );
  }

  Future<void> _edit() => showCharacterEditDialog(
    context,
    projectId: widget.projectId,
    characterId: widget.character.id,
  );

  Future<void> _rename() async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => InspectorNameDialog(
        title: ctx.l10n.characterRenameTitle,
        hint: ctx.l10n.characterFieldName,
        confirmLabel: ctx.l10n.characterSave,
        cancelLabel: ctx.l10n.commonCancel,
      ),
    );
    final String trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    await _guard(
      () => ref
          .read(charactersControllerProvider(widget.projectId).notifier)
          .rename(widget.character.id, trimmed),
    );
  }

  /// 软删后应用内无法恢复（角色不进回收站，回收站只收 project / canvas），
  /// 参考图文件仍留在磁盘上——正文按这个实情写，别许诺"可恢复"。
  Future<void> _confirmDelete() async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text(ctx.l10n.characterDeleteTitle),
            content: Text(ctx.l10n.characterDeleteBody(widget.character.name)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.l10n.commonCancel),
              ),
              TextButton(
                key: const ValueKey<String>('character-delete-confirm'),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(ctx.l10n.characterMenuDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    await _guard(
      () => ref
          .read(charactersControllerProvider(widget.projectId).notifier)
          .delete(widget.character.id),
    );
  }

  /// 改名 / 删除只经仓储，仓储只抛 InkError；失败给 SnackBar，不崩 UI 也不假装成功。
  ///
  /// 文案走 l10nError：这里的失败可能是磁盘满、连接断，套「角色导入失败」会把用户
  /// 引到一个跟本次操作无关的方向（这两条路径根本不导入任何文件）。
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on InkError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10nError(context, e))));
    }
  }
}

/// 首张参考图缩略图；无图 / 越权路径 / 坏文件都退成人形占位，不崩行。
class _RowThumb extends ConsumerWidget {
  const _RowThumb({required this.projectId, required this.relativePath});

  final String projectId;
  final String? relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final String? rel = relativePath;
    String? abs;
    if (rel != null && rel.isNotEmpty) {
      try {
        abs = ref
            .read(characterAssetServiceProvider)
            .absolutePathOf(projectId: projectId, relativePath: rel);
      } on CharacterAssetError {
        abs = null;
      }
    }
    final Widget placeholder = Icon(
      Icons.person_outline,
      size: _kRowThumb / 2,
      color: c.fg6,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.thumbFill,
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      // outline 画在盒子内沿：盒子仍是 36×36，不是 38×38。
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: abs == null
          ? Center(child: placeholder)
          : Image.file(
              File(abs),
              fit: BoxFit.cover,
              // LB-23：按显示尺寸缩略解码，别把原图整张塞进 ImageCache。
              cacheWidth: (_kRowThumb * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) => Center(child: placeholder),
            ),
    );
  }
}

/// 从磁盘选图 + 命名 → 新建角色。角色库的「新建角色」与检查器「从文件导入」同一条路。
Future<void> createCharacterFromFile(
  BuildContext context,
  WidgetRef ref,
  String projectId,
) async {
  const XTypeGroup group = XTypeGroup(
    label: 'images',
    extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
  );
  final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
  if (file == null || !context.mounted) return;
  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => InspectorNameDialog(
      title: ctx.l10n.characterNew,
      hint: ctx.l10n.characterFieldName,
      confirmLabel: ctx.l10n.characterSave,
      cancelLabel: ctx.l10n.commonCancel,
    ),
  );
  final String trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty || !context.mounted) return;
  try {
    await ref
        .read(charactersControllerProvider(projectId).notifier)
        .createFromImage(name: trimmed, sourceAbsolutePath: file.path);
  } on InkError catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(l10nError(context, e))));
  } on CharacterAssetError catch (_) {
    // 捕获集 = createFromImage 的真实抛出集（仓储 InkError / 资产服务 / dart:io）。
    // 后两类不是 InkError，只接 InkError 会让「选了个坏文件」变成未捕获异步异常：
    // 用户点了没反应，只多一份 crash 文件。
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.inspectorCharactersImportFailed)),
    );
  } on FileSystemException catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.inspectorCharactersImportFailed)),
    );
  }
}

/// 虚线框。InkDashedSlot 的边色写死 outline 且默认 dash 6/4，稿这两处要
/// controlStrong + Chromium 的 dash 3/3，故与静态复刻件同款自带 painter。
class CharacterDashedBox extends StatelessWidget {
  const CharacterDashedBox({
    super.key,
    required this.radius,
    required this.child,
    this.dimmed = false,
  });

  final double radius;
  final Widget child;

  /// 禁用态：虚线与内容一起压暗（达参考图上限时的「添加」格）。
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final Widget painted = CustomPaint(
      painter: _DashedRectPainter(context.inkColors.controlStrong, radius),
      child: child,
    );
    return dimmed ? Opacity(opacity: 0.5, child: painted) : painted;
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.5),
      );
    const double dash = 3;
    const double gap = 3;
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(
          m.extractPath(d, d + dash > m.length ? m.length : d + dash),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}
