// 设置浮层当前停在哪一页（左导航）。
//
// keepAlive：浮层关掉即销毁（不保活），再打开回到上次那一页；dev 截图也从这里指定页。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左导航的页。顺序即 Screens 稿第 3 屏的顺序（「语言」并入常规页，用户 2026-09-24）。
/// P7 补上稿上的快捷键 / 性能 / 网络三页——三页都是只读的，各自的「为什么只读」
/// 写在对应 section 的头注里。
enum SettingsPage {
  general,
  apiKeys,
  shortcuts,
  performance,
  nodeLayout,
  network,
  storage,
  about,
}

final settingsPageProvider = StateProvider<SettingsPage>(
  (ref) => SettingsPage.general,
  name: 'settingsPageProvider',
);
