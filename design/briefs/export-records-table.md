# export-records-table · export_records 表：v9 前向迁移 + 仓储 + 列常量 + 手写不可变模型
- 波次 W4 / lane E / 基底 origin/main〔W0–W3 已合入〕
- 依赖切片：无（纯存储层，不碰任何 W0–W3 新文件）
- 阻塞决定：无（SE-Q3 按建议 A：一直留、用户手动移除，不做定期清理）

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，撤销命令按 undo-stack（W0）的实际契约写：每个命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`（`class X extends CanvasCommand`，实现 `String label(AppLocalizations l)`、`Set<String> get affectedNodeIds`、`Future<CanvasCommandOutcome> revert(CanvasCommandEnv env)` / `apply(CanvasCommandEnv env)`，返回 `done / gone / failed`），**不改 canvas_command.dart、不用 part、没有 CanvasCommandLabel 枚举**；操作成功后 `ref.read(canvasHistoryControllerProvider(canvasId).notifier).record(cmd)`（只登记、不执行，拿回步 id）；步名文案键统一前缀 `canvasCommand`（W3 undo-adopt-existing 已用 canvasCommandDeleteNodes 等）；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
本片用户看不到界面变化。库里多一张 `export_records` 表，后面两片（W6 export-records-recording / export-tab-history）往里写、从里读「导出历史」。升级时老库经 v8 → v9 一条前向迁移建表，已有数据不动。

## 设计依据
- ShellExport.dc.html「导出第二批」规则第 1 条：需新表 `export_records`（新增一条前向迁移，落地时按合入顺序编号）：kind（mp4 / delivery / pdf / zip）· 文件 · 镜数 · 时长 · 大小 · status · 设置快照 · created_at。
- 同节规则第 2 条：完成或失败各记一行，取消不记 ⇒ status 只有两种值。
- 「需要你定」Q3：按 ShellExport-Q3 建议 A：一直留，用户手动移除 ⇒ 只有硬删，没有软删 / 清理任务 / updated_at。
- plan.md 第 4 节：编号 v9 已定。**核对 main（f64f56e）**：`lib/storage/migrations/app_migrations.dart` 第 14–23 行最高是 `Migration(version: 8, sql: kSchemaV8)`，`lib/storage/schema/` 最高 `schema_v8.dart`，所以本片就是 v9。
- ADR-0012（docs/adr/0012-forward-migration-as-sole-data-upgrade-path.md）：只加一条连续编号的迁移，发出去就不能改。**下面的 DDL 合入前要主 Agent 单独审一遍。**
- 设计缺口：板上没说导出历史进不进项目包。本片定为**不进**，理由写进 import_schema_sync_test 的豁免（见下）。

## 允许改的文件
- 新 `lib/storage/schema/schema_v9.dart`：`const String kSchemaV9`，DDL 全文见下，头注照 schema_v7.dart / schema_v8.dart 的格式写（版本、生命周期、为什么建表、为什么不进项目包、为什么没有 updated_at / deleted_at）。
- `lib/storage/migrations/app_migrations.dart`：加 `import '../schema/schema_v9.dart';` 和一行 `Migration(version: 9, sql: kSchemaV9),`。
- `lib/core/db/columns.dart`：在 `BatchResultCol` 之后、`SchemaVersionCol` 之前加 `abstract final class ExportRecordCol`（13 个常量，见下）。
- 新 `lib/core/interfaces/export_record_repository.dart`：抽象契约，返回 `Map<String, Object?>` 行（core 不许 import features，见 test/quality/no_reverse_layer_import_test.dart）。
- 新 `lib/storage/repositories/postgres_export_record_repository.dart`：`with BaseRepository implements ExportRecordRepository`，照 postgres_prompt_preset_repository.dart 的写法（guard / firstRow / allRows / `_selectAlive` JOIN projects）。
- `lib/core/di/repositories.dart`：加 import 两行 + `exportRecordRepositoryProvider`（FutureProvider，照第 81–86 行 promptPresetRepositoryProvider）。**不加进 `postgresRepositoryScope` / RepositoryScope**：导出记录是单行写入，从不和别的写入同事务；加进去要改 core/interfaces/unit_of_work.dart、FakeUnitOfWork 和 repository_scope_wiring_test。
- 新 `lib/features/export/models/export_record.dart`：手写不可变模型 + 两个枚举。
- 测试文件（见「测试」）：`test/quality/migration_registry_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/core/db/columns_schema_test.dart`、`test/storage/schema/populated_migration_test.dart`、新 `test/storage/repositories/postgres_export_record_repository_test.dart`、新 `test/storage/repositories/export_record_repository_sql_test.dart`、新 `test/features/export/models/export_record_test.dart`、新 `test/_harness/fake_export_record.dart`、`test/_harness/README.md`（文件清单加一行）、`test/_harness/shell_app.dart`（`sealedShellOverrides` 加一行 override）。

## 不许碰的文件
- W4 其他 lane：canvas_tool_actions.dart、widgets/stage/node_card_slot.dart、shot_config_inspector.dart、util/canvas_history_actions.dart、canvas/models/commands/*（W4 有 create_nodes_command / set_current_slot_command / set_current_take_command 在改）、widgets/stage/stage_lane_layer.dart、inspector_history_panel.dart、theme/components/ink_menu_panel.dart、features/shell/**、batch_results_controller.dart、batch_results_grid.dart、batch_slot_parts.dart、batch_compare_overlay.dart、batch_slot_view.dart、current_take_controller.dart、canvas_view.dart、node_card.dart、drop_placement.dart、canvas_drag_payload.dart、canvas_drop_hover.dart、ink_window_chrome.dart、ink_menu_bar.dart、shell_chrome.dart、shell_menu_bar.dart、shell_task_capsule.dart、task_popover_open.dart。
- 本片不碰：`lib/services/import/import_remapper.dart`、`lib/storage/repositories/postgres_project_archive_reader.dart`、`postgres_project_import_writer.dart`（不进项目包 ⇒ 三份清单都**不加** export_records）、`core/interfaces/unit_of_work.dart`、所有 features/export 下除 `models/export_record.dart` 外的文件。

## 具体改动

### schema_v9.dart（DDL 全文，供主 Agent 审）
```sql
CREATE TABLE export_records (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id        UUID        NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  canvas_id         UUID        REFERENCES canvases(id) ON DELETE SET NULL,
  kind              TEXT        NOT NULL,
  status            TEXT        NOT NULL,
  output_path       TEXT,
  shot_count        INTEGER     NOT NULL DEFAULT 0,
  duration_ms       INTEGER,
  size_bytes        BIGINT,
  error_code        TEXT,
  error_reason      TEXT,
  settings_snapshot JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_export_records_kind       CHECK (kind IN ('mp4', 'delivery', 'pdf', 'zip')),
  CONSTRAINT chk_export_records_status     CHECK (status IN ('succeeded', 'failed')),
  CONSTRAINT chk_export_records_output     CHECK (status = 'failed' OR output_path IS NOT NULL),
  CONSTRAINT chk_export_records_shot_count CHECK (shot_count >= 0)
);

CREATE INDEX idx_export_records_project_created ON export_records(project_id, created_at DESC);
CREATE INDEX idx_export_records_canvas_id       ON export_records(canvas_id);
```
列语义（写进头注）：
- `output_path`：**项目根相对路径**（`exports/x.mp4`、交付写工程文件 `exports/<名>.edl`），与 `ExportVideoSuccess.relativePath`、`DeliveryOutcome.outputDirRelative` 同一口径；显示时经 `FileResolverService.resolveInProject` 换绝对路径。不存绝对路径：DIR-1 搬过根目录后绝对路径会失效。失败行可为 null。
- `canvas_id` 用 `ON DELETE SET NULL`：画布硬删后「全部」里的历史仍在，只是归不到画布；项目硬删整批跟着删（CASCADE）。
- `kind` / `status` 的 CHECK 一次写全四种 kind（pdf / zip 由 W15 / W18 的切片写），之后加格式不需要再迁移。
- `error_code` = `InkErrorCode.wire`；`error_reason` = `InkError.extra['reason']`（如 `ffmpeg_not_found`），用来出「失败 · 找不到 ffmpeg」。
- `settings_snapshot`：内容由 export-records-recording 定义（镜头顺序 / 输出名 / 交付设置），本片只存不解析。
- 没有 `updated_at` / `deleted_at`：行写入后从不 UPDATE；「从历史移除」是硬删（SE-Q3 A）。test/quality/updated_at_test.dart 只扫 UPDATE 语句，本表没有 UPDATE，不用进它的白名单。
- 全是 CREATE，没有 ADD COLUMN / SET NOT NULL / DROP DEFAULT ⇒ import_schema_sync_test 组 C 不受影响。

### columns.dart
```dart
abstract final class ExportRecordCol {
  static const id = 'id';
  static const projectId = 'project_id';
  static const canvasId = 'canvas_id';
  static const kind = 'kind';
  static const status = 'status';
  static const outputPath = 'output_path';
  static const shotCount = 'shot_count';
  static const durationMs = 'duration_ms';
  static const sizeBytes = 'size_bytes';
  static const errorCode = 'error_code';
  static const errorReason = 'error_reason';
  static const settingsSnapshot = 'settings_snapshot';
  static const createdAt = 'created_at';
}
```

### export_record_repository.dart
```dart
abstract class ExportRecordRepository {
  /// 写一行，返回新 id。kind / status 传协议字面量（'mp4' / 'succeeded' …）。
  Future<String> create({
    required String projectId,
    String? canvasId,
    required String kind,
    required String status,
    String? outputPath,
    int shotCount = 0,
    int? durationMs,
    int? sizeBytes,
    String? errorCode,
    String? errorReason,
    Map<String, Object?> settingsSnapshot = const <String, Object?>{},
  });

  /// 活项目下的全部记录，created_at DESC, id DESC（同一毫秒内也稳定）。
  Future<List<Map<String, Object?>>> listByProject(String projectId);

  /// 「从历史移除」：硬删一行，只删记录不删文件。返回影响行数。
  Future<int> hardDelete(String id);
}
```
Postgres 实现要点：
- `create`：`INSERT INTO export_records (...) VALUES (... , @snap::jsonb) RETURNING id`；参数 `'snap': jsonEncode(settingsSnapshot)`——与 postgres_node_repository.dart 第 36 / 51 行 `@cfg::jsonb` + `jsonEncode(typeConfig)` 同一写法，不另造。
- `listByProject`：`static const _selectAlive = 'SELECT er.* FROM export_records er JOIN projects p ON p.id = er.project_id AND p.deleted_at IS NULL'`，过滤写在 JOIN 条件里（理由同 postgres_prompt_preset_repository.dart 第 48–52 行头注）；`WHERE er.project_id = @pid ORDER BY er.created_at DESC, er.id DESC`。
- `hardDelete`：`DELETE FROM export_records WHERE id = @id`。
- 三个方法都包 `guard(op, 'export_records', …)`。

### export_record.dart（手写不可变，照 gallery_selection.dart：@immutable + == / hashCode，不用 freezed）
```dart
enum ExportKind { mp4('mp4'), delivery('delivery'), pdf('pdf'), zip('zip');
  const ExportKind(this.wire); final String wire;
  static ExportKind? fromWire(Object? v); }
enum ExportRecordStatus { succeeded('succeeded'), failed('failed');
  const ExportRecordStatus(this.wire); final String wire;
  static ExportRecordStatus? fromWire(Object? v); }

@immutable
class ExportRecord {
  const ExportRecord({required this.id, required this.projectId, this.canvasId,
    required this.kind, required this.status, this.outputPath, required this.shotCount,
    this.durationMs, this.sizeBytes, this.errorCode, this.errorReason,
    required this.settingsSnapshot, required this.createdAt});
  final String id; final String projectId; final String? canvasId;
  final ExportKind kind; final ExportRecordStatus status;
  final String? outputPath; final int shotCount; final int? durationMs; final int? sizeBytes;
  final String? errorCode; final String? errorReason;
  final Map<String, Object?> settingsSnapshot; // 不可变视图（Map.unmodifiable）
  final DateTime createdAt; // UTC
  bool get succeeded;
  /// 行解码；kind / status 不认识、id / created_at 缺失 → null（坏行跳过，不让整张列表失败）。
  static ExportRecord? fromRow(Map<String, Object?> row);
}
```
- 解码走 `lib/core/db/row_reader.dart` 的 `DbRow`（reqId / optId / optString / optInt / optDateTime）；`settings_snapshot` 驱动可能回 Map 也可能回 JSON 文本，两者都收，其他类型当 `{}`。
- `==` 比较 settingsSnapshot 用 `mapEquals`（foundation），hashCode 不含 snapshot 内容（只含 id 等标量）以免深哈希。

### DI（repositories.dart）
```dart
final exportRecordRepositoryProvider = FutureProvider<ExportRecordRepository>((ref) async { … }, name: 'exportRecordRepositoryProvider');
```

## 行为规则与边界情况
1. 全新库：迁移链跑完 `schema_version = 9`，`export_records` 存在且为空。
2. 老库（v8 带数据）：v9 只建表建索引，前 8 版的行数、值逐一不变（populated_migration_test 覆盖）。
3. 降级：v9 库被只有 8 条迁移的版本打开 → `SchemaDowngradeError`（populated_migration_test 第 3 段用 `sublist(0, length-1)`，自动覆盖）。
4. `kind` 不在四种里、`status` 不在两种里、`status='succeeded'` 且 `output_path IS NULL`、`shot_count < 0` → 插入被 CHECK 拒绝（仓储翻成 `LocalIOError`，extra.db_code = '23514'）。
5. 项目软删 → `listByProject` 读不到；恢复后又读得到。项目硬删 → 行被 CASCADE 删掉。
6. 画布硬删 → 行还在，`canvas_id` 变 null。
7. 同一 created_at 的两行，按 id DESC 稳定排序。
8. `hardDelete` 不存在的 id → 返回 0，不抛。
9. `ExportRecord.fromRow`：kind = 'gif' / status = 'cancelled' / id 缺失 → null；`settings_snapshot` 是 JSON 文本 `'{"a":1}'` → 解出 `{'a': 1}`；是 null → `{}`；`created_at` 是 DateTime 或 ISO 串都归一到 UTC。
10. 项目包：导出（archive reader）不读这张表，导入（remapper / writer）不写这张表；导入后的新项目历史为空。

## 新文案键
无。

## 测试
- `test/quality/migration_registry_test.dart`：加 `import 'package:inkframe/storage/schema/schema_v9.dart';`，映射表加 `9: kSchemaV9`。现有 5 条用例自然覆盖连续性与引用一致。
- `test/quality/import_schema_sync_test.dart`（不改闸的判据，只登记豁免并加反向护栏）：
  - `_notTables` 加 `'ExportRecordCol': 'export_records（v9）是本机导出历史，不进项目包（SE-Q3 A）：settings_snapshot 里存着节点 id，进包就得让 import_remapper 改写它们才不悬空；导入后的项目从空历史开始'`。
  - 组 B 加常量 `_jsonbNotArchived = <String, String>{'settings_snapshot': '同 _notTables.ExportRecordCol：写入端从不写这张表'}`；在比较前先断言每个豁免列确实出现在 `fromMigrations` 里（豁免过期即红），再 `fromMigrations.removeAll(_jsonbNotArchived.keys)`。
  - 新用例 `'export_records 不进项目包（反向，源码级）'`：`postgres_project_archive_reader.dart`、`postgres_project_import_writer.dart`、`import_remapper.dart` 三个源文件都 `isNot(contains('export_records'))`。
- `test/core/db/columns_schema_test.dart`（pg）：`expected` 加 `'export_records': [ExportRecordCol 全部 13 个]`；`tableOf` 加 `'ExportRecordCol': 'export_records'`。
- `test/storage/schema/populated_migration_test.dart`（pg）：`seeders` 加 `9: () => _seedV9(conn)`（给 p1 插一行 mp4 succeeded），并加 `expect(await count('SELECT count(*) FROM export_records'), 1)`。
- 新 `test/storage/repositories/export_record_repository_sql_test.dart`（不连库；自带一个最小 spy Session，照 repository_sql_templates_test.dart 第 529 行 `_SpySession` 抄一份）：
  - `create 用 INSERT … RETURNING id 并绑定全部参数`：断言 SQL 含 `INSERT INTO export_records`、`RETURNING id`，参数里 kind='mp4'、status='succeeded'、snapshot 是 JSON。
  - `listByProject 只读活项目`：SQL 含 `JOIN projects p ON p.id = er.project_id AND p.deleted_at IS NULL`。
  - `listByProject 按 created_at DESC, id DESC`：SQL 含 `ORDER BY er.created_at DESC, er.id DESC`。
  - `hardDelete 是 DELETE 不是 UPDATE`：SQL 以 `DELETE FROM export_records` 开头。
- 新 `test/storage/repositories/postgres_export_record_repository_test.dart`（`@Tags(['pg'])`，照 postgres_repositories_integration_test.dart 第 1018 行的 req() / _Skip 写法）：
  - `全链路：create → listByProject → hardDelete`：两行按时间倒序；snapshot 往返相等；hardDelete 返回 1，再删返回 0。
  - `CHECK：未知 kind / 未知 status / 成功行缺 output_path / 负镜数 → LocalIOError(db_code 23514)`（四个子断言）。
  - `失败行可不带 output_path`：status='failed'、outputPath=null 插入成功。
  - `项目软删后读不到、恢复后又读到`。
  - `画布硬删 → canvas_id 置 null，行还在`。
  - `项目硬删 → 记录随之删除`。
- 新 `test/features/export/models/export_record_test.dart`：
  - `fromRow 解出全部字段`；`未知 kind → null`；`未知 status → null`；`缺 id → null`；`snapshot 是 JSON 文本 / Map / null 三种都收`；`created_at 字符串归一到 UTC`；`== 与 hashCode：同值相等`。
- 新 `test/_harness/fake_export_record.dart`：`FakeExportRecordRepo implements ExportRecordRepository`，内存 Map；`failCreate` / `failDelete` 开关抛 `LocalIOError`；`createCalls` 计数；`listByProject` 按 createdAt 倒序（fake 自己用递增的假时钟写 created_at）。`test/_harness/shell_app.dart` 的 `sealedShellOverrides` 加 `exportRecordRepositoryProvider.overrideWith((_) async => FakeExportRecordRepo())`（外壳测试不能去起真 PG）。

## 变异点
1. app_migrations.dart 删掉 `Migration(version: 9, …)` 一行 → migration_registry_test「每条迁移引用对应 kSchemaVN 常量」红（条数不等）。
2. `Migration(version: 9, sql: kSchemaV8)`（引用错常量）→ 同一条用例红（identical 失败）。
3. 仓储 `_selectAlive` 去掉 `AND p.deleted_at IS NULL` → sql_test「只读活项目」红；pg 测「项目软删后读不到」红。
4. `ORDER BY er.created_at DESC, er.id DESC` 改成 `ASC` → sql_test 排序用例红；pg 全链路用例的顺序断言红。
5. DDL 删掉 `chk_export_records_output` → pg「成功行缺 output_path」子断言红。
6. `canvas_id … ON DELETE SET NULL` 改成 `ON DELETE CASCADE` → pg「画布硬删 → canvas_id 置 null」红。（注意：迁移一旦合入不可改，这条变异只在合入前做。）
7. `ExportKind.fromWire` 未知值回落 `mp4` 而不是 null → model test「未知 kind → null」红。
8. columns.dart 多写一个 `static const foo = 'foo';` 进 ExportRecordCol → columns_schema_test（pg）双向比对红；同时 import_schema_sync_test 不受影响（_notTables 豁免整类）。
9. 在 postgres_project_archive_reader.dart 里加一条 `SELECT * FROM export_records …` → import_schema_sync_test「不进项目包」红。
10. 删掉 `_jsonbNotArchived` 的豁免 → import_schema_sync_test 组 B 红（settings_snapshot 在迁移里是 JSONB、写入端没有）。

## 验收
- `flutter analyze lib test` 零告警；`flutter test test/quality test/features/export/models test/storage/repositories/export_record_repository_sql_test.dart`；有 TEST_PG_URL 时 `flutter test --tags pg test/storage test/core/db`。
- 主 Agent 单独审「具体改动」里的 DDL 全文（ADR-0012：合入即不可改）：重点看 CHECK 枚举值是否够后续 pdf / zip 片用、`canvas_id` 的 SET NULL、`output_path` 为项目相对路径的约定。
- 非 UI 片，无截图。
- 合入后由主 Agent 在 docs/CLAUDE.md 项目结构里登记：`core/interfaces/export_record_repository.dart`、`storage/repositories/postgres_export_record_repository.dart`、`features/export/models/export_record.dart`、schema v9。

## 风险与不确定
- **迁移不可改**：CHECK 只放了 mp4 / delivery / pdf / zip。若以后剪映草稿 / FCPXML 要算独立 kind，需要新迁移改约束；本片按「交付 = delivery，目标软件放进快照」定，剪映 / FCPXML 都归 delivery。
- `duration_ms` 用 INTEGER（约 24 天上限，够用）；`size_bytes` 用 BIGINT（视频可超 2 GB），与 batch_results.file_size_bytes 同型。
- 不进项目包是本片自定（板上没写）；若主 Agent 改成要进包，需要同时改 archive reader、remapper（node_ids 改写）、writer 的 `_jsonbCols` 和 import_schema_sync 白名单——工作量明显变大。
- `listByProject` 不分页（SE-Q3 A 一直留）。行很小，几百行的列表由 export-tab-history 用 ListView.builder 画；若将来上千行再加 limit 参数。
