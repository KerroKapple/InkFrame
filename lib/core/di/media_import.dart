// 媒体导入 DI —— app-scoped：把图片 / 视频复制进画布 imports/ 的服务 + 文件选择 seam。
//
// 文件选择 seam 给后续的「导入媒体」入口用（Ctrl U / 右键 / 更多 / ⌘K），widget 测试可 override。
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/file_media_import_service.dart';
import '../interfaces/media_import_service.dart';
import 'file_resolver.dart';
import 'logger.dart';

final mediaImportServiceProvider = Provider<MediaImportService>(
  (ref) => FileMediaImportService(
    resolver: ref.watch(fileResolverServiceProvider),
    logger: ref.watch(loggerProvider),
    imageSizeProbe: probeEncodedImageSize,
  ),
  name: 'mediaImportServiceProvider',
);

/// 「选哪些媒体文件」的抽象：返回选中文件的绝对路径；用户取消 ⇒ 空列表。
typedef MediaFilesPicker = Future<List<String>> Function();

final mediaFilesPickerProvider = Provider<MediaFilesPicker>(
  (ref) => () async {
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'media',
          extensions: <String>[...kImportImageExtensions, ...kImportVideoExtensions],
        ),
      ],
    );
    return <String>[for (final XFile f in files) f.path];
  },
  name: 'mediaFilesPickerProvider',
);
