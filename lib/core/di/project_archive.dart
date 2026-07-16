// 项目导出 DI：reader/service 装配 + 保存位置选择 seam（widget 测试可 override）。
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/project_archive_reader.dart';
import '../interfaces/project_archive_service.dart';
import '../../services/project_archive_service.dart';
import '../../storage/repositories/postgres_project_archive_reader.dart';
import 'clock.dart';
import 'database.dart';
import 'package_info.dart';
import 'paths.dart';

/// 「导出到哪」的抽象：生产走 file_selector，测试 override 返回固定路径/null。
typedef SaveLocationPicker = Future<String?> Function(String suggestedName);

final saveLocationPickerProvider = Provider<SaveLocationPicker>(
  (ref) => (String suggestedName) async {
    final location = await getSaveLocation(suggestedName: suggestedName);
    return location?.path;
  },
  name: 'saveLocationPickerProvider',
);

final projectArchiveReaderProvider =
    FutureProvider<ProjectArchiveReader>((ref) async {
  final pool = await ref.watch(pgMigratedPoolProvider.future);
  return PostgresProjectArchiveReader(pool);
}, name: 'projectArchiveReaderProvider');

final projectArchiveServiceProvider =
    FutureProvider<ProjectArchiveService>((ref) async {
  final reader = await ref.watch(projectArchiveReaderProvider.future);
  final info = await ref.watch(packageInfoProvider.future);
  return ZipProjectArchiveService(
    reader: reader,
    paths: ref.watch(appPathsProvider),
    clock: ref.watch(clockProvider),
    appVersion: info.version,
  );
}, name: 'projectArchiveServiceProvider');
