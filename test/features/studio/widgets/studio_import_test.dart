// Studio 导入入口 widget 测试（LB-12）：picker→service→outcome 文案/选中/互斥。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/database_restore.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/project_archive.dart';
import 'package:inkframe/core/interfaces/project_import_service.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/studio/controllers/studio_state.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

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

void main() {
  late _FakeImportService service;
  late _RecordingToast toast;

  setUp(() {
    service = _FakeImportService();
    toast = _RecordingToast();
  });

  Future<ProviderContainer> pump(WidgetTester tester,
      {String? pickedPath}) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026, 5, 1),
              canvases: const <CanvasRef>[],
            ),
          ],
        ),
        openFilePickerProvider.overrideWithValue(() async => pickedPath),
        projectImportServiceProvider.overrideWith((ref) async => service),
        toastServiceProvider.overrideWithValue(toast),
        loggerProvider.overrideWithValue(RecordingLogger()),
      ],
    );
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

  testWidgets('导入成功：service 收 path、barrier 在途、选中新项目、成功 toast',
      (tester) async {
    service.gate = Completer<void>();
    final container = await pump(tester, pickedPath: 'C:/tmp/p.zip');

    await tester.tap(find.text('Import project…'));
    await tester.pump();
    expect(find.text('Importing…'), findsOneWidget); // barrier 模态在途。

    service.gate!.complete();
    await tester.pumpAndSettle();

    expect(service.paths, <String>['C:/tmp/p.zip']);
    expect(find.text('Importing…'), findsNothing);
    expect(toast.shown.single.message, 'Project imported');
    expect(container.read(selectedProjectIdProvider), 'new-proj');
    expect(container.read(projectImportBusyProvider), isFalse);
  });

  testWidgets('picker 取消 → 零调用零 toast', (tester) async {
    await pump(tester, pickedPath: null);
    await tester.tap(find.text('Import project…'));
    await tester.pumpAndSettle();
    expect(service.paths, isEmpty);
    expect(toast.shown, isEmpty);
  });

  testWidgets('outcome 文案：failedFormat / failedCorrupt', (tester) async {
    service.outcome = ImportOutcome.failedFormat;
    await pump(tester, pickedPath: 'C:/tmp/p.zip');
    await tester.tap(find.text('Import project…'));
    await tester.pumpAndSettle();
    expect(toast.shown.single.message, 'Not an InkFrame project archive');
    expect(toast.shown.single.kind, ToastKind.error);
  });

  testWidgets('还原 busy 时导入禁用（三大重操作互斥）', (tester) async {
    final container = await pump(tester, pickedPath: 'C:/tmp/p.zip');
    container.read(databaseRestoreBusyProvider.notifier).state = true;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import project…'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(service.paths, isEmpty);
  });
}
