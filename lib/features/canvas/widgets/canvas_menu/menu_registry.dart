// 画布右键菜单的注册表：空白处右键菜单与节点右键菜单的每一项是一条 [CanvasMenuItemDef]（id + 归哪个菜单 +
// 组号 + 组内序号 + 怎么画 + 选了做什么），菜单由 [buildMenuGroups] 按这张表现排。后续切片加菜单项 =
// 新文件里写一条定义 + 在 [kCanvasMenuItems] 里追加一行，不碰宿主。新建菜单不进表：它的项由
// util/create_menu_model.dart 的 CreateMenuAction 驱动（create_menu_entries.dart）。
//
// 【排序】先按组号升序、组内按序号升序；组与组之间一条分隔线。build 返回 null 的项不出，一项都不剩的组
// 整组不出（不留多余分隔线）。稿（ContextMenus「排序沿用节点菜单：动作 | 编排 | 删除」、GapsCanvas「节点右键
// 补项」）定下的组号约定——后续连线 / 泳道 / 多选菜单按它插，留空号就是为了插：
//   - 节点：10 做（生成 · 复制一份）/ 20 take / 30 归类 · 定位（存为角色 · 加入泳道 › · 在序列中定位）/
//     80 停用 / 90 删除。
//   - 空白处：0 撤销 · 重做 / 10 新建 · 导入 / 30 粘贴 / 50 选择 · 视图（全选 · 适应视图）/ 70 吸附开关。
//
// 【id】全局唯一、不含冒号（`blank.<x>` / `node.<x>`）。子菜单行的值是 `<id>:<参数>`（「加入泳道 ›」的
// `node.laneSubmenu:<laneId>`），派发时只拿第一个冒号之前的部分比 id（[menuItemForPick]），参数由那一项的
// run 自己从 [CanvasMenuContext.picked] 里拆。不可用的项置灰不隐藏（build 照样返回、enabled: false），
// 键位提示从快捷键表取（settings/util/shortcut_catalog.dart 的 canvasShortcutLabel）。
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/components/ink_menu_panel.dart';
import 'blank_menu_entries.dart';
import 'canvas_menu_request.dart';
import 'node_menu_entries.dart';

/// 这一项出在哪个菜单里。
enum CanvasMenuScope {
  /// 节点右键菜单。
  node,

  /// 空白处右键菜单。
  blank,
}

/// 一项菜单 build / run 时拿到的上下文。
class CanvasMenuContext {
  const CanvasMenuContext({
    required this.context,
    required this.ref,
    required this.canvasId,
    required this.request,
    required this.targets,
    this.picked = '',
    this.dismiss,
  });

  /// build 时是菜单浮层的 context（取颜色 / 文案）；run 时是宿主的 context——菜单此刻可能已经卸载，
  /// 开对话框 / 弹错误卡要用还挂着的那一个。
  final BuildContext context;

  /// build 时可以 watch（菜单跟着节点 / 泳道 / 提交状态变）；run 时只 read。
  final WidgetRef ref;
  final String canvasId;

  /// 开这个菜单的请求（锚点、右键的卡）。
  final CanvasMenuRequest request;

  /// 作用的节点集（node_menu_model.nodeMenuTargets 的口径：右键的卡在选中集里 = 整个选中集）。空白处为空集。
  final Set<String> targets;

  /// run 时 = 被选中那一行的值（子菜单行带参数 `<id>:<参数>`）；build 时为 ''。
  final String picked;

  /// run 里先调它：关菜单 + 焦点当场还给画布（宿主的 _dismiss）。「新建…」不调——原地换成新建菜单。
  final VoidCallback? dismiss;
}

/// 注册表里的一项。
class CanvasMenuItemDef {
  const CanvasMenuItemDef({
    required this.id,
    required this.scope,
    required this.group,
    required this.order,
    required this.build,
    required this.run,
  });

  /// 全局唯一、不含冒号；也是这一行交回来的值（子菜单行在它后面接 `:<参数>`）。
  final String id;
  final CanvasMenuScope scope;

  /// 组号（见头注的约定）；同组的项挨着排，组间一条分隔线。
  final int group;

  /// 组内序号。
  final int order;

  /// 这一行怎么画；null = 这一项此刻不出。
  final InkMenuEntry<String>? Function(CanvasMenuContext c) build;

  /// 选了这一行做什么。
  final FutureOr<void> Function(CanvasMenuContext c) run;
}

/// 全部菜单项。后续切片在这里追加一行。
final List<CanvasMenuItemDef> kCanvasMenuItems = <CanvasMenuItemDef>[
  ...blankMenuItems,
  ...nodeMenuItems,
];

/// [scope] 那个菜单的分组：先按组号、组内按序号排；build 返回 null 的项不出，空组不出。
/// [items] 缺省 = [kCanvasMenuItems]（测试传自己的表）。
List<List<InkMenuEntry<String>>> buildMenuGroups(
  CanvasMenuScope scope,
  CanvasMenuContext c, {
  List<CanvasMenuItemDef>? items,
}) {
  final List<CanvasMenuItemDef> defs = <CanvasMenuItemDef>[
    for (final CanvasMenuItemDef d in items ?? kCanvasMenuItems)
      if (d.scope == scope) d,
  ];
  defs.sort((CanvasMenuItemDef a, CanvasMenuItemDef b) {
    final int byGroup = a.group.compareTo(b.group);
    return byGroup != 0 ? byGroup : a.order.compareTo(b.order);
  });
  final List<List<InkMenuEntry<String>>> groups = <List<InkMenuEntry<String>>>[];
  List<InkMenuEntry<String>> bucket = <InkMenuEntry<String>>[];
  int? currentGroup;
  for (final CanvasMenuItemDef d in defs) {
    if (d.group != currentGroup) {
      if (bucket.isNotEmpty) groups.add(bucket);
      bucket = <InkMenuEntry<String>>[];
      currentGroup = d.group;
    }
    final InkMenuEntry<String>? entry = d.build(c);
    if (entry != null) bucket.add(entry);
  }
  if (bucket.isNotEmpty) groups.add(bucket);
  return groups;
}

/// 选中的那一行 [picked] 归哪一项：取第一个冒号之前的部分比 id（`<id>:<参数>` 与裸 id 都认）。
/// 找不到、或者那一项不在 [scope] 这个菜单里 ⇒ null。[items] 缺省 = [kCanvasMenuItems]。
CanvasMenuItemDef? menuItemForPick(
  CanvasMenuScope scope,
  String picked, {
  List<CanvasMenuItemDef>? items,
}) {
  final int colon = picked.indexOf(':');
  final String id = colon < 0 ? picked : picked.substring(0, colon);
  for (final CanvasMenuItemDef d in items ?? kCanvasMenuItems) {
    if (d.id == id) return d.scope == scope ? d : null;
  }
  return null;
}
