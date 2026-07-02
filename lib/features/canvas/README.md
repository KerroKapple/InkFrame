# features/canvas

节点画布编辑器——InkFrame 的标志性界面。用户在这里摆放节点（角色/场景/分镜/图像·视频生成）、连线、配置并发起生成。

> 相关 ADR：[0007 节点 type×role + JSONB](../../../docs/adr/0007-node-type-role-jsonb-config.md) · [0008 渲染队列](../../../docs/adr/0008-render-queue-jobstate-vs-jobstatus.md) · [0009 Provider 能力/接口隔离](../../../docs/adr/0009-provider-capability-and-interface-segregation.md) · [0010 i18n/token 零硬编码](../../../docs/adr/0010-zero-hardcoding-i18n-and-design-tokens.md)

## 分层

```
models/     不可变领域模型（freezed）
providers/  Riverpod ViewModel/控制器（screen-scoped，ADR-0002）
widgets/    纯 UI（读 provider、走 token/l10n）
util/       无副作用的几何/命中/预设工具
```

## models
- `canvas_node.dart` — `CanvasNodeType`(image/text/video/shot) × `NodeRole`(config/result) + `typeConfig`(JSONB Map) 与类型化 getter（见 ADR-0007）
- `canvas_edge.dart` — 边：`EdgeType`(data/narrative…) + `EdgeRole`(reference/firstFrame/lastFrame)
- `style_lane.dart` — 泳道（风格提示 + 色调 + 排序）
- `character.dart` — 角色实体
- `batch_result.dart` — 批量/变体结果槽位（对应 `batch_results` 表行）
- `prompt_preset.dart` — 提示词预设（项目级，schema_v7）

## providers（关键）
- `canvas_nodes_controller` / `canvas_edges_controller` / `canvas_lanes_controller` — 画布三大集合，仓库(Map)→freezed
- `canvas_selection_controller` / `selected_edge_controller` — 选择态
- `link_mode_controller` / `link_action_controller` — 连线模式与落库
- `inspector_submit_controller` — inspector 四态 + `type_config` 持久化 + 提交生成（见 §数据流）
- `node_active_job` — 按节点回读注册表里的活跃 job（inspector 进度来源，ADR-0008）
- `prompt_presets_controller` — 提示词预设 CRUD（项目级）
- `canvas_base_style` / `lane_collapse_controller` / `characters_controller` / `playable_video_path` / `current_canvas_id` / `current_canvas_name` / `canvas_bootstrap_controller`

## widgets（关键）
- `canvas_screen` — 整屏骨架：`canvas_top_chrome` + `canvas_left_toolbar` + `canvas_view` + `canvas_render_queue`
- `canvas_view` / `edge_painter` — 画布视口与连线绘制
- `node_card` / `canvas_node_card` / `video_node_body` — 节点卡片各形态
- `node_inspector_router` — 按 (role==config, type) 分发 → `image_config_inspector` / `video_config_inspector` / `shot_config_inspector`；前二者共用 `inspector_status_panel`
- `batch_results_grid` — 结果节点的批量/变体槽位网格
- `canvas_render_queue` — 右侧渲染队列（消费 `jobsRegistry`）
- `lane_*`（background/title_bar/toolbar/edit_dialog）/ `base_style_editor_dialog` / `canvas_add_node_fab` / `canvas_empty_state` / `video_lightbox` / `canvas_job_listener`

## util
`node_position` · `edge_hit_test` · `lane_geometry` · `lane_tint` · `base_style_presets` · `canvas_job_effects`

## 数据流（生成一次图/视频）
1. 选中 config 节点 → `node_inspector_router` 渲染对应 inspector
2. inspector 控件按 **provider 能力位**显隐（分辨率/比例/时长/运镜/seed/负向/批量，ADR-0009），改动经 `inspector_submit_controller.saveConfig` 落 `type_config`
3. 点"生成" → `inspector_submit_controller.submit` 落最终 config → `GenerationController.submitFromConfigNode`（见 [features/generation](../generation/README.md)）
4. 进度：`node_active_job` / `inspector_status_panel` 从 `jobsRegistry` 读该节点活跃 job 的真实进度；渲染队列面板同源展示

## 约束
- 文案走 `context.l10n.*`，样式走 `context.inkColors` / `InkSpacing` 等 token（ADR-0010，widget 内零硬编码）
