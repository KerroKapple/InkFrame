// CanvasCommand：画布撤销栈里的「一步」的契约。
//
// 一步 = 名字 + 受影响的节点 + revert / apply。命令**只持快照**（节点 / 边的
// 前后值、EdgeEndpoints），不持控制器引用：要动画布就经 [CanvasCommandEnv.ref]
// 现取，这样命令活得比某次画布页挂载更久也不会攥着已销毁的对象。
//
// 不用 sealed：具体命令在 models/commands/<x>_command.dart 各自成文件，
// 由后续 undo-* 切片添加；本文件不放任何具体命令。
//
// 进栈时机：调用方把操作**已经做成功之后**才 record（栈只登记、不执行 apply）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';

/// 一次 revert / apply 的结果。
enum CanvasCommandOutcome {
  /// 做成了。
  done,

  /// 要撤 / 要重做的对象已不在（被别处删了）：这一步作废，丢掉，不连带下一步。
  gone,

  /// 没做成（写库失败等）：整步回滚，原样留在栈顶，用户可以再试。
  failed,
}

/// 命令执行时拿到的环境：哪张画布 + 现取各控制器用的 ref。
abstract class CanvasCommandEnv {
  String get canvasId;
  Ref get ref;
}

abstract class CanvasCommand {
  const CanvasCommand();

  /// 这一步叫什么（「删除 2 个节点」这类）。菜单、⌘K、按钮提示共用这一份，
  /// 前面的「撤销 / 重做」由调用方拼。
  String label(AppLocalizations l);

  /// 这一步动到的节点 id（撤销后定位 / 高亮用）。
  Set<String> get affectedNodeIds;

  /// 把画布退回这一步之前。只许抛 InkError（栈视同 failed）。
  Future<CanvasCommandOutcome> revert(CanvasCommandEnv env);

  /// 把这一步重新做一遍（重做）。只许抛 InkError（栈视同 failed）。
  Future<CanvasCommandOutcome> apply(CanvasCommandEnv env);
}
