# 生成管线闭环 + DI 补齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复体检发现的后端致命断点——让生成任务的状态/文件真正落库落盘、补齐两个未挂 DI 的仓库、给零测试的错误映射器补上覆盖，使后端纵向链路真正闭环。

**Architecture:** 核心是把 `jobQueueServiceProvider` 从 sync `Provider` 升级为 `FutureProvider`，注入它依赖的 `JobRepository`/`NodeRepository`/`FileResolverService`（前两者依赖内嵌 PostgreSQL，故必须 async），并在解析时调用已有的 `init()` 做启动恢复。服务实现本身（`InMemoryJobQueueService`）b2/b3 阶段早已写好持久化与落盘逻辑，仅因 DI 未注入依赖而全程 no-op——本计划只补接线，不改服务内部。

**Tech Stack:** Flutter · Riverpod（`FutureProvider` / `overrideWith`）· Dio（错误映射测试）· flutter_test。

**约定（务必遵守）：**
- 真实代码库根：`/Users/kerro/Projects/InkFrame`（非 shell cwd）。所有命令先 `cd` 进去。用 `flutter` 工具链。
- 注释中文、精简。
- **提交策略**：本项目规则为「未经用户明确许可不 git commit」。各 Task 末尾的 commit 步骤为标准计划格式，执行时若用户未授权提交，则**只跑测试、把改动留在工作区**，commit 步骤暂缓。
- 测试坑：本计划不 pump UI 整屏，纯 provider/纯函数测试，无 ticker/DragToMoveArea 顾虑。

**本计划范围外（体检发现但留作后续独立计划，原因附后）：**
- `JobsRegistry.upsert()` 接线 + `CanvasRenderQueue`/`CanvasInspector`/`CanvasLeftToolbar` 去 mock + Studio→Canvas open-canvas 导航 —— 均为 **UI 集成**，按用户「后端先打实、UI 后做」的战略归入下一份 UI 计划。
- `CanvasNode.fromRow` 读 `nodes` 表不存在的 `project_id` 列（恒 null）—— 已核实生成落盘 path 走 `GenerationTask` 字段而非此字段，属**无害潜在不一致**，不阻塞闭环；留作清理项。
- `JobRepository`/`BatchResultRepository` 无 softDelete —— 设计选择（审计记录用 purge），非缺陷。

---

## File Structure

- **Modify** `lib/core/di/job_queue.dart` — `jobQueueServiceProvider` 升级为 `FutureProvider` 并注入全部依赖 + `init()`。单一职责：装配 app 级队列单例。
- **Modify** `lib/features/generation/generation_controller.dart` — 1 行：`ref.watch(jobQueueServiceProvider)` → `await ...future`（消费方适配）。
- **Modify** `lib/features/generation/widgets/job_queue_panel.dart` — `_cancel` 改 async 取队列（消费方适配）。
- **Modify** `lib/core/di/repositories.dart` — 新增 `styleLaneRepositoryProvider` + `batchResultRepositoryProvider`。
- **Test** `test/core/di/job_queue_provider_test.dart`（新建）
- **Test** `test/core/di/repositories_binding_test.dart`（新建）
- **Test** `test/providers/dio_error_mapper_test.dart`（新建）

---

### Task 1: 闭合生成持久化/落盘链路（B1 + B5）

把队列 provider 升级为注入依赖的 `FutureProvider`，解析时跑 `init()`。这是整个计划的核心。

**Files:**
- Modify: `lib/core/di/job_queue.dart`（整文件替换）
- Modify: `lib/features/generation/generation_controller.dart:46`
- Modify: `lib/features/generation/widgets/job_queue_panel.dart:269-272`
- Test: `test/core/di/job_queue_provider_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

```dart
// test/core/di/job_queue_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/di/thumbnail.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:inkframe/services/job_queue_service.dart';

class _NoopSecure implements SecureStorageService {
  @override
  Future<void> store(String k, String v) async {}
  @override
  Future<String?> retrieve(String k) async => null;
  @override
  Future<void> delete(String k) async {}
  @override
  Future<bool> exists(String k) async => false;
}

/// 只实现 init() 用到的两个方法，其余成员走 noSuchMethod 抛错（测试不应触达）。
class _FakeJobRepo implements JobRepository {
  _FakeJobRepo(this.orphans);
  final List<Map<String, Object?>> orphans;
  final List<String> transitioned = <String>[];

  @override
  Future<List<Map<String, Object?>>> listByStatus(List<String> statuses) async =>
      orphans;

  @override
  Future<int> transitionStatus({
    required String id,
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    transitioned.add('$id->$toStatus');
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeNodeRepo implements NodeRepository {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeResolver implements FileResolverService {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  test('jobQueueServiceProvider 注入 repo 且解析时跑 init() 清理孤儿', () async {
    final fakeRepo = _FakeJobRepo(<Map<String, Object?>>[
      <String, Object?>{'id': 'orphan-1'},
    ]);
    final container = ProviderContainer(
      overrides: <Override>[
        secureStorageServiceProvider.overrideWithValue(_NoopSecure()),
        jobRepositoryProvider.overrideWith((ref) async => fakeRepo),
        nodeRepositoryProvider.overrideWith((ref) async => _FakeNodeRepo()),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
        thumbnailServiceProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final service = await container.read(jobQueueServiceProvider.future);
    expect(service, isA<InMemoryJobQueueService>());
    // init() 应把 submitted/polling 孤儿转 cancelled —— 证明 repo 已被真正注入。
    expect(fakeRepo.transitioned, contains('orphan-1->cancelled'));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/core/di/job_queue_provider_test.dart`
Expected: 失败 —— 当前 `jobQueueServiceProvider` 是 `Provider`（非 `FutureProvider`），`.future` 不存在 → 编译失败；即便编译过，旧 provider 不注入 repo、init() no-op，`transitioned` 为空（RED）。

- [ ] **Step 3: 升级 `lib/core/di/job_queue.dart`（整文件替换）**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/job_queue_service.dart';
import '../../services/job_queue_service.dart';
import 'file_resolver.dart';
import 'providers.dart';
import 'repositories.dart';
import 'thumbnail.dart';
import 'video_download.dart';

/// app-scoped 单例：JobQueueService 横跨所有项目和画布（PRD §10.7）。
///
/// 持久化版：注入 JobRepository + NodeRepository + FileResolverService，解析时
/// 调用 init() 做启动恢复（孤儿 submitted/polling → cancelled）。repo 依赖内嵌
/// PG（async），故本 provider 为 FutureProvider；首次被 await 时触发 PG 启动 +
/// schema migrate。VideoDownload/Thumbnail 仍按 T5-S3 注入（thumbnail 可空）。
final jobQueueServiceProvider = FutureProvider<JobQueueService>((ref) async {
  final registry = ref.watch(providerRegistryProvider);
  final downloader = ref.watch(videoDownloadServiceProvider);
  final thumbnail = ref.watch(thumbnailServiceProvider);
  final repo = await ref.watch(jobRepositoryProvider.future);
  final nodeRepo = await ref.watch(nodeRepositoryProvider.future);
  final fileResolver = ref.watch(fileResolverServiceProvider);
  final service = InMemoryJobQueueService(
    registry: registry,
    repo: repo,
    fileResolver: fileResolver,
    nodeRepo: nodeRepo,
    videoDownloader: downloader,
    thumbnailService: thumbnail,
  );
  await service.init();
  ref.onDispose(service.dispose);
  return service;
});
```

- [ ] **Step 4: 适配消费方 1 —— `generation_controller.dart:46`**

把：

```dart
    final queue = ref.watch(jobQueueServiceProvider);
```

改为：

```dart
    final queue = await ref.watch(jobQueueServiceProvider.future);
```

（该处位于 `generationControllerProvider` 的 `(ref) async {...}` 内，第 42-44 行已在 `await ...future` 取其它仓库，新增此 await 风格一致。）

- [ ] **Step 5: 适配消费方 2 —— `job_queue_panel.dart` 的 `_cancel`**

把：

```dart
  void _cancel(WidgetRef ref, String jobId) {
    final queue = ref.read(jobQueueServiceProvider);
    queue.cancel(jobId);
  }
```

改为：

```dart
  Future<void> _cancel(WidgetRef ref, String jobId) async {
    final queue = await ref.read(jobQueueServiceProvider.future);
    await queue.cancel(jobId);
  }
```

调用点形如 `onPressed: () => _cancel(ref, job.jobId)` 无需改动（箭头函数可丢弃返回的 Future）。若调用点不是这种形式，保持其 fire-and-forget 调用即可。

- [ ] **Step 6: 运行测试确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/core/di/job_queue_provider_test.dart`
Expected: `All tests passed!`（1 passed）

- [ ] **Step 7: 回归生成控制器既有测试（确认 async 适配无回归）**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/generation/`
Expected: `All tests passed!`（若有用例直接 `ref.read(jobQueueServiceProvider)` 取旧 sync 实例，需同步改 `.future`；按报错定位修正后重跑至全绿。）

- [ ] **Step 8: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/core/di/job_queue.dart lib/features/generation/generation_controller.dart lib/features/generation/widgets/job_queue_panel.dart test/core/di/job_queue_provider_test.dart
git commit -m "fix(generation): inject job repo + run init so pipeline persists"
```

---

### Task 2: 补齐 StyleLane / BatchResult 仓库 DI 绑定

两个仓库接口+实现+测试都在，但 `repositories.dart` 没给 Provider，上层无法注入（死代码）。

**Files:**
- Modify: `lib/core/di/repositories.dart`
- Test: `test/core/di/repositories_binding_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

```dart
// test/core/di/repositories_binding_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/batch_result_repository.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';

void main() {
  test('styleLane / batchResult 已声明为正确类型的 FutureProvider', () {
    expect(styleLaneRepositoryProvider,
        isA<FutureProvider<StyleLaneRepository>>());
    expect(batchResultRepositoryProvider,
        isA<FutureProvider<BatchResultRepository>>());
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/core/di/repositories_binding_test.dart`
Expected: 编译失败 —— `styleLaneRepositoryProvider` / `batchResultRepositoryProvider` 未定义（RED）。

- [ ] **Step 3: 在 `lib/core/di/repositories.dart` 补绑定**

顶部 import 区，按字母序加入：

```dart
import '../interfaces/batch_result_repository.dart';
import '../interfaces/style_lane_repository.dart';
```

```dart
import '../../storage/repositories/postgres_batch_result_repository.dart';
import '../../storage/repositories/postgres_style_lane_repository.dart';
```

文件末尾追加两个 provider（与既有五个同构）：

```dart
final styleLaneRepositoryProvider = FutureProvider<StyleLaneRepository>(
  (ref) async {
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresStyleLaneRepository(conn);
  },
  name: 'styleLaneRepositoryProvider',
);

final batchResultRepositoryProvider = FutureProvider<BatchResultRepository>(
  (ref) async {
    final conn = await ref.watch(pgMigratedConnectionProvider.future);
    return PostgresBatchResultRepository(conn);
  },
  name: 'batchResultRepositoryProvider',
);
```

- [ ] **Step 4: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/core/di/repositories_binding_test.dart`
Expected: `All tests passed!`（1 passed）

- [ ] **Step 5: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/core/di/repositories.dart test/core/di/repositories_binding_test.dart
git commit -m "feat(di): bind StyleLane and BatchResult repositories"
```

---

### Task 3: 给 `dio_error_mapper` 补测试

它是所有 AI provider 的 HTTP 错误转换底座，却零测试（体检列为最大测试空白）。本任务**不改生产代码**，仅补覆盖。

**Files:**
- Test: `test/providers/dio_error_mapper_test.dart`（新建）

> 前置事实：`mapDioError(DioException e, {required String providerId})` 返回 `InkError`；其子类 `NetworkError`/`ProviderError`/`CancelledError`/`UnknownError` 均带 `code`（`InkErrorCode`）与 `extra`（`Map<String,Object?>`）getter（mapper 即以此构造，见 `dio_error_mapper.dart:16-71`）。

- [ ] **Step 1: 写测试**

```dart
// test/providers/dio_error_mapper_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/providers/dio_error_mapper.dart';

RequestOptions _ro() => RequestOptions(path: '/x');

DioException _typed(DioExceptionType t) =>
    DioException(requestOptions: _ro(), type: t);

DioException _badResponse(int status) => DioException(
      requestOptions: _ro(),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(requestOptions: _ro(), statusCode: status),
    );

void main() {
  test('连接/发送/接收超时 → networkTimeout', () {
    for (final t in <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      final err = mapDioError(_typed(t), providerId: 'p');
      expect(err, isA<NetworkError>());
      expect(err.code, InkErrorCode.networkTimeout);
    }
  });

  test('connectionError → networkOffline', () {
    final err = mapDioError(_typed(DioExceptionType.connectionError), providerId: 'p');
    expect(err.code, InkErrorCode.networkOffline);
  });

  test('cancel → CancelledError', () {
    final err = mapDioError(_typed(DioExceptionType.cancel), providerId: 'p');
    expect(err, isA<CancelledError>());
  });

  test('401 / 403 → invalidKey', () {
    for (final s in <int>[401, 403]) {
      final err = mapDioError(_badResponse(s), providerId: 'p');
      expect(err, isA<ProviderError>());
      expect(err.code, InkErrorCode.invalidKey);
    }
  });

  test('402 → insufficientBalance', () {
    expect(mapDioError(_badResponse(402), providerId: 'p').code,
        InkErrorCode.insufficientBalance);
  });

  test('429 → providerBusy', () {
    expect(mapDioError(_badResponse(429), providerId: 'p').code,
        InkErrorCode.providerBusy);
  });

  test('5xx → providerServer', () {
    expect(mapDioError(_badResponse(503), providerId: 'p').code,
        InkErrorCode.providerServer);
  });

  test('其它 4xx → invalidParameter', () {
    expect(mapDioError(_badResponse(400), providerId: 'p').code,
        InkErrorCode.invalidParameter);
  });

  test('providerId 写入 extra', () {
    final err = mapDioError(_badResponse(429), providerId: 'wanx-image');
    expect(err.extra['provider_id'], 'wanx-image');
  });
}
```

- [ ] **Step 2: 运行确认通过（生产代码已存在，应直接绿）**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/providers/dio_error_mapper_test.dart`
Expected: `All tests passed!`（9 passed）

> 若某断言失败（如 `err.code`/`err.extra` getter 名不符），说明对 `InkError` 基类的假设有误：先 Read `lib/core/errors/ink_error.dart` 确认 getter 名再修正测试断言（不改生产代码）。这是为补测试服务的对齐，不是 RED→GREEN 的实现步骤。

- [ ] **Step 3: 提交（若已获授权）**

```bash
cd /Users/kerro/Projects/InkFrame
git add test/providers/dio_error_mapper_test.dart
git commit -m "test(providers): cover dio error mapper status/type mapping"
```

---

### Task 4: 全量回归 + 静态检查

**Files:** 无（仅验证）

- [ ] **Step 1: 静态分析**

Run: `cd /Users/kerro/Projects/InkFrame && flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 2: 全量测试**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test`
Expected: `All tests passed!`，通过数 = 基线（495）+ 本计划新增（Task 1: 1 + Task 2: 1 + Task 3: 9 = 11），即约 **506 passed**，跳过数（35）不变。

- [ ] **Step 3: 收尾汇报**

向用户报告：基线 495 → 现通过数、analyze 结果；并明确：生成管线的持久化/落盘/启动恢复已闭合（Task 1），两个仓库已可注入（Task 2），错误映射器已有覆盖（Task 3）。提示范围外后续项（jobsRegistry.upsert + UI 去 mock + open-canvas 导航）应进下一份 **UI 集成计划**。

---

## Self-Review

**1. Spec coverage（对照体检的「必修」缺口）：**
- B1 生成结果不落库/落盘 → Task 1（注入 repo/nodeRepo/fileResolver）。✓
- B5 `init()` 启动恢复从未调用 → Task 1 Step 3 解析时 `await service.init()`。✓
- 2 个仓库未挂 DI（StyleLane/BatchResult）→ Task 2。✓
- `dio_error_mapper` 零测试 → Task 3。✓
- 消费方 async 适配（generation_controller / job_queue_panel）→ Task 1 Step 4-5 + Step 7 回归。✓
- B2（jobsRegistry.upsert）、UI 去 mock、open-canvas、project_id —— 明确列入「范围外后续项」并说明理由。✓

**2. Placeholder scan：** 每个代码步骤均给完整代码 + 确切命令/期望输出。无 TODO/TBD/「类似上文」。Task 3 Step 2 的「若失败则核对 getter 名」是对既有生产代码的对齐说明（生产代码已存在），非占位实现。✓

**3. Type consistency：** `jobQueueServiceProvider` 全程 `FutureProvider<JobQueueService>`；消费方统一 `await ...future`；`InMemoryJobQueueService` 构造参数名（`registry/repo/fileResolver/nodeRepo/videoDownloader/thumbnailService`）与 `lib/services/job_queue_service.dart:34-46` 实参名逐一对齐；`JobRepository.transitionStatus`/`listByStatus` fake 签名与 `lib/core/interfaces/job_repository.dart:20,31-36` 一致；新 provider 命名 `styleLaneRepositoryProvider`/`batchResultRepositoryProvider` 在 Task 2 测试与实现间一致。✓

**关键风险提示（执行者注意）：** Task 1 把 app 级队列单例改为 lazy-async，首次被任意路径 `await` 时才触发 PG 启动。若未来有「应用启动即恢复孤儿」的需求，需在 `main.dart` 启动序列里主动 `await container.read(jobQueueServiceProvider.future)` 预热——本计划未纳入（属产品决策），仅在此标注。
