// T9 脏刷新：画廊标签由「不可见 → 可见」且脏时才 invalidate 一次。
//
// 可观测量选的是 GalleryController.build 的调用次数——invalidate 的唯一可见
// 后果就是重跑一次聚合。断"文案变了"之类的间接代理在这里会漏掉"刷了但数据
// 没变"的情形。
//
// 【实测变异，逐条】
//  1. 「脏 + 上升沿 → 刷」：把 gallery_tab.dart 的 ref.invalidate(...) 那行删掉
//     ⇒ Expected: <2> Actual: <1>
//  2. 「刷完清脏」：把 ref.read(galleryDirtyProvider.notifier).clear() 那行删掉
//     ⇒ Expected: false Actual: <true>（同用例前一条断言仍绿）
//  3. 「不脏不刷」：把 `if (!ref.read(galleryDirtyProvider)) return;` 删掉
//     ⇒ Expected: <1> Actual: <2>
//  4. 「不可见不刷」：把 didUpdateWidget 的
//     `if (old.isVisible || !widget.isVisible) return;` 改成 `if (old.isVisible)
//     return;` ⇒ Expected: <1> Actual: <2>
//  5. 「脏标记 provider 必须有订阅者」：删掉 build 里的
//     `ref.watch(galleryDirtyProvider);` ⇒ Expected: true Actual: <false>
//     （它是懒的，没订阅者就没被实例化，job 成功那一刻根本没人在听）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_controller.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/gallery_dirty.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/tabs/gallery_tab.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

int _builds = 0;

/// 数 build 次数的画廊控制器——不碰任何仓储（本文件不关心聚合结果）。
class _CountingGalleryController extends GalleryController {
  @override
  Future<List<GalleryItem>> build(String projectId) async {
    _builds++;
    return const <GalleryItem>[];
  }
}

void main() {
  setUp(() => _builds = 0);

  // 外壳态里带项目：activeProjectProvider 是它的派生投影，禁止 override 投影。
  List<Override> overrides() => <Override>[
        shellControllerProvider.overrideWith(
          () => ShellNavigator(
            initial: const ShellState(
              tab: ShellTab.gallery,
              project: ProjectRef(id: 'p1', name: 'Alpha'),
            ),
          ),
        ),
        galleryControllerProvider
            .overrideWith(_CountingGalleryController.new),
      ];

  Future<void> pumpTab(
    WidgetTester tester,
    ProviderContainer container, {
    required bool visible,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GalleryTab(isVisible: visible),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void succeedOneJob(ProviderContainer container, String jobId) {
    container.read(jobsRegistryProvider.notifier).upsert(
          JobState.succeeded(
            jobId: jobId,
            providerId: 'fake',
            canvasId: 'c1',
            artifactPath: 'images/a.png',
          ),
        );
  }

  ProviderContainer newContainer(WidgetTester tester) {
    final ProviderContainer c = ProviderContainer(overrides: overrides());
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('后台生成成功 → 切回画廊时刷一次，并清脏', (tester) async {
    final ProviderContainer container = newContainer(tester);
    await pumpTab(tester, container, visible: false);
    expect(_builds, 1, reason: '前置：首次物化跑一次 build');

    succeedOneJob(container, 'j1');
    expect(
      container.read(galleryDirtyProvider),
      isTrue,
      reason: 'JobSucceeded 必须把画廊置脏——没订阅者的话这里就已经是 false',
    );
    expect(_builds, 1, reason: '前置：置脏本身不刷（标签还不可见）');

    await pumpTab(tester, container, visible: true);

    expect(_builds, 2, reason: '不可见→可见且脏 ⇒ invalidate 一次');
    expect(
      container.read(galleryDirtyProvider),
      isFalse,
      reason: '刷过就得清脏，否则每次切回画廊都白刷一次',
    );
  });

  testWidgets('没有成功的 job → 切回画廊不刷', (tester) async {
    final ProviderContainer container = newContainer(tester);
    await pumpTab(tester, container, visible: false);

    await pumpTab(tester, container, visible: true);

    expect(_builds, 1, reason: '不脏就不该刷——切标签不是刷新理由');
  });

  // 去重是正确性而不是优化：JobSucceeded 是终态，会长期留在 registry 里。
  // 不按 jobId 记账的话，任何一次 registry 变动（这里是另一条 job 入队）都会
  // 把刚清掉的脏标记重新置上 ⇒ 每次切回画廊都白刷。
  //
  // 【实测变异】gallery_dirty.dart 去掉 `_counted.add(job.jobId)` 这一半条件
  // （只留 `job is JobSucceeded`）⇒ Expected: false Actual: <true>
  testWidgets('清脏后，registry 的其它变动不会把脏标记重新置上', (tester) async {
    final ProviderContainer container = newContainer(tester);
    await pumpTab(tester, container, visible: false);
    succeedOneJob(container, 'j1');
    await pumpTab(tester, container, visible: true);
    expect(container.read(galleryDirtyProvider), isFalse, reason: '前置：已清脏');

    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.queued(
            jobId: 'j2',
            providerId: 'fake',
            canvasId: 'c1',
          ),
        );

    expect(
      container.read(galleryDirtyProvider),
      isFalse,
      reason: '一条新 job 入队不是新产物——已记账的成功 job 不该二次置脏',
    );
  });

  testWidgets('脏了但标签仍不可见 → 不刷', (tester) async {
    final ProviderContainer container = newContainer(tester);
    await pumpTab(tester, container, visible: false);
    succeedOneJob(container, 'j1');

    // 再 pump 一次仍然不可见：didUpdateWidget 会跑，但上升沿不成立。
    await pumpTab(tester, container, visible: false);

    expect(_builds, 1, reason: '后台标签不该因为脏就自己刷——刷了用户也看不见');
  });
}
