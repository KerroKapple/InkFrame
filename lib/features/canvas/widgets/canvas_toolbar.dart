// CanvasToolbar：画布舞台顶部居中的浮动工具条（画布重设计稿「画布页 · 改后」，图标集 v1）。
//
// 一座浮岛，三组：选择 · 平移 | 图像 · 视频 · 文本 · 分镜 · 泳道 · 连线 | 更多。
// 取代原来的左侧 37px 工具条（七个几乎一样的方块挤在左沿，左沿要让给导航条）和右下角
// 32×32 加号（建节点藏在一层菜单后面）。画布四角各有归属：顶部居中 = 本条、底部居中 =
// 提示词条、左下 = 缩放条、右下 = 通知卡。
//
// - 模式键（选择 / 平移）：亮的是「此刻实际在用」的那个。平移看 canvasPanActiveProvider
//   （工具 = 平移，或按住空格），所以按住空格时平移键也亮；连线模式下亮的是连线键，
//   选择键不亮（点选择 = 退出连线，与旧工具条同义）。
// - 建节点 / 泳道 / 连线：点下即生效，动作本体在 util/canvas_tool_actions.dart，
//   与 I / G / T / F / L 快捷键是同一条路径。连线键只在恰好选中一个节点或已在连线模式时可按。
// - 更多：小菜单，目前只有「导入脚本…」——整条链从视口中心起铺。
// - 每个键都走 InkActivatable（Tab 可达、Enter / Space 激活、焦点环）；tooltip =「名称  键位」，
//   键位取 canvas_shortcuts.dart 的 CanvasToolKeys，与快捷键表同源——改键位不会只改一半。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../storyboard/widgets/script_import_dialog.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_tool_mode.dart';
import '../providers/link_mode_controller.dart';
import '../util/canvas_tool_actions.dart';
import 'canvas_shortcuts.dart';

/// 「更多」菜单项。
enum _MoreAction { importScript }

class CanvasToolbar extends ConsumerWidget {
  const CanvasToolbar({super.key, required this.canvasId});

  final String canvasId;

  /// 工具键的测试锚点：select / pan / image / video / text / shot / lane / link / more。
  static Key keyOf(String tool) => ValueKey<String>('canvasToolbar-$tool');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InkColors c = context.inkColors;
    final l = context.l10n;
    final bool panning = ref.watch(canvasPanActiveProvider(canvasId));
    final bool linking = ref.watch(linkModeControllerProvider(canvasId)) != null;
    // 只订阅选中个数（连线键的可按判据）：选中换成别的节点、个数不变时本条不必重建。
    final int selectedCount = ref.watch(
      canvasSelectionControllerProvider(canvasId)
          .select((Set<String> s) => s.length),
    );

    void addNode(CanvasNodeType type) =>
        addNodeAtViewportCenter(context, ref, canvasId: canvasId, type: type);

    final List<List<Widget>> groups = <List<Widget>>[
      <Widget>[
        _ToolButton(
          key: keyOf('select'),
          tool: _Tool(
            label: l.canvasToolSelect,
            glyph: InkGlyph.select,
            keys: <String>[CanvasToolKeys.select.keyLabel],
            active: !panning && !linking,
            toggle: true,
            onTap: () => activateSelectTool(ref, canvasId: canvasId),
          ),
        ),
        _ToolButton(
          key: keyOf('pan'),
          tool: _Tool(
            label: l.canvasToolPan,
            glyph: InkGlyph.pan,
            keys: <String>[CanvasToolKeys.pan.keyLabel, l.canvasToolPanHoldSpace],
            active: panning,
            toggle: true,
            onTap: () => ref.read(canvasToolModeProvider(canvasId).notifier).pan(),
          ),
        ),
      ],
      <Widget>[
        _ToolButton(
          key: keyOf('image'),
          tool: _Tool(
            label: l.canvasToolImageNode,
            glyph: InkGlyph.imageConfig,
            keys: <String>[CanvasToolKeys.imageNode.keyLabel],
            onTap: () => addNode(CanvasNodeType.image),
          ),
        ),
        _ToolButton(
          key: keyOf('video'),
          tool: _Tool(
            label: l.canvasToolVideoNode,
            glyph: InkGlyph.videoConfig,
            keys: <String>[CanvasToolKeys.videoNode.keyLabel],
            onTap: () => addNode(CanvasNodeType.video),
          ),
        ),
        _ToolButton(
          key: keyOf('text'),
          tool: _Tool(
            label: l.canvasToolTextNode,
            glyph: InkGlyph.text,
            keys: <String>[CanvasToolKeys.textNode.keyLabel],
            onTap: () => addNode(CanvasNodeType.text),
          ),
        ),
        // 分镜没有单键（稿未分配），tooltip 只有名称。
        _ToolButton(
          key: keyOf('shot'),
          tool: _Tool(
            label: l.canvasToolShotNode,
            glyph: InkGlyph.shot,
            onTap: () => addNode(CanvasNodeType.shot),
          ),
        ),
        _ToolButton(
          key: keyOf('lane'),
          tool: _Tool(
            label: l.canvasToolLane,
            glyph: InkGlyph.lane,
            keys: <String>[CanvasToolKeys.lane.keyLabel],
            onTap: () => addLaneViaDialog(context, ref, canvasId: canvasId),
          ),
        ),
        _ToolButton(
          key: keyOf('link'),
          tool: _Tool(
            label: l.canvasToolLink,
            glyph: InkGlyph.link,
            keys: <String>[CanvasToolKeys.link.keyLabel],
            active: linking,
            toggle: true,
            // 不可按时给 null 而不是空闭包：连焦点都到不了（InkActivatable 性质 4）。
            onTap: canToggleLink(linking: linking, selectedCount: selectedCount)
                ? () => toggleLinkMode(ref, canvasId: canvasId)
                : null,
          ),
        ),
      ],
      <Widget>[
        // Builder 取的是「更多」键自己的 context：菜单要贴着这个键往下弹。
        Builder(
          builder: (BuildContext anchor) => _ToolButton(
            key: keyOf('more'),
            tool: _Tool(
              label: l.canvasToolMore,
              glyph: InkGlyph.more,
              onTap: () => _showMoreMenu(anchor, ref),
            ),
          ),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(InkSpacing.xs),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.elevated,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int g = 0; g < groups.length; g++) ...<Widget>[
            if (g > 0) const _GroupSeparator(),
            for (int i = 0; i < groups[g].length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: InkSpacing.s2),
              groups[g][i],
            ],
          ],
        ],
      ),
    );
  }

  /// 「更多」菜单：贴着键的下沿弹（工具条在舞台顶部，往下展开）。
  Future<void> _showMoreMenu(BuildContext anchor, WidgetRef ref) async {
    final RenderBox button = anchor.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final Offset below = Offset(0, button.size.height);
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(below, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(below), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final InkColors c = anchor.inkColors;
    final _MoreAction? picked = await showMenu<_MoreAction>(
      context: anchor,
      position: position,
      color: c.surface4,
      items: <PopupMenuEntry<_MoreAction>>[
        PopupMenuItem<_MoreAction>(
          value: _MoreAction.importScript,
          child: Text(
            anchor.l10n.canvasAddImportScript,
            style: anchor.inkTypography.body.copyWith(color: c.fg2),
          ),
        ),
      ],
    );
    if (picked == null || !anchor.mounted) return;
    switch (picked) {
      case _MoreAction.importScript:
        // 整条链从视口中心起铺——第一镜正对着用户，后续沿 x 轴排开。
        await showScriptImportDialog(
          anchor,
          canvasId: canvasId,
          origin: viewportCenteredNodeOrigin(
            ref,
            canvasId: canvasId,
            type: CanvasNodeType.shot,
          ),
        );
    }
  }
}

/// 一个工具键的全部呈现参数。
@immutable
class _Tool {
  const _Tool({
    required this.label,
    required this.glyph,
    required this.onTap,
    this.keys = const <String>[],
    this.active = false,
    this.toggle = false,
  });

  final String label;
  final InkGlyph glyph;

  /// null = 此刻不可按（禁用色、不可聚焦）。
  final VoidCallback? onTap;

  /// tooltip 里名称后面的键位（空 = 只有名称）。
  final List<String> keys;

  /// 亮（琥珀图标 + accentWash 底）。
  final bool active;

  /// 有开 / 关两态的键（选择、平移、连线）：读屏上报 selected；动作键不声明。
  final bool toggle;

  String get tooltip {
    if (keys.isEmpty) return label;
    final String keyText = keys.join(' · ');
    return '$label  $keyText';
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({super.key, required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final bool enabled = tool.onTap != null;
    return InkActivatable(
      onTap: tool.onTap,
      semanticLabel: tool.label,
      selected: tool.toggle ? tool.active : null,
      tooltip: tool.tooltip,
      focusRingRadius: BorderRadius.circular(InkRadius.sm),
      builder: (BuildContext context, bool hovered, bool focused) {
        final Color fg = !enabled ? c.fg6 : (tool.active ? c.accent : c.fg3);
        final Color? bg =
            tool.active ? c.accentWash : (hovered && enabled ? c.surface5 : null);
        return Container(
          width: InkToolbarSize.button,
          height: InkToolbarSize.button,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(InkRadius.sm),
          ),
          child: InkIcon(tool.glyph, size: InkIconSize.md, color: fg),
        );
      },
    );
  }
}

/// 组间分隔：1px 竖线，左右各留 xs。
class _GroupSeparator extends StatelessWidget {
  const _GroupSeparator();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: InkToolbarSize.separatorHeight,
        margin: const EdgeInsets.symmetric(horizontal: InkSpacing.xs),
        color: context.inkColors.control,
      );
}
