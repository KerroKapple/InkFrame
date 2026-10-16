// 「生成」能不能点的唯一判据：检查器的生成按钮（InspectorStatusBinding）与画布底部提示词条的生成按钮共用。
//
// 两处原来各判各的：检查器看「提示词非空 + 供应商有 Key」，提示词条只看「提示词非空 + 不在途」——没配 Key 时
// 检查器的按钮是灰的，提示词条的却点得动，点下去才报「生成失败」。
//
// 判 Key 的是哪个供应商，两处也得按同一条链取（[resolveConfigProviderId]）：节点已存 > 上次使用（须仍在
// 候选里，防自定义供应商已删）> 候选第一个。候选按节点类型取（[configProviderCandidates]）：视频节点只列
// 能出视频的；图像节点列全部（与图像检查器的下拉一致）。
//
// 纯函数，无 Flutter 依赖；文案映射在调用方（检查器传进来的那两句 / 提示词条按节点类型取同一组 ARB）。
import '../../../core/models/provider_capabilities.dart';
import '../models/canvas_node.dart';

/// 「生成」点不动的原因。按就近原则分层：先看提示词，再看 Key。
enum GenerateBlockReason {
  /// 提示词为空（去掉首尾空白后）。
  emptyPrompt,

  /// 供应商没解析出来，或它没配 API Key。
  missingApiKey,
}

/// 「生成」点不动的原因；null = 可以点。
///
/// 在途（提交中 / 生成中）不在这里判：检查器在途时整块换成进度视图，提示词条自己按在途置灰——
/// 那是「这一刻正忙」，不是「这样配不能生成」。
GenerateBlockReason? generateBlockReason({
  required bool promptEmpty,
  required bool hasApiKey,
}) {
  if (promptEmpty) return GenerateBlockReason.emptyPrompt;
  if (!hasApiKey) return GenerateBlockReason.missingApiKey;
  return null;
}

/// [type] 类型的 config 节点可选的供应商（与对应检查器的下拉同一份）。
///
/// 视频：能文生视频或图生视频的；图像：全部（图像检查器的下拉本来就列全部）。
List<ProviderCapabilities> configProviderCandidates(
  CanvasNodeType type,
  List<ProviderCapabilities> all,
) {
  if (type != CanvasNodeType.video) return all;
  return all
      .where(
        (ProviderCapabilities c) =>
            c.modes.contains(GenerationMode.textToVideo) ||
            c.modes.contains(GenerationMode.imageToVideo),
      )
      .toList(growable: false);
}

/// config 节点此刻用哪个供应商：节点已存 > 上次使用（须仍在 [candidates] 里）> [candidates] 第一个。
///
/// 节点已存的不校验是否在候选里——检查器一直如此（已存的值原样显示、原样提交）。
String? resolveConfigProviderId({
  required String? savedProviderId,
  required String? lastUsedProviderId,
  required List<ProviderCapabilities> candidates,
}) {
  if (savedProviderId != null) return savedProviderId;
  if (lastUsedProviderId != null &&
      candidates.any((ProviderCapabilities c) => c.providerId == lastUsedProviderId)) {
    return lastUsedProviderId;
  }
  return candidates.isNotEmpty ? candidates.first.providerId : null;
}
