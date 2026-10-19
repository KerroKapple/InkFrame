// 单个 config 节点「这次生成大概花多少」的唯一算法：检查器的「预估费用」行与画布底部提示词条的金额、
// 两处「生成」按钮悬停出的明细卡都从这里取（TakesCost 稿「花费预告」）。
//
// 取参口径对齐 GenerationController.submitFromConfigNode（真正发出去的那一笔）：
//   - 分辨率：type_config.resolution 解析不出 ⇒ p1080；
//   - 批量：只认 image 且 batch_size 为正整数，video 恒 1；
//   - 视频时长：duration_ms ~/ 1000。缺省时**与控制器不同**：取所选供应商 supportedDurations.first
//     （控制器缺省发 0、交给服务商默认）——对齐视频检查器 initState 的显示默认，有意为之；仍无 ⇒ 0。
// 供应商与「生成」能不能点同一条链（util/generate_gate.dart）：节点已存 > 上次使用 > 候选第一个。
//
// 算不出的三种情况写「—」，不写 $0.00：价目全为 0（自定义接口）、已存的供应商不在列表里了、
// 按秒计价却没有时长。币种只有 USD。
//
// [pending] 是检查器 / 提示词条还没落库的本地值：一律从 {...typeConfig, ...pending} 取，
// 不走 node.promptText / node.durationMs 这些只读 typeConfig 的派生 getter——不然本地改了金额不动。
//
// 纯函数，无 Flutter 依赖；文案（计价式、未知原因）在明细卡里映射。
import '../../../core/models/cost_model.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/util/generate_gate.dart';
import 'cost_estimator.dart';

/// 价格未知时的金额写法（格式量，不入 ARB）。
const String kCostUnknownMark = '—';

/// 金额算不出的原因（明细卡第三行按它取文案）。
enum NodeCostUnknown {
  /// 价目全为 0——自定义接口模板就是 PerCall(0)。
  customEndpoint,

  /// 节点存的供应商已不在能力列表里（自定义接口被删）。
  providerMissing,

  /// 按秒计价，但没有时长（节点没存、供应商也没声明可选时长）。
  noDuration,
}

/// 一个节点的估算结果 + 明细卡要用的参数。
///
/// 手写不可变值对象（只在内存里流转，不序列化）。[usd] 为 null ⇔ [unknown] 不为 null。
class NodeCostEstimate {
  const NodeCostEstimate({
    required this.providerId,
    required this.usd,
    this.unknown,
    this.costModel,
    this.batch = 1,
    this.durationSeconds = 0,
    this.resolution = Resolution.p1080,
    this.promptChars = 0,
    this.isVideo = false,
  });

  /// 实际用来估算的供应商（解析链的结果）。
  final String providerId;

  /// 估算金额（USD）；算不出时为 null。
  final double? usd;

  /// 算不出的原因；算得出时为 null。
  final NodeCostUnknown? unknown;

  /// 所选供应商的价目；供应商已不在列表里时为 null。
  final CostModel? costModel;

  /// 批量张数（video 恒 1）。
  final int batch;

  /// 视频时长（秒）；image 恒 0。
  final int durationSeconds;

  /// 计价用的分辨率。
  final Resolution resolution;

  /// 提示词字数（去首尾空白后）。
  final int promptChars;

  final bool isVideo;
}

/// [node] 这一次生成的估算。非 image / video 配置节点、或解析不出供应商 ⇒ null（不画金额）。
///
/// [lastUsedProviderId] 由调用方按节点类型取（video → lastVideoProviderId，image → lastImageProviderId），
/// 与提示词条判 Key 同口径。
NodeCostEstimate? estimateNodeCost({
  required CanvasNode node,
  required List<ProviderCapabilities> capabilities,
  String? lastUsedProviderId,
  Map<String, Object?> pending = const <String, Object?>{},
}) {
  if (node.role != NodeRole.config) return null;
  final bool isVideo = node.type == CanvasNodeType.video;
  if (!isVideo && node.type != CanvasNodeType.image) return null;

  final Map<String, Object?> tc = <String, Object?>{...node.typeConfig, ...pending};
  final Object? savedProvider = tc['provider_id'];
  final String? providerId = resolveConfigProviderId(
    savedProviderId: savedProvider is String ? savedProvider : null,
    lastUsedProviderId: lastUsedProviderId,
    candidates: configProviderCandidates(node.type, capabilities),
  );
  if (providerId == null) return null;

  final Object? prompt = tc['prompt'];
  final int promptChars = prompt is String ? prompt.trim().length : 0;

  ProviderCapabilities? caps;
  for (final ProviderCapabilities c in capabilities) {
    if (c.providerId == providerId) {
      caps = c;
      break;
    }
  }
  if (caps == null) {
    return NodeCostEstimate(
      providerId: providerId,
      usd: null,
      unknown: NodeCostUnknown.providerMissing,
      promptChars: promptChars,
      isVideo: isVideo,
    );
  }

  final Resolution resolution = _parseResolution(tc['resolution']) ?? Resolution.p1080;
  final Object? batchRaw = tc['batch_size'];
  // 批量只对图片节点生效：视频强制单张（与 GenerationController 同一处收口）。
  final int batch = (!isVideo && batchRaw is int && batchRaw > 0) ? batchRaw : 1;
  int durationSeconds = 0;
  if (isVideo) {
    final Object? durationMs = tc['duration_ms'];
    if (durationMs is int) {
      durationSeconds = durationMs ~/ 1000;
    } else if (caps.supportedDurations.isNotEmpty) {
      durationSeconds = caps.supportedDurations.first;
    }
  }

  final CostModel model = caps.costModel;
  final NodeCostUnknown? unknown;
  if (isPriceUnknown(model)) {
    unknown = NodeCostUnknown.customEndpoint;
  } else if (model is PerSecondVideo && durationSeconds <= 0) {
    unknown = NodeCostUnknown.noDuration;
  } else {
    unknown = null;
  }

  return NodeCostEstimate(
    providerId: providerId,
    usd: unknown != null
        ? null
        : estimateCostUsd(
            model,
            resolution: resolution,
            batchSize: batch,
            durationSeconds: durationSeconds,
            promptChars: promptChars,
          ),
    unknown: unknown,
    costModel: model,
    batch: batch,
    durationSeconds: durationSeconds,
    resolution: resolution,
    promptChars: promptChars,
    isVideo: isVideo,
  );
}

/// 金额展示：算不出写「—」，否则走 [formatCostUsd]（'$0.13' / '<$0.01'）。
String formatNodeCost(NodeCostEstimate e) {
  final double? usd = e.usd;
  return usd == null ? kCostUnknownMark : formatCostUsd(usd);
}

/// 多个节点的合计：[usd] 只加算得出的，[known] / [unknown] 各计数。
typedef NodeCostTotal = ({double usd, int known, int unknown});

/// 合计（批量运行 / 多选菜单的「另 N 个价格未知」用）：null 项（不是可生成的节点）不计。
NodeCostTotal sumNodeCosts(Iterable<NodeCostEstimate?> estimates) {
  double usd = 0;
  int known = 0;
  int unknown = 0;
  for (final NodeCostEstimate? e in estimates) {
    if (e == null) continue;
    final double? v = e.usd;
    if (v == null) {
      unknown++;
    } else {
      usd += v;
      known++;
    }
  }
  return (usd: usd, known: known, unknown: unknown);
}

/// 分辨率短写（明细卡「… · 720p」）。格式量，不入 ARB。
String resolutionShortLabel(Resolution r) => switch (r) {
      Resolution.p720 => '720p',
      Resolution.p1080 => '1080p',
      Resolution.k2 => '2K',
      Resolution.k4 => '4K',
    };

Resolution? _parseResolution(Object? raw) {
  if (raw is! String) return null;
  for (final Resolution r in Resolution.values) {
    if (r.name == raw) return r;
  }
  return null;
}
