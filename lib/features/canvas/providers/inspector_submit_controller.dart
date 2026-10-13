// InspectorSubmitController — Inspector 提交状态机（按 configNodeId 分族）。
//
// 从 Image/VideoConfigInspector 抽出的共享逻辑：
//   - 四态状态机：idle / submitting / running / failure
//   - type_config 持久化（含防抖保存，prompt/shot_notes 共用同一实现）——
//     widget 不再直写 repository
//   - submit：先落最终 config，再经 GenerationController.submitFromConfigNode
//   - 失败携带结构化 InspectorSubmitError，文案由 view 层映射 ARB
//   - 自动保存失败独立发布到 inspectorAutoSaveStatusProvider（见下方注释）
//
// JobState 绑定点（agent-generation slice 落地后接线）：
//   jobStateProvider(nodeId) 可在 build 中 watch 并派生 running 进度，
//   届时 InspectorSubmitRunning.progress 接真实值。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/logger.dart';
import '../../../core/di/repositories.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/errors/ink_error.dart';
import '../../generation/generation_controller.dart';

/// 日志 module 名（英文内部常量，不 i18n）。
const String _logModule = 'inspector.autosave';

/// providerId → 是否已配置 API Key。按 providerId 缓存，
/// 替代 widget 每次 build 新建 secure-storage Future。
final inspectorHasApiKeyProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, providerId) {
    final secure = ref.watch(secureStorageServiceProvider);
    return secure.exists(SecureStorageKeys.providerApiKey(providerId));
  },
  name: 'inspectorHasApiKeyProvider',
);

/// 提交失败的结构化原因。view 层 exhaustive switch 映射 l10n，本层不产文案。
sealed class InspectorSubmitError {
  const InspectorSubmitError();
}

class InspectorMissingApiKey extends InspectorSubmitError {
  const InspectorMissingApiKey();
}

class InspectorInvalidConfig extends InspectorSubmitError {
  const InspectorInvalidConfig(this.reason);

  /// 内部诊断字符串（英文常量），经 ARB placeholder 注入展示。
  final String reason;
}

class InspectorProviderNotRegistered extends InspectorSubmitError {
  const InspectorProviderNotRegistered();
}

class InspectorInkFailure extends InspectorSubmitError {
  const InspectorInkFailure(this.error);
  final InkError error;
}

/// Inspector 提交四态。
sealed class InspectorSubmitState {
  const InspectorSubmitState();
}

class InspectorSubmitIdle extends InspectorSubmitState {
  const InspectorSubmitIdle();
}

class InspectorSubmitSubmitting extends InspectorSubmitState {
  const InspectorSubmitSubmitting();
}

class InspectorSubmitRunning extends InspectorSubmitState {
  const InspectorSubmitRunning({this.progress});

  /// [0.0, 1.0]；null 渲染 indeterminate 进度条。
  final double? progress;
}

class InspectorSubmitFailure extends InspectorSubmitState {
  const InspectorSubmitFailure(this.error);
  final InspectorSubmitError error;
}

/// 自动保存（type_config 防抖/即时落盘）的可见状态。
///
/// 为什么不并进 [InspectorSubmitState]：保存失败不是提交失败。塞进提交四态会让
/// 「生成」按钮当场变成「重试生成」，把「这一笔改动没存上」和「这一次生成失败」
/// 混成一件事；而且自动保存的正确动作是「重试保存」，不是重新生成。
sealed class InspectorAutoSaveState {
  const InspectorAutoSaveState();
}

/// 没有未落盘的更改（含失败后被新输入覆盖、或重试成功而自愈的情形）。
class InspectorAutoSaveClean extends InspectorAutoSaveState {
  const InspectorAutoSaveClean();
}

/// 写失败、自动重试还没用完。[attempt] = 已失败次数（1 起）。
class InspectorAutoSaveRetrying extends InspectorAutoSaveState {
  const InspectorAutoSaveRetrying(this.attempt);
  final int attempt;
}

/// 自动重试用尽，等用户的明确动作（[InspectorSubmitController.retryUnsaved]）。
/// [error] 原样带上来，由 view 层映射 ARB 文案——本层不产用户文案。
class InspectorAutoSaveFailed extends InspectorAutoSaveState {
  const InspectorAutoSaveFailed(this.error);
  final InkError error;
}

/// 自动保存状态的发布端：只由 [InspectorSubmitController] 单向写入，UI 只读。
///
/// 独立 provider 而非控制器状态的一部分，是因为 Notifier 只有一份 state，而这
/// 两件事必须能分别渲染（见 [InspectorAutoSaveState] 的注释）。生命周期挂在
/// 控制器上：控制器在有未保存内容期间自己 keepAlive，发布端随之存活。
final inspectorAutoSaveStatusProvider = AutoDisposeNotifierProviderFamily<
    InspectorAutoSaveStatus, InspectorAutoSaveState, String>(
  InspectorAutoSaveStatus.new,
  name: 'inspectorAutoSaveStatusProvider',
);

class InspectorAutoSaveStatus
    extends AutoDisposeFamilyNotifier<InspectorAutoSaveState, String> {
  @override
  InspectorAutoSaveState build(String configNodeId) =>
      const InspectorAutoSaveClean();

  /// 单向发布口：唯一写入者是同 node 的 [InspectorSubmitController]。
  void publish(InspectorAutoSaveState next) => state = next;
}

final inspectorSubmitControllerProvider = AutoDisposeNotifierProviderFamily<
    InspectorSubmitController, InspectorSubmitState, String>(
  InspectorSubmitController.new,
  name: 'inspectorSubmitControllerProvider',
);

class InspectorSubmitController
    extends AutoDisposeFamilyNotifier<InspectorSubmitState, String> {
  Timer? _debounce;
  KeepAliveLink? _debounceKeepAlive;

  /// autoDispose family 下，await 期间 provider 可能已被回收——之后再触 ref
  /// 会抛 StateError。沿用画布各控制器的口径：await 之后的 ref 访问先查本标志。
  bool _alive = false;

  /// 自动重试计时器（退避等待）。
  Timer? _retry;

  /// 有未落盘内容期间挂起 autoDispose 的凭据。
  KeepAliveLink? _unsavedKeepAlive;

  /// 最近一次写失败、且此后没有被成功写入覆盖过的键值（每键保留最新值）。
  /// 空 = 全部落盘。重试写的就是这张表。
  final Map<String, Object?> _unsaved = <String, Object?>{};

  /// 本次失败回合里已失败的次数。成功落盘即归零。
  int _failedAttempts = 0;

  /// 写入串行链的尾巴：同一节点的 type_config 写入**落库顺序 = 发起顺序**。
  ///
  /// 为什么必须排队而不是「提交时取消在途写入」（BOARD 第 196 行）：计时器已
  /// 触发、自动保存正 await 仓储时，那条 UPDATE 已经发出去了，取消不了。若此刻
  /// submit 把终稿并发下发，两条 UPDATE 的到达顺序没人保证——旧 patch 晚到就把
  /// 终稿 prompt 盖掉。不并发，顺序就是确定的；代价是 submit 最多多等一个
  /// 在途写入的往返。
  ///
  /// 链永不断：[_serialized] 的闸在 finally 里 complete，所以某一笔写入失败
  /// （或抛非 InkError）都不会把后续写入永久挂死；错误照常冒给那一笔的调用方。
  Future<void> _writeTail = Future<void>.value();

  static const debounceDuration = Duration(milliseconds: 500);

  /// 自动重试上限（首次尝试之外再试几次）。
  ///
  /// 为什么是 2 次、退避 400ms / 1200ms：自动保存失败的现实主因是嵌入式
  /// PostgreSQL 连接池换连接那一瞬（仓储层翻成 LocalIOError，亚秒级自愈），
  /// 两次退避重试刚好盖住一次重连，用户什么都不用做。封顶在 2 次则意味着
  /// 「库真的写不进去」在 ~1.6s 内就如实上屏，而不是被无限重试一直伪装成
  /// 「正在保存」——自动保存不是后台同步任务，用户正坐在那儿打字，拖越久谎越大。
  static const int maxAutoRetries = 2;
  static const List<Duration> retryBackoff = <Duration>[
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
  ];

  @override
  InspectorSubmitState build(String configNodeId) {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _cancelPendingDebounce();
      _retry?.cancel();
      _retry = null;
      _unsavedKeepAlive?.close();
      _unsavedKeepAlive = null;
    });
    // 只订阅、不读值：把状态发布端挂在本控制器的生命周期上。控制器在有未保存
    // 内容期间自己 keepAlive，于是用户切到别的节点再切回来，失败行与「重试」
    // 按钮还在；否则发布端会因为没人看而被 autoDispose 复位成 Clean——等于再
    // 撒一次「已保存」的谎，而且那份 patch 再没人能重试。
    // 用 listen 而不是 watch：watch 会让本控制器在每次发布时重建，把提交状态机
    // 一起清零。
    ref.listen<InspectorAutoSaveState>(
      inspectorAutoSaveStatusProvider(configNodeId),
      (_, _) {},
    );
    return const InspectorSubmitIdle();
  }

  bool get isBusy =>
      state is InspectorSubmitSubmitting || state is InspectorSubmitRunning;

  /// 把 [body] 排到写入链尾。排队号在本方法同步段就取好（调用方在第一个
  /// await 之前就进了队），所以队列顺序严格等于发起顺序。
  Future<void> _serialized(Future<void> Function() body) async {
    final Future<void> previous = _writeTail;
    final Completer<void> gate = Completer<void>();
    _writeTail = gate.future;
    await previous;
    try {
      await body();
    } finally {
      gate.complete();
    }
  }

  /// 取消挂起的防抖计时器并释放其 keepAlive（不落盘）。
  void _cancelPendingDebounce() {
    _debounce?.cancel();
    _debounce = null;
    _debounceKeepAlive?.close();
    _debounceKeepAlive = null;
  }

  /// 立即持久化 type_config patch。
  ///
  /// 不抛——调用方多半是 onChanged 回调（fire-and-forget）。失败不再静默：翻成
  /// [InspectorAutoSaveState] 发布给 UI，并按退避自动重试；重试用尽后把
  /// 「未保存 + 重试」留给用户（[retryUnsaved]）。
  Future<void> saveConfig(Map<String, Object?> patch) => _attemptWrite(patch);

  /// 用户点「重试」：重置退避计数，立刻再试一次未落盘的更改。
  Future<void> retryUnsaved() async {
    _retry?.cancel();
    _retry = null;
    if (_unsaved.isEmpty) {
      _markClean();
      return;
    }
    _failedAttempts = 0;
    await _attemptWrite(Map<String, Object?>.of(_unsaved));
  }

  /// 一次写入尝试的完整生命周期：挂起 autoDispose → 落盘 → 成败记账。
  ///
  /// 只接 [InkError]：仓储层已经把 PgException 统一翻成 LocalIOError，非
  /// InkError（启动失败的 DatabaseBootstrapError、不可 JSON 编码的 patch）属
  /// 启动期/编程错误，让它冒给全局错误钩子——不把「吞 InkError」换成「吞得更宽」。
  ///
  /// 整段写入期间持 keepAlive：否则切换选中节点会在 await 中途把控制器回收，
  /// 写入被静默丢掉（与 #232 修的「挂起未发射」同类，只是发生在发射之后）。
  Future<void> _attemptWrite(Map<String, Object?> patch) async {
    if (!_alive) return;
    final KeepAliveLink link = ref.keepAlive();
    try {
      await _serialized(() async {
        final nodes = await ref.read(nodeRepositoryProvider.future);
        if (!_alive) return;
        await nodes.patchTypeConfig(arg, patch);
      });
      if (!_alive) return;
      _onWriteSucceeded(patch.keys);
    } on InkError catch (e) {
      if (!_alive) return;
      _onWriteFailed(patch, e);
    } finally {
      link.close();
    }
  }

  /// 写成功记账：这些键视为已落盘。
  ///
  /// 若用户在重试在途期间又改了同一个键，那次写入会自己报自己的成败——中间
  /// 短暂显示 Clean 与正常输入路径同口径（正常路径也不显示「保存中」）。
  void _onWriteSucceeded(Iterable<String> keys) {
    if (_unsaved.isEmpty) return; // 快路径：从没失败过，不产生状态抖动
    _unsaved.removeWhere((k, _) => keys.contains(k));
    if (_unsaved.isEmpty) _markClean();
  }

  void _onWriteFailed(Map<String, Object?> patch, InkError error) {
    _unsaved.addAll(patch); // 每键保留最新值：重试写的是新值，不是旧值
    _unsavedKeepAlive ??= ref.keepAlive();
    _failedAttempts++;
    final bool exhausted = _failedAttempts > maxAutoRetries;
    _publish(exhausted
        ? InspectorAutoSaveFailed(error)
        : InspectorAutoSaveRetrying(_failedAttempts));
    _logFailure(error, patch.keys, exhausted: exhausted);
    if (!exhausted) {
      _retry?.cancel();
      _retry = Timer(retryBackoff[_failedAttempts - 1], _runScheduledRetry);
    }
  }

  void _runScheduledRetry() {
    _retry = null;
    if (!_alive) return;
    if (_unsaved.isEmpty) {
      // 失败的键已被新输入覆盖并落盘：显式自愈，不再写回旧值。
      _markClean();
      return;
    }
    unawaited(_attemptWrite(Map<String, Object?>.of(_unsaved)));
  }

  /// 全部落盘：清零退避计数、停掉重试、释放保活、发布 Clean。
  void _markClean() {
    _failedAttempts = 0;
    _retry?.cancel();
    _retry = null;
    _unsavedKeepAlive?.close();
    _unsavedKeepAlive = null;
    _publish(const InspectorAutoSaveClean());
  }

  void _publish(InspectorAutoSaveState next) {
    if (!_alive) return;
    ref.read(inspectorAutoSaveStatusProvider(arg).notifier).publish(next);
  }

  /// 只记键名与错误码，**绝不记值**——patch 里常带用户 prompt
  /// （LogSanitizer.redactKeys 也正是把 prompt 列为敏感键）。
  void _logFailure(
    InkError error,
    Iterable<String> keys, {
    required bool exhausted,
  }) {
    if (!_alive) return;
    final extra = <String, Object?>{
      'node_id': arg,
      'keys': keys.join(','),
      'code': error.code.wire,
      'attempt': _failedAttempts,
    };
    final logger = ref.read(loggerProvider);
    if (exhausted) {
      logger.error(
        _logModule,
        'auto-save gave up, changes left unsaved',
        extra: extra,
        cause: error,
      );
    } else {
      logger.warn(_logModule, 'auto-save failed, will retry', extra: extra);
    }
  }

  /// 通用防抖保存：连续调用只落最后一次 patch。
  ///
  /// 挂起期间用 [Ref.keepAlive] 挂起本 provider 的 autoDispose——否则切换
  /// Inspector 选中的节点会在计时器触发前就把它回收，编辑内容直接丢失
  /// （2026-08-31 审计 P0）。prompt 字段与 shot_notes 字段共用这份实现——不能
  /// 各自维护一份本地 Timer：widget 的 dispose() 里不允许再用 ref 去 flush
  /// （Riverpod 的 ConsumerStatefulElement 在 widget 自身 unmount 时就会拒绝
  /// 该 widget 发起的任何 ref 访问，与 provider 容器是否还活着无关），所以
  /// debounce 必须整个挂在 controller（跟着 provider 容器的生命周期走）上，
  /// 而不是 widget 的 State 上。
  ///
  /// 每个 node 只有一个挂起中的 Timer/patch 槽位：同一 node 上第二次
  /// saveDebounced/savePromptDebounced 调用会在第一次落盘前把它替换掉。
  /// 因此同一 node 上两个不同的防抖字段会互相打架——目前不是活 bug（prompt
  /// 与 shot_notes 分属不相交的节点类型），但后续若有 node 类型要同时防抖
  /// 两个字段，需要另外处理。
  void saveDebounced(Map<String, Object?> patch) {
    _cancelPendingDebounce();
    _debounceKeepAlive = ref.keepAlive();
    _debounce = Timer(debounceDuration, () {
      final link = _debounceKeepAlive;
      _debounceKeepAlive = null;
      unawaited(saveConfig(patch).whenComplete(() => link?.close()));
    });
  }

  /// prompt 防抖保存：连续输入只落最后一次。
  void savePromptDebounced(String prompt) =>
      saveDebounced(<String, Object?>{'prompt': prompt});

  /// 提交生成。先把最终 config 落盘，再发起生成。
  ///
  /// fire-and-forget：提交成功即回 idle；进度看画布渲染队列面板，
  /// 终态结果/失败由 CanvasScreen 的 registry listener 反映。
  ///
  /// 终稿写入与自动保存走**同一条**串行链（[_serialized]）：已经发射的在途
  /// 自动保存会排在终稿**之前**落库，旧 patch 再也盖不到终稿头上
  /// （BOARD 第 196 行）。顺带保证 `submitFromConfigNode` 读到的那一行就是终稿。
  Future<void> submit(Map<String, Object?> finalConfig) async {
    if (isBusy) return;
    // 还没发射的防抖 patch 直接丢掉：终稿是检查器按当前 provider 能力裁剪过的
    // 完整快照，补落一笔旧的局部 patch 只会把刚被刻意省掉的键又写回去。
    _cancelPendingDebounce();
    // 提交期间挂起 autoDispose：widget 中途关闭也要把状态机走完。
    final link = ref.keepAlive();
    state = const InspectorSubmitSubmitting();
    try {
      await _serialized(() async {
        final nodes = await ref.read(nodeRepositoryProvider.future);
        if (!_alive) return;
        await nodes.patchTypeConfig(arg, finalConfig);
      });
      if (!_alive) return;
      _setSubmitState(const InspectorSubmitRunning());
      final controller = await ref.read(generationControllerProvider.future);
      if (!_alive) return;
      await controller.submitFromConfigNode(arg);
      _setSubmitState(const InspectorSubmitIdle());
    } on MissingApiKeyError {
      _setSubmitState(const InspectorSubmitFailure(InspectorMissingApiKey()));
    } on InvalidGenerationConfigError catch (e) {
      _setSubmitState(
        InspectorSubmitFailure(InspectorInvalidConfig(e.reason)),
      );
    } on ProviderNotRegisteredError {
      _setSubmitState(
        const InspectorSubmitFailure(InspectorProviderNotRegistered()),
      );
    } on InkError catch (e) {
      _setSubmitState(InspectorSubmitFailure(InspectorInkFailure(e)));
    } finally {
      link.close();
    }
  }

  /// await 之后写提交状态的唯一入口：控制器已销毁就什么都不做
  /// （`state =` 在 dispose 后会抛 StateError）。
  void _setSubmitState(InspectorSubmitState next) {
    if (!_alive) return;
    state = next;
  }
}
