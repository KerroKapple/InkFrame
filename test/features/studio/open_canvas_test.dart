import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/open_canvas.dart';

void main() {
  test('有画布 → set 第一个画布 id', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await openProjectCanvas(
      container.read,
      ProjectWithCanvases(
        id: 'p1',
        name: 'P',
        createdAt: DateTime.utc(2026, 5, 1),
        canvases: const [
          CanvasRef(id: 'cv-a', name: 'A'),
          CanvasRef(id: 'cv-b', name: 'B'),
        ],
      ),
      createCanvas: (_) async => fail('不该建画布'),
    );
    expect(container.read(currentCanvasIdProvider), 'cv-a');
  });

  test('0 画布 → 建新画布并 set', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await openProjectCanvas(
      container.read,
      ProjectWithCanvases(
        id: 'p1',
        name: 'P',
        createdAt: DateTime.utc(2026, 5, 1),
        canvases: const [],
      ),
      createCanvas: (projectId) async => 'cv-new',
    );
    expect(container.read(currentCanvasIdProvider), 'cv-new');
  });

  test('create 失败 → 不 set，错误冒泡', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(
      openProjectCanvas(
        container.read,
        ProjectWithCanvases(
        id: 'p1',
        name: 'P',
        createdAt: DateTime.utc(2026, 5, 1),
        canvases: const [],
      ),
        createCanvas: (_) async => throw StateError('boom'),
      ),
      throwsStateError,
    );
    expect(container.read(currentCanvasIdProvider), isNull);
  });

  test('打开成功 → 偏好记下 lastCanvasId/lastProjectId（重启恢复用）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await openProjectCanvas(
      container.read,
      ProjectWithCanvases(
        id: 'p1',
        name: 'P',
        createdAt: DateTime.utc(2026, 5, 1),
        canvases: const [CanvasRef(id: 'cv-a', name: 'A')],
      ),
      createCanvas: (_) async => fail('不该建画布'),
    );
    await pumpEventQueue(); // 记录是 fire-and-forget
    final prefs = container.read(preferencesServiceProvider).current;
    expect(prefs.lastCanvasId, 'cv-a');
    expect(prefs.lastProjectId, 'p1');
  });
}
