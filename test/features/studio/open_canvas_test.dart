import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/open_canvas.dart';

void main() {
  test('有画布 → set 第一个画布 id', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await openProjectCanvas(
      container.read,
      const ProjectWithCanvases(id: 'p1', name: 'P', canvases: [
        CanvasRef(id: 'cv-a', name: 'A'),
        CanvasRef(id: 'cv-b', name: 'B'),
      ]),
      createCanvas: (_) async => fail('不该建画布'),
    );
    expect(container.read(currentCanvasIdProvider), 'cv-a');
  });

  test('0 画布 → 建新画布并 set', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await openProjectCanvas(
      container.read,
      const ProjectWithCanvases(id: 'p1', name: 'P', canvases: []),
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
        const ProjectWithCanvases(id: 'p1', name: 'P', canvases: []),
        createCanvas: (_) async => throw StateError('boom'),
      ),
      throwsStateError,
    );
    expect(container.read(currentCanvasIdProvider), isNull);
  });
}
