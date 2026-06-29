import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_name.dart';

import '../../../_harness/fake_repositories.dart';

void main() {
  test('currentCanvasNameProvider 解析当前画布真实 name', () async {
    final canvasRepo = InMemoryCanvasRepository();
    final id = await canvasRepo.create(projectId: 'p1', name: '分镜画布 A');
    final container = ProviderContainer(overrides: [
      canvasRepositoryProvider.overrideWith((ref) async => canvasRepo),
    ]);
    addTearDown(container.dispose);
    container.read(currentCanvasIdProvider.notifier).state = id;

    final name = await container.read(currentCanvasNameProvider.future);
    expect(name, '分镜画布 A');
  });

  test('未选中画布时返回 null', () async {
    final container = ProviderContainer(overrides: [
      canvasRepositoryProvider
          .overrideWith((ref) async => InMemoryCanvasRepository()),
    ]);
    addTearDown(container.dispose);
    final name = await container.read(currentCanvasNameProvider.future);
    expect(name, isNull);
  });
}
