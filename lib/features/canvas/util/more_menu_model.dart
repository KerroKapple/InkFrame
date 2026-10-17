// 画布浮动工具条「更多」下拉的项：按顺序列动作表（app_actions/app_action_catalog.dart）里的 id。
//
// 文案、可用判据、禁用原因、执行都从动作表那一行取，这里只定「有哪几项、什么顺序」。后续切片往下拉里加项 =
// 在这里追加一行 id。
import '../../app_actions/app_action_ids.dart';

/// 「更多」下拉的项，按显示顺序。
final List<String> kMoreMenuActionIds = <String>[
  AppActionIds.importScript,
];
