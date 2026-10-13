import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/features/canvas/widgets/lane_toolbar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

// ---- fake 实现 ----

class _FakeCanvasRepo implements CanvasRepository {
  @override
  Future<List<Map<String, Object?>>> listTrashedByProject(String projectId) async =>
      const <Map<String, Object?>>[];

  @override
  Future<String> create({
    required String projectId,
    required String name,
    String baseStylePrefix = '',
    String baseStyleSuffix = '',
  }) async => 'cv';

  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      {'id': id, 'lane_direction': 'horizontal'};

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async => [];

  @override
  Future<List<Map<String, Object?>>> listByProjects(List<String> projectIds) async => [];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

class _FakeStyleLaneRepo implements StyleLaneRepository {
  @override
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = 400.0,
  }) async => 'lane-1';

  @override
  Future<Map<String, Object?>?> findById(String id) async => null;

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async => [];

  @override
  Future<int> update(String id, Map<String, Object?> patch) async => 1;

  @override
  Future<int> softDelete(String id) async => 1;

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async => 1;
}

/// 可配：读出指定方向 / 读失败；记下每次 update 的 patch。
class _ConfigurableCanvasRepo extends _FakeCanvasRepo {
  _ConfigurableCanvasRepo({this.direction = 'horizontal', this.readFails = false});
  final String direction;
  final bool readFails;
  final List<Map<String, Object?>> updates = <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    if (readFails) {
      throw const LocalIOError(extra: <String, Object?>{'op': 'findById'});
    }
    return <String, Object?>{'id': id, 'lane_direction': direction};
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    updates.add(patch);
    return 1;
  }
}

Future<void> _pumpToolbar(WidgetTester tester, CanvasRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        canvasRepositoryProvider.overrideWith((ref) async => repo),
        styleLaneRepositoryProvider.overrideWith((ref) async => _FakeStyleLaneRepo()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: const Scaffold(body: LaneToolbar(canvasId: 'cv')),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ---- 测试 ----

void main() {
  // GAP-3 评审 P3①：读不到方向时，切换键必须不可点。
  //
  // 读失败时方向回落成 horizontal，切换就恒定写 vertical。如果库里本来就是
  // vertical，用户点多少次都是"写 vertical → 读又失败 → 显示 horizontal"，
  // 永远到不了 horizontal——这个键按一个没读到的值决定往哪边翻。
  testWidgets('方向读失败 ⇒ 切换键禁用：点了不写库，tooltip 说明原因', (tester) async {
    final repo = _ConfigurableCanvasRepo(readFails: true);
    await _pumpToolbar(tester, repo);

    await tester.tap(find.text('Horizontal')); // 回落显示的那个标签
    await tester.pump();

    expect(repo.updates, isEmpty,
        reason: '读不到当前方向时按回落值去翻，可能永远翻不到用户要的那一边');
    expect(
      find.byTooltip(
        "Couldn't read the lane direction — switching is off until the canvas reloads",
      ),
      findsOneWidget,
    );
  });

  // 反向：读得到时照常可切，而且是按**读到的**值翻。
  testWidgets('方向读到 vertical ⇒ 点击写 horizontal', (tester) async {
    final repo = _ConfigurableCanvasRepo(direction: 'vertical');
    await _pumpToolbar(tester, repo);

    await tester.tap(find.text('Vertical'));
    await tester.pump();

    expect(repo.updates, hasLength(1));
    expect(repo.updates.single['lane_direction'], 'horizontal');
    expect(find.byTooltip('Toggle lane direction'), findsOneWidget);
  });
  testWidgets('LaneToolbar 渲染添加按钮和方向切换按钮', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          canvasRepositoryProvider.overrideWith(
            (ref) async => _FakeCanvasRepo(),
          ),
          styleLaneRepositoryProvider.overrideWith(
            (ref) async => _FakeStyleLaneRepo(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          home: const Scaffold(
            body: LaneToolbar(canvasId: 'cv'),
          ),
        ),
      ),
    );

    // 初始 frame 后 direction provider 异步解析，pump 等待
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 添加按钮
    expect(find.byIcon(Icons.add), findsOneWidget);

    // 方向切换：默认 horizontal → swap_horiz；异步完成后可能是 swap_horiz 或 swap_vert
    final hasSwapIcon = tester.any(
          find.byIcon(Icons.swap_horiz),
        ) ||
        tester.any(find.byIcon(Icons.swap_vert));
    expect(hasSwapIcon, isTrue);
  });

  // Lanes 稿：方向键带「横向 / 竖向」文字标签（默认横向）。
  testWidgets('方向键显示文字标签 Horizontal', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          canvasRepositoryProvider.overrideWith((ref) async => _FakeCanvasRepo()),
          styleLaneRepositoryProvider.overrideWith((ref) async => _FakeStyleLaneRepo()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          home: const Scaffold(body: LaneToolbar(canvasId: 'cv')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Horizontal'), findsOneWidget);
    expect(tester.getSize(find.byType(LaneToolbar)).height, LaneToolbar.height + 2, reason: '26 + 上下 1px 边');
  });
}
