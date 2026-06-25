// 错误码 ↔ i18n key 编译期闸门（评审 P2#7）：
// 每个 InkErrorCode 必须有 messageKey 映射，且该 key 必须同时存在于
// app_en.arb 与 app_zh.arb。防"新增错误码忘配文案 → messageKey 运行时崩溃 /
// 静默退化 errorUnknown"。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/l10n/l10n_x.dart';

Map<String, Object?> _arb(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

/// 为每个 code 造一个对应 InkError 子类实例（sealed，code 受子类约束）。
InkError _errorFor(InkErrorCode code) => switch (code) {
      InkErrorCode.invalidKey ||
      InkErrorCode.insufficientBalance ||
      InkErrorCode.contentPolicy ||
      InkErrorCode.invalidParameter ||
      InkErrorCode.providerServer ||
      InkErrorCode.providerBusy ||
      InkErrorCode.providerInvalidResponse ||
      InkErrorCode.pollTimeout =>
        ProviderError(code: code),
      InkErrorCode.networkTimeout ||
      InkErrorCode.networkOffline =>
        NetworkError(code: code),
      InkErrorCode.downloadFailed => const DownloadError(),
      InkErrorCode.localIOError => const LocalIOError(),
      InkErrorCode.cancelledByUser => const CancelledError.byUser(),
      InkErrorCode.cancelledOnExit => const CancelledError.onExit(),
      InkErrorCode.unknown => const UnknownError(cause: 'x'),
    };

void main() {
  final en = _arb('lib/l10n/app_en.arb');
  final zh = _arb('lib/l10n/app_zh.arb');

  test('每个 InkErrorCode 都有 messageKey 映射', () {
    for (final code in InkErrorCode.values) {
      expect(
        kInkErrorMessageKeys[code],
        isNotNull,
        reason: '$code 缺 kInkErrorMessageKeys 映射（messageKey 会 ! 崩溃）',
      );
    }
  });

  test('每个 messageKey 同时存在于 app_en.arb 与 app_zh.arb', () {
    for (final entry in kInkErrorMessageKeys.entries) {
      final key = entry.value;
      expect(en.containsKey(key), isTrue,
          reason: '${entry.key} → "$key" 不在 app_en.arb');
      expect(zh.containsKey(key), isTrue,
          reason: '${entry.key} → "$key" 不在 app_zh.arb');
    }
  });

  // l10nError 的 switch 才是真正渲染处：仅 ARB 有 key、switch 缺 case 仍会静默退化
  // errorUnknown。本用例确保每个非 unknown code 都被 switch 路由到专属文案。
  testWidgets('l10nError 为每个非 unknown code 路由到专属文案（不退化 errorUnknown）',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    final unknownText = l10nError(ctx, const UnknownError(cause: 'x'));
    for (final code in InkErrorCode.values) {
      final text = l10nError(ctx, _errorFor(code));
      expect(text, isNotEmpty, reason: '$code 渲染空串');
      if (code != InkErrorCode.unknown) {
        expect(text, isNot(unknownText),
            reason: '$code 退化为 errorUnknown（l10nError switch 缺 case）');
      }
    }
  });
}
