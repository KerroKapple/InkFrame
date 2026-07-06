# InkFrame 测试手册 v0.1.0

> **受众**：所有贡献者（人类 + AI agents）
> **权威性**：`ARCHITECTURE.md §12` 的工程化展开。冲突时以本文为准（更具体）
> **目的**：把"测试分层"从抽象约束，落到"写哪个文件、放哪里、怎么跑"的可操作步骤

---

## 目录

1. [测试金字塔与门槛](#1-测试金字塔与门槛)
2. [TDD 节奏（强制）](#2-tdd-节奏强制)
3. [目录结构与命名](#3-目录结构与命名)
4. [单元测试规范](#4-单元测试规范)
5. [Repository 集成测试（真 PG）](#5-repository-集成测试真-pg)
6. [Provider 契约测试](#6-provider-契约测试)
7. [Widget 测试 + Riverpod override](#7-widget-测试--riverpod-override)
8. [Golden 测试](#8-golden-测试)
9. [Mock 边界](#9-mock-边界)
10. [Fixture 与测试数据](#10-fixture-与测试数据)
11. [Hooks / CI 流水线](#11-hooks--ci-流水线)
12. [覆盖率门禁](#12-覆盖率门禁)
13. [Flaky / 慢测处理](#13-flaky--慢测处理)
14. [反模式清单](#14-反模式清单)

---

## 1. 测试金字塔与门槛

| 层 | 工具 | 依赖 | 覆盖率门槛 | 跑在哪 |
|---|---|---|---|---|
| 单元测试 (core / utils / errors) | `flutter_test` | 零外部 | ≥ 70% | pre-commit / pre-push / CI |
| Service 层 | `flutter_test` + Mocktail | Mock Repository | ≥ 70% | pre-push / CI |
| Repository 层 | `flutter_test` + 真 PG | `TEST_PG_URL` | **≥ 75%**（数据层硬门槛）| pre-push (有 PG) / CI |
| Riverpod Provider | `flutter_test` + `ProviderContainer` | override | ≥ 70% | pre-push / CI |
| Widget | `flutter_test` + `ProviderScope` override | fake services | ≥ 70% | pre-push / CI |
| Golden | `golden_toolkit` | Skia 渲染 | 关键 Widget 必须有 | CI（ubuntu，canonical 基线平台） |
| E2E (PRD §29.1 场景 A-H) | 手动 + 录屏 | 完整构建 | Sprint 2 收口 | 发版前 |

**口径：**

- "覆盖率"统一用 `lcov line coverage`，不用 branch coverage
- 数据层 75% 的理由：bug 传播代价最高
- 覆盖率是**最低门槛**不是**目标**——过了就是合格，想冲 85%+ 看 T2（实测 85.0%）

---

## 2. TDD 节奏（强制）

```
1. 写测试 → watch fail (红)
2. 写最简实现 → watch pass (绿)
3. 重构 → 保持绿
```

**硬约束：**

- 先写实现再补测试 = 违规。补出来的测试倾向于测实现细节而非行为
- 测试失败先定位测试是否写对，而不是改测试迎合实现
- 重构阶段**不**加新断言——重构就是不改行为；需要新断言？先回到步骤 1

**Scope 判定：**

- 一个 bug 修复 = 至少 1 个新测试（先复现 bug，再修）
- 一个 feature = 至少一个 happy path + 一个 error path 测试
- 一个纯重构（0 行为变化） = 0 新测试，现有测试必须保持绿

---

## 3. 目录结构与命名

```
test/
├── core/                              # 对应 lib/core/
│   ├── errors/ink_error_test.dart
│   ├── logging/logger_service_test.dart
│   └── di/theme_controller_test.dart
├── services/
│   └── file_resolver_service_test.dart
├── storage/
│   ├── pg_controller_test.dart
│   ├── pg_binary_locator_test.dart
│   ├── migration_runner_integration_test.dart   # _integration 后缀 = 要 PG
│   ├── schema/
│   │   ├── violation_matrix_test.dart
│   │   └── cascade_test.dart
│   └── repositories/
│       └── postgres_repositories_integration_test.dart
├── providers/                         # Provider 契约 + 单测
│   ├── contract/provider_contract_suite.dart   # 公共 suite
│   ├── gemini_image_provider_test.dart
│   └── ...
├── features/                          # 对应 lib/features/
│   └── canvas/providers/canvas_view_model_test.dart
├── widget_test.dart                   # 应用级 smoke
├── fixtures/                          # 共享测试数据
│   └── providers/{id}/*.json
└── helpers/                           # 测试工具
    ├── fake_provider.dart
    ├── fake_repositories.dart
    └── pg_test_harness.dart
```

### 命名约定

| 目标 | 文件名 | 备注 |
|---|---|---|
| 单元/逻辑 | `{subject}_test.dart` | 对应 `lib/` 同层路径 |
| 集成（需 PG / 真 IO） | `{subject}_integration_test.dart` | `_integration` 后缀**硬约束** |
| Golden | `{subject}_golden_test.dart` | CI 在 ubuntu 跑（canonical 基线平台） |
| 契约复用 suite | `{subject}_suite.dart` | 不以 `_test.dart` 结尾，不被 runner 直接跑 |

### 测试名规范

```dart
group('ThemeModeController', () {
  test('starts in dark variant', () { ... });   // 主语 + 动词 + 结果
  test('toggles to light on request', () { ... });
});
```

禁止：`test('works')` / `test('test 1')` / 含变量的名字。

---

## 4. 单元测试规范

### 4.1 模板

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';

void main() {
  group('ProviderError.invalidKey', () {
    test('has invalid_key code', () {
      final e = ProviderError.invalidKey();
      expect(e.code, 'invalid_key');
    });

    test('is not retryable', () {
      expect(ProviderError.invalidKey().isRetryable, isFalse);
    });
  });
}
```

### 4.2 断言规范

- 用 `expect(actual, matcher)`，**禁止** `assert(actual == expected)`
- 布尔值用 `isTrue` / `isFalse` 而非 `equals(true)`
- null 用 `isNull` / `isNotNull`
- 异常用 `throwsA(isA<T>())`

```dart
// ✅
expect(() => parse(''), throwsA(isA<InvalidParameterError>()));

// ❌
try { parse(''); fail('should throw'); } catch (e) { expect(e is Error, true); }
```

### 4.3 一个测试一个断言？

不硬性要求，但一个测试**只验一件事**。涉及多个字段时：

```dart
// ✅ 多字段同一行为
test('new instance has sensible defaults', () {
  final c = Capabilities.defaults();
  expect(c.maxBatchSize, 1);
  expect(c.supportsCancellation, isFalse);
  expect(c.qps, greaterThan(0));
});

// ❌ 把两个行为塞一起
test('defaults and validation', () { ... 20 行 ...});
```

---

## 5. Repository 集成测试（真 PG）

### 5.1 为什么要真 PG

- CHECK 约束、ON DELETE、UNIQUE 等**只有真 PG 能跑出差异**
- T2 的 22 case 违规矩阵 + 4 case 级联 = 100% 真 PG 覆盖
- 详见 `ADR-0001`：嵌入式 PG 的代价换的就是这个测试置信度

### 5.2 环境变量

```bash
# 指向一个可写的测试库
export TEST_PG_URL="postgres://inkframe:inkframe@127.0.0.1:5432/inkframe_test"
```

未设置时：集成测试**跳过**（打印 `TEST_PG_URL 未设置，跳过真 PG 集成测试`），单元测试继续跑。

### 5.3 起库命令

```bash
# 本地 docker 起一个 17-alpine（与 CI 对齐）
docker run --rm -d --name inkframe-pg \
  -e POSTGRES_USER=inkframe -e POSTGRES_PASSWORD=inkframe -e POSTGRES_DB=inkframe_test \
  -p 5432:5432 postgres:17-alpine

# CI 使用 GitHub Actions service container（见 .github/workflows/ci.yml）
```

### 5.4 Harness

`test/helpers/pg_test_harness.dart` 负责：

1. 连接 `TEST_PG_URL`，建独立 schema（`test_{uuid}`），测试结束 drop
2. 跑 migration_runner 初始化到当前 schema_version
3. 每个测试方法开启事务，结束 rollback——**数据不跨测试污染**
4. 提供 `insertTestProject()` / `insertTestNode()` 等 seeding helper

```dart
test('删 project → canvases CASCADE', () async {
  await harness.run((conn) async {
    final pid = await harness.insertTestProject();
    final cid = await harness.insertTestCanvas(projectId: pid);

    await conn.execute('DELETE FROM projects WHERE id = \$1', parameters: [pid]);

    final remaining = await conn.execute(
      'SELECT COUNT(*) FROM canvases WHERE id = \$1',
      parameters: [cid],
    );
    expect(remaining.first[0], 0);
  });
});
```

### 5.5 违规矩阵 (CHECK / UNIQUE) 范式

每个 CHECK / UNIQUE 约束**至少一个 case** — 插入非法值，期望抛 `PostgreSQLException`。命名直接点出违反了哪条约束：

```dart
test('nodes CHECK node_role 非 config/result → 拒绝', () async {
  await expectLater(
    harness.run((c) => c.execute(
      "INSERT INTO nodes (id, canvas_id, node_role, type) VALUES (\$1, \$2, 'bogus', 'text')",
      parameters: [uuid(), cid],
    )),
    throwsA(isA<ServerException>().having((e) => e.code, 'code', '23514')),
  );
});
```

SQLSTATE 速查：

| code | 含义 |
|---|---|
| `23514` | CHECK 违反 |
| `23505` | UNIQUE 违反 |
| `23503` | 外键违反 |

---

## 6. Provider 契约测试

详见 `docs/PROVIDER-API.md §12`，此处只补强约束：

- 每个具体 Provider 除自身单测外，**必须**跑 `providerContractSuite(factory)` 保证接口合规
- Fixture 必须由真 API 采集+脱敏生成，禁止手写（规避"我以为 Kling 会返回这样的 JSON"）
- Provider 单测 mock 的是 **HTTP 适配器** (`http_mock_adapter`)，不是 `FakeProvider` 本身——`FakeProvider` 只给上层服务的测试用

---

## 7. Widget 测试 + Riverpod override

### 7.1 模板

```dart
testWidgets('InkFrameApp boots', (tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(FakeAppPaths()),
          nodeRepositoryProvider.overrideWith((_) => FakeNodeRepository()),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CanvasView), findsOneWidget);
  });
});
```

### 7.2 硬约束

- **只 override 接口，不 override 具体类**——如果要 override `PostgresNodeRepository`，说明 Widget 直接依赖了具体类（违反 SOLID-D）
- **禁止在 Widget 测试里启 PG / 调真实网络**——那是集成测试职责
- `tester.runAsync` 只在真 I/O（文件系统、process）必须时用——能 fake 的就 fake

---

## 8. Golden 测试

### 8.1 范围

**关键 Widget 必须有 golden**：

- 画布节点的所有状态（default / selected / generating / error / success）
- 任务中心抽屉
- 设置各子页
- 所有 `InkButton` / `InkCard` / `InkInput` 变体

### 8.2 生成 / 更新

```bash
# 新增或有意更新 golden
flutter test --update-goldens test/widgets/node_golden_test.dart

# 本地对比
flutter test test/widgets/node_golden_test.dart
# 失败时会在 test/widgets/failures/ 生成 diff 图
```

**PR 规则**：更新 golden 必须在 PR 描述附一张前后对比图；没有视觉说明的 golden diff 视为未知变更，CR block。

### 8.3 平台差异

- Golden 基线的 canonical 平台是 CI 的 ubuntu runner——Windows / macOS 上字体光栅化差异会无限 false positive
- 禁止提交本地 Windows/macOS 生成的基线；用 `.github/workflows/update-goldens.yml`（workflow_dispatch）在 ubuntu 上跑 `--update-goldens` 后自动提交基线
- `node_card_golden_test.dart` 在基线 PNG 存在时自动启用（`_goldensPresent`），CI golden job 在“有基线却 0 测试运行”时硬失败

---

## 9. Mock 边界

```dart
// ✅ Mock 接口
class FakeNodeRepository implements NodeRepository { ... }

// ✅ Mocktail 对接口打桩
when(() => mockNodeRepo.findById(any())).thenAnswer((_) async => fakeRow);

// ❌ Mock 具体类
class FakePostgresNodeRepository extends PostgresNodeRepository { ... }

// ❌ Mock 被测对象的私有方法
// 如果你需要这样做，说明被测对象设计有问题——先重构把它拆开
```

**经验法则：** mock 的层要比被测对象"下一层"，不能同层或跨两层。

---

## 10. Fixture 与测试数据

### 10.1 分类

| 类型 | 位置 | 来源 |
|---|---|---|
| Provider 真 API 响应 | `test/fixtures/providers/{id}/*.json` | 真实 API + 脱敏 |
| Schema DDL | `lib/storage/schema/00X_*.sql` | 生产代码复用 |
| 领域模型样例 | `test/helpers/samples.dart` | 手工构造，工厂函数 |

### 10.2 脱敏规则（Provider fixture）

**去除：** API Key、`groupId`、`user_id`、实际 `task_id`、IP、CDN 签名 URL 参数
**替换：** `task_id` → `FIXTURE_JOB_ID`；`url` → `https://fixture.invalid/...`
**保留：** 错误码、结构、字段顺序

### 10.3 工厂函数

```dart
// test/helpers/samples.dart
Node sampleNode({String? id, NodeStatus status = NodeStatus.idle}) => Node(
  id: id ?? uuid(),
  canvasId: 'cid',
  type: 'image',
  nodeRole: 'config',
  status: status,
  // ... 其余默认值
);
```

**不**用顶层常量 `final kSampleNode = Node(...)` — copyWith 会污染跨测试状态。

---

## 11. Hooks / CI 流水线

### 11.1 三层门禁

| 阶段 | 跑什么 | 时长预算 |
|---|---|---|
| pre-commit | `flutter analyze` + 6 个 check 脚本 (i18n / inline styles / magic strings / direct instantiation / disposable cleanup / updated_at) | < 5s |
| pre-push | `flutter test`（含 runAsync 真 I/O） | < 60s |
| CI (GitHub Actions) | analyze + test + coverage + golden + postgres:17-alpine service | < 8min |

详见 `.github/workflows/ci.yml` 与 `scripts/hooks/`。

### 11.2 PG 集成测试在 CI

```yaml
services:
  postgres:
    image: postgres:17-alpine
    env:
      POSTGRES_USER: inkframe
      POSTGRES_PASSWORD: inkframe
      POSTGRES_DB: inkframe_test
    ports: ['5432:5432']
env:
  TEST_PG_URL: postgres://inkframe:inkframe@localhost:5432/inkframe_test
```

本地 pre-push 没起 PG？集成测试自动跳过并打印提示，**不**算失败——CI 会补上。

### 11.3 CI 失败处置

| 失败类型 | 处置 |
|---|---|
| analyze 0 warning 被破坏 | 修代码，不改规则 |
| 单测红 | 修代码；**禁止** `skip: true` 绕过 |
| 集成红（TEST_PG_URL 跑不通）| 本地 `docker run` 起 PG 复现，不要猜 |
| 覆盖率跌破门槛 | 补测试；门槛不下调 |
| Golden diff | 附前后图，PR 描述说明；无说明直接 block |

---

## 12. 覆盖率门禁

```bash
# 本地生成
flutter test --coverage

# 数据层 ≥ 75%
lcov --extract coverage/lcov.info 'lib/storage/*' -o coverage/storage.info
genhtml coverage/storage.info -o coverage/storage/  # 可视化

# 其余 ≥ 70%
lcov --remove coverage/lcov.info 'lib/storage/*' -o coverage/rest.info
```

**排除**（`coverage.yaml`）：

- `*.g.dart` / `*.freezed.dart`（生成代码）
- `lib/main.dart`（入口 bootstrap，靠 smoke 测覆盖）
- `lib/l10n/generated/`

**不排除**：

- `lib/core/di/*` — 接线必须在 Widget/Provider 测试里自然覆盖
- 所有 abstract interface — 抽象类不计入分母（Dart 行为），不需手动排

---

## 13. Flaky / 慢测处理

### 13.1 Flaky 判定

- 连续 3 次 CI 中有 1+ 次失败，本地至少 5 次跑不稳 → 判定 flaky
- **禁止** `@Retry(3)` 糊弄过去——flaky 是 bug 信号

### 13.2 Quarantine 流程

1. 在 `test/FLAKY.md` 登记：文件路径 + 失败模式 + 怀疑原因
2. 给测试打 `@Tags(['flaky'])`，CI 配置中改为"失败不 block"但仍收集
3. 开 issue / 登记 `docs/internal/tech-debt.md`
4. **7 天内必须修复或删除**——超期视为债务违约

### 13.3 慢测判定

- 单个 test > 5s → 审查能否拆分或 mock 掉外部 IO
- 集成测 single test > 30s → 分析是否在循环等待

---

## 14. 反模式清单

> 任意一条出现在 PR 中，CR block。

1. ❌ `test('works', () { ... })` / `test('test 1', ...)`
2. ❌ 先写实现再补测试（TDD 违反）
3. ❌ `catch (e) { print(e); }` 在测试里 —— 测试应让错误失败而不是打印
4. ❌ `Future.delayed(Duration(seconds: N))` 作为同步等待——用 `tester.pumpAndSettle` / 明确的 completer
5. ❌ 多个测试共享可变全局状态（比如顶层 `final node = Node(...)`）
6. ❌ Mock 具体类而非接口
7. ❌ 修测试去迎合实现——先问是不是行为要求错了
8. ❌ 用 `@skip: true` 绕过 red test
9. ❌ 集成测试文件名不带 `_integration` 后缀——CI 分组靠它识别
10. ❌ 手写 Provider fixture——必须真采集后脱敏
11. ❌ Golden 更新没截图说明
12. ❌ Widget 测试启真 PG 或发真实网络请求
13. ❌ `@Retry(N)` 包装 flaky test——必须 quarantine + 修根因

---

## 变更记录

| 日期 | 版本 | 内容 | 作者 |
|---|---|---|---|
| 2026-04-15 | v0.1.0 | 初版，基于 T1/T2 实战提炼；对齐 ARCHITECTURE §12 | P9 |
