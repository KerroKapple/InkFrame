// ScriptedCanvasCommand：撤销栈测试用的命令替身——按脚本依次返回结果，记调用日志。
//
// 每次 revert / apply 消费各自脚本的下一条：
// - [CanvasCommandOutcome]：直接返回；
// - [InkError]：抛出（测「命令抛 InkError ⇒ 栈视同 failed」）；
// - `Completer<CanvasCommandOutcome>`：等测试自己 complete（测撤销在途时的竞态）。
// 脚本用完之后一律返回 [CanvasCommandOutcome.done]。
//
// 日志：调用当下（等结果之前）往 [log] 追加 `'revert:<name>'` / `'apply:<name>'`；
// 与挂起写入 spy 共用一个列表就能断言「先冲写、再撤销」的顺序。
// undo-* 切片测各自命令接栈时复用本替身。
import 'dart:async';

import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

class ScriptedCanvasCommand extends CanvasCommand {
  ScriptedCanvasCommand(
    this.name, {
    List<String>? log,
    List<Object> revertScript = const <Object>[],
    List<Object> applyScript = const <Object>[],
    this.affectedNodeIds = const <String>{},
  })  : log = log ?? <String>[],
        _revertScript = List<Object>.of(revertScript),
        _applyScript = List<Object>.of(applyScript);

  final String name;
  final List<String> log;

  @override
  final Set<String> affectedNodeIds;

  final List<Object> _revertScript;
  final List<Object> _applyScript;

  /// 撤销被调了几次。
  int revertCalls = 0;

  /// 重做被调了几次。
  int applyCalls = 0;

  /// 最近一次调用拿到的环境。
  CanvasCommandEnv? lastEnv;

  /// 替身不走 ARB：直接返回 [name]。
  @override
  String label(AppLocalizations l) => name;

  @override
  Future<CanvasCommandOutcome> revert(CanvasCommandEnv env) {
    revertCalls++;
    lastEnv = env;
    log.add('revert:$name');
    return _next(_revertScript);
  }

  @override
  Future<CanvasCommandOutcome> apply(CanvasCommandEnv env) {
    applyCalls++;
    lastEnv = env;
    log.add('apply:$name');
    return _next(_applyScript);
  }

  static Future<CanvasCommandOutcome> _next(List<Object> script) async {
    if (script.isEmpty) return CanvasCommandOutcome.done;
    final Object entry = script.removeAt(0);
    if (entry is CanvasCommandOutcome) return entry;
    if (entry is InkError) throw entry;
    if (entry is Completer<CanvasCommandOutcome>) return entry.future;
    throw ArgumentError.value(entry, 'script', 'unsupported script entry');
  }
}
