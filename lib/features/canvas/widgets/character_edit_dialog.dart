// CharacterEditDialog：角色编辑框（P4），宽 560 content / 562 外框。
//
// 几何照搬静态复刻件 lib/features/workspace/batch_v2_screen.dart 的 03c 块：
// 标题栏 39（38 content + 1px 下沿）/ 正文 padding 16·14（内容宽 532）/ 四组间距 16 /
// 名称字段 25（24 + 1px 底线）/ 描述最小实高 61（48 content + 6×2 + 1px 底线）/
// 参考图格 96×96 + gap 4 + meta 行 14 / 被引用 chip 24（22 + 2px 边）/ 底部条 53。
//
// 与复刻件的两处差异（都是接线口径，不是画错）：
//   1. 参考图格下的「备注」删掉——PLAN §P4 明写无字段，meta 行只剩序号 + 最右 ✕。
//   2. 格子行从不换行的 Row 改成 Wrap：上限 6 张时 6×96 + 添加格 96 + 6×8 = 720 > 532，
//      稿只画了 4/6 那一档没触发；每行 5 格（5×96 + 4×8 = 512）正好落在 532 内。
//
// 四个动作接 CharactersController 的薄方法。名称 / 描述是「改完点保存」，
// 参考图的增删排是即时落库——后者本来就带文件搬运，攒到保存再做无法回滚。
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/character_assets.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../models/canvas_node.dart';
import '../models/character.dart';
import '../providers/character_usage.dart';
import '../providers/characters_controller.dart';
import 'character_library_panel.dart' show CharacterDashedBox;
import 'node_card.dart' show nodeRefName;

/// 参考图上限 = 所有已登记 provider 的 maxRefImages 最大值。
///
/// 角色是项目级的：从左栏打开编辑框时根本没有「当前 provider」，按某一家的上限卡会
/// 误伤别家。取最大值意味着「任一 provider 能吃下的张数都允许存」，真正的截断发生在
/// 生成侧（provider 自己按自己的 maxRefImages 截）。
int maxReferenceImagesOf(Iterable<ProviderCapabilities> capabilities) {
  int max = 0;
  for (final ProviderCapabilities c in capabilities) {
    if (c.maxRefImages > max) max = c.maxRefImages;
  }
  return max;
}

/// 打开角色编辑框。characterId 而非 Character：对话框自己 watch 列表，
/// 增删参考图后不必靠调用方重新传值。
Future<void> showCharacterEditDialog(
  BuildContext context, {
  required String projectId,
  required String characterId,
}) => showDialog<void>(
  context: context,
  barrierColor: context.inkColors.scrim,
  builder: (BuildContext _) =>
      CharacterEditDialog(projectId: projectId, characterId: characterId),
);

class CharacterEditDialog extends ConsumerStatefulWidget {
  const CharacterEditDialog({
    super.key,
    required this.projectId,
    required this.characterId,
  });

  final String projectId;
  final String characterId;

  /// 稿上的 content 宽；外框 +2（1px 边 ×2）。
  static const double width = 560;

  @override
  ConsumerState<CharacterEditDialog> createState() =>
      _CharacterEditDialogState();
}

class _CharacterEditDialogState extends ConsumerState<CharacterEditDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();

  /// 列表可能还在 loading（AsyncNotifier 要先 await 仓储），所以初值不能在 initState
  /// 里一次性取——那会把输入框钉在空串上。改成"角色第一次可读时"回填一次。
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Character? _read() => ref
      .read(charactersControllerProvider(widget.projectId))
      .valueOrNull
      ?.where((Character c) => c.id == widget.characterId)
      .firstOrNull;

  CharactersController get _controller =>
      ref.read(charactersControllerProvider(widget.projectId).notifier);

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;

    final Character? character = ref
        .watch(charactersControllerProvider(widget.projectId))
        .valueOrNull
        ?.where((Character ch) => ch.id == widget.characterId)
        .firstOrNull;
    // 角色在别处被删（软删）时列表里就没有了：收起内容，别留一个编辑幽灵记录的界面。
    if (character == null) return const SizedBox.shrink();
    if (!_seeded) {
      _seeded = true;
      _name.text = character.name;
      _description.text = character.description;
    }

    final List<CanvasNode> usedBy =
        ref.watch(characterUsageProvider(widget.projectId)).valueOrNull?[widget
            .characterId] ??
        const <CanvasNode>[];
    final int max = maxReferenceImagesOf(
      ref.watch(providerCapabilitiesListProvider),
    );
    final List<String> refs = character.referenceImagePaths;
    final bool atLimit = refs.length >= max;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(InkSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CharacterEditDialog.width + 2,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface3,
            border: Border.all(color: c.control),
            borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
            boxShadow: InkShadow.overlay,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _titleBar(c, t, l),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: InkSpacing.s14,
                    vertical: InkSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _label(t, c, l.characterFieldName),
                      const SizedBox(height: InkSpacing.s6),
                      _nameField(c, t, l),
                      const SizedBox(height: InkSpacing.md),
                      _label(t, c, l.characterFieldDescription),
                      const SizedBox(height: InkSpacing.s6),
                      _descriptionField(c, t, l),
                      const SizedBox(height: InkSpacing.s6),
                      Text(
                        l.characterDescriptionHint,
                        style: t.micro.copyWith(color: c.fg6, height: 1.5),
                      ),
                      const SizedBox(height: InkSpacing.md),
                      _referencesHeader(c, t, l, refs.length, max),
                      const SizedBox(height: InkSpacing.sm),
                      _referenceGrid(c, t, l, refs, atLimit: atLimit),
                      const SizedBox(height: InkSpacing.s6),
                      Text(
                        l.characterStorageHint,
                        style: t.micro.copyWith(color: c.fg6, height: 1.5),
                      ),
                      const SizedBox(height: InkSpacing.md),
                      _label(t, c, l.characterFieldReferencedBy),
                      const SizedBox(height: InkSpacing.sm),
                      _referencedBy(c, t, usedBy),
                    ],
                  ),
                ),
              ),
              _footer(c, t, l, usedBy.length),
            ],
          ),
        ),
      ),
    );
  }

  // 稿：38 content + 1px 下沿；标题是 12/500（不是 dialogTitle 的 17）。
  Widget _titleBar(InkColors c, InkTypography t, AppLocalizations l) =>
      Container(
        height: 39,
        padding: const EdgeInsets.only(
          left: InkSpacing.s14,
          right: InkSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border(bottom: BorderSide(color: c.borderStrong)),
        ),
        child: Row(
          children: <Widget>[
            Text(
              l.characterEditTitle,
              style: t.bodyStrong.copyWith(color: c.fg1),
            ),
            const Spacer(),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icon(Icons.close, size: InkSpacing.md, color: c.fg5),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

  Widget _label(InkTypography t, InkColors c, String text) =>
      Text(text, style: t.body.copyWith(color: c.fg4));

  // 稿：24 content + 1px 底线，左右零内边距（文字与正文左沿齐）。
  Widget _nameField(InkColors c, InkTypography t, AppLocalizations l) =>
      Container(
        height: 25,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.control)),
        ),
        child: TextField(
          key: const ValueKey<String>('character-name-field'),
          controller: _name,
          cursorColor: c.accent,
          style: t.body.copyWith(color: c.fg1),
          decoration: InputDecoration.collapsed(
            hintText: l.characterFieldName,
            hintStyle: t.body.copyWith(color: c.fg6),
          ),
        ),
      );

  // 稿：min-height 48 作用在内容盒上 → 含 padding 6×2 与 1px 底线的实高是 61。
  Widget _descriptionField(InkColors c, InkTypography t, AppLocalizations l) =>
      Container(
        constraints: const BoxConstraints(minHeight: 61),
        padding: const EdgeInsets.symmetric(vertical: InkSpacing.s6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.control)),
        ),
        child: TextField(
          key: const ValueKey<String>('character-description-field'),
          controller: _description,
          minLines: 2,
          maxLines: 5,
          cursorColor: c.accent,
          style: t.body.copyWith(color: c.fg2, height: 1.5),
          decoration: InputDecoration.collapsed(
            hintText: l.characterFieldDescription,
            hintStyle: t.body.copyWith(color: c.fg6),
          ),
        ),
      );

  Widget _referencesHeader(
    InkColors c,
    InkTypography t,
    AppLocalizations l,
    int count,
    int max,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: <Widget>[
      _label(t, c, l.characterFieldReferences),
      const SizedBox(width: InkSpacing.sm),
      Flexible(
        child: Text(
          // 一张都没有时「拖动重排」是空话，换成空态文案。
          count == 0 ? l.characterNoReferences : l.characterReferencesHint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.micro.copyWith(color: c.fg6),
        ),
      ),
      const Spacer(),
      Text(
        l.characterReferencesCount(count, max),
        style: t.monoSmall.copyWith(color: c.fg6),
      ),
    ],
  );

  Widget _referenceGrid(
    InkColors c,
    InkTypography t,
    AppLocalizations l,
    List<String> refs, {
    required bool atLimit,
  }) => Wrap(
    spacing: InkSpacing.sm,
    runSpacing: InkSpacing.sm,
    children: <Widget>[
      for (int i = 0; i < refs.length; i++)
        _ReferenceTile(
          key: ValueKey<String>('character-ref-$i'),
          projectId: widget.projectId,
          relativePath: refs[i],
          index: i,
          onRemove: () => _guard(
            () => _controller.removeReferenceImage(widget.characterId, i),
          ),
          onMoveHere: (int from) => _guard(
            () => _controller.reorderReferenceImages(widget.characterId, from, i),
          ),
        ),
      Tooltip(
        message: atLimit
            ? l.characterReferenceLimitReached
            : l.characterReferenceAdd,
        child: MouseRegion(
          cursor: atLimit
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            key: const ValueKey<String>('character-ref-add'),
            behavior: HitTestBehavior.opaque,
            onTap: atLimit ? null : _addReference,
            child: CharacterDashedBox(
              radius: InkRadius.sm,
              dimmed: atLimit,
              child: SizedBox(
                width: _kRefTile,
                height: _kRefTile,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('+', style: t.body.copyWith(color: c.fg6)),
                    const SizedBox(height: InkSpacing.xs),
                    Text(
                      l.characterReferenceAdd,
                      style: t.micro.copyWith(color: c.fg6),
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

  // 稿：wrap 的 chip 组，不是列表——没有类型列 / 画布列 / 分隔线。
  Widget _referencedBy(InkColors c, InkTypography t, List<CanvasNode> nodes) =>
      Wrap(
        spacing: InkSpacing.s6,
        runSpacing: InkSpacing.s6,
        children: <Widget>[
          for (final CanvasNode n in nodes)
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: c.control),
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 16,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.surface5,
                      borderRadius: BorderRadius.circular(InkRadius.s1),
                    ),
                  ),
                  const SizedBox(width: InkSpacing.s6),
                  Text(
                    nodeRefName(context, n),
                    style: t.meta.copyWith(color: c.fg3),
                  ),
                ],
              ),
            ),
        ],
      );

  // 稿：1px 上沿 + padding 12·14；取消实高 28、保存 26，靠 center 对齐。
  Widget _footer(
    InkColors c,
    InkTypography t,
    AppLocalizations l,
    int usageCount,
  ) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: InkSpacing.s14,
      vertical: InkSpacing.s12,
    ),
    decoration: BoxDecoration(
      color: c.surface2,
      border: Border(top: BorderSide(color: c.borderStrong)),
    ),
    child: Row(
      children: <Widget>[
        Flexible(
          child: Text(
            usageCount > 0
                ? l.characterEditFootnote(usageCount)
                : l.characterEditFootnoteNone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.micro.copyWith(color: c.fg6),
          ),
        ),
        const Spacer(),
        _TapWrap(
          tapKey: const ValueKey<String>('character-cancel'),
          onTap: () => Navigator.of(context).pop(),
          child: WsSecondaryButton(l.commonCancel, height: 26),
        ),
        const SizedBox(width: InkSpacing.sm),
        _TapWrap(
          tapKey: const ValueKey<String>('character-save'),
          onTap: _save,
          child: WsPrimaryButton(
            l.characterSave,
            height: 26,
            horizontalPadding: InkSpacing.s14,
            bordered: false,
          ),
        ),
      ],
    ),
  );

  /// 保存 = 名称 + 描述两条薄方法；没改的那条不发写请求。
  Future<void> _save() async {
    final Character? current = _read();
    if (current == null) return;
    final String name = _name.text.trim();
    final String description = _description.text.trim();
    final NavigatorState nav = Navigator.of(context);
    if (name.isNotEmpty && name != current.name) {
      if (!await _guard(() => _controller.rename(widget.characterId, name))) {
        return;
      }
    }
    if (description != current.description) {
      if (!await _guard(
        () => _controller.setDescription(widget.characterId, description),
      )) {
        return;
      }
    }
    if (mounted) nav.pop();
  }

  Future<void> _addReference() async {
    const XTypeGroup group = XTypeGroup(
      label: 'images',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[group],
    );
    if (file == null || !mounted) return;
    await _guard(
      () => _controller.addReferenceImage(
        widget.characterId,
        sourceAbsolutePath: file.path,
      ),
    );
  }

  /// 仓储 / 资产层只抛 InkError 与 CharacterAssetError；失败给 SnackBar 并回 false，
  /// 让调用方别继续走"成功"分支（例如失败时不关框）。
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on InkError catch (_) {
      _toast();
      return false;
    } on CharacterAssetError catch (_) {
      _toast();
      return false;
    }
  }

  void _toast() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.inspectorCharactersImportFailed)),
    );
  }
}

/// 稿上的参考图格边长。
const double _kRefTile = 96;

/// 序号徽标边长（稿：14×14，radius 2）。
const double _kBadge = 14;

/// 一张参考图：96 图 + gap 4 + meta 行（序号徽标 ←→ 删除 ✕）。
/// 整格即拖拽把手——稿上没有拖柄，唯一提示是表头那句「顺序即注入次序 · 拖动重排」。
class _ReferenceTile extends ConsumerWidget {
  const _ReferenceTile({
    super.key,
    required this.projectId,
    required this.relativePath,
    required this.index,
    required this.onRemove,
    required this.onMoveHere,
  });

  final String projectId;
  final String relativePath;
  final int index;
  final VoidCallback onRemove;
  final void Function(int from) onMoveHere;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    String? abs;
    try {
      abs = ref
          .read(characterAssetServiceProvider)
          .absolutePathOf(projectId: projectId, relativePath: relativePath);
    } on CharacterAssetError {
      abs = null;
    }

    final Widget thumb = Container(
      width: _kRefTile,
      height: _kRefTile,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.thumbFill,
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: abs == null
          ? null
          : Image.file(
              File(abs),
              fit: BoxFit.cover,
              cacheWidth: (_kRefTile * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) =>
                  Center(child: Icon(Icons.broken_image_outlined, color: c.fg6)),
            ),
    );

    return SizedBox(
      width: _kRefTile,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DragTarget<int>(
            onWillAcceptWithDetails: (DragTargetDetails<int> d) =>
                d.data != index,
            onAcceptWithDetails: (DragTargetDetails<int> d) =>
                onMoveHere(d.data),
            builder: (BuildContext _, List<int?> _, List<dynamic> _) =>
                Draggable<int>(
                  data: index,
                  // 横向 affinity：纵向滚动仍归 SingleChildScrollView，不抢手势。
                  affinity: Axis.horizontal,
                  feedback: Opacity(opacity: 0.8, child: thumb),
                  childWhenDragging: Opacity(opacity: 0.3, child: thumb),
                  child: thumb,
                ),
          ),
          const SizedBox(height: InkSpacing.xs),
          Row(
            children: <Widget>[
              Container(
                width: _kBadge,
                height: _kBadge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.control,
                  borderRadius: BorderRadius.circular(InkRadius.xs),
                ),
                child: Text(
                  '${index + 1}',
                  style: t.monoSmall.copyWith(color: c.fg2),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: context.l10n.characterReferenceRemove,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: ValueKey<String>('character-ref-remove-$index'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: SizedBox(
                      width: _kBadge,
                      height: _kBadge,
                      child: Center(
                        child: Text(
                          '✕',
                          style: t.micro.copyWith(color: c.fg6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 把纯呈现的 Ws*Button 变成可点控件（shell_tab_bar.dart 已确立的包法）。
class _TapWrap extends StatelessWidget {
  const _TapWrap({
    required this.tapKey,
    required this.onTap,
    required this.child,
  });

  final Key tapKey;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      key: tapKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}
