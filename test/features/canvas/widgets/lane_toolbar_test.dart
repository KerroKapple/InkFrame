import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';
import 'package:inkframe/features/canvas/widgets/lane_toolbar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

// ---- fake 实现 ----

class _FakeCanvasRepo implements CanvasRepository {
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

// ---- 测试 ----

void main() {
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
}
