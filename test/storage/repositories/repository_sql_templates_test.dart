// Repository SQL 模板单测（不触 PG）：
//   - 各 repo 的 create / list / softDelete / transition SQL 骨架正确
//   - 参数正确绑定
//   - JobRepository.transitionStatus 使用 ANY(@from)
//   - PurgeExpired / PurgePerCanvasCap 包含 PRD §21 retention 字面量
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/repositories/postgres_batch_result_repository.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_character_repository.dart';
import 'package:inkframe/storage/repositories/postgres_edge_repository.dart';
import 'package:inkframe/storage/repositories/postgres_job_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:inkframe/storage/repositories/postgres_prompt_preset_repository.dart';
import 'package:inkframe/storage/repositories/postgres_style_lane_repository.dart';
import 'package:inkframe/storage/repositories/postgres_video_backfill_repository.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('ProjectRepository SQL', () {
    test('create 使用 RETURNING id', () async {
      final spy = _SpySession(returnRows: const [
        ['new-id']
      ]);
      final repo = PostgresProjectRepository(spy);
      final id = await repo.create(name: 'P');
      expect(id, 'new-id');
      expect(spy.lastSql, contains('INSERT INTO projects'));
      expect(spy.lastSql, contains('RETURNING id'));
    });

    test('listAll 过滤 deleted_at IS NULL 并按 created_at DESC', () async {
      final spy = _SpySession();
      await PostgresProjectRepository(spy).listAll();
      expect(spy.lastSql, contains('WHERE deleted_at IS NULL'));
      expect(spy.lastSql, contains('ORDER BY created_at DESC'));
    });

    test('listTrashed 过滤 deleted_at IS NOT NULL', () async {
      final spy = _SpySession();
      await PostgresProjectRepository(spy).listTrashed();
      expect(spy.lastSql, contains('deleted_at IS NOT NULL'));
    });

    test('softDelete 写 deleted_at', () async {
      final spy = _SpySession();
      await PostgresProjectRepository(spy).softDelete('p1');
      expect(spy.lastSql, contains('UPDATE projects SET'));
      expect(spy.lastParams?['p_deleted_at'], isA<String>());
    });
  });

  group('CanvasRepository SQL', () {
    test('create 带 base_style', () async {
      final spy = _SpySession(returnRows: const [
        ['c1']
      ]);
      final id = await PostgresCanvasRepository(spy).create(
        projectId: 'p',
        name: 'C',
        baseStylePrefix: 'pre',
        baseStyleSuffix: 'suf',
      );
      expect(id, 'c1');
      expect(spy.lastSql, contains('INSERT INTO canvases'));
      expect(spy.lastParams?['pre'], 'pre');
      expect(spy.lastParams?['suf'], 'suf');
    });

    // 列名带了 `c.` 限定：读路径 JOIN projects 过滤项目软删后，created_at /
    // name / id / deleted_at 在两张表里都存在，裸写会被 PG 判 ambiguous。
    test('listByProject 过滤 + order ASC', () async {
      final spy = _SpySession();
      await PostgresCanvasRepository(spy).listByProject('p1');
      expect(spy.lastSql, contains('c.project_id = @pid'));
      expect(spy.lastSql, contains('ORDER BY c.created_at ASC'));
    });

    test('listByProjects 单条 ANY(@pids) 批量查询（反 N+1）', () async {
      final spy = _SpySession();
      await PostgresCanvasRepository(spy)
          .listByProjects(const ['p1', 'p2']);
      expect(spy.lastSql, contains('c.project_id = ANY(@pids)'));
      expect(spy.lastSql, contains('c.deleted_at IS NULL'));
      expect(spy.lastSql,
          contains('ORDER BY c.project_id ASC, c.created_at ASC'));
      expect(spy.lastParams?['pids'], const ['p1', 'p2']);
    });
  });

  group('NodeRepository SQL', () {
    test('create 将 type_config JSON 编码 + ::jsonb cast', () async {
      final spy = _SpySession(returnRows: const [
        ['n1']
      ]);
      await PostgresNodeRepository(spy).create(
        canvasId: 'c',
        type: 'image',
        nodeRole: 'config',
        typeConfig: {'prompt': 'hello'},
      );
      expect(spy.lastSql, contains('@cfg::jsonb'));
      expect(spy.lastParams?['cfg'], contains('"prompt":"hello"'));
    });

    test('listAllMediaUrls UNION 三个 url 键 + 不过滤软删（LB-13 引用集）',
        () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).listAllMediaUrls();
      expect(spy.lastSql, contains("type_config->>'image_url'"));
      expect(spy.lastSql, contains("type_config->>'video_url'"));
      expect(spy.lastSql, contains("type_config->>'thumbnail_url'"));
      expect(spy.lastSql, contains('UNION ALL'));
      // 关键：绝不含 deleted_at 过滤——软删产物必须算被引用（安全#2）。
      expect(spy.lastSql, isNot(contains('deleted_at')));
      expect(spy.lastSql, contains("url IS NOT NULL AND url <> ''"));
    });

    test('listOrphanResults 使用 node_role result + source_node_id IS NULL',
        () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).listOrphanResults('c');
      expect(spy.lastSql, contains("node_role = 'result'"));
      expect(spy.lastSql, contains('source_node_id IS NULL'));
    });

    // CR-01：nodes 行必须带 project_id（来自 canvases JOIN），
    // 否则生成链路读到 null → 产物静默丢弃。
    test('findById JOIN canvases 带出 project_id', () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).findById('n1');
      expect(spy.lastSql, contains('c.project_id'));
      expect(spy.lastSql, contains('JOIN canvases c ON c.id = n.canvas_id'));
      expect(spy.lastSql, contains('n.deleted_at IS NULL'));
    });

    test('listByCanvas JOIN canvases 带出 project_id 并保持排序', () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).listByCanvas('c1');
      expect(spy.lastSql, contains('c.project_id'));
      expect(spy.lastSql, contains('JOIN canvases c ON c.id = n.canvas_id'));
      expect(spy.lastSql, contains('ORDER BY n.z_index ASC, n.created_at ASC'));
    });

    test('listOrphanResults JOIN canvases 带出 project_id', () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).listOrphanResults('c1');
      expect(spy.lastSql, contains('c.project_id'));
      expect(spy.lastSql, contains('JOIN canvases c ON c.id = n.canvas_id'));
    });

    test('softDeleteEmptyOrphanResults 空壳判据 + 双守卫 + LB-01 状态常量',
        () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).softDeleteEmptyOrphanResults();
      final sql = spy.lastSql!;
      // SET deleted_at + updated_at（updated_at 质量闸）。
      expect(sql, contains('UPDATE nodes SET'));
      expect(sql, contains('deleted_at = now()'));
      expect(sql, contains('updated_at = now()'));
      // 目标：未删的 result 节点。
      expect(sql, contains("node_role = 'result'"));
      expect(sql, contains('deleted_at IS NULL'));
      // 空判据：3 个 url 键皆空。
      expect(sql, contains("COALESCE(type_config->>'image_url','') = ''"));
      expect(sql, contains("COALESCE(type_config->>'video_url','') = ''"));
      expect(sql, contains("COALESCE(type_config->>'thumbnail_url','') = ''"));
      // 成功 slot 守卫（SlotStatuses.success，LB-01）。
      expect(sql, contains('NOT EXISTS (SELECT 1 FROM batch_results br'));
      expect(sql, contains("br.status = 'success'"));
      // 在途 job 守卫（JobStatuses.pending/submitted/polling，LB-01）。
      expect(sql, contains('NOT EXISTS (SELECT 1 FROM jobs j'));
      expect(sql, contains("j.status IN ('pending','submitted','polling')"));
    });
  });

  // ===== 画布软删过滤（BOARD「删掉正在打开的画布 / 项目后外壳上下文悬空」第 3 件）=====
  //
  // 画布软删【不级联】到 nodes / edges / style_lanes（softDelete 只碰 canvases
  // 那一行），于是这三张表的行在画布被删后仍 `deleted_at IS NULL`。只过滤自身
  // 软删的读路径会把已删画布的内容照常读出来——界面上完全看不出它已被删，
  // 用户的改动会一直写进一张已删画布。
  //
  // 表驱动：新增 / 改写任何一条 canvas 域读路径而忘了带画布软删过滤，这里当场红。
  // 判据是 `JOIN canvases` + 同一行上的 `c.deleted_at IS NULL`（分成两条 expect
  // 会让 `JOIN canvases c ON c.id = x` 配一句无关的 `c.deleted_at IS NULL` 也过）。
  group('canvas 域读路径必带画布软删过滤', () {
    const String joinAlive = 'JOIN canvases c ON c.id =';
    const String aliveOnly = 'AND c.deleted_at IS NULL';

    final Map<String, Future<void> Function(_SpySession)> reads =
        <String, Future<void> Function(_SpySession)>{
      'nodes.findById': (s) => PostgresNodeRepository(s).findById('n1'),
      'nodes.listByCanvas': (s) => PostgresNodeRepository(s).listByCanvas('c1'),
      'nodes.listOrphanResults': (s) =>
          PostgresNodeRepository(s).listOrphanResults('c1'),
      'edges.findById': (s) => PostgresEdgeRepository(s).findById('e1'),
      'edges.listByCanvas': (s) => PostgresEdgeRepository(s).listByCanvas('c1'),
      'edges.listOutgoing': (s) => PostgresEdgeRepository(s).listOutgoing('a'),
      'edges.listIncoming': (s) => PostgresEdgeRepository(s).listIncoming('b'),
      'style_lanes.findById': (s) =>
          PostgresStyleLaneRepository(s).findById('l1'),
      'style_lanes.listByCanvas': (s) =>
          PostgresStyleLaneRepository(s).listByCanvas('c1'),
      'batch_results.listSuccessByProject': (s) =>
          PostgresBatchResultRepository(s).listSuccessByProject('p1'),
      'video_backfill.listMissingDuration': (s) =>
          PostgresVideoBackfillRepository(s).listMissingDuration(),
    };

    reads.forEach((String name, Future<void> Function(_SpySession) run) {
      test('$name 只读活画布', () async {
        final spy = _SpySession();
        await run(spy);
        final String sql = spy.lastSql!;
        expect(
          RegExp('$joinAlive [a-z]+\\.canvas_id $aliveOnly').hasMatch(sql),
          isTrue,
          reason: '$name 的 SQL 必须 JOIN canvases 并在 JOIN 条件上带 '
              'c.deleted_at IS NULL，否则已软删画布的行照常读出：\n$sql',
        );
      });
    });

    // 反向护栏：这两条是孤儿回收的「被引用集」，软删行必须算被引用（安全#2）。
    // 上面那张表长大时顺手给它们也加过滤，等于悄悄把用户还能恢复的产物删掉。
    test('孤儿回收引用集绝不过滤软删（反向）', () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).listAllMediaUrls();
      expect(spy.lastSql, isNot(contains('deleted_at')));
      await PostgresBatchResultRepository(spy).listAllOutputUrls();
      expect(spy.lastSql, isNot(contains('deleted_at')));
    });
  });

  // ===== 项目软删过滤（BOARD 206：#254 那个洞的上一级同款）=====
  //
  // 项目软删【不级联】到 canvases / characters / prompt_presets
  // （projects.softDelete 只碰 projects 那一行），于是这三张表的行在项目被删后
  // 仍 `deleted_at IS NULL`。只过滤自身软删的读路径会把回收站里项目的画布 /
  // 角色 / 预设照常读出来。
  //
  // 这个洞接上 #254 的 closeProject() 之后在产品里**已不可达**（画布/角色/预设的
  // projectId 全部来自已过滤软删的 projects.listAll() 或 ShellState.project，
  // 而后者在项目被删时当场清掉）。补它是纵深防御：那条不可达性是五个 UI 事实的
  // 合取，每一条都会悄悄烂掉——同一轮里就逮到 BOARD 另一条「openCanvas 三个
  // 调用点全部带 withProject」早已过期（实际五个，其中一个不带）。SQL 层是这条
  // 不变量唯一不会随 UI 改动而腐烂的地方。
  //
  // 判据同 #254：`JOIN projects` + **同一条 JOIN 子句上**的 `p.deleted_at IS NULL`
  // （拆成两条 expect 会让无关位置的同名串混过去）。
  group('项目域读路径必带项目软删过滤', () {
    const String joinAlive = 'JOIN projects p ON p.id =';
    const String aliveOnly = 'AND p.deleted_at IS NULL';

    final Map<String, Future<void> Function(_SpySession)> reads =
        <String, Future<void> Function(_SpySession)>{
      'canvases.findById': (s) => PostgresCanvasRepository(s).findById('c1'),
      'canvases.listByProject': (s) =>
          PostgresCanvasRepository(s).listByProject('p1'),
      'canvases.listByProjects': (s) =>
          PostgresCanvasRepository(s).listByProjects(const ['p1', 'p2']),
      'characters.findById': (s) =>
          PostgresCharacterRepository(s).findById('ch1'),
      'characters.listByProject': (s) =>
          PostgresCharacterRepository(s).listByProject('p1'),
      'prompt_presets.findById': (s) =>
          PostgresPromptPresetRepository(s).findById('pp1'),
      'prompt_presets.listByProject': (s) =>
          PostgresPromptPresetRepository(s).listByProject('p1'),
    };

    reads.forEach((String name, Future<void> Function(_SpySession) run) {
      test('$name 只读活项目', () async {
        final spy = _SpySession();
        await run(spy);
        final String sql = spy.lastSql!;
        expect(
          RegExp('$joinAlive [a-z]+\\.project_id $aliveOnly').hasMatch(sql),
          isTrue,
          reason: '$name 的 SQL 必须 JOIN projects 并在 JOIN 条件上带 '
              'p.deleted_at IS NULL，否则已软删项目的行照常读出：\n$sql',
        );
      });
    });

    // 反向护栏 ①：回收站是软删行的唯一出口。给它加「项目必须活」会让
    // 「项目和画布都在回收站」时那些画布永远取不回来——比本洞坏得多。
    test('回收站读路径绝不过滤项目软删（反向）', () async {
      final spy = _SpySession();
      await PostgresCanvasRepository(spy).listTrashedByProject('p1');
      expect(spy.lastSql, contains('deleted_at IS NOT NULL'));
      expect(spy.lastSql, isNot(contains('JOIN projects')),
          reason: '回收站读路径一旦要求项目活着，回收站里项目的画布就再也恢复不了');
      await PostgresProjectRepository(spy).listTrashed();
      expect(spy.lastSql, isNot(contains('JOIN projects')));
    });

    // 反向护栏 ②：归档导出是全保真（含软删行 + FK 闭包），契约写在
    // core/interfaces/project_archive_reader.dart。它有自己的 9 条 SQL，
    // 不走上面这三个仓储——上表长大时别顺手把它也"修"了。
    // 这里用源码文本断言：导出读的是单事务快照，spy 要同时是 SessionExecutor，
    // 为一条反向护栏造那套机器不值得。
    test('归档导出的 SQL 绝不过滤软删（反向，源码级）', () {
      final String src = File(
        'lib/storage/repositories/postgres_project_archive_reader.dart',
      ).readAsStringSync();
      expect(src, contains('FROM canvases WHERE project_id = @p'));
      expect(src, contains('FROM characters WHERE project_id = @p'));
      expect(src, contains('FROM prompt_presets WHERE project_id = @p'));
      expect(src, isNot(contains('JOIN projects')),
          reason: '全保真导出必须带上软删行，否则导出包缺行、导入侧 FK 闭包断裂');
      expect(src, isNot(contains('deleted_at')),
          reason: '同上：导出不看 deleted_at，软删行照样写进包里');
    });

    // 自证：上面那张表必须覆盖这三个仓储的【全部】项目域读路径。
    // 不自证的闸最后都会变成常绿装饰——有人加一条 listByOwner，表不动，
    // 七条 expect 照样全过，新读路径带着洞上线。Dart 测试里没有可用的运行期
    // 反射，所以从源码签名反推：判据是方法名以 find / list 起头。
    test('读路径清单 == 源码里的全部读方法（自证）', () {
      // 源码文件名 → 上表里用的表名前缀。
      const Map<String, String> files = <String, String>{
        'canvas': 'canvases',
        'character': 'characters',
        'prompt_preset': 'prompt_presets',
      };
      // 刻意不进上表的读路径。每一条都必须有自己的反向护栏（见上面两条）。
      const Set<String> exempt = <String>{'canvases.listTrashedByProject'};

      final Set<String> fromSource = <String>{};
      files.forEach((String file, String table) {
        final String src = File(
          'lib/storage/repositories/postgres_${file}_repository.dart',
        ).readAsStringSync();
        for (final RegExpMatch m in RegExp(
          r'^  Future<.*> ((?:find|list)\w*)\(',
          multiLine: true,
        ).allMatches(src)) {
          fromSource.add('$table.${m.group(1)}');
        }
      });

      expect(
        fromSource,
        unorderedEquals(reads.keys.toSet().union(exempt)),
        reason: '这三个仓储新增 / 改名了读方法，但项目软删过滤的清单没跟上。'
            '要么把它加进上面的 reads 表，要么连同反向护栏一起加进 exempt——'
            '别让它默默成为第四条漏过滤的读路径',
      );
    });
  });

  group('EdgeRepository SQL', () {
    test('create 绑定 UNIQUE 关键参数', () async {
      final spy = _SpySession(returnRows: const [
        ['e1']
      ]);
      await PostgresEdgeRepository(spy).create(
        canvasId: 'c',
        sourceNodeId: 'a',
        targetNodeId: 'b',
        edgeType: 'data',
      );
      expect(spy.lastParams?['src'], 'a');
      expect(spy.lastParams?['tgt'], 'b');
      expect(spy.lastParams?['type'], 'data');
      expect(spy.lastParams?['role'], 'reference');
    });

    test('softDelete 写 deleted_at（edges 表无 updated_at）', () async {
      final spy = _SpySession();
      await PostgresEdgeRepository(spy).softDelete('e1');
      expect(spy.lastSql, contains('UPDATE edges SET deleted_at'));
      expect(spy.lastSql, isNot(contains('updated_at')));
    });

    test('listOutgoing / listIncoming SQL 匹配', () async {
      final spy = _SpySession();
      await PostgresEdgeRepository(spy).listOutgoing('a');
      expect(spy.lastSql, contains('source_node_id = @sid'));
      await PostgresEdgeRepository(spy).listIncoming('b');
      expect(spy.lastSql, contains('target_node_id = @tid'));
    });
  });

  group('StyleLaneRepository SQL', () {
    // 列名带了 `l.` 限定：读路径 JOIN canvases 过滤画布软删后，
    // 裸 sort_order 在两张表里都不存在歧义，但限定是必须保持的书写纪律。
    test('listByCanvas 按 sort_order ASC', () async {
      final spy = _SpySession();
      await PostgresStyleLaneRepository(spy).listByCanvas('c');
      expect(spy.lastSql, contains('ORDER BY l.sort_order ASC'));
    });
  });

  group('JobRepository SQL', () {
    test('create 将 parameters 序列化为 jsonb', () async {
      final spy = _SpySession(returnRows: const [
        ['j1']
      ]);
      await PostgresJobRepository(spy).create(
        canvasId: 'c',
        sourceNodeId: 'n',
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
        parameters: {'model': 'kling'},
      );
      expect(spy.lastSql, contains('@params::jsonb'));
      expect(spy.lastParams?['params'], contains('"model":"kling"'));
      // 死列处置：retry 由 JobQueue 内存退避负责，INSERT 不再写 max_retries
      expect(spy.lastSql, isNot(contains('max_retries')));
    });

    test('transitionStatus 使用 ANY(@from) 做原子跃迁', () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy).transitionStatus(
        id: 'j1',
        fromStatuses: const ['pending', 'submitted'],
        toStatus: 'polling',
        extra: {'remote_task_id': 'x'},
      );
      expect(spy.lastSql, contains('UPDATE jobs SET status = @to'));
      expect(spy.lastSql, contains('ANY(@from)'));
      expect(spy.lastSql, contains('remote_task_id = @p_remote_task_id'));
      expect(spy.lastParams?['from'], const ['pending', 'submitted']);
      expect(spy.lastParams?['to'], 'polling');
    });

    test('purgeExpired 包含 retention 30 天字面量 + 孤儿保留子查询 + 成功 slot 守卫',
        () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy)
          .purgeExpired(retention: const Duration(days: 30));
      expect(spy.lastSql, contains('DELETE FROM jobs'));
      expect(spy.lastSql, contains('completed_at <'));
      expect(spy.lastSql, contains('source_node_id IS NULL'));
      expect(spy.lastParams?['days'], 30);
      // LB-13a：成功 slot 守卫——含 success batch_result 的 job 绝不被清（保护 gallery）。
      expect(spy.lastSql, contains('NOT EXISTS (SELECT 1 FROM batch_results br'));
      expect(spy.lastSql, contains('br.job_id = j.id'));
      expect(spy.lastSql, contains("br.status = 'success'"));
    });

    test('purgePerCanvasCap 使用 ROW_NUMBER PARTITION BY，只清终态行 + 成功 slot 守卫',
        () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy).purgePerCanvasCap(cap: 500);
      expect(spy.lastSql, contains('ROW_NUMBER() OVER'));
      expect(spy.lastSql, contains('PARTITION BY canvas_id'));
      expect(spy.lastParams?['cap'], 500);
      // ME-32：在途 job（pending/submitted/polling）绝不被限额清除
      expect(
        spy.lastSql,
        contains("status IN ('success','error','cancelled','timeout')"),
      );
      // LB-13a：成功 slot 守卫——引用 ranked 行 job id（br.job_id = r.id）。
      expect(spy.lastSql, contains('NOT EXISTS (SELECT 1 FROM batch_results br'));
      expect(spy.lastSql, contains('br.job_id = r.id'));
      expect(spy.lastSql, contains("br.status = 'success'"));
    });

    test('update 对 parameters 做 ::jsonb cast', () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy).update('j1', {
        'parameters': {'k': 'v'},
      });
      expect(spy.lastSql, contains('parameters = @p_parameters::jsonb'));
    });
  });

  group('BatchResultRepository SQL', () {
    test('findBySlot 按 (node_id, slot_index) 定位', () async {
      final spy = _SpySession();
      await PostgresBatchResultRepository(spy).findBySlot('n', 3);
      expect(spy.lastSql, contains('node_id = @nid AND slot_index = @si'));
      expect(spy.lastParams?['nid'], 'n');
      expect(spy.lastParams?['si'], 3);
    });

    test('markPromoted 写 promoted + promoted_node_id', () async {
      final spy = _SpySession();
      await PostgresBatchResultRepository(spy)
          .markPromoted(id: 'br1', promotedNodeId: 'n2');
      expect(spy.lastSql, contains('promoted = true'));
      expect(spy.lastSql, contains('promoted_node_id = @pnid'));
    });

    test('listAllOutputUrls 过滤空 output_url（LB-13 引用集）', () async {
      final spy = _SpySession();
      await PostgresBatchResultRepository(spy).listAllOutputUrls();
      expect(spy.lastSql, contains('SELECT output_url FROM batch_results'));
      expect(
        spy.lastSql,
        contains("output_url IS NOT NULL AND output_url <> ''"),
      );
    });
  });
}

class _SpySession implements Session {
  _SpySession({this.returnRows = const []});
  final List<List<Object?>> returnRows;
  String? lastSql;
  Map<String, Object?>? lastParams;

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async {
    if (query is String) {
      lastSql = query;
    } else {
      try {
        lastSql = (query as dynamic).sql as String;
      } on NoSuchMethodError {
        lastSql = query.toString();
      }
    }
    if (parameters is Map<String, Object?>) {
      lastParams = parameters;
    } else if (parameters is Map) {
      lastParams = parameters.cast<String, Object?>();
    }
    return Result(
      rows: returnRows
          .map((v) => ResultRow(values: v, schema: ResultSchema(const [])))
          .toList(),
      affectedRows: returnRows.length,
      schema: ResultSchema(const []),
    );
  }

  @override
  Future<Statement> prepare(Object query) => throw UnimplementedError();
  @override
  bool get isOpen => true;
  @override
  Future<void> get closed async {}
}
