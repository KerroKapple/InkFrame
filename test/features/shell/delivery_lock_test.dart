// 交付进行中锁住外壳（P6 §3「锁标签」）：
//   其余标签不可点 · ⌘K 不开 · 设置浮层不开 · Esc 不中断 · 结束后全部恢复。
//
// 「关窗时中断交付」在这里钉**控制器侧**（容器回收 ⇒ 取消令牌被触发）；
// 「清理半写的 EDL、媒体保留」在 test/features/export/providers/delivery_execute_test.dart
// 用真临时目录钉（那是服务侧的事）。
//
// 本文件遵外壳测试两条硬纪律：不 pumpAndSettle，只固定次数 pump。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/delivery.dart';
import 'package:inkframe/core/interfaces/delivery_service.dart';
import 'package:inkframe/core/interfaces/video_export_service.dart'
    show ExportCancelToken;
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/export/delivery_keys.dart';
import 'package:inkframe/features/export/models/delivery_plan.dart';
import 'package:inkframe/features/export/models/delivery_settings.dart';
import 'package:inkframe/features/export/providers/delivery_controller.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/shell_chrome.dart';
import 'package:inkframe/features/shell/widgets/shell_tab_bar.dart';

import '../../_harness/shell_app.dart';

/// 可控的交付服务：deliver 卡在 gate 上，直到测试放行。
class _GatedDeliveryService implements DeliveryService {
  final Completer<void> gate = Completer<void>();
  ExportCancelToken? token;
  int calls = 0;

  @override
  Future<bool> probeWritable({required String projectId}) async => true;

  @override
  Future<DeliveryOutcome> deliver({
    required String projectId,
    required List<DeliveryMediaCopy> media,
    required List<DeliveryTextFile> textFiles,
    void Function(int done, int total)? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    calls++;
    token = cancelToken;
    onProgress?.call(0, media.length);
    await gate.future;
    return DeliveryOutcome(
      outputDirRelative: 'exports',
      outputDirAbsolutePath: 'Z:/p1/exports',
      fileNames: <String>[
        for (final DeliveryMediaCopy m in media) m.fileName,
        for (final DeliveryTextFile t in textFiles) t.fileName,
      ],
      mediaCount: media.length,
    );
  }
}

DeliveryPlan _plan() => const DeliveryPlan(
      projectName: 'Alpha',
      settings: DeliverySettings.defaults,
      shots: <DeliveryShotPlan>[
        DeliveryShotPlan(
          index: 1,
          nodeId: 'n1',
          name: 'a',
          durationMs: 1000,
          durationFrames: 24,
          isPlaceholder: false,
          fileName: '001_a.mp4',
          sourceRelativePath: 'canvases/c1/videos/a.mp4',
        ),
      ],
    );

const ShellState _onSequence = ShellState(
  tab: ShellTab.sequence,
  canvasId: 'c1',
  project: ProjectRef(id: 'p1', name: 'Alpha'),
);

void main() {
  late _GatedDeliveryService service;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    service = _GatedDeliveryService();
    final AppPaths paths = await setupTempPaths(tester, 'ink_lock_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: _onSequence,
      extraOverrides: <Override>[
        deliveryServiceProvider.overrideWithValue(service),
      ],
    );
    return readShellContainer(tester);
  }

  /// 起一次交付并让它停在 gate 上。
  Future<void> startDelivery(
    WidgetTester tester,
    ProviderContainer c,
  ) async {
    unawaited(
      c
          .read(deliveryControllerProvider.notifier)
          .run(projectId: 'p1', plan: _plan()),
    );
    await tester.pump();
    await tester.pump();
    expect(c.read(deliveryBusyProvider), isTrue, reason: '交付没进在途态');
  }

  Future<void> finishDelivery(
    WidgetTester tester,
    ProviderContainer c,
  ) async {
    service.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(c.read(deliveryBusyProvider), isFalse);
  }

  testWidgets('交付中：其余标签不可点；序列标签自己照旧', (tester) async {
    final ProviderContainer c = await pump(tester);
    await startDelivery(tester, c);

    await tester.tap(find.byKey(ShellTabBar.keyOf(ShellTab.gallery)));
    await tester.pump();
    expect(
      c.read(shellControllerProvider).tab,
      ShellTab.sequence,
      reason: '交付中点画廊标签不该切走',
    );

    // 序列标签本身不锁（任务书：除序列标签本身）。
    await tester.tap(find.byKey(ShellTabBar.keyOf(ShellTab.sequence)));
    await tester.pump();
    expect(c.read(shellControllerProvider).tab, ShellTab.sequence);

    await finishDelivery(tester, c);
    await tester.tap(find.byKey(ShellTabBar.keyOf(ShellTab.gallery)));
    await tester.pump();
    expect(
      c.read(shellControllerProvider).tab,
      ShellTab.gallery,
      reason: '结束后恢复可点',
    );
  });

  testWidgets('交付中：⌘K 不开面板；结束后能开', (tester) async {
    final ProviderContainer c = await pump(tester);
    await startDelivery(tester, c);

    await sendCtrl(tester, LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.byType(CommandPaletteDialog), findsNothing);

    await finishDelivery(tester, c);
    await sendCtrl(tester, LogicalKeyboardKey.keyK);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
  });

  testWidgets('交付中：设置浮层不开；结束后能开', (tester) async {
    final ProviderContainer c = await pump(tester);
    await startDelivery(tester, c);

    await tester.tap(find.byKey(ShellChrome.settingsButtonKey));
    await tester.pump();
    expect(c.read(shellControllerProvider).overlay, isNull);
    expect(find.byType(SettingsScreen), findsNothing);

    await finishDelivery(tester, c);
    await tester.tap(find.byKey(ShellChrome.settingsButtonKey));
    await tester.pump();
    await tester.pump();
    expect(c.read(shellControllerProvider).overlay, ShellOverlay.settings);
  });

  testWidgets('交付中：Esc 不中断', (tester) async {
    final ProviderContainer c = await pump(tester);
    await startDelivery(tester, c);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.read(deliveryBusyProvider), isTrue, reason: 'Esc 不该中断交付');
    expect(service.token?.isCancelled, isFalse);

    await finishDelivery(tester, c);
  });

  testWidgets('交付中：主按钮变进度文案 + 序列标签右侧出进度环；按钮本身不可点',
      (tester) async {
    final ProviderContainer c = await pump(tester);
    await startDelivery(tester, c);

    expect(find.byKey(DeliveryKeys.progressRing), findsOneWidget);
    expect(find.text('Delivering 0/1'), findsOneWidget);
    expect(
      tester
          .widget<GestureDetector>(
            find.descendant(
              of: find.byKey(DeliveryKeys.deliverButton),
              matching: find.byType(GestureDetector),
            ),
          )
          .onTap,
      isNull,
      reason: '在途期间主按钮不可点（onTap null，不是空闭包）',
    );

    await finishDelivery(tester, c);
    expect(find.byKey(DeliveryKeys.progressRing), findsNothing);
    expect(find.text('Delivering 0/1'), findsNothing);
  });

  testWidgets('关窗（容器回收）→ 在途交付被取消', (tester) async {
    final ProviderContainer c = await pump(tester);
    await startDelivery(tester, c);

    expect(service.token?.isCancelled, isFalse);
    c.dispose();
    expect(
      service.token?.isCancelled,
      isTrue,
      reason: '不劫持关窗，但要把在途交付掐掉（半写的 EDL 由服务侧清，见 delivery_execute_test）',
    );
    service.gate.complete();
  });
}
