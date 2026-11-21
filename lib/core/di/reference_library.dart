// 参考库 DI —— app-scoped：读取适配器 + 选文件夹 seam + 文件夹路径 + 读出的条目。
//
// 数据流：偏好设置里的 reference_library_root → referenceLibraryRootProvider →
// referenceLibraryProvider（watch root，换文件夹即重读；非 autoDispose，同一文件夹只读一次）。
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/reference_library/ai_pose_gallery_zh_reader.dart';
import '../interfaces/reference_library_reader.dart';
import 'logger.dart';
import 'preferences.dart';

/// 读取适配器：现在只认 ai-pose-gallery-zh 格式。
final referenceLibraryReaderProvider = Provider<ReferenceLibraryReader>(
  (ref) => AiPoseGalleryZhReader(logger: ref.watch(loggerProvider)),
  name: 'referenceLibraryReaderProvider',
);

/// 「选哪个文件夹当参考库」的抽象：返回文件夹绝对路径；用户取消 ⇒ null。
typedef ReferenceFolderPicker = Future<String?> Function();

final referenceFolderPickerProvider = Provider<ReferenceFolderPicker>(
  (ref) => () => getDirectoryPath(),
  name: 'referenceFolderPickerProvider',
);

/// 当前参考库文件夹；null = 还没选。启动从偏好设置 seed，[set] 改内存态并落盘。
class ReferenceLibraryRootController extends Notifier<String?> {
  @override
  String? build() =>
      ref.read(preferencesServiceProvider).current.referenceLibraryRoot;

  /// 换成 [path]（文件夹绝对路径）：先改 state 让条目 provider 立刻重读，再写偏好设置。
  Future<void> set(String path) async {
    state = path;
    await ref.read(preferencesServiceProvider).update(
          (prefs) => prefs.copyWith(referenceLibraryRoot: path),
        );
  }
}

final referenceLibraryRootProvider =
    NotifierProvider<ReferenceLibraryRootController, String?>(
  ReferenceLibraryRootController.new,
  name: 'referenceLibraryRootProvider',
);

/// 读出的参考库：还没选文件夹 ⇒ null；否则是 reader 的结果（Loaded / NotFound）。
final referenceLibraryProvider = FutureProvider<ReferenceLibraryLoad?>(
  (ref) async {
    final String? root = ref.watch(referenceLibraryRootProvider);
    if (root == null) return null;
    return ref.watch(referenceLibraryReaderProvider).load(root);
  },
  name: 'referenceLibraryProvider',
);
