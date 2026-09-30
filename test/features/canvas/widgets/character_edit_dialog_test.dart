// CharacterEditDialog widget 测试（P4）：560 宽编辑框的四组字段 + 底部条。
//
// 断言的是落库内容与禁用态，不是"控件在树上"：保存把名称/描述写进仓储行、
// ✕ 真的删掉那一张并连带删文件、拖动真的换了注入次序、达上限时「添加」格 onTap 为 null。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/widgets/character_edit_dialog.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _kProjectId = 'p1';
const String _kCharacterId = 'c1';

caps.ProviderCapabilities _caps(String id, int maxRefs) =>
    caps.ProviderCapabilities(
  providerId: id,
  region: caps.ProviderRegion.global,
  modes: const <caps.GenerationMode>[caps.GenerationMode.imageToImage],
  supportedRatios: const <caps.AspectRatio>[caps.AspectRatio.r1x1],
  supportedResolutions: const <caps.Resolution>[caps.Resolution.p1080],
  supportedDurations: const <int>[],
  supportedCameras: const <caps.CameraMovement>[],
  maxBatchSize: 1,
  maxRefImages: maxRefs,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: false,
  supportsSeed: false,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: true,
  supportsPolling: true,
  costModel: const CostModel.perCall(usdPerCall: 0.01),
  maxConcurrentJobs: 1,
  qps: 1,
  burst: 1,
);

Map<String, Object?> _row({
  String name = '行者',
  String description = '',
  List<String> refs = const <String>[],
}) => <String, Object?>{
  'id': _kCharacterId,
  'project_id': _kProjectId,
  'name': name,
  'reference_image_paths': refs,
  'description': description,
  'sort_order': 0,
};

/// 打开编辑框的宿主：走 showCharacterEditDialog 这条真入口，不直接 pump 对话框
/// （直接 pump 会让保存时的 Navigator.pop 落在根路由上）。
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey<String>('open'),
        onPressed: () => showCharacterEditDialog(
          context,
          projectId: _kProjectId,
          characterId: _kCharacterId,
        ),
        child: const Text('open'),
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester, {
  required FakeCharacterRepo repo,
  required FakeCharacterAssetService assets,
  int maxRefs = 6,
  Map<String, List<String>> configCharacterIds = const <String, List<String>>{},
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

  await pumpInkApp(
    tester,
    const _Host(),
    overrides: <Override>[
      characterRepositoryProvider.overrideWith((_) async => repo),
      characterAssetServiceProvider.overrideWithValue(assets),
      providerCapabilitiesListProvider.overrideWithValue(
        <caps.ProviderCapabilities>[_caps('small', 1), _caps('big', maxRefs)],
      ),
      canvasRepositoryProvider.overrideWith((_) async => canvases),
      nodeRepositoryProvider.overrideWith((_) async => nodes),
      edgeRepositoryProvider.overrideWith((_) async => InMemoryEdgeRepository()),
      batchResultRepositoryProvider.overrideWith(
        (_) async => FakeBatchResultRepo(),
      ),
    ],
    surfaceSize: const Size(900, 1000),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('open')));
  await tester.pumpAndSettle();
}

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CharacterEditDialog)));

void main() {
  test('参考图上限取所有已登记 provider 的 maxRefImages 最大值', () {
    expect(
      maxReferenceImagesOf(<caps.ProviderCapabilities>[
        _caps('a', 2),
        _caps('b', 6),
        _caps('c', 0),
      ]),
      6,
    );
    expect(maxReferenceImagesOf(const <caps.ProviderCapabilities>[]), 0);
  });

  testWidgets('保存把名称与描述写进仓储行，并关掉框', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{_kCharacterId: _row()},
    );
    await _open(
      tester,
      repo: repo,
      assets: FakeCharacterAssetService(),
    );
    final AppLocalizations l = _l(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('character-name-field')),
      '山中老者',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('character-description-field')),
      '灰褐色斗篷，左颊有旧疤',
    );
    await tester.tap(find.byKey(const ValueKey<String>('character-save')));
    await tester.pumpAndSettle();

    expect(repo.rows[_kCharacterId]!['name'], '山中老者');
    expect(repo.rows[_kCharacterId]!['description'], '灰褐色斗篷，左颊有旧疤');
    expect(find.byType(CharacterEditDialog), findsNothing);
    expect(l.characterEditTitle, isNotEmpty);
  });

  testWidgets('取消不写库', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{_kCharacterId: _row()},
    );
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    await tester.enterText(
      find.byKey(const ValueKey<String>('character-name-field')),
      '不该落库',
    );
    await tester.tap(find.byKey(const ValueKey<String>('character-cancel')));
    await tester.pumpAndSettle();

    expect(repo.rows[_kCharacterId]!['name'], '行者');
    expect(find.byType(CharacterEditDialog), findsNothing);
  });

  testWidgets('✕ 删掉第 2 张：库里少一条，磁盘上那张也一并删', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{
        _kCharacterId: _row(
          refs: <String>[
            'characters/c1-0.png',
            'characters/c1-1.png',
            'characters/c1-2.png',
          ],
        ),
      },
    );
    final FakeCharacterAssetService assets = FakeCharacterAssetService();
    await _open(tester, repo: repo, assets: assets);

    await tester.tap(
      find.byKey(const ValueKey<String>('character-ref-remove-1')),
    );
    await tester.pumpAndSettle();

    expect(repo.rows[_kCharacterId]!['reference_image_paths'], <String>[
      'characters/c1-0.png',
      'characters/c1-2.png',
    ]);
    expect(assets.deleted, <String>['characters/c1-1.png']);
  });

  testWidgets('拖第 1 张到第 2 张：注入次序真的换了', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{
        _kCharacterId: _row(
          refs: <String>['characters/c1-0.png', 'characters/c1-1.png'],
        ),
      },
    );
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('character-ref-0'))),
    );
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey<String>('character-ref-1'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(repo.rows[_kCharacterId]!['reference_image_paths'], <String>[
      'characters/c1-1.png',
      'characters/c1-0.png',
    ]);
  });

  testWidgets('达上限：「添加」格禁用（onTap 为 null）且 tooltip 说明原因', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{
        _kCharacterId: _row(
          refs: <String>['characters/c1-0.png', 'characters/c1-1.png'],
        ),
      },
    );
    await _open(
      tester,
      repo: repo,
      assets: FakeCharacterAssetService(),
      maxRefs: 2,
    );
    final AppLocalizations l = _l(tester);

    final GestureDetector add = tester.widget<GestureDetector>(
      find.byKey(const ValueKey<String>('character-ref-add')),
    );
    expect(add.onTap, isNull, reason: '达上限仍可点 = 点了必然失败的死交互');
    expect(
      tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((Tooltip t) => t.message),
      contains(l.characterReferenceLimitReached),
    );
    expect(find.text(l.characterReferencesCount(2, 2)), findsOneWidget);
  });

  testWidgets('未达上限：「添加」格可点', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{
        _kCharacterId: _row(refs: <String>['characters/c1-0.png']),
      },
    );
    await _open(
      tester,
      repo: repo,
      assets: FakeCharacterAssetService(),
      maxRefs: 4,
    );

    final GestureDetector add = tester.widget<GestureDetector>(
      find.byKey(const ValueKey<String>('character-ref-add')),
    );
    expect(add.onTap, isNotNull);
    expect(find.text(_l(tester).characterReferencesCount(1, 4)), findsOneWidget);
  });

  testWidgets('被引用：chip 列出引用节点，底部条按实际引用数出文案', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{_kCharacterId: _row()},
    );
    await _open(
      tester,
      repo: repo,
      assets: FakeCharacterAssetService(),
      configCharacterIds: <String, List<String>>{
        '镜头 02': <String>[_kCharacterId],
        '镜头 05': <String>[_kCharacterId],
        '镜头 09': <String>['other'],
      },
    );
    final AppLocalizations l = _l(tester);

    expect(find.text('镜头 02'), findsOneWidget);
    expect(find.text('镜头 05'), findsOneWidget);
    expect(find.text('镜头 09'), findsNothing);
    expect(find.text(l.characterEditFootnote(2)), findsOneWidget);
  });

  testWidgets('无引用：底部条走 FootnoteNone', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{_kCharacterId: _row()},
    );
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    expect(find.text(_l(tester).characterEditFootnoteNone), findsOneWidget);
  });
}
