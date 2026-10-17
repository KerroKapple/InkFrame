# 第二批 W0–W3 · 设计缺口清单

写派工单时发现、画板没画到的状态 / 步骤 / 边界。每条列出画板、功能、缺什么，以及派工单里的暂定做法。细化画板时请逐条确认或推翻；推翻的条目要回头改对应派工单（括号里是切片 id）。

格式：画板 · 功能 · 缺什么 → 暂定（切片）

## KeyMap
- KeyMap · Esc 阶梯第 6 档「工具回到选择」· 连线、工具锁、平移同时生效时先剥哪个没写；现有代码是「平移先于连线」 → 暂定拆成三档：连线 > 工具锁 > 平移，与现状相反（esc-ladder）
- KeyMap · Ctrl 0 复位 100% · 已经是 100% 时按下有没有反馈没写 → 暂定不动、不提示；比例胶囊交给 canvas-capsule（zoom-reset-100）
- KeyMap / ShellExport · 重做键显示 · 画板写 ⇧⌘Z，现有 formatShortcutActivator 输出 ⌘⇧ 顺序，且有测试钉住 → 暂定 mac 统一改成 Apple 顺序 ⌃⌥⇧⌘，并改现有断言（undo-shortcuts-ui）
- KeyMap · 重做「每平台只注册一个主键」· 与现有 ⌘ / Ctrl 双注册冲突 → 暂定注册 ⇧⌘Z 和 Ctrl+Y；mac 上 Ctrl+Y 也会生效，但不展示（undo-shortcuts-ui）
- KeyMap · 右键拖 / 中键拖平移 · 光标（grab / grabbing）没画 → 暂定沿用平移工具的光标（marquee-select）

## Selection
- Selection · 框选 · 触摸屏 / 触控笔单指拖空白算框选还是平移，没画 → 暂定只有鼠标左键起框，其余设备照旧平移（marquee-select）
- Selection · 框选 · 同时按住 Shift 和 Ctrl/⌘ 时是哪种模式没写 → 暂定反选优先（marquee-select）
- Selection · 框选 · 起框时已经选中的连线怎么办没写 → 暂定起框就清掉，Esc 不恢复（marquee-select）
- Selection · 框选 · 拖到视口边缘自动平移的触发区和速度没写 → 暂定离边 24px 内触发，每帧最多平移 12px（marquee-select）
- Selection · 框选 · 按 Esc 取消后指针还按着继续拖，没写 → 暂定不重新起框，松手也不算点空白（marquee-select）
- Selection · 框选 · 拖框途中节点被删或节点集刷新，命中怎么变没写 → 暂定按新节点集重算；Esc 恢复选中时滤掉已删的 id（marquee-select）
- Selection · 框选 · 「已选 N」芯片在框很小或贴着视口边时放哪，只画了一个位置 → 待画（marquee-select）
- Selection · 框选命中 · 框正好贴着卡片边（相交面积为 0）算不算碰到，没写 → 暂定算（multi-select-core）
- Selection · 选区包围盒 · 选中的卡在折叠道里时怎么算没写 → 暂定跳过这些卡（multi-select-core）
- Selection · 批量删除失败 · 失败文案没画，选中要不要恢复也没写 → 暂定沿用 nodeDeleteFailed，选中不恢复（nodes-batch-ops）

## UndoClipboard
- UndoClipboard · 撤销卡 · 卡上撤销的那步不在栈顶时，进不进重做栈没写 → 暂定不进；在栈顶时等同 Ctrl Z（undo-stack）
- UndoClipboard · 关画布丢栈 · 切到同项目的另一张画布算不算「关闭」没写 → 暂定算，丢栈（undo-stack）
- UndoClipboard · 快捷键 · 栈空时按 Ctrl Z、撤销进行中再按，各给什么反馈没画 → 暂定都不提示（undo-shortcuts-ui）
- UndoClipboard · 撤销失败 · 反馈形态没画，画板只说「反馈走胶囊」 → 暂定失败出错误卡 undoFailed；「这一步已无法撤销」走胶囊（undo-stack / undo-shortcuts-ui）
- UndoClipboard · ⌘K 撤销 / 重做 · 画板要求带步名，但 AppAction.label 拿不到栈 → 暂定 ⌘K 只写通用的「撤销 / 重做」（undo-shortcuts-ui）
- UndoClipboard / ShellExport · 重做图标 · 画板画的是镜像撤销图标，图标集 v1 里没有 → 暂定留空，待补字形（undo-shortcuts-ui）
- UndoClipboard · 撤销卡清单 · 没列「删连线」，而检查器「移除」连线现在吞掉失败、也不出卡 → 暂定统一走一条路，都出卡（undo-adopt-existing）
- UndoClipboard · 普通拖动（不换道）· W3 不进栈，这段时间里 Ctrl Z 会跳过拖动 → 归 W4 undo-node-create-move（undo-adopt-existing）
- UndoClipboard · 撤销删除节点 · 节点原来的泳道已经被删时怎么处理没画 → 暂定照原样复原 lane_id，留给 undo-lanes（undo-adopt-existing）

## ContextMenus
- ContextMenus · 插入一镜让位 · 「后移一格」是多大、竖向泳道沿哪个轴移，没画 → 暂定一格 = 卡片主轴尺寸 + 64，方向跟 LaneDirection（narrative-splice）
- ContextMenus · 多选删除接上 · 一部分段接上、另一部分因为分叉没接时，卡片怎么写没画 → 本片只返回 skippedSegments 计数，文案归 cm-delete-bridge（narrative-splice）
- ContextMenus · 解散泳道 · 折叠中的道解散时按哪个厚度算屏幕位置没画 → 暂定按展开厚度（lane-ops-core）
- ContextMenus · 解散泳道 · 后面的道会整体前移、卡片跟着道走，这一点没画 → 待画（lane-ops-core）
- ContextMenus · 删除泳道和内容 · 「有生成中任务」确认框的文案和按钮没画 → 暂定加 3 个键（lane-ops-core）
- ContextMenus · 删除泳道和内容 · 撤销后，被取消的任务不会恢复，画板没写清 → 暂定写进确认框文案（lane-ops-core）
- ContextMenus · 空白处菜单顺序 · 画板「粘贴」排在「导入媒体」前，但 menu-split 把粘贴放进第 30 组，导入媒体在第 10 组 order 15 → 待 clipboard-paste（W7）对齐（import-media-command）
- ContextMenus / GapsCanvas · InkMenuPanel · 置灰项「悬停说原因」没有状态，也没有字段 → help-actions 给 InkMenuEntry 加可选 tooltip；悬停延迟和样式待画（menu-split / help-actions）

## ShellExport / RailScript
- ShellExport · 菜单栏下拉 · 宽度、相对标签的锚点都没给尺寸 → CanvasMenuPopover 暂定左上角对准一个全局点，放不下就往回收（menu-split）
- ShellExport · ⌘K · 禁用的动作要不要在 ⌘K 里灰着显示，没画 → 暂定不显示，只有菜单栏灰着写原因（app-action-table）
- 多张画板 · 工具条「更多」· 下拉项分散在四张板上，没有统一样稿和排序 → 本批只放「导入剧本…」「导入媒体…」，排序待 more-dropdown-panel 统一（app-action-table / import-media-command）
- RailScript · 帮助 ›「检查更新…」· 点下后的进行中、已是最新、失败三种状态没画 → 暂定关掉弹层，这一行灰着写「正在检查更新…」，结果用通知卡告诉用户（help-actions）
- RailScript · 帮助入口 · 非画布标签（Studio、画廊）没有帮助入口 → 等 W4 win-menubar / mac 菜单栏（help-actions）

## TakesCost
- TakesCost · 固定的 take 被删后 · 要不要清掉 pinned_result_id 没写 → 暂定不清，撤销删除后固定能自己回来（current-take）
- TakesCost · 设为当前 · 没有「取消固定」入口；最新那条 take 显示「已是当前」并置灰，所以没法把最新那条固定住 → 待定（tc-set-current）
- TakesCost · 设为当前 · 当前 take 的琥珀描边和选中描边都用 accent，选中时分不出来 → 暂定选中描边优先，图钉照画（tc-set-current）
- TakesCost · 设为当前 · 画布没打开时新 take 完成，拿不到固定信息，通知就不写「当前仍是 take N」 → 待定（tc-set-current）
- TakesCost · 设为当前 · 写库失败的错误卡文案没画 → 暂定复用通用写失败文案（tc-set-current）
- TakesCost · 花费 · 节点右键菜单「生成」悬停出明细，菜单行没有这种浮层 → 本片不做（node-cost）
- TakesCost · 花费 · 单价为 0 但其实知道价格（例如免费额度）没区分 → 暂定一律算「价格未知」（node-cost）
- TakesCost · 花费 · 视频没选时长时显示什么没画 → 暂定写「—」，明细写「没选时长」（node-cost）
- TakesCost · 花费 · 「生成」置灰时悬停显示什么没画 → 暂定只显示置灰原因，不显示明细（node-cost）
- TakesCost · gen_inputs · 文本节点入边的正文要不要进快照没写 → 按建议记 text（gen-inputs-snapshot）
- TakesCost · gen_inputs · 角色映射不到时，剥掉一个还是剥掉整份没写 → 按建议整份剥掉，记作「没快照」（gen-inputs-snapshot）
- 四块板 · 统一时长格式 · 满 1 小时怎么写没画 → 暂定 h:mm:ss（duration-format）
- 四块板 · 统一时长格式 · 舍入方式没写 → 暂定片长和估时长四舍五入，有时长就至少写 1 秒；计时向下取整（duration-format）
- GapsPanels · 导入对话框汇总行 · 写的是「约 9 秒」，和「~」前缀是两种写法 → 汇总行算整句文案，归 script-import 自己的键（duration-format）

## GapsCanvas
- GapsCanvas · 统一叫法 · 「开始分镜」「分镜创作」这类动作义要不要改没说 → 暂定只改节点类型名（naming-shot-unify）
- GapsCanvas · 胶囊 · 舞台太窄、两侧让位后放不下时怎么办没画 → 暂定可用宽度不到 96 就不画（canvas-capsule）
- GapsCanvas · 胶囊 · 动作按钮能不能用键盘按到没写 → 暂定不进 Tab 序，胶囊上写出键位（canvas-capsule）

## ImportSearch
- ImportSearch · 导入媒体 · 复制中途能不能取消没画 → 本批不做（media-import-service）
- ImportSearch · 导入媒体 · 文件大小上限、一次最多选几个文件，都没写 → 暂定都不设上限；磁盘满按复制失败处理（media-import-service / import-media-command）
- ImportSearch · 导入媒体 · 缩放小于 0.6（紧凑卡）时，复制中的卡长什么样没画 → 待画（media-import-service）
- ImportSearch · 导入媒体 · 右键「导入媒体…」落在哪没写 → 暂定落在右键点，其余入口落在视口中心（import-media-command）
- ImportSearch · 导入媒体 · 多个文件「散布」的排法没画 → 暂定按文件名（不分大小写）排序，最多 4 列网格，间距 lg，整片再散布一次（import-media-command）
- ImportSearch · 导入媒体 · 导入后选中谁没写 → 暂定新节点替换当前选中，相机不动（import-media-command）
- ImportSearch · 导入媒体 · 文件选择框打不开（例如 macOS 权限）时的提示没画 → 暂定加一个文案键（import-media-command）
