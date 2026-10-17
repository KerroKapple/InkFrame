# character-kind · 角色分 角色 / 物品 / 场景
- 波次：W14 / lane：D / 基底：origin/main（前序波已合入，含 W12 prompt-bar-mention-ui、W4 export-records-table 的 v9 / W10 script-tables 的 v10 迁移）
- 依赖切片：无硬依赖；软接 W12 prompt-bar-mention-ui（`util/mention_candidates.dart`、`widgets/mention_popover.dart`，@ 补全跟着分组）
- 阻塞决定：无（迁移编号 **v11 已定**；GapsPanels C1 按建议 A：类型不进提示词）

## 执行约定
1. 在你自己的工作树里，从 origin/main（前序波已合入）起新分支 `feat/character-kind`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。
5. 注册表每片只追加一行——本片不碰注册表。
6. CanvasNode 新派生属性写成 extension；不给 NodeRepository 加抽象方法。**不给 CharacterRepository 加方法、不改 `create` 签名**（`test/_harness/fake_character.dart` 实现它）：kind 走现有 `update(id, patch)`，新建靠列默认值。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 迁移一发出去不能改（ADR-0012）：`schema_v11.dart` 的 DDL 合入前由主 Agent 单独审。

## 目标
- 角色库（左栏「角色」页）按「角色 → 物品 → 场景」分组，每组一个小组头带数量；空组不画。
- 角色编辑框加「类型」三段（角色 / 物品 / 场景），改完点保存生效。
- 提示词条 @ 补全的候选同样按这三组排；老项目、老项目包里的角色一律落成「角色」。

## 设计依据
- 画板 `b2/project/GapsPanels.dc.html` ›「角色：按类型分组 · 被引用可点」：
  - 面板宽 241；组头 22 高、左右 12、11px fg4 文字 + 10px 等宽数字 fg5；行 36 高、28px 缩略（无图时画占位图标框）。
  - 原文要点：「characters 加列 kind（character / prop / scene，默认 character）：新增一条前向迁移；项目包照带」「按 角色 → 物品 → 场景 分组，空组不画；@ 补全同样分组；编辑框加「类型」三段；类型不进提示词（C1）」。
  - C1：「A 不进，只管分组 · B 注入描述时加英文类型前缀 — 建议 A：先不动模型行为」→ 选 A。
- plan.md 第 0 节：「character-kind 漏了 import_remapper.dart 的 `_characterCols` 白名单（第 49 行）和 import_schema_sync_test」；第 3 节验收：「老项目包没有 kind 列，导入后落默认值」。
- 设计缺口：编辑框「类型」三段的位置与尺寸没画——本片放在「名称」与「描述」之间，高 24、三等分、选中 surface5 底 + fg2 字，其余 fg5。
- 设计缺口：筛选后某组被筛空——按「空组不画」处理；全部筛空时沿用现有行为（列表为空，不出「还没有角色」）。

## 允许改的文件
- `lib/storage/schema/schema_v11.dart`（新建）：`kSchemaV11`。
- `lib/storage/migrations/app_migrations.dart`：import + `Migration(version: 11, sql: kSchemaV11)`。
- `lib/core/db/columns.dart`：`CharacterCol.kind = 'kind'`。
- `lib/features/canvas/models/character.dart`（手写不可变，非 freezed）：加 `enum CharacterKind` + `kind` 字段，copyWith / == / hashCode / fromRow 全补。
- `lib/features/canvas/providers/characters_controller.dart`：新增 `setKind`。
- `lib/features/canvas/widgets/character_library_panel.dart`：列表按类型分组 + 组头。
- `lib/features/canvas/widgets/character_edit_dialog.dart`：「类型」三段 + 保存时写 kind。
- `lib/services/import/import_remapper.dart`（W14 归本片）：`_characterCols` 加 `CharacterCol.kind`；非法 kind 值剔除该键（落默认值）。
- `lib/features/canvas/util/mention_candidates.dart`（W12 prompt-bar-mention-ui 新建）：**偏离归属表**——排序加一层「按类型分组」（组序 角色 → 物品 → 场景，组内已挂载优先）。W14 无人占用。
- `lib/features/canvas/widgets/mention_popover.dart`（W12 新建）：**偏离归属表**——不止一组非空时画组头。W14 无人占用。
- 不改：`core/interfaces/character_repository.dart`、`storage/repositories/postgres_character_repository.dart`（`update` 是通用 patch，`listByProject` 是 `SELECT ch.*`，自动带新列）。
- 测试：`test/quality/migration_registry_test.dart`（expected 加 `11: kSchemaV11`）、`test/storage/schema/populated_migration_test.dart`（追加断言）、`test/core/db/columns_schema_test.dart`（characters 列表加 `CharacterCol.kind`）、`test/quality/import_schema_sync_test.dart`（预期不改即绿；仅当 C 组正则需要正控时才动）、`test/services/import/import_remapper_test.dart`（追加）、`test/storage/repositories/project_import_writer_integration_test.dart`（追加，pg）、`test/features/canvas/providers/characters_controller_test.dart`（追加）、`test/features/canvas/widgets/character_library_panel_test.dart`（追加）、`test/features/canvas/widgets/character_edit_dialog_test.dart`（追加）、`test/features/canvas/util/mention_candidates_test.dart`（W12 prompt-bar-mention-ui 新建，追加）、`test/features/canvas/models/character_test.dart`（新建，若已有同名文件则追加）。

## 不许碰的文件
- W14 其他片：`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`widgets/canvas_toolbar.dart`、`widgets/node_card.dart`、`widgets/stage/stage_edge_layer.dart`、`widgets/text_node_inspector.dart`、`util/outline_model.dart`、`generation/generation_controller.dart`、`util/canvas_note_actions.dart`（note-variant）；`left_rail/left_rail_panel.dart`、`widgets/canvas_inspector_panel.dart`、`widgets/canvas_screen.dart`、`core/models/app_preferences.dart`、`services/file_preferences_service.dart`（panel-resize）；`left_rail/assets_panel.dart`（assets-hover-preview）；`export/**`、`shell/widgets/shell_task_*.dart`（export-in-task-popover → delivery-clips-tab）。
- 同 lane 后序：`providers/character_usage.dart`（W15 character-usage-links）；`canvas_prompt_bar.dart`、`mention_text_controller.dart`、`providers/inspector_submit_controller.dart`。
- 已发出的迁移 `schema_v1.dart`…`schema_v10.dart`（不可改）；`create_node_menu.dart`（barrel）、`canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W14）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- note-variant：`lib/features/app_actions/app_action_catalog.dart`（只换 newNote 占位行）、`lib/features/canvas/models/canvas_node_note.dart`、`lib/features/canvas/providers/link_action_controller.dart`、`lib/features/canvas/util/canvas_note_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/util/outline_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/shortcuts/note_keys.dart`、`lib/features/canvas/widgets/stage/stage_edge_layer.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/features/generation/generation_controller.dart`、`test/features/canvas/link_action_controller_test.dart`、`test/features/canvas/models/canvas_node_note_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/util/outline_model_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/canvas/widgets/note_node_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/features/generation/generation_controller_prompt_test.dart`
- panel-resize：`lib/core/models/app_preferences.dart`、`lib/features/canvas/providers/panel_widths.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/panel_resize_handle.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/canvas/providers/panel_widths_test.dart`、`test/features/canvas/widgets/canvas_inspector_tabs_test.dart`、`test/features/canvas/widgets/inspector_auto_save_row_test.dart`、`test/features/canvas/widgets/inspector_history_panel_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/panel_resize_test.dart`
- assets-hover-preview：`lib/core/interfaces/video_player_service.dart`、`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/services/media_kit_video_player_service.dart`、`test/features/canvas/widgets/left_rail/asset_hover_preview_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/sequence/widgets/sequence_monitor_test.dart`
- export-in-task-popover：`lib/features/export/providers/delivery_controller.dart`、`lib/features/export/providers/export_controller.dart`、`lib/features/export/providers/export_task_registry.dart`、`lib/features/shell/widgets/shell_task_capsule.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`test/features/export/providers/delivery_execute_test.dart`、`test/features/export/providers/export_controller_test.dart`、`test/features/export/providers/export_task_registry_test.dart`、`test/features/shell/shell_task_capsule_test.dart`、`test/features/shell/shell_task_popover_test.dart`
- delivery-clips-tab：`lib/features/export/util/delivery_clip_rows.dart`、`lib/features/export/widgets/delivery_clips_tab.dart`、`lib/features/export/widgets/delivery_panel.dart`、`test/features/export/util/delivery_clip_rows_test.dart`、`test/features/export/widgets/delivery_clips_tab_test.dart`

## 具体改动
```dart
// storage/schema/schema_v11.dart（头注照 schema_v8.dart 的写法：为什么加列、为什么有默认值）
const String kSchemaV11 = r'''
ALTER TABLE characters
  ADD COLUMN kind TEXT NOT NULL DEFAULT 'character';
ALTER TABLE characters
  ADD CONSTRAINT chk_characters_kind CHECK (kind IN ('character', 'prop', 'scene'));
''';

// models/character.dart
enum CharacterKind { character, prop, scene }        // 声明顺序 = 分组顺序
extension CharacterKindWire on CharacterKind { String get wire; }   // 'character' / 'prop' / 'scene'（内部协议字面量，不 i18n）
CharacterKind parseCharacterKind(Object? raw);        // 未知 / null ⇒ CharacterKind.character
// Character 加 `final CharacterKind kind;`（构造默认 character）；fromRow 读 row[CharacterCol.kind]

// providers/characters_controller.dart（与 rename 同形：乐观更新 + InkError 回滚，serialize 串行）
Future<void> setKind(String id, CharacterKind kind);   // repo.update(id, {CharacterCol.kind: kind.wire})

// widgets/character_library_panel.dart
List<({CharacterKind kind, List<Character> items})> groupCharactersByKind(List<Character> shown); // 纯函数，空组剔除（顶层公开，便于单测）

// util/mention_candidates.dart：mentionCandidates 返回顺序 = 先按 kind 分组，组内已挂载在前；MentionCandidate 加 `kind`
```
- 现有签名（照抄）：`Future<void> rename(String id, String name)`（characters_controller.dart 约第 101 行）、`Future<void> setDescription(String id, String description)`（约第 140 行）、`Future<int> update(String id, Map<String, Object?> patch)`（character_repository.dart）、`static Character fromRow(Map<String, Object?> row)`（character.dart 约第 68 行）、`const Set<String> _characterCols = {…}`（import_remapper.dart 约第 49 行）、`Future<void> _save()`（character_edit_dialog.dart 约第 456 行）。
- 编辑框：`_CharacterEditDialogState` 加 `CharacterKind? _kind`（`_seeded` 时回填 `character.kind`）；三段是本文件私有 widget `_KindSegments`（不跨 feature 引 export 的 DeliverySegments）；`_save` 在描述之后追加「kind 变了才写」一步，失败沿用 `_guard`。
- 面板：`ListView` 的 children 改为「组头 + 该组行」串接；组头私有 widget `_KindGroupHeader`（label + 数量）。行 key 不变（`character-row-<id>`），组头 key `character-group-<kind.wire>`。
- import_remapper：第 6 步（约第 261 行）在 `_filterCols` 之后，若 `row[CharacterCol.kind]` 存在且不在三值内 ⇒ `row.remove(CharacterCol.kind)` 并 `c.droppedColumns++`。

## 行为规则与边界情况
- R1 迁移后存量角色 kind = 'character'；schema_version = 11；从 v10 库升级不丢任何角色行。
- R2 CHECK 约束拒绝三值以外的写入（仓储层抛 InkError，控制器回滚乐观更新）。
- R3 面板组序固定 角色 → 物品 → 场景；空组（含被筛空的组）不画组头；组头数字 = 该组当前显示的行数。
- R4 组内顺序 = `listByProject` 的顺序（sort_order, created_at），分组不重排组内。
- R5 编辑框只改类型、不改名称描述 ⇒ 只发一条 update（kind）；什么都没改 ⇒ 不发写请求直接关。
- R6 setKind 失败：列表回滚到原类型，编辑框不关，弹错误卡（沿用 `_guard`）。
- R7 新建角色（createFromImage、画廊存为角色、剧本导入建角色）一律落默认「角色」——不改任何创建入口。
- R8 项目包：导出 `SELECT *` 自动带 kind；导入新包保留 kind；老包（无 kind 列）导入后为 'character'；第三方包里非法 kind 值被剔除并计入 droppedColumns，落默认值，不让整个导入因 CHECK 失败。
- R9 C1-A：kind 不进提示词，`generation_controller` 不读 kind（本片不碰它）。
- R10 @ 补全：候选按同样三组排，组内已挂载优先；只有一组非空时不画组头。
- R11 撤销：角色库不在画布撤销栈里，本片不登记撤销步。
- R12 平台差异：无（纯数据 + 列表渲染）。

## 新文案键
| key | en | zh |
|---|---|---|
| characterKindLabel | Type | 类型 |
| characterKindCharacter | Character | 角色 |
| characterKindProp | Prop | 物品 |
| characterKindScene | Scene | 场景 |

## 测试
- `test/quality/migration_registry_test.dart`：expected 加 `11: kSchemaV11`，`'版本序列从 1 起严格连续递增'` 自动覆盖。
- `test/storage/schema/populated_migration_test.dart`（pg）：用例 `'v11 backfills kind = character on existing rows'`：在 characters 有种子行时跑完链，断言 `kind = 'character'`；用例 `'v11 rejects unknown kind via CHECK'`：插 `kind = 'robot'` 抛 ServerException（CHECK）。
- `test/core/db/columns_schema_test.dart`（pg）：characters 期望列加 `CharacterCol.kind`（双向比对会逼着常量与真库一致）。
- `test/quality/import_schema_sync_test.dart`：不改；A 组 `'_characterCols 覆盖 CharacterCol 的全部列'` 必须绿；C 组新 ADD COLUMN 带 DEFAULT 必须绿。
- `test/services/import/import_remapper_test.dart`：`'character kind survives import'`；`'old package without kind column leaves kind unset for db default'`；`'invalid kind value is dropped and counted'`。
- `test/storage/repositories/project_import_writer_integration_test.dart`（pg）：`'old package characters import with default kind'`。
- `test/features/canvas/models/character_test.dart`：`'fromRow parses kind and falls back to character'`；`'equality includes kind'`。
- `test/features/canvas/providers/characters_controller_test.dart`：`'setKind updates optimistically and writes kind'`；`'setKind rolls back on InkError'`（FakeCharacterRepo.failUpdate）。
- `test/features/canvas/widgets/character_library_panel_test.dart`：`'groups by kind in character, prop, scene order'`；`'empty groups render no header'`；`'filter hides emptied groups'`。
- `test/features/canvas/widgets/character_edit_dialog_test.dart`：`'kind segments change kind on save'`；`'saving with only kind changed sends one update'`。
- `test/features/canvas/util/mention_candidates_test.dart`：`'candidates grouped by kind, mounted first within group'`。

## 变异点
- M1 `_characterCols` 去掉 `CharacterCol.kind` → import_schema_sync A 组与 `'character kind survives import'` 红。
- M2 迁移去掉 `DEFAULT 'character'` → `'v11 backfills kind = character on existing rows'` 红（ADD COLUMN NOT NULL 无默认值在有行时直接失败），import_schema_sync C 组同时红。
- M3 去掉 CHECK 约束 → `'v11 rejects unknown kind via CHECK'` 红。
- M4 `parseCharacterKind` 未知值改为抛错 → `'fromRow parses kind and falls back…'` 红。
- M5 `Character.==` 漏掉 kind → `'equality includes kind'` 红。
- M6 `groupCharactersByKind` 不剔除空组 → `'empty groups render no header'` 红。
- M7 `_save` 不写 kind → `'kind segments change kind on save'` 红。
- M8 remapper 不剔非法 kind → `'invalid kind value is dropped and counted'` 红。
- M9 `mentionCandidates` 去掉按类型排序 → `'candidates grouped by kind…'` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/quality test/services/import test/features/canvas --exclude-tags golden`；pg：`test/storage/schema`、`test/core/db/columns_schema_test.dart`、`test/storage/repositories/project_import_writer_integration_test.dart`（CI）；逐条做 M1–M9。
- 主 Agent 单独审 `schema_v11.dart` 的 DDL。
- 截图场景：`CharacterLibraryPanel`，ProviderScope 覆写 `charactersControllerProvider` 为 [阿青(角色,3 图)、小满(角色)、青铜灯(物品,2 图)、雾中山脊(场景,1 图)]：①三组全开；②筛「青」只剩两组；③只有角色组。`CharacterEditDialog` 打开阿青，类型切到「物品」未保存态。

## 风险与不确定
- v9 / v10 由 W4 / W10 加；若它们合入顺序变了，本片版本号仍是 11（plan 第 4 节已定），由主 Agent 在 rebase 时核对 `kAppMigrations` 连续。
- mention_candidates.dart / mention_popover.dart 不在归属表里：画板明写「@ 补全同样分组」，W12 先于本片合入，只能由本片补；W14 无人占用。
- character_library_panel.dart / character_edit_dialog.dart 在 W15 被 character-usage-links 叠改，本片尽量只动列表组装与表单区，少碰行内 meta 与「被引用」区。
- populated_migration_test 的种子写法需按该文件现有「边迁边种」结构插入 v11 断言，具体位置以文件为准。
