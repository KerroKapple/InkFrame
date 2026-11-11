// 导演会话的界面状态——除「正在跑」之外，全部从事件日志派生（DirectorSessionState.fromLog）。
import 'package:flutter/foundation.dart';

import '../../../core/constants/director_keys.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/models/director.dart';
import '../log/claude_usage_ledger.dart';
import '../log/director_log.dart';
import '../log/director_payloads.dart';
import '../steps/storyboard/storyboard_proposal.dart';

enum DirectorPhase {
  /// 还没拆，或上一轮被驳回 / 取消。
  idle,

  /// 正在等模型（只存在于内存，不从日志派生）。
  running,

  /// 有一份待人工确认的提案。
  proposed,

  /// 上一轮失败（[DirectorSessionState.errorCode]）。
  failed,

  /// 已落到画布。
  applied,
}

@immutable
class DirectorSessionState {
  const DirectorSessionState({
    required this.session,
    required this.log,
    required this.head,
    required this.phase,
    this.proposal,
    this.proposalSeq,
    this.proposedScript,
    this.errorCode,
    this.appliedNodeIds = const <String>[],
  });

  final DirectorSession session;
  final DirectorLog log;

  /// 当前分支的链头；空日志 ⇒ null。
  final int? head;
  final DirectorPhase phase;

  /// 当前提案（已叠上之后的 human_edited）。
  final StoryboardProposal? proposal;
  final int? proposalSeq;

  /// 提案对应的剧本原文——与框里现在的文字不同即「过期」。
  final String? proposedScript;
  final InkErrorCode? errorCode;
  final List<String> appliedNodeIds;

  /// 本会话的 Claude 用量（全部分支，含被驳回 / 取消的轮次）。
  ClaudeUsageLedger get ledger => ClaudeUsageLedger.fromEvents(log.events);

  bool isStaleFor(String text) => proposedScript != null && proposedScript != text;

  DirectorSessionState running() => DirectorSessionState(
        session: session,
        log: log,
        head: head,
        phase: DirectorPhase.running,
        proposal: proposal,
        proposalSeq: proposalSeq,
        proposedScript: proposedScript,
      );

  /// 日志之外的失败（写日志本身失败）——只给界面看。
  DirectorSessionState failed(InkErrorCode code) => DirectorSessionState(
        session: session,
        log: log,
        head: head,
        phase: DirectorPhase.failed,
        errorCode: code,
      );

  /// 沿 [head]（缺省 = 最近一件事件）所在分支重建状态。
  factory DirectorSessionState.fromLog(
    DirectorSession session,
    DirectorLog log, {
    int? head,
  }) {
    final int? h = head ?? log.latestSeq;
    final List<DirectorEvent> path = log.pathTo(h);
    DirectorSessionState make(DirectorPhase phase, {InkErrorCode? error, List<String>? applied}) {
      final DirectorEvent? proposed = log.lastOnPath(h, DirectorEventKind.storyboardProposed);
      StoryboardProposal? proposal;
      String? script;
      if (proposed != null) {
        proposal = StoryboardProposal.fromJson(proposed.payload);
        for (final DirectorEvent e in path.where((DirectorEvent e) =>
            e.seq > proposed.seq && e.kind == DirectorEventKind.humanEdited)) {
          final Object? lang = e.payload[DirectorPayloadKeys.contentLanguage];
          proposal = proposal!.copyWith(
            contentLanguage: lang is String ? lang : null,
            setting: e.payload.containsKey(DirectorPayloadKeys.setting)
                ? DirectorSetting.fromJson(e.payload[DirectorPayloadKeys.setting])
                : null,
          );
        }
        final DirectorEvent? input = log.lastOnPath(proposed.seq, DirectorEventKind.scriptSubmitted);
        script = input == null ? null : scriptOf(input).text;
      }
      final bool live = phase == DirectorPhase.proposed;
      return DirectorSessionState(
        session: session,
        log: log,
        head: h,
        phase: phase,
        proposal: live ? proposal : null,
        proposalSeq: live ? proposed?.seq : null,
        proposedScript: live ? script : null,
        errorCode: error,
        appliedNodeIds: applied ?? const <String>[],
      );
    }

    if (path.isEmpty) return make(DirectorPhase.idle);
    final DirectorEvent last = path.last;
    switch (last.kind) {
      case DirectorEventKind.storyboardProposed:
      case DirectorEventKind.humanEdited:
      case DirectorEventKind.humanConfirmed:
        return make(DirectorPhase.proposed);
      case DirectorEventKind.modelFailed:
        final InkErrorCode code = failedCodeOf(last);
        return code == InkErrorCode.cancelledByUser
            ? make(DirectorPhase.idle)
            : make(DirectorPhase.failed, error: code);
      case DirectorEventKind.appliedToCanvas:
        final Object? ids = last.payload[DirectorPayloadKeys.nodeIds];
        return make(
          DirectorPhase.applied,
          applied: ids is List ? <String>[for (final Object? i in ids) if (i is String) i] : null,
        );
      case DirectorEventKind.scriptSubmitted:
      case DirectorEventKind.modelRequest:
      case DirectorEventKind.modelResponse:
      case DirectorEventKind.humanRejected:
        // 没跑完的一轮（应用中途退出）与被驳回的提案：都回到「可以重拆」。
        return make(DirectorPhase.idle);
    }
  }
}
