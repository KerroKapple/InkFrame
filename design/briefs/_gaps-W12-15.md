# 第二批派工单 W12–W15 · 设计缺口与待定问题

供细化画板使用。格式：画板 · 功能 · 缺什么状态 / 步骤 / 边界（括号里是派工单暂定的做法，画板补上后以画板为准）。

## ContextMenus

- ContextMenus · 多选菜单 · 顶行「已选 3 · 约 $0.42」是标题行还是可点项没说（暂不实现）
- ContextMenus · 多选菜单 · 可生成数 N = 0 时这行文案没画（暂定「生成」置灰）

## ContextMenus / Selection

- ContextMenus / Selection · 横截轴对齐 · 两板说法不一致（「只在同一条道可点」vs「夹在各自的带里」），按 plan 取前者

## GapsCanvas

- GapsCanvas · 新建菜单「最近用过」· 哪些状态的 job 算「用过」没说（定为只取 success）
- GapsCanvas · 新建菜单「最近用过」· 预设的 Provider 已删 / 不支持该类型时没画（定为不出这行）
- GapsCanvas · 新建菜单 · 组头、「无 Key」小标、只在打字时出现的组——InkMenuPanel 是否支持未定
- GapsCanvas · 在画廊中定位 · 「已清除筛选」位置与消失时机没画（定为：筛选栏顶一行，下次改筛选即消失；四轴整体清空）
- GapsCanvas · 在画廊中定位 · 滚动方式没画（定为：已在视口内不滚，否则 jumpTo）
- GapsCanvas · 在画廊中定位 · 多选时没画（定为：目标恰好一张才可点，多张置灰写原因）
- GapsCanvas · 在画廊中定位 · 目标找不到（刚删）的反馈没画（定为：静默消费请求）

## GapsPanels

- GapsPanels · 通知按类型开关 · 默认值没写明（样稿画的「一般提示」是关；派工单定全开，待确认）
- GapsPanels · 通知按类型开关 · 被静音类别在铃铛历史里是否有视觉区分没画（定为无区分）
- GapsPanels · 通知按类型开关 · 交付侧现在没有完成卡，「导出完成」在交付侧无可标的卡
- GapsPanels · 通知按类型开关 · 导出失败是对话框内联横幅不是 toast，导出侧无失败卡可标
- GapsPanels · 大纲拖动排序 · 筛选框有字时能否拖没画（定为禁用）
- GapsPanels · 大纲拖动排序 · 拖到列表边缘自动滚动没画（不做）
- GapsPanels · 大纲拖动排序 · 拖动中 Esc 取消没画
- GapsPanels · 大纲拖动排序 · 「借号」行对（镜头 + 共用镜号的配置）只拖一行会被拆开，没画
- GapsPanels · 大纲拖动排序 · 被拖行是多子分叉点时怎么接没画（交给 narrative-splice 语义）
- GapsPanels · 面板拖宽 · 「↔ 280」读数的确切位置没画（定为热区外 8px、竖向居中）
- GapsPanels · 面板拖宽 · 左面板 200px 宽时角色行 / 素材网格 / 剧本页内容是否成立没核对
- GapsPanels · 面板拖宽 · 自动收起左面板后窗口变宽是否自动展开没画（定为不展开，同手动收起）
- GapsPanels · 一键收起 · 检查器收起后没有可见的重新打开按钮（只有快捷键与 ⌘K）
- GapsPanels · 一键收起 · 选中节点是否让检查器回来没画（定为不回来）
- GapsPanels · 一键收起 · 开合动画没画（定为无动画）
- GapsPanels · 剧本导入识别角色 · 候选取消勾选 / 移除没画；划选文字与已有角色同名没画；无活动项目态没画
- GapsPanels · 素材悬停预览 · 实际尺寸没定（定媒体宽 320）
- GapsPanels · 素材悬停预览 · 尺寸行「1920×1080」无数据来源（GalleryItem 无宽高）
- GapsPanels · 素材悬停预览 · 底部放不下的翻转、文件丢失 / 视频打不开态，没画
- GapsPanels · 角色编辑框「类型」三段 · 位置与尺寸没画（定为名称与描述之间，高 24）
- GapsPanels · 角色分组 · 组被筛空时没画（按「空组不画」）
- GapsPanels · 「M 处引用」· ≥2 处时点了去哪没画（定为 1 处直跳，≥2 处弹 CanvasMenuPopover 列表）
- GapsPanels · 「有未存改动先问」· 对话框没画（定为 保存后前往 / 不保存 / 取消）
- GapsPanels · 未存改动判据 · 只改参考图算不算没说（定为不算，参考图即时落库）
- GapsPanels · 序列右键菜单 · 右键时播放头 / 选中行是否移动没画（定为：都不动）
- GapsPanels · 序列右键菜单 · 价格算不出的写法没画（定为：「约 —」）
- GapsPanels · 序列右键菜单 · 「从这一镜播放」需要监视器公开播放入口（sequence_monitor._play 私有），不在任何片的归属里；本批不做

## ImportSearch

- ImportSearch · 便签 · 只画了琥珀一种底色；另两种与浅色主题下三种是派工单自定
- ImportSearch · 便签 · 卡片尺寸没画（暂定外框 kNodeCardSize，整卡便签纸，无标题 / 状态 / 继承行）
- ImportSearch · 便签 · 检查器底色选择器样式没画（暂定三颗色块）
- ImportSearch · 就地编辑 · 编辑态边框色、是否标「编辑中」没定（暂定 accent 内描边）
- ImportSearch · 就地编辑 · 缩放 < 0.6 卡片收成图标时双击没画（暂定不进入）
- ImportSearch · @ 补全 · 已软删角色的名字取不到（listByProject 不返回软删行），灰标签显示态没画（定为「已删除的角色」）
- ImportSearch · @ 标签 · 样稿是带头像圆角的 chip；TextEditingController.buildTextSpan 只能画样式区间，需要认可降级
- ImportSearch · @ 弹层 · 锚点位置没画（定为光标上方，超出舞台右对齐）
- ImportSearch · @ 触发 · `a@b` 邮箱式输入是否开弹层没说（定为前一字符是 ASCII 字母数字时不开）

## ImportSearch / GapsCanvas / ShellExport

- ImportSearch / GapsCanvas / ShellExport · 新建菜单里便签的位置三板不一致（「文本 · 便签 · 镜头」vs「文本 · 镜头 · 便签 · 泳道」），按多数排在镜头之后

## ImportSearch / KeyMap

- ImportSearch / KeyMap · 就地编辑 · Esc 阶梯里没有「就地编辑」这一层（暂定编辑框自己吃 Esc）

## RailScript

- RailScript · 剧本面板 · 「已生成」行标签没画（只在底栏计数）；「生成中」样式没画；读库失败态没画
- RailScript · 重建这一镜 · 前后邻居都不在、下一镜已有别的叙事入边、失败提示，都没画
- RailScript · 用镜头备注拼剧本 · 备注为空的镜头、链外镜头怎么排，没画
- RailScript · 剧中角色 · chip 数字含义没写（定为出现段数）；「+」与点实心 chip 的动作没画
- RailScript · 剧中角色 · 段行 chip 是「已挂角色」还是「匹配到的角色」看不出（按已挂 character_ids）；候选与已有角色重名没画

## Selection

- Selection · 浮动工具条 · 单选文本 / 镜头 / 便签没单独画（按单选配置处理）
- Selection · 浮动工具条 · 选区在视口外、左右顶出视口、翻到下方压住提示词条，没画（暂定不出 / 夹边 16 / 不避让）
- Selection · 浮动工具条 · 右键菜单开着时工具条是否保留没画（暂定隐藏）

## ShellExport

- ShellExport · 任务弹层导出行 · 导出 / 交付行版式没画（定为：同生成行，meta = 类别 · 状态 · 已用/用时，进度未知不画进度条）
- ShellExport · 任务弹层导出行 · 终态行动作（打开文件夹）没画（定为：不做）
- ShellExport · 片段页签 · 「尺寸不一致」行没画（暂定：第二行琥珀色「画幅 9:16 不一致」，基准为链上首个比值；宽高未知不算）
- ShellExport · 片段页签 · 空态（链上 0 镜）没画
- ShellExport · 片段页签 · 当前播放那一镜的高亮没画（暂定沿用序列链表行 surface5）
- ShellExport · 片段 / 历史页签 · 底部摘要（输出 / 包含）在不在没说（暂定只在「交付」页；结果条三页都显示）
- ShellExport · 历史页签 · 失败的交付行没画（暂定「失败 · 原因」，无「打开文件夹」）
- ShellExport · 历史页签 · 空态、行数上限没画（暂定全列、可滚动）
- ShellExport · 历史页签 · 「文件夹已不在」没画；与导出标签「划掉」规则不一致
- ShellExport · 图片 ZIP · 对话框整体没画（暂定沿用 export_video_dialog 骨架）
- ShellExport · 图片 ZIP · 链上图像镜无产物时的处理没说（暂定跳过并写跳过个数）
- ShellExport · 图片 ZIP · 孤儿图 / 导入图算不算一镜没说（暂定按 latestTakeNodeIds 各自成镜，排在链上镜之后）
- ShellExport · 导出历史 · zip 行「重新导出」路径没画

## 计划材料与代码不一致（核对 origin/main f64f56e 时发现）

- plan.md 第 0 节说 `CanvasNode` 是 freezed；实际 `lib/features/canvas/models/canvas_node.dart` 是手写的 `@immutable` 类。「新派生属性写成 extension、不改 canvas_node.dart」照旧适用。
- plan.md 第 0 节说 `delivery_writer_registry.dart` 不存在；实际 `lib/features/export/models/delivery_writer_registry.dart` 存在（delivery_panel.dart 在 import）。
- slices.json 让 create-menu-pick-recent 给 `addNode` 加 typeConfig；`CanvasNodesController.addNode` 已有该参数，只需给 `addNodeFromMenu` / `addNodeAtViewportCenter` 加。
- narrative-splice 的写入口在 plan.md（spliceInsert / bridgePlan / insertPlan）与 slices.json（applySplice）里名字不一致，outline-drag-reorder 两种都兼容。

## 跨片未定问题（需要主 Agent / 你拍板）

- sequence-locate-regenerate：画板序列菜单第三项「从这一镜播放」没做——要公开 `sequence_monitor.dart` 的播放入口，而这个文件不在任何片的归属里。可以另开一小片，也可以降级成只做 selectShot。
- image-zip-export：导出历史里 zip 行的「重新导出」要么另开小片，要么允许改 W6 的 export_history_row；ZIP 本片按「不进任务弹层」处理。
- toast-category-mute：五类默认全开，但样稿画的「一般提示」是关着的，需要确认。
- script-panel-repair-actions / script-import-characters：「重建这一镜」「拼剧本」不进撤销栈，导入时新建的角色撤销导入时也不删。已知后果：撤销「删除原镜」后，段落仍指向新镜。
- prompt-bar-mention-ui：@ 标签用样式区间代替带头像的 chip，与画板有出入。
- 前序 W0–W11 的 API（InkMenuEntry / CanvasMenuPopover / menu_registry 行形状、escape_ladder 登记口、currentResultFor 入参、estimateNodeCost 返回、formatElapsed、ScriptRepository 方法、ExportRecord 字段）各单都写了「签名以合入后为准」。这些切片合入后，主 Agent 要回头对一遍。
