// ProviderFailureLogger：provider 失败必须在日志里留下线索（GAP-3 评审 P3③）。
//
// 这道测试守的不是"日志好看"，而是**可报障性**：上屏文案把非 InkError 一律归一
// 成 errorUnknown（刻意的，raw toString 不上屏），于是一旦没有这条日志，真出问题
// 时用户只能说"它说出了点问题"，而我们手上一点东西都没有。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/services/provider_failure_logger.dart';

import '../helpers/recording_logger.dart';

void main() {
  late RecordingLogger logger;

  setUp(() => logger = RecordingLogger());

  ProviderContainer boot() {
    final c = ProviderContainer(
      observers: <ProviderObserver>[ProviderFailureLogger(logger)],
    );
    addTearDown(c.dispose);
    return c;
  }

  List<LogRecord> failures() => logger
      .byLevel(InkLogLevel.error)
      .where((LogRecord r) => r.msg == 'provider failed')
      .toList();

  test('非 InkError 失败 → 记下 provider 名与错误类型', () async {
    final FutureProvider<int> exploding = FutureProvider<int>(
      (ref) async => throw StateError('boom'),
      name: 'explodingProvider',
    );
    final c = boot();

    await expectLater(c.read(exploding.future), throwsA(isA<StateError>()));

    final List<LogRecord> recs = failures();
    expect(recs, hasLength(1));
    expect(recs.single.module, 'app.provider');
    expect(recs.single.extra?['provider'], 'explodingProvider');
    expect(
      recs.single.extra?['error_type'],
      'StateError',
      reason: '上屏只剩 errorUnknown，类型名是唯一还能区分"什么坏了"的东西',
    );
    expect(recs.single.extra?['is_ink_error'], false);
    expect(recs.single.extra?.containsKey('code'), isFalse,
        reason: '非 InkError 没有 code，不该塞一个 null 进去装样子');
    expect(recs.single.cause, isA<StateError>());
    expect(recs.single.stackTrace, isNotNull);
  });

  test('InkError 失败 → 额外记下 code', () async {
    final FutureProvider<int> failing = FutureProvider<int>(
      (ref) async => throw const LocalIOError(extra: {'op': 'read'}),
      name: 'diskProvider',
    );
    final c = boot();

    await expectLater(c.read(failing.future), throwsA(isA<LocalIOError>()));

    final List<LogRecord> recs = failures();
    expect(recs, hasLength(1));
    expect(recs.single.extra?['is_ink_error'], true);
    expect(recs.single.extra?['code'], 'local_io_error');
  });

  test('provider 成功 → 不落任何 error（不许见谁都喊）', () async {
    final FutureProvider<int> ok =
        FutureProvider<int>((ref) async => 1, name: 'okProvider');
    final c = boot();

    expect(await c.read(ok.future), 1);

    expect(failures(), isEmpty);
    expect(logger.byLevel(InkLogLevel.error), isEmpty);
  });

  // `main.dart` 不可测（起窗口、起 PG、跑 runApp），所以「观察者真的装上了」只能
  // 用源码级断言来守。少了这一条，上面三条就是在测一个**生产里从未被安装**的类
  // ——本仓反复逮到的那种"绿着但什么都没守"。
  test('main.dart 真的把观察者装进了 ProviderContainer（源码级）', () {
    final String src = File('lib/main.dart').readAsStringSync();
    expect(
      RegExp(r'observers:\s*<ProviderObserver>\[\s*ProviderFailureLogger\(')
          .hasMatch(src),
      isTrue,
      reason: 'lib/main.dart 的 ProviderContainer 必须带上 ProviderFailureLogger，'
          '否则这个类在生产里永远不会被调用',
    );
  });
}
