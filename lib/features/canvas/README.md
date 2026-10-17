# features/canvas

节点画布编辑器——InkFrame 的标志性界面。用户在这里摆放节点（text 文本 / image 图像 / video 视频 / shot 镜头，即 `CanvasNodeType` 四型）、连线、配置并发起生成。

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
- `canvas_tool_mode` — 工具态（选择 / 平移）+ 按住空格临时平移，按画布 autoDispose；实际是否平移 = 二者取或（`canvasPanActiveProvider`，舞台指针闸 / 手形光标 / 工具条高亮共用）
- `left_rail_state` — 画布左栏停在哪一页（大纲 / 素材 / 角色）+ 面板展开 / 收起；非 autoDispose（检查器「管理」链接、Ctrl+\ / ⌘\ 都要跨子树开合 / 切页）
- `inspector_tab` — 检查器停在「属性」还是「历史」；autoDispose，换选中节点不重置（历史页里点一行会把选中换到那张产物上，页签得留在历史页）
- `canvas_history_controller` — 每张画布一个撤销栈：keepAlive family、深度 100、纯内存不落库；`record` 只登记已做成的操作、清空重做栈；撤销 / 重做前先冲挂起写入；一道 busy 闸不排队；revert 失败那步留在栈顶，对象已不在就丢掉这步；`undoSpecific` 给撤销卡「点哪步撤哪步」；外壳 canvasId 离开本画布即丢栈并收起绑定的撤销卡
- `canvas_escape_ladder` — Esc 阶梯的运行时登记表：各层（菜单 / 拖线 / 框选 / 工具锁…）按 `EscapeRungId` 登记自己的「有没有东西可退、怎么退」，Esc 一次只剥最上面一层；层序在 `util/escape_ladder`
- `canvas_menu_state` — 画布菜单的请求与拖线 provider：`canvasMenuRequestProvider`（开着哪个菜单、锚点、源节点 / 右键的卡）+ `canvasWireDragProvider`（拖线实时状态，Esc 取消）；Esc 阶梯与快捷键从这里读，providers 层不反向依赖 widgets

## widgets（关键）
- `canvas_screen` — 整屏骨架：左栏（43px 导航条 + 可收起的 241 面板）| 画布区（`canvas_view` 舞台 + 浮层：顶部居中 `canvas_toolbar` / 底部居中提示词条 / 左下 `canvas_zoom_bar`）| 检查器；外层包 `canvas_shortcuts`（删除/Esc/全选/缩放 + 工具单键 V/H/I/G/T/F/L + 按住空格平移 + Ctrl+\ / ⌘\ 开合左栏；`isActive` 由外壳按标签可见性下传）。PR-6 页签去重撤掉了舞台上方的画布头（画布名在面包屑、泳道名写在泳道上、缩放比例在缩放条）和底部的渲染队列（任务进度挪到外壳状态栏的任务胶囊 + 任务弹层，见 `features/shell/widgets/shell_task_capsule.dart`），舞台上沿贴外壳标签栏、下沿贴状态栏。窗口 chrome 与面包屑在外壳 `ShellChrome`
- `canvas_zoom_bar` — 舞台左下的浮动缩放条（缩小 / % / 放大 / 适应），四格都走 `InkActivatable`
- `canvas_toolbar` — 舞台顶部居中的浮动工具条：选择 · 平移 | 图像 · 视频 · 文本 · 镜头 · 泳道 · 连线 | 更多（导入剧本…）。取代原左侧 37px 工具条与右下角加号
- `left_rail/` — 画布左栏（PR-4）：`canvas_left_rail`（43px 图标导航条：大纲 / 素材 / 角色 + 快捷键 / 收起）· `left_rail_panel`（241 面板宿主）· `outline_panel`（泳道分组的镜头行 + 产物子行，点行 = 单选 + 移到视口中心）· `canvas_switcher`（大纲面板头的画布切换胶囊）· `assets_panel` / `assets_model`（本画布 / 项目全部 + 类型 chip + 两列网格，数据复用画廊；开页即让画廊图失效一次，删掉的节点格子立刻消失）· `left_panel_parts`（面板头 / 筛选框）· `left_rail_actions`（定位：单选 + 居中）；角色页仍是 `character_library_panel`（顶上加了面板头 + 筛选）
- `canvas_view` — 只留 `CanvasView` / `_CanvasBody` / `_CanvasStage` 骨架，舞台各层在 `stage/`
- `stage/` — 舞台按层一层一个文件：`stage_pointer_layer`（平移闸 `StagePanGate` / 手形光标 / `StageSpace` / 空白处与右键的点击探测）· `node_card_slot`（单卡的定位、拖动换道、端口拖线）· `stage_edge_layer`（连线绘制、选中边的删除钮、边泳道错误、拖线中的预览线；画线本身走 `edge_painter`）· `stage_lane_layer`（分道位移 `StageLaneShift`、泳道底色、标题栏与分界线）· `stage_overlays`（挂起定位、选中计数、连线提示、加载失败）；后续切片各改各的层文件
- `canvas_menu/` — 画布上的菜单（`create_node_menu.dart` 是它的 barrel）：`canvas_menu_request`（菜单请求与拖线 provider 的转出口，实体在 `providers/canvas_menu_state`）· `canvas_menu_host`（舞台上的菜单宿主）· `canvas_menu_popover`（给锚点就开、null 就收的通用弹出层，大纲 / 序列右键也能用）· `menu_registry`（空白处 / 节点菜单项的分组表 `kCanvasMenuItems`；加菜单项 = 新文件 + 往表里追加一行）· `create_menu_entries` / `blank_menu_entries` / `node_menu_entries`（各类菜单项）；菜单面板本体是 theme 层的 `InkMenuPanel`
- `shortcuts/` — 画布快捷键注册表：`canvas_key_binding`（`CanvasKeyBinding`：id / 键位 / intent / 门槛 / 分组 / 文案 / onInvoke / listed / enabledWhen）· `canvas_shortcut_registry`（`kCanvasKeyRegistry`，后续切片新建 `shortcuts/<x>_keys.dart` 再往这里追加一行）· `core_canvas_keys`（现有键的绑定与回调）· `canvas_intents` · `canvas_tool_keys`；`canvas_shortcuts` 读注册表装配 Shortcuts / Actions。Esc 逐层退出：在输入框里只失焦、选中保留，没东西可退时不吞键
- `node_card` / `video_node_body` — 节点卡片各形态
- `canvas_inspector_panel` — 右侧检查器：页签「属性 / 历史」（原「状态」页签只画不挂交互，已删——状态内嵌在各配置检查器的 `inspector_status_panel` 里）
- `inspector_history_panel` — 检查器「历史」页：选中配置节点 = 名下全部 take（`node_artifacts.resultsFor`，新 → 旧），选中产物节点 = 同一来源的兄弟、当前那张高亮；「take N」按时间正序编号（`util/take_numbers`，与素材页同一个号；名下只有一个写「成片」）；有 data 出边（首帧 / 尾帧 / 参考）的 take 标「在用」；点一行 = 单选 + 居中（`left_rail_actions.focusNodeOnCanvas`）
- `node_inspector_router` — 按 (role, type) 分发：config → `image_config_inspector` / `video_config_inspector` / `shot_config_inspector`（前二者共用 `inspector_status_panel`）；result+image → `image_result_inspector`
- `node_inputs_section` — config 节点入边列表 + role 切换（reference/first_frame/last_frame，按能力位门控），被 image/video config inspector 挂载
- `batch_results_grid` — 结果节点的批量/变体槽位网格（挂载于 `image_result_inspector`）
- `lane_*`（background/title_bar/toolbar/edit_dialog）/ `base_style_editor_dialog` / `canvas_empty_state` / `video_lightbox` / `canvas_job_listener`（挂在外壳根 `InkShell`，不随画布页挂载）

## util
`node_position` · `edge_hit_test` · `lane_geometry` · `lane_tint` · `base_style_presets` · `canvas_job_effects` · `canvas_zoom` · `canvas_node_delete` · `canvas_snackbars` · `canvas_tool_actions`（工具条与单键快捷键共用：视口中心 + 散布建节点〔与新建菜单同一条 addNodeFromMenu：判泳道、只单选〕/ 建泳道 / 切连线 / 选择工具）· `outline_model`（左栏大纲分组 + 「在链上」的唯一判据；镜号走序列口径 `sequenceShotNumbers`，⌘K 共用）· `take_numbers`（take 号，素材页与检查器历史页共用）· `viewport_focus`（保持缩放、把节点移到视口中心）· `escape_ladder`（Esc 阶梯的层序表 `EscapeRungId` 与取最上层的纯函数；层序只在这里定，登记顺序不影响优先级）· `selection_geometry`（选区几何的唯一判据：框选命中〔闭区间相交，碰到就算；跳过折叠道里的卡〕、`applyMarquee` 三种模式〔替换 / Shift 加选 / Ctrl·⌘ 反选〕、选区包围盒〔按当前相机算、含分道位移〕；卡片矩形走 `nodeStageRect`）

## 数据流（生成一次图/视频）
1. 选中 config 节点 → `node_inspector_router` 渲染对应 inspector
2. inspector 控件按 **provider 能力位**显隐（分辨率/比例/时长/运镜/seed/负向/批量，ADR-0009），改动经 `inspector_submit_controller.saveConfig` 落 `type_config`
3. 点"生成" → `inspector_submit_controller.submit` 落最终 config → `GenerationController.submitFromConfigNode`（见 [features/generation](../generation/README.md)）
4. 进度：`node_active_job` / `inspector_status_panel` 从 `jobsRegistry` 读该节点活跃 job 的真实进度；外壳状态栏的任务胶囊 / 任务弹层同源展示全部 job

shot 分支：`shot_config_inspector` 的「用备注生成图像」以 `shot_notes` 为 prompt 新建 image config 节点 + narrative 边（复用同一生成链路）

## 约束
- 文案走 `context.l10n.*`，样式走 `context.inkColors` / `InkSpacing` 等 token（ADR-0010，widget 内零硬编码）
