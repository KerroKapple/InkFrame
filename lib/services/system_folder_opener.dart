// SystemFolderOpener：FolderOpener 的落地——按平台调系统文件浏览器打开目录。
//
//   - Windows：explorer <path>
//   - macOS：  open <path>
//
// 复用注入的 ProcessRunner（便于单测捕获命令行）。刻意不校验 exitCode——
// Windows 的 explorer 即便成功也常返回非 0，据此判失败会误报。
import 'dart:io';

import '../core/interfaces/folder_opener.dart';
import '../core/interfaces/process_runner.dart';

class SystemFolderOpener implements FolderOpener {
  const SystemFolderOpener(this._runner);

  final ProcessRunner _runner;

  @override
  Future<void> open(String path) async {
    final String executable = Platform.isWindows ? 'explorer' : 'open';
    await _runner.run(executable, <String>[path]);
  }
}
