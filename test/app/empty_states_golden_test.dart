// ON-5 空态/错误态 golden：Studio empty / Studio error / Canvas empty /
// Gallery empty / Settings 五屏基线入 CI 防回归。
//
// 基线存在才跑（_goldensPresent），否则 skip；基线只在 canonical ubuntu
// （update-goldens.yml workflow_dispatch）生成提交——详见 node_card_golden_test。
// 确定性约束：Settings 的 DB 路径文案会进像素——appPaths 钉死
// systemTemp/inkframe_golden_root（CI ubuntu 恒 /tmp）；备份列表用空 fake。
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/package_info.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/di/database_backup.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/database_backup_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../_harness/fake_batch_result.dart';
import '../_harness/fake_repositories.dart';
import '../_harness/fake_secure_storage.dart';
import '../_harness/golden_scaffold.dart';

final bool _goldensPresent =
    File('test/app/goldens/studio_empty.png').existsSync();
final bool _skipGolden = !_goldensPresent && !autoUpdateGoldenFiles;

const Size _surface = Size(1280, 800);

class _FakeFfmpegLocator implements FfmpegLocator {
  @override
  Future<String?> locate() async => 'ffmpeg';
  @override
  void invalidate() {}
}

class _EmptyBackupService implements DatabaseBackupService {
  @override
  Future<BackupOutcome> backup(BackupConnection conn) async =>
      BackupOutcome.skippedAlreadyToday;
  @override
  Future<BackupNowResult> backupNow(
    BackupConnection conn, {
    BackupKind kind = BackupKind.manual,
    String? preserve,
  }) async =>
      throw UnimplementedError();
  @override
  List<BackupFileInfo> listBackups() => const <BackupFileInfo>[];
}

void main() {
  testWidgets('Studio empty 空态基线', (tester) async {
    await pumpGoldenScene(
      tester,
      const StudioHomeScreen(),
      size: _surface,
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => const <ProjectWithCanvases>[],
        ),
        // 显式注入空 secure storage（拍板:空态含「未配 key」黄条,来源确定
        // 而非依赖测试环境插件缺失的 MissingPluginException——像素相同）。
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
      ],
    );
    await expectLater(
      find.byType(StudioHomeScreen),
      matchesGoldenFile('goldens/studio_empty.png'),
    );
  }, skip: _skipGolden);

  testWidgets('Studio error 错误态基线', (tester) async {
    await pumpGoldenScene(
      tester,
      const StudioHomeScreen(),
      size: _surface,
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => throw const LocalIOError(),
        ),
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
      ],
    );
    await expectLater(
      find.byType(StudioHomeScreen),
      matchesGoldenFile('goldens/studio_error.png'),
    );
  }, skip: _skipGolden);

  testWidgets('Canvas empty 空态基线（无画布打开）', (tester) async {
    await pumpGoldenScene(
      tester,
      const CanvasView(),
      size: _surface,
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((_) => null),
      ],
    );
    await expectLater(
      find.byType(CanvasView),
      matchesGoldenFile('goldens/canvas_empty.png'),
    );
  }, skip: _skipGolden);

  testWidgets('Gallery empty 空态基线', (tester) async {
    await pumpGoldenScene(
      tester,
      const GalleryScreen(projectId: 'p1', projectName: 'Alpha'),
      size: _surface,
      overrides: <Override>[
        canvasRepositoryProvider
            .overrideWith((_) async => InMemoryCanvasRepository()),
        nodeRepositoryProvider
            .overrideWith((_) async => InMemoryNodeRepository()),
        batchResultRepositoryProvider
            .overrideWith((_) async => FakeBatchResultRepo()),
      ],
    );
    await expectLater(
      find.byType(GalleryScreen),
      matchesGoldenFile('goldens/gallery_empty.png'),
    );
  }, skip: _skipGolden);

  testWidgets('Settings 屏基线', (tester) async {
    final AppPaths pinned = DefaultAppPaths.forRoot(
      Directory('${Directory.systemTemp.path}/inkframe_golden_root'),
    );
    await pumpGoldenScene(
      tester,
      const SettingsScreen(),
      size: _surface,
      overrides: <Override>[
        appPathsProvider.overrideWithValue(pinned),
        preferencesServiceProvider
            .overrideWithValue(InMemoryPreferencesService()),
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorage()),
        ffmpegLocatorProvider.overrideWithValue(_FakeFfmpegLocator()),
        databaseBackupServiceProvider
            .overrideWithValue(_EmptyBackupService()),
        // 版本行在折叠线下不进像素,仍显式钉死——消掉「靠插件缺失出 '—'」的
        // 隐式依赖,防未来折叠线移动引入漂移。
        packageInfoProvider.overrideWith(
          (_) async => PackageInfo(
            appName: 'InkFrame',
            packageName: 'inkframe',
            version: '0.0.0',
            buildNumber: '0',
          ),
        ),
      ],
    );
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_screen.png'),
    );
  }, skip: _skipGolden);
}
