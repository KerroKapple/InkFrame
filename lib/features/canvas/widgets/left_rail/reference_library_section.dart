// ReferenceLibrarySection：左栏素材页第三段「参考库」（概念图方案 A）。
//
// 搜索框（按条目自带的「检索」字段）→ 类别 chip「姿势 N / 人像 N / 服装 N」（单选，N 随搜索变）→ 姿势多一行视角
// chip（全部视角 + 数据里实际出现的角度）→ 两列网格（GridView.builder，只构建看得见的格子；缩略图按格宽 × dpr
// 解码）→ 底部一行「文件夹路径 · 换文件夹」。筛选 / 计数 / 视角都是 reference_library_model.dart 的纯函数。
//
// 视角只对姿势生效：切到人像 / 服装时选着的视角留着（切回姿势还在），但不往筛选里传——别的类别没有视角，传了
// 就一张都不剩。
//
// 空态三种，都带「选择参考库文件夹」：还没选文件夹 / 选的文件夹里没有参考库（选成上一级或 data 下一级，Review
// Focus 1）/ 读取失败。三种都不画网格。
//
// 点一格开菜单（CanvasMenuPopover + InkMenuPanel，锚在格子左下）：
//   - 「当〈类别〉参考 → 〈节点名〉」：可用判据是 reference_item_actions.currentReferenceAttachDecision（与动作点下去时
//     重新判的是同一个）；点不动时整行置灰，原因写在紧跟的一行置灰小字里（InkMenuEntry 没有副标题位）；没有恰好
//     选中一个节点时，节点名的位置直接写原因。
//   - 「只放进画布」：一直可用。
//   - 「存为角色」：只有人像可用。
// 菜单开着时 watch 选中集 / 节点 / 边：菜单开着时选了别的节点，菜单跟着改。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/reference_library.dart';
import '../../../../core/interfaces/reference_library_reader.dart';
import '../../../../core/models/reference_item.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/components/ink_button.dart';
import '../../../../theme/components/ink_error_banner.dart';
import '../../../../theme/components/ink_menu_panel.dart';
import '../../../../theme/primitives/ink_activatable.dart';
import '../../../../theme/tokens.dart';
import '../../../shell/models/shell_state.dart';
import '../../../shell/providers/active_project.dart';
import '../../models/canvas_node.dart';
import '../../providers/canvas_edges_controller.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../providers/canvas_selection_controller.dart';
import '../canvas_menu/canvas_menu_popover.dart';
import '../node_card.dart' show nodeDisplayName;
import 'left_panel_parts.dart';
import 'reference_item_actions.dart';
import 'reference_library_model.dart';

/// 格子菜单的项。
enum ReferenceMenuAction {
  /// 当〈类别〉参考 → 选中的配置节点。
  attach,

  /// 「当参考」点不动时的原因行（永远置灰，不交回）。
  reason,

  /// 只放进画布。
  place,

  /// 存为角色（只对人像）。
  saveCharacter,
}

class ReferenceLibrarySection extends ConsumerStatefulWidget {
  const ReferenceLibrarySection({super.key, required this.canvasId});

  final String canvasId;

  /// 类别 chip 的测试锚点。
  static Key categoryKey(ReferenceCategory c) =>
      ValueKey<String>('leftRail-reference-category-${c.name}');

  /// 视角 chip 的测试锚点；null =「全部视角」。
  static Key angleKey(String? angle) =>
      ValueKey<String>('leftRail-reference-angle-${angle ?? ''}');

  /// 「选择参考库文件夹」（三种空态共用）的测试锚点。
  static const Key pickFolderKey = ValueKey<String>('leftRail-reference-pick-folder');

  /// 底部「换文件夹」的测试锚点。
  static const Key changeFolderKey = ValueKey<String>('leftRail-reference-change-folder');

  /// 格子的测试锚点。
  static Key tileKey(String itemId) => ValueKey<String>('leftRail-reference-tile-$itemId');

  /// 格子菜单面板的测试锚点。
  static const Key menuKey = ValueKey<String>('leftRail-reference-menu');

  @override
  ConsumerState<ReferenceLibrarySection> createState() =>
      _ReferenceLibrarySectionState();
}

class _ReferenceLibrarySectionState extends ConsumerState<ReferenceLibrarySection> {
  final TextEditingController _query = TextEditingController();
  String _queryText = '';
  ReferenceCategory _category = ReferenceCategory.pose;

  /// 选着的视角；null = 全部。只在姿势下生效（见头注）。
  String? _angle;

  /// 开着菜单的那一格与锚点；都为 null = 菜单收着。
  ReferenceItem? _menuItem;
  Offset? _menuAnchor;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final ReferenceFolderPicker pick = ref.read(referenceFolderPickerProvider);
    final ReferenceLibraryRootController root =
        ref.read(referenceLibraryRootProvider.notifier);
    final String? path = await pick();
    if (path == null) return;
    await root.set(path);
  }

  /// 开菜单：锚在格子左下（键盘激活也有锚点）。
  void _openMenu(ReferenceItem item, BuildContext tileContext) {
    final RenderObject? box = tileContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    setState(() {
      _menuItem = item;
      _menuAnchor = box.localToGlobal(Offset(0, box.size.height));
    });
  }

  /// 收菜单；可能一次关调两次（见 CanvasMenuPopover.onDismiss），写成幂等。
  void _closeMenu() {
    if (_menuItem == null && _menuAnchor == null) return;
    setState(() {
      _menuItem = null;
      _menuAnchor = null;
    });
  }

  void _onMenuSelected(ReferenceMenuAction action) {
    final ReferenceItem? item = _menuItem;
    final ProjectRef? project = ref.read(activeProjectProvider);
    _closeMenu();
    if (item == null || project == null) return;
    switch (action) {
      case ReferenceMenuAction.attach:
        unawaited(attachReferenceToSelected(
          context,
          ref,
          canvasId: widget.canvasId,
          projectId: project.id,
          item: item,
        ));
      case ReferenceMenuAction.place:
        unawaited(placeReferenceOnCanvas(
          context,
          ref,
          canvasId: widget.canvasId,
          projectId: project.id,
          item: item,
        ));
      case ReferenceMenuAction.saveCharacter:
        if (item.category != ReferenceCategory.portrait) return;
        unawaited(saveReferenceAsCharacter(
          context,
          ref,
          projectId: project.id,
          item: item,
        ));
      case ReferenceMenuAction.reason:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final String? root = ref.watch(referenceLibraryRootProvider);
    if (root == null) {
      return _ReferenceEmptyState(
        message: l.referenceEmptyNoFolder,
        onPick: _pickFolder,
      );
    }
    final AsyncValue<ReferenceLibraryLoad?> load = ref.watch(referenceLibraryProvider);
    if (!load.hasValue && load.hasError) {
      // 读取失败要显性报错：静默降级成空网格 = 谎报「图库是空的」。
      return _ReferenceEmptyState(
        banner: l10nAsyncError(context, load.error!),
        onPick: _pickFolder,
      );
    }
    if (!load.hasValue) return const SizedBox.shrink();
    return switch (load.value) {
      null => _ReferenceEmptyState(
          message: l.referenceEmptyNoFolder,
          onPick: _pickFolder,
        ),
      ReferenceLibraryNotFound() => _ReferenceEmptyState(
          message: l.referenceEmptyNotFound,
          onPick: _pickFolder,
        ),
      final ReferenceLibraryLoaded loaded => _buildBrowser(context, root, loaded.items),
    };
  }

  Widget _buildBrowser(BuildContext context, String root, List<ReferenceItem> all) {
    final AppLocalizations l = context.l10n;
    final Map<ReferenceCategory, int> counts = referenceCounts(all, query: _queryText);
    final List<String> angles = referenceAngles(all);
    // 换了文件夹、选着的视角在新图库里没有 ⇒ 按「全部视角」算（否则一个 chip 都没亮、网格却是空的）。
    final String? angle = angles.contains(_angle) ? _angle : null;
    final List<ReferenceItem> shown = filterReferenceItems(
      all,
      category: _category,
      query: _queryText,
      angle: _category == ReferenceCategory.pose ? angle : null,
    );
    final ReferenceItem? menuItem = _menuItem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LeftPanelFilterField(
          controller: _query,
          hint: l.referenceSearchHint,
          onChanged: (String v) => setState(() => _queryText = v),
        ),
        _ChipRow(
          children: <Widget>[
            for (final ReferenceCategory c in ReferenceCategory.values)
              _ReferenceChip(
                key: ReferenceLibrarySection.categoryKey(c),
                label: _categoryLabel(l, c, counts[c] ?? 0),
                selected: _category == c,
                onTap: () => setState(() => _category = c),
              ),
          ],
        ),
        if (_category == ReferenceCategory.pose && angles.isNotEmpty)
          _ChipRow(
            children: <Widget>[
              _ReferenceChip(
                key: ReferenceLibrarySection.angleKey(null),
                label: l.referenceAngleAll,
                selected: angle == null,
                onTap: () => setState(() => _angle = null),
              ),
              for (final String a in angles)
                _ReferenceChip(
                  key: ReferenceLibrarySection.angleKey(a),
                  label: a,
                  selected: angle == a,
                  onTap: () => setState(() => _angle = a),
                ),
            ],
          ),
        Expanded(
          child: CanvasMenuPopover<ReferenceMenuAction>(
            anchor: _menuAnchor,
            groups: menuItem == null
                ? const <List<InkMenuEntry<ReferenceMenuAction>>>[]
                : _menuGroups(context, menuItem),
            onSelected: _onMenuSelected,
            onDismiss: _closeMenu,
            emptyText: '',
            width: InkMenuPanel.createWidth,
            panelKey: ReferenceLibrarySection.menuKey,
            child: _ReferenceGrid(items: shown, onOpen: _openMenu),
          ),
        ),
        _FolderFooter(path: root, onChange: _pickFolder),
      ],
    );
  }

  /// 菜单项（判据见头注）。菜单开着时才调：这里 watch 选中集 / 节点 / 边，菜单跟着选中变。
  List<List<InkMenuEntry<ReferenceMenuAction>>> _menuGroups(
    BuildContext context,
    ReferenceItem item,
  ) {
    final AppLocalizations l = context.l10n;
    final String canvasId = widget.canvasId;
    final Set<String> selected = ref.watch(canvasSelectionControllerProvider(canvasId));
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
            const <CanvasNode>[];
    ref.watch(canvasEdgesControllerProvider(canvasId));
    final Map<String, String> providerNames = ref.watch(providerDisplayNamesProvider);
    final bool hasProject = ref.watch(activeProjectProvider) != null;

    final ReferenceAttachDecision decision =
        currentReferenceAttachDecision(ref.read, canvasId: canvasId, item: item);
    final CanvasNode? target = selected.length == 1
        ? nodes.where((CanvasNode n) => n.id == selected.single).firstOrNull
        : null;
    final String? reason = referenceAttachBlockText(
      l,
      decision,
      providerNames: providerNames,
      targetGone: selected.length == 1 && target == null,
    );
    // 没有目标节点时，节点名的位置直接写原因（不再多一行）；有目标但点不动时，原因另起一行。
    final String nodeName =
        target == null ? (reason ?? '') : nodeDisplayName(context, target);
    final bool reasonRow = target != null && reason != null;

    return <List<InkMenuEntry<ReferenceMenuAction>>>[
      <InkMenuEntry<ReferenceMenuAction>>[
        InkMenuEntry<ReferenceMenuAction>(
          value: ReferenceMenuAction.attach,
          label: _attachLabel(l, item.category, nodeName),
          enabled: hasProject && decision.plan != null,
        ),
        if (reasonRow)
          InkMenuEntry<ReferenceMenuAction>(
            value: ReferenceMenuAction.reason,
            label: reason,
            enabled: false,
          ),
      ],
      <InkMenuEntry<ReferenceMenuAction>>[
        InkMenuEntry<ReferenceMenuAction>(
          value: ReferenceMenuAction.place,
          label: l.referenceMenuPlace,
          enabled: hasProject,
        ),
        InkMenuEntry<ReferenceMenuAction>(
          value: ReferenceMenuAction.saveCharacter,
          label: l.referenceMenuSaveCharacter,
          enabled: hasProject && item.category == ReferenceCategory.portrait,
        ),
      ],
    ];
  }

  static String _categoryLabel(AppLocalizations l, ReferenceCategory c, int count) =>
      switch (c) {
        ReferenceCategory.pose => l.referenceCategoryPose(count),
        ReferenceCategory.portrait => l.referenceCategoryPortrait(count),
        ReferenceCategory.costume => l.referenceCategoryCostume(count),
      };

  static String _attachLabel(AppLocalizations l, ReferenceCategory c, String node) =>
      switch (c) {
        ReferenceCategory.pose => l.referenceMenuAttachPose(node),
        ReferenceCategory.portrait => l.referenceMenuAttachPortrait(node),
        ReferenceCategory.costume => l.referenceMenuAttachCostume(node),
      };
}

/// 空态：一句说明（或读取失败的报错条）+「选择参考库文件夹」。不画网格。
class _ReferenceEmptyState extends StatelessWidget {
  const _ReferenceEmptyState({this.message, this.banner, required this.onPick});

  /// 说明文字（fg5 居中）。
  final String? message;

  /// 读取失败的报错文案（画成 InkErrorBanner）；与 [message] 二选一。
  final String? banner;

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final String? text = message;
    final String? error = banner;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (error != null) InkErrorBanner(message: error),
          if (text != null)
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.inkTypography.meta.copyWith(color: context.inkColors.fg5),
            ),
          const SizedBox(height: InkSpacing.md),
          Center(
            child: InkButton(
              key: ReferenceLibrarySection.pickFolderKey,
              label: context.l10n.referencePickFolder,
              variant: InkButtonVariant.secondary,
              onPressed: onPick,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行 chip：外边距上 10 / 左右 12 / 下 4，间距 6；放不下折行。
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          InkSpacing.s12,
          InkSpacing.s10,
          InkSpacing.s12,
          InkSpacing.xs,
        ),
        child: Wrap(
          spacing: InkSpacing.s6,
          runSpacing: InkSpacing.s6,
          children: children,
        ),
      );
}

/// 胶囊 chip：与素材页类型 chip 同款（20 高 + 上下 1px 边、圆角 999、10 号字；选中 accentWash 底 + accent 字）。
class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 稿 content-box：20 + 上下 1px 边。
  static const double height = 22;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return InkActivatable(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      focusRingRadius: BorderRadius.circular(InkRadius.pill),
      builder: (BuildContext context, bool hovered, bool focused) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accentWash : null,
          border: Border.all(color: selected ? c.accentWashBorder : c.outline),
          borderRadius: BorderRadius.circular(InkRadius.pill),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: t.micro.copyWith(color: selected ? c.accent : c.fg4),
        ),
      ),
    );
  }
}

/// 两列懒加载网格：行距 10、列距 8；内边距上下 8、左右 12。缩略图解码宽 = 格宽 × dpr。
class _ReferenceGrid extends StatelessWidget {
  const _ReferenceGrid({required this.items, required this.onOpen});

  final List<ReferenceItem> items;
  final void Function(ReferenceItem item, BuildContext tileContext) onOpen;

  /// 格子宽高比（宽 / 高）：缩略图区约 3:4（姿势白模多是竖图）+ 4 + 一行名字。
  static const double _tileAspect = 0.66;

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: InkSpacing.s12,
    vertical: InkSpacing.sm,
  );

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cellWidth =
            (constraints.maxWidth - _padding.horizontal - InkSpacing.sm) / 2;
        final int cacheWidth = (cellWidth * dpr).round().clamp(1, 1 << 14);
        return GridView.builder(
          padding: _padding,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: InkSpacing.s10,
            crossAxisSpacing: InkSpacing.sm,
            childAspectRatio: _tileAspect,
          ),
          itemBuilder: (BuildContext context, int i) => _ReferenceTile(
            key: ReferenceLibrarySection.tileKey(items[i].id),
            item: items[i],
            cacheWidth: cacheWidth,
            onOpen: onOpen,
          ),
        );
      },
    );
  }
}

/// 一格：缩略图（cover、圆角 3、1px outline，hover 提一档）+ 4 + 名字（10 号 fg5，单行省略）。
/// 缩略图读不出来时留 thumb 底；原图不存在要到点了「放进画布 / 当参考」才报（导入失败卡）。
class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    super.key,
    required this.item,
    required this.cacheWidth,
    required this.onOpen,
  });

  final ReferenceItem item;
  final int cacheWidth;
  final void Function(ReferenceItem item, BuildContext tileContext) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return InkActivatable(
      onTap: () => onOpen(item, context),
      semanticLabel: item.name,
      builder: (BuildContext _, bool hovered, bool focused) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.thumbFill,
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: hovered ? c.control : c.outline),
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              child: Image.file(
                File(item.thumbPath),
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: InkSpacing.xs),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.micro.copyWith(color: c.fg5),
          ),
        ],
      ),
    );
  }
}

/// 底部一行：文件夹路径（fg5，过长从中间省略不了就尾部省略）+「换文件夹」（accent 链接）；上沿 1px borderSubtle。
class _FolderFooter extends StatelessWidget {
  const _FolderFooter({required this.path, required this.onChange});

  final String path;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final String label = context.l10n.referenceChangeFolder;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Tooltip(
              message: path,
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.micro.copyWith(color: c.fg5),
              ),
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          InkActivatable(
            key: ReferenceLibrarySection.changeFolderKey,
            onTap: onChange,
            semanticLabel: label,
            builder: (BuildContext context, bool hovered, bool focused) => Text(
              label,
              style: t.meta.copyWith(color: hovered ? c.accentHover : c.accent),
            ),
          ),
        ],
      ),
    );
  }
}
