// 事务作用域的装配：每个仓储都必须绑在传进来的那个会话上。不需要真 PG。
//
// 事务的全部意义就在 `postgresRepositoryScope` 里那一行行 `(s)` 上：哪个仓储接成
// 了别的会话（典型是顺手接成连接池），它的写入就逃出事务——前面几步回滚了，
// 这一步还留着，库里出现半截数据。真 PG 回滚测（transaction_integration_test）
// 只在 CI 的 pg job 里跑、而且只覆盖它走到的那几张表；这里在本机就能把九张表
// 一次查完。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/storage/base_repository.dart';
import 'package:postgres/postgres.dart' show Session;

/// 只用来比身份的会话——任何真调用都说明测试写错了。
class _MarkerSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('装配检查不该真的用到会话：${invocation.memberName}');
}

/// RepositoryScope 的每个 getter。名字与接口声明一一对应，由下面的自证用例守住。
final Map<String, Object Function(RepositoryScope)> _getters =
    <String, Object Function(RepositoryScope)>{
  'nodes': (RepositoryScope s) => s.nodes,
  'edges': (RepositoryScope s) => s.edges,
  'canvas': (RepositoryScope s) => s.canvas,
  'projects': (RepositoryScope s) => s.projects,
  'jobs': (RepositoryScope s) => s.jobs,
  'styleLanes': (RepositoryScope s) => s.styleLanes,
  'batchResults': (RepositoryScope s) => s.batchResults,
  'characters': (RepositoryScope s) => s.characters,
  'promptPresets': (RepositoryScope s) => s.promptPresets,
};

void main() {
  test('postgresRepositoryScope：每个仓储都绑在同一个传入的会话上', () {
    final _MarkerSession session = _MarkerSession();
    final RepositoryScope scope = postgresRepositoryScope(session);

    _getters.forEach((String name, Object Function(RepositoryScope) get) {
      final Object repo = get(scope);
      expect(repo, isA<BaseRepository>(),
          reason: '$name 不是 BaseRepository——看不出它绑在哪个会话上');
      expect(
        identical((repo as BaseRepository).session, session),
        isTrue,
        reason: '$name 没有绑在事务会话上：它的写入会逃出事务，'
            '前面几步回滚了、这一步还留着',
      );
    });
  });

  // 自证：上面那张表必须覆盖 RepositoryScope 声明的**全部**仓储。否则往 scope 里
  // 加第十个仓储、表不动，上一条照样全绿——新仓储接错会话也没人知道。
  test('getter 表 == RepositoryScope 接口声明的全部仓储（自证）', () {
    final String src =
        File('lib/core/interfaces/unit_of_work.dart').readAsStringSync();
    final Set<String> declared = <String>{
      for (final RegExpMatch m in RegExp(
        r'^\s+\w+Repository\s+get\s+(\w+)\s*;',
        multiLine: true,
      ).allMatches(src))
        m.group(1)!,
    };

    expect(declared, isNotEmpty, reason: '一个 getter 都没抽到 ⇒ 正则失效，本闸形同不存在');
    expect(
      declared,
      unorderedEquals(_getters.keys),
      reason: 'RepositoryScope 的仓储清单变了，本测试的 _getters 表没跟上',
    );
  });
}
