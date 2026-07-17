// canvas_base_style_test.dart — canvasBaseStyleProvider + setBaseStyle 单测。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/features/canvas/providers/canvas_base_style.dart';

// ── fake ─────────────────────────────────────────────────────────────────────

class _FakeCanvasRepo implements CanvasRepository {
  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId) async =>
      const <Map<String, Object?>>[];

  final Map<String, Map<String, Object?>> _rows = {};
  // 最后一次 update 收到的 patch，断言用。
  Map<String, Object?>? lastPatch;

  void seed(String id, {String prefix = '', String suffix = ''}) {
    _rows[id] = {
      'id': id,
      'base_style_prefix': prefix,
      'base_style_suffix': suffix,
    };
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => _rows[id];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    lastPatch = patch;
    _rows[id]?.addAll(patch);
    return 1;
  }

  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async =>
      'canvas-x';

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async => [];

  @override
  Future<List<Map<String, Object?>>> listByProjects(List<String> projectIds) async => [];

  @override
  Future<int> softDelete(String id) async => 0;

  @override
  Future<int> restore(String id) async => 0;

  @override
  Future<int> hardDelete(String id) async => 0;
}

// ── 辅助 widget：点击按钮调用 setBaseStyle ───────────────────────────────────

class _TestWidget extends ConsumerWidget {
  const _TestWidget({
    required this.canvasId,
    required this.prefix,
    required this.suffix,
  });
  final String canvasId;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => setBaseStyle(
        ref,
        canvasId,
        prefix: prefix,
        suffix: suffix,
      ),
      child: const Text('go'),
    );
  }
}

// ── 测试 ──────────────────────────────────────────────────────────────────────

void main() {
  // ── canvasBaseStyleProvider ──────────────────────────────────────────────

  test('canvasBaseStyleProvider — findById 返回 null 时降级为空字符串', () async {
    final repo = _FakeCanvasRepo(); // 空 store，findById 返回 null
    final c = ProviderContainer(overrides: [
      canvasRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);

    final result = await c.read(canvasBaseStyleProvider('canvas-missing').future);
    expect(result.prefix, '');
    expect(result.suffix, '');
  });

  test('canvasBaseStyleProvider — 读取已有行的 prefix/suffix', () async {
    final repo = _FakeCanvasRepo();
    repo.seed('cv1', prefix: 'cinematic', suffix: '8k');
    final c = ProviderContainer(overrides: [
      canvasRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);

    final result = await c.read(canvasBaseStyleProvider('cv1').future);
    expect(result.prefix, 'cinematic');
    expect(result.suffix, '8k');
  });

  // ── setBaseStyle ─────────────────────────────────────────────────────────

  testWidgets('setBaseStyle — 调用 repo.update 并携带正确 prefix/suffix', (tester) async {
    final repo = _FakeCanvasRepo();
    repo.seed('cv2');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          canvasRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: _TestWidget(
              canvasId: 'cv2',
              prefix: 'anime',
              suffix: 'vibrant',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(repo.lastPatch, isNotNull);
    expect(repo.lastPatch!['base_style_prefix'], 'anime');
    expect(repo.lastPatch!['base_style_suffix'], 'vibrant');
  });
}
