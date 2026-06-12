// ProjectWithCanvases / CanvasRef 纯模型构造单测。
// provider 装配逻辑见 ../providers/workspace_projects_provider_test.dart。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';

void main() {
  group('ProjectWithCanvases / CanvasRef 构造', () {
    test('字段如实保留', () {
      const ref = CanvasRef(id: 'cv1', name: 'Scene 1');
      final pwc = ProjectWithCanvases(
        id: 'p1',
        name: 'Alpha',
        createdAt: DateTime.utc(2026, 5, 12),
        canvases: const <CanvasRef>[ref],
      );
      expect(pwc.id, 'p1');
      expect(pwc.name, 'Alpha');
      expect(pwc.createdAt, DateTime.utc(2026, 5, 12));
      expect(pwc.canvases.single.id, 'cv1');
      expect(pwc.canvases.single.name, 'Scene 1');
    });
  });
}
