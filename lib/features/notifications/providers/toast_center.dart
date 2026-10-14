// ToastCenter：ToastService 的实现——全应用通知卡的状态机（画面在 widgets/toast_layer.dart，
// 这里零 widget）。
//
// - 排队：live 按出现顺序（旧 → 新）。最新的 [kToastMaxVisible] 张在场，更旧的折进
//   「还有 N 条」，等前面的走了再轮到它
// - 计时：按类型停留（提示 / 完成 4 秒、警告 6 秒、撤销 8 秒；失败 / 进行中不自动消失）。
//   设置 › 停留时长：「加长」×2，「不自动关闭」一律不计时。只有在场的卡倒计时——折叠着的
//   用户根本没看见，不该替它把时间花掉
// - 暂停：鼠标停在卡片栈上、窗口不在前台（失焦 / 最小化）时全部停表，回来接着走
// - 去重：同一个 dedupeKey 原地替换在场的那一张（同一卡位、内容整组换掉、重新计时），不新增
// - 历史：本次会话最近 [kToastHistoryCap] 条（新 → 旧）+ 未读。历史面板开着时到达的不算未读；
//   未读里有失败 ⇒ 铃铛上的点变红（[ToastCenterState.hasUnreadError]）
// - 提示音：show / complete 带 chime 时按设置响一声；节流是提示音服务自己的事
//
// 【只有一个周期 Timer】只在「有在场的卡正在倒计时、且没暂停」时才跑，否则立刻取消；
// 退场动画结束后的移除各用一个一次性 Timer。全部在 ref.onDispose 里取消。
// 倒计时按 tick 累减而不是读墙钟：fake_async / tester.pump 推进时间时结果是确定的。
// 出现时刻（历史的「N 分钟前」）取 clockProvider。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/clock.dart';
import '../../../core/di/notification_sound.dart';
import '../../../core/di/paths.dart';
import '../../../core/di/preferences.dart';
import '../../../core/interfaces/notification_sound_service.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../core/models/app_preferences.dart';
import '../../../theme/motion.dart';
import '../models/notification_prefs.dart';
import '../models/toast_entry.dart';

/// 同时在场的卡最多几张；更旧的折进「还有 N 条」。
const int kToastMaxVisible = 3;

/// 铃铛历史保留本次会话最近多少条。
const int kToastHistoryCap = 100;

/// 倒计时步长。
const Duration kToastTick = Duration(milliseconds: 100);

/// 按类型的停留时长；null = 不自动消失。[pref] 是设置 › 停留时长。
Duration? toastDwellFor(ToastKind kind, ToastDwell pref) {
  if (pref == ToastDwell.never) return null;
  final Duration? base = switch (kind) {
    ToastKind.info || ToastKind.success => const Duration(seconds: 4),
    ToastKind.warning => const Duration(seconds: 6),
    ToastKind.undo => const Duration(seconds: 8),
    ToastKind.error || ToastKind.progress => null,
  };
  if (base == null) return null;
  return pref == ToastDwell.long ? base * 2 : base;
}

@immutable
class ToastCenterState {
  const ToastCenterState({
    this.live = const <ToastEntry>[],
    this.history = const <ToastEntry>[],
    this.unreadIds = const <int>{},
    this.historyOpen = false,
  });

  /// 右下角的卡，旧 → 新；含正在淡出的。
  final List<ToastEntry> live;

  /// 铃铛历史，新 → 旧，最多 [kToastHistoryCap] 条。
  final List<ToastEntry> history;

  /// 历史里还没看过的条目 id。
  final Set<int> unreadIds;

  /// 铃铛下拉是否开着。
  final bool historyOpen;

  int get unreadCount => unreadIds.length;

  /// 未读里有失败 ⇒ 铃铛上的点用 danger 而不是 accent。
  bool get hasUnreadError => history.any(
        (ToastEntry e) => e.kind == ToastKind.error && unreadIds.contains(e.id),
      );

  /// 在场且没被折叠的卡：不在淡出中的里面最新的 [kToastMaxVisible] 张。
  Set<int> get visibleIds {
    final List<ToastEntry> active = <ToastEntry>[
      for (final ToastEntry e in live)
        if (!e.leaving) e,
    ];
    return <int>{
      for (final ToastEntry e
          in active.skip(math.max(0, active.length - kToastMaxVisible)))
        e.id,
    };
  }

  /// 画在屏幕上的卡，旧 → 新：没被折叠的在场卡 + 正在淡出的。
  /// （折叠着的卡被关掉时直接移除、不走淡出，所以淡出中的一定是画过的。）
  List<ToastEntry> get shown {
    final Set<int> visible = visibleIds;
    return <ToastEntry>[
      for (final ToastEntry e in live)
        if (e.leaving || visible.contains(e.id)) e,
    ];
  }

  /// 折进「还有 N 条」的张数。
  int get overflowCount {
    int active = 0;
    for (final ToastEntry e in live) {
      if (!e.leaving) active++;
    }
    return math.max(0, active - kToastMaxVisible);
  }

  ToastCenterState copyWith({
    List<ToastEntry>? live,
    List<ToastEntry>? history,
    Set<int>? unreadIds,
    bool? historyOpen,
  }) =>
      ToastCenterState(
        live: live ?? this.live,
        history: history ?? this.history,
        unreadIds: unreadIds ?? this.unreadIds,
        historyOpen: historyOpen ?? this.historyOpen,
      );
}

/// 全应用唯一的通知中心（keepAlive）。调用方经 toastServiceProvider 以契约类型使用它；
/// 只有通知 UI（卡片层 / 铃铛）直接读写这个 provider。
final toastCenterProvider = NotifierProvider<ToastCenter, ToastCenterState>(
  ToastCenter.new,
  name: 'toastCenterProvider',
);

class ToastCenter extends Notifier<ToastCenterState> implements ToastService {
  /// 卡位 id 发号器——整个会话单调递增。
  int _nextId = 0;

  /// 正在倒计时的卡还剩多久（只有 dwell 非 null 的卡在这里）。不放进状态：见 ToastEntry 头注。
  final Map<int, Duration> _remaining = <int, Duration>{};

  /// 淡出中的卡：退场动画画完后移除。
  final Map<int, Timer> _removals = <int, Timer>{};

  Timer? _ticker;
  bool _hovered = false;
  bool _windowActive = true;

  /// provider 已销毁（应用退出 / 测试容器释放）之后，迟到的句柄调用一律空操作。
  bool _alive = false;

  @override
  ToastCenterState build() {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _ticker?.cancel();
      _ticker = null;
      for (final Timer t in _removals.values) {
        t.cancel();
      }
      _removals.clear();
      _remaining.clear();
    });
    return const ToastCenterState();
  }

  bool get _paused => _hovered || !_windowActive;

  // ===== ToastService =====

  @override
  ToastHandle show(
    String title, {
    ToastKind kind = ToastKind.info,
    String? body,
    String? meta,
    String? thumbnailPath,
    ToastAction? primary,
    ToastAction? secondary,
    String? dedupeKey,
    bool chime = false,
  }) {
    if (!_alive) return _ToastHandle(this, -1, -1);
    final ToastCenterState s = state;
    final Duration? dwell = _dwellFor(kind);
    final DateTime now = _now();
    final int replace = dedupeKey == null
        ? -1
        : s.live.indexWhere(
            (ToastEntry e) => !e.leaving && e.dedupeKey == dedupeKey,
          );
    final ToastEntry entry;
    final List<ToastEntry> live;
    if (replace >= 0) {
      // 同一个卡位原地换内容：id 不变（不重放进场），版本 +1（旧句柄就此失效）。
      final ToastEntry old = s.live[replace];
      entry = ToastEntry(
        id: old.id,
        version: old.version + 1,
        kind: kind,
        title: title,
        createdAt: now,
        body: body,
        meta: meta,
        thumbnailPath: thumbnailPath,
        primary: primary,
        secondary: secondary,
        dedupeKey: dedupeKey,
        dwell: dwell,
      );
      live = List<ToastEntry>.unmodifiable(
        <ToastEntry>[
          for (final ToastEntry e in s.live) e.id == old.id ? entry : e,
        ],
      );
    } else {
      entry = ToastEntry(
        id: _nextId++,
        version: 0,
        kind: kind,
        title: title,
        createdAt: now,
        body: body,
        meta: meta,
        thumbnailPath: thumbnailPath,
        primary: primary,
        secondary: secondary,
        dedupeKey: dedupeKey,
        dwell: dwell,
      );
      live = List<ToastEntry>.unmodifiable(<ToastEntry>[...s.live, entry]);
    }
    _setRemaining(entry.id, dwell);
    state = _recorded(s.copyWith(live: live), entry);
    if (chime) _chime();
    _syncTicker();
    return _ToastHandle(this, entry.id, entry.version);
  }

  // ===== 给通知 UI 用 =====

  /// 鼠标进出卡片栈。
  void setHovered(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    _syncTicker();
  }

  /// 应用窗口是否在前台（AppLifecycleState.resumed）。
  void setWindowActive(bool active) {
    if (_windowActive == active) return;
    _windowActive = active;
    _syncTicker();
  }

  /// 用户关掉一张卡（× / 按下卡上的按钮）。
  void dismiss(int id) => _leave(id);

  /// 打开铃铛历史：全部标为已读；开着期间到达的也不算未读。
  void openHistory() {
    final ToastCenterState s = state;
    if (s.historyOpen && s.unreadIds.isEmpty) return;
    state = s.copyWith(historyOpen: true, unreadIds: const <int>{});
  }

  void closeHistory() {
    if (!state.historyOpen) return;
    state = state.copyWith(historyOpen: false);
  }

  /// 清空历史（右下角在场的卡不受影响）。
  void clearHistory() {
    final ToastCenterState s = state;
    if (s.history.isEmpty && s.unreadIds.isEmpty) return;
    state = s.copyWith(
      history: const <ToastEntry>[],
      unreadIds: const <int>{},
    );
  }

  void markAllRead() {
    if (state.unreadIds.isEmpty) return;
    state = state.copyWith(unreadIds: const <int>{});
  }

  // ===== 句柄 =====

  /// 句柄指向的卡：还在场、没在淡出、而且卡位没被别的 show 接管。否则 null（空操作）。
  ToastEntry? _current(int id, int version) {
    if (!_alive) return null;
    for (final ToastEntry e in state.live) {
      if (e.id == id) return e.version == version && !e.leaving ? e : null;
    }
    return null;
  }

  void _update(
    int id,
    int version, {
    String? title,
    String? body,
    double? progress,
  }) {
    final ToastEntry? e = _current(id, version);
    if (e == null) return;
    final ToastEntry next = e.updated(
      title: title,
      body: body,
      progress: progress?.clamp(0.0, 1.0),
    );
    final ToastCenterState s = state;
    state = s.copyWith(
      live: _replacing(s.live, next),
      // 历史里那一行跟着改字，但不重新标未读：进度跳一格不是新消息。
      history: _replacing(s.history, next),
    );
  }

  void _complete(
    int id,
    int version, {
    required ToastKind kind,
    required String title,
    required bool chime,
    String? body,
    String? thumbnailPath,
    ToastAction? primary,
    ToastAction? secondary,
  }) {
    final ToastEntry? e = _current(id, version);
    if (e == null) return;
    final Duration? dwell = _dwellFor(kind);
    final ToastEntry next = e.completed(
      kind: kind,
      title: title,
      dwell: dwell,
      at: _now(),
      body: body,
      thumbnailPath: thumbnailPath,
      primary: primary,
      secondary: secondary,
    );
    _setRemaining(id, dwell);
    final ToastCenterState s = state;
    // 终态是一条新消息：历史里挪到最前、重新标未读。
    state = _recorded(s.copyWith(live: _replacing(s.live, next)), next);
    if (chime) _chime();
    _syncTicker();
  }

  void _dismissFromHandle(int id, int version) {
    if (_current(id, version) == null) return;
    _leave(id);
  }

  // ===== 内部 =====

  Duration? _dwellFor(ToastKind kind) => toastDwellFor(
        kind,
        toastDwellFromPref(ref.read(preferencesServiceProvider).current.toastDwell),
      );

  DateTime _now() => ref.read(clockProvider).nowUtc();

  void _setRemaining(int id, Duration? dwell) {
    if (dwell == null) {
      _remaining.remove(id);
    } else {
      _remaining[id] = dwell;
    }
  }

  /// [entry] 记进历史最前（已在历史里的同 id 那一行挪过来），标未读（面板开着时除外），截到上限。
  ToastCenterState _recorded(ToastCenterState s, ToastEntry entry) {
    final List<ToastEntry> all = <ToastEntry>[
      entry,
      for (final ToastEntry h in s.history)
        if (h.id != entry.id) h,
    ];
    final List<ToastEntry> kept = all.length > kToastHistoryCap
        ? all.sublist(0, kToastHistoryCap)
        : all;
    final Set<int> keptIds = <int>{for (final ToastEntry h in kept) h.id};
    return s.copyWith(
      history: List<ToastEntry>.unmodifiable(kept),
      unreadIds: Set<int>.unmodifiable(<int>{
        for (final int id in s.unreadIds)
          if (keptIds.contains(id)) id,
        if (!s.historyOpen) entry.id,
      }),
    );
  }

  /// 同 id 的那一条换成 [next]；没有就原样。
  static List<ToastEntry> _replacing(List<ToastEntry> list, ToastEntry next) =>
      List<ToastEntry>.unmodifiable(<ToastEntry>[
        for (final ToastEntry e in list) e.id == next.id ? next : e,
      ]);

  /// 开始退场：画着的卡淡出后再移除；折叠着的直接移除（没东西可淡出）。
  void _leave(int id) {
    if (!_alive) return;
    final ToastCenterState s = state;
    final int at = s.live.indexWhere((ToastEntry e) => e.id == id);
    if (at < 0 || s.live[at].leaving) return;
    _remaining.remove(id);
    if (!s.visibleIds.contains(id)) {
      _remove(id);
      return;
    }
    state = s.copyWith(
      live: List<ToastEntry>.unmodifiable(<ToastEntry>[
        for (final ToastEntry e in s.live) e.id == id ? e.asLeaving() : e,
      ]),
    );
    _removals[id] = Timer(InkMotionSpring.popoverOut, () {
      _removals.remove(id);
      _remove(id);
    });
    // 走掉一张，折叠着的下一张就进场了——它的倒计时从这里开始。
    _syncTicker();
  }

  void _remove(int id) {
    if (!_alive) return;
    final ToastCenterState s = state;
    final List<ToastEntry> live = <ToastEntry>[
      for (final ToastEntry e in s.live)
        if (e.id != id) e,
    ];
    if (live.length == s.live.length) return;
    _remaining.remove(id);
    // 一张卡都不剩，鼠标就不可能还停在卡片栈上。防 MouseRegion 的 onExit 没赶上
    // （卡片栈被抽空的那一帧），否则下一张卡会一直停表。
    if (live.isEmpty) _hovered = false;
    state = s.copyWith(live: List<ToastEntry>.unmodifiable(live));
    _syncTicker();
  }

  /// 有在场的卡在倒计时且没暂停 ⇒ 跑着唯一的那个周期 Timer；否则停掉。
  void _syncTicker() {
    final bool counting = _alive &&
        !_paused &&
        state.visibleIds.any(_remaining.containsKey);
    if (counting) {
      _ticker ??= Timer.periodic(kToastTick, (_) => _tick());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _tick() {
    final List<int> expired = <int>[];
    for (final int id in state.visibleIds) {
      final Duration? left = _remaining[id];
      if (left == null) continue;
      final Duration next = left - kToastTick;
      if (next > Duration.zero) {
        _remaining[id] = next;
      } else {
        expired.add(id);
      }
    }
    for (final int id in expired) {
      _leave(id);
    }
    _syncTicker();
  }

  /// 按设置响一声。自定义音只认 config/sounds/ 下的文件名（basename：偏好文件里
  /// 就算混进了路径分隔符，也出不了这个目录）。
  void _chime() {
    final AppPreferences prefs = ref.read(preferencesServiceProvider).current;
    final NotificationSound sound =
        notificationSoundFromPref(prefs.notificationSound);
    final String? file = prefs.notificationSoundFile;
    final String? customPath = sound == NotificationSound.custom && file != null
        ? p.join(
            ref.read(appPathsProvider).config.path,
            kCustomNotificationSoundDir,
            p.basename(file),
          )
        : null;
    unawaited(
      ref
          .read(notificationSoundServiceProvider)
          .play(sound, customFilePath: customPath),
    );
  }
}

class _ToastHandle implements ToastHandle {
  const _ToastHandle(this._center, this._id, this._version);

  final ToastCenter _center;
  final int _id;
  final int _version;

  @override
  void update({String? title, String? body, double? progress}) =>
      _center._update(_id, _version, title: title, body: body, progress: progress);

  @override
  void complete({
    required ToastKind kind,
    required String title,
    String? body,
    String? thumbnailPath,
    ToastAction? primary,
    ToastAction? secondary,
    bool chime = false,
  }) =>
      _center._complete(
        _id,
        _version,
        kind: kind,
        title: title,
        chime: chime,
        body: body,
        thumbnailPath: thumbnailPath,
        primary: primary,
        secondary: secondary,
      );

  @override
  void dismiss() => _center._dismissFromHandle(_id, _version);
}
