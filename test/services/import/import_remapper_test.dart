// 导入重映射器单测（LB-12）：FK 闭包 / 宽容策略 / 终态化 / 白名单 / 路径前缀。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/services/import/import_remapper.dart';

/// 确定性 id 工厂：N1, N2, ...
String Function() _seq() {
  var i = 0;
  return () => 'N${++i}';
}

Map<String, dynamic> _fullData() => <String, dynamic>{
      'project': {
        'id': 'P',
        'name': 'demo',
        'cover_node_id': 'n2',
        'created_at': '2026-01-01T00:00:00.000Z',
      },
      'canvases': [
        {'id': 'c1', 'project_id': 'P', 'name': 'A', 'deleted_at': null},
        {'id': 'c2', 'project_id': 'P', 'name': 'B', 'deleted_at': '2026-01-02T00:00:00.000Z'},
      ],
      'lanes': [
        {'id': 'l1', 'canvas_id': 'c1', 'label': 'lane'},
      ],
      'nodes': [
        {'id': 'n1', 'canvas_id': 'c1', 'type': 'image', 'node_role': 'config',
         'type_config': {'prompt': 'x', 'character_ids': ['ch1', 'ghost']}},
        {'id': 'n2', 'canvas_id': 'c1', 'type': 'image', 'node_role': 'result',
         'source_node_id': 'n1', 'lane_id': 'l1'},
        {'id': 'n3', 'canvas_id': 'c2', 'type': 'image', 'node_role': 'config'},
      ],
      'edges': [
        {'id': 'e1', 'canvas_id': 'c1', 'source_node_id': 'n1',
         'target_node_id': 'n2', 'edge_type': 'data'},
      ],
      'characters': [
        {'id': 'ch1', 'project_id': 'P', 'name': 'hero',
         'reference_image_paths': ['characters/hero.png', 'canvases/c1/images/r.png']},
      ],
      'prompt_presets': [
        {'id': 'pp1', 'project_id': 'P', 'name': 'preset'},
      ],
      'jobs': [
        {'id': 'j1', 'canvas_id': 'c1', 'source_node_id': 'n1',
         'result_node_id': 'n2', 'provider_id': 'prov', 'job_type': 'image',
         'status': 'polling', 'full_prompt': 'f', 'user_prompt': 'u',
         'created_at': '2026-01-03T00:00:00.000Z'},
      ],
      'batch_results': [
        {'id': 's1', 'node_id': 'n2', 'job_id': 'j1', 'slot_index': 0,
         'status': 'success', 'output_url': 'images/s0.png'},
        {'id': 's2', 'node_id': 'n2', 'job_id': 'j1', 'slot_index': 1,
         'status': 'generating', 'created_at': '2026-01-03T01:00:00.000Z'},
      ],
    };

void main() {
  test('全链路：id 全新、FK 闭包、cover/character_ids/canvasIdMap、终态化、project_id 强写',
      () {
    final plan = remapArchiveData(_fullData(), newId: _seq());

    // 新 id 集合。
    final newIds = <Object?>{
      plan.newProjectId,
      ...plan.canvases.map((r) => r['id']),
      ...plan.lanes.map((r) => r['id']),
      ...plan.nodes.map((r) => r['id']),
      ...plan.edges.map((r) => r['id']),
      ...plan.characters.map((r) => r['id']),
      ...plan.presets.map((r) => r['id']),
      ...plan.jobs.map((r) => r['id']),
      ...plan.batchResults.map((r) => r['id']),
    };
    // FK 闭包：全部引用值 ∈ 新 id 集或 null。
    void refIn(Object? v) =>
        expect(v == null || newIds.contains(v), isTrue, reason: 'ref=$v');
    refIn(plan.project['cover_node_id']);
    for (final n in plan.nodes) {
      refIn(n['canvas_id']);
      refIn(n['source_node_id']);
      refIn(n['lane_id']);
    }
    for (final e in plan.edges) {
      refIn(e['canvas_id']);
      refIn(e['source_node_id']);
      refIn(e['target_node_id']);
    }
    for (final j in plan.jobs) {
      refIn(j['canvas_id']);
      refIn(j['source_node_id']);
      refIn(j['result_node_id']);
    }
    for (final s in plan.batchResults) {
      refIn(s['node_id']);
      refIn(s['job_id']);
      refIn(s['promoted_node_id']);
    }

    // 旧 id 零残留（整包序列化扫描）。
    final blob = jsonEncode(<Object?>[
      plan.project, plan.canvases, plan.lanes, plan.nodes, plan.edges,
      plan.characters, plan.presets, plan.jobs, plan.batchResults,
    ]);
    for (final old in <String>['"P"', '"c1"', '"c2"', '"n1"', '"n2"', '"n3"',
        '"l1"', '"e1"', '"ch1"', '"pp1"', '"j1"', '"s1"', '"s2"']) {
      expect(blob.contains(old), isFalse, reason: '旧 id 残留 $old');
    }

    // canvasIdMap 完整且对齐画布行。
    expect(plan.canvasIdMap.keys.toSet(), {'c1', 'c2'});
    expect(plan.canvases.map((r) => r['id']).toSet(),
        plan.canvasIdMap.values.toSet());
    // 软删画布保真。
    expect(plan.canvases.where((r) => r['deleted_at'] != null), hasLength(1));

    // character_ids：ch1 映射、ghost 丢弃+计数。
    final cfg = plan.nodes.first['type_config'] as Map;
    final chNew = plan.characters.single['id'];
    expect(cfg['character_ids'], [chNew]);
    expect(plan.nulledRefCount, 1);

    // 终态化：polling→cancelled+completed_at；generating slot 同。
    expect(plan.jobs.single['status'], 'cancelled');
    expect(plan.jobs.single['completed_at'], '2026-01-03T00:00:00.000Z');
    final s2 = plan.batchResults.firstWhere((r) => r['slot_index'] == 1);
    expect(s2['status'], 'cancelled');
    expect(s2['completed_at'], '2026-01-03T01:00:00.000Z');
    // success slot 不动。
    expect(plan.batchResults.firstWhere((r) => r['slot_index'] == 0)['status'],
        'success');

    // project_id 强写。
    for (final r in [...plan.canvases, ...plan.characters, ...plan.presets]) {
      expect(r['project_id'], plan.newProjectId);
    }
    expect(plan.droppedRowCount, 0);
  });

  test('可空引用悬空→NULL+计数；NOT NULL 悬空→整行丢弃+连带', () {
    final data = _fullData();
    (data['nodes'] as List).add({
      'id': 'n9', 'canvas_id': 'c1', 'type': 'image', 'node_role': 'result',
      'source_node_id': 'missing', // 可空悬空→NULL。
    });
    (data['edges'] as List).add({
      'id': 'e9', 'canvas_id': 'c1', 'source_node_id': 'n1',
      'target_node_id': 'missing', 'edge_type': 'data', // NOT NULL 悬空→丢行。
    });
    (data['jobs'] as List).add({
      'id': 'j9', 'canvas_id': 'missing', 'source_node_id': 'n1',
      'provider_id': 'p', 'job_type': 'image', 'status': 'success',
      'full_prompt': 'f', 'user_prompt': 'u', // canvas 悬空→丢 job。
    });
    (data['batch_results'] as List).add({
      'id': 's9', 'node_id': 'n2', 'job_id': 'j9', 'slot_index': 0,
      'status': 'success', // 所属 job 被丢→连带丢。
    });

    final plan = remapArchiveData(data, newId: _seq());

    final n9 = plan.nodes.firstWhere((r) => r['label'] == null &&
        r['source_node_id'] == null && r['node_role'] == 'result' &&
        r['lane_id'] == null);
    expect(n9, isNotNull);
    expect(plan.edges, hasLength(1)); // e9 被丢。
    expect(plan.jobs, hasLength(1)); // j9 被丢。
    expect(plan.batchResults, hasLength(2)); // s9 连带丢。
    expect(plan.droppedRowCount, 3);
    expect(plan.nulledRefCount, greaterThanOrEqualTo(2)); // ghost + n9.source。
  });

  test('级联丢弃彻底性（#192 评审 P2-2）：画布悬空→节点丢→引用它的全链跟着收敛', () {
    final data = _fullData();
    // n_ghost 挂在不存在的画布上→整行丢；下游一切对它的引用必须收敛，
    // 绝不能拿到「已映射但永不插入」的新 id（写库层会 23503 整包回滚）。
    (data['nodes'] as List).add({
      'id': 'n_ghost', 'canvas_id': 'ghost-canvas',
      'type': 'image', 'node_role': 'config',
    });
    (data['edges'] as List).add({
      'id': 'e_g', 'canvas_id': 'c1', 'source_node_id': 'n1',
      'target_node_id': 'n_ghost', 'edge_type': 'data',
    });
    (data['jobs'] as List).add({
      'id': 'j_g', 'canvas_id': 'c1', 'source_node_id': 'n_ghost',
      'provider_id': 'p', 'job_type': 'image', 'status': 'success',
      'full_prompt': 'f', 'user_prompt': 'u',
    });
    ((data['project'] as Map))['cover_node_id'] = 'n_ghost';
    ((data['nodes'] as List).first as Map)['source_node_id'] = 'n_ghost';

    final plan = remapArchiveData(data, newId: _seq());

    expect(plan.nodes.map((r) => r['id']), isNot(contains(null)));
    expect(plan.nodes, hasLength(3)); // n_ghost 丢。
    expect(plan.edges, hasLength(1)); // e_g 丢（目标悬空）。
    expect(plan.jobs, hasLength(1)); // j_g 丢（source 悬空）。
    expect(plan.project['cover_node_id'], isNull); // cover 置空。
    // n1 的 source 引用收敛为 NULL 而非幽灵新 id。
    final n1 = plan.nodes.firstWhere((r) => (r['type_config'] as Map?)?['prompt'] == 'x');
    expect(n1['source_node_id'], isNull);
    // 全部引用仍闭合于实际保留行。
    final keptIds = plan.nodes.map((r) => r['id']).toSet();
    for (final e in plan.edges) {
      expect(keptIds, contains(e['source_node_id']));
      expect(keptIds, contains(e['target_node_id']));
    }
  });

  test('未知列丢弃+计数（老包 next_poll / 派生列 project_id on nodes）', () {
    final data = _fullData();
    ((data['jobs'] as List).first as Map)['next_poll'] = '2026-01-01';
    ((data['nodes'] as List).first as Map)['project_id'] = 'P';

    final plan = remapArchiveData(data, newId: _seq());

    expect(plan.jobs.single.containsKey('next_poll'), isFalse);
    expect(plan.nodes.first.containsKey('project_id'), isFalse);
    expect(plan.droppedColumnCount, 2);
  });

  // v8 加的 projects.delivery_settings 曾不在白名单里：导出（SELECT *）带着它，
  // 导入把它当未知列丢掉——导出再导入一个项目，交付设置静默清零。
  test('交付设置随项目导入，不被当未知列丢掉', () {
    final data = _fullData();
    // 夹具里的 project 是全字符串 map，塞不进嵌套值——重建一个宽类型的。
    data['project'] = <String, Object?>{
      ...(data['project'] as Map).cast<String, Object?>(),
      'delivery_settings': <String, Object?>{
        'target': 'final_cut',
        'relative_paths': false,
      },
    };

    final plan = remapArchiveData(data, newId: _seq());

    expect(plan.project['delivery_settings'], <String, Object?>{
      'target': 'final_cut',
      'relative_paths': false,
    });
    expect(plan.droppedColumnCount, 0, reason: '它不是未知列，不该进丢弃计数');
  });

  test('characters 路径：characters/ 原样、canvases/{旧}/ 前缀重写', () {
    final plan = remapArchiveData(_fullData(), newId: _seq());
    final paths =
        (plan.characters.single['reference_image_paths'] as List).cast<String>();
    expect(paths.first, 'characters/hero.png');
    final newC1 = plan.canvasIdMap['c1'];
    expect(paths[1], 'canvases/$newC1/images/r.png');
  });

  // 生成快照 gen_inputs（result 节点）与固定的当前 take pinned_result_id（配置节点）里存的是
  // 节点 / 角色 id，导入要跟着 UUID 映射改写；映射不到的剥掉（= 没快照 / 没固定）并计数。
  // 夹具自建：_fullData() 被全链路用例拿去断言 nulledRefCount 与整包旧 id 零残留，别往里加。
  group('gen_inputs / pinned_result_id 重映射', () {
    Map<String, dynamic> snapData({
      String sourceId = 'src',
      String characterId = 'ch1',
      Object? pinned = 'res',
    }) =>
        <String, dynamic>{
          'project': <String, Object?>{'id': 'P', 'name': 'demo'},
          'canvases': <Object?>[
            <String, Object?>{'id': 'c1', 'project_id': 'P', 'name': 'A'},
          ],
          'nodes': <Object?>[
            <String, Object?>{
              'id': 'cfg', 'canvas_id': 'c1', 'type': 'image', 'node_role': 'config',
              'type_config': <String, Object?>{
                'prompt': 'x',
                'pinned_result_id': ?pinned,
              },
            },
            <String, Object?>{
              'id': 'src', 'canvas_id': 'c1', 'type': 'image', 'node_role': 'result',
              'type_config': <String, Object?>{'image_url': 'images/s.png'},
            },
            <String, Object?>{
              'id': 'res', 'canvas_id': 'c1', 'type': 'image', 'node_role': 'result',
              'source_node_id': 'cfg',
              'type_config': <String, Object?>{
                'image_url': 'images/r.png',
                'gen_inputs': <String, Object?>{
                  'prompt': 'x',
                  'character_ids': <Object?>[characterId],
                  'sources': <Object?>[
                    <String, Object?>{'node_id': sourceId, 'role': 'reference', 'image_url': 'images/s.png'},
                  ],
                },
              },
            },
          ],
          'characters': <Object?>[
            <String, Object?>{'id': 'ch1', 'project_id': 'P', 'name': 'hero'},
          ],
        };

    // 节点行按包里的顺序保留：0 = cfg、1 = src、2 = res。
    Map<String, Object?> typeConfigAt(ImportPlanData plan, int i) =>
        (plan.nodes[i]['type_config']! as Map).cast<String, Object?>();

    test('gen_inputs 源 id / 角色 id 随 UUID 改写', () {
      final plan = remapArchiveData(snapData(), newId: _seq());

      final Map<String, Object?> gi =
          (typeConfigAt(plan, 2)['gen_inputs']! as Map).cast<String, Object?>();
      final List<Object?> sources = gi['sources']! as List<Object?>;
      expect((sources.single! as Map)['node_id'], plan.nodes[1]['id']);
      expect(gi['character_ids'], <Object?>[plan.characters.single['id']]);
      expect(gi['prompt'], 'x');
      expect(plan.nulledRefCount, 0);
      final String blob = jsonEncode(plan.nodes);
      for (final String old in <String>['"src"', '"res"', '"cfg"', '"ch1"']) {
        expect(blob.contains(old), isFalse, reason: '旧 id 残留 $old');
      }
    });

    test('gen_inputs 引用了包外节点 → 整份剥掉并计数', () {
      final plan = remapArchiveData(snapData(sourceId: 'hard-deleted'), newId: _seq());

      final Map<String, Object?> tc = typeConfigAt(plan, 2);
      expect(tc.containsKey('gen_inputs'), isFalse, reason: '剥掉源 id 的 take 记作「没快照」，不标过期');
      expect(tc['image_url'], 'images/r.png', reason: '其余键原样');
      expect(plan.nulledRefCount, 1);
    });

    test('gen_inputs 引用了包外角色 → 整份剥掉并计数', () {
      final plan = remapArchiveData(snapData(characterId: 'ghost'), newId: _seq());

      expect(typeConfigAt(plan, 2).containsKey('gen_inputs'), isFalse);
      expect(plan.nulledRefCount, 1);
    });

    test('配置节点 pinned_result_id 改写；悬空删键并计数', () {
      final hit = remapArchiveData(snapData(), newId: _seq());
      expect(typeConfigAt(hit, 0)['pinned_result_id'], hit.nodes[2]['id']);
      expect(hit.nulledRefCount, 0);

      final miss = remapArchiveData(snapData(pinned: 'gone'), newId: _seq());
      final Map<String, Object?> cfg = typeConfigAt(miss, 0);
      expect(cfg.containsKey('pinned_result_id'), isFalse, reason: '判据回落最新');
      expect(cfg['prompt'], 'x');
      expect(miss.nulledRefCount, 1);
    });

    test('老包没有这两个键 → 原样', () {
      final Map<String, dynamic> data = snapData(pinned: null);
      ((data['nodes']! as List<Object?>)[2]! as Map<String, Object?>)['type_config'] =
          <String, Object?>{'image_url': 'images/r.png'};

      final plan = remapArchiveData(data, newId: _seq());

      expect(typeConfigAt(plan, 0), <String, Object?>{'prompt': 'x'});
      expect(typeConfigAt(plan, 2), <String, Object?>{'image_url': 'images/r.png'});
      expect(plan.nulledRefCount, 0);
    });
  });
}
