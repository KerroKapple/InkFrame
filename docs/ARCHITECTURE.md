# InkFrame v0.1.0 — Architecture Reference

> **受众：** 所有参与本项目的开发者（人类 + AI agents）。
> **权威性：** 本文档与 `CLAUDE.md` 同等效力。冲突时以本文为准（本文更具体）。
> **输入来源：** `CLAUDE.md` + PRD §3 / §10 / §21 + 历次架构决策记录。

---

## 目录

1. [分层架构与依赖方向](#1-分层架构与依赖方向)
2. [Riverpod DI 模式与生命周期矩阵](#2-riverpod-di-模式与生命周期矩阵)
3. [SOLID 五条在本项目的落地举例](#3-solid-五条在本项目的落地举例)
4. [错误体系](#4-错误体系)
5. [并发与限流](#5-并发与限流)
6. [文件路径解析契约](#6-文件路径解析契约)
7. [设计 Token 系统与主题切换](#7-设计-token-系统与主题切换)
8. [i18n 架构与 ARB 一致性门禁](#8-i18n-架构与-arb-一致性门禁)
9. [密钥存储](#9-密钥存储)
10. [性能降级控制器](#10-性能降级控制器)
11. [A11y 分层责任与键盘覆盖率门禁](#11-a11y-分层责任与键盘覆盖率门禁)
12. [测试策略与分层](#12-测试策略与分层)
13. [日志规范](#13-日志规范)
14. [构建与发布流水线](#14-构建与发布流水线)

---

## 1. 分层架构与依赖方向

### 1.1 五层模型

```
┌─────────────────────────────────────────────────────┐
│  Widget Layer                                       │
│  lib/features/*/widgets/  lib/theme/components/     │
│  职责：渲染状态，分发用户事件。禁止含业务逻辑。      │
├─────────────────────────────────────────────────────┤
│  ViewModel Layer  (Riverpod Notifier)               │
│  lib/features/*/providers/                          │
│  职责：编排 Service 调用，管理 UI 状态。             │
│  禁止：直接操作数据库、直接调用 Provider API。       │
├─────────────────────────────────────────────────────┤
│  Service Layer                                      │
│  lib/features/*/services/  lib/services/            │
│  职责：领域业务逻辑。纯 Dart，零 Flutter import。    │
│  禁止：import flutter/material.dart 或任何 Widget。  │
├─────────────────────────────────────────────────────┤
│  Repository Layer                                   │
│  lib/storage/repositories/                          │
│  职责：数据访问抽象。接口定义在 core/interfaces/。   │
│  禁止：含业务判断，仅做数据转换与 SQL 执行。         │
├─────────────────────────────────────────────────────┤
│  Infrastructure Layer                               │
│  lib/storage/  lib/providers/  platform/            │
│  PostgreSQL / dio / ffmpeg / Keychain               │
│  禁止：被 Service 层以上直接 import 具体实现。       │
└─────────────────────────────────────────────────────┘
```

**唯一规则：依赖只向下流动。** 任何一层不得 import 上层的任何符号。

### 1.2 目录与层的对应关系

```
lib/
├── core/
│   ├── interfaces/      # 跨层抽象接口（无实现）
│   ├── errors/          # InkError sealed hierarchy
│   ├── constants/       # 枚举、常量（无副作用）
│   ├── di/              # Riverpod Provider 定义（DI 接线）
│   ├── models/          # 领域模型（freezed）
│   ├── logging/         # LoggerService（接口 + FileLoggerService 实现）
│   └── paths/           # AppPaths —— app 已知目录
├── features/
│   └── {feature}/
│       ├── widgets/     # Widget Layer
│       ├── providers/   # ViewModel Layer
│       └── services/    # Service Layer（feature 专属）
├── storage/
│   ├── repositories/    # Repository Layer 具体实现
│   ├── schema/          # DDL + schema_version
│   └── migrations/      # 增量迁移脚本
├── providers/           # AI Provider 适配器（Infrastructure）
├── services/            # 应用级 Service（跨 feature）
└── theme/               # 设计 Token + InkColors + 组件
```

### 1.3 跨 feature 通信规则

Feature 之间**不得互相 import**。跨 feature 通信通过以下方式：

1. **共享 Riverpod Provider**：定义在 `lib/core/di/` 或 `lib/services/`，双方都 watch 同一个 Provider。当前唯一手段——"生成完成"等跨 feature 通知也走共享 Provider 的 Stream（如 `JobHandle.statusStream`）。
2. **导航参数**：通过路由传递简单值（ID、枚举），不传复杂对象。

> **Planned**：独立事件总线（`lib/services/event_bus.dart`）尚未实现；确有一对多广播需求时再立项，不提前造设施。
>
> ⚠️ **已知违例（2026-07 审计）**：`canvas → generation` 存在 18 处跨 feature import（11 个文件，
> 集中在 `job_state.dart` / `jobs_registry.dart` / `batch_results_controller.dart` / `cost_estimator.dart`
> 等——生成状态与画布 UI 深度耦合的历史结果）。已登记 `docs/BOARD.md` 停车场，待 import 边界 lint
> （custom_lint 卡点解除后）收口：或上提共享模型到 `core/`，或建 lint 白名单逐步清零。新增代码**不得**
> 以此为先例。

---

## 2. Riverpod DI 模式与生命周期矩阵

### 2.1 核心规则

- **所有外部依赖通过 Riverpod Provider 注入**，禁止 `new ConcreteClass()` 出现在 Widget / ViewModel / Service 层。
- 每个可注入的服务必须有对应的抽象接口（`abstract class`），具体实现通过 Provider 绑定。
- `lib/core/di/` 是唯一的接线文件夹，所有 Provider 定义集中于此，不散落各处。

```dart
// ✅ 正确：接口在 core/interfaces/，实现在 storage/repositories/，接线在 core/di/
// core/interfaces/node_repository.dart
abstract class NodeRepository {
  Future<Node> findById(String id);
  Future<void> upsert(Node node);
}

// core/di/repositories.dart —— 真实风格：手写顶层 Provider（keepAlive 是顶层默认）
final nodeRepositoryProvider = FutureProvider<NodeRepository>((ref) async {
  final pool = await ref.watch(pgMigratedPoolProvider.future);
  return PostgresNodeRepository(pool);
}, name: 'nodeRepositoryProvider');

// ❌ 错误：在 Widget 或 Service 里直接 new
class GenerationService {
  final _repo = PostgresNodeRepository(PostgresDatabase()); // 违规
}
```

> **手写 Provider 是现行风格（决策 D-1，2026-05）**：`riverpod_generator` codegen（`@riverpod` / `@Riverpod(keepAlive: true)`）**未采用**——build_runner 全量构建当前损坏（analyzer 与 Dart 3.11 dot-shorthand 冲突，见 `docs/BOARD.md` 停车场 / `BLOCKERS-2026-07-06.md` §2）。codegen 待卡点解除后随 Riverpod 3 迁移一并评估；在那之前本节所有示例以手写风格为准。

### 2.2 生命周期矩阵

| 生命周期 | 手写 Provider 写法 | 适用场景 | 典型示例（真实 DI 名） |
|---------|------------------|---------|---------|
| **app-scoped 单例** | 顶层 `final x = Provider<T>(...)` / `FutureProvider<T>(...)`（顶层默认即 keepAlive） | 整个 app 生命周期内唯一 | `pgControllerProvider` / `pgMigratedPoolProvider`（`core/di/database.dart`）、`jobQueueServiceProvider`（`core/di/job_queue.dart`）、`secureStorageServiceProvider` |
| **feature-scoped** | `NotifierProvider.autoDispose<...>` 等 `.autoDispose` 变体 | 随 Widget 树挂载/卸载 | Canvas / Inspector 各 ViewModel（`lib/features/*/providers/`） |
| **参数化** | `.family` 变体 | 同类但不同实例 | `nodeActiveJobProvider(nodeId)` 一类 |
| **异步单次** | `FutureProvider.autoDispose` | 一次性请求，结果缓存在 Widget 树内 | 单个节点详情加载 |

**清理规则（无一例外）：**

```dart
// keepAlive Provider 必须注册 onDispose（真实例：core/di/job_queue.dart）
final jobQueueServiceProvider = FutureProvider<JobQueueService>((ref) async {
  final service = InMemoryJobQueueService(/* 注入 registry / repo / resolver ... */);
  await service.init();
  ref.onDispose(service.dispose); // ← 必须
  return service;
});

// autoDispose Provider 中的 StreamSubscription 必须取消
class CanvasViewModel extends AutoDisposeFamilyNotifier<CanvasState, String> {
  StreamSubscription<Object?>? _sub;

  @override
  CanvasState build(String canvasId) {
    ref.onDispose(() => _sub?.cancel()); // ← 必须
    _sub = _listenToChanges(canvasId);
    return const CanvasState.loading();
  }
}
```

### 2.3 禁止模式

```dart
// ❌ 静态单例
class DatabaseConnection {
  static final instance = DatabaseConnection._(); // 禁止
}

// ❌ ServiceLocator
final locator = GetIt.instance; // 禁止
locator<NodeRepository>().findById(id);

// ❌ ref.read() 在 build() 里
Widget build(BuildContext context, WidgetRef ref) {
  final vm = ref.read(canvasViewModelProvider); // 禁止，应用 ref.watch
}

// ❌ autoDispose Provider 持有跨请求共享状态
class TempNotifier extends AutoDisposeNotifier<TempState> {
  static final _sharedCache = <String, Node>{}; // 禁止，static = 跨 autoDispose 实例共享
}
```

---

## 3. SOLID 五条在本项目的落地举例

### S — 单一职责

每个文件做一件事。违规信号：文件超过 200 行，或文件名含 "And" / "Manager" / "Helper"。

```
✅ canvas_viewport_notifier.dart   → 仅管视口状态（缩放/平移）
✅ node_generation_service.dart    → 仅负责生成流程编排
✅ postgres_node_repository.dart   → 仅做节点的 SQL 操作

❌ canvas_manager.dart             → 同时管视口 + 节点 + 连线 + 保存
```

### O — 开闭原则

通过接口扩展，不修改已有代码。

```dart
// 添加新 Provider = 新建一个文件 + 在 core/di/providers.dart 注册一行，
// 零改动既有 Provider / Service 代码（接口见下方 I 节的四接口拆分）

// ✅ 新增 Provider 只需新建文件
class SeedanceProvider implements Submittable, Pollable, KeyValidatable { ... }

// ❌ 违反 OCP：在现有逻辑里加分支
Future<JobId> submit(task) {
  if (task.providerId == 'seedance') { ... }  // 每次加 Provider 都要改这里
  else if (task.providerId == 'kling-v3') { ... }
}
```

### L — 里氏替换

所有实现必须完整履行接口契约，不能在实现类里抛 `UnimplementedError`。

```dart
// ❌ 违反 LSP：接口承诺的能力，实现类无法履行时必须拆分接口
class SimpleProvider implements GenerationProvider {
  @override
  Future<void> cancel(JobId id) => throw UnimplementedError(); // 违规
}

// ✅ 通过接口隔离解决（见下）
```

### I — 接口隔离

按能力维度拆分接口，不强迫实现类实现它不支持的方法。

```dart
// lib/core/interfaces/generation_provider.dart（真实四接口）
abstract class Submittable {
  ProviderCapabilities get capabilities;
  Future<JobId> submit(GenerationTask task);
}
abstract class Pollable     { Future<JobStatus> poll(JobId id); }
abstract class Cancellable  { Future<void> cancel(JobId id); }
abstract class KeyValidatable {
  Future<KeyValidationResult> validateApiKey(String key);
}

// 当前所有 Provider 都实现这三个（同步 Provider 的 poll 走 inlineBytes cache）
class OpenAIImageProvider implements Submittable, Pollable, KeyValidatable {}

// 支持取消的 Provider 再加 Cancellable（目前没有，接口保留为扩展点）
```

> 历史版本曾有第 5 个接口 `QuotaAware`，已删除；配额展示属 ROADMAP。

### D — 依赖倒置

高层模块依赖抽象，不依赖具体实现。

```dart
// ✅ Service 层依赖接口，不知道具体实现是什么
class NodeGenerationService {
  final Submittable _provider;
  final NodeRepository _repo;

  NodeGenerationService(this._provider, this._repo); // 接口注入

  Future<void> generate(GenerationTask task) async {
    final jobId = await _provider.submit(task); // 不知道是 Kling 还是 Gemini
    await _repo.upsert(task.resultNode.copyWith(status: NodeStatus.submitted));
  }
}

// ❌ 依赖具体类
class NodeGenerationService {
  final KlingProvider _kling = KlingProvider(); // 违规，硬编码具体实现
}
```

---

## 4. 错误体系

### 4.1 InkError sealed hierarchy

所有跨层传播的错误必须是 `InkError` 的子类型。禁止裸 `Exception` 或 `String` 跨层传递。

```dart
// lib/core/errors/ink_error.dart
enum InkErrorCode {
  invalidKey('invalid_key'),
  insufficientBalance('insufficient_balance'),
  contentPolicy('content_policy'),
  invalidParameter('invalid_parameter'),
  networkTimeout('network_timeout'),
  networkOffline('network_offline'),
  providerServer('provider_5xx'),
  providerBusy('provider_busy'),
  providerInvalidResponse('provider_invalid_response'),
  pollTimeout('poll_timeout'),
  downloadFailed('download_failed'),
  localIOError('local_io_error'),
  cancelledByUser('cancelled_by_user'),
  cancelledOnExit('cancelled_on_exit'),
  unknown('unknown');

  const InkErrorCode(this.wire);
  final String wire;  // DB / 日志 / 跨进程的字符串 code
}

@immutable
sealed class InkError implements Exception {
  const InkError({
    required this.code,
    this.extra = const <String, Object?>{},
    this.cause,
    this.stackTrace,
  });

  final InkErrorCode code;
  final Map<String, Object?> extra;  // job_id / provider_id / status_code 等
  final Object? cause;                // 原始异常，仅用于日志
  final StackTrace? stackTrace;

  String get messageKey => kInkErrorMessageKeys[code]!; // ARB key，UI 层用 context.l10n 渲染
  bool get retryable => _retryable.contains(code);      // 是否可重试（影响 JobQueue 行为）
}

// Provider / 鉴权 / 配额 / 参数 / Provider 5xx / Busy / 响应结构不符 / Poll 超时
final class ProviderError extends InkError {
  const ProviderError({required super.code, super.extra, super.cause, super.stackTrace});
}

// 网络层（本机 / 链路 / TLS / 代理）：network_timeout / network_offline
final class NetworkError extends InkError {
  const NetworkError({required super.code, super.extra, super.cause, super.stackTrace});
}

// 产物下载（生成成功但取文件失败）
final class DownloadError extends InkError {
  const DownloadError({super.extra, super.cause, super.stackTrace})
      : super(code: InkErrorCode.downloadFailed);
}

// 本地 IO（磁盘满 / 权限拒绝 / 路径不存在）
final class LocalIOError extends InkError {
  const LocalIOError({super.extra, super.cause, super.stackTrace})
      : super(code: InkErrorCode.localIOError);
}

// 取消（用户主动 / 应用退出）
final class CancelledError extends InkError {
  const CancelledError.byUser({super.extra}) : super(code: InkErrorCode.cancelledByUser);
  const CancelledError.onExit({super.extra}) : super(code: InkErrorCode.cancelledOnExit);
}

// 兜底：未归类异常，必须带 cause 以便诊断
final class UnknownError extends InkError {
  const UnknownError({required Object super.cause, super.stackTrace, super.extra})
      : super(code: InkErrorCode.unknown);
}
```

`messageKey` 与 `retryable` 由顶层 `kInkErrorMessageKeys`（公开，供 `ink_error_i18n_test`
做"每 code 有 key 且 key 在 ARB 内"闸门）/ `_retryable` 表按 code 静态查表（`lib/core/errors/ink_error.dart`），
子类不重写、不通过构造参数注入——新增 code 改两张表即可，子类层级保持稳定。

**完整 15 个错误码**（PRD §10.6 的 14 个 + `provider_invalid_response`——远端报终态成功却无产物 URL，确定性失败不可重试，避免轮询风暴）：

| code (`wire`) | 子类 | retryable | messageKey (ARB) |
|---------------|------|-----------|------------------|
| `invalid_key` | ProviderError | false | `errorInvalidKey` |
| `insufficient_balance` | ProviderError | false | `errorInsufficientBalance` |
| `content_policy` | ProviderError | false | `errorContentPolicy` |
| `invalid_parameter` | ProviderError | false | `errorInvalidParameter` |
| `provider_5xx` | ProviderError | true | `errorProviderServer` |
| `provider_busy` | ProviderError | true | `errorProviderBusy` |
| `provider_invalid_response` | ProviderError | false | `errorProviderInvalidResponse` |
| `poll_timeout` | ProviderError | false | `errorPollTimeout` |
| `network_timeout` | NetworkError | true | `errorNetworkTimeout` |
| `network_offline` | NetworkError | true | `errorNetworkOffline` |
| `download_failed` | DownloadError | true | `errorDownloadFailed` |
| `local_io_error` | LocalIOError | false | `errorLocalIO` |
| `cancelled_by_user` | CancelledError | false | `errorCancelled` |
| `cancelled_on_exit` | CancelledError | false | `errorCancelledOnExit` |
| `unknown` | UnknownError | false | `errorUnknown` |

**体系外错误（不在 InkError 层级内，各有明确定位）：**

- **`PathSecurityError`**（`lib/core/interfaces/file_resolver_service.dart`，`ArgumentError` 子类）：
  路径穿越/绝对路径/空串/控制字符/越界——**编程契约错**，不是运行时业务错误。服务边界（如
  JobQueueService 落盘链路）统一翻译为 `LocalIOError(extra.reason='unsafe_path')` 再入 InkError
  体系；**渲染路径的 widget 允许只捕它**做占位兜底（node_card / batch_results_grid /
  gallery_tile 等）——这是 §4.2「Widget 层禁 try-catch」的**显式豁免**，且只豁免这一种。
- **`GenerationError` 族**（`lib/features/generation/generation_controller.dart`，sealed：
  `MissingApiKeyError` / `InvalidGenerationConfigError` / `ProviderNotRegisteredError`）：
  提交前置校验失败，属 UI 可直接消化的领域错误，不落 `jobs.error_code`，不进 InkError 层级。

### 4.2 跨层传播规则

```
Infrastructure 层   → 抛 InkError 子类（不泄露 PostgreSQL / dio 原生异常）
Repository 层       → catch 基础设施异常，包装为 LocalIOError / UnknownError 后重新抛出
Service 层          → catch InkError，判断 retryable，决定重试或上报
ViewModel 层        → catch InkError，写入 AsyncValue.error(inkError)，不再 catch
Widget 层           → 读取 AsyncValue.error，用 messageKey 显示 i18n 错误信息

禁止：
- catch(e) 或 catch(Exception e)（必须 catch 具体 InkError 子类）
- catch 块只有 print/debugPrint（必须上报或重抛）
- Widget 层 try-catch（Widget 不处理业务错误，只渲染）
```

### 4.3 AsyncValue 使用规范

```dart
// ✅ ViewModel 层：用 AsyncValue.guard 自动捕获并转换（手写 Notifier 风格）
class GenerationViewModel extends AutoDisposeNotifier<AsyncValue<void>> {
  Future<void> generate(GenerationTask task) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.generate(task));
    // guard 自动把异常包进 AsyncValue.error
  }
}

// ✅ Widget 层：.when() 必须覆盖三态
ref.watch(generationViewModelProvider).when(
  data:    (_)       => GenerationSuccessView(),
  loading: ()        => const CircularProgressIndicator(),
  error:   (e, _)    => InkErrorBanner(error: e as InkError),
);

// ❌ 禁止：强制解包
final result = ref.watch(someProvider).value!; // 可能是 loading 或 error 态
```

---

## 5. 并发与限流

### 5.1 JobQueueService — 双层并发控制

`JobQueueService` 是 app-scoped keepAlive 单例（实现 `lib/services/job_queue_service.dart` 的 `InMemoryJobQueueService`），横跨所有画布和项目。

> **LB-03 结构（编排器 < 500 行 + 三协作者）**：`InMemoryJobQueueService` 只保留调度、单任务状态机与 cancel 竞态裁决（`_lostToCancel` / `_arbitrate`），落盘与写库经构造注入的协作者完成：
> - `lib/services/job_queue/job_media_persister.dart` —— `JobMediaPersister`（接口在 `lib/core/interfaces/job_media_persister.dart`）：inlineBytes / remoteUrls 落盘 + 批量 slot 收敛（`convergeSlots` / `convergeSlotsAfterTerminal`）。依赖未注入时注入 `NullJobMediaPersister`（null-object 全 no-op），编排器不再判空分支。
> - `lib/services/job_queue/job_state_persister.dart` —— `JobStatePersister`：`jobs` 表写库漏斗（`persistTransition` / `persistUpdate` / `persistFailure` / `persistTimeout` / `persistCancel`）与启动孤儿回收 `init()`。`affectedRows`(int?) 语义严格保持——`0` = 被抢写 / 行不存在，`null` = 未注入 repo（纯内存），编排器据此做 cancel 竞态裁决。
> - `lib/services/job_queue/job_handle_impl.dart` —— `JobHandleImpl`：`JobStatus` 流的 last-value 重放 + `done` completer。
> - `lib/services/job_queue/job_queue_util.dart` —— 共享内件：`RunningJob` 运行态值对象、`lostToCancel` 裁决谓词（单一真相源）、`truncate`、日志 module 常量。

```
全局并发上限（构造参数 globalConcurrency，默认 2）
      ↕ min()
Per-Provider 并发上限（ProviderCapabilities.maxConcurrentJobs）
  gemini-image=1 / openai-image=1 / stability-image-core=1
  wanx-image=2 / 视频系（wanx-t2v/i2v/r2v、kling-v3、kling-v3-omni）=1
  custom:*（协议模板派生，openai-image 模板）=1

实际可调度数 = min(全局剩余槽位, per-provider 剩余槽位)
```

> **Planned (b4)**：UI 性能档位 → `globalConcurrency` 动态联动（省电 / 均衡 / 性能 / 极致 = 1/2/3/4），目前未实现，`globalConcurrency` 固定为构造时注入值。`PerformanceTier` 枚举与 `PerformanceDegradationController` 仍属 ROADMAP。

**调度状态机（`jobs.status`，schema 见 `lib/storage/schema/001_init.sql:156-158`）：**

```
pending ──► submitted ──► polling ──► success
                 │              │  ╲
                 │              │   ╲► error
                 │              │    ╲► timeout
                 ▼              ▼     ╲
              cancelled  ◄──────────── (任何阶段，含 app 退出)
```

`jobs.status` 的 CHECK 取值恰好是 7 个：`pending / submitted / polling / success / error / cancelled / timeout`。**末态只有一个 `cancelled`**；取消原因由 `jobs.error_code` 区分：

- `cancelled_by_user`：用户主动调用 `cancel(jobId)`（`InMemoryJobQueueService.cancel`，写入见 `JobStatePersister.persistCancel`）。
- `cancelled_on_exit`：app 启动时对上次未结束的 `pending / submitted / polling` 行做扫尾（`JobStatePersister.init()`，一条 bulkTransition）。启动期同时做两件收尾：孤儿 batch slot 收敛 `finalizeAllPending`（见下方「批量 slot 收敛」）与 jobs 表 housekeeping purge（`purgeExpired` 30 天保留 + `purgePerCanvasCap` 单画布 500 条，失败不阻断启动）。

**出队策略：** FIFO，同 provider 按 `created_at` 升序；跨 provider 抢占全局槽位也按 FIFO，被 per-provider 上限卡住的 pending 会让位给后面 provider 槽位有空的任务（`_pickNextSchedulable`）。

**Cancel 性能 invariant：**

- `cancel(jobId)` 对 pending 队列**摊还 O(1)**（与 pending 长度无关），对 running 任务为 O(1) + provider cancel 网络往返。
- 数据结构：`Queue<_PendingJob> _pending` 维持 FIFO，`Map<String, _PendingJob> _pendingIndex` 提供 jobId → 队列条目的 O(1) 索引；cancel 走"软删除"——`_pendingIndex.remove + _PendingJob.cancelled = true`，**不重建 Queue**；dispatch loop 在队头顺手丢弃 cancelled 条目（`_schedule`）。源码顶部「数据结构」注释是契约说明。
- 回归基线：N=10000 pending 全量 cancel < 500 ms（`test/services/job_queue_service_test.dart` 中的 perf 用例）。
- 实现引用：commit `41afffb` (`fix(jobqueue): O(1) cancel via pendingIndex + soft-delete`)，并入 PR #86。修改这块数据结构前先看测试与本节 invariant。

**批量 slot 收敛（batch_size > 1）：**

批量任务在 `jobs` 状态机之下再挂一层 **slot 子状态机**（`batch_results` 表，表侧注记见
DATABASE.md「batch_results 生命周期」，本节为语义正本）：提交事务预建 N 个 `generating`
slot 占位行 → JobQueue 下载阶段逐 slot 落终态（成功 → `success` + `output_url`；失败 →
`error` + `error_code`；取消 → `cancelled`），入口 `JobMediaPersister.convergeSlots` →
`BatchResultRepository.finalizePendingByJob`。三条 invariant：

1. **slot 只从 `generating` 单向收敛**——终态 slot（success/error/cancelled）绝不被改写，
   条件批量 UPDATE 只圈 `status = 'generating'` 行。
2. **cancel / error 保留已 success 的 slot**（部分成功拍板语义）：≥1 张成功即整体 job
   `success`，首张成功图作结果节点主图 `image_url`；用户中途取消只翻未完成 slot。
3. **收敛链绝不抛出**——收敛失败仅记 WARN（抛出会跳过 emit、handle 永挂）；启动期
   `JobStatePersister.init()` 的 `finalizeAllPending`（孤儿 slot → cancelled_on_exit）兜底。

### 5.2 ProviderRateLimiter — Token Bucket

每个 Provider 客户端内置独立的 Token Bucket，防止超出 Provider 的 QPS 限制。

```dart
// lib/providers/rate_limiter.dart
class ProviderRateLimiter {
  final int qps;
  final int burst;

  Future<void> acquire(); // 阻塞直到拿到 token，不抛错，不计入 retry_count
}

// 各 Provider 当前值的唯一事实源是其 capabilities.qps / burst，
// 速查表见 docs/PROVIDER-API.md §7.1（gemini-image 2/10、openai-image 2/5、
// stability-image-core 1/3、DashScope 系 1/2）。
// 实例在 lib/core/di/providers.dart 按 providerId 预创建并被 factory 闭包共享。
```

`acquire()` 等待期间：日志记录 DEBUG 级等待时长，对用户透明，不显示任何 UI。

### 5.3 轮询参数（全局默认，Provider 可覆盖）

```dart
// lib/services/job_queue_service.dart —— InMemoryJobQueueService 构造参数默认值
InMemoryJobQueueService({
  // ...
  Duration pollInitialInterval = const Duration(seconds: 3),
  Duration pollMaxInterval = const Duration(seconds: 30),
  double pollBackoffMultiplier = 2.0,
  Duration pollTimeout = const Duration(minutes: 30),
});

// Provider 可在 ProviderCapabilities 中声明覆盖值
// pollInterval: Duration(seconds: 5)  → 覆盖 pollInitialInterval
// pollTimeout:  Duration(minutes: 10) → 覆盖 pollTimeout
```

**可重试白名单：** `network_timeout / network_offline / provider_5xx / provider_busy / download_failed`（事实源：`ink_error.dart` 的 `_retryable` 表，消费侧读 `InkError.retryable`）。
**不可重试：** `invalid_key / insufficient_balance / content_policy / invalid_parameter / provider_invalid_response / poll_timeout / local_io_error / cancelled_by_user / cancelled_on_exit / unknown`。

> **Planned**：自动重试调度（次数上限 + 指数退避）尚未实现（remoteUrls 下载的重试 / 续传亦未实现）；当前可重试错误进 `error` 终态后由 UI "重试"人工触发。

---

## 6. 文件路径解析契约

### 6.1 存储规则

数据库中 **只存相对路径**，按用途分**两个根**。禁止任何层持有绝对路径字符串。

- **canvas 根**（节点产物）：`projects/{projectId}/canvases/{canvasId}/`——`type_config.image_url` 等节点级产物以它为根
- **project 根**（跨画布/项目级产物）：`projects/{projectId}/`——视频导出落 `exports/`、画廊等跨画布读取以它为根（`resolveInProject`）

```
存储值（type_config.image_url）：  "images/node-abc123.png"          # canvas 根相对
存储值（type_config.video_url）：  "videos/node-def456.mp4"          # canvas 根相对
存储值（type_config.thumbnail_url）： "images/node-abc123_thumb.jpg" # canvas 根相对
导出产物 / 跨画布读：              "exports/out.mp4"、"canvases/<c>/videos/<f>.mp4"  # project 根相对

运行时由 FileResolverService 拼接为绝对路径：
  {dataDir}/projects/{projectId}/canvases/{canvasId}/images/node-abc123.png
```

### 6.2 FileResolverService 接口

```dart
// lib/core/interfaces/file_resolver_service.dart（真实签名）
abstract class FileResolverService {
  /// 相对路径 → 绝对 File。相对路径非法时抛 [PathSecurityError]。
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  });

  /// 项目根相对路径 → 绝对 File（守 `projects/{project-id}/` 边界）。
  /// 跨画布/项目级产物（如 `exports/<name>.mp4`、`canvases/<c>/videos/<f>`）
  /// 走此入口；相对路径非法时抛 [PathSecurityError]。
  File resolveInProject({
    required String projectId,
    required String relativePath,
  });

  /// 绝对路径 → 相对路径；源路径不在指定 canvas 根目录内时抛 [PathSecurityError]。
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  });

  /// 返回 canvas 根目录绝对路径（不保证存在）。
  Directory canvasRoot({required String projectId, required String canvasId});
}

/// 非法路径（穿越 / 绝对 / 空 / 控制字符 / 越界）→ 抛这个
class PathSecurityError extends ArgumentError { ... }
```

安全边界：所有绝对路径回写必须校验在 canvas 根目录之内，拒绝 `..` 穿越、绝对路径、空串、控制字符。实现在 `lib/services/file_resolver_service.dart`（`DefaultFileResolverService`）。

### 6.3 dataDir 来源

```dart
// lib/core/di/file_resolver.dart（真实接线）
// 根目录来自 AppPaths（main.dart 在 runApp 前预创建并 override appPathsProvider）
final fileResolverServiceProvider = Provider<FileResolverService>(
  (ref) => DefaultFileResolverService(ref.watch(appPathsProvider)),
);

// 默认根：~/InkFrame（AppPaths 展开为绝对路径）
```

> **Planned**：用户在"设置 → 存储"自定义 dataDir 尚未实现，当前固定走 `AppPaths` 默认根。

### 6.4 文件名清理规则

> **Planned**：独立的 `FileNameSanitizer` 尚未实现。当前落盘文件名由系统按 `{uuid}.{ext}` 生成（不含用户输入），非法路径防护由 §6.2 的 `PathSecurityError` 校验兜底。届时规则：移除路径分隔符 / 控制字符 / 前导点号；保留 CJK；超 200 字符截断保留扩展名；冲突追加 `_1`、`_2` 后缀。

---

## 7. 设计 Token 系统与主题切换

### 7.1 Token 层次

```
Raw values（色值/数值）
    ↓ 定义在 lib/theme/tokens.dart
Semantic tokens（InkColors / InkSpacing / InkRadius 等）
    ↓ 由 InkTheme.of(context) 读取
Component variants（InkCard / InkButton / InkInput 等）
    ↓ lib/theme/components/
Feature widgets（只用 Ink 组件，不碰原始值）
```

**铁律：feature 代码只能用 Ink 组件和 semantic token，不得出现原始色值或数值。**

### 7.2 InkColors 三套主题

```dart
// lib/theme/tokens.dart
class InkColors {
  const InkColors._({
    required this.surface1,
    required this.surface2,
    required this.contentPrimary,
    required this.contentSecondary,
    required this.accent,
    required this.error,
    required this.success,
    required this.warning,
    required this.focusRing,         // A11y §11 新增
    // ... 完整 token 列表
  });

  factory InkColors.dark()  => const InkColors._(
    surface1: Color(0xFF0F0F13),
    surface2: Color(0xFF1C1C24),
    // ...
  );

  factory InkColors.light() => const InkColors._(
    surface1: Color(0xFFFAFAFA),
    surface2: Color(0xFFF0F0F5),
    // ... P0 提供最小可用集，P1 完整打磨
  );

  factory InkColors.highContrast() => const InkColors._(
    surface1: Color(0xFF000000),
    surface2: Color(0xFF1A1A1A),
    contentPrimary: Color(0xFFFFFFFF),
    // ... A11y 高对比度变体
  );
}
```

### 7.3 主题切换机制

```dart
// lib/app.dart
// 监听系统亮度变化，实时切换
Consumer(
  builder: (context, ref, _) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      themeMode: themeMode,
      theme:     InkTheme.buildLight(),
      darkTheme: InkTheme.buildDark(),
    );
  },
)

// "跟随系统"：监听 PlatformDispatcher.platformBrightnessChanged
// 设置优先级：用户手动选择 > 跟随系统
```

### 7.4 禁止模式

```dart
// ❌ 硬编码色值
Container(color: Color(0xFF1A1A2E))

// ❌ 原始 Material 颜色
Text(style: TextStyle(color: Colors.white))

// ❌ 任意 Tailwind 风格字面值（不适用，但记录原则）
// feature 代码里出现任何数字色值均为违规

// ✅ 正确
Container(color: context.inkColors.surface2)
Text(style: context.inkTypography.bodyMedium)
InkCard(child: ...)
```

---

## 8. i18n 架构与 ARB 一致性门禁

### 8.1 文件结构

```
lib/l10n/
├── app_en.arb          # 英文（source of truth，开发语言）
├── app_zh.arb          # 中文（key 集合必须与 en 完全一致）
├── generated/          # flutter gen-l10n 产物（app_localizations*.dart，入 git）
└── l10n_x.dart         # 手写扩展：BuildContext.l10n getter（非生成代码）
```

`AppLocalizations` 由 `flutter gen-l10n` 按根目录 `l10n.yaml`（`output-dir: lib/l10n/generated`）
生成并**提交入库**（非 synthetic package）；所有 UI 通过 `context.l10n.<key>` 触达，由
`l10n_x.dart` 桥接。改 ARB 后必须重跑 `flutter gen-l10n` 并把 `generated/` 一起提交——
stale 生成物只有 pre-push 的全量 `flutter analyze lib test` 能拦住（`flutter test` 编译不到未被
import 的破文件）。

### 8.2 Key 命名规范

```
{feature}_{element}{State?}

示例：
  canvasAddNode              → 画布"添加节点"按钮文字
  generationSubmitButton     → 生成提交按钮
  errorNetworkTimeout        → 网络超时错误提示（对应 InkErrorCode.networkTimeout）
  settingsApiKeyLabel        → 设置页 API Key 标签
  baseStylePreset_cinematic  → 基底风格预设（下划线分隔变体）
```

### 8.3 使用规范

```dart
// ✅ 正确
Text(context.l10n.canvasAddNode)
ToastService.show(context.l10n.generationCompleted(providerName))

// ❌ 硬编码字符串（中英文均禁止）
Text("添加节点")
Text("Add Node")
ToastService.show("Generation complete")
```

**System prompt 不走 i18n —— 必须是英文常量：**

发给 AI Provider 的系统 prompt 是模型契约的一部分，不是面向用户的拷贝。统一以英文常量形式留在 `lib/providers/<provider>_prompts.dart`（短 prompt 可内联在调用点附近）。把 system prompt 翻译成多语言等于按 locale 给模型行为做 A/B 分叉，无法对照推理。

```dart
// ✅ 正确 —— 英文常量
const _kGeminiImageSystemPrompt = '''
You are an image-generation assistant...
''';

// ❌ 错误 —— i18n'd prompt 会随 locale 漂移
final hint = context.l10n.geminiSystemPrompt;
```

如需在 prompt 内**注入**与用户语言相关的文本（例如 "respond in the user's UI language"），把 UI locale code 作为参数传入；prompt 模板本身保持英文。

### 8.4 ARB 一致性门禁（测试化）

原 `check-i18n-coverage.sh` bash hook 已删除，门禁固化为可执行断言：

1. **`test/l10n/arb_hygiene_test.dart`**：en/zh message key 集合双向差集必须为空 + 死 key 检查
2. **`test/core/errors/ink_error_i18n_test.dart`**：每个 `InkErrorCode` 都有 messageKey 且 key 真实存在于 ARB

两者随 pre-push 全量 `flutter test` 与 CI test job 阻断式执行——**CI 端已有兜底**，无需独立 i18n workflow。

**每次 commit 必须满足：en 和 zh 的 key 集合完全一致，无空值。**

### 8.5 新增字符串流程（强制顺序）

```
1. 在 app_en.arb 添加 key + 英文 value
2. 在 app_zh.arb 添加相同 key + 中文 value
3. 运行 flutter gen-l10n
4. 在代码中使用 context.l10n.yourNewKey
5. 两个 ARB 文件必须在同一 commit 中更新
```

---

## 9. 密钥存储

### 9.1 存储规则

API Key、代理密码与嵌入式 PG 超级用户密码（LB-07 SCRAM）**只允许**通过 `SecureStorageService` 存取，不得出现在：

- Dart 源文件
- 配置文件（JSON / YAML / .env）
- 数据库（PostgreSQL）
- 日志文件（打码，见 §13.4）
- Git 仓库（任何路径）

### 9.2 SecureStorageService 接口

```dart
// lib/core/interfaces/secure_storage_service.dart
abstract class SecureStorageService {
  Future<void>    store(String key, String value);
  Future<String?> retrieve(String key);
  Future<void>    delete(String key);
  Future<bool>    exists(String key);
}

// 平台实现（Infrastructure 层）：
// macOS  → flutter_secure_storage → macOS Keychain
// Windows → flutter_secure_storage → Windows Credential Manager

// Key 命名约定（实现见 lib/core/constants/secure_storage_keys.dart）
// provider API key：  'provider.{scope}.api_key'
//   - scope = SecureStorageKeys.scopeOf(providerId)
//   - 同一 API 家族的多个 providerId 折叠为单一 scope（共用 Key，避免重复配置）
//   - 当前家族：dashscope = { wanx-image, wanx-t2v, wanx-i2v, wanx-r2v, kling-v3, kling-v3-omni }
//     → 全部存到 'provider.dashscope.api_key'
//   - 非家族成员 scope 直接等于 providerId（如 'provider.gemini-image.api_key'）
// proxy password：    'network.proxy.password'（无 provider 维度）
// PG 超级用户密码：   'database.pg.password'（LB-07：initdb 时随机生成入库；
//   连接期取出注入 Endpoint。无条目 = 存量 trust 集群，password 传 null，Zero-BC 免迁移）
```

> ⚠️ 新加 Provider 时务必走 `SecureStorageKeys.providerApiKey(providerId)` 工厂方法构造 key，
> 不要散落 `'provider.${providerId}.api_key'` 字面量——否则给家族成员存的会是孤儿 key，存了读不到。

### 9.3 Key 验证缓存

> **Planned**：验证结果缓存尚未实现——当前每次点"验证"都实调 Provider 轻量端点（`validateApiKey` 本身不消耗生成配额）。届时设计：TTL 1 小时；失效条件 = TTL 到期 / 手动重新验证 / Key 被修改删除。

---

## 10. 性能降级控制器

> ⚠️ **Planned —— 本章整体未实现。** `PerformanceTier` / `PerformanceDegradationController` / `FpsMonitor` 在 repo 中均不存在（见 `ROADMAP.md` "稳定 alpha → beta" 性能基线方向，及 §5.1 的 **Planned (b4)** 注）。以下为设计蓝图，实现时以本节为验收基准，落地后删除本横幅。

### 10.1 PerformanceDegradationController

单例 keepAlive，监听系统信号，自动切换 effectiveTier。

```dart
// lib/services/performance_degradation_controller.dart（规划路径；手写 Provider 风格，见 §2.1）
// final performanceDegradationControllerProvider =
//     NotifierProvider<PerformanceDegradationController, PerformanceTier>(
//   PerformanceDegradationController.new,
// );
class PerformanceDegradationController extends Notifier<PerformanceTier> {

  // 基准档位（用户配置）
  PerformanceTier get baseTier => ref.watch(settingsProvider).performanceTier;

  // 实际运行档位（可能因降级低于基准）
  PerformanceTier get effectiveTier => state;

  // 降级信号阈值（Hysteresis 双阈值防抖动）
  // 内存：降级 > 80% 持续 10s，恢复 < 60% 持续 30s
  // 帧率：降级 < 30fps 持续 5s，恢复 > 55fps 持续 30s
  // 磁盘：降级 < 1GB，恢复 > 5GB
}
```

### 10.2 双阈值防抖动矩阵

| 信号 | 降级触发 | 降级持续 | 降级动作 | 恢复触发 | 恢复持续 | 冷却期 |
|------|---------|---------|---------|---------|---------|--------|
| 内存 RSS | > 80% | 10s | 清 LRU 至 50%、缩略图减半 | < 60% | 30s | 60s |
| 帧率（3s 均值）| < 30fps | 5s | 关动画、连线降为直线、禁模糊 | > 55fps | 30s | 60s |
| 磁盘剩余 | < 1GB | 立即 | 停止所有生成，Toast 警告 | > 5GB | 立即 | 60s |

**冷却期：** 每次降级或恢复后 60s 内不再触发同向动作。

### 10.3 effectiveTier 消费

所有需要根据性能调整行为的代码，读取 `effectiveTier`，不读 `baseTier`。

```dart
// ✅ 读 effectiveTier
final config = kPerformanceConfig[ref.watch(performanceTierProvider).effectiveTier]!;
final thumbnailRes = config.thumbnailRes;

// ❌ 绕过降级控制器
final config = kPerformanceConfig[settings.performanceTier]!; // 可能忽略了降级
```

### 10.4 帧率采样

帧率用 **3 秒滑动平均**，不用瞬时帧率。单帧 spike 不触发降级。

```dart
// lib/services/fps_monitor.dart（规划路径）
class FpsMonitor {
  static const _windowDuration = Duration(seconds: 3);
  // 维护一个 3s 内的帧时间戳队列，计算平均 FPS
  double get averageFps { ... }
}
```

---

## 11. A11y 分层责任与键盘覆盖率门禁

### 11.1 分层责任矩阵

| 层 | 职责 | 工具/API |
|----|------|---------|
| Widget Layer | 声明 `Semantics` label、role、state | `Semantics` widget |
| ViewModel Layer | 状态变化时触发 `announce` | `SemanticsService.announce` |
| Theme/Token | 提供 `focusRing` token、高对比度变体 | `InkColors.focusRing` |
| 设置系统 | 暴露"高对比度"开关、字号四档（S/M/L/XL） | `MediaQuery.textScaleFactor` |
| 全局 | 尊重 OS 级"减少动画"偏好 | `MediaQuery.disableAnimations` |

### 11.2 Semantics 必须覆盖的场景

```dart
// 节点状态变化必须 announce
void _onStatusChanged(NodeStatus newStatus) {
  SemanticsService.announce(
    context.l10n.nodeStatusChanged(node.label, newStatus.label),
    TextDirection.ltr,
  );
}

// 所有按钮/输入框必须有 label
InkButton(
  onPressed: _generate,
  semanticsLabel: context.l10n.generateButtonLabel, // 即使按钮有图标也要加
)

// 节点必须声明 role + state
Semantics(
  label: node.label,
  button: true,
  selected: isSelected,
  child: NodeWidget(node),
)
```

### 11.3 焦点环规范

```dart
// Tab 导航时显示 2px 高对比度焦点环
// 颜色来自 token，不硬编码
FocusableActionDetector(
  focusNode: _focusNode,
  child: AnimatedContainer(
    decoration: _focusNode.hasFocus
        ? BoxDecoration(
            border: Border.all(
              color: context.inkColors.focusRing, // token
              width: 2.0,
            ),
          )
        : null,
    child: child,
  ),
)
```

### 11.4 键盘完全可达门禁

**P0-Beta 前必须满足：** 所有鼠标操作有等价键盘路径（框选除外，用 Tab 遍历替代）。

> **Planned**：键盘覆盖检查闸门尚未编写——按现行铁律机制应落为 `test/quality/` 静态测试（非 bash hook，见 §14.6）：扫描 `lib/features/` 下的 `GestureDetector` / `InkWell`，无对应 `onKey` / `KeyboardListener` / `Shortcuts` 覆盖即红。

**VoiceOver / Narrator 验收：** 人工验证 + 录屏归档（Sprint 1 T4 验收条件），不做自动化（Flutter Semantics 测试无法覆盖实际朗读行为）。

---

## 12. 测试策略与分层

### 12.1 分层工具矩阵

| 层 | 工具 | 范围 |
|----|------|------|
| core / utils | `flutter_test` (Dart 单测) | 纯函数，无 mock |
| Service 层 | `flutter_test` + 手写 Fake（`test/_harness/`，接口实现，无 mock 框架） | fake Repository / Provider 接口 |
| Provider 层 | `flutter_test` + `http_mock_adapter` + fixture（`test/fixtures/providers/`） | HTTP 层 mock |
| Repository 层 | `flutter_test` + `test/storage/schema/pg_test_harness.dart` | 真实 PG（`TEST_PG_URL`，本地无 PG 时 skip） |
| Riverpod Provider | `ProviderContainer` + override | override Provider |
| Widget | `flutter_test` + `ProviderScope` overrides | 渲染 + 交互 |
| Golden | `matchesGoldenFile`（基线锁 CI ubuntu） | UI 回归，关键 Widget 必须有 |
| E2E | `test/e2e/`（fake provider 回放，2 用例）+ 手动场景 | 核心闭环 |

**覆盖率门槛：全仓单门 70%**（决策 D-4，2026-05）——CI `very_good_coverage min_coverage: 70` 是唯一门禁，不再按层分档；早期"数据层 75%"分层门已废除。排除清单唯一事实源是 `ci.yml` 的 `exclude:` 行（本地镜像 `scripts/coverage/report.sh`）。

### 12.2 TDD 节奏（强制）

```
1. 写测试，watch it fail（红）
2. 写最简实现，watch it pass（绿）
3. 重构，保持绿

禁止：先写实现再补测试（补出来的测试倾向于测实现细节，不测行为）
```

### 12.3 Mock 边界规则

本项目不用 mock 框架——测试替身是手写 Fake（实现 `core/interfaces/` 的抽象接口，集中在 `test/_harness/`）。

```dart
// ✅ Fake 实现接口，不替换具体类
class FakeNodeRepository implements NodeRepository {
  @override
  Future<Node> findById(String id) async => fakeNode;
}

// ❌ 不 extends / 替换具体类（意味着你依赖了具体实现）
class FakePostgresNodeRepository extends PostgresNodeRepository { ... } // 违规

// ❌ 不替换被测对象的内部方法
// 如果你需要 stub 一个私有方法，说明设计有问题，先重构
```

### 12.4 集成测试配置

```yaml
# dart_test.yaml（根目录，真实内容）——三个 tag，配环境变量门控
tags:
  pg:      # 真 PG 集成测：需 TEST_PG_URL；未设置时用例内 markTestSkipped
  golden:  # golden 像素测：基线锁 CI ubuntu；mac/win 以 --exclude-tags golden 排除
  ffmpeg:  # 真 ffmpeg 集成测：需 TEST_FFMPEG=1 且 PATH 有 ffmpeg；否则自跳
```

```bash
# 本地全量（pre-push 同款）：golden 排除，pg/ffmpeg 未设 env 自跳
flutter test --exclude-tags golden

# 单独跑真 PG 集成测（先起库并 export TEST_PG_URL）
flutter test --tags pg
```

### 12.5 CI 覆盖率门禁

```yaml
# .github/workflows/ci.yml（test job，真实机制）
- name: flutter test --coverage
  run: flutter test --coverage
- name: enforce coverage threshold (70%)
  uses: VeryGoodOpenSource/very_good_coverage@v3
  with:
    path: coverage/lcov.info
    min_coverage: 70
    exclude: '...'   # 唯一事实源在 ci.yml 本体；report.sh 运行时抽取此行
```

本地按同一口径复算：`bash scripts/coverage/report.sh`（从 ci.yml 抽取 exclude、归一化路径、ΣLH/ΣLF 对阈值）。

---

## 13. 日志规范

### 13.1 格式

单行 JSON，所有字段固定：

```json
{"ts":"2026-04-13T10:30:00Z","level":"ERROR","module":"provider.kling","msg":"poll timeout","extra":{"job_id":"uuid","retry_count":2}}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `ts` | ISO 8601 UTC | 精确到毫秒 |
| `level` | ERROR/WARN/INFO/DEBUG | 默认 INFO，可在设置调整 |
| `module` | 点分层级 | 见 §13.2 |
| `msg` | 字符串 | 描述事件，英文，不含变量 |
| `extra` | 对象 | 上下文参数，变量放这里 |

### 13.2 模块命名规范

```
storage.postgres       → 数据库连接与查询
storage.migration      → Schema 迁移
provider.{id}          → 具体 Provider（provider.kling-v3, provider.gemini-image）
job_queue              → 任务队列调度
file_resolver          → 文件路径解析
canvas.autosave        → 自动保存
performance            → 性能降级事件
app.lifecycle          → 启动 / 退出
```

### 13.3 使用规范

```dart
// lib/core/logging/logger_service.dart（真实接口）
abstract class LoggerService {
  void debug(String module, String msg, {Map<String, Object?>? extra});
  void info(String module, String msg, {Map<String, Object?>? extra});
  void warn(String module, String msg, {Map<String, Object?>? extra});
  void error(String module, String msg,
      {Map<String, Object?>? extra, Object? cause, StackTrace? stackTrace});
  Future<void> flush();
  Future<void> close();
}
// 落盘实现：FileLoggerService（同步写，保证行序；轮转 + 限流 + 脱敏内置）

// 使用示例
_logger.error(
  'provider.kling-v3',
  'poll timeout',
  cause: e,
  extra: {'job_id': jobId, 'retry_count': retryCount},
);

// ❌ 禁止
print('Error: $e');
debugPrint('job failed');
```

### 13.4 敏感字段打码规则

敏感字段**禁止**明文出现在日志中。`FileLoggerService` 对 `extra` 按 key 名打码（不区分大小写），命中即替换为 `***`：

```
key / api_key / apikey / token / authorization / authorisation /
prompt / password / proxy_password / proxypassword / secret
```

调用方仍负有第一责任：不要把敏感值塞进 `msg`（msg 是固定英文短语，变量只进 `extra`）。

### 13.5 日志轮转

```
单文件上限：10 MB（当天超限立即轮转，不等跨日）
总磁盘上限：200 MB
紧急模式：总占用 > 200MB 立即删除最旧文件直到 < 150MB
DEBUG 写入限流：每秒最多 100 行，超限丢弃 + 写一条 WARN 汇总
崩溃日志：inkframe.crash.{timestamp}.log，独立保留最近 3 份，不参与轮转
```

---

## 14. 构建与发布流水线

### 14.1 触发条件

| 事件 | 触发流程 |
|------|---------|
| PR → `main` | CI 检查（analyze + test/coverage + golden + release-scripts，见 §14.6） |
| push `main` tag `v*` | Release Build（三平台矩阵） |
| 手动触发 | 可指定平台和渠道 |

### 14.2 平台矩阵

```yaml
strategy:
  matrix:
    include:
      - os: macos-latest
        arch: arm64
        target: macos
      - os: macos-latest
        arch: x64
        target: macos
      - os: windows-latest
        arch: x64
        target: windows
```

### 14.3 PG 二进制获取流程

PG 二进制**不进代码仓库**。当前现状：

- **CI 测试**：`.github/workflows/ci.yml` 用 `postgres:17-alpine` service container（`TEST_PG_URL` 注入），不打包二进制。
- **本地开发**：`PgBinaryLocator`（`lib/storage/pg_binary_locator.dart`）按约定目录发现本机 PG；找不到时 storage 集成测试 `markTestSkipped`。

> **Planned**：Release 构建打包内嵌 PG 二进制的拉取脚本（`scripts/fetch-pg-binaries.sh` + `scripts/pg-version.txt`，从对象存储按平台拉取并校验版本）尚未编写——Release 流水线立项时一并实现。

### 14.4 构建步骤

> **Planned**：Release 流水线（含 `fetch-pg-binaries.sh` / `sign-and-notarize.sh`）尚未搭建；当前 CI 只跑 PR 检查（analyze + test + coverage）。以下为 Release 蓝图：

```bash
# 完整 Release 构建流程
scripts/fetch-pg-binaries.sh        # 1. 拉取 PG 二进制
flutter pub get                      # 2. 依赖
flutter gen-l10n                     # 3. 生成 i18n
dart run build_runner build          # 4. 代码生成（freezed / riverpod）
flutter analyze --fatal-infos        # 5. 静态分析（0 warning 门槛）
flutter test                         # 6. 全量测试
flutter build macos --release        # 7. 构建（平台对应）
scripts/sign-and-notarize.sh         # 8. 签名 + 公证
```

### 14.5 签名与公证

**macOS：**

```bash
# Developer ID Application 签名
codesign --deep --force --options runtime \
  --entitlements macos/Runner/Release.entitlements \
  --sign "Developer ID Application: ..." \
  build/macos/Build/Products/Release/InkFrame.app

# Apple 公证
xcrun notarytool submit InkFrame.dmg \
  --apple-id $APPLE_ID --team-id $TEAM_ID \
  --password $NOTARYTOOL_PASSWORD --wait

xcrun stapler staple InkFrame.dmg
```

**Windows：**

```bash
# EV Code Sign（SmartScreen 零警告需要 EV）
signtool sign /tr http://timestamp.digicert.com /td sha256 \
  /fd sha256 /a InkFrame.exe
```

### 14.6 铁律闸门清单（测试化）

原 6 个 `check-*.sh` bash hook 已删除（python3 + bash 双依赖、Windows 跨平台脆弱），铁律迁为
**Dart 静态测试**，跨平台随 `flutter test` 稳定执行：

| 测试（`test/quality/`） | 检测内容 | 执行点 |
|------|---------|--------|
| `no_magic_strings_test.dart` | 硬编码 UI 字符串、状态字符串比较 | pre-commit + CI |
| `no_inline_styles_test.dart` | `Color(0xFF...)` / 硬编码 EdgeInsets / BoxShadow | pre-commit + CI |
| `no_direct_instantiation_test.dart` | Widget/Service 内直接 new 具体实现 | pre-commit + CI |
| `disposable_cleanup_test.dart` | StreamSubscription / Timer / Controller 未 dispose | pre-commit + CI |
| `updated_at_test.dart` | `lib/storage/` 的 UPDATE 语句缺 `updated_at` | pre-commit + CI |
| `migration_registry_test.dart` | `kAppMigrations` 版本连续性 / 注册完整性 | pre-commit + CI |

i18n 平权闸门在 `test/l10n/arb_hygiene_test.dart`（见 §8.4），随全量测试跑。
`dart run custom_lint` 作为 AST 级增强挂在 pre-commit 与 CI，**暂非阻断**（riverpod_lint 兼容
Dart 3.11 AST 前），铁律防护不依赖它。

**pre-commit（本地 git hook）：** `flutter analyze` + `flutter test test/quality/` + custom_lint（非阻断）。
**pre-push（本地 git hook）：** `flutter analyze lib test` + `flutter test --exclude-tags golden`。
**CI PR check：** analyze / test + coverage 70% 闸 / golden + 基线守卫 / release-scripts 四并行 job。

### 14.7 发布渠道

```
alpha   → GitHub Release prerelease=true,  tag: v0.1.0-alpha.N
beta    → GitHub Release prerelease=true,  tag: v0.1.0-beta.N
stable  → GitHub Release prerelease=false, tag: v0.1.0
```

用户在设置 → 关于选择接收哪个渠道，app 启动时后台轮询 GitHub Releases API。

---

## 附录：快速检查清单

在提交代码前，逐条确认：

- [ ] 没有 `new ConcreteClass()` 在 Widget / Service 层
- [ ] 没有硬编码 UI 字符串（中英文均禁止）
- [ ] 没有 `Color(0xFF...)` / `fontSize: N` / `EdgeInsets.all(N)`
- [ ] 所有 `StreamSubscription` / `Timer` / `AnimationController` 有 dispose
- [ ] `app_en.arb` 和 `app_zh.arb` 同步更新，key 集合一致
- [ ] 所有 Repository `upsert/update` 经过 `withUpdatedAt()` 包装
- [ ] 错误通过 `InkError` 子类传播，没有裸 `Exception` 跨层
- [ ] `ref.watch()` 在 `build()` 里，`ref.read()` 只在事件回调里
- [ ] `flutter analyze` 0 warning
- [ ] `flutter test` 全绿
