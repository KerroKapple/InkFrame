// CanvasPromptBar 的「基础风格」入口 + base style 编辑对话框集成测试。
// Workspace v2 稿撤掉了画布工具条，基底风格入口挂在底部提示词条上（选中一个 config 节点时出现）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';

import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

// 提示词条只在恰好选中一个 image / video config 节点时出现；fake 隔离 DB DI。
const CanvasNode _imageNode = CanvasNode(id: 'n1', label: 'Shot', type: CanvasNodeType.image, canvasId: 'cv1');

class _OneNodeController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => const <CanvasNode>[_imageNode];
}

class _Selected extends CanvasSelectionController {
  @override
  Set<String> build(String canvasId) => <String>{'n1'};
}

// 最小化 fake：仅实现 findById（返回 base_style 字段），update 记录调用。
// readFails / updateFails：读 / 写抛 InkError，走两条失败提示。
class _FakeCanvasRepository implements CanvasRepository {
  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId) async =>
      const <Map<String, Object?>>[];

  _FakeCanvasRepository({
    String prefix = 'pre',
    String suffix = 'suf',
    this.readFails = false,
    this.updateFails = false,
  })  : _prefix = prefix,
        _suffix = suffix;

  final String _prefix;
  final String _suffix;
  final bool readFails;
  final bool updateFails;

  Map<String, Object?>? lastPatch;

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    if (readFails) throw const LocalIOError();
    return <String, Object?>{
      'id': id,
      'base_style_prefix': _prefix,
      'base_style_suffix': _suffix,
    };
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    lastPatch = patch;
    if (updateFails) throw const LocalIOError();
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

/// 失败用例的装配：overrides 同下面两条，外加把通知出口换成 RecordingToastService
/// （这里没有卡片层可看，断言记下来的卡）。
Future<void> _pumpBar(
  WidgetTester tester,
  _FakeCanvasRepository repo,
  RecordingToastService toast,
) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasPromptBar(canvasId: 'cv1')),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      canvasRepositoryProvider.overrideWith((_) async => repo),
      canvasNodesControllerProvider.overrideWith(_OneNodeController.new),
      canvasSelectionControllerProvider.overrideWith(_Selected.new),
      toastServiceProvider.overrideWithValue(toast),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('选中一个 config 节点 → 提示词条带「基础风格」入口', (tester) async {
    final repo = _FakeCanvasRepository();
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasPromptBar(canvasId: 'cv1')),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
        canvasRepositoryProvider.overrideWith((_) async => repo),
        canvasNodesControllerProvider.overrideWith(_OneNodeController.new),
        canvasSelectionControllerProvider.overrideWith(_Selected.new),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(CanvasPromptBar.baseStyleKey), findsOneWidget);
  });

  testWidgets('基础风格入口 → 对话框用已存值预填 → 保存 → repo 收到 base_style patch',
      (tester) async {
    // 端到端覆盖 _openEditor：await provider.future 预填（防数据丢失 guard）→
    // 编辑前缀 → Save → setBaseStyle 写库。这是用户真实路径。
    final repo = _FakeCanvasRepository(prefix: 'old-pre', suffix: 'old-suf');
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasPromptBar(canvasId: 'cv1')),
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
        canvasRepositoryProvider.overrideWith((_) async => repo),
        canvasNodesControllerProvider.overrideWith(_OneNodeController.new),
        canvasSelectionControllerProvider.overrideWith(_Selected.new),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CanvasPromptBar.baseStyleKey));
    await tester.pump();
    await tester.pumpAndSettle();

    // 对话框已打开，且用已存值预填（验证 await .future 防数据丢失 guard）。
    expect(find.text('Project base style'), findsOneWidget);
    expect(find.text('old-pre'), findsOneWidget);

    // 改前缀后保存。
    // 第 0 个 TextField 是提示词条自己的输入框，对话框的前缀框是第 1 个。
    await tester.enterText(find.byType(TextField).at(1), 'new-pre');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // setBaseStyle → repo.update 收到正确列名与值；后缀保持不变。
    expect(repo.lastPatch, isNotNull);
    expect(repo.lastPatch!['base_style_prefix'], 'new-pre');
    expect(repo.lastPatch!['base_style_suffix'], 'old-suf');
  });

  // 读不到已存值就不能开编辑器（空预填 + 保存 = 已存前后缀被覆盖为空，#199 评审 P2-3），
  // 但得说一声为什么点了没反应。
  testWidgets('读已存基底风格失败 → 不开编辑器，弹该 InkError 文案的错误卡', (tester) async {
    final repo = _FakeCanvasRepository(readFails: true);
    final toast = RecordingToastService();
    await _pumpBar(tester, repo, toast);

    await tester.tap(find.byKey(CanvasPromptBar.baseStyleKey));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Project base style'), findsNothing);
    expect(toast.titles, <String>[
      'Local disk I/O error. Check space and permissions.',
    ]);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(repo.lastPatch, isNull);
  });

  testWidgets('保存写库失败 → 错误卡「Failed to update base style」', (tester) async {
    final repo = _FakeCanvasRepository(updateFails: true);
    final toast = RecordingToastService();
    await _pumpBar(tester, repo, toast);

    await tester.tap(find.byKey(CanvasPromptBar.baseStyleKey));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Project base style'), findsOneWidget);

    // 第 0 个 TextField 是提示词条自己的输入框，对话框的前缀框是第 1 个。
    await tester.enterText(find.byType(TextField).at(1), 'new-pre');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.lastPatch, isNotNull, reason: '前置：写请求确实发出去了');
    expect(toast.titles, <String>['Failed to update base style']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
  });
}
