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
// 同一节点的 type_config 写入（自动保存 + submit 的终稿）全部走一条串行链
// _serialized：落库顺序 = 发起顺序，在途的旧 patch 盖不到终稿头上。
//
// 本控制器实现 [PendingWriteFlushable] 并把自己注册进 [PendingWriteRegistry]：
// 退出序列在关连接池之前会叫它把挂起内容冲掉（BOARD 第 201 行）。注册方向是
// feature → core，退出路径不认识检查器。
//
// JobState 绑定点（agent-generation slice 落地后接线）：
//   jobStateProvider(nodeId) 可在 build 中 watch 并派生 running 进度，
//   届时 InspectorSubmitRunning.progress 接真实值。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/logger.dart';
import '../../../core/di/pending_writes.dart';
import '../../../core/di/repositories.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/pending_write_flush.dart';
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
    extends AutoDisposeFamilyNotifier<InspectorSubmitState, String>
    implements PendingWriteFlushable {
  Timer? _debounce;
  KeepAliveLink? _debounceKeepAlive;

  /// 挂起中的防抖 patch（按键合并，每键留最新值）。计时器触发时整张写出。
  final Map<String, Object?> _pendingDebounced = <String, Object?>{};

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

  /// 当前这一笔写入是退出路径冲刷出来的（[flushPendingWrites]）。
  ///
  /// 唯一作用是让失败记账说真话：退出时容器马上要 dispose，退避计时器永远不会
  /// 再触发，所以这种失败一律按「已用尽」处理——否则日志会留下一句
  /// 「will retry」的谎话，而那条日志正是这一笔丢失的唯一线索。
  bool _exitFlush = false;

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
    // 退避表按「第几次重试」索引，两个常量必须同时改，否则越界。
    assert(
      retryBackoff.length == maxAutoRetries,
      'retryBackoff must carry one delay per automatic retry',
    );
    _alive = true;
    // 注册进退出冲刷注册表：退出序列在关连接池之前会把挂起内容冲掉
    // （BOARD 第 201 行）。register 幂等，注销与 onDispose 对称——注册表只
    // 认抽象接口，不会因此持有一个已销毁控制器的悬空引用。
    final PendingWriteRegistry flushRegistry =
        ref.read(pendingWriteRegistryProvider);
    flushRegistry.register(this);
    ref.onDispose(() {
      _alive = false;
      flushRegistry.unregister(this);
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

  /// 取消挂起的防抖计时器、丢掉已累积的 patch 并释放其 keepAlive（不落盘）。
  void _cancelPendingDebounce() {
    _debounce?.cancel();
    _debounce = null;
    _pendingDebounced.clear();
    _debounceKeepAlive?.close();
    _debounceKeepAlive = null;
  }

  /// 立即持久化 type_config patch。
  ///
  /// 不抛——调用方多半是 onChanged 回调（fire-and-forget）。失败不再静默：翻成
  /// [InspectorAutoSaveState] 发布给 UI，并按退避自动重试；重试用尽后把
  /// 「未保存 + 重试」留给用户（[retryUnsaved]）。
  Future<void> saveConfig(Map<String, Object?> patch) => _attemptWrite(patch);

  /// 挂起写入 = 未发射的防抖 patch + 失败等重试的 `_unsaved`。
  ///
  /// #256 引入 `_unsaved` 之后这个判据就是两个 Map 的 isEmpty，便宜到可以在退出
  /// 路径上对每个注册对象问一次——这也正是这张卡从「不做」翻成「做」的前提
  /// （#232 时代还没有 `_unsaved`，当时只能去探私有计时器）。
  ///
  /// 不含「已发射、正在 await」的那一笔：`Pool.close(force: false)` 会等在用连接
  /// 归还，在途 UPDATE 自己会落地。
  @override
  bool get hasPendingWrites =>
      _pendingDebounced.isNotEmpty || _unsaved.isNotEmpty;

  /// 退出序列的冲刷口（BOARD 第 201 行）：把挂起内容合成一笔立刻写出去。
  ///
  /// 为什么必须由退出序列来叫，而不是在 onDispose 里补一次：`container.dispose()`
  /// 那一刻连接池已经关了（`AppTeardown` 的顺序是 Pool.close → PgController.stop
  /// → container.dispose），`Pool` 关的第一件事就是关掉内部 semaphore，之后的
  /// execute 直接抛——在 onDispose 里补写等于写进一个已经关掉的池子。
  ///
  /// 不抛（契约要求）：[_attemptWrite] 自己收 InkError 并记日志。
  @override
  Future<void> flushPendingWrites() async {
    // 退避计时器不会再有机会触发（容器马上 dispose），先停掉，免得它在冲刷
    // 在途时又排一笔重复写入。
    _retry?.cancel();
    _retry = null;
    // `_unsaved` 在前、`_pendingDebounced` 在后：同一个键取更新的那份——防抖里
    // 存的是用户最后敲进去的值，`_unsaved` 里是上一次写失败留下的旧值。
    final Map<String, Object?> merged = <String, Object?>{
      ..._unsaved,
      ..._pendingDebounced,
    };
    _cancelPendingDebounce();
    if (merged.isEmpty) return;
    // finally 复位：这个标志只许盖住**这一笔**写入的失败记账。留成常开模式等于
    // 把「自动重试」永久关掉——实践上退出之后没人再写，但一个会悄悄改变正常路径
    // 行为的粘滞开关不该存在。
    _exitFlush = true;
    try {
      await _attemptWrite(merged);
    } finally {
      _exitFlush = false;
    }
  }

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
    // 退出路径上「还会重试」是谎话：容器马上 dispose，退避计时器永远不会触发。
    // 直接按「已用尽」记账 → error 级日志 + Failed 态，而不是 warn「will retry」。
    final bool exhausted = _exitFlush || _failedAttempts > maxAutoRetries;
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

  /// 通用防抖保存：连续调用**按键合并**，每个键落最后一次值，窗口静默后一次写出。
  ///
  /// 合并而不是整笔替换（BOARD 第 198 行）：同一 node 上第二次 saveDebounced
  /// 若把第一次还没落盘的 patch 整个顶掉，另一个字段的编辑就凭空消失。今天两个
  /// 防抖调用点（prompt / shot_notes）分属不相交的节点类型碰不到，但「每键留
  /// 最新值」与失败重试用的 [_unsaved] 是同一条规则，一个类里不该有两套。
  ///
  /// 挂起期间用 [Ref.keepAlive] 挂起本 provider 的 autoDispose——否则切换
  /// Inspector 选中的节点会在计时器触发前就把它回收，编辑内容直接丢失
  /// （2026-08-31 审计 P0）。prompt 字段与 shot_notes 字段共用这份实现——不能
  /// 各自维护一份本地 Timer：widget 的 dispose() 里不允许再用 ref 去 flush
  /// （Riverpod 的 ConsumerStatefulElement 在 widget 自身 unmount 时就会拒绝
  /// 该 widget 发起的任何 ref 访问，与 provider 容器是否还活着无关），所以
  /// debounce 必须整个挂在 controller（跟着 provider 容器的生命周期走）上，
  /// 而不是 widget 的 State 上。
  void saveDebounced(Map<String, Object?> patch) {
    _pendingDebounced.addAll(patch);
    _debounce?.cancel();
    // 一串输入只取一次保活凭据，而不是每次按键换一个。
    _debounceKeepAlive ??= ref.keepAlive();
    _debounce = Timer(debounceDuration, () {
      final Map<String, Object?> merged =
          Map<String, Object?>.of(_pendingDebounced);
      _pendingDebounced.clear();
      _debounce = null;
      final KeepAliveLink? link = _debounceKeepAlive;
      _debounceKeepAlive = null;
      unawaited(saveConfig(merged).whenComplete(() => link?.close()));
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

  /// 带着挂起的编辑提交生成（画布 Ctrl+↵ / ⌘↵ 与节点右键菜单「生成」）：手里没有终稿快照的入口用它。
  ///
  /// 终稿 = 失败等重试的 `_unsaved` + 还没发射的防抖 patch（同一个键取防抖里的——那是用户最后敲进去的值；与
  /// [flushPendingWrites] 同一个合并顺序），一并交给 [submit]：终稿与生成走的是 submit 那一条写入链，生成读到的
  /// 就是用户最后敲进去的那句——与提示词条带着最新文本提交是同一个效果。
  ///
  /// 不借退出路径的 [flushPendingWrites]：那一笔写失败会直接按「已用尽」记账、不再重试，接着的 submit 读到
  /// 库里的旧提示词，白生成一次。并进终稿之后，终稿写不进去 submit 就停在失败态、不发起生成。
  ///
  /// 重试表里与防抖同键的旧值一并换成新值：失败重试还在排队的话，它晚到也只会把同一份终稿再写一遍，
  /// 不会把旧值盖回去（「每键留最新值」，与 _onWriteFailed 同一条规则）。
  Future<void> submitWithPending() {
    for (final MapEntry<String, Object?> e in _pendingDebounced.entries) {
      if (_unsaved.containsKey(e.key)) _unsaved[e.key] = e.value;
    }
    return submit(<String, Object?>{..._unsaved, ..._pendingDebounced});
  }

  /// await 之后写提交状态的唯一入口：控制器已销毁就什么都不做
  /// （`state =` 在 dispose 后会抛 StateError）。
  void _setSubmitState(InspectorSubmitState next) {
    if (!_alive) return;
    state = next;
  }
}
