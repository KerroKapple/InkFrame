// 批量 slot 的呈现态与几何——纯函数，检查器网格与对比浮层共用同一份判定。
//
// 放在 util/ 而不是某个 widget 文件里：两个消费者互不 import（网格 import 浮层
// 是为了开浮层，反向没有依赖），判定若挂在其中一侧就会出现循环 import。
import '../../../core/constants/job_statuses.dart';
import '../models/batch_result.dart';

/// 稿画的四态。仓库的 `cancelled` 没有独立视觉，见 [batchSlotViewOf]。
enum BatchSlotView { success, promoted, error, generating }

/// slot 行 → 呈现态。
///
/// 两处收口是有意的：
///   - `cancelled` 并入 error——用户角度「这格没出图、可以重跑」与失败同构，
///     且取消时写了 `error_code = cancelled_by_user`，本地化文案现成；
///     若照 status 落到 generating 分支，会画成「生成中」并给出一个取消
///     已取消任务的死按钮。
///   - success 但 output_url 为空同样并入 error——没有产物就无从转正，
///     画成可转正的成功格等于给一个点了没反应的动作。
BatchSlotView batchSlotViewOf(BatchResult slot) {
  if (slot.status == SlotStatuses.success) {
    final String? url = slot.outputUrl;
    if (url == null || url.isEmpty) return BatchSlotView.error;
    return slot.promoted ? BatchSlotView.promoted : BatchSlotView.success;
  }
  if (slot.status == SlotStatuses.generating) return BatchSlotView.generating;
  return BatchSlotView.error;
}

/// 图区宽高比：优先用落库的真实像素尺寸，缺任一维或非正值时回落 16:9。
/// （`width`/`height` 由 XM-2 从 PNG 头解析，非 PNG / 解析失败时整列不写。）
double batchSlotAspectRatio(BatchResult slot) {
  final int? w = slot.width;
  final int? h = slot.height;
  if (w != null && h != null && w > 0 && h > 0) return w / h;
  return 16 / 9;
}

/// 该 slot 能否被转正（成功且有产物；已是当前产物的不再重复转正）。
bool batchSlotCanPromote(BatchResult slot) =>
    batchSlotViewOf(slot) == BatchSlotView.success;
