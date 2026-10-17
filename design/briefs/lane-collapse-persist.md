# lane-collapse-persist · 泳道折叠落库（style_lanes.collapsed，随项目包走）
决定：Selection-Q6 按建议 C（style_lanes 加 collapsed 列，随项目包走，新增一条前向迁移，编号 v12）

- 波次：W19；lane：B；基底：origin/main（W0–W18 已全部合入后的 main）
- 依赖切片：无硬依赖。软相关（执行时都已在 main）：lane-ops-core（W2）、undo-lanes（W6）、cm-lane-menu（W7，标题栏右键「折叠」也调 `laneCollapseProvider.toggle`）、wrap-in-lane（W8）、multi-select-core（W0，`marqueeHits` 的 collapsedLaneIds 来自 `laneCollapseProvider`）。迁移号前序 v9（export-records-table W4）、v10（script-tables W10）、v11（character-kind W14）都已在 main。
- 阻塞决定：Selection-Q6 → 按建议 C 执行（plan.md 第 5 节；第 4 节定编号 v12）。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
- 泳道折叠（双击标题栏 / 标题栏右键「折叠」）现在会记住：关掉画布、重启应用、导出项目包再导入，折叠的道仍是折叠的。
- 除此之外外观与交互不变：36px 轨、双击标题栏开合、折叠道里的卡不参与框选命中，都照旧。

## 设计依据
- Selection 板 · 「包成泳道」小节规则：「折叠已实现（36px 轨、双击标题栏），记不记住见 Q6」。
- Selection 板 · 需要你定 Q6：「A 不记（现状，重开全展开）· B 记在本机偏好 · C 落库 style_lanes 新列，随项目包走。建议 C，折叠是排版的一部分；新增一条前向迁移」。
- UndoClipboard 板 · 「什么进栈」表的「不进栈」列：**泳道折叠**不进撤销栈。
- ContextMenus 板 · 标题栏右键：「折叠 · 双击标题」——菜单项与双击走同一个开合动作。
- 设计缺口：板上没画「折叠写库失败」的状态。本片定为：乐观先折、写库失败回滚到原状态 + 记 warn 日志，不出卡（折叠是排版偏好，失败时回弹本身就是反馈）。

## 允许改的文件
- `lib/storage/schema/schema_v12.dart`（新建）：`const String kSchemaV12`，文件头注释照 schema_v8.dart 的格式写版本、生命周期、为什么加列。
- `lib/storage/migrations/app_migrations.dart`：import `schema_v12.dart`，`kAppMigrations` 末尾追加 `Migration(version: 12, sql: kSchemaV12)` 一行。
- `lib/core/db/columns.dart`：`StyleLaneCol` 里在 `size` 后加 `static const collapsed = 'collapsed';`（只动这一个类）。
- `lib/features/canvas/models/style_lane.dart`：加 `collapsed` 字段（见下）。
- `lib/features/canvas/providers/canvas_lanes_controller.dart`：新增 `setCollapsed` / `toggleCollapsed`；`build`、`createLane`、`reorderLanes` 不改语义（`copyWith` 自然保留 collapsed）。
- `lib/features/canvas/providers/lane_collapse_controller.dart`：改成从 `canvasLanesControllerProvider` 派生，toggle 落库。
- `lib/services/import/import_remapper.dart`：`_laneCols`（第 31 行）加 `StyleLaneCol.collapsed`。
- `test/features/canvas/lane_collapse_controller_test.dart`：重写为带 fake 仓储的用例。
- `test/features/canvas/models/style_lane_test.dart`：加 collapsed 的 fromRow / == / copyWith 用例。
- `test/features/canvas/canvas_lanes_controller_test.dart`：加 collapsed 用例（文件内已有 `_FakeLaneRepo` / `_ThrowingOnUpdateRepo`）。
- `test/quality/migration_registry_test.dart`：import `schema_v12.dart`，`expected` 映射加 `12: kSchemaV12`。
- `test/core/db/columns_schema_test.dart`（@Tags pg）：`'style_lanes'` 那一行的期望列加 `StyleLaneCol.collapsed`——这个测试是双向的（真列必须都有常量），不加会红。
- `test/storage/schema/populated_migration_test.dart`（@Tags pg）：升到 v12 后种子泳道 `collapsed = false`（规则 1）。
- `test/services/import/import_remapper_test.dart`：加 lanes 行带 / 不带 collapsed 的用例。
- `test/services/project_roundtrip_integration_test.dart`（@Tags pg）：种子泳道改成 collapsed=true，断言导入后仍为 true。
- `test/features/canvas/widgets/lane_interactions_test.dart`：**仅当**现有两条 toggle 用例（约第 320–355 行）因写库改成异步而需要多一次 `pump()` 时才改，只许加 pump，不改断言。

## 不许碰的文件
- 同波 tool-lock：`lib/features/canvas/providers/canvas_tool_mode.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/canvas_shortcuts.dart`（及 shortcuts/ 下键文件）、`lib/features/canvas/widgets/canvas_view.dart` 与 stage_pointer_layer（W19 归 tool-lock）、`lib/features/canvas/util/canvas_tool_actions.dart`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/settings/util/pointer_gesture_catalog.dart`、`lib/features/settings/widgets/shortcuts_section.dart`、`test/features/canvas/widgets/canvas_tool_lock_test.dart`。
- 同波 my-templates-table：`lib/storage/schema/schema_v13.dart`、`lib/core/interfaces/canvas_template_repository.dart`、`lib/storage/repositories/postgres_canvas_template_repository.dart`、`lib/core/di/repositories.dart`、`lib/features/templates/providers/my_templates_controller.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`test/quality/import_schema_sync_test.dart`（本片**不需要**改它，A 组会自动核对新列；它归 my-templates-table 加 `_notTables` 豁免）。
- `app_migrations.dart`、`columns.dart`、`migration_registry_test.dart`、`columns_schema_test.dart`、`populated_migration_test.dart` 两片都要改：本片先合，my-templates-table 叠在本片之后各追加自己那一行（见风险）。
- stage_lane_layer / lane_title_bar / canvas_menu 下的泳道菜单条目：调用方保持 `laneCollapseProvider(canvasId).notifier.toggle(laneId)` 不变，本片不碰。
- `lib/storage/repositories/postgres_style_lane_repository.dart` 与 `StyleLaneRepository` 接口：读是 `SELECT l.*`、写是通用 `update(id, patch)`（base_repository.dart 第 70 行 `buildUpdate`），无需改；`create` 不加参数（新道一律默认展开，由列 DEFAULT 给值），免得改 9 个测试里的 fake。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W19 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - tool-lock：`lib/features/canvas/providers/canvas_tool_mode.dart`、`lib/features/canvas/util/canvas_tool_lock_actions.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/shortcuts/tool_lock_keys.dart`、`lib/features/canvas/widgets/stage/stage_pointer_layer.dart`、`lib/features/canvas/widgets/tool_lock_ghost.dart`、`lib/features/settings/util/pointer_gesture_catalog.dart`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/settings/widgets/shortcuts_section.dart`、`test/features/canvas/providers/canvas_tool_mode_test.dart`、`test/features/canvas/widgets/canvas_tool_lock_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/settings/pointer_gesture_catalog_test.dart`、`test/features/settings/shortcuts_section_test.dart`
  - my-templates-table：`lib/core/di/repositories.dart`、`lib/core/interfaces/canvas_template_repository.dart`、`lib/features/canvas/widgets/left_rail/template_card.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`lib/features/templates/providers/my_templates_controller.dart`、`lib/features/templates/util/my_template_actions.dart`、`lib/storage/repositories/postgres_canvas_template_repository.dart`、`lib/storage/schema/schema_v13.dart`、`lib/theme/components/ink_name_dialog.dart`、`test/_harness/fake_canvas_template_repository.dart`、`test/features/canvas/widgets/left_rail/templates_panel_test.dart`、`test/features/templates/providers/my_templates_controller_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/storage/repositories/postgres_canvas_template_repository_integration_test.dart`（与本片串行共用的文件不列）

## 具体改动
迁移（v12，发出去不能改，合入前主 Agent 单审）：
```sql
ALTER TABLE style_lanes
  ADD COLUMN collapsed BOOLEAN NOT NULL DEFAULT false;
```
模型：
```dart
// style_lane.dart
const StyleLane({..., this.collapsed = false});
final bool collapsed;
StyleLane copyWith({..., bool? collapsed});
// == / hashCode 纳入 collapsed
// fromRow: collapsed: row.optBool(StyleLaneCol.collapsed) ?? false   // row_reader.dart 第 77 行已有 optBool
```
控制器：
```dart
// canvas_lanes_controller.dart —— 走 serialize，乐观更新 + InkError 回滚并 rethrow（与 updateLane 同策略）
Future<void> setCollapsed(String id, bool collapsed);
/// 取反在 serialize 的 op 内读 previous 再算，连按两次不会读到同一份旧快照。
Future<void> toggleCollapsed(String id);
// 两者都只写 {StyleLaneCol.collapsed: v}，不经 updateLane、不推撤销栈命令；目标道不在 previous 里 ⇒ 直接 return，不写库。
```
```dart
// lane_collapse_controller.dart —— provider 名与类型不变：
final laneCollapseProvider = AutoDisposeNotifierProviderFamily<LaneCollapseController, Set<String>, String>(...);
class LaneCollapseController extends AutoDisposeFamilyNotifier<Set<String>, String> {
  Set<String> build(String canvasId);        // ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull 里 collapsed 的 id；未加载 ⇒ const {}
  void toggle(String laneId);                // 签名不变（仍是 void）：内部 unawaited 调 lanes 控制器 toggleCollapsed；on InkError 记 loggerProvider.warn('canvas.lanes', ...)
  bool isCollapsed(String laneId);           // 不变
  void expand(String laneId);                // cm-lane-menu（W7）加的，签名不变：已折叠 ⇒ unawaited setCollapsed(laneId, false)，已展开 ⇒ 什么都不做
  @override bool updateShouldNotify(Set<String> previous, Set<String> next); // setEquals 判等：改名 / 改风格不让折叠集重算出「新」集合而重建舞台
}
```
导入链：`_laneCols` 加 `StyleLaneCol.collapsed`。导出端 `postgres_project_archive_reader.dart` 第 60 行是 `SELECT l.*`，自动带出；写入端 `postgres_project_import_writer.dart` 按行插入，不需改（BOOLEAN 不进 `_jsonbCols`）。

## 行为规则与边界情况
1. 存量库升级到 v12 后，所有泳道 collapsed=false，打开画布与升级前一致（全部展开）。
2. 双击标题栏折叠 → 立即折叠（乐观），库里该行 collapsed=true；关掉画布再开，仍折叠。
3. 再次双击 → 展开并写 false。连续快速双击两次（两次 toggle 在第一次写库返回前发生）最终状态 = 展开，库里依次收到 true、false 两次写（serialize 内取反）。
4. 写库抛 InkError → 折叠集回滚到点之前，记一条 warn 日志，不出通知卡；不抛到 UI。
5. toggle 一个不存在 / 已删的 laneId → 不写库、状态不变。
6. 泳道列表尚未加载（AsyncLoading）时 `laneCollapseProvider` 为空集；加载完成后带出库里的折叠态。
7. 折叠不进撤销栈：toggle 后 Ctrl Z 撤的是上一步别的操作，折叠态不变。
8. 新建泳道（F、Ctrl G 包成泳道、模板插入、剧本导入建道）一律展开（列 DEFAULT false）。
9. 软删泳道再恢复（撤销「解散 / 删除泳道和内容」）保留软删前的 collapsed 值（restore 只清 deleted_at）。
10. 导出项目包 → 导入：折叠态原样带过去。v12 之前导出的旧包没有 collapsed 列 → 导入后 false。
11. 两个画布 family 互不影响；同一画布在两处订阅（舞台、左栏 `focusNodeOnCanvas`、`canvas_tool_actions` 的三处 `ref.read(laneCollapseProvider(...))`）读到同一份。
12. 折叠集合内容不变时（改名、改风格、改厚），`laneCollapseProvider` 不通知订阅者。
13. mac / Windows 无差异。

## 新文案键
无。

## 测试
- `test/features/canvas/lane_collapse_controller_test.dart`（重写；`styleLaneRepositoryProvider.overrideWith` 注入内存 fake，可复用 `test/_harness/fake_repositories.dart` 的 `InMemoryStyleLaneRepository`）：
  - `build 从泳道行派生折叠集`：两行，一行 collapsed=true → 状态 == {该 id}。
  - `toggle 落库 true 并更新状态`：toggle 后 fake 行 `collapsed == true`，状态含该 id。
  - `连按两次 toggle 最终展开，库里依次写 true / false`。
  - `写库失败回滚`：update 抛 `LocalIOError` → 状态回到空集，不抛出。
  - `未知 laneId 不写库`。
  - `不同 family 互不干扰`。
  - `改名不触发折叠集通知`：listen 计数，updateLane(label) 后计数不变。
- `test/features/canvas/canvas_lanes_controller_test.dart`：
  - `setCollapsed 乐观写 + 落库 patch 只有 collapsed`。
  - `toggleCollapsed 在 serialize 内取反`：不 await 连调两次 → 最终 false。
  - `setCollapsed 失败回滚并 rethrow`（用 `_ThrowingOnUpdateRepo`）。
  - `reorderLanes 保留 collapsed`。
- `test/features/canvas/models/style_lane_test.dart`：`fromRow 缺列 ⇒ false`、`fromRow true`、`== 区分 collapsed`、`copyWith 不传 collapsed 保留原值`。
- `test/quality/migration_registry_test.dart`：映射加 12，原有「连续无缺口」「引用常量」用例覆盖新迁移。
- `test/quality/import_schema_sync_test.dart`（不改，跑）：A 组 `_laneCols 覆盖 StyleLaneCol 的全部列`、C 组「NOT NULL 无 DEFAULT」两条都要绿。
- `test/services/import/import_remapper_test.dart`：`lanes 行 collapsed=true 原样保留`、`旧包 lanes 行无 collapsed 列 ⇒ 输出行不含该键（由列默认补）`。
- `test/services/project_roundtrip_integration_test.dart`（pg）：种子道 `collapsed=true` → 导入后读出仍 true。

## 变异点
1. 迁移 DDL 去掉 `DEFAULT false` → import_schema_sync_test C 组 `v2 起不出现：加 NOT NULL 无默认的列…` 变红。
2. `_laneCols` 删掉 `StyleLaneCol.collapsed` → import_schema_sync_test A 组 `_laneCols 覆盖 StyleLaneCol 的全部列` 变红；import_remapper_test `lanes 行 collapsed=true 原样保留` 变红。
3. `StyleLane.fromRow` 把 collapsed 写死成 false → lane_collapse_controller_test `build 从泳道行派生折叠集` 变红。
4. `LaneCollapseController.toggle` 改回只改内存不调 lanes 控制器 → `toggle 落库 true 并更新状态` 变红。
5. `toggleCollapsed` 把取反挪到 serialize 外（入口读 state） → canvas_lanes_controller_test `toggleCollapsed 在 serialize 内取反` 变红。
6. `setCollapsed` 的 `on InkError` 回滚删掉 → `setCollapsed 失败回滚并 rethrow` / `写库失败回滚` 变红。
7. 删掉 `updateShouldNotify` 覆写 → `改名不触发折叠集通知` 变红。
8. app_migrations 漏注册 v12 → migration_registry_test `每条迁移引用对应 kSchemaVN 常量` 变红。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/quality test/services/import test/storage --exclude-tags golden`，有 TEST_PG_URL 时加跑 pg 标签的 `test/services/project_roundtrip_integration_test.dart` 与 `test/storage/schema/`。
- 逐条做上面的变异。
- 迁移 DDL 单独审一遍（ADR-0012：发出去不可改）。
- 截图（可选，非 UI 改动）：`lane_interactions_test` 的测试 app，两条道、`lane-1` collapsed=true 的 fake 行，截首帧即为折叠态。

## 风险与不确定
- **迁移号**：本片 v12，my-templates-table v13 叠在本片之后。两片都改 `app_migrations.dart`（各追加一行）、`columns.dart`（本片只动 `StyleLaneCol`，它新增 `CanvasTemplateCol` 类）、`migration_registry_test.dart`（映射各加一项）。若合入顺序颠倒，编号要对调，迁移文件名与常量名一起改。
- `canvas_lanes_controller` 热点链 W19 归本片；W6 undo-lanes / W8 wrap-in-lane 之后 `updateLane` 很可能已带撤销命令，所以本片**不**扩展 `updateLane`，另开 `setCollapsed` 绕开撤销栈（slices.json 原写「updateLane 收 collapsed」，此处有意偏离）。
- cm-lane-menu（W7）按它的派工单给 `LaneCollapseController` 加了 `void expand(String laneId)`（幂等，「选中泳道内容」先展开再选）：保留签名，改为 `setCollapsed(laneId, false)` 落库（已展开就不写库）；`cm-lane-menu` 的 `lane_collapse_controller_test` 用例 `expand 幂等…` 改成带 fake 仓储后继续过。
- 折叠写库是每次双击一次 UPDATE，并顺带刷新 `style_lanes.updated_at`；不影响其他逻辑，但「最近修改」类排序若读泳道 updated_at 会被折叠扰动（目前没有这种读法）。
- 模板（template-core 的 `template_capture`）是否要带折叠态：本片不改，模板插入的道一律展开。
