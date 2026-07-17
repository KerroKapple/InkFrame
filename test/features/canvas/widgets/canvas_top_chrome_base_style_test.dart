// CanvasTopChrome — 调色板按钮 + base style 编辑对话框集成测试。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_top_chrome.dart';

import '../../../_harness/test_app.dart';

// 导出按钮 watch 节点集合；fake 隔离 DB DI。
class _EmptyNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async =>
      const <CanvasNode>[];
}

// 最小化 fake：仅实现 findById（返回 base_style 字段），update 记录调用。
class _FakeCanvasRepository implements CanvasRepository {
  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId) async =>
      const <Map<String, Object?>>[];

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
        canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
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

  testWidgets('调色板按钮 → 对话框用已存值预填 → 保存 → repo 收到 base_style patch',
      (tester) async {
    // 端到端覆盖 _openEditor：await provider.future 预填（防数据丢失 guard）→
    // 编辑前缀 → Save → setBaseStyle 写库。这是用户真实路径。
    final repo = _FakeCanvasRepository(prefix: 'old-pre', suffix: 'old-suf');
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasTopChrome(canvasName: 'X')),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
        canvasRepositoryProvider.overrideWith((_) async => repo),
        canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.palette_outlined));
    // DragToMoveArea 的 onDoubleTap 会把单击识别延迟 kDoubleTapTimeout(300ms)，
    // 必须 pump 越过该窗口，onPressed 才会触发。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // 对话框已打开，且用已存值预填（验证 await .future 防数据丢失 guard）。
    expect(find.text('Project base style'), findsOneWidget);
    expect(find.text('old-pre'), findsOneWidget);

    // 改前缀后保存。
    await tester.enterText(find.byType(TextField).first, 'new-pre');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // setBaseStyle → repo.update 收到正确列名与值；后缀保持不变。
    expect(repo.lastPatch, isNotNull);
    expect(repo.lastPatch!['base_style_prefix'], 'new-pre');
    expect(repo.lastPatch!['base_style_suffix'], 'old-suf');
  });
}
