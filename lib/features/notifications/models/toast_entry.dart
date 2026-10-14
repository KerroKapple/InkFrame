// ToastEntry：一张通知卡的不可变快照——右下角那一张，也是铃铛历史里那一行。
//
// 手写不可变类（仓库禁新增 freezed，见 docs/BOARD.md）。不写 == / hashCode：
// 它带着调用方的回调（ToastAction），值相等没有意义，状态更新一律整条替换。
//
// 【倒计时不在这里】只记总时长 [dwell]（null = 不自动消失）。还剩多少由 ToastCenter
// 私下记账：剩余时间每 100ms 变一次，放进状态就等于每 100ms 重建一次整个卡片栈。
import 'package:flutter/foundation.dart';

import '../../../core/interfaces/toast_service.dart';

@immutable
class ToastEntry {
  const ToastEntry({
    required this.id,
    required this.version,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.meta,
    this.thumbnailPath,
    this.primary,
    this.secondary,
    this.dedupeKey,
    this.progress,
    this.dwell,
    this.leaving = false,
  });

  /// 卡位 id：整个会话唯一。去重替换沿用原 id（卡片原地换内容，不重放进场）。
  final int id;

  /// 同一个卡位被去重替换过几次。句柄记着自己拿到时的版本——卡位被别的
  /// show 接管之后，旧句柄的 update / complete / dismiss 都是空操作。
  final int version;

  final ToastKind kind;
  final String title;
  final String? body;
  final String? meta;

  /// 缩略图绝对路径。
  final String? thumbnailPath;

  final ToastAction? primary;
  final ToastAction? secondary;
  final String? dedupeKey;

  /// 进行中卡的进度 0..1；null = 不确定。
  final double? progress;

  /// 这张卡总共停留多久；null = 不自动消失（失败 / 进行中 / 设置为「不自动关闭」）。
  final Duration? dwell;

  /// 正在淡出：还在列表里，只为让退场动画画完。
  final bool leaving;

  /// 这张卡（或它最近一次原地换内容）出现的时刻，UTC。铃铛历史的「N 分钟前」据此算。
  final DateTime createdAt;

  /// [ToastHandle.update]：只改传了的字段，不动计时、不动出现时刻。
  ToastEntry updated({String? title, String? body, double? progress}) =>
      ToastEntry(
        id: id,
        version: version,
        kind: kind,
        title: title ?? this.title,
        createdAt: createdAt,
        body: body ?? this.body,
        meta: meta,
        thumbnailPath: thumbnailPath,
        primary: primary,
        secondary: secondary,
        dedupeKey: dedupeKey,
        progress: progress ?? this.progress,
        dwell: dwell,
        leaving: leaving,
      );

  /// [ToastHandle.complete]：原地变成终态卡。正文 / 缩略图 / 按钮按传入值整组替换
  /// （没传就是没有），进度清掉；出处与去重键保留。
  ToastEntry completed({
    required ToastKind kind,
    required String title,
    required Duration? dwell,
    required DateTime at,
    String? body,
    String? thumbnailPath,
    ToastAction? primary,
    ToastAction? secondary,
  }) =>
      ToastEntry(
        id: id,
        version: version,
        kind: kind,
        title: title,
        createdAt: at,
        body: body,
        meta: meta,
        thumbnailPath: thumbnailPath,
        primary: primary,
        secondary: secondary,
        dedupeKey: dedupeKey,
        dwell: dwell,
      );

  /// 开始淡出。
  ToastEntry asLeaving() => ToastEntry(
        id: id,
        version: version,
        kind: kind,
        title: title,
        createdAt: createdAt,
        body: body,
        meta: meta,
        thumbnailPath: thumbnailPath,
        primary: primary,
        secondary: secondary,
        dedupeKey: dedupeKey,
        progress: progress,
        dwell: dwell,
        leaving: true,
      );
}
