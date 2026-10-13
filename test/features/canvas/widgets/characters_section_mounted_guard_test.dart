// CH-2 评审残留③ 的回归闸：`_createFromReference` / `_importFromFile` 在
// `await _promptName` 之后不得再裸 `ref.read`。
//
// 命名框是模态，但检查器并不是：用户在框开着的时候可以取消选中节点、选别的节点、
// 甚至关掉画布——角色区这就被 dispose 了，之后再 `ref.read` 就是 ref-after-dispose
// （debug 下直接抛，release 下行为未定义）。守卫本身在 #240 已经补上了，这里补的是
// **闸**：没有它，下一次重构把两行 `if (!mounted) return;` 顺手删掉不会有任何东西变红。
//
// 测法 = 真的在框开着的时候把角色区从树上摘掉，再点确认。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/characters_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_providers.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _kCanvasId = 'cv-1';
const String _kProjectId = 'proj-1';

/// 只拼路径、不碰磁盘。
class _PathResolver implements FileResolverService {
  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) => File('/abs/$projectId/$canvasId/$relativePath');

  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) => throw UnimplementedError();

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) => throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      throw UnimplementedError();
}

/// 角色区挂在一个可摘掉的开关下——摘掉 = 用户取消选中 / 换选别的节点。
class _Host extends StatelessWidget {
  const _Host({required this.show, required this.node});

  final ValueNotifier<bool> show;
  final CanvasNode node;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ValueListenableBuilder<bool>(
      valueListenable: show,
      builder: (BuildContext _, bool visible, Widget? _) => visible
          ? SingleChildScrollView(
              child: CharactersSection(
                targetNode: node,
                selectedCaps: fakeVideoCapabilities(
                  id: 'kling-v3-omni',
                  maxRefImages: 4,
                  supportsFirstFrame: true,
                ),
                requireImageToImageMode: false,
              ),
            )
          : const SizedBox.shrink(),
    ),
  );
}

void _stubFilePicker(WidgetTester tester) {
  const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/file_selector',
  );
  final TestDefaultBinaryMessenger messenger =
      tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
    if (call.method != 'openFile') return null;
    return <String>['/src/ref.png'];
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

void main() {
  late InMemoryNodeRepository nodeRepo;
  late InMemoryEdgeRepository edgeRepo;
  late FakeCharacterRepo charRepo;
  late ValueNotifier<bool> show;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
    edgeRepo = InMemoryEdgeRepository();
    charRepo = FakeCharacterRepo();
    show = ValueNotifier<bool>(true);
    addTearDown(show.dispose);
  });

  Future<CanvasNode> seedTargetWithInput() async {
    final String id = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'video',
      nodeRole: 'config',
      label: 'cfg',
    );
    final String srcId = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'image',
      nodeRole: 'result',
      label: 'src',
      typeConfig: <String, Object?>{'image_url': 'images/hero.png'},
    );
    await edgeRepo.create(
      canvasId: _kCanvasId,
      sourceNodeId: srcId,
      targetNodeId: id,
      edgeType: 'data',
      role: 'first_frame',
    );
    return CanvasNode(
      id: id,
      label: 'cfg',
      type: CanvasNodeType.video,
      canvasId: _kCanvasId,
      projectId: _kProjectId,
    );
  }

  Future<AppLocalizations> pump(WidgetTester tester, CanvasNode node) async {
    await pumpInkApp(
      tester,
      _Host(show: show, node: node),
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        characterRepositoryProvider.overrideWith((ref) async => charRepo),
        characterAssetServiceProvider.overrideWithValue(
          FakeCharacterAssetService(),
        ),
        fileResolverServiceProvider.overrideWithValue(_PathResolver()),
      ],
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(CharactersSection)));
  }

  /// 框开着的时候把角色区摘掉，然后确认。
  Future<void> dismissSectionThenConfirm(
    WidgetTester tester,
    AppLocalizations l,
  ) async {
    show.value = false;
    await tester.pumpAndSettle();
    expect(
      find.byType(CharactersSection),
      findsNothing,
      reason: '前置条件：角色区确实已经不在树上了',
    );
    await tester.enterText(find.byType(TextField), 'Hero');
    await tester.pump();
    await tester.tap(find.text(l.inspectorCharactersSave));
    await tester.pumpAndSettle();
  }

  testWidgets('存为角色：命名框开着时角色区被摘掉 → 确认不抛、不建角色', (
    WidgetTester tester,
  ) async {
    final CanvasNode node = await seedTargetWithInput();
    final AppLocalizations l = await pump(tester, node);

    await tester.tap(find.text(l.inspectorCharactersSaveFromReference));
    await tester.pumpAndSettle();
    await dismissSectionThenConfirm(tester, l);

    expect(
      tester.takeException(),
      isNull,
      reason: 'await _promptName 之后缺 mounted 守卫 ⇒ ref-after-dispose',
    );
    expect(charRepo.rows, isEmpty, reason: '检查器已经不在了，不该替用户建角色');
  });

  testWidgets('从文件导入：命名框开着时角色区被摘掉 → 确认不抛、不建角色', (
    WidgetTester tester,
  ) async {
    _stubFilePicker(tester);
    final CanvasNode node = await seedTargetWithInput();
    final AppLocalizations l = await pump(tester, node);

    await tester.tap(find.text(l.inspectorCharactersImportFile));
    await tester.pumpAndSettle();
    await dismissSectionThenConfirm(tester, l);

    expect(tester.takeException(), isNull);
    expect(charRepo.rows, isEmpty);
  });
}
