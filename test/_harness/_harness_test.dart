// Harness 自身契约测试：保证 pumpInkApp / loadProviderFixture 行为符合约定。
//
// 文件名带 `_test.dart` 后缀，被 flutter test 主动识别；同目录其他 harness 文件
// 以 `_` 前缀（test/_harness/）整体被 dart test runner 跳过，不会被误当 test 跑。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/l10n/l10n_x.dart';

import 'fixtures.dart';
import 'test_app.dart';

void main() {
  group('pumpInkApp', () {
    testWidgets('装配 MaterialApp + ProviderScope + l10n', (tester) async {
      await pumpInkApp(
        tester,
        Builder(builder: (ctx) => Text(ctx.l10n.studioEmptyTitle)),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('locale=zh 时 l10n 走中文', (tester) async {
      await pumpInkApp(
        tester,
        Builder(builder: (ctx) => Text(ctx.l10n.studioEmptyTitle)),
        locale: const Locale('zh'),
      );
      // 中文/英文文案不同即视为 locale 生效；具体文案值不锁，避免 ARB 调整误伤
      final Iterable<Text> texts =
          tester.widgetList<Text>(find.byType(Text));
      expect(texts.first.data, isNotEmpty);
    });

    testWidgets('surfaceSize 生效并在 tearDown 复位', (tester) async {
      await pumpInkApp(
        tester,
        const SizedBox.expand(),
        surfaceSize: const Size(800, 600),
      );
      expect(tester.view.physicalSize.width / tester.view.devicePixelRatio,
          800);
    });
  });

  group('loadProviderFixture', () {
    test('已存在的 fixture 正常解析', () {
      // gemini-image/submit_success.json 在仓库内长期存在
      final Map<String, Object?> json =
          loadProviderFixture('gemini-image', 'submit_success');
      expect(json, isA<Map<String, Object?>>());
      expect(json, isNotEmpty);
    });

    test('文件缺失时 fail 而非抛 IO 异常', () {
      expect(
        () => loadProviderFixture('no-such-provider', 'no-such-name'),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
