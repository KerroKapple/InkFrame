// 真 PG 事务回滚集成测：UnitOfWork.run 中途抛错 → 整体回滚，无残留行。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/storage/postgres_unit_of_work.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';

import 'schema/pg_test_harness.dart';

class _Skip implements Exception {}

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'tx');
  });
  tearDown(() async {
    await harness?.close();
  });

  PgTestHarness req() {
    final x = harness;
    if (x == null) {
      markTestSkipped('TEST_PG_URL 未设置，跳过真 PG 集成测试');
      throw _Skip();
    }
    return x;
  }

  test('闭包中途抛错 → 已写入的 project 行回滚（不残留）', () async {
    try {
      final h = req();
      final uow = PostgresUnitOfWork(h.conn);
      final projects = PostgresProjectRepository(h.conn);

      await expectLater(
        uow.run((scope) async {
          await scope.projects.create(name: 'Alpha');
          // 第二步用不存在的 project_id 触发 FK 违例 → guard 翻成 LocalIOError → 回滚。
          await scope.canvas.create(
            projectId: '00000000-0000-0000-0000-000000000000',
            name: 'X',
          );
        }),
        throwsA(isA<LocalIOError>()),
      );

      // 回滚后 projects 表应为空。
      expect(await projects.listAll(), isEmpty);
    } on _Skip {
      return;
    }
  });

  test('闭包全部成功 → project + canvas 双双提交', () async {
    try {
      final h = req();
      final uow = PostgresUnitOfWork(h.conn);
      final projects = PostgresProjectRepository(h.conn);
      final canvases = PostgresCanvasRepository(h.conn);

      await uow.run((scope) async {
        final pid = await scope.projects.create(name: 'Alpha');
        await scope.canvas.create(projectId: pid, name: 'C1');
      });

      final all = await projects.listAll();
      expect(all, hasLength(1));
      final cs = await canvases.listByProject(all.single['id']!.toString());
      expect(cs, hasLength(1));
    } on _Skip {
      return;
    }
  });
}
