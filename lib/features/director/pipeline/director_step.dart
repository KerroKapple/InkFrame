// 导演步骤的抽象（ADR-0015）。
//
// 每一步固定走：组请求 → 写 model_request → 调用 → 写 model_response / model_failed →
// 解析成提案 → 人工关口（确认 / 改 / 驳回，本地完成、不调模型）→ 确认后 apply。
// 步骤只描述「怎么组请求、怎么读回应、怎么落画布」，不碰仓储——写日志由
// DirectorStepRunner / DirectorSessionController 负责。
import '../../../core/models/claude_message.dart';
import '../../../core/models/director.dart';
import '../../storyboard/models/shot_draft.dart';
import '../log/director_log.dart';

/// 落画布的出口：把一串草稿建成一条镜头链，返回建出的节点 id（按链序）。
/// 生产实现走 ScriptImportController.importDrafts——规则拆分与导演共用这一条建链路径。
abstract interface class ShotChainWriter {
  Future<List<String>> writeShotChain(List<ShotDraft> drafts);
}

/// 提案顺带要写回会话的字段（与提案事件同一事务）。null = 不改。
typedef DirectorSessionPatch = ({String? contentLanguage, DirectorSetting? setting});

abstract class DirectorStep<P> {
  const DirectorStep();

  /// 步骤 id（英文常量），写进每件事件的 payload.step。
  String get id;

  /// 解析成功后写的提案事件种类。
  DirectorEventKind get proposedKind;

  /// 只靠 [session] 与 [log] 组出请求；[inputSeq] 是本轮输入事件（如 script_submitted）。
  ClaudeRequest buildRequest({
    required DirectorSession session,
    required DirectorLog log,
    required int inputSeq,
  });

  /// 读不出 ⇒ 抛 InkError（ProviderError(providerInvalidResponse)）。
  P parse(ClaudeMessage message);

  Map<String, Object?> encodeProposal(P proposal);
  P decodeProposal(Map<String, Object?> payload);

  DirectorSessionPatch sessionPatchOf(P proposal);

  /// 确认后落画布；返回建出的节点 id。
  Future<List<String>> apply(P proposal, ShotChainWriter writer);
}
