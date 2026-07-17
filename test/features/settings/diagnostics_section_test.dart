// DiagnosticsSection widget 测试：打开日志目录 / 导出流程成败（LB-18）。
import 'dart:async';
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

  /// 置入后 exportBundle 卡在 gate 上（busy 防重入观测）。
  Completer<void>? gate;

  @override
  Future<void> exportBundle({required String targetPath}) async {
    exports.add(targetPath);
    final g = gate;
    if (g != null) await g.future;
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
  String? lastSuggested;

  setUp(() {
    opener = _SpyFolderOpener();
    service = _FakeBundleService();
    toast = _RecordingToast();
    lastSuggested = null;
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
          saveLocationPickerProvider.overrideWithValue((suggested) async {
            lastSuggested = suggested;
            return pickedPath;
          }),
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
    // clock → diagnosticsBundleFileName → picker 接线（评审 P3-4）。
    expect(
      lastSuggested,
      matches(RegExp(r'^inkframe-diagnostics-\d{4}-\d{2}-\d{2}-\d{6}\.zip$')),
    );
  });

  testWidgets('busy 防重入：导出在途二次点击不产生第二次调用', (tester) async {
    service.gate = Completer<void>();
    await pump(tester, pickedPath: 'C:/tmp/diag.zip');

    await tester.tap(find.text('Export diagnostics…'));
    await tester.pump();
    await tester.tap(find.text('Export diagnostics…'), warnIfMissed: false);
    await tester.pump();

    expect(service.exports, hasLength(1));
    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(toast.shown, hasLength(1));
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
