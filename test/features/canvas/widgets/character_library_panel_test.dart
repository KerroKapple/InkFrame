// CharacterLibraryPanel widget 测试（P4）：左栏「角色」页。
//
// 断言的是行为不是存在性：meta 行的引用数由真 galleryGraphProvider + 真节点行算出
// （config 记、result 不记）、删除必须过二次确认且真的落到 softDelete、改名真的改库、
// 检查器「管理」链接真的把左栏页签切到角色页。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/project_panel_tab.dart';
import 'package:inkframe/features/canvas/widgets/character_library_panel.dart';
import 'package:inkframe/features/canvas/widgets/characters_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _kProjectId = 'p1';

Map<String, Object?> _characterRow(
  String id, {
  required String name,
  List<String> refs = const <String>[],
}) => <String, Object?>{
  'id': id,
  'project_id': _kProjectId,
  'name': name,
  'reference_image_paths': refs,
  'description': '',
  'sort_order': 0,
};

/// 真 galleryGraphProvider 的四个仓储都接上，引用计数走真实路径。
Future<List<Override>> _overrides(
  FakeCharacterRepo characters, {
  Map<String, List<String>> configCharacterIds = const <String, List<String>>{},
  Map<String, List<String>> resultCharacterIds = const <String, List<String>>{},
}) async {
  final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
  final InMemoryNodeRepository nodes = InMemoryNodeRepository();
  final String canvasId = await canvases.create(
    projectId: _kProjectId,
    name: 'A',
  );
  for (final MapEntry<String, List<String>> e in configCharacterIds.entries) {
    await nodes.create(
      canvasId: canvasId,
      type: 'image',
      nodeRole: 'config',
      label: e.key,
      typeConfig: <String, Object?>{'character_ids': e.value},
    );
  }
  for (final MapEntry<String, List<String>> e in resultCharacterIds.entries) {
    await nodes.create(
      canvasId: canvasId,
      type: 'image',
      nodeRole: 'result',
      label: e.key,
      typeConfig: <String, Object?>{'character_ids': e.value},
    );
  }
  return <Override>[
    characterRepositoryProvider.overrideWith((_) async => characters),
    characterAssetServiceProvider.overrideWithValue(
      FakeCharacterAssetService(),
    ),
    canvasRepositoryProvider.overrideWith((_) async => canvases),
    nodeRepositoryProvider.overrideWith((_) async => nodes),
    edgeRepositoryProvider.overrideWith((_) async => InMemoryEdgeRepository()),
    batchResultRepositoryProvider.overrideWith(
      (_) async => FakeBatchResultRepo(),
    ),
  ];
}

Future<void> _pumpPanel(WidgetTester tester, List<Override> overrides) async {
  await pumpInkApp(
    tester,
    const Scaffold(
      body: SizedBox(
        width: 241,
        child: CharacterLibraryPanel(projectId: _kProjectId),
      ),
    ),
    overrides: overrides,
    surfaceSize: const Size(400, 700),
  );
  await tester.pumpAndSettle();
}

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CharacterLibraryPanel)));

void main() {
  testWidgets('meta 行：引用数只数 config 节点，无引用走 RefAndUsageNone', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(<String, Map<String, Object?>>{
      'c1': _characterRow('c1', name: '行者', refs: <String>['characters/a.png', 'characters/b.png']),
      'c2': _characterRow('c2', name: '少年'),
    });
    await _pumpPanel(
      tester,
      await _overrides(
        repo,
        // 两个 config 引 c1；一个 result 也带 c1（从 config 拷来的），不得计数。
        configCharacterIds: <String, List<String>>{
          'cfgA': <String>['c1'],
          'cfgB': <String>['c1'],
        },
        resultCharacterIds: <String, List<String>>{
          'res': <String>['c1'],
        },
      ),
    );

    final AppLocalizations l = _l(tester);
    expect(find.text('行者'), findsOneWidget);
    expect(find.text(l.characterRefAndUsage(2, 2)), findsOneWidget);
    expect(find.text(l.characterRefAndUsageNone(0)), findsOneWidget);
  });

  testWidgets('零角色 → 空态文案 + 底部「新建角色」仍在', (WidgetTester tester) async {
    await _pumpPanel(tester, await _overrides(FakeCharacterRepo()));

    final AppLocalizations l = _l(tester);
    expect(find.text(l.characterLibraryEmpty), findsOneWidget);
    expect(find.text(l.characterNew), findsOneWidget);
  });

  testWidgets('⋯ → 删除 → 二次确认后才 softDelete；取消则不动库', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(<String, Map<String, Object?>>{
      'c1': _characterRow('c1', name: '行者'),
    });
    await _pumpPanel(tester, await _overrides(repo));
    final AppLocalizations l = _l(tester);

    // 第一次：确认框里点取消 → 不落库。
    await tester.tap(find.byKey(const ValueKey<String>('character-menu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.characterMenuDelete).last);
    await tester.pumpAndSettle();
    expect(find.text(l.characterDeleteBody('行者')), findsOneWidget);
    await tester.tap(find.text(l.commonCancel));
    await tester.pumpAndSettle();
    expect(repo.softDeleted, isEmpty, reason: '没确认就删 = 无法撤销的破坏');

    // 第二次：确认 → 落库 + 行消失。
    await tester.tap(find.byKey(const ValueKey<String>('character-menu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.characterMenuDelete).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('character-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repo.softDeleted, <String>['c1']);
    expect(find.text('行者'), findsNothing);
  });

  testWidgets('⋯ → 改名：输入的名字真的写进仓储行', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(<String, Map<String, Object?>>{
      'c1': _characterRow('c1', name: '行者'),
    });
    await _pumpPanel(tester, await _overrides(repo));
    final AppLocalizations l = _l(tester);

    await tester.tap(find.byKey(const ValueKey<String>('character-menu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.characterMenuRename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  山中老者  ');
    await tester.tap(find.text(l.characterSave));
    await tester.pumpAndSettle();

    expect(repo.rows['c1']!['name'], '山中老者', reason: '首尾空白要 trim 掉');
    expect(find.text('山中老者'), findsOneWidget);
  });

  testWidgets('检查器角色区的「管理」链接把左栏页签切到角色页', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo();
    await pumpInkApp(
      tester,
      const Scaffold(
        body: SizedBox(
          width: 301,
          child: CharactersSection(
            // canvasId 为 null：只测「管理」链接，不牵扯连线来源查找。
            targetNode: CanvasNode(
              id: 'n1',
              label: 'n1',
              type: CanvasNodeType.image,
              projectId: _kProjectId,
            ),
            selectedCaps: null,
            requireImageToImageMode: true,
          ),
        ),
      ),
      overrides: <Override>[
        characterRepositoryProvider.overrideWith((_) async => repo),
        characterAssetServiceProvider.overrideWithValue(
          FakeCharacterAssetService(),
        ),
      ],
      surfaceSize: const Size(400, 700),
    );
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(CharactersSection)),
    );
    expect(container.read(projectPanelTabProvider), ProjectPanelTab.canvases);

    await tester.tap(find.byKey(const ValueKey<String>('characters-manage')));
    await tester.pumpAndSettle();

    expect(container.read(projectPanelTabProvider), ProjectPanelTab.characters);
  });
}
