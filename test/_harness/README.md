# test/_harness

InkFrame 测试基础设施。所有 widget / provider / controller test 共享的装配代码沉到这里。

## 为什么有这个目录

- 消除每个 test 自己装 `MaterialApp + ProviderScope + l10n delegates` 的重复
- 消除每个 provider test 自己写 `_loadFixture(name)` 的重复
- 给 custom-providers 等后续 sprint 提供 `FakeSubmittable` / `FakeSecureStorage` 等开箱即用件
- 单向依赖：harness 文件**禁止 import 任何 test 文件**

## 目录命名

`_harness/` 前缀下划线，`flutter test` 自动跳过整个目录。**唯一例外**：本目录下以 `_test.dart` 结尾的契约测试（如 `_harness_test.dart`）仍被识别为 test，用来守护 harness 自身契约。

## 文件清单

| 文件 | 职责 |
|---|---|
| `test_app.dart` | `pumpInkApp(tester, child, {...})` widget 启动器 |
| `fixtures.dart` | `loadProviderFixture(providerId, name)` JSON loader |
| `_harness_test.dart` | 上述 API 的契约测试 |

> 其余 fake_*.dart / golden_scaffold.dart 在后续 Task 2/3/4 落地。

## 用法

### Widget test

```dart
import '../../_harness/test_app.dart';

testWidgets('xxx', (tester) async {
  await pumpInkApp(
    tester,
    MyWidget(),
    overrides: [myProvider.overrideWithValue(fake)],
    locale: const Locale('zh'),
  );
  expect(find.text('生成'), findsOneWidget);
});
```

### Provider test

```dart
import '../_harness/fixtures.dart';

final Map<String, Object?> body =
    loadProviderFixture('gemini-image', 'submit_success');
dioAdapter.onPost(path, (req) => req.reply(200, body));
```

## 反模式（不要这样写）

- ❌ 在 harness 文件里写 production 业务逻辑——harness 只装环境，不持业务
- ❌ 在 harness 里 import 任何 `test/` 下的文件——单向依赖
- ❌ 用 `pumpWidget(MaterialApp(...))` 绕过 `pumpInkApp`——回到老路
- ❌ 在 widget test 里复制 l10n delegates 列表——直接用 `pumpInkApp`
- ❌ 写 `Map<String, Object?> _loadFixture(...)` 私有 helper——用 `loadProviderFixture`
