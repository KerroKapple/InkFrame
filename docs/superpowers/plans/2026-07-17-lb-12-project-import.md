# LB-12 项目导入（ID 重映射 + JSONB/FK 重写）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 全计划最大风险卡（W4 压轴）。本计划先经三镜头设计评审再执行。

**Goal:** LB-11 导出的 zip 一键导入为新项目：全表旧→新 UUID、FK/JSONB 重写、files/ 树改名落盘；损坏/恶意/版本不符的包显式拒绝且零残留。产出 BP-11 项目复制的全部机器。

**Architecture:** 四层分工——①`archive_import_guard.dart` 纯函数（zip slip 校验 + manifest 门）②`import_remapper.dart` 纯函数（ID 重映射 + FK 重写 + 列白名单过滤 + canvas 目录改名映射）③`PostgresProjectImportWriter`（专用写侧，raw INSERT + runTx 单事务按 FK 序——仓储 create() 不收显式 id/时间戳，导入要保真）④`ZipProjectImportService` 编排（校验→解析→重映射→写库→**提交后**提取 files/→失败补偿=级联硬删项目+删目录，零残留）。UI=Studio 导入入口 + `openFilePickerProvider` seam。

**Tech Stack:** archive、uuid（已在 pubspec）、postgres v3 runTx、file_selector openFile。

## Global Constraints

- 分支 `feat/lb-12-project-import`；conventional commits；每 commit `flutter analyze lib test` + `flutter test --exclude-tags golden`；pg 集成测本地 Docker postgres:17 预演。
- 注释中文；内部字符串 English-only；ARB en+zh + gen-l10n；零硬编码样式；InkError 链；plain test() 真 IO；#188 P1-1 惯例；CI 真绿核验（sleep 75 再 watch + 合并前一次性 checks）。
- **红测先行**是卡面硬要求：roundtrip 与恶意 zip 两组测试先写。

## 语义拍板（三镜头评审的输入基准）

1. **版本门**：`formatVersion != 1` → `failedFormat` 拒绝；`schemaVersion > kAppMigrations.last.version` → `failedVersionNewer` 拒绝（Zero-BC）；`≤ 当前` 放行——插入按**当前列白名单**过滤（迁移史含 v4 drop 列；老包多余键丢弃并 warn 计数）。白名单来源=columns.dart 各 *Col 常量的显式 const Set（NodeCol.projectId 这类 join 派生列不入白名单）。
2. **重映射面**（卡面清单 + 勘察补遗）：projects.id/cover_node_id；canvases.id/project_id；style_lanes.id/canvas_id；nodes.id/canvas_id/source_node_id/lane_id；edges.id/canvas_id/source_node_id/target_node_id；characters.id/project_id；prompt_presets.id/project_id；jobs.id/canvas_id/source_node_id/result_node_id；batch_results.id/node_id/job_id/**promoted_node_id**（卡面「三 id」漏此 FK，勘察补上）。悬空引用（指向包内不存在的 id）→ 置 NULL 并 warn（宽容导入：LB-11 全保真闭包下不应出现，防御第三方手工包）。
3. **路径重写**：nodes.type_config / batch_results.output_url 为 canvas 相对——无需重写 ✓；files/ 树 `canvases/{旧id}` 段按映射改名 ✓；**characters.reference_image_paths 为项目相对**——常规形态 `characters/<file>` 原样，防御性重写 `canvases/{旧id}/` 前缀（勘察确认可能形态）。
4. **zip 安全（rev2，安全评审 2×P1+P2 簇全并入）**：
   a. **声明尺寸只作早期粗筛，绝不作防线**（archive 包 `uncompressedSize` 是攻击者可任写的 zip 头声明值）——真防线=**流式解压计数 sink**：files 逐条目 writeTo 与 data.json/manifest 读取全部经计数包装，实际字节超限即刻中止（单条目 2GB / 总量 16GB / data.json 单独 256MB）→ `failedCorrupt`；
   b. **重复条目名整包拒绝**（ZipDecoder 去重后内容取首个、元数据取末个的分裂来源——正版 LB-11 导出绝无重名，拒绝零成本关掉整类）；guard 与提取共用**同一个**解码后 Archive 对象，杜绝「验一份、解另一份」；
   c. 条目名正面校验：拒绝绝对路径/`..` 段/盘符/反斜杠/控制字符/非法 UTF-8/**Windows 保留设备名**（复用导出侧 `_kReservedNames`，含剥扩展名后比较）/结尾点或空格；名单外条目（非 manifest.json/data.json/files/**）拒绝；最终落盘路径长度预检（MAX_PATH 余量）；
   d. `files/canvases/{seg}` 的 seg 必须 **UUID 形** 且命中 canvasIdMap（未知/畸形段=拒绝——孤儿目录注入关死）；
   e. 符号链接条目拒绝（`isSymbolicLink` 仅 Unix 属性位可靠——保留该检查但不依赖；本实现绝不使用 `extractArchiveToDisk`、绝不创建 Link，加断言测试）；
   f. **纵深防御**：最终写盘路径一律经 `FileResolverService.resolveInProject(newId, rel)` 二次界内校验（改名发生在 guard 之后，必须在 join 点重验）。
5. **顺序与补偿（rev2，事务轴自决——崩溃窗口收口）**：**files 先行、DB 最后**：
   ① 解压（经计数 sink）到 staging 目录 `projects/.import-<tmpToken>/`（canvases/{旧} 段按映射改名）→
   ② staging 整体 rename 为 `projects/{newProjectId}/`（单次目录 rename）→
   ③ runTx 单事务写全部行（FK 序：project → canvases → style_lanes → nodes 两趟（先 source_node_id/lane_id 置 NULL 后 patch）→ edges → characters → prompt_presets → jobs → batch_results → projects.cover_node_id 补丁）。
   失败补偿：③ 失败→删 `projects/{newProjectId}` 目录（无行无引用，删净即零残留）；①/② 失败→删 staging。崩溃窗口（②后③前/③中断电）残留=**一个无行背书的孤儿目录**——不可见、无害（对比 rev1 的「行在图裂的可见残缺项目」）；启动清扫 `.import-*` 残留目录（service init 顺手，一行 listSync）。补偿自身失败→ ERROR 日志（含路径）不扩散。
6. **命名与时间戳**：导入行保真（created_at/updated_at/deleted_at 原样——回收站随包恢复，与 LB-11 全保真对偶）；项目名原样（同名容忍，BOARD 既有债口径）；导入的项目获得全新 id，绝不与既有行冲突。
7. **jobs 终态化（rev2 补全）**：批量部分成功期间 job 仍 polling——导入时非终态 status 改写 `cancelled` **并补写 completed_at（=该行 created_at；#149 孤儿回收教训：终态行必须有 completed_at）**；slot generating → `cancelled` 同补 completed_at。这些行全有 success slot，purge 的 success-slot 守卫（#163）本就永久保护。roundtrip DoD 表述修正：行数相等 + 字段抽查相等，**除拍板 7 的显式改写字段**（单独断言：在途种子 job 导入后 status=cancelled 且 completed_at 非空）。
8. **type_config 内 id 形引用核查（数据轴强制项）**：Task 2 实现前 grep 全部 type_config 写点（inspector/controller/persister），确认是否存在 character_ids/节点引用类键——有则入重映射面，无则在 PR body 记录论证与 grep 证据。
9. **重操作互斥**：新增 `projectImportBusyProvider`（app 级）；导入入口在 `databaseRestoreBusyProvider || projectExportBusyProvider || importBusy` 任一为真时禁用（三大重操作互不并发；反向禁用记 BOARD 小债——还原/导出侧本卡不回改）。导入成功后 `selectedProjectIdProvider` 自动选中新项目 + workspace invalidate + toast。

## Tasks（每个含红测先行 + commit）

### Task 1: archive_import_guard 纯函数（zip 门 + manifest 门）
**Files:** Create `lib/services/import/archive_import_guard.dart`；Test `test/services/import/archive_import_guard_test.dart`
**Produces:**
```dart
class ImportGuardResult { final String? rejectReason; ... } // null=放行
/// 条目名+尺寸校验（拍板 4 全清单）；[entries]=(name, uncompressedSize, isSymlink)
ImportGuardResult validateArchiveEntries(List<ArchiveEntryMeta> entries);
/// manifest 校验（拍板 1）：返回 rejectReason 或 null。
String? validateManifest(Map<String, Object?> manifest, {required int currentSchemaVersion});
```
红测（rev2 扩）：`../evil`、`C:\abs`、`/abs`、`a\\b`、symlink 标记、超声明单条目/总量（早期粗筛）、名单外条目（`foo.txt`）、**重复条目名**、**NUL.png/CON 等保留名（含剥扩展名比较）**、**结尾点/空格**、**控制字符段**、**files/canvases/{非 UUID 段}**、**超长最终路径** 全拒；合法清单放行；formatVersion 2 / schemaVersion 超前拒、等于当前放行。计数 sink 纯类 `CountingLimitSink`（超限抛）单测：真 deflate 小体积/大解压流被实测字节截停。

### Task 2: import_remapper 纯函数
**Files:** Create `lib/services/import/import_remapper.dart`；Test `test/services/import/import_remapper_test.dart`
**Produces:**
```dart
class ImportPlanData {
  final String newProjectId;
  final Map<String, String> canvasIdMap; // 旧→新（files/ 改名用）
  final Map<String, Object?> project;    // 已重写+白名单过滤
  final List<Map<String, Object?>> canvases, lanes, nodes, edges,
      characters, presets, jobs, batchResults;
  final int droppedColumnCount, nulledRefCount;
}
ImportPlanData remapArchiveData(Map<String, dynamic> dataJson, {required String Function() newId});
```
newId 注入（测试确定性）；生产用 `const Uuid().v4`。红测：①全 FK 闭包保持（新 id 集合自洽，无旧 id 残留于任何值）②自引用 nodes source 链正确 ③cover_node_id/promoted_node_id 重写 ④悬空引用置 NULL+计数 ⑤未知列丢弃+计数（种 `next_poll`）⑥非终态 jobs/slots → cancelled（拍板 7）⑦characters 路径 `canvases/{旧}/` 前缀重写 ⑧canvasIdMap 完整。

### Task 3: PostgresProjectImportWriter（写侧 + pg 集成测）
**Files:** Create `lib/core/interfaces/project_import_writer.dart`、`lib/storage/repositories/postgres_project_import_writer.dart`；Test `test/storage/repositories/project_import_writer_integration_test.dart`
**Produces:** `Future<void> writeAll(ImportPlanData plan)`——runTx 单事务按拍板 5 顺序 raw INSERT；JSONB 列（type_config/parameters/reference_image_paths）`jsonEncode + @c::jsonb`；两趟 patch（nodes.source_node_id/lane_id、projects.cover_node_id）；guard 翻 LocalIOError。
红测（pg tag）：写入一份手工 plan → 各表行数/字段回读相等（含 deleted_at 保真、JSONB 往返、时间戳保真）；事务性——最后一表种非法行（FK 悬空）→ 整体回滚零残留。

### Task 4: ZipProjectImportService 编排 + 恶意/损坏 zip 红测
**Files:** Create `lib/core/interfaces/project_import_service.dart`、`lib/services/project_import_service.dart`；Modify `lib/core/di/project_archive.dart`（或新 di 文件）；Test `test/services/project_import_service_test.dart`
**Produces:**
```dart
enum ImportOutcome { imported, failedFormat, failedVersionNewer, failedCorrupt, failed }
class ImportResult { final ImportOutcome outcome; final String? newProjectId; }
Future<ImportResult> importArchive({required String zipPath});
```
流程（rev2 顺序）：读 zip（单一 Archive 对象供门+提取共用）→ Task1 双门（含重名拒绝）→ data.json 经计数 sink 读取解析（超限/损坏→failedCorrupt）→ Task2 重映射（含 files 条目 seg∈canvasIdMap 校验）→ **staging 提取**（逐文件计数 sink 流式 + resolveInProject 二次界内校验，路径=staging 根）→ **rename staging→projects/{newId}** → Task3 writeAll → 成功；失败补偿=删对应目录（拍板 5）；service init/首次导入前清扫 `.import-*` 残留。
红测（plain，fake writer 记录/可抛）：恶意 zip（`../x`）→ failed 零调用零文件；**谎报尺寸 zip bomb（声明 0 实胀超限）→ failedCorrupt 且落盘量有界**；**重名 manifest → failedCorrupt**；损坏 zip → failedCorrupt 零残留；writer 抛错 → 已 rename 的项目目录被删零残留；**全程不创建 Link 断言**；`.import-*` 启动清扫。

### Task 5: Roundtrip 大红测（卡面 DoD）
**Files:** Test `test/services/project_roundtrip_integration_test.dart`（pg tag）
真链路：repos 种满配项目（软删画布/节点、含 success+failed slot 的 job、角色带资产路径、预设、cover）→ 真 `ZipProjectArchiveService.exportProject` → 真 `ZipProjectImportService.importArchive` 同库 → 断言：各表新项目行数 == 原行数；`listSuccessByProject(new)` 与原画廊逐项对齐（路径经 canvasIdMap 换算）；files/ 磁盘树逐文件字节相等（种子真文件）；新旧 id 零交集。

### Task 6: UI 入口 + l10n
**Files:** Create picker seam（`openFilePickerProvider`——`core/di/project_archive.dart` 旁）；Modify Studio home（「新建项目」旁导入入口，实勘现有按钮布局后定点）；ARB ×2 + gen-l10n；Widget tests。
键：`studioImportProject`（Import project…/导入项目…）、`importInProgress`（Importing…/正在导入…）、`importDone`（Project imported/项目已导入）、`importFailedFormat`（Not an InkFrame project archive/不是 InkFrame 项目包）、`importFailedVersionNewer`（复用 restoreFailedVersionNewer 文案口径/该项目包来自更新版本的 InkFrame）、`importFailedCorrupt`（Archive failed verification/项目包校验未通过）、`importFailed`（Import failed/导入失败）。
流程：picker(zip 过滤)→barrier 模态（LB-22 同款）→service→成功 invalidate workspace+toast；busy app 级 provider（导入分钟级，跨页守卫——LB-22 P1-2 教训）。
测试：成败/取消/防重入/各 outcome 文案。

### Task 7: docs + 闸门 + PR + 对抗评审
BOARD 落地行（#192 预写核验）+「项目复制」行备注（BP-11 机器就绪）+ M1 补遗表项目复制行更新；MASTERPLAN §3 LB-11/12 行 → LB-12 ✅；SETUP.md 导入一句；docs/CLAUDE.md services/import 树。全量闸门（Docker PG）→ PR → 对抗评审（重点=重映射完备性/事务补偿/zip 安全/roundtrip 真伪）→ 修 P1/P2 → CI 真绿 → squash。

## Self-Review

卡面全覆盖：manifest 拒绝 ✓ 全表映射 ✓（+promoted_node_id 补遗）重写清单 ✓ files 改名 ✓ zip slip+上限 ✓ 单事务+提交后文件+补偿 ✓ roundtrip/恶意 zip 红测 ✓ BP-11 机器 ✓。
已知风险留白：导入进度粒度（barrier 转圈，无百分比——与导出同债）；并发导入两次同包=两个独立新项目（合法语义，非 bug）；jobs 终态化改写是拍板 7 的新语义（评审重点验）。
