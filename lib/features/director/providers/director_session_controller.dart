// DirectorSessionController：导演会话的唯一写入口（按会话 id）。
//
// 模型轮次（split）走 DirectorStepRunner：script_submitted → model_request(s) →
// model_response(s) → storyboard_proposed / model_failed。
// 人工命令（edit / reject / confirm）只写 human_* 事件，不占模型轮次、不调模型。
// 分叉：每次重拆都从当前分支上最近一件 human_confirmed（没有就是空根）分出新枝，
// 驳回意见跟着新枝的 script_submitted 进下一次请求；确认过的结果不受影响。
//
// 状态除「正在跑」外全部由日志派生；控制器被回收（对话框关了）后，在途的一轮照样把
// 模型可见的东西写进日志，只是不再更新状态。
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/director_keys.dart';
import '../../../core/db/columns.dart';
import '../../../core/di/anthropic.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/anthropic_client.dart';
import '../../../core/interfaces/director_repository.dart';
import '../../../core/models/director.dart';
import '../../storyboard/models/shot_draft.dart';
import '../../storyboard/providers/script_import_controller.dart';
import '../log/director_log.dart';
import '../log/director_payloads.dart';
import '../pipeline/director_step.dart';
import '../pipeline/director_step_runner.dart';
import '../steps/storyboard/storyboard_step.dart';
import 'director_session_state.dart';

final directorSessionControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DirectorSessionController, DirectorSessionState, String>(
  DirectorSessionController.new,
  name: 'directorSessionControllerProvider',
);

class DirectorSessionController
    extends AutoDisposeFamilyAsyncNotifier<DirectorSessionState, String> {
  static const StoryboardStep _step = StoryboardStep();

  late DirectorRepository _repo;
  late AnthropicClient _client;
  bool _disposed = false;

  DirectorSession? _session;
  DirectorLog _log = DirectorLog(const <DirectorEvent>[]);
  int? _head;
  DirectorCancelToken? _running;
  DirectorStepRunner? _runner;

  @override
  Future<DirectorSessionState> build(String sessionId) async {
    ref.onDispose(() => _disposed = true);
    _client = ref.watch(anthropicClientProvider);
    _repo = await ref.watch(directorRepositoryProvider.future);
    final DirectorSession? session = await _repo.findSession(sessionId);
    if (session == null) {
      throw const LocalIOError(extra: <String, Object?>{'reason': 'session_not_found'});
    }
    _session = session;
    _log = DirectorLog(await _repo.listEvents(sessionId));
    _head = _log.latestSeq;
    return _derive();
  }

  DirectorSessionState get _current => state.requireValue;

  DirectorSessionState _derive() =>
      DirectorSessionState.fromLog(_session!, _log, head: _head);

  void _publish(DirectorSessionState s) {
    if (!_disposed) state = AsyncData<DirectorSessionState>(s);
  }

  /// 不改链头地刷新（日志多了别的分支上的事件）；另一轮在跑就保持 running。
  void _refresh() => _publish(_running != null ? _derive().running() : _derive());

  Future<DirectorEvent> _append(
    DirectorEventKind kind, {
    int? parentSeq,
    Map<String, Object?> payload = const <String, Object?>{},
    String? contentLanguage,
    DirectorSetting? setting,
  }) async {
    final DirectorEvent e = await _repo.appendEvent(
      arg,
      kind: kind,
      parentSeq: parentSeq,
      payload: payload,
      contentLanguage: contentLanguage,
      setting: setting,
    );
    _log = _log.append(e);
    if (contentLanguage != null || setting != null) {
      _session = _session!.copyWith(
        contentLanguage: contentLanguage,
        setting: setting,
        updatedAt: e.createdAt,
      );
    }
    return e;
  }

  /// 拆（或重拆）[text]。当前有提案 ⇒ 先记一件 human_rejected（[feedback] 是意见，可空）。
  /// 结束时状态是 proposed / failed / idle（被取消）。
  Future<void> split(String text, {String feedback = ''}) async {
    final DirectorSessionState cur = _current;
    if (cur.phase == DirectorPhase.running) return;
    final String note = feedback.trim();

    if (cur.phase == DirectorPhase.proposed && cur.proposalSeq != null) {
      final DirectorEvent rejected = await _append(
        DirectorEventKind.humanRejected,
        parentSeq: _head,
        payload: <String, Object?>{
          DirectorPayloadKeys.step: _step.id,
          DirectorPayloadKeys.proposalSeq: cur.proposalSeq,
          DirectorPayloadKeys.reason: note,
        },
      );
      _head = rejected.seq;
    }
    final DirectorEvent? previousInput = _log.lastOnPath(_head, DirectorEventKind.scriptSubmitted);
    final List<String> feedbackSoFar = <String>[
      if (previousInput != null) ...scriptOf(previousInput).feedback,
      if (note.isNotEmpty) note,
    ];
    final int? forkPoint = _log.lastOnPath(_head, DirectorEventKind.humanConfirmed)?.seq;

    final DirectorEvent input = await _append(
      DirectorEventKind.scriptSubmitted,
      parentSeq: forkPoint,
      payload: scriptSubmittedPayload(step: _step.id, text: text, feedback: feedbackSoFar),
    );
    _head = input.seq;

    final DirectorCancelToken token = DirectorCancelToken();
    final DirectorStepRunner runner = DirectorStepRunner(client: _client, append: _append);
    _running = token;
    _runner = runner;
    _publish(_derive().running());

    final DirectorRunOutcome<Object?> outcome;
    try {
      outcome = await runner.run(
        _step,
        session: _session!,
        log: _log,
        inputSeq: input.seq,
        cancel: token,
      );
    } on InkError catch (e) {
      // 连 model_failed 都没写进去（日志写失败）：只在界面上报错，日志保持原样。
      if (token.isCancelled) return _refresh();
      _running = null;
      _runner = null;
      _publish(_derive().failed(e.code));
      return;
    }
    // 取消时已经记过 model_failed；迟到的回应只进账（用量），不出提案。
    if (token.isCancelled) return _refresh();
    _running = null;
    _runner = null;
    _head = switch (outcome) {
      DirectorRunProposed(:final DirectorEvent event) => event.seq,
      DirectorRunFailed(:final DirectorEvent event) => event.seq,
      DirectorRunCancelled() => _head,
    };
    _publish(_derive());
  }

  /// 取消在途的一轮：结果丢弃，当下记 model_failed(cancelled_by_user)。
  Future<void> cancel() async {
    final DirectorCancelToken? token = _running;
    final DirectorStepRunner? runner = _runner;
    if (token == null || runner == null) return;
    token.cancel();
    _running = null;
    _runner = null;
    final DirectorEvent failed = await _append(
      DirectorEventKind.modelFailed,
      parentSeq: runner.head,
      payload: modelFailedPayload(step: _step.id, error: const CancelledError.byUser()),
    );
    _head = failed.seq;
    _publish(_derive());
  }

  /// 人工改识别出的语言 / 设定：记 human_edited 并写回会话。与当前提案相同 ⇒ 不记。
  Future<void> edit({required String contentLanguage, required DirectorSetting setting}) async {
    final DirectorSessionState cur = _current;
    final proposal = cur.proposal;
    if (cur.phase != DirectorPhase.proposed || proposal == null) return;
    final String lang = contentLanguage.trim();
    if (lang == proposal.contentLanguage && setting == proposal.setting) return;
    final DirectorEvent e = await _append(
      DirectorEventKind.humanEdited,
      parentSeq: _head,
      payload: <String, Object?>{
        DirectorPayloadKeys.step: _step.id,
        DirectorPayloadKeys.proposalSeq: cur.proposalSeq,
        DirectorPayloadKeys.contentLanguage: lang,
        DirectorPayloadKeys.setting: setting.toJson(),
      },
      contentLanguage: lang,
      setting: setting,
    );
    _head = e.seq;
    _publish(_derive());
  }

  /// 「创建镜头」：human_confirmed → 落画布（走 ScriptImportController.importDrafts）→
  /// applied_to_canvas。返回建出的节点 id；落画布失败抛 InkError（确认已入日志，可再点一次）。
  Future<List<String>> confirm({Offset origin = Offset.zero}) async {
    final DirectorSessionState cur = _current;
    final proposal = cur.proposal;
    if (cur.phase != DirectorPhase.proposed || proposal == null) return const <String>[];
    final ShotChainWriter writer = _ImportWriter(
      ref.read(scriptImportControllerProvider(_session!.canvasId)),
      origin,
    );
    final DirectorEvent confirmed = await _append(
      DirectorEventKind.humanConfirmed,
      parentSeq: _head,
      payload: <String, Object?>{
        DirectorPayloadKeys.step: _step.id,
        DirectorPayloadKeys.proposalSeq: cur.proposalSeq,
      },
    );
    _head = confirmed.seq;
    final List<String> ids = await _step.apply(proposal, writer);
    final DirectorEvent applied = await _append(
      DirectorEventKind.appliedToCanvas,
      parentSeq: _head,
      payload: <String, Object?>{
        DirectorPayloadKeys.step: _step.id,
        DirectorPayloadKeys.nodeIds: ids,
      },
    );
    _head = applied.seq;
    _publish(_derive());
    return ids;
  }
}

class _ImportWriter implements ShotChainWriter {
  _ImportWriter(this._controller, this._origin);

  final ScriptImportController _controller;
  final Offset _origin;

  @override
  Future<List<String>> writeShotChain(List<ShotDraft> drafts) =>
      _controller.importDrafts(drafts, origin: _origin);
}

/// 新开一次导演会话（AI 拆分第一次点「开始拆分」时）。
final directorSessionStarterProvider = Provider<DirectorSessionStarter>(
  DirectorSessionStarter.new,
  name: 'directorSessionStarterProvider',
);

class DirectorSessionStarter {
  DirectorSessionStarter(this._ref);

  final Ref _ref;

  /// 在 [canvasId] 所属项目下建会话，返回会话 id。
  Future<String> start(String canvasId) async {
    final canvas = await (await _ref.read(canvasRepositoryProvider.future)).findById(canvasId);
    final Object? projectId = canvas?[CanvasCol.projectId];
    if (projectId == null) {
      throw const LocalIOError(extra: <String, Object?>{'reason': 'canvas_not_found'});
    }
    final DirectorRepository repo = await _ref.read(directorRepositoryProvider.future);
    final DirectorSession s =
        await repo.createSession(projectId: projectId.toString(), canvasId: canvasId);
    return s.id;
  }
}
