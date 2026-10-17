# 第二批设计稿 · 执行计划

原有约 110 个切片，合并后剩 98 个，分 20 波（W0–W19），每波 5 个 executor，同一 lane 可以串两片。主要结论：

- **必须先做的地基**：W0 先做三个纯重构（拆 `canvas_view.dart`、拆 `create_node_menu.dart`、快捷键改注册表），否则约 20 个切片会抢同一个文件。
- **最长的串行链是 `node_card.dart`**：11 个切片要改它，决定了总波数。
- **要拍板的 8 件事**见第 5 节，其中 4 件最迟在 W4 / W5 之前要定。

## 0. 前提与校正（我读代码核对过）

**当前状态**
- 本地 `main` 还停在 abbd1f3，`origin/main` 已到 655d1dd，#299 lane-drag 已合入，`canvas_view.dart` 现在 1875 行。所有切片都要从 `origin/main` 起。
- `fix/demo-inspectors` 在 025aeae 已补上检查器的 ARB 键，result-inspector-align 说的「ARB 留在工作树里」的前置已经不存在了。
- `fix/demo-promptbar-sample` 还没合。node-cost 和 prompt-bar-mention-ui 必须排在它后面。

**各切片文件清单里的错误**
- `lib/core/di/` 是一个服务一个文件，没有 `services.dart`。新服务新建 `core/di/<name>.dart`。
- `delivery_writer_registry.dart` 不存在，实际是 `features/export/providers/delivery_writers.dart`。
- character-kind 漏了 `import_remapper.dart` 的 `_characterCols` 白名单（第 49 行）和 `import_schema_sync_test`。

**写法上的约束**
- `CanvasNode` 是 freezed 模型。`isDisabled`、`pinnedResultId`、`isImported`、`isNote` 一律写成新文件里的 extension，不改 `canvas_node.dart`。
- 节点仓库已有 `patchTypeConfig`（inspector_submit_controller 第 354 行在用）。停用、固定都用它，不给 `NodeRepository` 加抽象方法：有 26 个 fake 实现它，加一个方法就要改 26 个测试文件。
- 新的画布动作写进新文件 `util/canvas_<x>_actions.dart`。只有要改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）的切片才碰 `canvas_tool_actions.dart`。

**文件正交的例外**：下面这些由主 Agent 在 rebase 时统一合并，不算占用。
- ARB 和 `generated/`、`docs/CLAUDE.md`
- `theme/tokens.dart`，只许追加常量
- W0 / W1 建的四张注册表，每片只许追加一行：
  - `canvas_shortcut_registry.dart`
  - `canvas_menu/menu_registry.dart`（节点 / 空白处 / 新建三类菜单的分组表）
  - `app_actions/app_action_catalog.dart` 的动作列表
  - `more_menu_model.dart` 的项表

## 1. 合并后的切片表

板名缩写：Sel = Selection，UC = UndoClipboard，CM = ContextMenus，TC = TakesCost，IS = ImportSearch，RS = RailScript，SE = ShellExport，KM = KeyMap，GC = GapsCanvas，GP = GapsPanels。

**地基**

| id | 标题 | 板 | 大小 | 价值 | 依赖 | 迁移/新依赖 | 卡在 |
|---|---|---|---|---|---|---|---|
| menu-split | 拆 `create_node_menu`：Panel/Entry/Row 进 `theme/components/ink_menu_panel.dart`，加 `CanvasMenuPopover`；`canvas_menu/` 下分宿主、新建、空白处、节点条目、menu_registry；原文件只做 barrel 导出 | CM+GC+SE | M（搬） | 低 | — | — | — |
| canvas-view-split | 拆 `canvas_view`：stage_pointer_layer / node_card_slot / stage_lane_layer / stage_edge_layer / stage_overlays；骨架留在原文件 | 新增 | M（搬） | 低 | — | — | — |
| esc-ladder | Esc 阶梯；修「输入框里按 Esc 清空选中」（第 469 行）；快捷键改注册表（新键 = 新文件，shortcut_catalog 从注册表取文案） | KM | M | 中 | — | — | — |
| undo-stack | CanvasHistoryController + CanvasCommand；按两端找边；undoSpecific；关掉画布就丢栈并收卡 | UC | M | 低 | — | — | — |
| multi-select-core | replace / addAll / toggleAll + selection_geometry | Sel | S | 低 | — | — | — |
| duration-format | `l10n/duration_format.dart`，并掉 RS / GP / TC / SE 四份 | 多板 | S | 低 | — | — | — |
| naming-shot-unify | 分镜→镜头、导入脚本→导入剧本、「创建 N 个镜头」（并掉 shot-node-naming） | GC+SE | S | 中 | — | — | — |
| nodes-batch-ops | moveNodes / removeNodes / restoreAll / patchTypeConfigMany，各一个事务；多选删除只出一张卡（不碰 canvas_tool_actions） | Sel | M | 中 | — | — | — |
| narrative-splice | 插入 / 删除接上 / 换类型 / removeEdges / addEdgesInTx / replaceRoleEdge（并掉两份） | CM+GP | M | 低 | undo-stack（令牌形状） | — | — |
| canvas-capsule | InkCanvasCapsule、host、provider，接上缩放和适应时的比例提示（并掉 canvas-hint-capsule） | GC+UC | M | 中 | — | — | — |
| current-take | currentResultFor 加各处调用改用它；导出默认勾当前 take | TC | M | 中 | — | — | — |
| app-action-table | AppAction 表；⌘K 从表里按上下文过滤；没落地的动作登记成禁用 | SE | L | 低 | esc-ladder | — | — |
| gen-inputs-snapshot | 建 job 的同一事务写 gen_inputs；remapper 改写 / 剥除；导出 stripUnmappedGenInputs | TC | M | 低 | — | — | — |
| node-cost | estimateNodeCost；算不出写「—」（修掉自定义接口显示 $0.00）；提示词条常驻金额 | TC | M | 高 | promptbar-sample | — | — |
| help-actions | 帮助动作组 + 左栏帮助弹层（并掉 RS / SE 两份） | RS+SE | M | 中 | app-action-table | — | — |
| media-import-service | 复制进 `canvases/<id>/imports/` + 导入式产物节点；orphan reaper 和孤儿结果判定豁免导入节点 | IS | L | 高 | — | — | — |
| stage-drop-target | sealed 拖放载荷 + 舞台 DragTarget + 悬停卡高亮 | IS | M | 中 | canvas-view-split | — | — |
| export-records-table | 新表 + 仓储 + 手写不可变模型 | SE | M | 低 | — | 迁移 | — |
| dep-drop-pasteboard | 引入 desktop_drop + pasteboard，封装读图接口 | IS | S | 中 | — | 新依赖 | IS-Q1 |

**撤销**

| id | 标题 | 板 | 大小 | 价值 | 依赖 |
|---|---|---|---|---|---|
| undo-shortcuts-ui | Ctrl Z、Ctrl Y / ⇧⌘Z、空白处右键两项、⌘K | UC | M | 高 | undo-stack、canvas-capsule、esc-ladder、app-action-table |
| undo-adopt-existing | 删节点、删线、换道的撤销卡并进栈；修「关掉画布后卡还能点」 | UC | M | 高 | undo-shortcuts-ui、nodes-batch-ops |
| undo-node-create-move | 新建 / 复制 / 移动 / 进出泳道进栈；moveNodesToLane 改走 moveNodes | UC | M | 高 | undo-adopt-existing |
| undo-edges | 连线、删线、改语义（含被降级的那条）进栈 | UC | M | 中 | undo-node-create-move、narrative-splice |
| undo-params | 一次聚焦编辑算一步，原来没有的键撤销时删掉 | UC | L | 高 | undo-stack、nodes-batch-ops |
| lane-ops-core | 解散 / 删除泳道和内容；修删道后 lane_id 悬空 | CM | M | 高 | — |
| undo-lanes | 泳道新建 / 改名 / 风格 / 排序 / 改厚 + 解散 / 删除进栈 | UC | M | 中 | lane-ops-core、undo-adopt-existing |

**选区与剪贴板**

| id | 标题 | 板 | 大小 | 价值 | 依赖 | 卡在 |
|---|---|---|---|---|---|---|
| marquee-select | 框选；平移改走 H / 空格 / 右键拖 / 中键拖（并进 KM 的中键平移） | Sel+KM | L | 高 | multi-select-core、canvas-view-split、esc-ladder | — |
| group-drag | 整组拖，按抓住的那张用 resolveCardDrop 判换道；Shift 锁轴（并进 KM 的 drag_axis_lock） | Sel+KM | L | 高 | multi-select-core、nodes-batch-ops、undo-node-create-move | — |
| snapping | 网格 + 对象参考线 + Ctrl/⌘ 原样放下标志 + 空白处菜单两个开关（并掉 CM grid-snap） | Sel+CM | M | 低 | group-drag | — |
| align-distribute-arrange | 对齐 / 分布 / 排布 / 整理叙事链 + Alt 字母 | Sel | M | 中 | multi-select-core、nodes-batch-ops、undo-stack | — |
| wrap-in-lane | Ctrl G 包成泳道 / Ctrl Shift G 移出 | Sel | M | 中 | lane-ops-core、undo-stack | — |
| selection-toolbar | 浮动工具条（Q3-B：单选配置节点出精简条） | Sel | L | 中 | multi-select-core、batch-run-dialog（软） | — |
| multi-select-inspector | 多选检查器 | Sel | L | 中 | nodes-batch-ops、undo-stack、node-cost | — |
| lane-collapse-persist | style_lanes.collapsed | Sel | S | 低 | — | **Sel-Q6**（迁移） |
| canvas-clipboard-core | 应用内剪贴板 + 快照改写 + 粘贴落点 | UC | M | 低 | multi-select-core | — |
| clipboard-paste | Ctrl C / X / V 节点 + 右键项；媒体复用 media-import 的写入 | UC | L | 高 | canvas-clipboard-core、nodes-batch-ops、undo-shortcuts-ui、media-import-service | — |
| clipboard-text-paste | 外部文字粘成文本节点 + 胶囊上的「按剧本拆镜…」 | UC | S | 中 | clipboard-paste、canvas-capsule | — |
| os-drop-paste-image | 从系统拖入 + 粘贴剪贴板图片（并掉 UC 的图片粘贴片） | IS+UC | M | 高 | dep-drop-pasteboard、media-import-service、clipboard-paste | **IS-Q1** |

**右键菜单与 TakesCost**

| id | 标题 | 板 | 大小 | 价值 | 依赖 | 卡在 |
|---|---|---|---|---|---|---|
| node-disabled-flag | 停用 / 启用 | CM | M | 中 | menu-split | — |
| cm-edge-menu | 连线右键菜单 + 中点工具条；Del 删线 | CM | L | 高 | menu-split、narrative-splice、canvas-view-split | — |
| cm-lane-menu | 泳道标题栏右键菜单 | CM | L | 中 | menu-split、lane-ops-core | — |
| cm-drag-insert-narrative | 拖到叙事线上插一镜 | CM | L | 高 | narrative-splice、group-drag、snapping、undo-stack | — |
| cm-delete-bridge | 删链中间的镜时前后接上 | CM | M | 中 | narrative-splice、nodes-batch-ops、undo-adopt-existing | — |
| cm-knife-cut | Alt + 拖切线 | CM | L | 低 | narrative-splice、esc-ladder、marquee-select | — |
| cm-multi-select-menu | 多选右键菜单 | CM | M | 中 | node-disabled-flag、node-cost、batch-run-dialog、align-distribute-arrange、wrap-in-lane | — |
| tc-set-current | 设为当前（固定）+ 进栈 | TC | L | 高 | current-take、menu-split、undo-stack | — |
| tc-batch-slot-set-current | slot 走 promote + 设为当前，同一事务，带撤销令牌（并掉 undo-set-current） | TC+UC | M | 中 | current-take、undo-stack | — |
| tc-take-edge-follow | 下游 data 边跟着当前 take 走 | TC | M | 高 | tc-set-current、gen-inputs-snapshot | **TC-Q1** |
| tc-stale-marks | 过期标记 | TC | L | 高 | current-take、gen-inputs-snapshot、node-cost | — |
| job-eta | 耗时预估 | TC | S | 低 | duration-format | — |
| batch-run-planner | 批量运行计划（纯函数） | TC | M | 低 | current-take、node-cost、node-disabled-flag | — |
| batch-run-executor | 批量运行执行器 | TC | L | 高 | batch-run-planner、tc-take-edge-follow | **TC-Q1** |
| batch-run-dialog | 运行对话框 + 全部入口（多选 Ctrl ↵ 分流） | TC | L | 高 | batch-run-planner、batch-run-executor、job-eta | — |
| tc-next-shot-first-frame | 「当下一镜的首帧 ›」 | TC | M | 中 | menu-split、current-take、undo-stack | — |

**ImportSearch 与 RailScript**

| id | 标题 | 板 | 大小 | 价值 | 依赖 | 迁移/新依赖 | 卡在 |
|---|---|---|---|---|---|---|---|
| import-media-command | Ctrl U + 空白处 / 更多菜单里的「导入媒体…」 | IS | M | 高 | media-import-service | — | — |
| rail-drag-assets | 素材拖进画布（替换首帧用 replaceRoleEdge） | IS | L | 高 | stage-drop-target、media-import-service、narrative-splice | — | — |
| rail-drag-characters | 角色行拖到配置节点 | IS | S | 中 | stage-drop-target | — | — |
| mention-token-core | `@{角色 id}` 记号纯函数层 | IS | M | 中 | — | — | **IS-Q3** |
| prompt-bar-mention-ui | 提示词条里的 @ 补全 | IS | L | 中 | mention-token-core、promptbar-sample | — | — |
| canvas-find-bar | Ctrl F 查找 | IS | M | 高 | esc-ladder | — | — |
| canvas-minimap | 小地图 | IS | M | 中 | — | — | — |
| back-to-content-chip | 「回到内容」胶囊 | IS | S | 中 | — | — | — |
| note-variant | 便签 | IS | M | 中 | — | — | **IS-Q5** |
| text-inline-edit | 双击就地编辑 | IS | M | 中 | — | — | — |
| tool-lock | 工具锁 | IS | S | 低 | — | — | IS-Q4（只定做不做，默认 A） |
| script-tables | script_documents / paragraphs（含 character_candidates） | RS | L | 高 | — | 迁移 | — |
| script-import | 导入写段落、接到链尾、估时长写进 duration_ms（并掉 RS 写段落片 + GP 估时长片，估时长函数只留一份） | RS+GP | L | 高 | script-tables、duration-format、naming-shot-unify | — | — |
| script-import-characters | 导入时识别角色（匹配函数与 RS 共用） | GP | L | 中 | script-import | — | — |
| rail-script-panel | 左栏剧本页 | RS | L | 高 | script-tables、script-import | — | — |
| script-panel-repair-actions | 重建这一镜 / 拼剧本 / 追加 | RS | M | 中 | rail-script-panel | — | — |
| script-characters-row | 剧中角色行 | RS | M | 中 | script-panel-repair-actions、script-import-characters | — | — |
| script-reimport-diff | 重新导入逐段比对 | RS | L | 中 | script-import、rail-script-panel | — | R2（只决定这片做不做） |
| template-core | 模板核心 | RS | L | 中 | mention-token-core（软） | — | — |
| rail-templates-page | 左栏模板页（内置） | RS | M | 中 | template-core、rail-script-panel | — | — |
| my-templates-table | canvas_templates 表 | RS | L | 低 | rail-templates-page | 迁移 | **R5** |
| node-library-section | 节点库 | RS | S | 低 | rail-templates-page、note-variant（软） | — | — |
| node-library-drag-recents | 节点库拖进画布 + 最近用过（复用 recentPresetsProvider，不另加仓库方法） | RS | M | 低 | stage-drop-target、node-library-section、create-menu-pick-recent | — | — |

**ShellExport、KeyMap、GapsCanvas、GapsPanels**

| id | 标题 | 板 | 大小 | 价值 | 依赖 | 迁移/新依赖 | 卡在 |
|---|---|---|---|---|---|---|---|
| win-menubar | Windows 自绘菜单栏 | SE | L | 高 | app-action-table、menu-split、help-actions | — | — |
| lone-alt-menubar | 单独按下再松开 Alt 聚焦菜单栏 | SE | M | 中 | win-menubar | — | — |
| mac-platform-menubar | macOS PlatformMenuBar | SE | M | 中 | app-action-table、help-actions | — | — |
| job-timing | JobTiming 旁表 + 弹层显示耗时（formatElapsed 用 duration-format） | SE | M | 中 | duration-format | — | — |
| system-notifications | 系统通知 | SE | L | 高 | job-timing | local_notifier | 需同意依赖 |
| f6-notification-region | F6 跳到通知区 | SE | M | 中 | system-notifications | — | — |
| export-records-recording | 导出完成 / 失败写历史 | SE | S | 中 | export-records-table | — | — |
| export-tab-history | 导出标签 + 导出历史 | SE | L | 高 | export-records-recording、menu-split | — | — |
| delivery-clips-tab | 交付面板「片段」页签 | SE | S | 中 | — | — | — |
| delivery-history-tab | 交付面板「历史」页签 | SE | S | 低 | delivery-clips-tab、export-records-recording | — | — |
| image-zip-export | 图片 ZIP（archive 已在依赖里） | SE | M | 中 | export-tab-history | — | — |
| storyboard-pdf-export | 分镜 PDF | SE | L | 中 | export-tab-history | pdf + 字体 | **SE-Q4** |
| export-in-task-popover | 导出 / 交付进任务弹层 | SE | M | 中 | job-timing、export-records-recording | — | — |
| zoom-reset-100 | Ctrl 0 = 100% | KM | S | 低 | esc-ladder | — | — |
| shortcuts-page-v2 | 快捷键页分组 | KM | M | 中 | esc-ladder | — | — |
| next-shot | 新建下一镜，三个入口（并掉 KM / GC 两份） | KM+GC | L | 高 | menu-split、canvas-capsule、undo-stack | — | **KM-Q1 与 GC-N3 冲突** |
| node-menu-append-chain | 节点右键「新建下一镜」「加入叙事链末尾」 | GC | M | 高 | next-shot、narrative-splice | — | — |
| locate-in-gallery | 在画廊中定位 | GC | M | 中 | menu-split、current-take | — | — |
| create-menu-pick-recent | CreateMenuPick + 「最近用过」/「模型」两组 + recentPresetsProvider | GC | L | 中 | next-shot | — | — |
| create-menu-notes-characters | 新建菜单加便签 / 角色组 | GC | M | 中 | create-menu-pick-recent、note-variant | — | **IS-Q5** |
| more-dropdown-panel | 「更多」改用菜单面板 | GC | M | 中 | menu-split、naming-shot-unify、cm-knife-cut（软） | — | — |
| note-heading-style | 便签两档字号 | GC | L | 低 | note-variant | — | **IS-Q5** |
| toast-category-mute | 通知按类型开关 | GP | M | 中 | — | — | — |
| toast-corner | 通知卡位置 | GP | S | 低 | toast-category-mute | — | — |
| panel-resize | 面板拖宽 | GP | M | 中 | — | — | — |
| collapse-all-panels | 一键收起两侧面板 | GP | S | 中 | panel-resize | — | — |
| outline-rename-menu | 大纲改名 + 右键菜单 | GP | M | 高 | menu-split | — | — |
| outline-drag-reorder | 大纲拖动排序 | GP | M | 高 | narrative-splice、outline-rename-menu | — | — |
| character-kind | 角色 / 物品 / 场景（同时补 remapper 的 `_characterCols`） | GP | M | 中 | — | 迁移 | — |
| character-usage-links | 「被引用」可点 | GP | S | 中 | character-kind | — | — |
| assets-hover-preview | 素材悬停预览 | GP | M | 中 | — | — | — |
| assets-gallery-import-origin | 导入来源标与筛选 | GP | M | 中 | media-import-service、assets-hover-preview | — | — |
| sequence-locate-regenerate | 序列里定位 / 重生成 | GP | M | 高 | menu-split、current-take | — | — |
| result-inspector-align | 产物检查器三处对齐 | GP | S | 低 | duration-format | — | — |
| export-one-click | 一键导出分体按钮 | GP | L | 中 | export-records-table、toast-category-mute（软） | — | — |

**撤掉或拆进别片的**
- cm-blank-menu-additions：三个菜单项分别交给 clipboard-paste、import-media-command、snapping。
- canvas-pointer-pan-axis：中键平移交给 marquee-select，锁轴交给 group-drag。
- undo-set-current：交给 tc-batch-slot-set-current 和 tc-set-current。

## 2. 分波与热点文件

每一波内部，除第 0 节列的例外，同一个文件只出现在一个切片里。

| 波 | lane A | lane B | lane C | lane D | lane E |
|---|---|---|---|---|---|
| W0 | menu-split | canvas-view-split（**最先合**） | esc-ladder → zoom-reset-100 | undo-stack → naming-shot-unify | multi-select-core → duration-format |
| W1 | nodes-batch-ops | narrative-splice | canvas-capsule | current-take | app-action-table |
| W2 | undo-shortcuts-ui | node-cost | gen-inputs-snapshot | lane-ops-core | media-import-service |
| W3 | undo-adopt-existing | marquee-select | tc-set-current | import-media-command | help-actions |
| W4 | undo-node-create-move | tc-batch-slot-set-current | stage-drop-target | win-menubar | export-records-table（v9） |
| W5 | group-drag | undo-edges | undo-params | rail-drag-assets | tc-take-edge-follow（Q1） |
| W6 | snapping | cm-edge-menu | cm-delete-bridge | undo-lanes | export-records-recording → export-tab-history |
| W7 | tc-stale-marks | cm-drag-insert-narrative | canvas-clipboard-core → clipboard-paste | cm-lane-menu | lone-alt-menubar → mac-platform-menubar |
| W8 | node-disabled-flag | align-distribute-arrange | wrap-in-lane | clipboard-text-paste | job-timing |
| W9 | canvas-find-bar | batch-run-planner → job-eta | dep-drop-pasteboard → os-drop-paste-image（Q1） | multi-select-inspector | rail-drag-characters → outline-rename-menu |
| W10 | batch-run-executor | next-shot（KM-Q1 / N3） | tc-next-shot-first-frame | script-tables（v10） | system-notifications（新依赖） |
| W11 | batch-run-dialog | node-menu-append-chain → result-inspector-align | script-import | mention-token-core（Q3） | f6-notification-region |
| W12 | cm-multi-select-menu | toast-category-mute | rail-script-panel | prompt-bar-mention-ui | locate-in-gallery |
| W13 | selection-toolbar | outline-drag-reorder | script-import-characters → script-panel-repair-actions | create-menu-pick-recent | sequence-locate-regenerate |
| W14 | note-variant（Q5） | panel-resize | assets-hover-preview | character-kind（v11） | export-in-task-popover → delivery-clips-tab |
| W15 | text-inline-edit | collapse-all-panels | script-characters-row | character-usage-links | delivery-history-tab → image-zip-export |
| W16 | note-heading-style | template-core | toast-corner | assets-gallery-import-origin | export-one-click |
| W17 | rail-templates-page | script-reimport-diff（R2） | canvas-minimap | cm-knife-cut | shortcuts-page-v2 |
| W18 | more-dropdown-panel | create-menu-notes-characters | back-to-content-chip | node-library-section → node-library-drag-recents | storyboard-pdf-export（Q4） |
| W19 | tool-lock | lane-collapse-persist（Q6） | my-templates-table（R5） | — | — |

**热点文件逐波归谁**（每波只有一个切片占用；→ 表示按波次往后叠）

- **canvas_view.dart 骨架**：W0 拆分 → W4 stage-drop-target → W6 cm-edge-menu → W9 os-drop → W13 selection-toolbar。
- **stage_pointer_layer**：W3 marquee → W17 knife-cut → W19 tool-lock。
- **node_card_slot**：W3 undo-adopt → W4 undo-create-move → W5 group-drag → W6 snapping → W7 drag-insert → W9 find-bar → W15 inline-edit。
- **stage_edge_layer**：W3 undo-adopt → W6 edge-menu → W14 note-variant（便签不接端口）。
- **stage_lane_layer**：W2 lane-ops → W6 undo-lanes → W7 lane-menu。
- **node_card.dart**（最长链，11 片）：W2 media-import → W3 set-current → W4 stage-drop → W5 group-drag → W6 snapping → W7 stale → W8 disabled → W9 find → W14 note-variant → W15 inline → W16 heading。
- **canvas_shortcuts**：W0 拆成注册表之后，后面的切片只新建 `shortcuts/<x>_keys.dart` 并往注册表追加一行。核心键文件归 W1 capsule（缩放提示）和 W11 batch-run-dialog（Ctrl ↵ 分流）。
- **菜单**：
  - `canvas_menu_host`：W5 rail-drag-assets → W6 edge → W7 lane → W12 multi → W13 selection-toolbar。
  - 空白处条目：W2 → W3 → W6 → W7。
  - 新建菜单条目和 `create_menu_model`：W1 current-take → W10 next-shot → W13 pick-recent → W14 note-variant → W17 templates → W18 notes-characters。
  - `node_menu_model`：只有 W12 multi-select-menu 改共享的 targets / kind 判据，其余菜单项都走注册表。`nodeStatusOf` 在 node_card 里，跟着 node_card 那条链走。
- **canvas_nodes_controller**：W1 batch → W2 media（放宽断言）→ W6 delete-bridge → W7 paste → W9 outline-rename → W13 pick-recent。
- **canvas_edges_controller**：W1 splice → W5 undo-edges。
- **canvas_lanes_controller**：W2 → W6 → W8 wrap → W19 collapse-persist。
- **canvas_tool_actions**：W1 capsule → W4 → W5 → W6 → W13。
- **generation_controller**：W2 gen-inputs → W5 edge-follow → W10 executor → W11 mention → W14 note-variant。
- **import_remapper**：W2 → W10 script-tables → W11 mention → W14 character-kind → W19。
- **app_preferences + file_preferences_service**（每波最多一片）：W6 snapping → W10 sys-notif → W11 run-dialog → W12 toast-category → W13 selection-toolbar → W14 panel-resize → W16 corner → W17 minimap。
- **canvas_screen**：W1 → W9 → W14 → W15 → W17 → W18。
- **outline_panel**：W7 → W8 → W9 → W11 → W13。
- **任务弹层**：`shell_task_popover`：W8 → W10 → W14。`shell_task_capsule`：W4 → W10 → W14。
- **toast_center**：W10 → W11 → W12。
- **script_import_dialog**：W0 → W8 → W11 → W13 → W17。

## 3. 派工建议与验收要点

**通用验收**
- 纯搬移的 PR：用 `git diff -M --color-moved=zebra` 核对，测试全部不改仍是绿的，测试锚点 Key 保持原名。
- 每条新测试都要做一次变异：拿掉实现，证明它变红。

**W0**：B 先合，因为它最大、rebase 代价最高；C、A 其次；D、E 随时合。
- menu-split：`no_reverse_layer_import_test` 绿（theme 层不引用画布类型）；菜单相关的 3 个测试文件不改动就能过。
- esc-ladder：在提示词条里按 Esc 只失焦，选中还在（变异：删掉 isEditingText 分支就红）；层序表单测；新键缺 `includeRepeats: false` 时守卫测试要红。
- undo-stack：深度 100、新操作清空重做栈、revert 失败时那一步留在栈顶、对象已消失就丢弃这一步、关掉画布就丢栈。
- multi-select-core：框选命中跳过折叠道里的卡。

**W1**
- nodes-batch-ops：在 `transaction_integration_test` 里让第 3 张失败，整批回滚。
- narrative-splice：分叉 / 汇合时 bridgePlan 返回「不接」；撤销令牌按两端找边。
- canvas-capsule：一次只有一条；位置贴在提示词条上方 8；滚轮缩放不出提示。
- current-take：固定的 take 被软删后回落到最新，撤销删除后又回来。
- app-action-table：⌘K 的动作全部来自表；禁用项带原因。

**W2**
- node-cost：自定义接口显示「—」，不再是 $0.00（变异：把判据改回 0 就红）。
- lane-ops-core：解散后屏幕位置不变、lane_id 清空；删除时道、节点、边在一个事务里。
- media-import：先写 `.partial` 再改名，零残留；reaper 不把 `imports/` 当孤儿。
- gen-inputs：导入项目包后 gen_inputs 里的源 id 已改写，映射不到的剥掉。
- undo-shortcuts-ui：文本框有焦点时 Ctrl Z 归文本框。

**W3**
- undo-adopt：关掉画布后卡被收掉，Ctrl Z 能撤卡片对应的那一步（undoSpecific）。
- marquee：拖动不到 4px 算点空白；Esc 恢复原来的选中；右键在抬起时开菜单没被破坏。
- set-current：固定之后，新 take 到达时通知写「当前仍是 take N」。
- import-media-command：跳过的文件在卡片里点名。
- help-actions：两个入口用同一张动作表。

**W4–W6**
- group-drag：整组按抓住的那张判换道；广播不逐帧重建全部卡片（重建计数断言）。
- undo-params：撤销前先冲掉 500ms 防抖 patch（变异：去掉 flush 就撤到旧值上）。
- edge-follow：画布没开时新 take 到达也会挪边。
- cm-edge-menu：Del 优先删线；产出线点不中。
- delete-bridge：遇到分叉不接，卡片文案对应。
- export-records：取消不写记录；写库失败不影响导出本身成功。

**W7–W9**
- stale：改回原值后标记消失；老产物（没有快照）不标过期。
- drag-insert：12px 命中阈值；放不下时让位；插入、让位、换道合计一步撤销。
- paste：跨项目时 `@{id}` 换成「@名字」，并从 character_ids 删掉；媒体复制失败零残留。
- disabled：只在批量运行时跳过。
- job-timing：注入时钟测试排队 / 用时（终态不含排队时间）。
- find-bar：在文字里也接管 Ctrl F；Esc 档位正确。
- multi-inspector：换成同一模型后清掉不支持的字段，一个事务、一步撤销。

**W10–W13**
- executor：上游失败，下游不提交；run_group 写进 parameters。
- next-shot：继承键的白名单（变异：多继承一个 seed 就红）；Ctrl → 在文字里让给光标。
- script-tables：项目包往返测试 + import_schema_sync 测试。
- run-dialog：1 张直接提交，≥2 张开对话框，上限 50。
- mention：remapper 映射不到的角色记号变成「@名字」。
- multi-menu：「另 N 个价格未知」文案统一。
- outline-drag：越组回弹。

**W14–W19**
- character-kind：老项目包没有 kind 列，导入后落默认值。
- panel-resize：舞台至少 480，窗口变窄时自动收起左面板。
- note-variant：便签不进提示词、不进大纲，查找能搜到。
- 其余切片按各自板上的规则逐条钉测试。

## 4. 迁移编号与新依赖

**迁移**：按合入顺序编号，板上的版本号一律不算数。

| 编号 | 切片 | 波 | 是否已定 |
|---|---|---|---|
| v9 | export-records-table | W4 | 已定 |
| v10 | script-tables（script_documents + script_paragraphs，含 character_candidates JSONB） | W10 | 已定 |
| v11 | character-kind（characters.kind，带 CHECK 约束） | W14 | 已定 |
| v12 / v13 | lane-collapse-persist（Q6 选 C）、my-templates-table（R5 选 A，应用级，不进项目包） | W19 | 要等拍板 |
| 视情况 | 便签做成新类型 | — | 只有 IS-Q5 选 B 才有 |

迁移一发出去就不能改（ADR-0012），所以每条 DDL 在合入前要由主 Agent 单独审一遍。

**新 pub 依赖**（都需要你同意）：
- desktop_drop + pasteboard：原生插件，Windows 和 macOS 的插件注册文件都要重新生成（对应 IS-Q1）。
- local_notifier：系统通知用；Windows zip 版要实测它建的开始菜单快捷方式。
- pdf，外加打包 NotoSansSC-Regular.otf（安装包约 +10 MB，OFL 授权，登记进 `core/licenses.dart`，对应 SE-Q4）。

其余功能都只用已有依赖：file_selector、archive、Flutter 自带的 Clipboard。

## 5. 必须先拍板的决定

| 决定 | 卡住哪些切片 | 最迟 | 建议 |
|---|---|---|---|
| IS-Q1 拖放 / 粘贴图片用哪套依赖 | dep-drop-pasteboard、os-drop-paste-image | W9 | A |
| TC-Q1 下游连线怎么跟当前 take | tc-take-edge-follow、batch-run-executor，以及 set-current 撤销命令的形状 | **W5 前** | A（改写边） |
| KM-Q1 与 GC-N3 冲突：锚点已有下一镜时按 Ctrl → | next-shot，连带 node-menu-append-chain、create-menu-pick-recent | W10 | GC-N3 的 A：开分叉，排在已有分叉之后，与现有 nextNarrativeSortOrder 和新建菜单「下一镜」一致；要插中间就拖到线上插入 |
| IS-Q3 `@{角色 id}` 的持久化格式 | mention-token-core、prompt-bar-mention-ui；template-core 软依赖 | W11 | A |
| IS-Q5 便签怎么存 | note-variant、note-heading-style、create-menu-notes-characters | W14 | A（`variant = note`，不迁移）。critic 和设计稿在这件事上的说法不一致，要你明确选一个 |
| Selection-Q6 泳道折叠要不要记住 | lane-collapse-persist | W19 | C（但要加一条不可撤回的迁移） |
| RailScript-R5 我的模板存哪 | my-templates-table | W19 | A |
| 新依赖 local_notifier、SE-Q4（pdf + 字体） | system-notifications（W10）、storyboard-pdf-export（W18） | 各自那一波前 | — |

不阻塞、按建议默认的：R2（只决定 script-reimport-diff 做不做，排在 W17）、IS-Q4（工具锁默认做，排在 W19），以及其余全部「需要你定」项。

## 6. 建议的前三个 PR

1. **esc-ladder（含快捷键注册表）**：顺带修一个现存 bug——在提示词条里按 Esc 会清空选中。它让后面约 20 个加快捷键的切片不再抢 `canvas_shortcuts.dart`。M，只动两个文件，风险低。
2. **canvas-view-split**：纯搬移，文件 1875 行。后面 14 个切片都要改它，越早合 rebase 越便宜。必须在 W0 第一个合，基于 `origin/main`（已含 #299）。
3. **node-cost**：价值高，直接修掉自定义接口显示 $0.00；不碰任何热点文件，前提是 `fix/demo-promptbar-sample` 先合。合了 promptbar-sample 的话可以提前进 W0 并行跑，它也是 TakesCost 和多选菜单的地基。

menu-split 和这三个同在 W0 并行，只是不算进「前三」。紧接着最先能让用户看到变化的是 W1–W3 的 lane-ops-core、current-take 和 undo-shortcuts-ui。