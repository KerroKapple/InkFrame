# LB-11 项目导出（整项目 zip 带产物）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 项目卡菜单一键把整个项目（DB 行 + 磁盘产物）导出为单个 zip：`manifest.json + data.json + files/`，为 LB-12 导入与 BP-11 项目复制产出全部机器。

**Architecture:** 新增专用只读 `ProjectArchiveReader`（storage 层，**全保真**——软删行连 `deleted_at` 一起导出，保证 FK 闭包：jobs/slots 引用的软删节点必须在包内，否则 LB-12 导入悬空）+ `ZipProjectArchiveService`（services 层：拼 manifest/data.json、递归打包 `projects/{id}` 全量目录、`.partial` 临时文件 + 原子 rename，镜像 LB-10 冷备的落盘纪律）。UI 入口 = Studio 项目卡菜单 + `file_selector.getSaveLocation`（经 DI seam 注入以便 widget 测试）。

**Tech Stack:** Dart（archive 纯 Dart 包做 zip）、postgres v3（`Sql.named` + `toColumnMap`）、Riverpod DI、file_selector。

## Global Constraints

- 分支：`feat/lb-11-project-export`，从合入 #185 后的 main 切出；conventional commits；每 commit 过 `flutter analyze lib test` + `flutter test --exclude-tags golden`（flutter 用绝对路径 `C:\Users\Kerro\flutter\bin\flutter.bat`，不在 PATH）。
- 代码注释中文、内部字符串（日志 module/错误 reason/SQL/JSON 键）English-only；UI 文案全走 ARB（en+zh 同 commit + `flutter gen-l10n` 提交 generated/）。
- 零硬编码样式：颜色/间距/圆角一律 token（`InkSpacing`/`context.inkColors`）。
- 真实 IO 测试用 plain `test()`，禁 `testWidgets` 内 await 真 dart:io（TD-003）；真库测试 `@Tags(['pg'])` + `PgTestHarness.openFromEnv`（环境缺失自跳过）。
- 错误只走 `InkError` 链（DB 边界 `BaseRepository.guard` 翻 `LocalIOError`），禁 catch `Exception`/`dynamic`。
- zip 内路径统一 `/` 分隔（Windows 上 `p.relative` 产 `\`，必须 replace）。
- schemaVersion 单一来源：`appMigrations.last.version`（`lib/storage/migrations/app_migrations.dart`，当前 7）；不得手写数字。
- slot 状态常量用 `lib/core/constants/job_statuses.dart`，不得裸写 `'success'`。

## 语义拍板（本计划的三个决策，执行者勿再摇摆）

1. **全保真导出**：canvases/nodes/edges/lanes/characters/presets 不过滤 `deleted_at`（回收站随包迁移；FK 闭包由此成立）。jobs 仍按卡面只带「拥有 ≥1 success slot 的 job」+ 这些 job 的**全部** batch_results 行（失败 slot 的 error 信息也是真相）。
2. **files/ = `projects/{id}` 目录全量镜像**（含 exports/、含软删节点媒体——与 LB-13 reaper「软删=被引用」同哲学）。项目目录不存在（纯空项目）→ zip 无 files/ 条目，合法。
3. **落盘纪律**：写 `<target>.partial` → 成功后 rename `<target>`；任何失败删 partial、抛 `LocalIOError`。

---

### Task 1: ProjectArchiveReader 接口 + Postgres 实现 + 真库集成测

**Files:**
- Create: `lib/core/interfaces/project_archive_reader.dart`
- Create: `lib/storage/repositories/postgres_project_archive_reader.dart`
- Test: `test/storage/repositories/project_archive_reader_integration_test.dart`

**Interfaces:**
- Produces: `ProjectArchiveReader`（9 个只读方法，签名见下）——Task 3 的 `ZipProjectArchiveService` 消费。

- [ ] **Step 1: 写接口**

```dart
// ProjectArchiveReader 契约：LB-11 项目导出的专用只读读侧（全保真）。
//
// 与常规仓储 list 方法的关键差异：**不过滤 deleted_at**。导出必须保证 FK 闭包
// （jobs.source_node_id / batch_results.node_id 可能指向软删节点），软删行连
// deleted_at 一起进包，LB-12 导入后回收站语义原样恢复。
abstract class ProjectArchiveReader {
  /// 项目行（按 PK，单行；不存在 → null）。
  Future<Map<String, Object?>?> projectRow(String projectId);

  /// 项目下全部画布（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> canvasRows(String projectId);

  /// 项目全画布下全部节点（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> nodeRows(String projectId);

  /// 项目全画布下全部连线（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> edgeRows(String projectId);

  /// 项目全画布下全部泳道（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> laneRows(String projectId);

  /// 项目角色（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> characterRows(String projectId);

  /// 项目提示词预设（含软删），created_at ASC。
  Future<List<Map<String, Object?>>> presetRows(String projectId);

  /// 拥有 ≥1 success slot 的 jobs 行（跨画布），created_at ASC。
  Future<List<Map<String, Object?>>> successJobRows(String projectId);

  /// 上述 jobs 的全部 batch_results 行（含失败 slot），job_id + slot_index ASC。
  Future<List<Map<String, Object?>>> batchResultRows(String projectId);
}
```

- [ ] **Step 2: 写真库红测（pg tag，先跑确认 fail：实现类不存在编译错）**

`test/storage/repositories/project_archive_reader_integration_test.dart`，仿 `postgres_repositories_integration_test.dart` 的 harness 模式：

```dart
// PostgresProjectArchiveReader 真 PG 集成测：全保真读侧（软删含入、success-job 过滤、FK 闭包）。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/job_statuses.dart';
import 'package:inkframe/storage/repositories/postgres_batch_result_repository.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_job_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_archive_reader.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';

import '../schema/pg_test_harness.dart';

void main() {
  late PgTestHarness? harness;

  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'archive');
  });

  tearDown(() async {
    await harness?.close();
  });

  test('全保真读侧：软删行含入、success-job 过滤、slot 全带', () async {
    final h = harness;
    if (h == null) return; // 无 PG 环境自跳过（与既有集成测同口径）。

    final projects = PostgresProjectRepository(h.session);
    final canvases = PostgresCanvasRepository(h.session);
    final nodes = PostgresNodeRepository(h.session);
    final jobs = PostgresJobRepository(h.session);
    final slots = PostgresBatchResultRepository(h.session);
    final reader = PostgresProjectArchiveReader(h.session);

    // 种子：项目 → 2 画布（1 软删）→ 3 节点（1 软删）→ 2 job（1 有 success slot）。
    final pid = await projects.create(name: 'p');
    final c1 = await canvases.create(projectId: pid, name: 'c1');
    final c2 = await canvases.create(projectId: pid, name: 'c2');
    await canvases.softDelete(c2);

    final n1 = await nodes.create(canvasId: c1, type: 'image', nodeRole: 'config');
    final n2 = await nodes.create(canvasId: c1, type: 'image', nodeRole: 'result', sourceNodeId: n1);
    final n3 = await nodes.create(canvasId: c2, type: 'image', nodeRole: 'config');
    await nodes.softDelete(n2);

    final j1 = await jobs.create(
      canvasId: c1, sourceNodeId: n1, resultNodeId: n2,
      providerId: 'prov', jobType: 'image',
      fullPrompt: 'fp', userPrompt: 'up',
    );
    final j2 = await jobs.create(
      canvasId: c1, sourceNodeId: n1,
      providerId: 'prov', jobType: 'image',
      fullPrompt: 'fp', userPrompt: 'up',
    );
    final s1 = await slots.create(nodeId: n2, jobId: j1, slotIndex: 0, status: JobStatuses.generating);
    await slots.update(s1, <String, Object?>{'status': JobStatuses.success});
    await slots.create(nodeId: n2, jobId: j1, slotIndex: 1, status: JobStatuses.failed);
    await slots.create(nodeId: n2, jobId: j2, slotIndex: 0, status: JobStatuses.failed);

    // 断言：软删画布/节点含入（全保真）。
    expect((await reader.projectRow(pid))?['id'], pid);
    expect((await reader.canvasRows(pid)).length, 2);
    final nodeRows = await reader.nodeRows(pid);
    expect(nodeRows.length, 3);
    expect(nodeRows.where((r) => r['deleted_at'] != null).length, 1);
    expect(nodeRows.map((r) => r['id']), containsAll(<String>[n1, n2, n3]));

    // 断言：只有 j1（有 success slot）被导出，且其全部 2 个 slot 都带上。
    final jobRows = await reader.successJobRows(pid);
    expect(jobRows.map((r) => r['id']), <String>[j1]);
    final slotRows = await reader.batchResultRows(pid);
    expect(slotRows.length, 2);
    expect(slotRows.every((r) => r['job_id'] == j1), isTrue);

    // 断言：无关项目隔离。
    final pid2 = await projects.create(name: 'other');
    expect(await reader.canvasRows(pid2), isEmpty);
    expect(await reader.successJobRows(pid2), isEmpty);
  });
}
```

> 注意核对 `job_statuses.dart` 里常量的真实名字（`JobStatuses.success` 等按实际改）；
> `PgTestHarness` 暴露的是 `session` 还是 `pool` getter 以现文件为准（照抄
> `postgres_repositories_integration_test.dart` 的用法）。edges/lanes/characters/presets
> 的同型断言可并入本 test 或加第二个 test，种子走对应 PG 仓储。

- [ ] **Step 3: 跑测确认红**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/storage/repositories/project_archive_reader_integration_test.dart`
Expected: 编译失败（PostgresProjectArchiveReader 未定义）——这就是本轮的「红」。

- [ ] **Step 4: 写 Postgres 实现**

`lib/storage/repositories/postgres_project_archive_reader.dart`（仿 `postgres_video_backfill_repository.dart`）：

```dart
// PostgresProjectArchiveReader —— LB-11 导出专用全保真只读（含软删；见接口注释）。
import 'package:postgres/postgres.dart';

import '../../core/constants/job_statuses.dart';
import '../../core/interfaces/project_archive_reader.dart';
import '../base_repository.dart';

class PostgresProjectArchiveReader
    with BaseRepository
    implements ProjectArchiveReader {
  PostgresProjectArchiveReader(this.session);

  @override
  final Session session;

  /// 「项目下拥有 ≥1 success slot 的 jobs」共享子句（jobs 过滤与 slot 全带复用）。
  static const String _successJobsFrom =
      'FROM jobs j JOIN canvases c ON c.id = j.canvas_id '
      'WHERE c.project_id = @p AND EXISTS ('
      'SELECT 1 FROM batch_results s '
      "WHERE s.job_id = j.id AND s.status = '${JobStatuses.success}')";

  Future<List<Map<String, Object?>>> _rows(String sql, String projectId) {
    return guard('archiveRead', 'project_archive', () async {
      final r = await session.execute(
        Sql.named(sql),
        parameters: <String, Object?>{'p': projectId},
      );
      return <Map<String, Object?>>[for (final row in r) row.toColumnMap()];
    });
  }

  @override
  Future<Map<String, Object?>?> projectRow(String projectId) async {
    final rows =
        await _rows('SELECT * FROM projects WHERE id = @p', projectId);
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<Map<String, Object?>>> canvasRows(String projectId) => _rows(
      'SELECT * FROM canvases WHERE project_id = @p ORDER BY created_at',
      projectId);

  @override
  Future<List<Map<String, Object?>>> nodeRows(String projectId) => _rows(
      'SELECT n.* FROM nodes n JOIN canvases c ON c.id = n.canvas_id '
      'WHERE c.project_id = @p ORDER BY n.created_at',
      projectId);

  @override
  Future<List<Map<String, Object?>>> edgeRows(String projectId) => _rows(
      'SELECT e.* FROM edges e JOIN canvases c ON c.id = e.canvas_id '
      'WHERE c.project_id = @p ORDER BY e.created_at',
      projectId);

  @override
  Future<List<Map<String, Object?>>> laneRows(String projectId) => _rows(
      'SELECT l.* FROM style_lanes l JOIN canvases c ON c.id = l.canvas_id '
      'WHERE c.project_id = @p ORDER BY l.created_at',
      projectId);

  @override
  Future<List<Map<String, Object?>>> characterRows(String projectId) => _rows(
      'SELECT * FROM characters WHERE project_id = @p ORDER BY created_at',
      projectId);

  @override
  Future<List<Map<String, Object?>>> presetRows(String projectId) => _rows(
      'SELECT * FROM prompt_presets WHERE project_id = @p ORDER BY created_at',
      projectId);

  @override
  Future<List<Map<String, Object?>>> successJobRows(String projectId) =>
      _rows('SELECT j.* $_successJobsFrom ORDER BY j.created_at', projectId);

  @override
  Future<List<Map<String, Object?>>> batchResultRows(String projectId) =>
      _rows(
          'SELECT br.* FROM batch_results br WHERE br.job_id IN '
          '(SELECT j.id $_successJobsFrom) '
          'ORDER BY br.job_id, br.slot_index',
          projectId);
}
```

> `JobStatuses.success` 若实际是别名（如 `kSlotStatusSuccess`），SQL 插值处同步改；
> 插值仅用于 const 状态常量，无注入面（projectId 走 @p 参数）。
> `toColumnMap()` 若与本仓库既有行读法不一致，以现有 PG 仓储的行→Map 写法为准。

- [ ] **Step 5: 跑测确认绿**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/storage/repositories/project_archive_reader_integration_test.dart`
Expected: PASS（无 PG 环境则 skip，同样算过；有环境时必须真绿一次再提交）。

- [ ] **Step 6: Commit**

```bash
git add lib/core/interfaces/project_archive_reader.dart lib/storage/repositories/postgres_project_archive_reader.dart test/storage/repositories/project_archive_reader_integration_test.dart
git commit -m "feat(storage): LB-11 读侧——ProjectArchiveReader 全保真项目读取（软删含入保 FK 闭包）"
```

---

### Task 2: 债 #20——characters / prompt_presets 真库 CRUD 集成测

**Files:**
- Modify: `test/storage/repositories/postgres_repositories_integration_test.dart`（在既有 7 仓储冒烟的同一文件加 2 组）

**Interfaces:**
- Consumes: 既有 `PostgresCharacterRepository` / `PostgresPromptPresetRepository`（不改产品代码——这是补测债，测试应直接绿；若发现真 bug 单独开修复 commit）。

- [ ] **Step 1: 加 characters CRUD 测试**

```dart
test('characters：CRUD + 软删 + 恢复', () async {
  final h = harness;
  if (h == null) return;
  final projects = PostgresProjectRepository(h.session);
  final repo = PostgresCharacterRepository(h.session);
  final pid = await projects.create(name: 'p');

  final id = await repo.create(
    projectId: pid,
    name: 'hero',
    referenceImagePaths: <String>['images/a.png'],
    description: 'd',
    sortOrder: 1,
  );
  final row = await repo.findById(id);
  expect(row?['name'], 'hero');

  expect(await repo.update(id, <String, Object?>{'name': 'hero2'}), 1);
  expect((await repo.findById(id))?['name'], 'hero2');

  expect(await repo.softDelete(id), 1);
  expect(await repo.listByProject(pid), isEmpty);
  expect(await repo.restore(id), 1);
  expect((await repo.listByProject(pid)).length, 1);

  expect(await repo.hardDelete(id), 1);
  expect(await repo.findById(id), isNull);
});
```

- [ ] **Step 2: 加 prompt_presets CRUD 测试**

同型：`create(projectId:, name:, prompt:, prefix:, suffix:, negative:, sortOrder:)` → findById → update(name) → softDelete/listByProject 空 → restore → hardDelete。列名以 `core/db/columns.dart` 与 001_init.sql 为准。

- [ ] **Step 3: 跑该文件确认绿**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/storage/repositories/postgres_repositories_integration_test.dart`
Expected: PASS（补测债，本来就该绿；红了=挖到真 bug，停下单独处置）。

- [ ] **Step 4: Commit**

```bash
git add test/storage/repositories/postgres_repositories_integration_test.dart
git commit -m "test(storage): 债#20——characters/prompt_presets 真库 CRUD 集成测补齐"
```

---

### Task 3: archive 依赖 + ZipProjectArchiveService

**Files:**
- Modify: `pubspec.yaml`（`flutter pub add archive`，勿手编）
- Create: `lib/core/interfaces/project_archive_service.dart`
- Create: `lib/services/project_archive_service.dart`
- Test: `test/services/project_archive_service_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `ProjectArchiveReader`；`AppPaths`（`.projects` getter）；`Clock`（`nowUtc()`，来自 `core/logging/logger_service.dart`）；`appMigrations.last.version`。
- Produces: `ProjectArchiveService.exportProject({required String projectId, required String targetPath})` + 纯函数 `suggestedArchiveName(String projectName)`——Task 4/5 消费。

- [ ] **Step 1: 加依赖**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat pub add archive`
Expected: pubspec.yaml/lock 更新成功。随后**核对 API**：在 `%LOCALAPPDATA%\Pub\Cache`（或 `~/.pub-cache`）读 `archive` 包的 `ZipFileEncoder`（`create`/`addFile`/`addArchiveFile`/`close`）与 `ArchiveFile.string` 真实签名，下方代码按实际版本微调（3.x 同步 / 4.x 部分 async）。

- [ ] **Step 2: 写接口**

`lib/core/interfaces/project_archive_service.dart`：

```dart
// ProjectArchiveService 契约：整项目导出为单 zip（LB-11）。
//
// zip 布局：manifest.json + data.json + files/（= projects/{id} 目录全量镜像，
// 路径一律 '/' 分隔）。写盘纪律：先 <target>.partial 再原子 rename；
// 任何失败清 partial 并抛 LocalIOError。
abstract class ProjectArchiveService {
  Future<void> exportProject({
    required String projectId,
    required String targetPath,
  });
}
```

- [ ] **Step 3: 写红测（plain test()，真临时目录）**

`test/services/project_archive_service_test.dart` 要点（完整写出再跑红）：

```dart
// ZipProjectArchiveService 单测：zip 布局 / 全保真行 / 原子落盘 / 失败清理。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/project_archive_reader.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/project_archive_service.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';

class _FakeReader implements ProjectArchiveReader {
  _FakeReader({this.project, this.throwOnNodes = false});
  Map<String, Object?>? project;
  bool throwOnNodes;

  @override
  Future<Map<String, Object?>?> projectRow(String projectId) async => project;
  @override
  Future<List<Map<String, Object?>>> canvasRows(String p) async =>
      <Map<String, Object?>>[
        <String, Object?>{'id': 'c1', 'project_id': p, 'deleted_at': null},
      ];
  @override
  Future<List<Map<String, Object?>>> nodeRows(String p) async {
    if (throwOnNodes) throw const LocalIOError();
    return <Map<String, Object?>>[
      <String, Object?>{
        'id': 'n1',
        'canvas_id': 'c1',
        'created_at': DateTime.utc(2026, 7, 16), // DateTime 必须被 ISO 化。
        'type_config': <String, Object?>{'image_url': 'images/a.png'},
      },
    ];
  }
  // edges/lanes/characters/presets/jobs/slots → 返回空列表（各自 @override，同型省略）。
  @override
  Future<List<Map<String, Object?>>> edgeRows(String p) async => const [];
  @override
  Future<List<Map<String, Object?>>> laneRows(String p) async => const [];
  @override
  Future<List<Map<String, Object?>>> characterRows(String p) async => const [];
  @override
  Future<List<Map<String, Object?>>> presetRows(String p) async => const [];
  @override
  Future<List<Map<String, Object?>>> successJobRows(String p) async => const [];
  @override
  Future<List<Map<String, Object?>>> batchResultRows(String p) async => const [];
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('archive_test');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  ZipProjectArchiveService build(_FakeReader reader) {
    final paths = DefaultAppPaths.forRoot(Directory('${temp.path}/root'));
    return ZipProjectArchiveService(
      reader: reader,
      paths: paths,
      clock: const SystemClock(),
      appVersion: '9.9.9',
    );
  }

  test('导出 zip：manifest/data/files 齐全，路径用 /，DateTime ISO 化', () async {
    final reader = _FakeReader(project: <String, Object?>{'id': 'p1', 'name': 'demo'});
    final svc = build(reader);
    // 种子磁盘产物：projects/p1/canvases/c1/images/a.png + exports/out.mp4。
    final proj = Directory('${temp.path}/root/projects/p1/canvases/c1/images')
      ..createSync(recursive: true);
    File('${proj.path}/a.png').writeAsBytesSync(<int>[1, 2, 3]);
    Directory('${temp.path}/root/projects/p1/exports').createSync(recursive: true);
    File('${temp.path}/root/projects/p1/exports/out.mp4').writeAsBytesSync(<int>[4]);

    final target = '${temp.path}/demo.zip';
    await svc.exportProject(projectId: 'p1', targetPath: target);

    final archive = ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, containsAll(<String>{
      'manifest.json',
      'data.json',
      'files/canvases/c1/images/a.png',
      'files/exports/out.mp4',
    }));
    expect(names.any((n) => n.contains('\\')), isFalse);

    final manifest = jsonDecode(utf8.decode(
        archive.files.firstWhere((f) => f.name == 'manifest.json').content as List<int>))
        as Map<String, dynamic>;
    expect(manifest['formatVersion'], 1);
    expect(manifest['schemaVersion'], appMigrations.last.version);
    expect(manifest['appVersion'], '9.9.9');
    expect(manifest['exportedAt'], isA<String>());

    final data = jsonDecode(utf8.decode(
        archive.files.firstWhere((f) => f.name == 'data.json').content as List<int>))
        as Map<String, dynamic>;
    expect((data['project'] as Map)['id'], 'p1');
    expect((data['nodes'] as List).length, 1);
    expect(((data['nodes'] as List).first as Map)['created_at'],
        '2026-07-16T00:00:00.000Z');
    // 未产生 .partial 残留。
    expect(File('$target.partial').existsSync(), isFalse);
  });

  test('项目不存在 → LocalIOError，且不产生任何文件', () async {
    final svc = build(_FakeReader(project: null));
    final target = '${temp.path}/none.zip';
    await expectLater(
      svc.exportProject(projectId: 'nope', targetPath: target),
      throwsA(isA<LocalIOError>()),
    );
    expect(File(target).existsSync(), isFalse);
    expect(File('$target.partial').existsSync(), isFalse);
  });

  test('读侧中途抛错 → 清 partial、错误冒泡', () async {
    final reader = _FakeReader(
        project: <String, Object?>{'id': 'p1'}, throwOnNodes: true);
    final svc = build(reader);
    final target = '${temp.path}/boom.zip';
    await expectLater(
      svc.exportProject(projectId: 'p1', targetPath: target),
      throwsA(isA<LocalIOError>()),
    );
    expect(File(target).existsSync(), isFalse);
    expect(File('$target.partial').existsSync(), isFalse);
  });

  test('suggestedArchiveName：非法字符剥离、空名兜底', () {
    expect(suggestedArchiveName('My: Film/Take*2'), 'My Film Take2.zip');
    expect(suggestedArchiveName('   '), 'project.zip');
  });
}
```

- [ ] **Step 4: 跑红**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/services/project_archive_service_test.dart`
Expected: 编译失败（ZipProjectArchiveService / suggestedArchiveName 未定义）。

- [ ] **Step 5: 写实现**

`lib/services/project_archive_service.dart`：

```dart
// ZipProjectArchiveService：ProjectArchiveService 的 zip 落地（LB-11）。
//
// 流程：读全保真行 → manifest/data.json → 递归打包 projects/{id} 全量 →
// .partial 原子 rename（镜像 LB-10 落盘纪律）。失败清 partial 抛 LocalIOError。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../core/errors/ink_error.dart';
import '../core/interfaces/project_archive_reader.dart';
import '../core/interfaces/project_archive_service.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import '../storage/migrations/app_migrations.dart';

/// 日志 module 名（内部标识，English-only）。
const String kArchiveModule = 'project.archive';

/// zip 格式版本——LB-12 导入端按此显式拒绝不认识的包（Zero-BC）。
const int kArchiveFormatVersion = 1;

/// 纯函数：项目名 → 建议保存文件名（剥非法字符，空兜底 project）。
String suggestedArchiveName(String projectName) {
  final safe = projectName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
      .trim();
  return '${safe.isEmpty ? 'project' : safe}.zip';
}

/// 纯函数：行值 JSON 安全化（DateTime → ISO8601 UTC，容器递归）。
Object? jsonSafe(Object? v) {
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is Map) {
    return <String, Object?>{
      for (final e in v.entries) e.key.toString(): jsonSafe(e.value),
    };
  }
  if (v is List) return <Object?>[for (final e in v) jsonSafe(e)];
  return v;
}

class ZipProjectArchiveService implements ProjectArchiveService {
  ZipProjectArchiveService({
    required ProjectArchiveReader reader,
    required AppPaths paths,
    required Clock clock,
    required String appVersion,
    LoggerService? logger,
  })  : _reader = reader,
        _paths = paths,
        _clock = clock,
        _appVersion = appVersion,
        _logger = logger;

  final ProjectArchiveReader _reader;
  final AppPaths _paths;
  final Clock _clock;
  final String _appVersion;
  final LoggerService? _logger;

  @override
  Future<void> exportProject({
    required String projectId,
    required String targetPath,
  }) async {
    final File partial = File('$targetPath.partial');
    try {
      final project = await _reader.projectRow(projectId);
      if (project == null) {
        throw LocalIOError(
          extra: <String, Object?>{'reason': 'project_not_found'},
        );
      }

      final Map<String, Object?> data = <String, Object?>{
        'project': jsonSafe(project),
        'canvases': jsonSafe(await _reader.canvasRows(projectId)),
        'nodes': jsonSafe(await _reader.nodeRows(projectId)),
        'edges': jsonSafe(await _reader.edgeRows(projectId)),
        'lanes': jsonSafe(await _reader.laneRows(projectId)),
        'characters': jsonSafe(await _reader.characterRows(projectId)),
        'prompt_presets': jsonSafe(await _reader.presetRows(projectId)),
        'jobs': jsonSafe(await _reader.successJobRows(projectId)),
        'batch_results': jsonSafe(await _reader.batchResultRows(projectId)),
      };
      final Map<String, Object?> manifest = <String, Object?>{
        'formatVersion': kArchiveFormatVersion,
        'schemaVersion': appMigrations.last.version,
        'appVersion': _appVersion,
        'exportedAt': _clock.nowUtc().toIso8601String(),
      };

      final encoder = ZipFileEncoder()..create(partial.path);
      try {
        encoder.addArchiveFile(
            ArchiveFile.string('manifest.json', jsonEncode(manifest)));
        encoder.addArchiveFile(
            ArchiveFile.string('data.json', jsonEncode(data)));
        final Directory projectDir =
            Directory(p.join(_paths.projects.path, projectId));
        if (projectDir.existsSync()) {
          final entries = projectDir
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path)); // 确定序，测试可复现。
          for (final File f in entries) {
            final rel = p
                .relative(f.path, from: projectDir.path)
                .replaceAll('\\', '/');
            await encoder.addFile(f, 'files/$rel');
          }
        }
      } finally {
        encoder.close();
      }

      // 原子发布。
      if (File(targetPath).existsSync()) File(targetPath).deleteSync();
      partial.renameSync(targetPath);
      _logger?.info(kArchiveModule, 'export.done', extra: <String, Object?>{
        'project_id': projectId,
        'file': p.basename(targetPath),
      });
    } on InkError {
      _deleteQuietly(partial);
      rethrow;
    } on FileSystemException catch (e, st) {
      _deleteQuietly(partial);
      throw LocalIOError(
        extra: <String, Object?>{'reason': 'export_io', 'detail': e.message},
        cause: e,
        stackTrace: st,
      );
    }
  }

  void _deleteQuietly(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // 清理失败不影响主错误。
    }
  }
}
```

> archive 包版本差异按 Step 1 核对结果调整（如 4.x `addFile` 为 async、`close()` 可能为
> `closeSync()`）；`LocalIOError` 的构造签名以 `ink_error.dart` 现状为准（reason 进
> extra 还是具名参数，照既有用法）。`LoggerService`/`Clock` 名字以
> `core/logging/logger_service.dart` 现状为准。

- [ ] **Step 6: 跑绿**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/services/project_archive_service_test.dart`
Expected: PASS（4 tests）。

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/interfaces/project_archive_service.dart lib/services/project_archive_service.dart test/services/project_archive_service_test.dart
git commit -m "feat(services): LB-11 ZipProjectArchiveService——manifest/data/files 三件套 + .partial 原子落盘"
```

---

### Task 4: DI 装配（reader + service + save-location seam）

**Files:**
- Create: `lib/core/di/project_archive.dart`
- Test: `test/core/di/project_archive_provider_test.dart`

**Interfaces:**
- Consumes: `pgMigratedPoolProvider`（`core/di/database.dart`）、`appPathsProvider`（`core/di/paths.dart`，名字以现文件为准）、`clockProvider`、`packageInfoProvider`。
- Produces: `projectArchiveServiceProvider`（FutureProvider<ProjectArchiveService>）、`saveLocationPickerProvider`（widget 测试可 override 的 file_selector seam）——Task 5 消费。

- [ ] **Step 1: 写 DI**

```dart
// 项目导出 DI：reader/service 装配 + 保存位置选择 seam（widget 测试可 override）。
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/project_archive_reader.dart';
import '../interfaces/project_archive_service.dart';
import '../../services/project_archive_service.dart';
import '../../storage/repositories/postgres_project_archive_reader.dart';
import 'clock.dart';
import 'database.dart';
import 'package_info.dart';
import 'paths.dart';

/// 「导出到哪」的抽象：生产走 file_selector，测试 override 返回固定路径/null。
typedef SaveLocationPicker = Future<String?> Function(String suggestedName);

final saveLocationPickerProvider = Provider<SaveLocationPicker>(
  (ref) => (String suggestedName) async {
    final location = await getSaveLocation(suggestedName: suggestedName);
    return location?.path;
  },
  name: 'saveLocationPickerProvider',
);

final projectArchiveReaderProvider =
    FutureProvider<ProjectArchiveReader>((ref) async {
  final pool = await ref.watch(pgMigratedPoolProvider.future);
  return PostgresProjectArchiveReader(pool);
}, name: 'projectArchiveReaderProvider');

final projectArchiveServiceProvider =
    FutureProvider<ProjectArchiveService>((ref) async {
  final reader = await ref.watch(projectArchiveReaderProvider.future);
  final paths = await ref.watch(appPathsProvider.future);
  final info = await ref.watch(packageInfoProvider.future);
  return ZipProjectArchiveService(
    reader: reader,
    paths: paths,
    clock: ref.watch(clockProvider),
    appVersion: info.version,
  );
}, name: 'projectArchiveServiceProvider');
```

> `appPathsProvider` 是否 FutureProvider、logger 是否随构造注入，以 `core/di/paths.dart`
> 与其它 service DI 文件（如 orphan_reaper.dart）的既有写法为准，保持同风格。

- [ ] **Step 2: provider 冒烟测（override 依赖，解析出正确类型）**

`test/core/di/project_archive_provider_test.dart`：仿 `test/core/di/canvas_style_controller_test.dart` 的容器模式——override `pgMigratedPoolProvider`/`appPathsProvider`/`packageInfoProvider` 为 fake，断言 `projectArchiveServiceProvider` 解析为 `ZipProjectArchiveService`、`saveLocationPickerProvider` 可 override。

- [ ] **Step 3: 跑绿后 Commit**

```bash
git add lib/core/di/project_archive.dart test/core/di/project_archive_provider_test.dart
git commit -m "feat(di): LB-11 导出装配——reader/service provider + 保存位置 seam"
```

---

### Task 5: UI 入口——项目卡菜单「Export」+ snackbar + l10n

**Files:**
- Modify: `lib/features/studio/widgets/project_card.dart`（加 `onExport` 参数 + 菜单项）
- Modify: `lib/features/studio/studio_home_screen.dart`（挂 handler：picker → service → snackbar）
- Modify: `lib/l10n/app_en.arb` + `lib/l10n/app_zh.arb`（3 键）+ 重新生成 `lib/l10n/generated/`
- Test: `test/features/studio/widgets/project_card_test.dart`（存在则扩展，不存在则新建）+ `test/features/studio/studio_home_test.dart` 扩展

**Interfaces:**
- Consumes: Task 4 的 `projectArchiveServiceProvider` / `saveLocationPickerProvider`、Task 3 的 `suggestedArchiveName`。

- [ ] **Step 1: ARB 加键（两文件同 commit）**

`app_en.arb`：

```json
"projectMenuExport": "Export project…",
"exportProjectSuccess": "Project exported",
"exportProjectFailed": "Export failed"
```

`app_zh.arb`：

```json
"projectMenuExport": "导出项目…",
"exportProjectSuccess": "项目已导出",
"exportProjectFailed": "导出失败"
```

Run: `C:\Users\Kerro\flutter\bin\flutter.bat gen-l10n`

- [ ] **Step 2: 红测——菜单项出现且回调触发**

在 project_card 测试里 pump `StudioProjectCard(..., onExport: spy)` → 打开菜单 → 断言 `projectMenuExport` 文案出现 → tap → spy 被调。跑红（onExport 参数不存在编译失败）。

- [ ] **Step 3: project_card.dart 加 `onExport`**

构造参数 + `_ProjectMenu` 透传 + 菜单项（照抄既有 Gallery/Rename 项的样式与 l10n 取法，间距/图标走 token）。

- [ ] **Step 4: studio_home_screen.dart 挂 handler**

在建卡处（`onManageCanvases` 旁）：

```dart
onExport: () => _exportProject(context, ref, project),
```

handler（跟既有 snackbar 风格一致；`_exporting` 局部防重入）：

```dart
Future<void> _exportProject(
    BuildContext context, WidgetRef ref, /* 项目行/模型，按现有类型 */ project) async {
  if (_exporting) return;
  final picker = ref.read(saveLocationPickerProvider);
  final path = await picker(suggestedArchiveName(project.name));
  if (path == null) return; // 用户取消。
  _exporting = true;
  try {
    final service = await ref.read(projectArchiveServiceProvider.future);
    await service.exportProject(projectId: project.id, targetPath: path);
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.exportProjectSuccess)),
      );
    }
  } on InkError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.exportProjectFailed)),
      );
    }
  } finally {
    _exporting = false;
  }
}
```

> 具体形参类型（project 是 Map 行还是模型）、`context.mounted` 守卫、以及失败文案是否用
> `l10n_x` 的 InkError→本地化映射拼接（`exportProjectFailed` + 具体错误），照
> studio_home_screen 既有 3 处 snackbar 的写法对齐。

- [ ] **Step 5: 红测→绿测——home 流程**

`studio_home_test.dart` 加用例：override `saveLocationPickerProvider`（返回固定 temp 路径）+ `projectArchiveServiceProvider`（fake service 记录调用/抛 LocalIOError）→ 点菜单 Export → 断言 fake 收到 (projectId, path)、成功/失败 snackbar 文案出现。fake service 是纯内存实现，无真 IO（TD-003 安全）。

- [ ] **Step 6: Commit**

```bash
git add lib/features/studio lib/l10n test/features/studio
git commit -m "feat(studio): LB-11 项目卡菜单导出入口——getSaveLocation + 成败 snackbar"
```

---

### Task 6: 全量闸门 + 文档登记 + PR

**Files:**
- Modify: `docs/BOARD.md`（近期落地表加行：`| LB-11 项目导出（整项目 zip=manifest+data+files 全保真，.partial 原子写；产出 LB-12 导入的读侧机器） | #<PR> |`）
- Modify: `docs/MASTERPLAN.md`（§3 硬门槛列表 LB-11 行标 ✅ #<PR>，进度行加 LB-11）
- Modify: `docs/CLAUDE.md`（Project Structure：`core/interfaces` 无需逐文件列出（该段只列目录），`services/` 树加 `project_archive_service.dart` 一行、`storage/repositories` 已是目录级无需改——以该文件现有粒度为准，新增模块同 commit 同步）

- [ ] **Step 1: 自查闸门**

```bash
C:\Users\Kerro\flutter\bin\flutter.bat analyze lib test
C:\Users\Kerro\flutter\bin\flutter.bat test --exclude-tags golden
```

Expected: 0 issues / 全绿。

- [ ] **Step 2: 文档登记 commit**

```bash
git add docs/BOARD.md docs/MASTERPLAN.md docs/CLAUDE.md
git commit -m "docs: BOARD/MASTERPLAN 登记 LB-11 项目导出"
```

- [ ] **Step 3: push + PR（base main）**

```bash
git push -u origin feat/lb-11-project-export
gh pr create --title "feat(storage): LB-11 项目导出——整项目 zip（manifest+data+files 全保真）" --body "<Summary/Test plan，含三条语义拍板与 FK 闭包论证>"
```

- [ ] **Step 4: 对抗评审（playbook 两路评审）→ 修完 P1/P2 → CI 全绿 → squash 合并删分支**

---

## Self-Review 结论

- **卡面覆盖**:manifest 四字段 ✓ / data.json 表清单 ✓（jobs 只带 success-slot 者+其全部 slot ✓）/ files 全量 ✓ / 流式写（逐文件 InputFileStream）✓ / pubspec archive ✓ / 入口=项目卡菜单+getSaveLocation ✓ / plain test() 红测 ✓ / 债#20 借道 ✓ / zip 路径 `/` ✓。
- **超出卡面的语义决策**（全保真含软删）已在「语义拍板」一节给出理由（FK 闭包），评审时作为语义基准输入。
- **已知留白**（有意）:导出进行中的 busy/进度 UI（大项目秒级~分钟级）——v1 只防重入不做进度条，记 BOARD 债表由 LB-12 同窗决定是否统一做传输进度组件。
- **archive API 版本差异**留了核对步骤（Task 3 Step 1），计划内代码按 3.x/4.x 主流签名书写。
