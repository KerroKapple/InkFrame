// 项目导出 DI 冒烟：service 装配正确类型、picker seam 可 override。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/package_info.dart';
import 'package:inkframe/core/di/project_archive.dart';
import 'package:inkframe/core/interfaces/project_archive_reader.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/project_archive_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeReader implements ProjectArchiveReader {
  @override
  Future<ProjectArchiveSnapshot> snapshot(String projectId) async => (
        project: null,
        canvases: const <Map<String, Object?>>[],
        nodes: const <Map<String, Object?>>[],
        edges: const <Map<String, Object?>>[],
        lanes: const <Map<String, Object?>>[],
        characters: const <Map<String, Object?>>[],
        presets: const <Map<String, Object?>>[],
        jobs: const <Map<String, Object?>>[],
        batchResults: const <Map<String, Object?>>[],
      );
}

void main() {
  test('projectArchiveServiceProvider 装配 ZipProjectArchiveService', () async {
    final container = ProviderContainer(
      overrides: [
        projectArchiveReaderProvider.overrideWith((ref) async => _FakeReader()),
        appPathsProvider.overrideWithValue(
          DefaultAppPaths.forRoot(Directory.systemTemp),
        ),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'InkFrame',
            packageName: 'inkframe',
            version: '1.2.3',
            buildNumber: '1',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final service = await container.read(projectArchiveServiceProvider.future);
    expect(service, isA<ZipProjectArchiveService>());
  });

  test('saveLocationPickerProvider 可被 override 成固定路径', () async {
    final container = ProviderContainer(
      overrides: [
        saveLocationPickerProvider.overrideWithValue(
          (suggestedName) async => 'C:/tmp/$suggestedName',
        ),
      ],
    );
    addTearDown(container.dispose);

    final picker = container.read(saveLocationPickerProvider);
    expect(await picker('demo.zip'), 'C:/tmp/demo.zip');
  });
}
