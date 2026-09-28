// 启动恢复上次会话：偏好里有 lastCanvasId/lastProjectId → 校验两者均未软删
// → 置 currentCanvasId 直接回画布。任一无效则清掉记录、停留 Studio。
//
// best-effort：PG 未就绪/查询失败不阻断启动（吞 InkError 静默留在首页）；
// 恢复完成前用户已发生任何导航时不抢占（判据 ShellState.isPristine）。
//
// 是否恢复由偏好开关 shellKeepLastCanvas 单独控制（默认开），且它是这件事
// 的【唯一真相源】——lib 里不再有第二处「悄悄清掉会话记录」的写点
// （T11 退掉了 ⌘K「Back to Studio」里那处 clearLastCanvas）。
//
// 「有没有可恢复的上次会话」这个判据与 Studio 首页的「上次离开时」恢复条共用
// util/last_session.dart 的 hasRestorableLastSession，不各写一份。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../util/last_session.dart';

final restoreLastSessionProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(preferencesServiceProvider);
  final saved = prefs.current;
  // T11：开关关掉 = 这次不回去，但【不清记录】——用户可能只是这次想从
  // Studio 开始，重新打开开关还应当回到同一张画布。
  //
  // 【这个守卫的位置是 load-bearing 的，不只是它的存在】：必须在库查询之前。
  // 挪到下面 `if (!valid)` 之后，「开关关着 + 上次画布恰好已被软删」这一格
  // 就会先判无效、走 clearLastCanvas，把记录静默清掉——开关说"保留"，
  // 应用却没保留，而且用户重新打开开关也回不去了。
  // 由 restore_last_session_test.dart 的
  // `开关 false + 记录已失效（画布被软删）→ 仍不清记录` 钉死：
  // 实跑变异（把本守卫挪到 `if (!valid)` 之后）→ 该例红
  // `Expected: 'cv1' / Actual: <null>`，而喂有效记录的那例仍绿
  // （两例钉的是不同格子，有效记录那一格对位置零鉴别力）。
  if (!hasRestorableLastSession(saved)) return;
  final String canvasId = saved.lastCanvasId!;
  final String projectId = saved.lastProjectId!;

  final bool valid;
  // fix round 1（M-5）：name 的类型窄化放在 try 内、用 `as String?` 安全转型
  // ——旧版本 `projectRow['name'] as String` 落在 try 外，name 为 null（脏行）
  // 时会抛 TypeError 逃出 `on InkError` 网，冒泡成 FutureProvider 未捕获错误。
  // 现在缺 name 直接并入 valid=false，走既有的「清记录、留在首页」路径。
  String? projectName;
  try {
    final canvases = await ref.read(canvasRepositoryProvider.future);
    final projects = await ref.read(projectRepositoryProvider.future);
    // findById 均带 deleted_at IS NULL 过滤：软删的画布/项目直接判无效。
    final canvasRow = await canvases.findById(canvasId);
    final projectRow = await projects.findById(projectId);
    projectName = projectRow?['name'] as String?;
    valid = canvasRow != null &&
        projectRow != null &&
        projectName != null &&
        canvasRow['project_id'] == projectId;
  } on InkError catch (_) {
    return; // 存储未就绪/失败：不恢复也不清记录，下次启动再试。
  }

  if (!valid) {
    await prefs.update((p) => p.copyWith(clearLastCanvas: true));
    return;
  }
  // 债145：守卫判据 = 用户尚未发生任何导航（isPristine 的三项合取：
  // canvasId == null && overlay == null && tab == ShellTab.studio）。
  // tab 默认 studio，所以 PG 就绪窗口内用户切到任何标签 / 开任何浮层 /
  // 自己打开画布，本判据都自然为假——不需要额外的布尔闩。
  // 三项各有一例单测钉死（restore_last_session_test.dart）。
  if (!ref.read(shellControllerProvider).isPristine) return;
  ref.read(shellControllerProvider.notifier).openCanvas(
        canvasId,
        withProject: ProjectRef(id: projectId, name: projectName),
      );
}, name: 'restoreLastSessionProvider');
