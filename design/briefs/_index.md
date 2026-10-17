# 第二批派工单总索引（W0–W19，112 片）

2026-10-17 跨批核对后的版本。5 位撰写人各写一批（W0–3 / W4–7 / W8–11 / W12–15 / W16–19），各自核对过本批；主 Agent 再把他们报给别批的问题改进了对应派工单。改前备份在 `design/briefs_bak_xbatch/`（另有各批自己的备份 `briefs-w0/`、`briefs_bak_w12_15/`、`briefs-backup-w16-19/`）。

## 全批统一约定（派工单与此不符时，以这里为准）

- **撤销命令**：`CanvasCommand` 不 sealed、不用 `part`、没有 label 枚举。每条命令一个独立文件 `lib/features/canvas/models/commands/<x>_command.dart`，自带 `String label(AppLocalizations l)`；`revert` / `apply` 收 `CanvasCommandEnv`（canvasId 从这里取，不进构造参数），返回 `CanvasCommandOutcome`。入栈用 `CanvasHistoryController.record`：只登记、不执行。`canvas_command.dart` 只有 W0 undo-stack 改它。
- **步名键**：一律用 `canvasCommand*` 前缀（原来混着用的 `canvasCmd*` / `canvasUndoStep*` 已统一改掉；`canvasUndoStepGone` 是失败提示，不是步名，保留）。
- **撤销卡**：`showCanvasUndoSnack(context, {message, canvasId, stepId, onUndo, body})` 两种用法二选一。给 `canvasId + stepId` 时按步登记。只给 `onUndo` 时出旧式回调卡，只留给 W2 lane-ops-core 的两处用；W6 undo-lanes、cm-delete-bridge 两片都合入后，由主 Agent 删掉这个分支。
- **菜单置灰原因**：统一用 `InkMenuEntry.disabledReason`（W3 help-actions 加）。行尾常显的小字用 `InkMenuEntry.note`（W6 cm-edge-menu 加）。没有叫 `tooltip` 的字段。
- **快捷键**：一律写成 esc-ladder 的 `CanvasKeyBinding` + `CanvasKeyGate`，往 `kCanvasKeyRegistry` 追加一行。绑定 id 用 lowerCamel、以 `canvas` 开头、不含「.」。第二批新键位只引用 W1 的 `PlannedKeys`，不另抄常量。Esc 层只调 `canvasEscapeLadderProvider.register / unregister`。只有 cm-knife-cut 会往 `EscapeRungId` 追加 `edgeCut`。
- **舞台路径**：canvas-view-split 拆出的文件都在 `lib/features/canvas/widgets/stage/` 下（`node_card_slot` / `stage_edge_layer` / `stage_lane_layer` / `stage_overlays` / `stage_pointer_layer`）。类名用 `StagePanGate`、`BlankPointerDetector`。
- **菜单请求**：`CanvasMenuKind` / `CanvasMenuRequest` / `CanvasMenuController` / `CanvasMenuKeys` 都在 `canvas_menu/canvas_menu_request.dart`，宿主只管渲染。
- **时长**：片长和估时用 `formatDurationLabel`（四舍五入，`estimated:` 加「~」）。计时用 `formatElapsed`（向下取整）。
- **当前 take**：用 `currentResultFor` / `currentTakeNodeIds` / `pinnedResultIdsBySource`。`latestResultFor` 在 W1 之后删掉，不许回退。`CanvasNode` 是手写的 `@immutable` 类，新派生属性写成单独文件里的 extension。
- **注册表例外**（每片只追加一行，不算占用）：除了 plan 第 0 节列的四张表，还有 `app_action_ids.dart`、`widgets/stage_drop/stage_drop_registry.dart`（`kStageDropHandlers`）、`canvas_drag_payload.dart` 的 `part` 行、`lib/features/export/re_export.dart`（`kReExportHandlers`）。
- **价格 / 时长 / 动作文案**：复用 node-cost 的 `costApprox` / `costUnknown` / `costUnknownMore`、duration-format 的 `durationEstimated`、W1 的 `appAction*`（例如「包成泳道」= `appActionWrapInLane`），不另建同义键。

## 一、派工单总表

基底 / 前序一栏的「依赖」只列更早波次的切片；同 lane 串行的写「叠在 X 之后」。阻塞决定里加粗的是 plan 第 5 节「必须先拍板」的项：派工单都按建议写了，仍需你确认。

| id | 标题 | 波次 | lane | 基底 / 前序 | 迁移 | 新依赖 | 阻塞决定 |
|---|---|---|---|---|---|---|---|
| menu-split | 拆 create_node_menu.dart：菜单面板进 theme 层，宿主 / … | W0 | A | origin/main f64f56e | — | — | — |
| canvas-view-split | 拆 canvas_view.dart：舞台各层搬进 widgets/stage/，骨架… | W0 | B | origin/main f64f56e | — | — | — |
| esc-ladder | Esc 阶梯 + 画布快捷键改注册表 | W0 | C | origin/main f64f56e | — | — | — |
| zoom-reset-100 | Ctrl 0 / ⌘0 = 缩放到 100%、保持视口中心 | W0 | C | origin/main f64f56e；叠在 esc-ladder 之后 | — | — | KM-Q5 → B |
| undo-stack | 画布撤销栈底座（CanvasHistoryController + CanvasCom… | W0 | D | origin/main f64f56e | — | — | UC-Q1 → A |
| naming-shot-unify | 统一叫法：分镜 → 镜头、导入脚本 → 导入剧本、「创建 N 个镜头」 | W0 | D | origin/main f64f56e；叠在 undo-stack 之后 | — | — | — |
| multi-select-core | 选中控制器补批量方法 + 选区几何纯函数（框选命中 / 选区包围盒） | W0 | E | origin/main f64f56e | — | — | Sel-Q1 → A（按建议） |
| duration-format | 统一时长 / 耗时格式函数 | W0 | E | origin/main f64f56e；叠在 multi-select-core 之后 | — | — | — |
| nodes-batch-ops | 节点批量写：moveNodes / removeNodes / restoreAll … | W1 | A | main（W0 合入后）；依赖 undo-stack | — | — | — |
| narrative-splice | 叙事链拼接底座（插入一镜 / 删除接上 / 挪位 / 换连线类型 / 批量删线，纯函数… | W1 | B | main（W0 合入后）；依赖 undo-stack | — | — | — |
| canvas-capsule | 画布轻提示胶囊（InkCanvasCapsule + CanvasCapsuleHos… | W1 | C | main（W0 合入后）；依赖 esc-ladder、zoom-reset-100 | — | — | — |
| current-take | 「当前 take」判据收成 currentResultFor | W1 | D | main（W0 合入后）；依赖 menu-split | — | — | TC-Q2 → A |
| app-action-table | 共用动作表（id · 文案 · 键位 · 可用判据 · 执行） | W1 | E | main（W0 合入后）；依赖 esc-ladder、menu-split、zoom-reset-100 | — | — | — |
| undo-shortcuts-ui | 撤销 / 重做入口：Ctrl Z · Ctrl Y / ⌘Z · ⇧⌘Z、空白处右键两… | W2 | A | main（W0–W1 合入后）；依赖 app-action-table、canvas-capsule、esc-ladder、menu-split、multi-select-core、undo-stack | — | — | — |
| node-cost | 节点花费预估（算不出写「—」，提示词条常驻金额，悬停「生成」出明细） | W2 | B | main（W0–W1 合入后）；依赖 duration-format | — | — | 币种已定 USD |
| gen-inputs-snapshot | 生成快照 gen_inputs（建 job 同一事务写入；项目包导入改写 / 剥除） | W2 | C | main（W0–W1 合入后）；依赖 current-take | — | — | — |
| lane-ops-core | 泳道操作底座：解散（节点留下）与删除泳道和内容；修删道后 lane_id 悬空 | W2 | D | main（W0–W1 合入后）；依赖 canvas-view-split、undo-stack | — | — | — |
| media-import-service | 媒体导入服务：复制进 canvases/<id>/imports/，建无来源的导入式产… | W2 | E | main（W0–W1 合入后）；依赖 multi-select-core、nodes-batch-ops | — | — | IS-Q2 / IS-Q6 → A |
| undo-adopt-existing | 已有撤销卡并进栈：删节点、删连线、拖动换道；卡片只是提醒，收起后 Ctrl Z 仍可撤 | W3 | A | main（W0–W2 合入后）；依赖 canvas-view-split、nodes-batch-ops、undo-shortcuts-ui、undo-stack | — | — | — |
| marquee-select | 左键拖空白 = 框选（Shift 加选、Ctrl/⌘ 反选），Esc 取消并恢复；中键… | W3 | B | main（W0–W2 合入后）；依赖 canvas-view-split、esc-ladder、multi-select-core | — | — | Sel-Q1 / Q7 按建议 |
| tc-set-current | 设为当前（固定 take）+ 进撤销栈 | W3 | C | main（W0–W2 合入后）；依赖 canvas-capsule、current-take、media-import-service、menu-split、node-cost、nodes-batch-ops、undo-shortcuts-ui、undo-stack | — | — | **TC-Q1 → A**（定撤销命令形状） |
| import-media-command | Ctrl/⌘ U 与「导入媒体…」：多选文件，视口中心散布落点，一张通知带撤销并点名跳… | W3 | D | main（W0–W2 合入后）；依赖 app-action-table、esc-ladder、media-import-service、menu-split、multi-select-core、nodes-batch-ops、undo-shortcuts-ui、undo-stack | — | — | — |
| help-actions | 帮助动作组 + 左栏帮助弹层（菜单栏帮助 = 快捷键 + 同一组动作） | W3 | E | main（W0–W2 合入后）；依赖 app-action-table、menu-split | — | — | R8 → A |
| undo-node-create-move | 新建 / 复制一份 / 移动 / 加入·移出泳道进栈（含新建菜单里建好并连线算一步） | W4 | A | main（W0–W3 合入后）；依赖 canvas-capsule、nodes-batch-ops、undo-adopt-existing、undo-shortcuts-ui、undo-stack | — | — | — |
| tc-batch-slot-set-current | 批量 slot：点 slot = promote + 设为当前，同一事务，带撤销令牌；… | W4 | B | main（W0–W3 合入后）；依赖 current-take、tc-set-current、undo-stack | — | — | UC-Q3 → A |
| stage-drop-target | 舞台应用内拖放底座：sealed 拖放载荷 + 舞台 DragTarget + 悬停卡… | W4 | C | main（W0–W3 合入后）；依赖 canvas-view-split | — | — | — |
| win-menubar | Windows 自绘菜单栏（文件 / 编辑 / 画布 / 节点 / 窗口 / 帮助真能… | W4 | D | main（W0–W3 合入后）；依赖 app-action-table、esc-ladder、help-actions、menu-split | — | — | — |
| export-records-table | export_records 表：v9 前向迁移 + 仓储 + 列常量 + 手写不可变… | W4 | E | main（W0–W3 合入后） | v9 | — | SE-Q3 → A |
| group-drag | 整组拖动（按抓住的那张判换道）+ Shift 锁轴 | W5 | A | main（W0–W4 合入后）；依赖 canvas-view-split、marquee-select、multi-select-core、nodes-batch-ops、stage-drop-target、undo-adopt-existing、undo-node-create-move、undo-stack | — | — | Sel-Q2 已定 B |
| undo-edges | 连线 / 删线 / 改语义进栈；改首帧·尾帧连带降级的那条一起回 | W5 | B | main（W0–W4 合入后）；依赖 narrative-splice、undo-adopt-existing、undo-node-create-move、undo-shortcuts-ui、undo-stack | — | — | — |
| undo-params | 改参数 / 改文本正文 / 挂·摘角色进栈：一次聚焦编辑算一步，记旧值，原来没有的键撤… | W5 | C | main（W0–W4 合入后）；依赖 nodes-batch-ops、undo-node-create-move、undo-shortcuts-ui、undo-stack | — | — | — |
| rail-drag-assets | 左栏素材格拖进画布：落空白建导入式产物节点，落配置节点弹「当参考 / 替换首帧 / 当… | W5 | D | main（W0–W4 合入后）；依赖 media-import-service、menu-split、narrative-splice、stage-drop-target、undo-adopt-existing、undo-stack | — | — | — |
| tc-take-edge-follow | 下游 data 边跟着当前 take 走（设为当前 / 没固定时来了新 take，一个… | W5 | E | main（W0–W4 合入后）；依赖 current-take、gen-inputs-snapshot、tc-batch-slot-set-current、tc-set-current、undo-stack | — | — | **TC-Q1 → A**（选 B 则本片作废） |
| snapping | 拖动吸附（网格 24 + 对象参考线）+ Ctrl/⌘ 原样放下 + 两个开关 | W6 | A | main（W0–W5 合入后）；依赖 canvas-view-split、group-drag、menu-split、undo-node-create-move | — | — | — |
| cm-edge-menu | 连线右键菜单 + 中点工具条；选中连线时 Del 删线 | W6 | B | main（W0–W5 合入后）；依赖 canvas-view-split、esc-ladder、menu-split、narrative-splice、nodes-batch-ops、undo-adopt-existing、undo-edges、undo-stack | — | — | — |
| cm-delete-bridge | 删链中间的镜时前后两镜自动接上 | W6 | C | main（W0–W5 合入后）；依赖 menu-split、narrative-splice、nodes-batch-ops、undo-adopt-existing、undo-stack | — | — | CM-W1 → A |
| undo-lanes | 泳道操作进栈：新建 / 改名 / 改风格 / 排序 / 改厚 + 解散（节点留下）/ … | W6 | D | main（W0–W5 合入后）；依赖 canvas-view-split、lane-ops-core、undo-adopt-existing、undo-shortcuts-ui、undo-stack | — | — | — |
| export-records-recording | 拼接导出和交付完成或失败时各写一条导出历史（取消不写） | W6 | E | main（W0–W5 合入后）；依赖 export-records-table | — | — | — |
| export-tab-history | 导出标签重做：「新导出」五格 + 「导出历史」列表 | W6 | E | main（W0–W5 合入后）；叠在 export-records-recording 之后；依赖 export-records-table、menu-split | — | — | — |
| tc-stale-marks | 过期标记：只比当前 take 的快照；成片卡「已过期」+ 原因卡 + 重新生成 约 $… | W7 | A | main（W0–W6 合入后）；依赖 current-take、gen-inputs-snapshot、menu-split、node-cost、tc-take-edge-follow | — | — | TC-Q3 → C |
| cm-drag-insert-narrative | 拖到叙事线上插一镜 | W7 | B | main（W0–W6 合入后）；依赖 canvas-view-split、group-drag、narrative-splice、nodes-batch-ops、snapping、undo-adopt-existing、undo-stack | — | — | CM-W4 → B |
| canvas-clipboard-core | 应用内剪贴板与快照改写（纯函数）：选区 → 快照，粘贴时换新 id、剥掉选区外引用、跨… | W7 | C | main（W0–W6 合入后）；依赖 current-take、gen-inputs-snapshot、multi-select-core | — | — | UC-Q4 → A |
| clipboard-paste | Ctrl C / X / V 复制·剪切·粘贴节点（同画布 / 同项目别的画布 / 别… | W7 | C | main（W0–W6 合入后）；叠在 canvas-clipboard-core 之后；依赖 canvas-capsule、esc-ladder、media-import-service、menu-split、multi-select-core、nodes-batch-ops、undo-adopt-existing、undo-shortcuts-ui、undo-stack | — | — | — |
| cm-lane-menu | 泳道标题栏右键菜单 | W7 | D | main（W0–W6 合入后）；依赖 canvas-view-split、cm-edge-menu、lane-ops-core、menu-split、multi-select-core、undo-lanes | — | — | — |
| lone-alt-menubar | 单独按下再松开 Alt 聚焦菜单栏（Windows） | W7 | E | main（W0–W6 合入后）；依赖 win-menubar | — | — | — |
| mac-platform-menubar | macOS 系统菜单栏 PlatformMenuBar（同一张动作表；⌘Q 走有序退出） | W7 | E | main（W0–W6 合入后）；叠在 lone-alt-menubar 之后；依赖 app-action-table、help-actions、win-menubar | — | — | — |
| node-disabled-flag | 节点停用 / 启用 | W8 | A | main（W0–W7 合入后）；依赖 esc-ladder、menu-split、nodes-batch-ops、tc-stale-marks、undo-params、undo-stack | — | — | CM-W2 → A；KM-Q4 → B |
| align-distribute-arrange | 对齐 · 分布 · 排布 · 整理叙事链 | W8 | B | main（W0–W7 合入后）；依赖 canvas-capsule、esc-ladder、menu-split、multi-select-core、nodes-batch-ops、undo-adopt-existing、undo-node-create-move、undo-stack | — | — | — |
| wrap-in-lane | Ctrl G 包成泳道 / Ctrl Shift G 移出泳道 | W8 | C | main（W0–W7 合入后）；依赖 app-action-table、cm-lane-menu、esc-ladder、lane-ops-core、menu-split、multi-select-core、undo-adopt-existing、undo-lanes、undo-node-create-move、undo-shortcuts-ui、undo-stack | — | — | Sel-Q5 → B |
| clipboard-text-paste | 从别的软件粘贴文字 → 文本节点；文字指纹对得上 → 按节点粘贴；长段落给「按剧本拆镜… | W8 | D | main（W0–W7 合入后）；依赖 canvas-capsule、canvas-clipboard-core、clipboard-paste、naming-shot-unify、undo-stack | — | — | UC-Q5 → A |
| job-timing | 任务计时旁表 + 任务弹层显示「已用 / 排队 / 用时」 | W8 | E | main（W0–W7 合入后）；依赖 duration-format | — | — | — |
| canvas-find-bar | 画布内查找 Ctrl/⌘ F：工具条下方的查找条，↵ / Shift ↵ 循环跳转，命… | W9 | A | main（W0–W8 合入后）；依赖 app-action-table、canvas-view-split、esc-ladder、media-import-service | — | — | — |
| batch-run-planner | 批量运行计划（纯函数） | W9 | B | main（W0–W8 合入后）；依赖 current-take、node-cost、node-disabled-flag、tc-stale-marks | — | — | TC-Q4 → A；TC-Q8 → A |
| job-eta | 按 provider 历史估算耗时 | W9 | B | main（W0–W8 合入后）；叠在 batch-run-planner 之后；依赖 duration-format | — | — | — |
| dep-drop-pasteboard | 引入 desktop_drop + pasteboard，封装系统剪贴板读图接口 | W9 | C | main（W0–W8 合入后） | — | desktop_drop + pasteboard（待同意） | **IS-Q1 → A** |
| os-drop-paste-image | 从系统拖入文件 + Ctrl V 粘贴剪贴板图片 → 无源配置的导入产物节点 | W9 | C | main（W0–W8 合入后）；叠在 dep-drop-pasteboard 之后；依赖 canvas-capsule、clipboard-paste、clipboard-text-paste、import-media-command、media-import-service、stage-drop-target | — | 用 dep-drop-pasteboard 引入的两包 | **IS-Q1 → A** |
| multi-select-inspector | 多选检查器 | W9 | D | main（W0–W8 合入后）；依赖 multi-select-core、node-cost、node-disabled-flag、nodes-batch-ops、undo-params、undo-stack | — | — | — |
| rail-drag-characters | 角色行拖到图像 / 视频配置：追加进 character_ids，超配额按 ref_i… | W9 | E | main（W0–W8 合入后）；依赖 canvas-capsule、rail-drag-assets、stage-drop-target、undo-params | — | — | — |
| outline-rename-menu | 大纲行双击就地改名（写 nodes.label，一步撤销）+ 右键弹节点右键菜单原样 | W9 | E | main（W0–W8 合入后）；叠在 rail-drag-characters 之后；依赖 menu-split、node-disabled-flag、undo-stack | — | — | — |
| batch-run-executor | 批量运行执行器 | W10 | A | main（W0–W9 合入后）；依赖 batch-run-planner、gen-inputs-snapshot、job-timing、tc-take-edge-follow | — | — | **TC-Q1 → A** |
| next-shot | 新建下一镜：createNextShot 一个函数给 Ctrl→ / ⌘→ 与拖线菜单… | W10 | B | main（W0–W9 合入后）；依赖 canvas-capsule、esc-ladder、menu-split、undo-node-create-move、undo-stack | — | — | **KM-Q1 / GC-N3 → GC-N3 的 A** |
| tc-next-shot-first-frame | 节点右键「当下一镜的首帧 ›」 | W10 | C | main（W0–W9 合入后） | — | — | TC-Q7 → A |
| script-tables | 剧本两张表：script_documents + script_paragraphs（… | W10 | D | main（W0–W9 合入后）；依赖 export-records-table | v10 | — | — |
| system-notifications | 窗口在后台时发系统通知 | W10 | E | main（W0–W9 合入后）；依赖 duration-format、job-timing | — | local_notifier（待同意） | **新依赖 local_notifier**；SE-Q1 → A |
| batch-run-dialog | 运行对话框与全部入口 | W11 | A | main（W0–W10 合入后）；依赖 app-action-table、batch-run-executor、batch-run-planner、canvas-capsule、duration-format、esc-ladder、job-eta、node-cost、node-disabled-flag、tc-stale-marks | — | — | TC-Q5 → C；CM-W5 → A |
| node-menu-append-chain | 节点右键补「新建下一镜 Ctrl→」与「加入叙事链末尾」（多选按位置依次接上，一个事务… | W11 | B | main（W0–W10 合入后）；依赖 canvas-capsule、esc-ladder、menu-split、narrative-splice、next-shot、undo-edges | — | — | KM-Q1 / GC-N3 → A；N5 → A |
| result-inspector-align | 产物检查器三处对齐：节点头走 ARB、片长统一格式、图标换成图标集 v1 | W11 | B | main（W0–W10 合入后）；叠在 node-menu-append-chain 之后；依赖 duration-format、multi-select-inspector、naming-shot-unify、tc-set-current | — | — | — |
| script-import | 导入剧本写段落、接到链尾、估时长写进镜头 | W11 | C | main（W0–W10 合入后）；依赖 clipboard-text-paste、duration-format、naming-shot-unify、script-tables、undo-node-create-move、undo-stack | — | — | R3 → B |
| mention-token-core | `@{角色 id}` 记号纯函数层，接上生成、项目包导入与跨项目粘贴 | W11 | D | main（W0–W10 合入后）；依赖 batch-run-executor、canvas-clipboard-core、clipboard-paste、clipboard-text-paste、gen-inputs-snapshot | — | — | **IS-Q3 → A** |
| f6-notification-region | F6 跳到通知区 | W11 | E | main（W0–W10 合入后）；依赖 app-action-table、esc-ladder、system-notifications | — | — | — |
| cm-multi-select-menu | 多选右键菜单（选中 ≥2） | W12 | A | main（W0–W11 合入后）；依赖 align-distribute-arrange、batch-run-dialog、cm-delete-bridge、menu-split、multi-select-core、node-cost、node-disabled-flag、wrap-in-lane | — | — | CM-W5 → A；**横截轴对齐口径与 W8 冲突，待拍板** |
| toast-category-mute | 通知按类型开关（生成完成 / 导出完成 / 失败 / 撤销 / 一般） | W12 | B | main（W0–W11 合入后）；依赖 f6-notification-region、system-notifications、undo-shortcuts-ui、undo-stack | — | — | N1 → A；N3 → A |
| rail-script-panel | 左栏剧本页（P1）：原文逐段对到镜头 | W12 | C | main（W0–W11 合入后）；依赖 duration-format、menu-split、script-import、script-tables | — | — | R4 → A |
| prompt-bar-mention-ui | 提示词条里的 @角色补全 | W12 | D | main（W0–W11 合入后）；依赖 esc-ladder、mention-token-core | — | — | **IS-Q3 → A** |
| locate-in-gallery | 节点右键「在画廊中定位」 | W12 | E | main（W0–W11 合入后）；依赖 current-take、help-actions、menu-split | — | — | — |
| selection-toolbar | 选中后浮出的工具条 | W13 | A | main（W0–W12 合入后）；依赖 align-distribute-arrange、batch-run-dialog、canvas-view-split、cm-multi-select-menu、group-drag、marquee-select、menu-split、multi-select-core、node-cost、node-disabled-flag、tc-next-shot-first-frame、wrap-in-lane | — | — | Sel-Q3 → B |
| outline-drag-reorder | 大纲拖行改叙事顺序（只在本组内放，越组回弹） | W13 | B | main（W0–W12 合入后）；依赖 batch-run-dialog、narrative-splice、outline-rename-menu、undo-stack | — | — | O1 → A |
| script-import-characters | 剧本导入识别角色：已有角色名挂到镜头，划选「设为角色」导入时新建 | W13 | C | main（W0–W12 合入后）；依赖 rail-script-panel、script-import、script-tables | — | — | R1 → B |
| script-panel-repair-actions | 剧本面板补全动作：「重建这一镜」「用镜头备注拼出剧本」头部「追加…」 | W13 | C | main（W0–W12 合入后）；叠在 script-import-characters 之后；依赖 narrative-splice、rail-script-panel、script-import、script-tables | — | — | R4 → A；R3 → B |
| create-menu-pick-recent | 新建菜单：「最近用过」「模型」两组 + 带载荷的 CreateMenuPick | W13 | D | main（W0–W12 合入后）；依赖 cm-edge-menu、duration-format、help-actions、menu-split、next-shot | — | — | — |
| sequence-locate-regenerate | 序列里右键「在画布中定位」/「在画布中定位并重生成」 | W13 | E | main（W0–W12 合入后）；依赖 current-take、help-actions、menu-split、node-cost | — | — | — |
| note-variant | 便签（text 节点 variant = note） | W14 | A | main（W0–W13 合入后）；依赖 app-action-table、canvas-find-bar、canvas-view-split、create-menu-pick-recent、esc-ladder、menu-split、naming-shot-unify | — | — | **IS-Q5 → A** |
| panel-resize | 左面板与检查器拖边调宽（舞台至少留 480） | W14 | B | main（W0–W13 合入后）；依赖 rail-script-panel | — | — | P1 → A |
| assets-hover-preview | 素材格悬停 400ms 出大预览，贴面板右沿外；视频静音循环播前 6 秒 | W14 | C | main（W0–W13 合入后）；依赖 duration-format | — | — | — |
| character-kind | 角色分 角色 / 物品 / 场景 | W14 | D | main（W0–W13 合入后）；依赖 export-records-table、prompt-bar-mention-ui、script-tables | v11 | — | C1 → A |
| export-in-task-popover | 导出 / 交付进任务弹层 | W14 | E | main（W0–W13 合入后）；依赖 batch-run-executor、duration-format、export-records-recording、job-timing | — | — | SE-Q2 → A |
| delivery-clips-tab | 交付面板「片段」页签：只读镜头表，点一行播放头跳到那一镜 | W14 | E | main（W0–W13 合入后）；叠在 export-in-task-popover 之后；依赖 duration-format | — | — | — |
| text-inline-edit | 双击文本 / 便签卡就地编辑 | W15 | A | main（W0–W14 合入后）；依赖 canvas-find-bar、canvas-view-split、esc-ladder、note-variant、undo-params、undo-shortcuts-ui | — | — | — |
| collapse-all-panels | Ctrl Shift \\ / ⌘⇧\\ 一起收起左面板和检查器 | W15 | B | main（W0–W14 合入后）；依赖 app-action-table、esc-ladder、panel-resize | — | — | — |
| script-characters-row | 剧本面板「剧中角色」：已有角色实心 chip，虚线候选可新建 / 关联 / 忽略，原文… | W15 | C | main（W0–W14 合入后）；依赖 character-kind、menu-split、rail-script-panel、script-import-characters、script-panel-repair-actions、script-tables | — | — | R1 → B |
| character-usage-links | 角色「被引用」可点：跳到引用它的节点 | W15 | D | main（W0–W14 合入后）；依赖 character-kind、menu-split、sequence-locate-regenerate | — | — | — |
| delivery-history-tab | 交付面板「历史」页签：本画布的交付记录、打开文件夹、跳到导出标签看全部 | W15 | E | main（W0–W14 合入后）；依赖 delivery-clips-tab、export-records-recording、export-records-table、export-tab-history | — | — | SE-Q3 → A |
| image-zip-export | 图片 ZIP 导出：每镜选定的图片产物 + metadata.json | W15 | E | main（W0–W14 合入后）；叠在 delivery-history-tab 之后；依赖 current-take、export-records-recording、export-records-table、export-tab-history | — | — | — |
| note-heading-style | 便签两档字号（正文 / 标题） | W16 | A | main（W0–W15 合入后）；依赖 canvas-view-split、note-variant、text-inline-edit | — | — | **IS-Q5 → A**；N6 → A |
| template-core | 模板核心：画布 / 选中 → 模板骨架，插入换新 id、落到视口中心、单事务；内置模板… | W16 | B | main（W0–W15 合入后）；依赖 canvas-capsule、current-take、gen-inputs-snapshot、mention-token-core、multi-select-core、undo-stack | — | — | R6 → A |
| toast-corner | 通知卡位置五选一（跟随系统 / 四个角） | W16 | C | main（W0–W15 合入后）；依赖 toast-category-mute | — | — | N2 → A |
| assets-gallery-import-origin | 导入的素材：「导入」小标、原文件名、来源筛选 | W16 | D | main（W0–W15 合入后）；依赖 assets-hover-preview、media-import-service | — | — | — |
| export-one-click | 「导出视频」改成分体按钮：主体按上次设置一键导出，▾ 打开现有对话框 | W16 | E | main（W0–W15 合入后）；依赖 export-records-table、toast-category-mute | — | — | E1 → A |
| rail-templates-page | 左栏模板页（内置）：示意卡 + 悬停展开「插入当前画布 / 用它新建画布」；新建菜单与… | W17 | A | main（W0–W16 合入后）；依赖 rail-script-panel、template-core | — | — | R7 → B；R6 → A |
| script-reimport-diff | 重新导入剧本逐段比对（同段沿用原镜、新段建镜、删掉的段标出） | W17 | B | main（W0–W16 合入后）；依赖 duration-format、narrative-splice、next-shot、rail-script-panel、script-import-characters、script-import、script-panel-repair-actions、script-tables | — | — | R2（做不做）→ 做 |
| canvas-minimap | 小地图（M / 缩放条末格开合，全局记忆） | W17 | C | main（W0–W16 合入后）；依赖 canvas-capsule、canvas-find-bar、canvas-view-split、esc-ladder、toast-corner | — | — | — |
| cm-knife-cut | Alt + 拖空白切线 | W17 | D | main（W0–W16 合入后）；依赖 canvas-view-split、esc-ladder、lone-alt-menubar、marquee-select、narrative-splice、undo-adopt-existing、undo-edges、undo-stack | — | — | CM-W3 → A（Alt + 拖） |
| shortcuts-page-v2 | 设置「快捷键」页分组（单键 / Esc 阶梯 / 组合键 / 指针 / 弹层内部，每行… | W17 | E | main（W0–W16 合入后）；依赖 app-action-table、canvas-find-bar、esc-ladder、f6-notification-region、group-drag、lone-alt-menubar、marquee-select、note-variant、prompt-bar-mention-ui、snapping、text-inline-edit、win-menubar | — | — | — |
| more-dropdown-panel | 工具条「更多」改用菜单面板 | W18 | A | main（W0–W17 合入后）；依赖 align-distribute-arrange、app-action-table、canvas-find-bar、canvas-minimap、cm-knife-cut、import-media-command、menu-split、naming-shot-unify、rail-templates-page | — | — | 切线手势 → A |
| create-menu-notes-characters | 新建菜单加便签 / 角色组 | W18 | B | main（W0–W17 合入后）；依赖 character-kind、create-menu-pick-recent、menu-split、note-variant、rail-templates-page | — | — | **IS-Q5 → A**；N4 → A |
| back-to-content-chip | 「回到内容」胶囊 | W18 | C | main（W0–W17 合入后）；依赖 canvas-find-bar、canvas-minimap | — | — | — |
| node-library-section | 节点库（模板页顶部）：六项「图像配置 · 视频配置 · 文本 · 镜头 · 便签 · … | W18 | D | main（W0–W17 合入后）；依赖 note-variant、rail-templates-page | — | — | R7 → B |
| node-library-drag-recents | 节点库拖进画布 +「最近用过 · 本项目」+ 提示词预设组 | W18 | D | main（W0–W17 合入后）；叠在 node-library-section 之后；依赖 create-menu-pick-recent、stage-drop-target | — | — | R7 → B |
| storyboard-pdf-export | 分镜 PDF 导出（每页 6 镜，打包中文字体） | W18 | E | main（W0–W17 合入后）；依赖 export-records-recording、export-tab-history | — | pdf + 打包 NotoSansSC 静态 .ttf（待同意） | **SE-Q4 → A** |
| tool-lock | 工具锁（Q / 双击工具键，点放建节点） | W19 | A | main（W0–W18 合入后）；依赖 cm-knife-cut、esc-ladder、marquee-select、more-dropdown-panel、naming-shot-unify、note-variant | — | — | IS-Q4 → A（做） |
| lane-collapse-persist | 泳道折叠落库（style_lanes.collapsed，随项目包走） | W19 | B | main（W0–W18 合入后）；依赖 character-kind、cm-lane-menu、export-records-table、lane-ops-core、multi-select-core、script-tables、undo-lanes、wrap-in-lane | v12（待 Sel-Q6） | — | **Sel-Q6 → C** |
| my-templates-table | 「我的模板」：新表 canvas_templates（应用级）+ 存为模板… + 右键… | W19 | C | main（W0–W18 合入后）；叠在 lane-collapse-persist 之后；依赖 rail-templates-page、template-core | v13（待 R5） | — | **R5 → A** |

## 二、设计缺口（5 份 `_gaps-*.md` 合并去重，按画板分组）

格式：功能 · 缺什么 → 派工单里的暂定做法（切片）。没写「暂定」的，派工单里也没定，要回到画板补。已经解决、或因跨批统一而过时的条目已删；原文仍留在各 `_gaps-*.md` 里，并标了「已解决 / 已过时」。

### 先要设计确认的跨板冲突
- ContextMenus vs Selection · 横截轴对齐：ContextMenus 写「跨道置灰」，Selection 写「各自夹在自己道的带里」。W8 align-distribute-arrange 按 Selection 做（不置灰、夹带），W12 cm-multi-select-menu 按 ContextMenus 做（跨道置灰）→ **两片口径相反，W12 之前要拍板**。
- ContextMenus vs Selection · 分布：ContextMenus 是单独一行「分布 ›」，Selection 并进「对齐 ›」→ 暂定按 Selection（align-distribute-arrange）。
- ContextMenus vs Selection · 吸附时机：ContextMenus 写松手时取整，Selection 画的是拖动中出参考线 → 暂定按 Selection（snapping）。
- GapsCanvas N1 vs KeyMap Q1 · 下一镜继承哪些键：两板在镜头语言五键和批量数上说法相反 → 暂定按 KeyMap Q1 的 A，不继承镜头语言 / seed / prompt / shot_notes / 产物 / 首尾帧。改判只需动 `kNextShotInheritedKeys` 和两条测试（next-shot）。
- RailScript vs GapsPanels · 剧本估时：RailScript 板上的数字与「只数汉字、4 字 / 秒、向上取整、至少 2 秒」对不上（~5 应为 ~4，合计 ~14 应为 ~13）；GapsPanels 每行不带「~」→ 暂定按算法算，每行和合计都带「~」（script-import / rail-script-panel）。
- GapsPanels vs 现有 ARB · 产物检查器叫法：板上写「图像」，现有中文是「图片」→ 要定一个（result-inspector-align）。
- ImportSearch / GapsCanvas / ShellExport · 新建菜单里便签的位置：样稿是「文本 · 便签 · 镜头」，节点库、工具锁、工具条是「文本 · 镜头 · 便签」→ 暂定便签排在镜头之后（note-variant / create-menu-notes-characters）。
- RailScript vs GapsCanvas ·「最近用过」条数：一张写 5，一张写 3 → 定死 3（create-menu-pick-recent）。
- RailScript vs TakesCost · 模板里的 gen_inputs：一张写换 id、剥掉模板外的引用，一张写出现就剥 → 按 TakesCost 一律剥（template-core）。
- GapsPanels · 通知按类型开关的默认值：样稿画的「一般提示」是关，派工单全开 → 待确认（toast-category-mute）。
- ShellExport · 导出失败与「导出完成」卡：导出失败只在对话框内联报错，不出卡，所以没有系统通知，也没法按类型静音；交付侧没有完成卡；导出卡主按钮实际是「复制路径」，不是「打开文件夹」（system-notifications / toast-category-mute）。
- ShellExport · 交付行「重新导出 / 重试」：板上写「用快照重走」，自动重跑要么偷改项目交付设置，要么复制一份交付拼装逻辑 → 暂定跳到序列标签的交付面板，由用户确认（export-tab-history）。
- ShellExport · 一键导出 ▾：图上画了两项小菜单，规则写「▾ = 现有对话框」→ 暂定按规则；「上次：…」放进主体按钮的 tooltip（export-one-click）。
- GapsCanvas · 下一镜第三个入口：板上说检查器里已有「下一镜」，实际没有 → 改成节点右键（node-menu-append-chain）；「↵ 后光标进提示词条」要改 canvas_prompt_bar.dart，没人拥有，本批不做（next-shot）。
- ShellExport · F6 与 ⌘K 同层：⌘K 绑在 Navigator 里，通知区持焦时 ⌘K 不生效（f6-notification-region）。
- ImportSearch · 系统拖入浮层：desktop_drop 松手前拿不到文件列表 → 浮层只写「松手导入」，数字放到松手后的通知卡（os-drop-paste-image）。
- Selection · 多选检查器：视频配置画了「画幅 / 种子」，单选视频检查器没有 → 只列模型和时长（multi-select-inspector）。
- TakesCost · 内置「短剧示例」：板上 4 镜，代码是 2 镜 → 以代码为准（template-core）。
- GapsPanels · toast 位置：板上写「40 标题栏、43 导航条」，代码是标题栏 31 + 标签栏 35、左栏宽 43 → 按代码常量取（toast-corner）。

### KeyMap
- Esc 阶梯第 6 档：连线、工具锁、平移同时生效时先退哪个 → 暂定连线 > 工具锁 > 平移，与现状相反（esc-ladder）。
- Ctrl 0：已经是 100% 时按下 → 不动、不提示（zoom-reset-100）。
- 重做键显示：画板写 ⇧⌘Z，现有格式化输出 ⌘⇧ → mac 统一改成 Apple 顺序 ⌃⌥⇧⌘，改现有断言（undo-shortcuts-ui）。
- 重做「每平台一个主键」与现有双注册冲突 → 注册 ⇧⌘Z 和 Ctrl Y，mac 上 Ctrl Y 也生效但不展示（undo-shortcuts-ui）。
- 右键拖 / 中键拖平移的光标没画 → 沿用平移工具光标（marquee-select）。
- 快捷键页：段头、范围列、Esc 阶梯的版式没画 → 照 API 密钥页的表形；「单独 Alt」「文字让位」不单列；弹层内部键表在设置侧维护常量表，弹层改键时测试不会变红（shortcuts-page-v2）。
- 就地编辑没有对应的 Esc 档 → 编辑框自己吃 Esc（text-inline-edit）。
- Ctrl G / Ctrl Shift G 没进让位表 → 交给输入框（wrap-in-lane）。

### Selection
- 框选：触屏 / 触控笔只有鼠标左键起框；Shift 和 Ctrl 同按时反选优先；起框清掉选中的连线，Esc 不恢复；离视口边 24px 内自动平移，每帧最多 12；Esc 后指针仍按着不重新起框；拖框中节点集刷新就重算，Esc 恢复时滤掉已删的 id；「已选 N」芯片在小框 / 贴边时放哪待画（marquee-select）。
- 命中判定：框正好贴着卡片边算碰到；选区包围盒跳过折叠道里的卡（multi-select-core）。
- 批量删除失败 → 沿用 nodeDeleteFailed，选中不恢复（nodes-batch-ops）。
- 整组拖：换道提示挂在抓住的卡上方（板上画在舞台右上）；整组移出所有泳道的文案没画；Shift 锁累计位移的主分量；折叠道里的卡不带（group-drag）。
- 吸附：网格底画在屏幕空间、吸附按世界坐标，视觉上对不齐，要么改网格底，要么改文案；对象吸附优先于网格；整组按抓住的卡吸附；半透明虚线参考线的含义没写；打勾项点完后菜单关闭（snapping）。
- 对齐 / 排布：名下产物按 result_placement 跟着排；竖向道沿主轴排；数量不够弹胶囊（align-distribute-arrange）。
- 包成泳道：跨道时取 sortOrder 最大的那条；多道来源用复数文案；没有选中弹胶囊（wrap-in-lane）。
- 多选检查器：清单行不可点；停用节点写「已停用」、不计价；「历史」页沿用空态；有节点在生成时整组置灰（multi-select-inspector）。
- 浮动工具条：单选文本 / 镜头 / 便签按单选配置处理；选区在视口外不出、顶出时夹边 16、不避让提示词条；右键菜单开着时隐藏（selection-toolbar）。
- 泳道折叠落库写失败 → 回滚 + warn 日志，不出卡（lane-collapse-persist）。

### UndoClipboard
- 撤销卡上撤的那步不在栈顶 → 不进重做栈；在栈顶时等同 Ctrl Z（undo-stack）。
- 切到同项目另一张画布 → 算关闭，丢栈（undo-stack）。
- 栈空按 Ctrl Z、撤销进行中再按 → 都不提示；撤销失败出 undoFailed 错误卡，「这一步已无法撤销」走胶囊（undo-stack / undo-shortcuts-ui）。
- ⌘K 的撤销 / 重做拿不到步名 → 只写通用文案（undo-shortcuts-ui）。
- 重做图标：图标集 v1 没有镜像撤销字形 → 留空，待补字形（undo-shortcuts-ui）。
- 撤销删除节点时原泳道已删 → 照原样复原 lane_id（undo-adopt-existing）。
- 撤销新建时任务还在跑 → 胶囊写「…· 任务仍在运行」（undo-node-create-move）。
- 改参数写库失败 → 不进栈，重试成功也不补；文本会话开着又改下拉算两步（undo-params）。
- 撤销连线时线已被改过角色 → 按栈序，找不到线就丢步；按「源 + 目标 + role + data」找边（undo-edges / tc-take-edge-follow）。
- 泳道进栈：「改厚」算一步，切换方向不进栈；排序中有道被删时怎么合并没画（undo-lanes）。
- 复制粘贴：右键「粘贴」对齐包围盒左上角，指针在画布上时对中心；生成中、没有产物的 result 跳过；包围盒没算泳道锚定位移，缩放离 1 远时略偏；源文件已不在按复制失败处理；剪切 · 复制 · 复制一份同组；只在跨项目去掉了角色引用时出胶囊；剪切卡写「已剪切 N 个节点」（canvas-clipboard-core / clipboard-paste）。
- 粘贴文字：空 / 全空白 / 读取失败出胶囊；「长段落」= 默认拆分 ≥2 块；拆完保留原文本节点，粘贴和拆镜是两步；拆镜落点会被 W11「接链尾」忽略（clipboard-text-paste）。

### ContextMenus
- 插入一镜让位：一格 = 卡片主轴尺寸 + 64，方向跟 LaneDirection（narrative-splice）。
- 删除并接上：多段删除时部分接上、部分因分叉没接，卡片文案没画；「删除（不接上）」放删除组第二行，接不上时置灰；卡片标题沿用「节点已删除」；段前段后本来就连着时不重复建（narrative-splice / cm-delete-bridge）。
- 解散泳道：折叠的道按展开厚度算；后面的道整体前移没画（lane-ops-core）。
- 删除泳道和内容：「有生成中任务」的确认框文案没画；撤销后被取消的任务不会恢复，写进确认框（lane-ops-core / undo-lanes）。
- 空白处菜单顺序：画板「粘贴」在「导入媒体」前，menu-split 把粘贴放在第 30 组 → 待 clipboard-paste 对齐（import-media-command）。
- InkMenuPanel 置灰项「悬停说原因」：字段已定为 `disabledReason`，悬停延迟和样式待画（help-actions）。
- 节点菜单分组「做 | take | 归类 | 定位 | 停用 · 删除」要挪 menu_registry 现有行，切片只能追加 → 主 Agent 合入时统一调（node-menu-append-chain）。
- 停用：只有图像 / 视频配置可停用；停用中被单独生成时按 job 报状态；成功不提示（node-disabled-flag）。
- 拖到叙事线插一镜：停在松手处；成功 / 失败反馈没画；拖动中 Esc 没写（cm-drag-insert-narrative）。
- 连线菜单：「插入节点…」只列镜头 / 图像配置 / 视频配置；中点工具条屏幕尺寸恒定；五种置灰原因没画；线型小样用 8px 色点（cm-edge-menu）。
- 泳道菜单：折叠道第四行写「展开」；折叠道「选中内容」先展开；空道置灰写「0 个」；改名失焦 = 保存；被右键的标题栏加 accent 描边（cm-lane-menu）。
- 多选菜单：顶行「已选 3 · 约 $0.42」是标题还是可点项没说；可生成数为 0 时「生成」置灰（cm-multi-select-menu）。
- 切线：红线宽 1.5、虚线 4/3；Alt + 单击按单击空白处理；Flutter 没有剪刀光标、图标集也没有剪刀 → 用 `SystemMouseCursors.precise`（cm-knife-cut / more-dropdown-panel）。

### TakesCost
- 固定的 take 被删 → 不清 pinned_result_id，撤销删除后自动回来（current-take）。
- 设为当前：没有「取消固定」入口，最新那条没法固定；当前描边和选中描边同为 accent → 选中优先；画布没开时新 take 到达，通知写不出「当前仍是 take N」；写库失败复用通用文案（tc-set-current）。
- 花费：节点菜单「生成」没有明细浮层；单价 0 一律算「价格未知」；视频没选时长写「—」；置灰时只出原因（node-cost）。
- gen_inputs：文本入边记 text；角色映射不到整份剥掉（gen-inputs-snapshot）。
- 时长格式：满 1 小时写 h:mm:ss；导入对话框汇总行「约 9 秒」算整句文案（duration-format）。
- 批量 slot：「已选但不是当前」的格子、孤儿 result 的 slot、对比浮层开着时撤销键归谁、历史页 slot 条谁画，都没画（tc-batch-slot-set-current）。
- 线跟当前 take：img2img 回连自己的线不挪；新当前已连同一目标时旧线软删；删掉当前 take 后下游线去哪、挪线要不要告诉用户，没说（tc-take-edge-follow）。
- 过期标记：原因卡只画了 4 种行，其余几行的写法是补的；点「当前 take 已过期」做什么、「重新生成」在缺 Key / 空提示词 / 生成中 / 价格未知时的样子，都没画；文本正文、角色描述改了判不出来（快照里没有）（tc-stale-marks）。
- 批量运行：只跑过期模式下最新的节点不列；「全部」模式写「重新生成」；缺尾帧跳过、缺参考照跑；在跑写「生成中 · 跳过」；上游重跑带下游；成环按链序；预计总耗时怎么折算并发、估时不区分批量数和时长、空态 / 序号 / 组头「运行这组」/ 无可生成反馈都没画；标题栏放不下分段切换 → 挪到正文第一行（要严格照画板得给 InkOverlayDialog 加 titleTrailing）；从选中集打开一律「全部」；批次只放内存；任务弹层的批次头和三种等待 / 失败行没画；模型不支持首帧时生成侧会抛 `first_frame_unsupported`，批量计划不预判（batch-run-*）。
- 当下一镜的首帧：链尾只有「新建下一镜（视频配置）」；没成片时父项置灰；镜头无备注置灰；后面已接视频配置就改接它；模型不支持首帧的提示、接好后的反馈、导入图片出不出这一项，都没画（tc-next-shot-first-frame）。

### ImportSearch
- 导入媒体：复制中不能取消；不设大小和数量上限；缩放 < 0.6 时复制中的卡没画；右键入口落在右键点；多文件按文件名排序、最多 4 列；新节点替换选中、相机不动；文件选择框打不开时加一个文案键（media-import-service / import-media-command）。
- 舞台拖放：Draggable 不认 Esc，本批不做；拖到空白只高亮泳道；处理器拒收的落点不回调，做不了「放错位置」的提示（stage-drop-target）。
- 素材拖到配置：「替换尾帧」与首帧对称；已连着同一角色置灰「已连着」；解析不出 provider 写「没有可用的模型」；新素材节点放配置左侧一列；只有替换出撤销卡（rail-drag-assets）。
- 角色拖放：拖到空白 / 文本 / 镜头 / 产物、重复挂载、途中角色被删，各一句胶囊（rail-drag-characters）。
- 系统拖入 / 粘贴图片：文件夹、读不到的文件、纯链接各一条跳过理由；Finder 复制文件后 Ctrl V 走拖入同一条路；文件拖到配置卡按空白处理；剪贴板图片节点标题只能是 `clipboard-<时间>.png`（导入请求不收标签）；Windows 上透明 PNG 会变黑底（os-drop-paste-image）。
- 查找条：与舞台顶部其他浮层怎么叠没画；零命中照样降暗、计数写「无结果」；命中在折叠道里先展开；只暗卡片；打字不动相机；组字中 ↵ 只确认组字；mac 文字里的 Ctrl F 留给 emacs（canvas-find-bar）。
- @ 记号：映射不到的角色在全保真项目包里也没有名字，plan 第 3 节对应验收要改写；检查器完整提示词预览、产物检查器、画廊、大纲、⌘K 会露出原始 uuid，需要显示侧 stripToNames；提示词只剩已删角色的记号时「生成」仍可点（mention-token-core）。
- @ 补全：已删角色显示「已删除的角色」；标签只能画样式区间，不是带头像的 chip；弹层在光标上方；`a@b` 不开弹层（prompt-bar-mention-ui）。
- 便签：只画了琥珀一种底色；卡片尺寸、底色选择器没画（note-variant）。
- 便签标题：选中描边 / 空标题占位 / 底色保留 / 缩放 < 0.6 反向放大（note-heading-style）。
- 就地编辑：编辑态用 accent 内描边；紧凑卡不进入（text-inline-edit）。
- 小地图：放在泳道工具栏之上；宽 152（样稿 160 超出避让值）；竖向 / 折叠泳道、选中节点的样子没画；查找条开着时不让位（canvas-minimap）。
- 回到内容：挪到工具条下方 64，与查找条互斥；连线模式下、节点全在折叠道里时不出；动效没画（back-to-content-chip）。
- 工具锁：没锁时按 Q 锁最近点过的工具；锁定中 I / G / T 照常建；占位框为真实卡片大小；锁定中双击空白不开菜单；锁定条可能与查找条重叠（tool-lock）。

### RailScript
- 帮助 ›「检查更新…」的三态没画 → 关弹层、行灰着写「正在检查更新…」、结果走通知卡；非画布标签没有帮助入口，等菜单栏（help-actions）。
- 剧本表：一张画布一份剧本，文档没有标题和软删（script-tables）。
- 剧本导入：链尾在视口外 / 在泳道里 / 落点压卡 → 不动相机、跟链尾同道、不避让（script-import）。
- 剧本面板：「已生成」行标签、「生成中」样式、读库失败态没画（rail-script-panel）。
- 重建这一镜：前后邻居都不在、下一镜已有别的叙事入边、失败提示，没画；拼剧本时空备注、链外镜头怎么排，没画（script-panel-repair-actions）。
- 剧中角色：chip 数字 = 出现段数；「+」和点实心 chip 的动作没画；段行 chip 按已挂 character_ids；候选与已有角色重名、取消勾选、无活动项目态没画（script-characters-row / script-import-characters）。
- 重新导入：入口 / 预览 / 确认文案没画；加一类「改动 · 沿用原镜」（相似度 ≥ 0.6）；「原文已删」只做标记；过期 / 写库失败 / 无变化三态没画；不进撤销栈（script-reimport-diff）。
- 模板插入：追加在已有泳道之后、主轴居中；横向模板插竖向画布自动转向（template-core）。
- 模板页：「内置 | 我的」分段、卡片单击、键盘展开、插入中、新建画布后左栏停哪页，都没画（rail-templates-page）。
- 节点库：与模板卡的分隔、搜索是否也筛模板、全空态、镜头没有单键，没画；拖泳道只能等同按 F；预设行只有恰好选中一个配置节点时可点（node-library-*）。
- 我的模板：存为模板对话框、重名、排序、右键键盘入口、软删清理，没画（my-templates-table）。

### ShellExport
- 菜单栏下拉：宽度与锚点 → CanvasMenuPopover 左上对齐全局点（menu-split）。
- ⌘K 禁用项不显示，只在菜单栏灰着写原因；「更多」下拉项分散在四张板，排序待 more-dropdown-panel 统一（app-action-table）。
- Windows 菜单栏：悬停 / 打开态按 KeyMap altBox；下拉贴 chrome 下沿；行高取 22；没有 job 时「窗口 › 任务」置灰；当前标签用打勾代替圆点；设置浮层开着时能用；「导出项目包…」先登记禁用；Alt F4 的键名可能缺（win-menubar）。
- 单独 Alt：聚焦后点别处 / 点标签没画；对话框盖着时不响应；下拉开着时关下拉（lone-alt-menubar）。
- macOS 菜单：系统菜单没有 Tooltip，做不到「置灰说原因」；只登记带 ⌘ 的键；启动失败页只留应用菜单；对话框盖着时自定义项全灰（mac-platform-menubar）。
- 导出历史表：不进项目包；kind 只有四种，剪映 / FCPXML 归 delivery；交付失败「文件」栏留空（export-records-table）。
- 导出标签：无项目 / 历史空 / 本画布空 / 加载中 / 读取失败 / 来源画布已删六种状态没画；「从历史移除」没有撤销；历史行右键菜单没有键盘入口；跨画布重新导出先切画布（export-tab-history）。
- 任务计时与通知：首次进度前注册表一直是 JobQueued，以计时表为准；排队中取消只写「已取消」；只给成功卡加用时；合并通知标题「N 件事已完成 / · K 个失败」，点开铃铛历史；到点时已回到窗口不发；出处行和 provider 名卡片数据里没有；macOS 上 local_notifier 0.1.x 的权限接口待核对；没有铃铛时 F6 只播报「没有通知」；F6 焦点细节画板没画（job-timing / system-notifications / f6-notification-region）。
- 任务弹层导出行：版式同生成行；终态行不放「打开文件夹」（export-in-task-popover）。
- 片段页签：「尺寸不一致」行写琥珀色第二行；空态没画；当前播放镜沿用 surface5（delivery-clips-tab）。
- 历史页签：失败行写「失败 · 原因」；空态、行数上限没画；「文件夹已不在」没画，且与导出标签的「划掉」规则不一致（delivery-history-tab）。
- 图片 ZIP：对话框沿用 export_video_dialog 骨架；无产物的镜跳过并计数；孤儿 / 导入图按 currentTakeNodeIds 各自成镜（image-zip-export）。
- 分镜 PDF：对话框、页面版式、无镜状态都按建议补了；`package:pdf` 只认 TrueType，plan 写的 `.otf` 要换成静态 `.ttf`（storyboard-pdf-export）。

### GapsCanvas
- 统一叫法：只改节点类型名，不改「开始分镜」这类动作义（naming-shot-unify）。
- 胶囊：可用宽度不到 96 就不画；动作按钮不进 Tab 序，胶囊上写键位（canvas-capsule）。
- 下一镜：锚点在折叠道里照建并展开；连按时上一笔还在写库就丢弃新按键（next-shot）。
- 加入叙事链末尾：全在链上 / 全是文本 / 全是孤儿产物的置灰原因；部分已在链上加「跳过 N 个」；链尾无镜号时写「已接到「名字」之后」（node-menu-append-chain）。
- 新建菜单：「最近用过」只取成功的 job；provider 已删的预设不出；组头、「无 Key」小标、只在打字时出现的组由 create-menu-pick-recent 往 InkMenuPanel 追加可选字段（create-menu-pick-recent）。
- 新建菜单 · 角色组：在全部角色里按名字搜、最多 3 行；无参考图用 characters 图标；新节点用默认名；角色已删时出错误卡（create-menu-notes-characters）。
- 「更多」下拉：右对齐按钮往下弹；一次性切线模式出胶囊「拖过要剪的线 · Esc 退出」，点空白不拖算普通单击（more-dropdown-panel）。
- 在画廊中定位：「已清除筛选」放筛选栏顶、下次改筛选消失；已在视口内不滚；多选置灰；目标刚删时静默（locate-in-gallery）。

### GapsPanels
- 通知按类型开关：静音的类别在铃铛历史里没有视觉区分（toast-category-mute）。
- 通知位置：上方两角镜像进退；没有画布左栏的标签下左角也让出 43（toast-corner）。
- 大纲改名：只做双击，没有 F2 / ↵；上限 200 字；改名中节点被删 / 列表重建 / 被筛掉没画；改名框自己吃 Esc；产物子行不可改名（outline-rename-menu）。
- 大纲拖动排序：筛选有字时禁用；不自动滚动；拖动中 Esc 没画；「借号」行对只拖一行会拆开；分叉点按 narrative-splice 语义（outline-drag-reorder）。
- 面板拖宽：「↔ 280」读数在热区外 8px；左面板 200 宽时内容成不成立没核对；自动收起后变宽不自动展开（panel-resize）。
- 一键收起：检查器收起后没有可见的打开按钮；选中节点不让它回来；无动画（collapse-all-panels）。
- 素材悬停预览：媒体宽 320；尺寸行没有数据来源（GalleryItem 没有宽高）；放不下时翻转、文件丢失、视频打不开，没画（assets-hover-preview）。
- 导入来源：「导入」放在类型组末尾、与图片 / 视频互斥，所以选「图片」时看不到导入的参考图；复制中的不显示（assets-gallery-import-origin）。
- 角色类型：三段选择放名称与描述之间、高 24；组被筛空不画（character-kind）。
- 「M 处引用」：1 处直跳，≥2 处弹列表；有未存改动时问「保存后前往 / 不保存 / 取消」；只改参考图不算未存（character-usage-links）。
- 序列右键菜单：右键不动播放头和选中；价格算不出写「约 —」；「从这一镜播放」要公开 sequence_monitor 的私有 `_play`，不在任何片的归属里，本批不做（sequence-locate-regenerate）。
- 产物检查器：只画了对齐前的样子；图标集缺「图片丢失」「圆圈播放」两个字形，派工单手写了路径，设计源 icons.js 要补，ink_icon_sheet golden 要在 CI 重生成（result-inspector-align）。
- 一键导出：导出进行中整体置灰（export-one-click）。

## 三、plan.md 需要修订的地方（只记录，没改 plan.md）

- 第 0 节说 `CanvasNode` 是 freezed，实际是手写的 `@immutable` 类（`lib/features/canvas/models/canvas_node.dart`）。「写成 extension、不改 canvas_node.dart」的做法照旧。
- 第 0 节说 `delivery_writer_registry.dart` 不存在，实际在 `lib/features/export/models/delivery_writer_registry.dart`（`providers/delivery_writers.dart` 也在）。
- 第 0 节的「注册表例外」要补上：`app_action_ids.dart`、`stage_drop_registry.dart`、`canvas_drag_payload.dart` 的 part 行、`re_export.dart`。
- 第 4 节新依赖：`NotoSansSC-Regular.otf` 改成静态 `.ttf`。
- 第 2 节热点链，按各派工单「允许改的文件」重算后的完整链（加粗的是 plan 漏掉的环节）：
  - canvas_view.dart 骨架：W0 → **W3 marquee-select** → W4 → W6 → **W7 clipboard-paste** → W9 → W13 → **W14 note-variant**
  - stage_edge_layer：W3 → **W5 group-drag** → W6 → **W7 drag-insert** → W14
  - stage_lane_layer：W2 → **W4 stage-drop-target** → W6 → W7
  - stage_overlays：W0 → **W6 snapping**
  - node_drag_delta：**W5 group-drag → W6 snapping → W7 drag-insert**；edge_painter：**W5 → W7**
  - core_canvas_keys：W0 esc-ladder → W0 zoom-reset-100 → W1 capsule → **W6 cm-edge-menu** → W11 run-dialog
  - canvas_menu_request（plan 只写了 host）：**W0 → W5 → W6 → W7 → W12 → W13**；canvas_menu_host 链尾另有 **W18 create-menu-notes-characters**
  - canvas_snackbars：**W3 undo-adopt → W6 cm-delete-bridge → W12 toast-category-mute**
  - ink_menu_panel：**W0 → W3 help-actions → W4 win-menubar → W6 cm-edge-menu → W13 pick-recent → W18 notes-characters**
  - shortcut_catalog：**W0 → W2 undo-shortcuts-ui → W11 f6 → W17 shortcuts-page-v2 → W19 tool-lock**
  - canvas_toolbar：**W1 app-action-table → W14 note-variant → W18 more-dropdown → W19 tool-lock**
  - canvas_tool_actions：W1 → W4 → **W5 undo-edges** → **W6 undo-lanes** → W13
  - canvas_lane_actions：**W2 → W6 undo-lanes → W7 cm-lane-menu**；current_take_controller：**W3 → W4 → W5**
  - canvas_capsule_host：**W1 → W17 canvas-minimap**；escape_ladder.dart：**W0 → W17 cm-knife-cut**（追加 `edgeCut`）
  - inspector_submit_controller：**W5 undo-params → W12 prompt-bar-mention-ui → W15 text-inline-edit**
  - 同一波里没有两片抢同一文件；只有 W19 的 lane-collapse-persist 与 my-templates-table 串行共用 `app_migrations.dart` / `columns.dart`（v12 → v13）。

## 四、仍未解决的问题

1. **横截轴对齐的口径冲突**（W8 align-distribute-arrange 与 W12 cm-multi-select-menu）：前者不置灰、各自夹在自己道的带里，后者跨道置灰。不统一的话，菜单置灰而 Alt 字母快捷键照样能执行。W12 之前要拍板，cm-multi-select-menu 的风险条里写了两种改法。
2. **plan 第 5 节的拍板项**：派工单都按建议写了，还没有你的确认。
   - TC-Q1：W3 tc-set-current 起就按它定撤销命令形状，最迟 W5 前。
   - IS-Q1 + 新依赖 desktop_drop / pasteboard：W9。
   - KM-Q1 / GC-N3：W10。
   - local_notifier：W10。
   - IS-Q3：W11。
   - IS-Q5：W14。
   - SE-Q4 pdf + 字体：W18。
   - Sel-Q6（迁移 v12）与 R5（迁移 v13）：W19。
3. **画板冲突待设计确认**：见第二节第一小节，约 19 条。优先看这几条：下一镜继承键、剧本估时的数字、「图像 / 图片」叫法、通知类别默认值、交付行重跑、F6 与 ⌘K 同层。
4. **@ 记号会露出 uuid**：W12 开始往提示词里写 `@{id}`，但检查器预览、产物检查器、画廊、大纲、⌘K 都没做显示侧转换。需要在 W12 之前加一片 stripToNames，或并进 prompt-bar-mention-ui。另外 generate_gate 缺「提示词里只剩已删角色记号」这条判断。
5. **几件没人负责的改动**：
   - 公开 `sequence_monitor._play`（序列菜单「从这一镜播放」要用）。
   - canvas_prompt_bar：下一镜按 ↵ 后光标进提示词条。
   - InkOverlayDialog 加 titleTrailing 插槽。
   - inspector_submit_controller 加「只落盘、不提交」入口（B8）。
   - 查找条与舞台顶部浮层的叠放（要改 canvas_view）。
   - 图标集补四个字形：重做、图片丢失、圆圈播放、剪刀，并在 CI 上重生成 golden。
6. **合入时由主 Agent 手动做的事**：
   - W6 两片都合入后，删掉 `showCanvasUndoSnack` 的 `onUndo` 分支。
   - 按 node-menu-append-chain 的分组重排 menu_registry 的现有行。
   - 验收 W9 os-drop-paste-image：它改了 W3 的 `canvas_import_actions.dart`（抽出 `importMediaFiles`，已认可），W3 的测试必须原样绿。
   - 合并重复实现：链尾判据（script-import 与 append_to_chain）、能力位判据三处、首帧链尾新建视频配置（tc-next-shot-first-frame 应改走 createNextShot）。
7. **迁移发出前要定的形状**：script-tables（v10）的角色候选只有 candidate / ignored 两种状态。W15 用「candidate 加 character_id」表示「已关联」；如果想要显式的 `linked` 状态，得在 v10 合入前改 W10。v9–v13 的 DDL 合入前都要单独审。
8. **底座能力缺口（已接受降级）**：
   - stage-drop-target 拒收落点时不回调，做不了「放错位置」提示。
   - media-import-service 的导入请求不收标签，剪贴板图片只能叫 `clipboard-<时间>.png`。
   - macOS 系统菜单不能显示置灰原因。
   - Windows 上粘贴透明 PNG 会变成黑底。
9. **有意修改现有 ARB 值的键**（主 Agent 加 ARB 时按改值处理，不是新建）：
   - `settingsShortcutCanvasEscape`：只由 W0 esc-ladder 改，W17 不再改。
   - `settingsShortcutCanvasZoomReset`：W0。
   - `exportVideoDialogHint`：W1 current-take。
   - `batchOverlayHint`：W4。
10. **plan.md 本身需要订正**：见第三节，包括 CanvasNode 不是 freezed、delivery_writer_registry 实际存在、注册表例外清单要补、热点链漏了若干环节、字体要改成 .ttf。
