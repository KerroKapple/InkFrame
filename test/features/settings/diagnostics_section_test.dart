// DiagnosticsSection widget 测试：打开日志目录 / 导出流程成败（LB-18）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/diagnostics.dart';
import 'package:inkframe/core/di/folder_opener.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/project_archive.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/diagnostics_bundle_service.dart';
import 'package:inkframe/core/interfaces/folder_opener.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/settings/widgets/diagnostics_section.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

class _SpyFolderOpener implements FolderOpener {
  final List<String> opened = <String>[];

  @override
  Future<void> open(String path) async => opened.add(path);
}

class _FakeBundleService implements DiagnosticsBundleService {
  final List<String> exports = <String>[];
  InkError? error;

  @override
  Future<void> exportBundle({required String targetPath}) async {
    exports.add(targetPath);
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
  late _SpyFolderOpener opener;
  late _FakeBundleService service;
  late _RecordingToast toast;
  late AppPaths paths;

  setUp(() {
    opener = _SpyFolderOpener();
    service = _FakeBundleService();
    toast = _RecordingToast();
    final tmp = Directory.systemTemp.createTempSync('ink_diag_ui_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    paths = DefaultAppPaths.forRoot(tmp);
  });

  Future<void> pump(WidgetTester tester, {String? pickedPath}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(paths),
          folderOpenerProvider.overrideWithValue(opener),
          diagnosticsBundleServiceProvider.overrideWith((ref) async => service),
          saveLocationPickerProvider
              .overrideWithValue((suggested) async => pickedPath),
          toastServiceProvider.overrideWithValue(toast),
        ],
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DiagnosticsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('打开日志目录 → FolderOpener.open(logs 路径)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Open log folder'));
    await tester.pump();
    expect(opener.opened, <String>[paths.logs.path]);
  });

  testWidgets('导出：picker 路径 → service 收到 + 成功 toast', (tester) async {
    await pump(tester, pickedPath: 'C:/tmp/diag.zip');
    await tester.tap(find.text('Export diagnostics…'));
    await tester.pumpAndSettle();

    expect(service.exports, <String>['C:/tmp/diag.zip']);
    expect(toast.shown.single.message, 'Diagnostics exported');
    expect(toast.shown.single.kind, ToastKind.success);
  });

  testWidgets('picker 取消 → 零调用零 toast', (tester) async {
    await pump(tester, pickedPath: null);
    await tester.tap(find.text('Export diagnostics…'));
    await tester.pumpAndSettle();
    expect(service.exports, isEmpty);
    expect(toast.shown, isEmpty);
  });

  testWidgets('service 抛 LocalIOError → 失败 toast', (tester) async {
    service.error = const LocalIOError();
    await pump(tester, pickedPath: 'C:/tmp/diag.zip');
    await tester.tap(find.text('Export diagnostics…'));
    await tester.pumpAndSettle();
    expect(toast.shown.single.message, 'Export failed');
    expect(toast.shown.single.kind, ToastKind.error);
  });
}
