// FolderOpener DI —— app-scoped：在系统文件浏览器中打开目录（复用 ProcessRunner）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/system_folder_opener.dart';
import '../interfaces/folder_opener.dart';
import 'process_runner.dart';

final folderOpenerProvider = Provider<FolderOpener>(
  (ref) => SystemFolderOpener(ref.watch(processRunnerProvider)),
  name: 'folderOpenerProvider',
);
