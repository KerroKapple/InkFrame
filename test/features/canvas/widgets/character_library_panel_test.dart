// CharacterLibraryPanel widget 测试（P4）：左栏「角色」页。
//
// 断言的是行为不是存在性：meta 行的引用数由真 galleryGraphProvider + 真节点行算出
// （config 记、result 不记）、删除必须过二次确认且真的落到 softDelete、改名真的改库、
// 检查器「管理」链接真的把左栏页签切到角色页。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/character_asset_service.dart';
import 'package:inkframe/core/models/provider_capabilities.dart' as caps;
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/project_panel_tab.dart';
import 'package:inkframe/features/canvas/widgets/character_edit_dialog.dart';
import 'package:inkframe/features/canvas/widgets/character_library_panel.dart';
import 'package:inkframe/features/canvas/widgets/characters_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/components/ink_error_banner.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_character.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _kProjectId = 'p1';

/// softDelete 会失败的仓储（FakeCharacterRepo 只带 update / create / hardDelete 的失败开关）。
class _SoftDeleteFailsRepo extends FakeCharacterRepo {
  _SoftDeleteFailsRepo(super.rows);

  @override
  Future<int> softDelete(String id) async => throw const LocalIOError();
}

/// importImage 抛指定对象的资产服务——用来喂 createFromImage 那条路上
/// 「不是 InkError」的两类真实抛出：CharacterAssetError 与 FileSystemException。
class _ImportThrowsAssets extends FakeCharacterAssetService {
  _ImportThrowsAssets(this.error);

  final Object error;

  @override
  Future<String> importImage({
    required String projectId,
    required String sourceAbsolutePath,
    required String fileBaseName,
  }) async => throw error;
}

/// 「新建角色」要先过系统文件选择器；widget test 里把 file_selector 的方法通道
/// 打桩成「用户选了一张图」，否则这条入口一步都走不到。
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
  CharacterAssetService? assets,
  InkError? readError,
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
    characterRepositoryProvider.overrideWith((_) async {
      // readError 非空 = 模拟「读库这一步就失败」（复审 #25）。
      final InkError? failure = readError;
      if (failure != null) throw failure;
      return characters;
    }),
    characterAssetServiceProvider.overrideWithValue(
      assets ?? FakeCharacterAssetService(),
    ),
    // 编辑框要读参考图上限；这里不测上限，给空列表即可（不牵扯真 provider 注册表）。
    providerCapabilitiesListProvider.overrideWithValue(
      const <caps.ProviderCapabilities>[],
    ),
    canvasRepositoryProvider.overrideWith((_) async => canvases),
    nodeRepositoryProvider.overrideWith((_) async => nodes),
    edgeRepositoryProvider.overrideWith((_) async => InMemoryEdgeRepository()),
    batchResultRepositoryProvider.overrideWith(
      (_) async => FakeBatchResultRepo(),
    ),
  ];
}

Future<void> _pumpPanel(
  WidgetTester tester,
  List<Override> overrides, {
  Size surfaceSize = const Size(400, 700),
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(
      body: SizedBox(
        width: 241,
        child: CharacterLibraryPanel(projectId: _kProjectId),
      ),
    ),
    overrides: overrides,
    surfaceSize: surfaceSize,
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

  // ── A：改名 / 删除失败的文案（_guard 走 l10nError，不套导入文案）─────────────
  //
  // 这两条路径根本不导入任何文件。原实现一律弹「角色导入失败」，等于把磁盘满 /
  // 连接断说成「导入失败」，把用户引向一个跟本次操作无关的方向。

  testWidgets('改名失败 → SnackBar 是该 InkError 的文案，不是「角色导入失败」', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo =
        FakeCharacterRepo(<String, Map<String, Object?>>{
          'c1': _characterRow('c1', name: '行者'),
        })..failUpdate = true;
    await _pumpPanel(tester, await _overrides(repo));
    final AppLocalizations l = _l(tester);

    await tester.tap(find.byKey(const ValueKey<String>('character-menu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.characterMenuRename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '山中老者');
    await tester.tap(find.text(l.characterSave));
    await tester.pumpAndSettle();

    expect(find.text(l.errorLocalIO), findsOneWidget);
    expect(
      find.text(l.inspectorCharactersImportFailed),
      findsNothing,
      reason: '改名不导入任何文件，套导入文案是误导',
    );
    // 乐观更新要回滚：名字仍是旧的，不假装成功。
    expect(find.text('行者'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除失败 → SnackBar 是该 InkError 的文案，不是「角色导入失败」', (
    WidgetTester tester,
  ) async {
    final _SoftDeleteFailsRepo repo =
        _SoftDeleteFailsRepo(<String, Map<String, Object?>>{
          'c1': _characterRow('c1', name: '行者'),
        });
    await _pumpPanel(tester, await _overrides(repo));
    final AppLocalizations l = _l(tester);

    await tester.tap(find.byKey(const ValueKey<String>('character-menu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.characterMenuDelete).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('character-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.errorLocalIO), findsOneWidget);
    expect(
      find.text(l.inspectorCharactersImportFailed),
      findsNothing,
      reason: '删除不导入任何文件，套导入文案是误导',
    );
    // 乐观删除要回滚：行还在。
    expect(find.text('行者'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── B：createCharacterFromFile 的捕获集要盖住 createFromImage 的真实抛出集 ──
  //
  // createFromImage 会抛仓储 InkError / 资产服务 CharacterAssetError /
  // dart:io FileSystemException。后两类不是 InkError：只接 InkError 的话，
  // 用户选了一张坏文件后界面毫无反应，错误变成未捕获异步异常（只多一份 crash 文件）。

  testWidgets('新建角色：资产服务抛 CharacterAssetError → 导入失败提示，且无异常逃逸', (
    WidgetTester tester,
  ) async {
    _stubFilePicker(tester);
    final FakeCharacterRepo repo = FakeCharacterRepo();
    await _pumpPanel(
      tester,
      await _overrides(
        repo,
        assets: _ImportThrowsAssets(
          const CharacterAssetError('path escapes project root'),
        ),
      ),
    );
    final AppLocalizations l = _l(tester);

    await tester.tap(find.byKey(const ValueKey<String>('character-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '行者');
    await tester.tap(find.text(l.characterSave));
    await tester.pumpAndSettle();

    expect(find.text(l.inspectorCharactersImportFailed), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'CharacterAssetError 不是 InkError，漏接就会变成未捕获异步异常',
    );
    // 补偿跑过：不留 ghost 记录。
    expect(repo.rows, isEmpty);
  });

  testWidgets('新建角色：资产服务抛 FileSystemException → 导入失败提示，且无异常逃逸', (
    WidgetTester tester,
  ) async {
    _stubFilePicker(tester);
    final FakeCharacterRepo repo = FakeCharacterRepo();
    await _pumpPanel(
      tester,
      await _overrides(
        repo,
        assets: _ImportThrowsAssets(
          const FileSystemException('source file vanished'),
        ),
      ),
    );
    final AppLocalizations l = _l(tester);

    await tester.tap(find.byKey(const ValueKey<String>('character-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '行者');
    await tester.tap(find.text(l.characterSave));
    await tester.pumpAndSettle();

    expect(find.text(l.inspectorCharactersImportFailed), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'FileSystemException 不是 InkError，漏接就会变成未捕获异步异常',
    );
    expect(repo.rows, isEmpty);
  });

  // ── C：⋯ 的 tooltip 不是角色名 ───────────────────────────────────────────────
  //
  // 按钮的 tooltip 说的是「点下去会怎样」。填角色名等于把提示当正文用：
  // 名字已经就在同一行里，悬停再复述一遍没有信息量，读屏软件也会读出错误的动作名。

  testWidgets('⋯ 按钮的 tooltip 不是角色名，而是系统默认的「显示菜单」', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(<String, Map<String, Object?>>{
      'c1': _characterRow('c1', name: '行者'),
    });
    await _pumpPanel(tester, await _overrides(repo));

    final Tooltip tip = tester.widget<Tooltip>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('character-menu-c1')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tip.message, isNot('行者'), reason: 'tooltip 不是复述正文的地方');
    expect(
      tip.message,
      MaterialLocalizations.of(
        tester.element(find.byType(CharacterLibraryPanel)),
      ).showMenuTooltip,
    );
  });

  // ── 复审 #25：读库失败必须显性报错，不能静默降级成空态 ───────────────────────

  testWidgets('读库失败 → InkErrorBanner，而不是谎报「还没有角色」', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      await _overrides(FakeCharacterRepo(), readError: const LocalIOError()),
    );
    final AppLocalizations l = _l(tester);

    expect(find.byType(InkErrorBanner), findsOneWidget);
    expect(find.text(l.errorLocalIO), findsOneWidget);
    expect(
      find.text(l.characterLibraryEmpty),
      findsNothing,
      reason: '读失败降级成空态 = 告诉用户「你没有角色」，会诱发重建',
    );
    expect(tester.takeException(), isNull);
  });

  // ── 复审 #26：进编辑框的两条路（⋯ 菜单第一项 / 整行点击）───────────────────
  //
  // 多角色场景：弹出的必须是「被点那一行」的角色，不是列表第一个。

  testWidgets('⋯ → 编辑 → 打开的是被点那一行的角色编辑框', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(<String, Map<String, Object?>>{
      'c1': _characterRow('c1', name: '行者'),
      'c2': _characterRow('c2', name: '少年'),
    });
    await _pumpPanel(
      tester,
      await _overrides(repo),
      surfaceSize: const Size(900, 1000),
    );
    final AppLocalizations l = _l(tester);

    await tester.tap(find.byKey(const ValueKey<String>('character-menu-c2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.characterMenuEdit));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterEditDialog), findsOneWidget);
    expect(
      tester
          .widget<CharacterEditDialog>(find.byType(CharacterEditDialog))
          .characterId,
      'c2',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('character-name-field')),
          )
          .controller
          ?.text,
      '少年',
    );
  });

  testWidgets('点整行 → 打开该行角色的编辑框（与菜单第一项同语义）', (
    WidgetTester tester,
  ) async {
    final FakeCharacterRepo repo = FakeCharacterRepo(<String, Map<String, Object?>>{
      'c1': _characterRow('c1', name: '行者'),
      'c2': _characterRow('c2', name: '少年'),
    });
    await _pumpPanel(
      tester,
      await _overrides(repo),
      surfaceSize: const Size(900, 1000),
    );

    await tester.tap(find.byKey(const ValueKey<String>('character-row-c1')));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterEditDialog), findsOneWidget);
    expect(
      tester
          .widget<CharacterEditDialog>(find.byType(CharacterEditDialog))
          .characterId,
      'c1',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('character-name-field')),
          )
          .controller
          ?.text,
      '行者',
    );
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
