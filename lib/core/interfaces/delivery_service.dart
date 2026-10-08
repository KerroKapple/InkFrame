// DeliveryService 抽象（P6 交付）：把一组文件落进 `<项目目录>/exports/`。
//
// ## 为什么这里看不见 EDL、也看不见交付计划
//
// `lib/core` 不许 import `features/`（test/quality/no_reverse_layer_import_test.dart）。
// 更重要的是职责：这个服务只会做两件事——**拷文件**、**写文本**，它不该知道
// 什么是 EDL、什么是镜头。「计划 → 要拷哪些、要写哪些」是 features/export 那层的
// 事（DeliveryController 用写出器 registry + metadata 构造器算出来）。
// 好处很直接：接上 FCPXML / 剪映草稿写出器时，本文件一个字都不用改。
//
// 取消令牌复用 [ExportCancelToken]（视频导出已有的那个）——「可取消的长活儿」
// 只该有一个概念，不为交付再造一套。
import 'video_export_service.dart' show ExportCancelToken;

/// 一个要拷进交付目录的媒体文件。
class DeliveryMediaCopy {
  const DeliveryMediaCopy({
    required this.sourceRelativePath,
    required this.fileName,
  });

  /// 源文件的**项目根**相对路径（`canvases/<canvasId>/videos/x.mp4`）。
  final String sourceRelativePath;

  /// 落在交付目录里的文件名（单层，不含目录）。
  final String fileName;
}

/// 一个要写进交付目录的文本文件（EDL / metadata.json）。
class DeliveryTextFile {
  const DeliveryTextFile({required this.fileName, required this.contents});

  final String fileName;
  final String contents;
}

/// 交付结果。
class DeliveryOutcome {
  const DeliveryOutcome({
    required this.outputDirRelative,
    required this.outputDirAbsolutePath,
    required this.fileNames,
    required this.mediaCount,
  });

  /// 项目根相对的交付目录（`exports`）。
  final String outputDirRelative;

  /// 交付目录的绝对路径——「打开文件夹」「复制路径」要用。
  final String outputDirAbsolutePath;

  /// 实际落盘的文件名，媒体在前、文本在后。
  final List<String> fileNames;

  final int mediaCount;
}

abstract class DeliveryService {
  /// 交付目录可不可写：试建目录 + 写一个探针文件再删掉。
  /// **不抛**——这是交付前检查的一条，失败就是「不可写」。
  Future<bool> probeWritable({required String projectId});

  /// 把 [media] 拷进交付目录、把 [textFiles] 写进去，返回落盘清单。
  ///
  /// 契约：
  /// - 目录已存在时**只覆盖同名文件，不清目录**（稿 §3：用户自己放进去的东西不动）。
  /// - 文本文件走 `.partial` → rename（仓库 LB-10/11/18 同款惯例）：中途失败 /
  ///   取消只留下被清掉的 `.partial`，**半写的 EDL 不会留在目录里**；
  ///   已拷完的媒体保留（稿 §3：关窗时中断交付并清理半写的 EDL，媒体文件保留）。
  /// - [onProgress] 的分母是媒体文件数（长活儿都在拷贝上）；文本写入阶段不再推进。
  /// - [cancelToken] 取消 → [CancelledError.byUser]（extra.reason='delivery_cancelled'）。
  ///
  /// 错误映射（InkError 体系）：
  /// - 源文件不存在 → LocalIOError(reason='delivery_source_missing')
  /// - 建目录 / 拷贝 / 写入失败 → LocalIOError(reason='delivery_io_failed')
  /// - 文件名非法（含目录分隔符等）→ ProviderError(invalidParameter, reason='delivery_bad_file_name')
  Future<DeliveryOutcome> deliver({
    required String projectId,
    required List<DeliveryMediaCopy> media,
    required List<DeliveryTextFile> textFiles,
    void Function(int done, int total)? onProgress,
    ExportCancelToken? cancelToken,
  });
}
