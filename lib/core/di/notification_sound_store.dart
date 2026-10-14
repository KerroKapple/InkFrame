// 自定义提示音的存取 DI + 选文件 seam（设置 › 常规 › 通知）。
//
// 存取：app-scoped，文件落在 `<root>/config/sounds/`（appPathsProvider）。
// 选文件：与 openFilePickerProvider（project_archive.dart）同一做法——生产走 file_selector，
// widget 测试 override 成返回固定路径 / null。类型组的文案与扩展名由调用方给：文案要过
// l10n，扩展名白名单在 features 层，这一层两样都不该认识。
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/file_notification_sound_store.dart';
import '../interfaces/notification_sound_store.dart';
import 'logger.dart';
import 'paths.dart';

final notificationSoundStoreProvider = Provider<NotificationSoundStore>(
  (ref) => FileNotificationSoundStore(
    paths: ref.watch(appPathsProvider),
    logger: ref.watch(loggerProvider),
  ),
  name: 'notificationSoundStoreProvider',
);

/// 选一个音频文件：返回绝对路径，用户取消返回 null。
typedef NotificationSoundFilePicker = Future<String?> Function(
  String typeLabel,
  List<String> extensions,
);

final notificationSoundFilePickerProvider =
    Provider<NotificationSoundFilePicker>(
  (ref) => (String typeLabel, List<String> extensions) async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: typeLabel, extensions: extensions),
      ],
    );
    return file?.path;
  },
  name: 'notificationSoundFilePickerProvider',
);
