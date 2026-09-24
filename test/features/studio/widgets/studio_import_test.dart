// LB-12 导入流：入口有两处——标签栏「导入项目包」（有项目时，在壳里）与零项目空态的「Import project…」。
// 两处走同一条 runProjectImportFlow（审计 2026-08-31 P0-3），同一把 busy 互斥锁。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/database_restore.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/project_archive.dart';
import 'package:inkframe/core/interfaces/project_import_service.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/widgets/shell_tab_bar.dart';
import 'package:inkframe/features/studio/controllers/studio_state.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_ghost_button.dart';

import '../../../_harness/shell_app.dart';
import '../../../helpers/recording_logger.dart';

class _FakeImportService implements ProjectImportService {
  final List<String> paths = [];
  ImportOutcome outcome = ImportOutcome.imported;
  Completer<void>? gate;

  @override
  Future<ImportResult> importArchive({required String zipPath}) async {
    paths.add(zipPath);
    final g = gate;
    if (g != null) await g.future;
    return ImportResult(
      outcome: outcome,
      newProjectId: outcome == ImportOutcome.imported ? 'new-proj' : null,
    );
  }
}

class _RecordingToast implements ToastService {
  final List<({String message, ToastKind kind})> shown = [];

  @override
  void show(String message, {ToastKind kind = ToastKind.info}) {
    shown.add((message: message, kind: kind));
  }
}

List<ProjectWithCanvases> get _oneProject => <ProjectWithCanvases>[
      ProjectWithCanvases(
        id: 'p1',
        name: 'Alpha',
        createdAt: DateTime.utc(2026, 5, 1),
        canvases: const <CanvasRef>[],
      ),
    ];

void main() {
  late _FakeImportService service;
  late _RecordingToast toast;

  setUp(() {
    service = _FakeImportService();
    toast = _RecordingToast();
  });

  List<Override> overrides({String? pickedPath, List<ProjectWithCanvases> projects = const []}) => [
        workspaceProjectsProvider.overrideWith((_) async => projects),
        openFilePickerProvider.overrideWithValue(() async => pickedPath),
        projectImportServiceProvider.overrideWith((ref) async => service),
        toastServiceProvider.overrideWithValue(toast),
        loggerProvider.overrideWithValue(RecordingLogger()),
      ];

  /// 有项目：入口在壳的标签栏「导入项目包」——整壳里跑。
  Future<ProviderContainer> pumpShell(WidgetTester tester, {String? pickedPath}) async {
    final paths = await setupTempPaths(tester, 'ink_studio_import_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(),
      extraOverrides: overrides(pickedPath: pickedPath, projects: _oneProject),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }
    return readShellContainer(tester);
  }

  /// 零项目：空态卡片里的「Import project…」，只 pump Studio 屏。
  Future<ProviderContainer> pumpStudio(WidgetTester tester, {String? pickedPath}) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(overrides: overrides(pickedPath: pickedPath));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapImportPackage(WidgetTester tester) async {
    await tester.tap(find.byKey(ShellTabBar.importPackageKey));
    await tester.pump();
  }

  testWidgets('标签栏导入成功：service 收 path、barrier 在途、选中新项目、成功 toast', (tester) async {
    service.gate = Completer<void>();
    final container = await pumpShell(tester, pickedPath: 'C:/tmp/p.zip');

    await tapImportPackage(tester);
    expect(find.text('Importing…'), findsOneWidget); // barrier 模态在途。

    service.gate!.complete();
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(service.paths, <String>['C:/tmp/p.zip']);
    expect(find.text('Importing…'), findsNothing);
    expect(toast.shown.single.message, 'Project imported');
    expect(container.read(selectedProjectIdProvider), 'new-proj');
    expect(container.read(projectImportBusyProvider), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('picker 取消 → 零调用零 toast', (tester) async {
    await pumpShell(tester, pickedPath: null);
    await tapImportPackage(tester);
    await tester.pump();
    expect(service.paths, isEmpty);
    expect(toast.shown, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('outcome 文案：failedFormat', (tester) async {
    service.outcome = ImportOutcome.failedFormat;
    await pumpShell(tester, pickedPath: 'C:/tmp/p.zip');
    await tapImportPackage(tester);
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(toast.shown.single.message, 'Not an InkFrame project archive');
    expect(toast.shown.single.kind, ToastKind.error);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('还原 busy 时标签栏导入禁用（三大重操作互斥）', (tester) async {
    final container = await pumpShell(tester, pickedPath: 'C:/tmp/p.zip');
    container.read(databaseRestoreBusyProvider.notifier).state = true;
    await tester.pump();

    await tapImportPackage(tester);
    await tester.pump();
    expect(service.paths, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('零项目空态也能看到并使用 Import project（回归 2026-08-31 审计 P0）',
      (tester) async {
    service.gate = Completer<void>();
    final container = await pumpStudio(tester, pickedPath: 'C:/tmp/p.zip');

    expect(find.text('Import project…'), findsOneWidget);
    await tester.tap(find.text('Import project…'));
    await tester.pump();
    expect(find.text('Importing…'), findsOneWidget);

    service.gate!.complete();
    await tester.pumpAndSettle();

    expect(service.paths, <String>['C:/tmp/p.zip']);
    expect(toast.shown.single.message, 'Project imported');
    expect(container.read(selectedProjectIdProvider), 'new-proj');
  });

  testWidgets('零项目空态：还原 busy 时导入按钮同样禁用（与标签栏同一把互斥锁）',
      (tester) async {
    final container = await pumpStudio(tester, pickedPath: 'C:/tmp/p.zip');
    container.read(databaseRestoreBusyProvider.notifier).state = true;
    await tester.pumpAndSettle();

    final btn = tester.widget<InkGhostButton>(
      find.widgetWithText(InkGhostButton, 'Import project…'),
    );
    expect(btn.onPressed, isNull, reason: '还原在途时空态导入按钮必须禁用');

    await tester.tap(find.text('Import project…'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(service.paths, isEmpty);
  });
}
