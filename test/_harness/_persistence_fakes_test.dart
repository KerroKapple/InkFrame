// FakeClock + FakeSecureStorage + InMemory*Repository 契约测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/core/logging/logger_service.dart';

import 'fake_clock.dart';
import 'fake_repositories.dart';
import 'fake_secure_storage.dart';

void main() {
  group('FakeClock', () {
    test('默认起点 2026-01-01 UTC', () {
      final FakeClock c = FakeClock();
      expect(c.nowUtc(), DateTime.utc(2026, 1, 1));
      expect(c, isA<Clock>());
    });

    test('advance 推进时间', () {
      final FakeClock c = FakeClock();
      c.advance(const Duration(hours: 2));
      expect(c.nowUtc(), DateTime.utc(2026, 1, 1, 2));
    });

    test('setNow 跳到指定时刻并规范化为 UTC', () {
      final FakeClock c = FakeClock();
      c.setNow(DateTime.utc(2027, 5, 1));
      expect(c.nowUtc(), DateTime.utc(2027, 5, 1));
    });
  });

  group('FakeSecureStorage', () {
    test('store / retrieve / exists / delete 完整流程', () async {
      final FakeSecureStorage s = FakeSecureStorage();
      expect(await s.exists('k'), isFalse);
      expect(await s.retrieve('k'), isNull);
      await s.store('k', 'v');
      expect(await s.exists('k'), isTrue);
      expect(await s.retrieve('k'), 'v');
      await s.delete('k');
      expect(await s.exists('k'), isFalse);
    });

    test('seed 初始化', () async {
      final FakeSecureStorage s = FakeSecureStorage(<String, String>{'k': 'v'});
      expect(await s.retrieve('k'), 'v');
    });

    test('snapshot 暴露只读视图', () async {
      final FakeSecureStorage s = FakeSecureStorage();
      await s.store('a', '1');
      expect(s.snapshot, <String, String>{'a': '1'});
      expect(() => s.snapshot['x'] = 'y', throwsUnsupportedError);
    });

    test('实现 SecureStorageService', () {
      expect(FakeSecureStorage(), isA<SecureStorageService>());
    });
  });

  group('InMemoryProjectRepository', () {
    test('CRUD + 软删除 + 恢复 + 物理删除', () async {
      final ProjectRepository r = InMemoryProjectRepository();
      final String id = await r.create(name: 'P1');
      expect((await r.findById(id))?['name'], 'P1');
      expect(await r.listAll(), hasLength(1));

      await r.update(id, <String, Object?>{'name': 'P1-renamed'});
      expect((await r.findById(id))?['name'], 'P1-renamed');

      await r.softDelete(id);
      expect(await r.findById(id), isNull);
      expect(await r.listAll(), isEmpty);
      expect(await r.listTrashed(), hasLength(1));

      await r.restore(id);
      expect(await r.listAll(), hasLength(1));

      await r.hardDelete(id);
      expect(await r.listAll(), isEmpty);
      expect(await r.listTrashed(), isEmpty);
    });
  });

  group('InMemoryCanvasRepository', () {
    test('listByProject 按 created_at ASC', () async {
      final InMemoryCanvasRepository r = InMemoryCanvasRepository();
      final String a = await r.create(projectId: 'p1', name: 'A');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final String b = await r.create(projectId: 'p1', name: 'B');
      await r.create(projectId: 'p2', name: 'C');
      final List<Map<String, Object?>> list = await r.listByProject('p1');
      expect(list.map((m) => m['id']).toList(), <String>[a, b]);
    });
  });

  group('InMemoryNodeRepository', () {
    test('create + patchTypeConfig 合并', () async {
      final NodeRepository r = InMemoryNodeRepository();
      final String id = await r.create(
        canvasId: 'c1',
        type: 'image',
        nodeRole: 'config',
        typeConfig: <String, Object?>{'prompt': 'hello'},
      );
      await r.patchTypeConfig(id, <String, Object?>{'seed': 42});
      final Map<String, Object?>? row = await r.findById(id);
      expect((row?['type_config'] as Map<String, Object?>)['prompt'], 'hello');
      expect((row?['type_config'] as Map<String, Object?>)['seed'], 42);
    });

    test('listOrphanResults 过滤 role + source_node_id IS NULL', () async {
      final NodeRepository r = InMemoryNodeRepository();
      await r.create(canvasId: 'c1', type: 'image', nodeRole: 'result');
      await r.create(
        canvasId: 'c1',
        type: 'image',
        nodeRole: 'result',
        sourceNodeId: 'some-source',
      );
      await r.create(canvasId: 'c1', type: 'image', nodeRole: 'config');
      final List<Map<String, Object?>> orphans = await r.listOrphanResults('c1');
      expect(orphans, hasLength(1));
    });

    test('softDeleteEmptyOrphanResults 只软删空 result 壳（LB-14）', () async {
      final InMemoryNodeRepository r = InMemoryNodeRepository();
      // 空 result 壳 → 会进回收站
      final String empty =
          await r.create(canvasId: 'c1', type: 'image', nodeRole: 'result');
      // 有 image_url 的 result → 保留
      final String withImage = await r.create(
        canvasId: 'c1',
        type: 'image',
        nodeRole: 'result',
        typeConfig: <String, Object?>{'image_url': 'images/a.png'},
      );
      // config 节点 → 不受影响
      final String cfg =
          await r.create(canvasId: 'c1', type: 'image', nodeRole: 'config');

      expect(await r.softDeleteEmptyOrphanResults(), 1);
      expect(await r.findById(empty), isNull);
      expect(await r.findById(withImage), isNotNull);
      expect(await r.findById(cfg), isNotNull);
    });
  });

  group('InMemoryEdgeRepository', () {
    test('listOutgoing / listIncoming 双向索引', () async {
      final EdgeRepository r = InMemoryEdgeRepository();
      await r.create(
        canvasId: 'c1',
        sourceNodeId: 'n1',
        targetNodeId: 'n2',
        edgeType: 'data',
      );
      await r.create(
        canvasId: 'c1',
        sourceNodeId: 'n1',
        targetNodeId: 'n3',
        edgeType: 'data',
      );
      expect(await r.listOutgoing('n1'), hasLength(2));
      expect(await r.listIncoming('n2'), hasLength(1));
      expect(await r.listIncoming('n3'), hasLength(1));
    });
  });
}
