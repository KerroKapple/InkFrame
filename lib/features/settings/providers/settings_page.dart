// 设置浮层当前停在哪一页（左导航）。
//
// keepAlive：浮层关掉即销毁（不保活），再打开回到上次那一页；dev 截图也从这里指定页。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左导航的页。顺序即 Screens 稿第 3 屏的顺序（去掉没有后端的项）。
enum SettingsPage { general, apiKeys, nodeLayout, storage, about }

final settingsPageProvider = StateProvider<SettingsPage>(
  (ref) => SettingsPage.general,
  name: 'settingsPageProvider',
);
