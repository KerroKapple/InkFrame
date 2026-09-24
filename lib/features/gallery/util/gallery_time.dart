// 「2 小时前」这类相对时间（右栏来源行 / 稿上「画布 02 · 主线 · 2 小时前」）。
import '../../../l10n/generated/app_localizations.dart';

String galleryTimeAgo(AppLocalizations l, DateTime at, DateTime now) {
  final Duration d = now.difference(at);
  if (d.inMinutes < 1) return l.galleryTimeJustNow;
  if (d.inHours < 1) return l.galleryTimeMinutesAgo(d.inMinutes);
  if (d.inDays < 1) return l.galleryTimeHoursAgo(d.inHours);
  return l.galleryTimeDaysAgo(d.inDays);
}

/// 稿上的时长写法 00:04:08（时:分:秒）。
String galleryFormatDuration(int ms) {
  final Duration d = Duration(milliseconds: ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
}
