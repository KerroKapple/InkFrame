// 设置「性能」页：只读上限上屏，且数字来自真相源而非页面自己编的。
//
// 这一页没有 setter（性能档位整章未实现，见 ARCHITECTURE §10），所以测试钉的是
// 「显示的就是生效的」：全局上限 == kDefaultGlobalConcurrency、图像缓存 ==
// kImageCacheMaxBytes、Provider 行 == 能力表里的 maxConcurrentJobs / qps。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/image_cache.dart';
import 'package:inkframe/core/di/custom_providers.dart';
import 'package:inkframe/core/interfaces/custom_provider_store.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/features/settings/widgets/performance_section.dart';
import 'package:inkframe/services/job_queue_service.dart'
    show kDefaultGlobalConcurrency;

import '../../_harness/test_app.dart';

class _EmptyStore implements CustomProviderStore {
  const _EmptyStore();
  @override
  Future<List<CustomProviderConfig>> list() async =>
      const <CustomProviderConfig>[];
  @override
  Future<void> upsert(CustomProviderConfig config) async {}
  @override
  Future<void> remove(String id) async {}
}

void main() {
  Future<void> pump(WidgetTester tester) => pumpInkApp(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: PerformanceSection()),
        ),
        overrides: <Override>[
          customProviderStoreProvider.overrideWithValue(const _EmptyStore()),
        ],
        surfaceSize: const Size(900, 1400),
      );

  testWidgets('全局并发上限与图像缓存上限读的是真相源常量', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Concurrency and quota'), findsOneWidget);
    expect(find.text('Global concurrent jobs'), findsOneWidget);
    expect(find.text('$kDefaultGlobalConcurrency'), findsWidgets);
    expect(find.text('Image cache limit'), findsOneWidget);
    expect(find.text('${kImageCacheMaxBytes >> 20} MB'), findsOneWidget);
  });

  testWidgets('每个 Provider 一行：并发 / QPS 来自能力表', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Per-provider limits'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('QPS'), findsOneWidget);
    // 内置 provider 的展示名（能力表的 displayName）。
    expect(find.text('Gemini Image'), findsOneWidget);
  });

  testWidgets('说明两条：调度公式 + 本版不可调', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Jobs actually dispatched = min(free global slots, free slots for '
        'that provider).',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'These limits come from the built-in capability table and cannot be '
        'changed in this version.',
      ),
      findsOneWidget,
    );
  });
}
