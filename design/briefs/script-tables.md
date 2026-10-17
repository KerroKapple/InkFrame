# script-tables · 剧本两张表：script_documents + script_paragraphs（迁移 v10）
- 波次 W10 / lane D / 基底：origin/main（W0–W9 已合入）；依赖切片：export-records-table（W4，占 v9）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
本片没有界面变化。给剧本落一个家：每张画布最多一份剧本（script_documents），剧本按段存原文、每段可关联一个镜头节点（script_paragraphs.node_id）。项目包导出 / 导入带上这两张表，导入后段落仍指向新画布上的同一镜。W11 script-import 往里写，W12 rail-script-panel 读出来画左栏剧本页。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/RailScript.dc.html` ›「剧本 P1 · 原文逐段对到镜头」：「需新表 script_documents + script_paragraphs（含 node_id）；新增一条前向迁移；项目包白名单同步，导入时 node_id 随 import_remapper 改写」；「镜头删了标『已删』，可重建」（节点是软删，「已删」看 nodes.deleted_at，硬删时 node_id 置空）。
- 同板「需要你定」R1 建议 B（原文划选「设为角色」→ 虚线候选，可新建 / 关联 / 忽略）：候选与忽略状态要落库，本片顺手在 script_documents 上放 `character_candidates JSONB`，免得 W13 script-import-characters 再加一条迁移。
- 同板 R2 建议 B（重新导入逐段比对）、R4 建议 A（原文只读）：段落行带 `deleted_at`，比对时删掉的段软删、可标出。
- plan.md 第 4 节：v10 = script-tables（v9 已给 export-records-table）；第 0 节：core/di 一服务一文件，但仓储统一在 `core/di/repositories.dart`。
- 设计缺口：RailScript 没说一张画布能不能有多份剧本——本片按「一画布一份」做（UNIQUE(canvas_id)），追加 = 往同一份里续段。
- 设计缺口：剧本有没有标题 / 能不能单独删整份剧本，板上没画；本片不放 title、documents 不带 deleted_at（随画布级联）。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/storage/schema/schema_v10.dart`（新）：`kSchemaV10`，DDL 全文见下。
- `lib/storage/migrations/app_migrations.dart`：import + `Migration(version: 10, sql: kSchemaV10)`。
- `lib/core/db/columns.dart`：新增 `ScriptDocumentCol`、`ScriptParagraphCol`。
- `lib/core/interfaces/script_repository.dart`（新）：`ScriptRepository` 契约。
- `lib/storage/repositories/postgres_script_repository.dart`（新）：`PostgresScriptRepository with BaseRepository`。
- `lib/core/di/repositories.dart`：`scriptRepositoryProvider`；`postgresRepositoryScope` 加 `scripts: PostgresScriptRepository(s)`。
- `lib/core/interfaces/unit_of_work.dart`：`RepositoryScope` 加 `ScriptRepository get scripts;`（RepositoryScope 只有 3 个实现：RepositoryScopeData、postgresRepositoryScope 装配、FakeRepositoryScope，不是 UnitOfWork 本身）。
- `lib/storage/postgres_unit_of_work.dart`：`RepositoryScopeData` 加 `scripts` 字段。
- `lib/features/storyboard/models/script_document.dart`（新）：手写不可变模型 `ScriptDocument` / `ScriptParagraph` / `ScriptCharacterCandidate`（`@immutable` + `==`/`hashCode` + `fromRow`），照 `features/storyboard/models/sequence_shot.dart` 的写法——freezed 生成仍被 build_runner 卡点挡着（docs/BOARD.md 第 161 行），不新增 .freezed.dart。
- `lib/core/interfaces/project_archive_reader.dart`：`ProjectArchiveSnapshot` 加 `scriptDocuments`、`scriptParagraphs` 两个字段，接口注释「9 张表」改 11。
- `lib/storage/repositories/postgres_project_archive_reader.dart`：同一 REPEATABLE READ 事务里多读两张表（含软删、含软删画布下的）。
- `lib/services/project_archive_service.dart`：data.json 加 `'script_documents'`、`'script_paragraphs'`；`kArchiveFormatVersion` 不动。
- `lib/core/models/import_plan_data.dart`：加 `scriptDocuments`、`scriptParagraphs`。
- `lib/services/import/import_remapper.dart`：两个白名单 `_scriptDocumentCols` / `_scriptParagraphCols` + 第 10、11 步重映射。
- `lib/storage/repositories/postgres_project_import_writer.dart`：插入两张表；`_jsonbCols` 加 `ScriptDocumentCol.characterCandidates`。
- 测试（改 / 新）：`test/_harness/fake_unit_of_work.dart`（FakeRepositoryScope 加可选 `scripts`）、`test/_harness/fake_script_repository.dart`（新，内存版，供 W11 script-import 复用）、`test/quality/import_schema_sync_test.dart`、`test/quality/migration_registry_test.dart`、`test/core/db/columns_schema_test.dart`、`test/storage/schema/populated_migration_test.dart`、`test/storage/schema/cascade_test.dart`、`test/storage/schema/violation_matrix_test.dart`、`test/storage/repositories/postgres_script_repository_test.dart`（新）、`test/storage/transaction_integration_test.dart`、`test/core/di/repository_scope_wiring_test.dart`、`test/core/di/repositories_binding_test.dart`、`test/services/import/import_remapper_test.dart`、`test/services/project_roundtrip_integration_test.dart`、`test/storage/repositories/project_archive_reader_integration_test.dart`、`test/storage/repositories/project_import_writer_integration_test.dart`、`test/services/project_archive_service_test.dart`（_FakeReader 补两个字段）、`test/core/di/project_archive_provider_test.dart`（同上）、`test/features/storyboard/models/script_document_test.dart`（新）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- batch-run-executor：`lib/features/generation/generation_controller.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`lib/features/shell/widgets/shell_task_capsule.dart`、新 `batch_run_controller.dart`。
- next-shot：`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`widgets/shot_config_inspector.dart`、新 `util/next_shot.dart` / `providers/next_shot_controller.dart` / `shortcuts/next_shot_keys.dart`。
- tc-next-shot-first-frame：`widgets/video_config_inspector.dart` 及其新文件（`util/next_shot_frame.dart`、`util/canvas_next_frame_actions.dart`、`canvas_menu/next_frame_menu_entries.dart`、`models/commands/replace_role_edge_command.dart`）；`canvas_menu/menu_registry.dart`（W10 归它追加一行）。
- system-notifications：`pubspec.yaml`、`pubspec.lock`、平台插件注册文件、`lib/main.dart`、`toast_center.dart`、`toast_entry.dart`、`notification_prefs.dart`、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`、通知设置页、`job_notification_listener.dart`，及新 `lib/core/interfaces/system_notification_service.dart` / `lib/services/local_notifier_system_notification_service.dart` / `lib/services/noop_system_notification_service.dart` / `lib/core/di/system_notification.dart` / `lib/features/settings/providers/system_notify_pref_controller.dart`。
- next-shot 另有：`canvas_shortcut_registry.dart` 追加一行（本片不加键）。
- 全波：`util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_shortcuts.dart` 骨架与注册表（本片不加键）、`models/canvas_command.dart`；storyboard 下的 controller / splitter / dialog（W11 script-import 的）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：system-notifications：`lib/core/interfaces/toast_service.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/settings/widgets/notifications_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
DDL（`kSchemaV10` 全文，主 Agent 合入前单独审；迁移一发出就不可改）：
```sql
CREATE TABLE script_documents (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  canvas_id            UUID        NOT NULL REFERENCES canvases(id) ON DELETE CASCADE,
  character_candidates JSONB       NOT NULL DEFAULT '[]'::jsonb,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_script_documents_canvas UNIQUE (canvas_id),
  CONSTRAINT chk_script_documents_candidates CHECK (jsonb_typeof(character_candidates) = 'array')
);

CREATE TABLE script_paragraphs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID        NOT NULL REFERENCES script_documents(id) ON DELETE CASCADE,
  sort_order  INTEGER     NOT NULL DEFAULT 0,
  source_text TEXT        NOT NULL DEFAULT '',
  node_id     UUID        REFERENCES nodes(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at  TIMESTAMPTZ,
  CONSTRAINT chk_script_paragraphs_text CHECK (char_length(source_text) <= 131072)
);

CREATE INDEX idx_script_paragraphs_document ON script_paragraphs(document_id, sort_order);
CREATE INDEX idx_script_paragraphs_node     ON script_paragraphs(node_id) WHERE node_id IS NOT NULL;
CREATE INDEX idx_script_paragraphs_deleted  ON script_paragraphs(deleted_at) WHERE deleted_at IS NOT NULL;
```
文件头注释照 schema_v7 的格式写：动机、生命周期（schema_version = 9 时单事务执行，UPSERT 到 10）、为什么一画布一份、为什么 candidates 用 JSONB 数组（形状 `[{name, state: candidate|ignored, character_id?}]`，与 nodes.type_config 同一套容错解析）、131072 与 jobs.full_prompt 上限同值。UNIQUE 自带 canvas_id 索引，不另建。

```dart
abstract final class ScriptDocumentCol { id, canvasId, characterCandidates, createdAt, updatedAt }
abstract final class ScriptParagraphCol { id, documentId, sortOrder, sourceText, nodeId, createdAt, updatedAt, deletedAt }

abstract class ScriptRepository {
  Future<Map<String, Object?>?> findDocumentByCanvas(String canvasId);
  /// 没有就建；并发两次也只有一份（INSERT … ON CONFLICT (canvas_id) DO NOTHING 后再 SELECT）。
  Future<String> ensureDocument(String canvasId);
  Future<int> updateDocument(String id, Map<String, Object?> patch); // 走 buildUpdate，touch updated_at
  Future<List<Map<String, Object?>>> listParagraphs(String documentId, {bool includeDeleted = false}); // sort_order, id ASC
  /// 本文档已有段（含软删）的 max(sort_order) + 1；一段都没有 ⇒ 0。
  Future<int> nextParagraphSortOrder(String documentId);
  Future<String> createParagraph({required String documentId, required int sortOrder, required String sourceText, String? nodeId});
  Future<int> updateParagraph(String id, Map<String, Object?> patch);
  Future<int> softDeleteParagraph(String id);
  Future<int> restoreParagraph(String id);
}
final scriptRepositoryProvider = FutureProvider<ScriptRepository>(…, name: 'scriptRepositoryProvider');

@immutable class ScriptParagraph { id, documentId, sortOrder, sourceText, nodeId?, deletedAt?; factory fromRow(DbRow) }
@immutable class ScriptCharacterCandidate { name, state (ScriptCandidateState.candidate|ignored), characterId? ; fromJson / toJson }
@immutable class ScriptDocument { id, canvasId, List<ScriptCharacterCandidate> characterCandidates; factory fromRow(DbRow) } // 坏形状 ⇒ 空表，不抛
```
remapper：第 10 步 documents——`canvas_id` 经 canvasMap（NOT NULL，悬空丢整行）；同一新 canvas 已有一份时后来的整行丢弃 + droppedRows（防第三方手工包撞 UNIQUE 整包回滚）；`character_candidates` 非 List ⇒ `[]`，条目里的 `character_id` 经 characterMap，映射不到的删掉这个键（保留 name）+ nulledRefs。第 11 步 paragraphs——`document_id` 只认上一步保留下来的文档（同 batch_results 认 keptJobIds 的写法），`node_id` 走 optRef(nodeMap)。documentMap / paragraphMap 都只给会保留的行发新 id（#192 P2-2 的 kept 语义）。writer：batch_results 之后、cover 补丁之前，先 documents 再 paragraphs。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 迁移在有数据的 v9 库上执行后，旧表数据零丢失，两张新表存在且为空；schema_version = 10。
2. 删画布（硬删）⇒ 该画布的 document 和全部 paragraph 级联删除；软删画布不动它们。
3. 硬删节点 ⇒ 指向它的 paragraph.node_id 变 NULL，段落行本身还在；软删节点不动 node_id。
4. 同一画布第二次 INSERT document ⇒ 违反 uq_script_documents_canvas；`ensureDocument` 连调两次返回同一个 id，库里只有一行（并发两个事务各调一次也只有一行）。
5. `character_candidates` 写入非数组（如 `{}`）⇒ CHECK 拒绝；source_text 超 131072 ⇒ CHECK 拒绝（仓储翻成 InkError，不漏 PgException）。
6. `nextParagraphSortOrder`：空文档 0；有 sort_order 0、5（含一条软删的 5）⇒ 6。
7. `listParagraphs` 默认不含软删；`includeDeleted: true` 含；顺序 (sort_order, id)。
8. UoW：`scope.scripts` 与其它仓储同一会话；闭包里写了 document + paragraph 后抛错 ⇒ 两表零残留。
9. 导出：data.json 带两张表（含软删段落、含软删画布下的文档），与其它 9 张表同一快照。
10. 导入：新 document 的 canvas_id = 新画布 id；paragraph 的 document_id / node_id 换成新 id；node_id 悬空 ⇒ NULL + nulledRefs；文档悬空 ⇒ 段落整行丢 + droppedRows。
11. 老项目包（v8/v9 导出，没有这两个键）照常导入，两张表为空，不报错。
12. 包里同一画布两份文档 ⇒ 只留第一份及其段落，其余计入 droppedRows，导入不回滚。
13. candidates 里的 character_id 换成新角色 id；映射不到 ⇒ 去掉该键、name 保留。
14. 导入往返：导出再导入后，段落的 node_id 指向的新节点与原节点是同一镜（label / shot_notes 相同）。
15. 撤销栈：本片不进栈（纯存储层）。mac / Windows 无差异（纯 SQL）。

## 新文案键（key · en · zh 表；没有写无）
无

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/quality/import_schema_sync_test.dart`：`_whitelistOf` 加两行 ⇒ 未改 remapper 前 A 组「白名单 Set 清单…（自证）」先红；B 组自动抓到 `character_candidates` ⇒ writer 未登记前红。
- `test/quality/migration_registry_test.dart`：expected 表加 `10: kSchemaV10`。
- `test/core/db/columns_schema_test.dart`（pg）：`script_documents`、`script_paragraphs` 两表双向列比对。
- `test/storage/schema/populated_migration_test.dart`（pg）：`10: _seedV10` 种一份文档 + 两段（一段 node_id 指 v1 种子节点）；全表非空守卫过。
- `test/storage/schema/cascade_test.dart`（pg）：「删 canvas → script_documents / script_paragraphs CASCADE」「硬删 node → script_paragraphs.node_id SET NULL」（规则 2、3）。
- `test/storage/schema/violation_matrix_test.dart`（pg）：UNIQUE(canvas_id)、candidates 非数组、source_text 超长三条拒绝（规则 4、5）。
- `test/storage/repositories/postgres_script_repository_test.dart`（新，pg）：ensureDocument 幂等；nextParagraphSortOrder 空 / 含软删；listParagraphs 默认滤软删且有序；update 后 updated_at 变（规则 4、6、7）。
- `test/storage/transaction_integration_test.dart`（pg）：「scripts 写入后闭包抛错 ⇒ 两表零残留」（规则 8）。
- `test/core/di/repository_scope_wiring_test.dart`：scripts 绑在传入会话；自证 getter 表含 scripts。`repositories_binding_test.dart`：`scriptRepositoryProvider` 是 `FutureProvider<ScriptRepository>`。
- `test/services/import/import_remapper_test.dart`：「剧本：文档 canvas_id / 段落 document_id、node_id 全换新」「node_id 悬空 ⇒ NULL + 计数」「文档悬空 ⇒ 段落连带丢弃」「同画布两份文档只留第一份」「candidates 的 character_id 改写 / 映射不到删键」「老包没有剧本键 ⇒ 两表空」（规则 10–13）。
- `test/services/project_roundtrip_integration_test.dart`（pg）：满配项目里种剧本（含软删段、node_id 指软删节点）；往返后逐列对齐、node_id 落在同一镜（规则 9、14）。
- `test/storage/repositories/project_archive_reader_integration_test.dart` / `project_import_writer_integration_test.dart`（pg）：快照含两表含软删；writer 写入 candidates 数组不报错。
- `test/features/storyboard/models/script_document_test.dart`（新）：fromRow 正常 / candidates 坏形状回落空表 / 未知 state 丢弃该条。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. DDL 里 `ON DELETE CASCADE`（canvas_id）删掉 ⇒ cascade_test 红。
2. `node_id … ON DELETE SET NULL` 改成无动作 ⇒ cascade_test 红（硬删节点被 FK 拒）。
3. 删掉 `uq_script_documents_canvas` ⇒ violation_matrix + ensureDocument 幂等用例红。
4. `_jsonbCols` 去掉 characterCandidates ⇒ import_schema_sync B 组红 + writer 集成测红。
5. `_scriptParagraphCols` 漏 `ScriptParagraphCol.deletedAt` ⇒ import_schema_sync A 组红。
6. remapper 段落 `node_id` 改成原样拷贝旧 id ⇒ remapper「全换新」用例红。
7. remapper 去掉「同画布第二份丢弃」⇒ 对应用例红。
8. `postgresRepositoryScope` 里 `scripts: PostgresScriptRepository(pool)`（接成别的会话）⇒ wiring 测红。
9. archive reader 漏读 script_paragraphs ⇒ 往返测红。
10. nextParagraphSortOrder 改成只看未软删行 ⇒ 仓储测红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/quality test/services/import test/core/di test/features/storyboard/models`；带 `TEST_PG_URL` 跑 `test/storage test/core/db test/services/project_roundtrip_integration_test.dart`。
- 主 Agent 单独审 `kSchemaV10` 全文（约束名、ON DELETE、CHECK、索引）。无 UI，不截图。

## 风险与不确定
- 迁移号依赖 W4 export-records-table 已占 v9；若 W4 没合，本片改成 v9 并在回报里说明——不得两片都用同一个号。
- W4 是否也给 RepositoryScope 加了 getter、是否进项目包（_whitelistOf / _notTables）以落地为准；本片在其后追加，不改它的行。
- `ProjectArchiveSnapshot` 是 record，加字段会让两个测试 fake 编译失败——已列进允许改的文件。
- 一画布一份（UNIQUE）是本片替设计拍的；以后要多份剧本可再加迁移去掉约束（前向可行）。
- docs/CLAUDE.md 的 storyboard/models 与 storage 小节要补一行，回报给主 Agent。
