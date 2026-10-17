# gen-inputs-snapshot · 生成快照 gen_inputs（建 job 同一事务写入；项目包导入改写 / 剥除）

- 波次 W2 · lane C · 基底：origin/main（W0–W1 全部合入后，含 W1 current-take 新建的 `lib/core/constants/take_keys.dart` 的 `TakeKeys.genInputs` / `TakeKeys.pinnedResultId`）
- 依赖切片：current-take（常量与 `pinned_result_id` 语义）
- 阻塞决定：无

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（W0–W1 已合入，含 current-take）起分支 `feat/gen-inputs-snapshot`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（本片不碰）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart（本片不加派生属性；读快照归 W7 tc-stale-marks）。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法；用现有 create(typeConfig:) / patchTypeConfig，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`（本片无）。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
每次生成，在建 result 节点和 job 行的**同一个事务**里，把这次用到的输入（提示词、负向、种子、模型参数、运镜 / 镜头语言、泳道与画布底稿风格、挂载角色、每条 data 入边的源节点与 image_url）写进 result 节点的 `type_config.gen_inputs`。项目包导入时，快照里的源节点 id、角色 id 和配置节点的 `pinned_result_id` 跟着 UUID 映射改写，映射不到的剥掉。用户这一片看不到变化——它是 W7 过期标记、W5 下游连线跟随的数据底座。

## 设计依据
- **TakesCost.dc.html · 过期标记**：「**快照**：建 job 的同一事务写 result 的 type_config.`gen_inputs`——提示词 / 负向 / 种子 / 模型参数 / 运镜、泳道与画布底稿风格、挂载角色、每条 data 入边的源与 image_url」「不拿 jobs 行当快照：它 30 天 / 按画布上限会被清」「只标当前 take；旧 take 是历史不标；没快照的老产物不标」「不算变化：改名、位置、层级、批量张数、原本就随机的种子」。
- 同节「**重映射**：`gen_inputs` 里的源节点 id 和 `pinned_result_id` 一起处理。导入项目包（`import_remapper`）按 UUID 映射改写 · 插入模板：模板不带产物，两样都不该出现，出现就剥掉 · 跨项目粘贴：映射得到的改写，映射不到的剥掉；剥掉源 id 的 take 记作「没快照」，不标过期 · 提示词里的 `@{角色 id}` 同样要改写或剥掉，规则在 ImportSearch」（`@{角色 id}` 归 W11 mention-token-core）。
- critic 第 18 条（重映射漏项）：本片落 `import_remapper` 一处，并导出 `stripUnmappedGenInputs` 给 W17 模板插入、W7 粘贴复用。
- **设计缺口**：① 快照里要不要记**文本节点**入边的正文——板上只写「源与 image_url」，但关联文本会并进提示词，改了它属于「输入变了」。按建议：文本源额外记 `text`（与 `_resolveAssociatedTexts` 同口径：正文为空取 label）。② 角色映射不到时是剥一个角色还是整份快照——板上没写。按建议：**整份快照剥掉**（与「剥掉源 id 的 take 记作没快照」同一口径，宁可不标过期也不误标）。③ 批量张数不进快照（板：「不算变化」）。

## 允许改的文件
- `lib/core/models/gen_inputs.dart`（新建，纯 Dart，无 Flutter）：`GenInputSource` 值对象 + `stripUnmappedGenInputs`。放 core 是因为 `services/import/import_remapper.dart` 要用，services 不 import features。
- `lib/features/generation/services/gen_inputs_snapshot.dart`（新建）：`buildGenInputs` 纯函数；`export '../../../core/models/gen_inputs.dart' show GenInputSource, stripUnmappedGenInputs;`（contract 名字从这里也拿得到）。
- `lib/features/generation/generation_controller.dart`：
  - `_assembleFullPrompt`（第 911 行）拆出 `_readStyles(canvasId, laneId, ignoreLaneStyle)` 返回 `({String basePrefix, String baseSuffix, String laneStyle})`，`_assembleFullPrompt` 改收这个记录（只读一次库）。
  - 新私有 `_snapshotSources(List<Map<String, Object?>> incoming)`：按 `incoming` 顺序遍历 data 边，`nodes.findById` 取源，产出 `List<GenInputSource>`；单条查不到 / 抛 `InkError` → 仍记 `node_id + role`，`image_url` 为 null，warn 一条（不阻断生成）。
  - `submitFromConfigNode` 第 307–318 行 `scope.nodes.create(...)` 加 `typeConfig: <String, Object?>{TakeKeys.genInputs: snapshot}`；`snapshot` 在 `uow.run` **之前**算好（读库在事务外，写在事务内）。
- `lib/services/import/import_remapper.dart`：第 220–238 行（拍板 8 改写 `character_ids` 的同一处）之后调用 `stripUnmappedGenInputs`，`dropped` 计进 `c.nulledRefs`。
- 测试：`test/features/generation/services/gen_inputs_snapshot_test.dart`（新）、`test/core/models/gen_inputs_test.dart`（新）、`test/features/generation/generation_controller_test.dart`、`test/services/import/import_remapper_test.dart`。

## 不许碰的文件
- W2 node-cost（同波）：`lib/features/generation/services/cost_estimator.dart`、`lib/features/generation/services/node_cost.dart`、`lib/features/canvas/widgets/cost_breakdown_tooltip.dart`、`image_config_inspector.dart`、`video_config_inspector.dart`、`inspector_status_panel.dart`、`canvas_prompt_bar.dart` 及其测试。
- W2 undo-shortcuts-ui：`shortcuts/undo_keys.dart`、`canvas_menu/undo_menu_items.dart`、`util/canvas_history_actions.dart`、`app_actions/app_action_catalog.dart`。
- W2 lane-ops-core：`canvas_lanes_controller.dart`、`util/lane_dissolve.dart`、`util/canvas_lane_actions.dart`（新）、`stage/stage_lane_layer.dart`、`lane_toolbar.dart` / `lane_title_bar.dart`。
- （主 Agent 跨批核对补充）W2 undo-shortcuts-ui 还改 `lib/features/settings/util/shortcut_catalog.dart`。
- W2 media-import-service：`canvas_nodes_controller.dart`、`node_card.dart`、`services/orphan_file_reaper.dart`、`storage/repositories/postgres_node_repository.dart`、`core/interfaces/media_import_service.dart`、`services/file_media_import_service.dart`、`core/di/media_import.dart`、`canvas/models/canvas_node_import.dart`、`providers/media_import_controller.dart`。
- 本片额外不碰：`lib/services/project_archive_service.dart`、`lib/storage/repositories/postgres_project_archive_reader.dart`（见「风险」：导出是全保真闭包，不需要剥）、`lib/core/constants/take_keys.dart`（W1 已建好两个键）、`lib/services/job_queue/job_media_persister.dart`（它用 `patchTypeConfig` 合并写 `image_url` 等，不会冲掉 `gen_inputs`——只读确认，不改）。

## 具体改动
```dart
// core/models/gen_inputs.dart
class GenInputSource {
  const GenInputSource({required this.nodeId, required this.role, this.imageUrl, this.text});
  final String nodeId; final String role; // first_frame / last_frame / reference（edge.role，缺省 reference）
  final String? imageUrl; final String? text;
  Map<String, Object?> toJson();            // 键：node_id / role / image_url / text（null 不写）
  static GenInputSource? fromJson(Object? raw); // 形状不对 ⇒ null
}
typedef GenInputsRemap = ({Map<String, Object?> typeConfig, int dropped});
/// 改写一份 type_config 里的 gen_inputs 与 pinned_result_id：
///  - gen_inputs.sources[].node_id、gen_inputs.character_ids 全部映射得到 ⇒ 改写成新 id；
///    任一映射不到 / 形状不对 ⇒ 整个 gen_inputs 键删掉（= 没快照），dropped += 1；
///  - pinned_result_id 映射得到 ⇒ 改写；映射不到 ⇒ 删键，dropped += 1；
///  - 两个键都没有 ⇒ 原样返回、dropped 0。返回新 Map，不改入参。
/// 模板插入传 (_) => null；跨项目粘贴传选区内映射。
GenInputsRemap stripUnmappedGenInputs(Map<String, Object?> typeConfig,
    {required String? Function(String oldNodeId) mapNode, required String? Function(String oldCharacterId) mapCharacter});

// features/generation/services/gen_inputs_snapshot.dart
/// 结果只含有值的键；prompt 是用户提示词（trim 后，不含镜头语言前缀与风格——那些分开记）。
Map<String, Object?> buildGenInputs({
  required Map<String, Object?> configTypeConfig, required String prompt, required int? seed, bool seedOverridden = false,
  required String providerId, required Resolution resolution, required AspectRatio aspectRatio,
  required int? durationMs, required String? negativePrompt,
  required ({String basePrefix, String baseSuffix, String laneStyle}) styles, required bool ignoreLaneStyle,
  required List<GenInputSource> sources,
});
```
快照形状（`type_config.gen_inputs`，JSONB，不迁移）：
`prompt` · `negative_prompt`? · `seed`?（实际用的，含 seedOverride；随机 = 不写）· `seed_override`?（true 才写：这次的种子来自「以该种子重跑」，不是节点设置）· `provider_id` · `resolution` · `aspect_ratio` · `duration_ms`?（video）· `camera`? · `shot_size` / `camera_angle` / `camera_motion_strength` / `focal_length_mm`?（`ShotLanguage.key*` 常量，原样拷）· `base_style_prefix` · `base_style_suffix` · `lane_style`（ignore 时为 ''）· `ignore_lane_style`?（true 才写）· `character_ids`（原序，空列表也写）· `sources`（`List<Map>`，`listIncoming` 顺序）。不含 `batch_size`。

## 行为规则与边界情况
1. 每次 `submitFromConfigNode` 成功建出的 result 节点 `type_config` 恰有一个键 `gen_inputs`（产物 url 由 persister 之后合并写入，不冲掉它）。
2. `seedOverride`（以该种子重跑）→ 快照 `seed` 是 override 值，并写 `seed_override: true`；配置节点不变。W7 tc-stale-marks 见到这个键就不比种子，否则这张一成为当前就被误判「种子已改」过期（主 Agent 跨批核对补充）。
3. 节点没设 seed → 快照不写 `seed`。
4. `ignore_lane_style: true` → `lane_style` 为 ''、`ignore_lane_style: true`。
5. 泳道 / 画布风格读库失败（已有 warn 降级为空串）→ 快照照记空串，生成不受影响。
6. data 入边源节点查不到 → 该源仍记 `node_id`/`role`，`image_url` 缺；narrative 边不进 `sources`。
7. 文本节点源 → 记 `text`（正文为空用 label）；图像源 → 记 `image_url`（画布相对路径，原样）。
8. 建行事务失败（`jobs.create` 抛）→ result 节点（含快照）一并回滚，库里无残留；`queue.submit` 失败的补偿路径照旧软删 result。
9. 批量（batch_size>1）→ 一个 result 容器一份快照，slot 行不带快照。
10. 导入：老包（无 `gen_inputs` / `pinned_result_id`）→ 节点 `type_config` 原样，计数不变。
11. 导入：快照的源节点与角色都在包里 → 改写成新 UUID；配置节点 `pinned_result_id` 改写成新 id。
12. 导入：任一源 / 角色映射不到（硬删过的节点、手工包）→ 整份 `gen_inputs` 删掉，`nulledRefs` +1；`pinned_result_id` 映射不到 → 删键，`nulledRefs` +1（判据回落最新，见 current-take）。
13. 导入：`gen_inputs` 不是 Map / `sources` 不是 List / 某项缺 `node_id` → 当形状不对，整份删掉 +1。
14. 纯函数部分无并发；与撤销栈无交互（生成本就不进栈）；mac / Windows 无差异（路径是画布相对的 `/` 分隔字符串，原样存）。

## 新文案键
无。

## 测试
- `test/core/models/gen_inputs_test.dart`（新）：
  - `'GenInputSource toJson / fromJson 往返；null 字段不写'`；`'fromJson 形状不对 → null'`。
  - `'stripUnmappedGenInputs：全映射得到 → 改写源 id 与角色 id'`。
  - `'任一源映射不到 → 整份 gen_inputs 删掉，dropped=1'`。
  - `'角色映射不到 → 整份删掉'`。
  - `'pinned_result_id 映射得到改写、映射不到删键'`。
  - `'模板插入 (_) => null：两个键都剥掉，其余键原样'`。
  - `'没有这两个键 → 原样、dropped=0、不改入参'`。
- `test/features/generation/services/gen_inputs_snapshot_test.dart`（新）：
  - `'只写有值的键；不含 batch_size'`；`'镜头语言四键原样拷'`；`'ignore_lane_style → lane_style 空串 + 标记'`；`'sources 保持传入顺序'`。
- `test/features/generation/generation_controller_test.dart` 新 `group('gen_inputs 快照')`：
  - `'result 节点 type_config 带 gen_inputs：提示词 / provider / 分辨率 / 画幅 / 底稿风格 / 泳道风格'`（`_FakeCanvasRepo(baseStylePrefix:)`、`_FakeLaneRepo(stylePrompt:)`）。
  - `'seedOverride 记进快照并带 seed_override: true，节点 seed 不变；没有 override 时不写 seed_override'`。
  - `'data 入边：图像源记 image_url，文本源记 text，查不到的源只记 id'`（`_FakeEdgeRepo.listIncoming`）。
  - `'挂载角色 character_ids 原序进快照'`。
  - 断言方式：读 `_FakeNodeRepo.creates.first['type_config']`——快照必须在 `create` 那一刻就带上（`FakeUnitOfWork.run` 只是直调闭包、不模拟回滚，「同一事务」靠「随 create 一起写」来钉；真回滚由 PG 保证，现有 `'jobs.create 抛错 → 创建事务回滚…'` 不改）。
- `test/services/import/import_remapper_test.dart` 追加：
  - `'gen_inputs 源 id / 角色 id 随 UUID 改写'`；`'gen_inputs 引用了包外节点 → 整份剥掉并计数'`；`'配置节点 pinned_result_id 改写；悬空删键并计数'`；`'老包没有这两个键 → 原样'`。

## 变异点
1. `scope.nodes.create` 不传 `typeConfig` → `'result 节点 type_config 带 gen_inputs…'` 红。
2. 快照 `seed` 取配置节点的而非实际用的 → `'seedOverride 记进快照…'` 红。
3. 快照里多写 `batch_size` → `'只写有值的键；不含 batch_size'` 红。
4. `_snapshotSources` 查不到源就 `continue` → `'data 入边：… 查不到的源只记 id'` 红。
5. 不写 `seed_override`（或无 override 时也写）→ `'seedOverride 记进快照…'` 红。
5. 快照改成事务提交后再单独 `patchTypeConfig` 写（不随 create 带上）→ `'result 节点 type_config 带 gen_inputs…'` 红（它断言的是 `creates.first['type_config']`）。
6. `stripUnmappedGenInputs` 映射不到时只删那一个源而不是整份 → `'任一源映射不到 → 整份 gen_inputs 删掉'` 红。
7. 角色不映射（原样保留旧 id）→ `'stripUnmappedGenInputs：全映射得到 → 改写源 id 与角色 id'` 红。
8. `pinned_result_id` 悬空时留旧 id → `'pinned_result_id 映射得到改写、映射不到删键'` 与 remapper `'…悬空删键并计数'` 红。
9. remapper 不调用 `stripUnmappedGenInputs` → `'gen_inputs 源 id / 角色 id 随 UUID 改写'` 红。
10. `dropped` 不计进 `nulledRefs` → `'gen_inputs 引用了包外节点 → 整份剥掉并计数'` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/core/models test/features/generation test/services/import test/quality/import_schema_sync_test.dart`；上面 10 条变异。
- 手动核对：`job_media_persister.dart` 第 223 / 343 / 470 / 610 行全部是 `patchTypeConfig`（`type_config || patch` 合并语义，见 `postgres_node_repository.dart` 第 137–150 行），不会冲掉 `gen_inputs`。
- 无 UI，不截图。

## 风险与不确定
- **偏离约定（导出侧）**：contract 写「project_archive 导出侧 stripUnmappedGenInputs」。核对后：`ZipProjectArchiveService` 经 `PostgresProjectArchiveReader` 读的是**全保真闭包**（含软删行），快照引用的节点 / 角色都在包里，导出侧没有可剥的；唯一可能悬空的是被 LB-14 硬删的空 result 壳，由导入侧 `stripUnmappedGenInputs` 兜住。所以导出侧不改，`stripUnmappedGenInputs` 由 `core/models/gen_inputs.dart` 定义、`gen_inputs_snapshot.dart` 再导出，供导入 / 模板 / 粘贴三处共用。
- **偏离约定（位置）**：`stripUnmappedGenInputs` 实体放在 `lib/core/models/gen_inputs.dart`（services 层的 remapper 要用），名字不变。
- `canvas_tool_actions.duplicateNodes`（Ctrl D 复制一份）会把配置节点的 `pinned_result_id` 一起复制：副本的固定 id 指向原配置的产物，`currentResultFor` 因 sourceNodeId 不符回落最新，无害；要剥请在 W4 起碰 canvas_tool_actions 的切片里顺手用 `stripUnmappedGenInputs(…, mapNode: (_) => null, …)`。本片不碰。
- `generation_controller.dart` 是热点（W5 edge-follow / W10 executor / W11 mention 依次改），本片只动 `_assembleFullPrompt` 签名、加 `_readStyles` / `_snapshotSources`、给 create 加一个参数，尽量不挪别的行。
