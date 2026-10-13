// CH-2 残留②：挂载角色数 + 边连参考图合计超过 maxRefImages 时，UI 此前一个字都不说，
// 而 provider 的 take(maxRefImages) 从尾部截断——掉的恰好是角色图。用户挂了角色、
// 以为生效了，实际被悄悄丢掉。
//
// 这组用例按用户遭遇走：超限时角色区必须出现带角色名的提示（提交之前就看得见，
// 用户才有机会取舍），没超限时不许吓人。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/characters_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_providers.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _kCanvasId = 'cv-1';
const String _kProjectId = 'proj-1';

/// 超限提示的测试锚点——文案带三个占位符，按 Key 找比拼字符串稳。
final Finder _overLimit = find.byKey(
  const ValueKey<String>('characters-over-limit'),
);

void main() {
  late InMemoryNodeRepository nodeRepo;
  late InMemoryEdgeRepository edgeRepo;
  late FakeCharacterRepo charRepo;

  setUp(() {
    nodeRepo = InMemoryNodeRepository();
    edgeRepo = InMemoryEdgeRepository();
    charRepo = FakeCharacterRepo();
  });

  void seedCharacter(String id, String name, int imageCount) {
    charRepo.rows[id] = <String, Object?>{
      'id': id,
      'project_id': _kProjectId,
      'name': name,
      'reference_image_paths': <String>[
        for (int i = 0; i < imageCount; i++) 'characters/$id-$i.png',
      ],
    };
  }

  Future<CanvasNode> seedTarget(List<String> attachedIds) async {
    final Map<String, Object?> tc = <String, Object?>{
      'character_ids': attachedIds,
    };
    final String id = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'video',
      nodeRole: 'config',
      label: 'cfg',
      typeConfig: tc,
    );
    return CanvasNode(
      id: id,
      label: 'cfg',
      type: CanvasNodeType.video,
      canvasId: _kCanvasId,
      projectId: _kProjectId,
      typeConfig: tc,
    );
  }

  /// 一条 data 入边 + 带图的源节点。role 决定它是否占参考图配额。
  Future<void> seedInput(String targetId, {required String role}) async {
    final String srcId = await nodeRepo.create(
      canvasId: _kCanvasId,
      type: 'image',
      nodeRole: 'result',
      label: 'src',
      typeConfig: <String, Object?>{
        'image_url': 'images/$role-${edgeRepo.rows.length}.png',
      },
    );
    await edgeRepo.create(
      canvasId: _kCanvasId,
      sourceNodeId: srcId,
      targetNodeId: targetId,
      edgeType: 'data',
      role: role,
    );
  }

  Future<AppLocalizations> pump(
    WidgetTester tester,
    CanvasNode node, {
    required int maxRefImages,
  }) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: CharactersSection(
            targetNode: node,
            selectedCaps: fakeVideoCapabilities(
              id: 'kling-v3-omni',
              maxRefImages: maxRefImages,
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
        characterAssetServiceProvider.overrideWithValue(
          FakeCharacterAssetService(),
        ),
      ],
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(CharactersSection)));
  }

  testWidgets('合计超限 → 角色区出现提示，并点名被丢的角色', (WidgetTester tester) async {
    seedCharacter('char-1', 'Hero', 2);
    final CanvasNode node = await seedTarget(<String>['char-1']);
    await seedInput(node.id, role: 'reference');
    final AppLocalizations l = await pump(tester, node, maxRefImages: 2);

    // 1 条 reference 入边 + 角色 2 张 = 3 > 2 ⇒ 角色图被截掉一张。
    expect(
      _overLimit,
      findsOneWidget,
      reason: '超限必须让用户在提交前看得见，不能只有 provider 悄悄 take()',
    );
    expect(
      find.text(l.inspectorCharactersOverLimit(3, 2, 'Hero')),
      findsOneWidget,
      reason: '文案要说清合计几张 / 上限几张 / 是谁被丢了',
    );
  });

  testWidgets('未超限 → 不出现提示', (WidgetTester tester) async {
    seedCharacter('char-1', 'Hero', 1);
    final CanvasNode node = await seedTarget(<String>['char-1']);
    await seedInput(node.id, role: 'reference');
    await pump(tester, node, maxRefImages: 4);

    expect(_overLimit, findsNothing, reason: '没超限不该吓人');
  });

  testWidgets('首/尾帧入边不占配额 → 同样的角色不再报超限', (WidgetTester tester) async {
    // refImagesIncludeKeyframes 全家为 false，首/尾帧走 firstFramePath/lastFramePath
    // 两个独立字段，不进 refImagePaths ⇒ 不该挤掉角色图。
    seedCharacter('char-1', 'Hero', 2);
    final CanvasNode node = await seedTarget(<String>['char-1']);
    await seedInput(node.id, role: 'first_frame');
    await pump(tester, node, maxRefImages: 2);

    expect(_overLimit, findsNothing);
  });

  testWidgets('两个角色超限 → 提示里按注入顺序只点名真正被咬的那个', (
    WidgetTester tester,
  ) async {
    seedCharacter('char-1', 'Hero', 1);
    seedCharacter('char-2', 'Villain', 2);
    final CanvasNode node = await seedTarget(<String>['char-1', 'char-2']);
    final AppLocalizations l = await pump(tester, node, maxRefImages: 2);

    // 0 边 + 1 + 2 = 3 > 2 ⇒ Hero 整份进去，Villain 掉一张。
    expect(
      find.text(l.inspectorCharactersOverLimit(3, 2, 'Villain')),
      findsOneWidget,
    );
  });

  testWidgets('未挂角色但边连超限 → 角色区不插话（那是入边区那条提示的事）', (
    WidgetTester tester,
  ) async {
    final CanvasNode node = await seedTarget(const <String>[]);
    await seedInput(node.id, role: 'reference');
    await seedInput(node.id, role: 'reference');
    await pump(tester, node, maxRefImages: 1);

    expect(_overLimit, findsNothing, reason: '角色区只对"角色被丢掉"发声');
  });
}
