# Test Harness 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `test/_harness/` 下落一套统一的测试基础设施，消除当前 widget 装配 / fixture 加载 / mock 构造的重复代码，并为 custom-providers sprint 提供必备的 `FakeSubmittable` / `FakeSecureStorage` / `FakeRepository` 件。

**Non-goals (本 sprint 不做):**
- 替换现有 `PgTestHarness`（设计已干净，保留并迁移到 `test/_harness/pg.dart` 命名一致即可）
- 引入新的 mocking 框架（mocktail / mockito）——保持原 `http_mock_adapter` + 手写 fake 风格
- 改写 CI workflow（golden job 占位保留，Task 4 只新增一个真 golden test）
- Coverage 目标调整（70% 不动）

**底层逻辑：** 测试代码也是代码，DRY/SRP 同样适用。当前每个 widget test 自己装 `MaterialApp + ProviderScope + l10n delegates`，每个 provider test 自己写 `_loadFixture`——一处接口改动牵动 N 处测试。Harness 把这层抽象出来：测试只声明"我要测什么"，不声明"环境怎么装"。

**Architecture decisions:**
- 目录命名 `test/_harness/` —— `_` 前缀避免被 `flutter test` 当作 test 自动跑（Dart test runner 跳过下划线开头的文件）
- 每个 fake 件单独成文件，避免 god-file
- Harness 文件**禁止 import 任何 test 文件**——单向依赖
- Harness 件不进 coverage 统计（CI workflow 已 exclude pattern 处理）
- 所有 fake 必须实现对应的 abstract 接口（lib/core/interfaces/）——和真实现走同一契约，避免 LSP 违反

**Tech Stack:** Flutter test, Riverpod test overrides, dio + http_mock_adapter（已有），postgres-dart（已有）。

---

## 文件结构

| 状态 | 路径 | 职责 |
|---|---|---|
| Create | `test/_harness/test_app.dart` | `pumpInkApp` widget test 启动器（MaterialApp + ProviderScope + l10n） |
| Create | `test/_harness/fixtures.dart` | `loadProviderFixture(id, name)` 统一 JSON fixture loader |
| Create | `test/_harness/fake_dio.dart` | `FakeDio.fromFixture(provider, name, {status})` builder |
| Create | `test/_harness/fake_providers.dart` | `FakeSubmittable` + `FakePollable` + `FakeKeyValidatable`，行为脚本化 |
| Create | `test/_harness/fake_clock.dart` | `FakeClock` + clockProvider override |
| Create | `test/_harness/fake_secure_storage.dart` | 内存版 SecureStorageService |
| Create | `test/_harness/fake_repositories.dart` | InMemoryNodeRepository / EdgeRepository / CanvasRepository / ProjectRepository |
| Create | `test/_harness/golden_scaffold.dart` | 标准 surface size + 字体 stub + 主题装配 |
| Create | `test/_harness/README.md` | 用法 + 反模式清单 |
| Modify | `test/storage/schema/pg_test_harness.dart` → `test/_harness/pg.dart` | 迁移命名（保留旧路径 re-export 一个 sprint 后删） |

**Refactor 调用方（按 Task 拆）：**

| Task | 调用方文件 | 改造内容 |
|---|---|---|
| 1 | 5 个 widget test | `MaterialApp(...) → pumpInkApp(tester, ...)` |
| 1 | 7 个 provider test | `_loadFixture(...) → loadProviderFixture(id, name)` |
| 2 | provider_registry_test + 拟新增的 custom_provider_registry_test | 用 `FakeSubmittable` 替代手写 mock |
| 3 | job_queue_service_test + 后续 polling 类测试 | 用 `FakeClock` 替代 `Future.delayed` |
| 3 | settings api_keys_section_test | 用 `FakeSecureStorage` |
| 4 | 新增 1 个 golden widget test | 用 `goldenScaffold` |

---

## Task 1: test_app + fixtures（吃掉最高频两个重复）

**Files:**
- Create: `test/_harness/test_app.dart`
- Create: `test/_harness/fixtures.dart`
- Create: `test/_harness/README.md`
- Modify: 5 个 widget test 调用方
- Modify: 7 个 provider test 调用方

**`test_app.dart` 设计：**
```dart
/// 标准 widget test 启动器。所有 InkFrame widget test 都该走这个。
///
/// 默认：dark 主题 / textScale=1 / locale=en / 全套 l10n delegates。
/// 通过参数覆盖：overrides 注入 ProviderScope，surfaceSize 改窗口大小（自动 tearDown）。
Future<void> pumpInkApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  InkThemeVariant variant = InkThemeVariant.dark,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(variant: variant, textScale: textScale),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}
```

**`fixtures.dart` 设计：**
```dart
/// 加载 `test/fixtures/providers/<providerId>/<name>.json`。
/// 文件不存在 → fail with 清晰提示，不抛 IO 异常。
Map<String, Object?> loadProviderFixture(String providerId, String name) {
  final path = 'test/fixtures/providers/$providerId/$name.json';
  final file = File(path);
  if (!file.existsSync()) {
    fail('fixture not found: $path');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

/// 文本形式（用于 Response.fromJson 之外的场景）。
String loadProviderFixtureRaw(String providerId, String name) { ... }
```

**Steps:**
- [ ] **Step 1: 写 harness 自身的契约测试** — `test/_harness/_harness_test.dart`（命名特殊，确保 _harness_test.dart 仍被识别），断言 `pumpInkApp` 装配后能 find `MaterialApp`，`loadProviderFixture` 找不到文件时 `fail` 而非崩溃
- [ ] **Step 2: 落 test_app.dart + fixtures.dart + README.md**
- [ ] **Step 3: 改造 5 个 widget test 调用方**
- [ ] **Step 4: 改造 7 个 provider test 调用方**
- [ ] **Step 5: 全量 `flutter test` 绿**

**Verification:**
```powershell
flutter test test/_harness/_harness_test.dart
flutter test  # 全量
```

---

## Task 2: FakeDio + FakeProviders（拉通 provider 系测试）

**Files:**
- Create: `test/_harness/fake_dio.dart`
- Create: `test/_harness/fake_providers.dart`
- Modify: `test/providers/provider_registry_test.dart`

**`fake_dio.dart` 设计：**
```dart
/// 基于 http_mock_adapter 的薄封装。常见模式直接给 builder：
class FakeDio {
  /// 200 + fixture body
  static Dio fromFixture(String providerId, String name,
      {required String baseUrl, required String path}) { ... }

  /// 任意 status + body
  static Dio respondWith(int status, Map<String, Object?> body,
      {required String baseUrl, required String path}) { ... }

  /// 抛 DioException（用于错误映射测试）
  static Dio throws(DioException error, {required String baseUrl, required String path}) { ... }

  /// 多步序列：第 N 次调用返回第 N 个响应（用于 poll 退避测试）
  static Dio sequence(List<DioResponse> responses,
      {required String baseUrl, required String path}) { ... }
}
```

**`fake_providers.dart` 设计：**
```dart
/// 行为脚本化的 Submittable，用于 ProviderRegistry / GenerationController 测试。
class FakeSubmittable implements Submittable {
  FakeSubmittable({
    required this.capabilities,
    this.onSubmit,
  });

  @override
  final ProviderCapabilities capabilities;

  /// 默认实现：返回 'local://fake-job-<count>'，可用 onSubmit 覆盖
  final Future<JobId> Function(GenerationTask)? onSubmit;

  int submitCallCount = 0;
  final List<GenerationTask> submittedTasks = [];

  @override
  Future<JobId> submit(GenerationTask task) async {
    submitCallCount += 1;
    submittedTasks.add(task);
    if (onSubmit != null) return await onSubmit!(task);
    return 'local://fake-job-$submitCallCount';
  }
}

class FakePollable implements Pollable { ... }
class FakeKeyValidatable implements KeyValidatable { ... }

/// 三接口组合的快捷类，覆盖大多数测试场景
class FakeProvider implements Submittable, Pollable, KeyValidatable { ... }

/// 构造一个标准 ProviderCapabilities（image / global / 默认数值）。
ProviderCapabilities fakeImageCapabilities({String id = 'fake-image', ...}) { ... }
ProviderCapabilities fakeVideoCapabilities({String id = 'fake-video', ...}) { ... }
```

**关键不变量：** Fake 必须实现真接口，不能用 `dynamic` / `Object` 偷懒。这样 ProviderRegistry 的 LSP 校验也能跑过。

**Steps:**
- [ ] **Step 1: 写 fake 自身契约测试** — 断言 FakeSubmittable 满足 Submittable 接口、submitCallCount 正确累加、submittedTasks 顺序
- [ ] **Step 2: 落 fake_dio.dart + fake_providers.dart**
- [ ] **Step 3: 改造 provider_registry_test 调用方**

---

## Task 3: FakeClock + FakeSecureStorage + FakeRepositories

**Files:**
- Create: `test/_harness/fake_clock.dart`
- Create: `test/_harness/fake_secure_storage.dart`
- Create: `test/_harness/fake_repositories.dart`

**`fake_clock.dart`：** 需要 lib 侧配套——先看 lib/core/di/clock.dart 是否已有 `clockProvider` 抽象。如有：直接 fake；如无：本 task 顺手补 `Clock` 接口 + 默认 `SystemClock` 实现 + DI provider。

```dart
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime(2026, 1, 1);
  DateTime _now;
  @override DateTime now() => _now;
  void advance(Duration d) { _now = _now.add(d); }
}
```

**`fake_secure_storage.dart`：**
```dart
class FakeSecureStorage implements SecureStorageService {
  final Map<String, String> _store = {};
  @override Future<String?> read(String key) async => _store[key];
  @override Future<void> write(String key, String value) async { _store[key] = value; }
  @override Future<void> delete(String key) async { _store.remove(key); }
  @override Future<SecureStorageProbe> probe() async => SecureStorageProbe.available('fake');
}
```

**`fake_repositories.dart`：** 每个 repository 一个 in-memory 实现。所有数据存 `Map<String, T>`，watchAll 用 `StreamController.broadcast()` 推变更。

**Steps:**
- [ ] **Step 1: 核账 clock 抽象**（若缺则顺手补 lib 侧）
- [ ] **Step 2: 写各 fake 的契约测试**
- [ ] **Step 3: 实现三个 fake 文件**
- [ ] **Step 4: 改造 1-2 个 controller test 验证替换可行性**（不要求全量改造，作为可用性验证即可）

---

## Task 4: goldenScaffold + 首个真 golden test + CI 解锁

**Files:**
- Create: `test/_harness/golden_scaffold.dart`
- Create: `test/features/canvas/widgets/node_card_golden_test.dart`（首选目标：node_card 三态：idle / selected / link-source）
- 现有 ci.yml 第 102-108 行的 `if ls test/**/*_golden_test.dart` 占位逻辑保留，会自动 picked up 新文件，**不改 workflow**

**`golden_scaffold.dart` 设计：**
```dart
/// Golden test 专用启动器：固定 surface size，禁用动画，加载真实字体。
Future<void> pumpGoldenScene(
  WidgetTester tester,
  Widget child, {
  required Size size,
  List<Override> overrides = const [],
}) async {
  await loadAppFonts(); // golden_toolkit / 内置字体加载
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}
```

**Golden 字体处理：** Flutter golden test 默认用 Ahem font（方块字），看不出真实效果。需要 pub dependency `golden_toolkit` 提供 `loadAppFonts()`，或自己在 `test/flutter_test_config.dart` 里手动加载 `assets/fonts/*.ttf`。Task 4 落地时决策。

**首个 golden 选 node_card 三态的理由：**
- 视觉密度高，token 体系（amber accent / surface2 / borderSubtle）全覆盖
- 状态机简单，三个变体即可
- 后续 Inspector / EmptyState 加 golden 的成本几乎为零

**Steps:**
- [ ] **Step 1: 决策字体加载方案**（golden_toolkit vs 手动），更新 pubspec.yaml 与 flutter_test_config.dart
- [ ] **Step 2: 落 golden_scaffold.dart**
- [ ] **Step 3: 写 node_card_golden_test.dart 三个 scene**
- [ ] **Step 4: `flutter test --update-goldens` 生成基线 png**
- [ ] **Step 5: CI 验证 golden job 真正跑起来**

---

## 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| Harness 文件被 `flutter test` 当 test 跑 | 低 | `_` 前缀（_harness_test.dart 例外，已显式命名为 test） |
| Refactor 时 widget test 行为变化导致回归 | 中 | Task 1 改造完后跑全量 `flutter test`，失败立刻回滚单个文件 |
| `loadAppFonts` 在 headless CI 上 flaky | 中 | golden_toolkit 已被广泛验证；首次落地仅 1 个 golden 文件，flaky 暴露面小 |
| FakeClock 不能 mock `Future.delayed` | 中 | 文档化：Clock 只管 `now()`，Future.delayed 用 `fakeAsync` package 隔离（必要时 Task 3 顺手引入） |
| 既有测试改造遗漏 → coverage 下降 | 低 | 70% gate 已守门；harness 件本身 exclude 不计 |

---

## Done criteria

- [ ] `test/_harness/` 下 8 个文件全部就位，每个有契约测试
- [ ] 5 个 widget test + 7 个 provider test 全部走 harness 调用
- [ ] `flutter test` 全绿，coverage ≥ 70%
- [ ] CI golden job 不再 echo skip，至少跑 1 个真 golden 用例
- [ ] `test/_harness/README.md` 写清用法 + 反模式（"不要在 harness 里加 production 逻辑"等）
- [ ] custom-providers Task 3/4/5 落地时可直接 `import 'package:inkframe/.../test/_harness/fake_providers.dart'` 拿来用

---

## 后续 sprint 占位

- 引入 `fakeAsync` package 配合 FakeClock，吃掉 Future.delayed
- HTTP 录制回放：给真实 provider 的 fixture 加自动化录制脚本
- Performance test harness：JobQueue / 大画布渲染基线
