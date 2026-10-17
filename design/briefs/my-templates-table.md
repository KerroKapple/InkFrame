# my-templates-table · 「我的模板」：新表 canvas_templates（应用级）+ 存为模板… + 右键改名 / 软删带撤销 + 空态
决定：RailScript-R5 按建议 A
- 波次：W19；lane：C；基底：叠在 lane-collapse-persist 之后（同波另一片，迁移 v12；本片迁移 v13，两片共用的迁移与 schema 护栏文件必须串行，见风险 1）
- 依赖切片：
  - 硬依赖 template-core（W16）：`CanvasTemplatePayload` / `TemplateCounts` / `CanvasTemplate`、`captureTemplate`、`countTemplate`、`CanvasTemplatePayload.fromJson`（format 不认识返回 null）——已在 main。
  - 硬依赖 rail-templates-page（W17）：`templates_panel.dart`、`TemplateCard`、`insertTemplateWithFeedback`、`createCanvasFromTemplateAndOpen`——已在 main。
  - 已在 main：node-library-section / node-library-drag-recents（W18，模板页顶部的节点库，本片不动它）、menu-split（W0，`CanvasMenuPopover` / `CanvasMenuPanel`）、mention-token-core（W11）。
  - 硬依赖 lane-collapse-persist（W19，同波先合）：v12 迁移已占号。
- 阻塞决定：RailScript-R5 → 按建议 A 执行：应用级表，**不带 project_id、不进项目包**（不改导出白名单、不改 import_remapper）；分享需求以后再加 .json 导出。迁移编号按 plan.md 第 4 节定为 **v13**。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
模板页面板头右侧出现「存为模板…」：起个名字，就把当前画布（有选中时只存选中的）存成一张「我的」模板，跨项目都能用。
模板卡上方出现「内置 3 | 我的 N」分段；「我的」里的卡和内置卡一样能悬停插入 / 新建画布，右键可改名、删除（删除出一张带「撤销」的通知）；一张都没有时给一个「把当前画布存为模板」按钮。

## 设计依据
画板 `RailScript.dc.html`「模板」（b2_rail.js 第 145–200 行）：
- 面板头「模板」，右侧「存为模板…」：11 号 fg4，悬停变亮（hovfg）。
- 分段：外边距 10 12 8、26 高、圆角 4、surface2 底、1px outline 边、内边距 2、两段等宽间距 2；选中段 surface5 底 + fg1，未选中 fg4；文字 11 号「内置 3」「我的 1」。
- 规则：我的 = 需新表 `canvas_templates`（name, payload JSONB, 计数），新增一条前向迁移；存为模板：整张画布或选中的；存节点、叙事 / 数据边、泳道与风格词；不存产物、媒体、角色；「我的」右键：改名 / 删除（软删 + 撤销）；为空时给「把当前画布存为模板」。
- 需要你定 R5：A 应用级、跨项目可用（建议）。
`UndoClipboard.dc.html`「不进栈」：「角色库 / 画廊 / 导出」「项目与画布增删」不进画布撤销栈——模板库同属库级操作，删除的撤销走通知卡（`ToastKind.undo`，停 8 秒）。
设计缺口：①存为模板时对话框是否说明存的是「整张画布」还是「选中的 N 个」——本单定标题区分两种；②画布上没有配置节点时点「存为模板…」——本单定不弹框，出 info 通知「画布上没有可存的节点」；③重名——允许，不去重；④「我的」排序——按 updated_at 倒序（改名会把它顶到最前）；⑤右键菜单没有键盘入口——本单不补（与画板一致），记入缺口清单；⑥删掉的模板没有回收站、没有定期清理（软删行永久留在库里，量很小）。

## 允许改的文件
- `lib/storage/schema/schema_v13.dart`（新建）：建表 DDL。
- `lib/storage/migrations/app_migrations.dart`：import + 追加 `Migration(version: 13, sql: kSchemaV13)` 一行（v12 那行由 lane-collapse-persist 已加）。
- `lib/core/db/columns.dart`：新增 `abstract final class CanvasTemplateCol`。
- `lib/core/interfaces/canvas_template_repository.dart`（新建）。
- `lib/storage/repositories/postgres_canvas_template_repository.dart`（新建）。
- `lib/core/di/repositories.dart`：新增 `canvasTemplateRepositoryProvider`（写法照第 81 行 `promptPresetRepositoryProvider`）。
- `lib/features/templates/providers/my_templates_controller.dart`（新建）。
- `lib/features/templates/util/my_template_actions.dart`（新建）：存为模板 / 改名 / 删除三个带 context 的动作。
- `lib/features/canvas/widgets/left_rail/templates_panel.dart`（rail-templates-page 建，W17；W18 节点库已在其顶部）：面板头右侧动作、分段、「我的」列表、右键菜单、空态。
- `lib/features/canvas/widgets/left_rail/template_card.dart`（rail-templates-page 建）：加可选 `onSecondaryTapUp` 回调（右键）。
- `lib/theme/components/ink_name_dialog.dart`：仅当没有初始值参数时加可选 `initialValue`（默认 ''，构造时写进 `_ctrl.text` 并全选）。
- 测试：`test/quality/import_schema_sync_test.dart`、`test/quality/migration_registry_test.dart`、`test/core/db/columns_schema_test.dart`、`test/storage/schema/populated_migration_test.dart`（四个都在 lane-collapse-persist 之后再改）；`test/storage/repositories/postgres_canvas_template_repository_integration_test.dart`（新建，`@Tags(['pg'])`）；`test/_harness/fake_canvas_template_repository.dart`（新建）；`test/features/templates/providers/my_templates_controller_test.dart`（新建）；`test/features/canvas/widgets/left_rail/templates_panel_test.dart`（加用例）。

## 不许碰的文件
- 同波：`providers/canvas_tool_mode.dart`、`widgets/canvas_toolbar.dart`、`widgets/canvas_shortcuts.dart` 与 `shortcuts/**`、`widgets/canvas_view.dart` / `stage_pointer_layer.dart`、`util/canvas_tool_actions.dart`、`settings/util/shortcut_catalog.dart`（tool-lock）；`features/canvas/models/style_lane.dart`、`storage/repositories/postgres_style_lane_repository.dart`、`providers/lane_collapse_controller.dart`、`providers/canvas_lanes_controller.dart`、`services/import/import_remapper.dart`（lane-collapse-persist）。
- R5 A ⇒ 不碰：`lib/services/project_archive_service.dart`、`lib/storage/repositories/postgres_project_archive_reader.dart`、`postgres_project_import_writer.dart`、`import_remapper.dart`、`core/models/import_plan_data.dart`、`unit_of_work.dart` / `postgres_unit_of_work.dart`（模板读写都是单行操作，不进 `RepositoryScope`，省得改 FakeRepositoryScope）。
- `lib/features/templates/` 下 template-core 建的文件（只调用）；`node_library_section.dart`。
- 已发出的 `schema_v1`…`schema_v12.dart`（ADR-0012，不可改）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W19 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - tool-lock：`lib/features/canvas/providers/canvas_tool_mode.dart`、`lib/features/canvas/util/canvas_tool_lock_actions.dart`、`lib/features/canvas/util/escape_ladder.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/shortcuts/tool_lock_keys.dart`、`lib/features/canvas/widgets/stage_pointer_layer.dart`、`lib/features/canvas/widgets/tool_lock_ghost.dart`、`lib/features/settings/util/pointer_gesture_catalog.dart`、`lib/features/settings/util/shortcut_catalog.dart`、`test/features/canvas/providers/canvas_tool_mode_test.dart`、`test/features/canvas/widgets/canvas_tool_lock_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/settings/pointer_gesture_catalog_test.dart`
  - lane-collapse-persist：`lib/features/canvas/models/style_lane.dart`、`lib/features/canvas/providers/canvas_lanes_controller.dart`、`lib/features/canvas/providers/lane_collapse_controller.dart`、`lib/services/import/import_remapper.dart`、`lib/storage/schema/schema_v12.dart`、`test/features/canvas/canvas_lanes_controller_test.dart`、`test/features/canvas/lane_collapse_controller_test.dart`、`test/features/canvas/models/style_lane_test.dart`、`test/features/canvas/widgets/lane_interactions_test.dart`、`test/services/import/import_remapper_test.dart`、`test/services/project_roundtrip_integration_test.dart`

## 具体改动
```sql
-- schema_v13.dart：const String kSchemaV13 = r''' … ''';  头注照 schema_v7.dart：真相源、生命周期、为什么应用级（R5 A）
CREATE TABLE canvas_templates (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT    NOT NULL DEFAULT '',
  payload     JSONB   NOT NULL DEFAULT '{}'::jsonb,
  node_count  INTEGER NOT NULL DEFAULT 0,
  shot_count  INTEGER NOT NULL DEFAULT 0,
  lane_count  INTEGER NOT NULL DEFAULT 0,
  edge_count  INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at  TIMESTAMPTZ,
  CONSTRAINT chk_canvas_templates_name   CHECK (char_length(name) <= 200),
  CONSTRAINT chk_canvas_templates_counts CHECK (node_count >= 0 AND shot_count >= 0 AND lane_count >= 0 AND edge_count >= 0)
);
CREATE INDEX idx_canvas_templates_alive ON canvas_templates(updated_at DESC) WHERE deleted_at IS NULL;
```
```dart
// columns.dart
abstract final class CanvasTemplateCol { static const id='id'; static const name='name'; static const payload='payload';
  static const nodeCount='node_count'; static const shotCount='shot_count'; static const laneCount='lane_count'; static const edgeCount='edge_count';
  static const createdAt='created_at'; static const updatedAt='updated_at'; static const deletedAt='deleted_at'; }

// core/interfaces/canvas_template_repository.dart
abstract class CanvasTemplateRepository {
  Future<String> create({required String name, required Map<String, Object?> payload,
    required int nodeCount, required int shotCount, required int laneCount, required int edgeCount});
  Future<List<Map<String, Object?>>> listAlive();          // deleted_at IS NULL，ORDER BY updated_at DESC, id
  Future<int> update(String id, Map<String, Object?> patch); // 走 buildUpdate（自动 touch updated_at）
  Future<int> softDelete(String id);
  Future<int> restore(String id);
}

// providers/my_templates_controller.dart
final myTemplatesControllerProvider = AsyncNotifierProvider.autoDispose<MyTemplatesController, List<CanvasTemplate>>(...);
class MyTemplatesController extends AutoDisposeAsyncNotifier<List<CanvasTemplate>> {
  Future<String> save({required String name, required CanvasTemplatePayload payload});  // 名字 trim、超 200 截断；counts = countTemplate(payload)
  Future<void> rename(String id, String name);
  Future<void> delete(String id);   // 软删
  Future<void> restore(String id);  // 撤销删除
}

// util/my_template_actions.dart
Future<void> saveCanvasAsTemplate(BuildContext context, WidgetRef ref, {required String canvasId, required String? projectId});
Future<void> renameMyTemplate(BuildContext context, WidgetRef ref, CanvasTemplate t);
Future<void> deleteMyTemplate(BuildContext context, WidgetRef ref, CanvasTemplate t);
```
- 仓储：`with BaseRepository implements CanvasTemplateRepository`，写法照 `postgres_prompt_preset_repository.dart`（`guard('create', 'canvas_templates', …)`；payload 参数 `@payload::jsonb` + `jsonEncode`，照 postgres_node_repository.dart:36/51）。没有项目 JOIN（应用级）。
- 行 → 模型：`CanvasTemplatePayload.fromJson(row[payload])` 为 null 的行跳过并 `logger.warn('templates.my', 'unreadable template payload', extra: {'id': …})`；counts 读四个计数列；`builtin: false`；`tagline: null`。
- `saveCanvasAsTemplate`：同步取齐节点 / 边 / 泳道控制器现值、`laneCollapseProvider` 切片（与 `menuNodePlacement` 同一个 `collapseLaneSlices` 写法）、`canvasLaneDirectionProvider`、`canvasSelectionControllerProvider(canvasId)`、`canvasBaseStyleProvider(canvasId)`、角色名表（`charactersControllerProvider(projectId)`，没有项目 ⇒ 名字都取不到）；选中非空 ⇒ `selection` 传选中集合，否则 null（整张）；先 `captureTemplate`，`nodes.isEmpty` ⇒ info 通知「画布上没有可存的节点」并返回；否则弹 `InkNameDialog`（标题按整张 / 选中区分，初始名 = 当前画布名），确认后 `save`，成功 success 通知「已存为模板「X」」并把分段切到「我的」；`InkError` ⇒ error 通知「存为模板失败」。
- `renameMyTemplate`：`InkNameDialog(initialValue: t.name)`，空串或未改 ⇒ 不写；失败 error 通知。
- `deleteMyTemplate`：`delete` 后出 `ToastKind.undo` 通知「已删除模板「X」」+ 动作「撤销」（`commonUndo`）→ `restore`；失败 error 通知。
- 面板：面板头 `LeftPanelHeader(trailing: 存为模板… 文字按钮)`；W18 节点库之下、模板卡之上加分段（`_TemplateSourceSegments`，样式照 assets_panel.dart:262 的 `_ScopeSegments`）；分段状态本地，默认「内置」；「我的」数据 `myTemplatesControllerProvider`，加载中画空列表、出错画 `LeftPanelNote(l10nAsyncError(…))`；空 ⇒ 一行说明 +「把当前画布存为模板」按钮（与面板头同一个动作）。
- 「我的」卡右键：`TemplateCard.onSecondaryTapUp` → 在指针处开 `CanvasMenuPopover` + `CanvasMenuPanel`，两项「改名」「删除」（删除 `danger: true`）；↑↓ / ↵ / Esc 走面板既有行为。

## 行为规则与边界情况
1. 迁移：schema_version 12 → 13 单事务；老库升级后表为空；`SchemaDowngradeError` 行为不变（v13 库给旧版应用打开被拒）。
2. 应用级：在项目 A 存的模板，切到项目 B 的画布照样出现在「我的」里；删项目 / 删画布不影响模板。
3. 导出项目包不含 canvas_templates；导入项目包不写它（import_schema_sync 护栏显式豁免）。
4. 存为模板：有选中 ⇒ 只存选中的配置节点与它们之间的边、所在泳道；无选中 ⇒ 整张；产物、媒体路径、`character_ids`、`pinned_result_id`、`gen_inputs` 全部不存；提示词里的 `@{角色 id}` 存成「@名字」。
5. 画布只有产物节点或空画布：不弹框，info 通知。
6. 名字：首尾空白去掉；为空 ⇒ 不保存；超过 200 字截断到 200（不触发 CHECK）；重名允许。
7. 保存成功后分段切到「我的」，新卡排第一；分段计数「我的 N」随之 +1。
8. 改名：成功后卡片名更新并排到第一（updated_at 变了）；取消 / 原名 ⇒ 不写库。
9. 删除：卡片立即消失；通知停 8 秒，点「撤销」⇒ 卡片回来（同 id、同内容）；通知过期后无法撤销（库里仍是软删行）。
10. 插入「我的」模板：与内置同一条路（`insertTemplateWithFeedback` / `createCanvasFromTemplateAndOpen`），进画布撤销栈的是「插入」那一步，模板库本身的增删改不进画布栈。
11. 库里某行 payload 坏了（手工改库 / 未来 format 2）：该行不显示，其他行照常，记 warn 日志，不弹错。
12. 读失败（库不可用）：「我的」段显示错误说明，「内置」段不受影响。
13. 并发：连点两次「存为模板…」只会出一个对话框（对话框是模态的）；保存进行中面板头按钮置灰。
14. mac / Windows：右键在 mac 触控板双指点按同样触发 `onSecondaryTapUp`；Ctrl+点击在 mac 上不当右键（Flutter 默认不转换，不额外处理）。

## 新文案键
| key | en | zh |
|---|---|---|
| templatesSaveAs | Save as template… | 存为模板… |
| templatesSourceBuiltin | Built-in {count} | 内置 {count} |
| templatesSourceMine | Mine {count} | 我的 {count} |
| templatesMineEmpty | No templates of your own yet | 还没有自己的模板 |
| templatesSaveCurrentCanvas | Save this canvas as a template | 把当前画布存为模板 |
| templatesSaveDialogTitleCanvas | Save canvas as template | 整张画布存为模板 |
| templatesSaveDialogTitleSelection | {count, plural, =1{Save 1 selected node as template} other{Save {count} selected nodes as template}} | 选中的 {count} 个节点存为模板 |
| templatesNameHint | Template name | 模板名称 |
| templatesSaveConfirm | Save | 保存 |
| templatesNothingToSave | Nothing on this canvas can be saved as a template | 画布上没有可存的节点 |
| templatesSaved | Saved as template “{name}” | 已存为模板「{name}」 |
| templatesSaveFailed | Couldn't save template | 存为模板失败 |
| templatesRename | Rename | 改名 |
| templatesRenameDialogTitle | Rename template | 模板改名 |
| templatesRenameFailed | Couldn't rename template | 模板改名失败 |
| templatesDelete | Delete | 删除 |
| templatesDeleted | Deleted template “{name}” | 已删除模板「{name}」 |
| templatesDeleteFailed | Couldn't delete template | 删除模板失败 |
取消复用 `commonCancel`，撤销复用 `commonUndo`。

## 测试
先写会失败的用例。
- `test/quality/migration_registry_test.dart`：expected 表加 `13: kSchemaV13`（「每条迁移引用对应 kSchemaVN 常量」）。
- `test/quality/import_schema_sync_test.dart`：`_notTables` 加 `'CanvasTemplateCol': 'canvas_templates 是应用级表（RailScript-R5 A），不随项目导出'`；B 组加豁免表 `_appLevelJsonb = {'payload': 'canvas_templates.payload：应用级表，不进项目包'}`，比较前从迁移集合里减掉；新增用例 `应用级 JSONB 豁免只出现在 canvas_templates 的 DDL 里`（扫迁移，`payload JSONB` 只能出现在 `CREATE TABLE canvas_templates` 块内）。
- `test/core/db/columns_schema_test.dart`：expected 加 `'canvas_templates': [CanvasTemplateCol 全部 10 列]`（pg）。
- `test/storage/schema/populated_migration_test.dart`：seeders 加 `13: () => _seedV13(conn)`（插一行模板，含 payload）；完整性断言加 `canvas_templates` 计数 1、payload `->>'format'` 原样存活（pg）。
- `test/storage/repositories/postgres_canvas_template_repository_integration_test.dart`（pg）：`create 后 listAlive 读回 payload 与计数`；`update 改名 touch updated_at 且排序到最前`；`softDelete 后 listAlive 读不到，restore 后回来`；`名字超 200 被 CHECK 拒绝并翻成 InkError`。
- `test/features/templates/providers/my_templates_controller_test.dart`（`test/_harness/fake_canvas_template_repository.dart`）：`save 写入计数 = countTemplate`；`名字 trim 并截断到 200`；`坏 payload 行被跳过`；`delete 后列表少一张、restore 回来`；`rename 后排第一`。
- `test/features/canvas/widgets/left_rail/templates_panel_test.dart`（追加）：`分段默认内置，切到我的显示库里的卡`；`我的为空时显示把当前画布存为模板`；`无选中点存为模板：对话框标题是整张画布，确认后 save 收到整张 payload`；`有选中：标题是选中的 N 个节点，payload 只含选中`；`空画布点存为模板：不弹框、出 info 通知`；`右键我的卡出改名 / 删除，删除后出撤销通知，点撤销卡片回来`。

## 变异点
1. `app_migrations.dart` 删掉 v13 那一行 ⇒ `migration_registry_test` 的「每条 schema_vN 已注册」红。
2. `_notTables` 不登记 `CanvasTemplateCol` ⇒ import_schema_sync「白名单 Set 清单与列类清单都没有漏登（自证）」红。
3. 去掉 `_appLevelJsonb` 豁免 ⇒ import_schema_sync B 组红（证明豁免是必要的）；把豁免键改成别的列名 ⇒ 同样红。
4. `save` 不截断名字 ⇒ `名字 trim 并截断到 200` 红。
5. 行解析不跳过坏 payload（直接 `!`）⇒ `坏 payload 行被跳过` 红。
6. `saveCanvasAsTemplate` 忽略选中、一律整张 ⇒ `有选中：标题是选中的 N 个节点，payload 只含选中` 红。
7. 删除通知的撤销不调 `restore` ⇒ `…点撤销卡片回来` 红。
8. `listAlive` 去掉 `deleted_at IS NULL` ⇒ 仓储集成测 `softDelete 后 listAlive 读不到` 红（pg）。

## 验收
- `flutter analyze lib test`；`flutter test test/quality test/features/templates test/features/canvas/widgets/left_rail`；有 `TEST_PG_URL` 时再跑 `test/storage test/core/db`；逐条变异。
- 主 Agent 单独审 `schema_v13.dart` 的 DDL（ADR-0012：发出后不可改），并核对 `docs/CLAUDE.md` 的 Project Structure 补 `canvas_template_repository` / `postgres_canvas_template_repository` / `my_templates_controller` 三行。
- 截图（screenshot 标签）：`InkShell` 画布标签、左栏模板页、fake 模板仓储两条；截①分段停在「我的」两张卡；②「我的」为空的空态；③右键一张卡弹出改名 / 删除菜单；④存为模板对话框（选中 2 个节点时的标题）。

## 风险与不确定
1. **同波串行例外**：`lib/storage/migrations/app_migrations.dart`、`lib/core/db/columns.dart`、`test/quality/migration_registry_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/core/db/columns_schema_test.dart`、`test/storage/schema/populated_migration_test.dart` 与同波 lane-collapse-persist（v12）共用。两片各追加一行 / 一项，必须 lane-collapse-persist 先合、本片 rebase 后再合；编号固定 v12 → v13，不得对调（迁移号连续性由 migration_registry_test 守）。
2. 迁移一发出去就不能改：`payload` 用 JSONB + 四个计数列，以后 payload 格式升级只靠 `format` 字段和应用层容错，不再动表。
3. 豁免按列名 `payload` 记，正则口径只认列名；以后别的表再加名为 `payload` 的 JSONB 列会被误豁免——新增的「豁免只出现在 canvas_templates DDL 里」用例就是为了抓这个。
4. `InkNameDialog` 若在 W9 outline-rename-menu 等切片里已有初始值参数，直接用，不再改 theme 文件。
5. 「我的」右键菜单没有键盘入口、软删行没有清理，按画板现状接受，记入设计缺口。
