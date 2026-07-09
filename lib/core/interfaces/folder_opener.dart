// FolderOpener 抽象：在系统文件浏览器中打开一个目录的最小注入点。
//
// 消费方当前为启动失败 surface（LB-09）的"打开日志目录"按钮。
// 单测注入 fake 记录调用；生产使用 SystemFolderOpener（走 ProcessRunner）。
//
// 失败语义：best-effort——底层可执行文件缺失会抛 [ProcessException]（dart:io 原生），
// 由调用方吞掉（打不开文件夹不应阻断或崩溃 UI）。
abstract class FolderOpener {
  /// 在系统文件浏览器中打开 [path] 指向的目录。
  Future<void> open(String path);
}
