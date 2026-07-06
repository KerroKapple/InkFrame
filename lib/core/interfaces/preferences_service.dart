// PreferencesService：应用级 UI 偏好的读写契约。
//
// current 同步可读（供 Notifier build 期 seed）；load 启动调一次填充 current；
// update 走读-改-写并落盘。失败/损坏一律退默认值，不阻断启动、不炸设置操作。
import '../models/app_preferences.dart';

abstract class PreferencesService {
  /// 已加载的当前偏好（同步快照）。
  AppPreferences get current;

  /// 从持久化读取并填充 [current]。缺失/损坏返回默认值。
  Future<AppPreferences> load();

  /// 以 [mutate] 变换当前偏好并落盘。
  Future<void> update(AppPreferences Function(AppPreferences prev) mutate);
}
