// CharacterEditDialog widget 测试（P4）：560 宽编辑框的四组字段 + 底部条。
//
// 断言的是落库内容与禁用态，不是"控件在树上"：开框即回填、保存把名称/描述写进仓储行、
// ✕ 真的删掉那一张并连带删文件、拖动真的换了注入次序、达上限时「添加」格 onTap 为 null。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/db/columns.dart';
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

/// 在既有 FakeCharacterRepo 之上只加一件事：把每次 update 的 patch 原样记下来。
///
/// 既有 fake 只留「最终行状态」，于是"一次写请求都没发"和"发了一次把值写回原样"
/// 这两种截然不同的行为在断言里长得一模一样——`_save` 里"没改的那条不发写请求"
/// 这条契约因此从来没被钉住过。patches 让写请求本身成为可断言对象。
class _SpyCharacterRepo extends FakeCharacterRepo {
  _SpyCharacterRepo([super.rows]);

  /// 按调用顺序记下每次 update 的 patch（失败的那次也记——记的是"发出去了"）。
  final List<Map<String, Object?>> patches = <Map<String, Object?>>[];

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    patches.add(patch);
    return super.update(id, patch);
  }
}

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

/// 直接读输入框背后的 controller 文本——不经 enterText，才能看见"打开那一刻"的值。
String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey<String>(key))).controller!.text;

/// 把第 [from] 格拖到第 [to] 格。整格即把手，Draggable 的 affinity 是横向，
/// 所以一次横向 moveTo 就够起拖。[via] 用于先绕开再落回原位（自拖自）。
Future<void> _dragRef(
  WidgetTester tester, {
  required int from,
  required int to,
  int? via,
}) async {
  Offset centerOf(int i) =>
      tester.getCenter(find.byKey(ValueKey<String>('character-ref-$i')));

  final TestGesture gesture = await tester.startGesture(centerOf(from));
  await tester.pump();
  if (via != null) {
    await gesture.moveTo(centerOf(via));
    await tester.pump();
  }
  await gesture.moveTo(centerOf(to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

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

  // 钉 _CharacterEditDialogState.build 里的 `if (!_seeded) { ... }` 回填两行。
  // 既有用例一律先 enterText 再断言，等于把回填结果整个覆盖掉——那两行被删也全绿，
  // 而线上表现是"开框即空"。所以这里不许碰输入框，直接读 controller。
  testWidgets('打开即回填：两个输入框的 controller 等于库里的名称与描述', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{
        _kCharacterId: _row(description: '灰褐色斗篷，左颊有旧疤'),
      },
    );
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    expect(_fieldText(tester, 'character-name-field'), '行者');
    expect(_fieldText(tester, 'character-description-field'), '灰褐色斗篷，左颊有旧疤');
  });

  // 回填失效的真正后果不是"框里空着"，是"用户一个字没改点保存，描述被写成空串"。
  // 这条用写请求的条数把它钉死：没改过就不该有任何 update 发出去。
  testWidgets('一个字都没改点保存：一次 update 都不发', (WidgetTester tester) async {
    final _SpyCharacterRepo repo = _SpyCharacterRepo(
      <String, Map<String, Object?>>{
        _kCharacterId: _row(description: '灰褐色斗篷，左颊有旧疤'),
      },
    );
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    await tester.tap(find.byKey(const ValueKey<String>('character-save')));
    await tester.pumpAndSettle();

    expect(repo.patches, isEmpty, reason: '没改动却发写请求 = 拿界面状态覆盖库里的值');
    expect(repo.rows[_kCharacterId]!['description'], '灰褐色斗篷，左颊有旧疤');
    expect(find.byType(CharacterEditDialog), findsNothing);
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

  // 钉 _save 的第一条守卫 `name.isNotEmpty &&`。既有用例只保存过非空名称，
  // 这条守卫被删也全绿；删掉后清空名称点保存会把角色名写成空串（列表里从此是个无名条目）。
  testWidgets('名称清空点保存：库里仍是原名，且没发过带 name 的写请求', (
    WidgetTester tester,
  ) async {
    final _SpyCharacterRepo repo = _SpyCharacterRepo(
      <String, Map<String, Object?>>{_kCharacterId: _row(description: '灰袍')},
    );
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    await tester.enterText(
      find.byKey(const ValueKey<String>('character-name-field')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey<String>('character-save')));
    await tester.pumpAndSettle();

    expect(repo.rows[_kCharacterId]!['name'], '行者');
    expect(
      repo.patches.where(
        (Map<String, Object?> p) => p.containsKey(CharacterCol.name),
      ),
      isEmpty,
      reason: '空名不落库',
    );
  });

  // 钉 _save 里 `if (!await _guard(...)) return;` 的早退。既有用例没有一条走失败路径，
  // 把早退删成 `await _guard(...)` 也全绿；删掉后写库失败仍然关框，用户以为存上了。
  testWidgets('保存失败：框不关，出 SnackBar', (WidgetTester tester) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(
      <String, Map<String, Object?>>{_kCharacterId: _row()},
    )..failUpdate = true;
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    await tester.enterText(
      find.byKey(const ValueKey<String>('character-name-field')),
      '山中老者',
    );
    await tester.tap(find.byKey(const ValueKey<String>('character-save')));
    await tester.pumpAndSettle();

    expect(
      find.byType(CharacterEditDialog),
      findsOneWidget,
      reason: '写库失败却关框 = 用户以为存上了',
    );
    expect(find.byType(SnackBar), findsOneWidget);
    expect(repo.rows[_kCharacterId]!['name'], '行者');
  });

  // 钉 _save 里 `if (description != current.description)` 这条按列取舍。
  // 只看最终行状态是看不出来的（写回原值和不写，行状态一模一样），得看 patch 的列集合。
  testWidgets('只改名称：patch 里没有 description 列', (WidgetTester tester) async {
    final _SpyCharacterRepo repo = _SpyCharacterRepo(
      <String, Map<String, Object?>>{_kCharacterId: _row(description: '灰袍')},
    );
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    await tester.enterText(
      find.byKey(const ValueKey<String>('character-name-field')),
      '山中老者',
    );
    await tester.tap(find.byKey(const ValueKey<String>('character-save')));
    await tester.pumpAndSettle();

    expect(repo.patches, hasLength(1), reason: '没改的那条不该发写请求');
    expect(repo.patches.single.containsKey(CharacterCol.name), isTrue);
    expect(repo.patches.single.containsKey(CharacterCol.description), isFalse);
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

  // 三张，不是两张：两张时 reorder(from, to) 与 reorder(to, from) 都只是"对调"，
  // 参数颠倒测不出来。三张且跨两格才把两个参数的角色分开——
  // 正确的 0→2 是 [1,2,0]，颠倒成 2→0 是 [2,0,1]。
  testWidgets('三张参考图，第 1 张拖到第 3 张：落库次序是 1,2,0', (
    WidgetTester tester,
  ) async {
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
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    await _dragRef(tester, from: 0, to: 2);

    expect(repo.rows[_kCharacterId]!['reference_image_paths'], <String>[
      'characters/c1-1.png',
      'characters/c1-2.png',
      'characters/c1-0.png',
    ]);
  });

  // 钉 _ReferenceTile 里 DragTarget 的 onWillAcceptWithDetails: `d.data != index`。
  // 只断言"库没变"抓不到它——把守卫改成恒 true，落到自己身上仍会走 reorder(i, i)，
  // 而 controller 自己那条 `oldIndex == newIndex` 早退会把写请求挡下来，库照样不变。
  // 所以这里既断行为（不重排、不发写请求），也直接断这个谓词本身。
  testWidgets('拖到自己身上是 no-op：不重排、不发写请求', (WidgetTester tester) async {
    final _SpyCharacterRepo repo = _SpyCharacterRepo(
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
    await _open(tester, repo: repo, assets: FakeCharacterAssetService());

    // 先绕到第 3 格再落回自己，保证真的起拖了（横向位移超过 slop）。
    await _dragRef(tester, from: 0, to: 0, via: 2);

    expect(repo.rows[_kCharacterId]!['reference_image_paths'], <String>[
      'characters/c1-0.png',
      'characters/c1-1.png',
      'characters/c1-2.png',
    ]);
    expect(repo.patches, isEmpty);

    final DragTarget<int> target = tester.widget<DragTarget<int>>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('character-ref-0')),
        matching: find.byType(DragTarget<int>),
      ),
    );
    expect(
      target.onWillAcceptWithDetails!(
        DragTargetDetails<int>(data: 0, offset: Offset.zero),
      ),
      isFalse,
      reason: '第 0 格不该把第 0 格当作可接收的来源',
    );
    expect(
      target.onWillAcceptWithDetails!(
        DragTargetDetails<int>(data: 1, offset: Offset.zero),
      ),
      isTrue,
    );
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
