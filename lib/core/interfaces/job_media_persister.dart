// JobMediaPersister 契约：生成产物落盘 + 批量 slot 收敛（LB-03 从 JobQueue 抽出）。
library;

import '../errors/ink_error.dart';
import '../models/generation_task.dart';

/// 取消信号：媒体落盘只需读实时取消位（ISP——不暴露完整 RunningJob）。
abstract class CancelSignal {
  bool get cancelled;
}

/// 生成产物落盘器：把 Provider 返回的 inlineBytes / remoteUrls 写到 canvas 目录，
/// 更新 node.type_config，并收敛批量 slot 终态。依赖未注入时由 null 实现全 no-op。
abstract class JobMediaPersister {
  /// 同步 Provider inlineBytes 落盘（batchSize>1 走逐 slot 部分成功语义）。
  /// 返回 null=成功/跳过；非 null=失败错误（由 orchestrator 转 job failure）。
  Future<InkError?> persistInlineBytes(
    GenerationTask task,
    List<dynamic> bytesList,
    CancelSignal running,
  );

  /// 异步 Provider remoteUrls 下载落盘（batchSize>1 走逐 slot 部分成功语义）。
  Future<InkError?> persistRemoteUrls(
    GenerationTask task,
    List<String> remoteUrls,
    CancelSignal running,
  );

  /// 单 job 收敛：该 job 下仍 generating 态 slot 一次性置 [toStatus]（绝不抛）。
  Future<void> convergeSlots(
    String jobId, {
    required String toStatus,
    String? errorCode,
  });

  /// job 落终态后收敛遗留 generating 态 slot：cancel 竞态赢→cancelled，否则→error。
  Future<void> convergeSlotsAfterTerminal(
    GenerationTask task,
    int? rows,
    CancelSignal running,
    InkError error,
  );
}
