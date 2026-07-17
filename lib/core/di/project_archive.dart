// 项目导出/导入 DI：reader/writer/service 装配 + 文件选择 seam（widget 测试可 override）。
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/project_archive_reader.dart';
import '../interfaces/project_archive_service.dart';
import '../interfaces/project_import_service.dart';
import '../interfaces/project_import_writer.dart';
import '../../services/project_archive_service.dart';
import '../../services/project_import_service.dart';
import '../../storage/repositories/postgres_project_archive_reader.dart';
import '../../storage/repositories/postgres_project_import_writer.dart';
import 'clock.dart';
import 'database.dart';
import 'logger.dart';
import 'package_info.dart';
import 'paths.dart';

/// 「导出到哪」的抽象：生产走 file_selector，测试 override 返回固定路径/null。
typedef SaveLocationPicker = Future<String?> Function(String suggestedName);

/// 「从哪导入」的抽象（LB-12）：与 SaveLocationPicker 对偶。
typedef OpenFilePicker = Future<String?> Function();

final openFilePickerProvider = Provider<OpenFilePicker>(
  (ref) => () async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'zip', extensions: <String>['zip']),
      ],
    );
    return file?.path;
  },
  name: 'openFilePickerProvider',
);

/// 导入进行中（app 级——分钟级重操作，跨页守卫；LB-22 P1-2 教训）。
final projectImportBusyProvider = StateProvider<bool>(
  (ref) => false,
  name: 'projectImportBusyProvider',
);

final saveLocationPickerProvider = Provider<SaveLocationPicker>(
  (ref) => (String suggestedName) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'zip', extensions: <String>['zip']),
      ],
    );
    return location?.path;
  },
  name: 'saveLocationPickerProvider',
);

final projectArchiveReaderProvider =
    FutureProvider<ProjectArchiveReader>((ref) async {
  final pool = await ref.watch(pgMigratedPoolProvider.future);
  return PostgresProjectArchiveReader(pool);
}, name: 'projectArchiveReaderProvider');

final projectImportWriterProvider =
    FutureProvider<ProjectImportWriter>((ref) async {
  final pool = await ref.watch(pgMigratedPoolProvider.future);
  return PostgresProjectImportWriter(pool);
}, name: 'projectImportWriterProvider');

final projectImportServiceProvider =
    FutureProvider<ProjectImportService>((ref) async {
  final writer = await ref.watch(projectImportWriterProvider.future);
  return ZipProjectImportService(
    paths: ref.watch(appPathsProvider),
    writer: writer,
    logger: ref.watch(loggerProvider),
  );
}, name: 'projectImportServiceProvider');

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
