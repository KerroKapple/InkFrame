// VideoExportService 抽象：项目内视频产物的导出（M3 视频导出首切片）。
//
// 首切片仅提供顺序拼接（concat）。转码、分辨率归一、UI 入口为后续切片；
// ffmpeg 二进制不随应用打包（体积/许可评估延后），依赖系统 PATH 上的 ffmpeg。
abstract class VideoExportService {
  /// 按给定顺序拼接项目内多个视频，返回导出文件的项目相对路径
  /// （形如 `exports/<name>.mp4`，DB/UI 侧一律存相对路径）。
  ///
  /// 契约：
  /// - [inputRelativePaths] 为项目根相对路径（形如
  ///   `canvases/<canvasId>/videos/<file>.mp4`），逐一经 FileResolverService
  ///   解析并做路径安全校验；非法路径（穿越/绝对/空串等）抛 PathSecurityError。
  /// - 流拷贝（`-c copy`）不转码：要求所有输入编码参数一致，否则产物可能
  ///   损坏或不可播——转码归一是后续切片。
  /// - [outputBaseName] 为导出文件名主体（不含扩展名），必须是单层文件名段；
  ///   缺省时按 UTC 毫秒时间戳生成。同名输出会被覆盖（ffmpeg -y）。
  ///
  /// 错误映射（InkError 体系）：
  /// - 空输入列表 → ProviderError(invalidParameter, extra.reason='empty_input_list')
  /// - 输入文件不存在 → LocalIOError(extra.reason='input_not_found')
  /// - ffmpeg 不可用 → LocalIOError(extra.reason='ffmpeg_not_found')
  /// - ffmpeg 非零退出 → LocalIOError(extra.reason='ffmpeg_failed'，stderr 进
  ///   extra；已写出的半截产物会被清理)
  /// - 导出目录创建 / 临时 list 写入失败 → LocalIOError(extra.reason='export_io_failed')
  Future<String> concat({
    required String projectId,
    required List<String> inputRelativePaths,
    String? outputBaseName,
  });
}
