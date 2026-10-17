// 全应用唯一的「时长 / 耗时」写法：不到 60 秒写「N 秒」，满 60 秒写 m:ss，满 1 小时写 h:mm:ss；
// 估算值前加「~」。片长 / 估时长走 formatDurationLabel，计时器（已用 / 排队 / 用时）走 formatElapsed。
//
// m:ss / h:mm:ss 是格式量（同 formatCostUsd 的口径），不入 ARB；「N 秒」与「~」前缀走 ARB。
// 纯函数：不读时钟，只依赖传进来的 AppLocalizations。
import 'generated/app_localizations.dart';

/// 片长 / 估时长：四舍五入到秒（>0ms 至少 1 秒，有时长就不写 0）；0 与负数写「0 秒」。
/// 档位按舍入**之后**的秒数判——59 500ms 舍成 60 秒，写「1:00」而不是「60 秒」。
/// [estimated] 时整体套 `durationEstimated`（「~5 秒」「~1:14」）。
String formatDurationLabel(
  AppLocalizations l,
  int ms, {
  bool estimated = false,
}) {
  final int seconds;
  if (ms <= 0) {
    seconds = 0;
  } else {
    final int rounded = (ms / 1000).round();
    seconds = rounded < 1 ? 1 : rounded;
  }
  final String text = _tiered(l, seconds);
  return estimated ? l.durationEstimated(text) : text;
}

/// 计时（已用 / 排队 / 用时）：向下取整到秒，避免 59.6 秒提前跳成 1:00 又停一秒；
/// 负值当 0；不带「~」。
String formatElapsed(AppLocalizations l, Duration d) {
  final int seconds = d.inSeconds;
  return _tiered(l, seconds < 0 ? 0 : seconds);
}

/// 分档：<60 →「N 秒」；<3600 → m:ss（分不补零，秒补两位）；否则 h:mm:ss。
String _tiered(AppLocalizations l, int seconds) {
  if (seconds < 60) return l.durationSeconds(seconds);
  final int h = seconds ~/ 3600;
  final int m = (seconds % 3600) ~/ 60;
  final String ss = (seconds % 60).toString().padLeft(2, '0');
  if (h == 0) return '$m:$ss';
  return '$h:${m.toString().padLeft(2, '0')}:$ss';
}
