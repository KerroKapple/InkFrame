// 统一时长 / 耗时格式：不到 60 秒写「N 秒」，满 60 秒写 m:ss，满 1 小时写 h:mm:ss；
// 估算值前加「~」。
//
// 这条测试存在的理由：剧本面板、导入对话框、产物检查器片长、任务弹层、通知卡、系统通知、
// 花费预告各自写过一套（「00:00:05」「1 分 12 秒」「预计 4 分钟」），口径互相打架。
// 档位按舍入「之后」的秒数判、计时器向下取整——这两条是最容易被顺手改坏的地方。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/l10n/duration_format.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations zh = lookupAppLocalizations(const Locale('zh'));

  group('formatDurationLabel', () {
    test('不到 60 秒写 N 秒', () {
      expect(formatDurationLabel(zh, 5000), '5 秒');
      expect(formatDurationLabel(en, 5000), '5s');
    });

    test('满 60 秒写 m:ss，分不补零', () {
      expect(formatDurationLabel(zh, 72000), '1:12');
      expect(formatDurationLabel(zh, 600000), '10:00');
      expect(formatDurationLabel(zh, 3599000), '59:59');
      // m:ss 是格式量，不随语言变。
      expect(formatDurationLabel(en, 72000), '1:12');
    });

    test('档位按四舍五入后的秒数判', () {
      expect(formatDurationLabel(zh, 59499), '59 秒');
      expect(formatDurationLabel(zh, 59500), '1:00');
    });

    test('满 1 小时写 h:mm:ss', () {
      expect(formatDurationLabel(zh, 3600000), '1:00:00');
      expect(formatDurationLabel(zh, 3723000), '1:02:03');
    });

    test('有时长至少写 1 秒，0 与负数写 0 秒', () {
      expect(formatDurationLabel(zh, 1), '1 秒');
      expect(formatDurationLabel(zh, 499), '1 秒');
      expect(formatDurationLabel(zh, 0), '0 秒');
      expect(formatDurationLabel(zh, -500), '0 秒');
    });

    test('estimated 加 ~ 前缀', () {
      expect(formatDurationLabel(zh, 5000, estimated: true), '~5 秒');
      expect(formatDurationLabel(zh, 74000, estimated: true), '~1:14');
      expect(formatDurationLabel(zh, 0, estimated: true), '~0 秒');
      expect(formatDurationLabel(en, 5000, estimated: true), '~5s');
    });
  });

  group('formatElapsed', () {
    test('向下取整，不提前进位', () {
      expect(formatElapsed(zh, const Duration(milliseconds: 59999)), '59 秒');
      expect(formatElapsed(zh, const Duration(milliseconds: 60000)), '1:00');
      expect(formatElapsed(zh, const Duration(milliseconds: 72999)), '1:12');
    });

    test('负值当 0', () {
      expect(formatElapsed(zh, const Duration(seconds: -3)), '0 秒');
    });

    test('整秒输入与 formatDurationLabel 同结果', () {
      for (final AppLocalizations l in <AppLocalizations>[zh, en]) {
        for (final int s in <int>[0, 8, 59, 60, 72, 123, 3600]) {
          expect(
            formatElapsed(l, Duration(seconds: s)),
            formatDurationLabel(l, s * 1000),
            reason: '${l.localeName} · $s 秒',
          );
        }
      }
    });
  });
}
