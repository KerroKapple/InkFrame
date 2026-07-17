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

  test('未知列丢弃+计数（老包 next_poll / 派生列 project_id on nodes）', () {
    final data = _fullData();
    ((data['jobs'] as List).first as Map)['next_poll'] = '2026-01-01';
    ((data['nodes'] as List).first as Map)['project_id'] = 'P';

    final plan = remapArchiveData(data, newId: _seq());

    expect(plan.jobs.single.containsKey('next_poll'), isFalse);
    expect(plan.nodes.first.containsKey('project_id'), isFalse);
    expect(plan.droppedColumnCount, 2);
  });

  test('characters 路径：characters/ 原样、canvases/{旧}/ 前缀重写', () {
    final plan = remapArchiveData(_fullData(), newId: _seq());
    final paths =
        (plan.characters.single['reference_image_paths'] as List).cast<String>();
    expect(paths.first, 'characters/hero.png');
    final newC1 = plan.canvasIdMap['c1'];
    expect(paths[1], 'canvases/$newC1/images/r.png');
  });
}
