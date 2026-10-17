// InkMenuPanel：通用菜单面板的纯呈现层（画布重设计稿 › 画布交互「右键菜单」，ContextMenus / ShellExport 稿）。
//
// 画布的新建菜单、空白处右键菜单、节点右键菜单（含「加入泳道 ›」子菜单）都画它；菜单栏下拉、工具条「更多」、
// 大纲 / 序列的右键菜单后续也复用它——所以它在 theme 层、不认识任何画布类型：项只是 [InkMenuEntry]（值 + 文案 +
// 图标 / 色点 + 键位提示 + 置灰 / 危险 / 打勾 / 子菜单），选中交回值，开在哪、选了以后做什么都归调用方
// （画布那边是 features/canvas/widgets/canvas_menu/ 的宿主与菜单注册表）。theme 不得 import features/
// （test/quality/no_reverse_layer_import_test.dart）。
//
// 键盘：↑ / ↓ 移动高亮（跳过置灰的项、首尾相接；鼠标悬停也移）、↵ 执行、Esc 关；带子菜单的行 → / ↵ 打开、
// ← / Esc 收回。子菜单经第二个 OverlayPortal 贴在父行旁边（右边放不下翻到左边、下面放不下往上长），与主菜单
// 同一个点击区组（[InkMenuPanel.tapRegionGroup]）——点在子菜单里不算「点外面」。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../icons/ink_glyph.dart';
import '../primitives/ink_activatable.dart';
import '../tokens.dart';
import '../typography.dart';
import 'ink_icon.dart';
import 'ink_primitives.dart';

/// 测试锚点（面板自己画的两块）。值沿用画布菜单拆分前的写法，画布侧 CanvasMenuKeys 的同名常量直接指向这里。
abstract final class InkMenuPanelKeys {
  /// 带搜索框的菜单（新建菜单）的搜索框。
  static const Key search = ValueKey<String>('canvasMenu.search');

  /// 子菜单的框（节点右键菜单「加入泳道 ›」）。
  static const Key submenu = ValueKey<String>('canvasMenu.submenu');
}

/// 搜索过滤：按 [labelOf] 给出的文字做不区分大小写的包含匹配；整组都没匹配上的组不出（不留孤零零的
/// 分隔线）。[query] 去首尾空白后为空 ⇒ 原样返回。与 features/canvas/util/create_menu_model.dart 的
/// filterMenuGroups 同一个口径——theme 层不能反向 import 它，这里留一份。
List<List<E>> _filterMenu<E>(
  List<List<E>> groups,
  String query,
  String Function(E entry) labelOf,
) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return groups;
  final List<List<E>> out = <List<E>>[];
  for (final List<E> group in groups) {
    final List<E> kept = <E>[
      for (final E entry in group)
        if (labelOf(entry).toLowerCase().contains(q)) entry,
    ];
    if (kept.isNotEmpty) out.add(kept);
  }
  return out;
}

/// 菜单的一行（呈现参数）。
@immutable
class InkMenuEntry<T> {
  const InkMenuEntry({
    required this.value,
    required this.label,
    this.glyph,
    this.swatch,
    this.keyHint,
    this.enabled = true,
    this.danger = false,
    this.checked = false,
    this.submenu,
  });

  /// 选中这一行时交回给调用方的值。
  final T value;

  /// 文案；搜索按它过滤。
  final String label;

  /// 左侧 16 号图标（fg4）；null = 留出同宽的空位，文字照样对齐。
  final InkGlyph? glyph;

  /// 左侧色点（子菜单里的泳道行）：8px 方点居中画在图标那一格里；给了就不画 [glyph]。
  final Color? swatch;

  /// 右侧键位提示（等宽 10 号 fg5）；null = 不画。
  final String? keyHint;

  /// false = 置灰（不隐藏）：整行降 0.5、点不动、不可聚焦，↑ / ↓ 跳过它。
  final bool enabled;

  /// 危险操作（删除）：文字用 danger 色。
  final bool danger;

  /// 行尾打勾（子菜单里「当前所在」那一项）。打勾的行不降色——它是「现在就在这儿」，不是「不能用」；
  /// 点不点得动仍看 [enabled]。
  final bool checked;

  /// 非空 = 这一行带子菜单（行尾画 ›）：悬停 / 点击 / → / ↵ 打开，← / Esc 收回；这一行本身不交回。
  final List<List<InkMenuEntry<T>>>? submenu;
}

/// 主菜单与子菜单共用的点击区组的类型（只为拿一个独一份的 const 实例当 groupId）。
class _InkMenuTapGroup {
  const _InkMenuTapGroup();
}

/// 菜单本体（稿：宽 236 / 196、内边距 4、surface4 底 + overlayBorder 边、圆角 6、浮层阴影；
/// 行 28 高、圆角 3、左右 10、图标与文字间距 8；分组之间 1px borderStrong 分隔线、上下各 4）。
///
/// 新建菜单（[searchHint] 非空）顶上是搜索框，一打开就持焦，直接打字就按文字过滤（不区分大小写的包含
/// 匹配），一项都没匹配上时出一行 [emptyText]。右键菜单没有搜索框，焦点落在菜单本身。两种都是
/// ↑ / ↓ 移动高亮（跳过置灰的项；鼠标悬停也移，高亮行 surface5 底）、↵ 执行高亮那一行、Esc 关；点某一行 =
/// 执行它。带子菜单的行：悬停 / 点击 / → / ↵ 打开子菜单（键盘打开时高亮落在子菜单第一项），子菜单开着时
/// ↑ / ↓ / ↵ 归子菜单，← / Esc 收回子菜单；悬停到主菜单别的行也收回。焦点始终在主菜单上。
class InkMenuPanel<T> extends StatefulWidget {
  const InkMenuPanel({
    super.key,
    required this.width,
    required this.groups,
    required this.onSelected,
    required this.onDismiss,
    required this.emptyText,
    this.searchHint,
    this.onFocusChange,
  });

  /// 新建菜单宽（稿 box-sizing: border-box，含边与内边距）。
  static const double createWidth = 236;

  /// 空白处右键菜单 / 节点右键菜单（及其子菜单）宽。
  static const double blankWidth = 196;

  /// 行高。
  static const double rowHeight = 28;

  /// 搜索框高：稿 content-box，28 + 上下 1px 边（与左栏筛选框同一个算法）。
  static const double searchHeight = 30;

  /// 组间分隔线占的高：1px 线 + 上下各 xs。
  static const double separatorExtent = 1 + InkSpacing.xs * 2;

  /// 菜单框外沿到第一行的距离：1px 边 + xs 内边距。子菜单按它对齐到父行。
  static const double frameInset = 1 + InkSpacing.xs;

  /// 泳道色点边长（与泳道标题栏的色点同一个尺寸）。
  static const double swatchSize = 8;

  /// 主菜单与它的子菜单共用的点击区组：宿主的 TapRegion 与子菜单的 TapRegion 都用它——点在子菜单里
  /// 不算「点外面」。
  static const Object tapRegionGroup = _InkMenuTapGroup();

  final double width;

  /// 分组；组与组之间画分隔线。
  final List<List<InkMenuEntry<T>>> groups;
  final ValueChanged<T> onSelected;
  final VoidCallback onDismiss;

  /// 一项都没匹配上时那一行的文案。
  final String emptyText;

  /// 搜索框占位文案；null = 没有搜索框。
  final String? searchHint;

  /// 焦点进 / 出整个菜单（搜索框、菜单本身、Tab 进去的某一行都算在里面）。
  final ValueChanged<bool>? onFocusChange;

  @override
  State<InkMenuPanel<T>> createState() => _InkMenuPanelState<T>();
}

/// 把分组展平成一列（高亮下标按它数）。
List<InkMenuEntry<T>> _flattenMenu<T>(List<List<InkMenuEntry<T>>> groups) =>
    <InkMenuEntry<T>>[
      for (final List<InkMenuEntry<T>> group in groups) ...group,
    ];

/// 从 [from] 起往 [delta] 方向找下一个能点的项，首尾相接；[from] < 0 = 从头（往下）或从尾（往上）找。
/// 一个能点的都没有 ⇒ -1。
int _stepEnabled<T>(List<InkMenuEntry<T>> entries, int from, int delta) {
  final int n = entries.length;
  if (n == 0) return -1;
  int i = from < 0 ? (delta > 0 ? -1 : n) : from;
  for (int k = 0; k < n; k++) {
    i = (i + delta) % n;
    if (entries[i].enabled) return i;
  }
  return -1;
}

/// 一个没有搜索框的菜单框（给定分组）的总高：上下边 + 内边距、行、组间分隔线。
double _menuFrameHeight<T>(List<List<InkMenuEntry<T>>> groups) {
  int rows = 0;
  for (final List<InkMenuEntry<T>> group in groups) {
    rows += group.length;
  }
  final int separators = groups.isEmpty ? 0 : groups.length - 1;
  return InkMenuPanel.frameInset * 2 +
      rows * InkMenuPanel.rowHeight +
      separators * InkMenuPanel.separatorExtent;
}

class _InkMenuPanelState<T> extends State<InkMenuPanel<T>> {
  final FocusNode _panelFocus =
      FocusNode(debugLabel: 'canvasMenu', skipTraversal: true);
  final FocusNode _searchFocus = FocusNode(debugLabel: 'canvasMenu.search');
  final OverlayPortalController _submenuPortal =
      OverlayPortalController(debugLabel: 'canvasMenu.submenu');
  final LayerLink _submenuLink = LayerLink();
  String _query = '';
  int _highlight = 0;

  /// 开着子菜单的那一行（[_visibleEntries] 里的下标）；null = 没开。
  int? _submenuOf;

  /// 子菜单里的高亮（子菜单展平后的下标）；-1 = 还没有（悬停打开时不预选）。
  int _subHighlight = -1;

  bool get _searchable => widget.searchHint != null;

  @override
  void initState() {
    super.initState();
    // 挂上之后再要焦点（与铃铛下拉同一做法）：新建菜单直接能打字，右键菜单的 ↑ / ↓ 直接能用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_searchable ? _searchFocus : _panelFocus).requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  List<List<InkMenuEntry<T>>> get _visibleGroups =>
      _filterMenu<InkMenuEntry<T>>(
        widget.groups,
        _query,
        (InkMenuEntry<T> entry) => entry.label,
      );

  List<InkMenuEntry<T>> get _visibleEntries => _flattenMenu<T>(_visibleGroups);

  /// 此刻真正高亮的那一项：记下的下标还能点就是它，否则退到第一个能点的项；一个都没有 ⇒ -1。
  int _effectiveHighlight(List<InkMenuEntry<T>> entries) {
    if (_highlight >= 0 &&
        _highlight < entries.length &&
        entries[_highlight].enabled) {
      return _highlight;
    }
    return _stepEnabled<T>(entries, -1, 1);
  }

  /// 开着的子菜单的项（展平）；没开 / 那一行已经没有子菜单了 ⇒ null。
  List<InkMenuEntry<T>>? get _submenuEntries {
    final int? parent = _submenuOf;
    if (parent == null) return null;
    final List<InkMenuEntry<T>> entries = _visibleEntries;
    if (parent >= entries.length) return null;
    final List<List<InkMenuEntry<T>>>? groups = entries[parent].submenu;
    return groups == null ? null : _flattenMenu<T>(groups);
  }

  void _onQueryChanged(String query) {
    _closeSubmenu();
    setState(() {
      _query = query;
      _highlight = 0;
    });
  }

  /// 鼠标进入 / 在主菜单某一行里移动：高亮挪过去（置灰的行不高亮）；带子菜单的行顺手打开子菜单，
  /// 主菜单别的行收起开着的子菜单。主菜单不会因为子菜单开合挪位置，所以悬停开合不会来回抖。
  void _onRowHover(int index) {
    final List<InkMenuEntry<T>> entries = _visibleEntries;
    if (index >= entries.length) return;
    if (_submenuOf != null && _submenuOf != index) _closeSubmenu();
    final InkMenuEntry<T> entry = entries[index];
    if (!entry.enabled) return;
    if (entry.submenu != null) {
      if (_submenuOf != index) _openSubmenu(index, viaKeyboard: false);
      return;
    }
    if (index != _highlight) setState(() => _highlight = index);
  }

  /// ↑ / ↓：跳过置灰的项，首尾相接。
  void _moveHighlight(int delta) {
    final List<InkMenuEntry<T>> entries = _visibleEntries;
    final int next = _stepEnabled<T>(entries, _effectiveHighlight(entries), delta);
    if (next >= 0 && next != _highlight) setState(() => _highlight = next);
  }

  void _activateHighlighted() {
    final List<InkMenuEntry<T>> entries = _visibleEntries;
    _activate(_effectiveHighlight(entries), viaKeyboard: true);
  }

  /// 执行第 [index] 项：带子菜单的打开子菜单，否则交回给调用方。置灰的项什么都不做。
  void _activate(int index, {required bool viaKeyboard}) {
    final List<InkMenuEntry<T>> entries = _visibleEntries;
    if (index < 0 || index >= entries.length || !entries[index].enabled) return;
    if (entries[index].submenu != null) {
      _openSubmenu(index, viaKeyboard: viaKeyboard);
      return;
    }
    widget.onSelected(entries[index].value);
  }

  /// 打开第 [index] 行的子菜单。键盘打开时高亮落在子菜单第一个能点的项；鼠标打开时不预选。
  void _openSubmenu(int index, {required bool viaKeyboard}) {
    final List<InkMenuEntry<T>> entries = _visibleEntries;
    if (index < 0 || index >= entries.length) return;
    final List<List<InkMenuEntry<T>>>? groups = entries[index].submenu;
    if (groups == null || !entries[index].enabled) return;
    setState(() {
      _highlight = index;
      _submenuOf = index;
      _subHighlight =
          viaKeyboard ? _stepEnabled<T>(_flattenMenu<T>(groups), -1, 1) : -1;
    });
    _submenuPortal.show();
  }

  void _closeSubmenu() {
    if (_submenuPortal.isShowing) _submenuPortal.hide();
    if (_submenuOf == null) return;
    setState(() {
      _submenuOf = null;
      _subHighlight = -1;
    });
  }

  void _onSubRowHover(int index) {
    final List<InkMenuEntry<T>>? entries = _submenuEntries;
    if (entries == null || index >= entries.length || !entries[index].enabled) {
      return;
    }
    if (index != _subHighlight) setState(() => _subHighlight = index);
  }

  void _moveSubHighlight(int delta) {
    final List<InkMenuEntry<T>>? entries = _submenuEntries;
    if (entries == null) return;
    final int next = _stepEnabled<T>(entries, _subHighlight, delta);
    if (next >= 0 && next != _subHighlight) setState(() => _subHighlight = next);
  }

  void _activateSub(int index) {
    final List<InkMenuEntry<T>>? entries = _submenuEntries;
    if (entries == null ||
        index < 0 ||
        index >= entries.length ||
        !entries[index].enabled) {
      return;
    }
    widget.onSelected(entries[index].value);
  }

  /// 菜单的键盘：挂在包着整块菜单的 Focus 上——搜索框持焦时按键先过它自己、再冒泡到这里，
  /// 比 app 层的文本编辑快捷键（↑ / ↓ 挪光标）离焦点更近，所以 ↑ / ↓ / ↵ / Esc 在这里先截住。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    final bool pressed = event is KeyDownEvent || event is KeyRepeatEvent;
    if (_submenuOf != null) {
      // 子菜单开着：↑ / ↓ / ↵ 归子菜单，← / Esc 只收回子菜单（回到父行），→ 吞掉。
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
        if (pressed) _moveSubHighlight(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        if (event is KeyDownEvent) _activateSub(_subHighlight);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.escape) {
        if (event is KeyDownEvent) _closeSubmenu();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      // → 打开高亮那一行的子菜单；高亮的那一行不带子菜单时照常往下走（有搜索框时是挪光标）。
      final List<InkMenuEntry<T>> entries = _visibleEntries;
      final int index = _effectiveHighlight(entries);
      if (index >= 0 && entries[index].submenu != null) {
        if (event is KeyDownEvent) _openSubmenu(index, viaKeyboard: true);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      if (pressed) _moveHighlight(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) _activateHighlighted();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onDismiss();
      return KeyEventResult.handled;
    }
    // 没有搜索框（右键菜单）时，菜单开着别的键不往画布漏——不然按一下 I 会在菜单底下建个节点。
    // 有搜索框时放行：字母要进搜索框，画布的单键快捷键在打字时本来就让位。松开事件一律放行
    // （按住空格临时平移之类要靠松开收尾）。
    if (_searchable || event is KeyUpEvent) return KeyEventResult.ignored;
    return KeyEventResult.skipRemainingHandlers;
  }

  /// 第 [index] 项的上沿到菜单框外沿的距离（与 build 里搜索框 / 行 / 分隔线的排法同一个算法）。
  double _rowOffset(int index) {
    double y = InkMenuPanel.frameInset +
        (_searchable ? InkMenuPanel.searchHeight + InkSpacing.xs : 0);
    int seen = 0;
    final List<List<InkMenuEntry<T>>> groups = _visibleGroups;
    for (int g = 0; g < groups.length; g++) {
      if (g > 0) y += InkMenuPanel.separatorExtent;
      for (int k = 0; k < groups[g].length; k++) {
        if (seen == index) return y;
        y += InkMenuPanel.rowHeight;
        seen++;
      }
    }
    return y;
  }

  /// 子菜单往哪边长：右边放不下就翻到左边，下面放不下就往上长（底边贴着父行的底边）。按主菜单此刻在屏幕上
  /// 的位置判（主菜单上一帧已经布局好，读它的渲染盒）；还拿不到位置时按默认的右下。窗口尺寸从
  /// [overlayContext]（正在 build 的子菜单浮层）取。
  ({bool left, bool up}) _submenuFlip(
    BuildContext overlayContext,
    int parent,
    List<List<InkMenuEntry<T>>> groups,
  ) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return (left: false, up: false);
    }
    final Offset origin = box.localToGlobal(Offset.zero);
    final Size screen = MediaQuery.sizeOf(overlayContext);
    final double subTop =
        origin.dy + _rowOffset(parent) - InkMenuPanel.frameInset;
    return (
      left: origin.dx + box.size.width + widget.width > screen.width,
      up: subTop + _menuFrameHeight<T>(groups) > screen.height,
    );
  }

  /// 子菜单（第二个 OverlayPortal 的浮层）：贴着父行摆（CompositedTransformFollower 跟着父行走），
  /// 与主菜单同一个点击区组。
  Widget _buildSubmenu(BuildContext overlayContext) {
    final int? parent = _submenuOf;
    final List<InkMenuEntry<T>> entries = _visibleEntries;
    if (parent == null || parent >= entries.length) return const SizedBox.shrink();
    final List<List<InkMenuEntry<T>>>? groups = entries[parent].submenu;
    if (groups == null) return const SizedBox.shrink();
    final ({bool left, bool up}) flip = _submenuFlip(overlayContext, parent, groups);
    final List<Widget> rows = <Widget>[];
    int index = 0;
    for (int g = 0; g < groups.length; g++) {
      if (g > 0) rows.add(const _MenuSeparator());
      for (final InkMenuEntry<T> entry in groups[g]) {
        final int i = index++;
        rows.add(
          _MenuRow<T>(
            key: ValueKey<T>(entry.value),
            entry: entry,
            highlighted: i == _subHighlight,
            onPointerOver: () => _onSubRowHover(i),
            onTap: () => _activateSub(i),
          ),
        );
      }
    }
    const double inset = InkMenuPanel.frameInset;
    final Alignment targetAnchor = flip.left
        ? (flip.up ? Alignment.bottomLeft : Alignment.topLeft)
        : (flip.up ? Alignment.bottomRight : Alignment.topRight);
    final Alignment followerAnchor = flip.left
        ? (flip.up ? Alignment.bottomRight : Alignment.topRight)
        : (flip.up ? Alignment.bottomLeft : Alignment.topLeft);
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _submenuLink,
        showWhenUnlinked: false,
        targetAnchor: targetAnchor,
        followerAnchor: followerAnchor,
        // 父行在菜单框里缩进了 frameInset：子菜单框的外沿贴着主菜单框的外沿，第一行（往上长时是最后一行）
        // 与父行对齐。
        offset: Offset(flip.left ? -inset : inset, flip.up ? inset : -inset),
        child: TapRegion(
          groupId: InkMenuPanel.tapRegionGroup,
          child: TextFieldTapRegion(
            child: _MenuFrame(
              key: InkMenuPanelKeys.submenu,
              width: widget.width,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<List<InkMenuEntry<T>>> groups = _visibleGroups;
    final List<InkMenuEntry<T>> entries = _flattenMenu<T>(groups);
    final int highlight = _effectiveHighlight(entries);
    final List<Widget> rows = <Widget>[];
    int index = 0;
    for (int g = 0; g < groups.length; g++) {
      if (g > 0) rows.add(const _MenuSeparator());
      for (final InkMenuEntry<T> entry in groups[g]) {
        final int i = index++;
        Widget row = _MenuRow<T>(
          key: ValueKey<T>(entry.value),
          entry: entry,
          highlighted: i == highlight,
          onPointerOver: () => _onRowHover(i),
          onTap: () => _activate(i, viaKeyboard: false),
        );
        // 开着子菜单的那一行：子菜单的 CompositedTransformFollower 跟着它走。
        if (i == _submenuOf) {
          row = CompositedTransformTarget(link: _submenuLink, child: row);
        }
        rows.add(row);
      }
    }
    if (entries.isEmpty) rows.add(_MenuEmptyRow(text: widget.emptyText));
    final String? hint = widget.searchHint;
    // 子菜单的 OverlayPortal 放在 Focus 与 Material 里面：子菜单的行在焦点树上仍是菜单的后代（Tab 进去
    // 不算焦点离开菜单），也照样有 Material 祖先。
    return Focus(
      focusNode: _panelFocus,
      onKeyEvent: _onKey,
      onFocusChange: widget.onFocusChange,
      child: Material(
        type: MaterialType.transparency,
        child: OverlayPortal(
          controller: _submenuPortal,
          overlayChildBuilder: _buildSubmenu,
          child: _MenuFrame(
            width: widget.width,
            children: <Widget>[
              if (hint != null)
                _MenuSearchField(
                  focusNode: _searchFocus,
                  hint: hint,
                  onChanged: _onQueryChanged,
                ),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }
}

/// 菜单框：宽 [width]、内边距 xs、surface4 底 + overlayBorder 边、圆角 6、浮层阴影。主菜单与子菜单共用。
class _MenuFrame extends StatelessWidget {
  const _MenuFrame({super.key, required this.width, required this.children});

  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return Container(
      width: width,
      padding: const EdgeInsets.all(InkSpacing.xs),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.overlayBorder),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.overlay,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// 搜索框（稿：28 高 content-box、surface2 底 + outline 边、圆角 3；左侧 13 号 search 图标，
/// 占位文字 11 号 fg6）。
class _MenuSearchField extends StatelessWidget {
  const _MenuSearchField({
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: InkMenuPanel.searchHeight,
      margin: const EdgeInsets.only(bottom: InkSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: <Widget>[
          InkIcon(InkGlyph.search, size: InkIconSize.xs, color: c.fg6),
          const SizedBox(width: InkSpacing.s6),
          Expanded(
            child: TextField(
              key: InkMenuPanelKeys.search,
              focusNode: focusNode,
              onChanged: onChanged,
              style: t.meta.copyWith(color: c.fg2),
              cursorColor: c.accent,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: t.meta.copyWith(color: c.fg6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行：左侧 16 号图标（fg4）或色点 | 8 | 文字（fg2；危险项 danger）| 键位提示（等宽 10 号 fg5）|
/// 打勾 | 子菜单的 ›。点击壳走 InkActivatable；置灰的行给 null（不可点、不可聚焦）。
class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.entry,
    required this.highlighted,
    required this.onPointerOver,
    required this.onTap,
  });

  final InkMenuEntry<T> entry;
  final bool highlighted;

  /// 鼠标进入 / 在行内移动：把高亮挪到这一行（稿：悬停也移动高亮）。
  final VoidCallback onPointerOver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final InkGlyph? glyph = entry.glyph;
    final Color? swatch = entry.swatch;
    final String? keyHint = entry.keyHint;
    final bool enabled = entry.enabled;
    final Widget leading = swatch != null
        ? SizedBox(
            width: InkIconSize.sm,
            child: Center(
              child: InkSquareDot(size: InkMenuPanel.swatchSize, color: swatch),
            ),
          )
        : glyph != null
            ? InkIcon(glyph, size: InkIconSize.sm, color: c.fg4)
            : const SizedBox(width: InkIconSize.sm);
    return MouseRegion(
      onEnter: (_) => onPointerOver(),
      onHover: (_) => onPointerOver(),
      child: InkActivatable(
        onTap: enabled ? onTap : null,
        semanticLabel: entry.label,
        selected: highlighted,
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) => Container(
          height: InkMenuPanel.rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
          decoration: BoxDecoration(
            color: highlighted ? c.surface5 : null,
            borderRadius: BorderRadius.circular(InkRadius.s3),
          ),
          // 置灰（不隐藏）：整行降 0.5。打勾的行（当前所在）照常亮着，只是点不动。
          child: Opacity(
            opacity: enabled || entry.checked ? 1 : 0.5,
            child: Row(
              children: <Widget>[
                leading,
                const SizedBox(width: InkSpacing.sm),
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: entry.danger ? c.danger : c.fg2),
                  ),
                ),
                if (keyHint != null) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  Text(keyHint, style: t.monoSmall.copyWith(color: c.fg5)),
                ],
                if (entry.checked) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  InkIcon(InkGlyph.success, size: InkIconSize.s14, color: c.accent),
                ],
                if (entry.submenu != null) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  Text('›', style: t.body.copyWith(color: c.fg5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 分组之间的分隔线：1px borderStrong，上下各 4。
class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: InkSpacing.xs),
        color: context.inkColors.borderStrong,
      );
}

/// 一项都没匹配上：一行 fg5 说明。
class _MenuEmptyRow extends StatelessWidget {
  const _MenuEmptyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: InkMenuPanel.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.inkTypography.body.copyWith(color: context.inkColors.fg5),
        ),
      );
}
