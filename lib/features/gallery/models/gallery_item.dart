// GalleryItem：项目产物画廊单元——已生成图片/视频的只读投影。
//
// 数据源：result 节点 type_config（image_url / video_url）与 batch_results
// 成功 slot（output_url）；relativePath 为 canvas 相对路径，渲染前经
// FileResolverService 解析（PRD §12.6 相对路径契约）。
import 'package:freezed_annotation/freezed_annotation.dart';

part 'gallery_item.freezed.dart';

enum GalleryItemKind { image, video }

@freezed
abstract class GalleryItem with _$GalleryItem {
  const factory GalleryItem({
    required GalleryItemKind kind,

    /// canvas 相对路径（images/... 或 videos/...）。
    required String relativePath,

    /// 来源画布（路径解析 + caption 展示）。
    required String canvasId,
    required String canvasName,

    /// 来源节点；批量 slot 为其挂载的结果节点。
    required String nodeId,
    required DateTime createdAt,

    /// 批量 slot 来源时的槽位序号；节点主产物为 null。
    int? slotIndex,

    /// 视频时长（毫秒）；未知为 null。
    int? durationMs,
  }) = _GalleryItem;
}
