// CanvasTopChrome — 调色板按钮 + base style 编辑对话框集成测试。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_top_chrome.dart';

import '../../../_harness/test_app.dart';

// 最小化 fake：仅实现 findById（返回 base_style 字段），update 记录调用。
class _FakeCanvasRepository implements CanvasRepository {
  _FakeCanvasRepository({
    String prefix = 'pre',
    String suffix = 'suf',
  })  : _prefix = prefix,
        _suffix = suffix;

  final String _prefix;
  final String _suffix;

  Map<String, Object?>? lastPatch;

  @override
  Future<Map<String, Object?>?> findById(String id) async => <String, Object?>{
        'id': id,
        'base_style_prefix': _prefix,
        'base_style_suffix': _suffix,
      };

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    lastPatch = patch;
    return 1;
  }

  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async => 'new-id';

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async => [];

  @override
  Future<List<Map<String, Object?>>> listByProjects(List<String> projectIds) async => [];

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

void main() {
  testWidgets('调色板按钮在 canvasId 非 null 时可见', (tester) async {
    final repo = _FakeCanvasRepository();
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasTopChrome(canvasName: 'X')),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
        canvasRepositoryProvider.overrideWith((_) async => repo),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
  });

  testWidgets('调色板按钮在 canvasId 为 null 时隐藏', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasTopChrome(canvasName: 'X')),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => null),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.palette_outlined), findsNothing);
  });

  testWidgets('调色板按钮已接线（onPressed 非空）', (tester) async {
    // dialog 打开 + Save→update 由 base_style_editor_dialog_test 与
    // canvas_base_style_test 分别覆盖；此处只验证 chrome 按钮接线（确定性）。
    final repo = _FakeCanvasRepository();
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasTopChrome(canvasName: 'X')),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
        canvasRepositoryProvider.overrideWith((_) async => repo),
      ],
    );
    await tester.pumpAndSettle();

    final iconButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.palette_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(iconButton.onPressed, isNotNull);
  });
}
