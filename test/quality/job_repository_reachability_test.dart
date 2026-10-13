// 死 API 回归闸：`JobRepository` 的每个方法都必须指名一个真实的生产调用点。
//
// 由来：BOARD 记过一条「jobs 读路径是死代码」——`findById` / `listByStatus` /
// `listByCanvas` 在 `lib/` 下零消费点，全部调用都在测试里。测试让它们看起来
// 是活的（真 PG 冒烟测逐条断言过它们的语义），于是三年没人发现从未被调用。
// 这类债只有源码级闸能抓：analyzer 不报「public 方法无人调用」，覆盖率反而满。
//
// 为什么不复用 `shell_transition_reachability_test.dart` 那套「扫 .<name>( 」：
// 那一套**按名字判定、不按接收者类型**。外壳迁移的名字全局唯一，所以够用；
// 仓储方法名在十几个仓储之间大面积重名（`findById` / `listByCanvas` /
// `create` / `update` 每个仓储都有），裸名字扫描会把 `nodes.findById(` 算成
// `jobs.findById(` 的调用点——正好在本闸要抓的那一类上给出假绿。
//
// 所以判据改成「指名道姓」：每个方法在下表里登记一条 (文件, 带接收者的正则)，
// 闸做两件事：
//   1. 接口里声明的方法集 == 表的键集。加了方法不登记 ⇒ 红（必须说出谁在调）；
//      删了方法不撤登记 ⇒ 也红（表不许留幻影）。
//   2. 每条登记的正则必须在它指名的文件里命中。调用点被删 / 改名 ⇒ 当场红，
//      而不是等下一轮审计顺手发现。
//
// 口径（刻意写明限制）：
// - 正则是逐文件文本匹配，不是静态分析。接收者拼写变了（`repo` 改名）要同步
//   改表——这是本闸的成本，也是它能指名道姓的代价。
// - 只管 `JobRepository`：债在这里。推广到其余仓储接口是另一笔账（十几个接口
//   近百个方法，一次性登记的维护面不值得在这一窗里铺开）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _kInterfaceFile = 'lib/core/interfaces/job_repository.dart';

/// 方法 → (生产调用点所在文件, 带接收者的匹配正则)。
///
/// 正则必须含接收者：裸 `\.update\(` 在 job_state_persister 里会被
/// `nodeRepo.update(` 这类同名调用蒙过去。
final Map<String, (String, RegExp)> _kCallSites = <String, (String, RegExp)>{
  'create': (
    'lib/features/generation/generation_controller.dart',
    RegExp(r'(?<![\w$])scope\.jobs\.create\s*\('),
  ),
  'update': (
    'lib/services/job_queue/job_state_persister.dart',
    RegExp(r'(?<![\w$])repo\.update\s*\('),
  ),
  'transitionStatus': (
    'lib/services/job_queue/job_state_persister.dart',
    RegExp(r'(?<![\w$])repo\.transitionStatus\s*\('),
  ),
  'bulkTransition': (
    'lib/services/job_queue/job_state_persister.dart',
    RegExp(r'(?<![\w$])repo\.bulkTransition\s*\('),
  ),
  'purgeExpired': (
    'lib/services/job_queue/job_state_persister.dart',
    RegExp(r'(?<![\w$])repo\.purgeExpired\s*\('),
  ),
  'purgePerCanvasCap': (
    'lib/services/job_queue/job_state_persister.dart',
    RegExp(r'(?<![\w$])repo\.purgePerCanvasCap\s*\('),
  ),
  'hardDelete': (
    'lib/features/generation/generation_controller.dart',
    RegExp(r'(?<![\w$])scope\.jobs\.hardDelete\s*\('),
  ),
};

/// 注释行不算声明。
bool _isComment(String line) {
  final String t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

/// 抽接口里声明的方法名。
///
/// 判据 = 行上第一个「空白 + 小写开头标识符 + (」。覆盖三种写法：
///   `Future<int> update(String id, …);`（单行、位置参）
///   `Future<int> purgeExpired({required Duration retention});`（单行、具名参）
///   `Future<String> create({`（跨行具名参，参数续行自身不含 `(` 故不误配）
/// 小写开头把 `Map(` / `Sql(` 这类类型构造排除在外。
Set<String> _declaredMethods() {
  final File f = File(_kInterfaceFile);
  expect(f.existsSync(), isTrue, reason: '$_kInterfaceFile 不存在');
  final RegExp decl = RegExp(r'\s([a-z]\w*)\s*\(');
  final Set<String> names = <String>{};
  for (final String line in f.readAsLinesSync()) {
    if (_isComment(line)) continue;
    final RegExpMatch? m = decl.firstMatch(line);
    if (m != null) names.add(m.group(1)!);
  }
  return names;
}

void main() {
  test('JobRepository 声明的方法集 == 登记了生产调用点的方法集', () {
    final Set<String> declared = _declaredMethods();
    // 正则失效保护：抽空了说明正则坏了，不是"接口空了"。
    expect(declared, isNotEmpty, reason: '方法清单抽空了 = 正则失效，不是"全删了"');

    final Set<String> registered = _kCallSites.keys.toSet();
    final List<String> unregistered = (declared.difference(registered).toList())
      ..sort();
    final List<String> phantom = (registered.difference(declared).toList())
      ..sort();

    expect(
      unregistered,
      isEmpty,
      reason: '以下 JobRepository 方法没有登记生产调用点：\n'
          '${unregistered.join('\n')}\n'
          '要么在 _kCallSites 里指名道姓登记真实调用点，要么连同它的测试一起删'
          '——"有测试养着的死读路径" 是本闸专治的那种债。',
    );
    expect(
      phantom,
      isEmpty,
      reason: '_kCallSites 登记了接口里已不存在的方法：\n${phantom.join('\n')}\n'
          '删方法时一并撤登记，别让表留幻影。',
    );
  });

  test('每条登记的生产调用点都真实存在', () {
    final List<String> missing = <String>[];
    _kCallSites.forEach((String method, (String, RegExp) site) {
      final (String path, RegExp needle) = site;
      final File f = File(path);
      if (!f.existsSync()) {
        missing.add('$method → $path（文件不存在）');
        return;
      }
      if (!needle.hasMatch(f.readAsStringSync())) {
        missing.add('$method → $path（${needle.pattern} 未命中）');
      }
    });
    expect(
      missing,
      isEmpty,
      reason: '以下登记的调用点已不在：\n${missing.join('\n')}\n'
          '调用点真的搬家了就改表；真的没了就删这个方法——'
          '一个没人调的读路径不该靠测试活着。',
    );
  });
}
