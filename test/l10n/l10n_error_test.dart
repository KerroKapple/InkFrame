// l10nError 映射单测：InkError.messageKey → 本地化文案。
//
// 走 pumpInkApp 拿真 BuildContext；en/zh 双语断言真实文案，并校验 default 兜底分支。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/l10n/l10n_x.dart';

import '../_harness/test_app.dart';

/// 把 l10nError(context, error) 的结果通过一个 Text 渲染出来，便于断言文案。
Future<String> _resolve(
  WidgetTester tester,
  InkError error, {
  Locale locale = const Locale('en'),
}) async {
  late String resolved;
  await pumpInkApp(
    tester,
    Builder(
      builder: (ctx) {
        resolved = l10nError(ctx, error);
        return Text(resolved);
      },
    ),
    locale: locale,
  );
  return resolved;
}

void main() {
  group('l10nError 英文映射', () {
    testWidgets('invalid_key → API key 文案', (tester) async {
      final s = await _resolve(
        tester,
        const ProviderError(code: InkErrorCode.invalidKey),
      );
      expect(s, 'API key was rejected by the provider. Update it in Settings → API Keys.');
    });

    testWidgets('network_timeout → 超时文案', (tester) async {
      final s = await _resolve(
        tester,
        const NetworkError(code: InkErrorCode.networkTimeout),
      );
      expect(s, 'Network timed out. Please retry.');
    });

    testWidgets('cancelled_by_user vs cancelled_on_exit 文案不同', (tester) async {
      final byUser = await _resolve(tester, const CancelledError.byUser());
      final onExit = await _resolve(tester, const CancelledError.onExit());
      expect(byUser, 'Cancelled.');
      expect(onExit, 'Cancelled because the application is exiting.');
      expect(byUser, isNot(onExit));
    });

    testWidgets('download_failed / local_io 各自文案', (tester) async {
      expect(
        await _resolve(tester, const DownloadError()),
        "The generated file couldn't be downloaded. Check your connection and retry.",
      );
      expect(
        await _resolve(tester, const LocalIOError()),
        'Local disk I/O error. Check space and permissions.',
      );
    });

    testWidgets('default 兜底：messageKey 命中 unknown → errorUnknown', (tester) async {
      // UnknownError.messageKey == 'errorUnknown'，落到 switch 的 `_` 分支。
      final s = await _resolve(
        tester,
        const UnknownError(cause: 'boom'),
      );
      expect(s, 'An unknown error occurred.');
    });
  });

  group('l10nError 中文映射', () {
    testWidgets('locale=zh 时返回中文，且与英文不同', (tester) async {
      const err = ProviderError(code: InkErrorCode.invalidKey);
      final zh = await _resolve(tester, err, locale: const Locale('zh'));
      final en = await _resolve(tester, err);
      expect(zh, 'API Key 无效，请到「设置 → API Keys」更新。');
      expect(zh, isNot(en));
    });

    testWidgets('locale=zh 取消文案走中文', (tester) async {
      final zh = await _resolve(
        tester,
        const CancelledError.byUser(),
        locale: const Locale('zh'),
      );
      expect(zh, '已取消。');
    });
  });

  group('l10nAsyncError 桥接（AsyncValue.error 类型 Object）', () {
    testWidgets('InkError → 与 l10nError 逐字一致', (tester) async {
      late String viaAsync;
      late String viaDirect;
      const err = NetworkError(code: InkErrorCode.networkTimeout);
      await pumpInkApp(
        tester,
        Builder(
          builder: (ctx) {
            viaAsync = l10nAsyncError(ctx, err);
            viaDirect = l10nError(ctx, err);
            return Text(viaAsync);
          },
        ),
      );
      expect(viaAsync, viaDirect);
      expect(viaAsync, 'Network timed out. Please retry.');
    });

    testWidgets('非 InkError（普通异常）→ 兜底 errorUnknown', (tester) async {
      late String s;
      await pumpInkApp(
        tester,
        Builder(
          builder: (ctx) {
            s = l10nAsyncError(ctx, Exception('boom'));
            return Text(s);
          },
        ),
      );
      expect(s, 'An unknown error occurred.');
    });
  });

  group('l10nKeyRejectReason：被拒原因 → 分流文案', () {
    Future<String> resolveReason(
      WidgetTester tester,
      KeyInvalidReason reason, {
      Locale locale = const Locale('en'),
    }) async {
      late String resolved;
      await pumpInkApp(
        tester,
        Builder(
          builder: (ctx) {
            resolved = l10nKeyRejectReason(ctx.l10n, reason);
            return Text(resolved);
          },
        ),
        locale: locale,
      );
      return resolved;
    }

    // 这一条就是本卡的全部意义：三种成因的文案必须两两不同，
    // 否则「余额不足」仍会被读成「换一把 Key」。
    testWidgets('三种 reason 的英文文案两两不同且非空', (tester) async {
      final texts = <String>[];
      for (final reason in KeyInvalidReason.values) {
        texts.add(await resolveReason(tester, reason));
      }
      expect(texts.every((t) => t.isNotEmpty), isTrue);
      expect(texts.toSet().length, KeyInvalidReason.values.length);
    });

    testWidgets('余额不足文案不提「换 Key」，只提充值', (tester) async {
      final quota =
          await resolveReason(tester, KeyInvalidReason.insufficientBalance);
      final invalid = await resolveReason(tester, KeyInvalidReason.invalidKey);
      expect(quota, contains('balance'));
      expect(quota, isNot(invalid));
      expect(invalid.toLowerCase(), contains('invalid'));
    });

    testWidgets('zh 覆盖三种 reason，且与 en 不同', (tester) async {
      for (final reason in KeyInvalidReason.values) {
        final zh = await resolveReason(tester, reason, locale: const Locale('zh'));
        final en = await resolveReason(tester, reason);
        expect(zh, isNotEmpty);
        expect(zh, isNot(en));
      }
    });
  });
}
