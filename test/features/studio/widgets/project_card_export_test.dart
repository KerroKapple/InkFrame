// 项目卡菜单「Export project…」（LB-11）：picker → ProjectArchiveService → 成败 toast。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/project_archive.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/project_archive_service.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/project_export_busy.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../helpers/recording_logger.dart';

class _FakeArchiveService implements ProjectArchiveService {
  final List<({String projectId, String targetPath})> calls = [];
  InkError? error;

  @override
  Future<void> exportProject({
    required String projectId,
    required String targetPath,
  }) async {
    calls.add((projectId: projectId, targetPath: targetPath));
    final e = error;
    if (e != null) throw e;
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
  late _FakeArchiveService service;
  late _RecordingToast toast;

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    String? pickedPath,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: <Override>[
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
        saveLocationPickerProvider.overrideWithValue(
          (suggestedName) async => pickedPath,
        ),
        projectArchiveServiceProvider.overrideWith((ref) async => service),
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

  Future<void> tapExport(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export project…'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    service = _FakeArchiveService();
    toast = _RecordingToast();
  });

  testWidgets('菜单导出 → service 收到 (projectId, path) + 成功 toast', (tester) async {
    final container = await pumpHome(tester, pickedPath: 'C:/tmp/Alpha.zip');
    await tapExport(tester);

    expect(service.calls, hasLength(1));
    expect(service.calls.single.projectId, 'p1');
    expect(service.calls.single.targetPath, 'C:/tmp/Alpha.zip');
    expect(toast.shown, hasLength(1));
    expect(toast.shown.single.message, 'Project exported');
    expect(toast.shown.single.kind, ToastKind.info);
    expect(container.read(projectExportBusyProvider), isFalse);
  });

  testWidgets('用户取消保存对话框 → 不调 service 不弹 toast', (tester) async {
    await pumpHome(tester, pickedPath: null);
    await tapExport(tester);

    expect(service.calls, isEmpty);
    expect(toast.shown, isEmpty);
  });

  testWidgets('service 抛 InkError → 失败 toast（error 态）+ busy 复位', (tester) async {
    service.error = const LocalIOError();
    final container = await pumpHome(tester, pickedPath: 'C:/tmp/Alpha.zip');
    await tapExport(tester);

    expect(service.calls, hasLength(1));
    expect(toast.shown, hasLength(1));
    expect(toast.shown.single.message, 'Failed to export project');
    expect(toast.shown.single.kind, ToastKind.error);
    expect(container.read(projectExportBusyProvider), isFalse);
  });
}
