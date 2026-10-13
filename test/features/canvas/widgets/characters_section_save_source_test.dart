// CH-2 残留①：「存为角色」在默认连法下恒灰。
//
// image→video 拉一条线，默认 role 是 first_frame（link_action_controller._defaultRole，
// 已由 test/features/canvas/link_action_controller_test.dart「智能默认 role」钉住），
// 而「存为角色」此前只认 reference 入边 ⇒ 正常连法下按钮永远不可点，用户必须先去
// 入边区把边切成 reference 才存得了。这组用例按用户的真实连法走：
//   1. first_frame 入边 → 按钮可点，且存出来的是那条入边源节点的图；
//   2. 无图入边 → 仍然不可点（onPressed == null，不是空闭包）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/characters_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/components/ink_name_dialog.dart';

import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_providers.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _kCanvasId = 'cv-1';
const String _kProjectId = 'proj-1';

/// 只拼路径、不碰磁盘：relativePath 原样出现在绝对路径里，便于断言「存的是哪一张」。
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

/// 记下 importImage 收到的源路径——这就是「存出来的是哪一张」的证据。
class _RecordingAssets extends FakeCharacterAssetService {
  final List<String> sources = <String>[];

  @override
  Future<String> importImage({
    required String projectId,
    required String sourceAbsolutePath,
    required String fileBaseName,
  }) {
    sources.add(sourceAbsolutePath);
    return super.importImage(
      projectId: projectId,
      sourceAbsolutePath: sourceAbsolutePath,
      fileBaseName: fileBaseName,
    );
  }
}

void main() {
  late InMemoryNodeRepository nodeRepo;
  late InMemoryEdgeRepository edgeRepo;
  late FakeCharacterRepo charRepo;
  late _RecordingAssets assets;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
    edgeRepo = InMemoryEdgeRepository();
    charRepo = FakeCharacterRepo();
    assets = _RecordingAssets();
  });

  /// video config 节点（被检查的那个）。
  Future<CanvasNode> seedTarget() async {
    final String id = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'video',
      nodeRole: 'config',
      label: 'cfg',
    );
    return CanvasNode(
      id: id,
      label: 'cfg',
      type: CanvasNodeType.video,
      canvasId: _kCanvasId,
      projectId: _kProjectId,
    );
  }

  /// 一张图片 result 节点 + 一条 data 入边（role 由调用方给）。
  Future<void> seedInput(
    String targetId, {
    required String role,
    String? imageUrl,
    String label = 'src',
  }) async {
    final String srcId = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'image',
      nodeRole: 'result',
      label: label,
      typeConfig: <String, Object?>{'image_url': ?imageUrl},
    );
    await edgeRepo.create(
      canvasId: _kCanvasId,
      sourceNodeId: srcId,
      targetNodeId: targetId,
      edgeType: 'data',
      role: role,
    );
  }

  Future<AppLocalizations> pump(WidgetTester tester, CanvasNode node) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: CharactersSection(
            targetNode: node,
            selectedCaps: fakeVideoCapabilities(
              id: 'kling-v3-omni',
              maxRefImages: 4,
              supportsFirstFrame: true,
            ),
            requireImageToImageMode: false,
          ),
        ),
      ),
      overrides: [
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => edgeRepo),
        characterRepositoryProvider.overrideWith((ref) async => charRepo),
        characterAssetServiceProvider.overrideWithValue(assets),
        fileResolverServiceProvider.overrideWithValue(_PathResolver()),
      ],
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(CharactersSection)),
    );
  }

  TextButton saveButton(WidgetTester tester, AppLocalizations l) =>
      tester.widget<TextButton>(
        find
            .ancestor(
              of: find.text(l.inspectorCharactersSaveFromReference),
              matching: find.byType(TextButton),
            )
            .first,
      );

  testWidgets('first_frame 入边（image→video 默认连法）→「存为角色」可点', (
    WidgetTester tester,
  ) async {
    final CanvasNode node = await seedTarget();
    await seedInput(node.id, role: 'first_frame', imageUrl: 'images/hero.png');
    final AppLocalizations l = await pump(tester, node);

    expect(
      saveButton(tester, l).onPressed,
      isNotNull,
      reason: '默认连法就是 first_frame；按钮在这条路上必须可点，否则功能等于不存在',
    );
  });

  testWidgets('first_frame 入边 → 存出来的是那条入边源节点的图', (
    WidgetTester tester,
  ) async {
    final CanvasNode node = await seedTarget();
    await seedInput(node.id, role: 'first_frame', imageUrl: 'images/hero.png');
    final AppLocalizations l = await pump(tester, node);

    await tester.tap(find.text(l.inspectorCharactersSaveFromReference));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hero');
    await tester.pump();
    await tester.tap(find.text(l.inspectorCharactersSave));
    await tester.pumpAndSettle();

    expect(
      assets.sources,
      <String>['/abs/$_kProjectId/$_kCanvasId/images/hero.png'],
      reason: '放开 role 之后存的仍须是入边那张图，不能错位到别的节点',
    );
    expect(charRepo.rows, hasLength(1), reason: '角色记录已建');
    expect(tester.takeException(), isNull);
  });

  testWidgets('两条入边（first_frame 在前）→ 存的是入边区最上面那一行的图', (
    WidgetTester tester,
  ) async {
    final CanvasNode node = await seedTarget();
    // 建行顺序 = 入边区的显示顺序（EdgeRepository 的 ORDER BY sort_order, created_at）。
    await seedInput(node.id, role: 'first_frame', imageUrl: 'images/first.png');
    await seedInput(node.id, role: 'reference', imageUrl: 'images/ref.png');
    final AppLocalizations l = await pump(tester, node);

    await tester.tap(find.text(l.inspectorCharactersSaveFromReference));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hero');
    await tester.pump();
    await tester.tap(find.text(l.inspectorCharactersSave));
    await tester.pumpAndSettle();

    expect(
      assets.sources,
      <String>['/abs/$_kProjectId/$_kCanvasId/images/first.png'],
      reason: '选的是第一条有图的入边——与检查器「关键帧」组的行序同一个排序',
    );
  });

  testWidgets('命名框是收口后的那一份共用件（CH-2 残留④）', (WidgetTester tester) async {
    final CanvasNode node = await seedTarget();
    await seedInput(node.id, role: 'first_frame', imageUrl: 'images/hero.png');
    final AppLocalizations l = await pump(tester, node);

    await tester.tap(find.text(l.inspectorCharactersSaveFromReference));
    await tester.pumpAndSettle();

    expect(
      find.byType(InkNameDialog),
      findsOneWidget,
      reason: '三份近似件收成一份，检查器这端走的就是它',
    );
    expect(
      tester
          .widget<ButtonStyleButton>(
            find
                .ancestor(
                  of: find.text(l.inspectorCharactersSave),
                  // find.byType 不认子类，确认键是 FilledButton。
                  matching: find.byWidgetPredicate(
                    (Widget w) => w is ButtonStyleButton,
                  ),
                )
                .first,
          )
          .onPressed,
      isNull,
      reason: '空名字时确认键禁用——此前检查器那份恒可点，点下去才被调用方 trim 掉',
    );
  });

  testWidgets('入边源节点无图 → 按钮不可点（onPressed == null，不是空闭包）', (
    WidgetTester tester,
  ) async {
    final CanvasNode node = await seedTarget();
    await seedInput(node.id, role: 'first_frame');
    final AppLocalizations l = await pump(tester, node);

    expect(
      saveButton(tester, l).onPressed,
      isNull,
      reason: '没有图可存就该真禁用，而不是点了没反应',
    );
  });
}
