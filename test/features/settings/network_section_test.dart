// 设置「网络」页：env 代理只读快照上屏；凭据不上屏。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/net.dart';
import 'package:inkframe/features/settings/widgets/network_section.dart';

import '../../_harness/test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Map<String, String> env,
) =>
    pumpInkApp(
      tester,
      const Scaffold(body: NetworkSection()),
      overrides: <Override>[
        processEnvironmentProvider.overrideWithValue(env),
      ],
      surfaceSize: const Size(900, 700),
    );

void main() {
  testWidgets('无代理变量：四行全「未设置」+ 当前直连', (tester) async {
    await _pump(tester, const <String, String>{});
    await tester.pumpAndSettle();

    expect(find.text('HTTPS_PROXY'), findsOneWidget);
    expect(find.text('HTTP_PROXY'), findsOneWidget);
    expect(find.text('ALL_PROXY'), findsOneWidget);
    expect(find.text('NO_PROXY'), findsOneWidget);
    expect(find.text('not set'), findsNWidgets(4));
    expect(find.text('Direct connection'), findsOneWidget);
  });

  testWidgets('有代理：值上屏且凭据掩码；当前状态写出代理目标', (tester) async {
    await _pump(tester, const <String, String>{
      'HTTPS_PROXY': 'http://alice:s3cret@proxy.corp:3128',
      'NO_PROXY': '.corp',
    });
    await tester.pumpAndSettle();

    expect(find.text('http://•••@proxy.corp:3128'), findsOneWidget);
    expect(find.textContaining('s3cret'), findsNothing, reason: '口令不许上屏');
    expect(find.text('.corp'), findsOneWidget);
    expect(find.text('Via •••@proxy.corp:3128'), findsOneWidget);
  });

  testWidgets('空串 = 显式禁用该档，与「未设置」区分', (tester) async {
    await _pump(tester, const <String, String>{'HTTPS_PROXY': ''});
    await tester.pumpAndSettle();

    expect(find.text('empty — proxy disabled'), findsOneWidget);
    expect(find.text('not set'), findsNWidgets(3));
    expect(find.text('Direct connection'), findsOneWidget);
  });
}
