// 「上次离开时」的唯一判据：启动恢复守卫（restoreLastSessionProvider，债 145）与
// Studio 首页的恢复条共用这一个谓词——开关关掉时两边一起不动，不各写一份。
import '../../../core/models/app_preferences.dart';

/// 有可恢复的上次会话：开关开着，且记了画布与项目。
/// 记录是否仍指向存在的画布 / 项目由调用方各自校验（守卫查库，恢复条查项目列表）。
bool hasRestorableLastSession(AppPreferences p) =>
    p.shellKeepLastCanvas && p.lastCanvasId != null && p.lastProjectId != null;
