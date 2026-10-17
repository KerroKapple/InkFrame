# 第二批 W4–W7 · 设计缺口清单（供细化画板）

写派工单时发现的画板空白。每条格式：画板 · 功能 · 缺什么。「暂定」是派工单里先写死的处理；画板定了别的，只改对应派工单那一条规则和对应的测试。

## UndoClipboard

1. 撤销新建时任务还在跑（undo-node-create-move）
   - 缺：胶囊里「任务仍在运行」排在哪。
   - 暂定：「已撤销 · 新建 视频配置 · 任务仍在运行」。
2. 改参数时写库失败（undo-params）
   - 缺：这段编辑进不进栈；之后点「重试」成功了补不补进栈。
   - 暂定：库里没变就不进栈，重试成功也不补。
3. 文本框会话还开着，又改了同一节点的下拉（undo-params）
   - 缺：算一步还是两步。
   - 暂定：两步。
4. 撤销连线时，这条线已经被改过角色（undo-edges）
   - 缺：先撤哪一步。
   - 暂定：按栈序，后改的那步先撤；找不到线就丢掉这一步。
5. 反向找 data 边时「端口」取什么（undo-edges、tc-take-edge-follow）
   - 缺：「端口」的定义。
   - 暂定：取 role，按「源 + 目标 + role + data」四项找边。
6. 泳道进栈（undo-lanes）
   - 「改厚」不在进栈表里。暂定：算一步。
   - 切换泳道方向没提。暂定：不进栈。
   - 「删除泳道和内容」（道内有任务在生成时）的确认框文案没画。
   - 排序进行中有一条道被删，顺序怎么合并没画。
7. 改连线类型（叙事 ↔ data）的撤销
   - 说明：这不是画板缺口，是切片归属。
   - 暂定：命令归 cm-edge-menu 的 ChangeEdgeTypeCommand，复用 undo-edges 的 EdgeEnds。
8. 复制粘贴（canvas-clipboard-core、clipboard-paste）
   - 右键「粘贴」的落点「按下那一点」，没说对的是包围盒左上角还是中心。暂定：左上角，与新建菜单锚点一致；指针在画布上时对中心。
   - 正在生成、还没有产物的 result 节点能不能复制。暂定：跳过。
   - 包围盒没算泳道的锚定位移，缩放离 1 远时粘出的相对位置会略偏。
   - 源文件已不在磁盘。暂定：按复制失败处理，零残留。
   - 节点菜单里剪切 / 复制放哪组。暂定：剪切 · 复制 · 复制一份。
   - 粘贴成功要不要提示。暂定：只有跨项目去掉了角色引用时出胶囊。
   - 剪切的删除卡文案没写。暂定：「已剪切 N 个节点」。

## Selection

9. 整组拖（group-drag）
   - 换道提示锚在哪：画板画在舞台右上角。暂定：挂在抓住的那张卡上方。
   - 整组移出所有泳道时的提示文案没画。
   - Shift 锁哪个轴没写。暂定：累计位移的主分量。
   - 选中集里有折叠泳道中的卡，跟不跟着走没写。暂定：不带。
10. 吸附（snapping；ContextMenus 的网格吸附已并入本片）
    - 网格底的问题：CanvasGridPainter 画在屏幕空间，不随平移和缩放变；吸附按世界坐标 24 取整。所以「与网格底同源」在视觉上对不齐。要么网格底改成世界坐标，要么改文案。
    - 网格吸附和对象吸附同时满足时谁优先。暂定：每个轴上对象优先。
    - 整组拖按谁吸附。暂定：抓住的那张。
    - 示意图里那条半透明虚线参考线是什么意思，没写。
    - 打勾项点完后菜单关不关。暂定：关。
    - 两张画板冲突：ContextMenus 写「松手时取整」，Selection 画的是拖动中出参考线。暂定：按 Selection。

## ContextMenus

11. 拖到叙事线上插一镜（cm-drag-insert-narrative）
    - 插入后卡停在哪。暂定：停在松手处。
    - 成功反馈卡、失败文案都没画。
    - 拖动途中按 Esc 能不能取消，没写。
12. 连线菜单（cm-edge-menu）
    - 「插入节点…」打开的菜单没画。暂定：新建菜单同款，只列镜头 / 图像配置 / 视频配置。
    - 中点工具条随不随缩放变大。暂定：屏幕尺寸恒定。
    - 以下置灰原因没画：已有同类线、目标是产物、文本不入链、源不带图、目标不是视频配置。
    - 行内的线型小样。暂定：用 8px 色点代替。
13. 删除并接上（cm-delete-bridge）
    - 「删除（不接上）」放在哪、什么时候能点。暂定：删除组第二行；接不上任何东西时置灰。
    - 多段删除时，一部分接上、一部分因分叉没接，撤销卡怎么写，没画。
    - 撤销卡标题：画板带节点名，现有卡写「节点已删除」。暂定：沿用现有标题。
    - 段前、段后两镜之间本来就有叙事线。暂定：不重复建，撤销时也不删那条原有的线。
14. 泳道菜单（cm-lane-menu）
    - 折叠的道，第四行写什么。暂定：「展开」。
    - 折叠的道上点「选中内容」。暂定：先展开再选中。
    - 空道的「选中内容」。暂定：置灰，行尾写「0 个」。
    - 改名输入框失焦。暂定：等同保存；名字为空或没变就不写库。
    - 被右键的标题栏有没有高亮。暂定：加 accent 描边。

## TakesCost

15. 批量 slot（tc-batch-slot-set-current）
    - 「已选，但所在 take 不是当前」的格子长什么样，没画。
    - 孤儿 result（没有配置节点）的 slot 没画。
    - 对比浮层开着时，撤销键归谁，没说。
    - 历史页 mock 里的 slot 条由 W3 画还是本片画，不确定。
16. 线跟着当前 take 走（tc-take-edge-follow，TC-Q1 按建议 A）
    - 线接回本配置节点自己（img2img 迭代）时挪不挪。暂定：不挪。
    - 新当前已经有一条连到同一目标的线。暂定：旧线软删。
    - 删掉当前 take 后，下游线去哪，没说。
    - 挪线要不要告诉用户，没说。
17. 过期标记（tc-stale-marks）
    - 原因卡只画了 4 种行。以下几行的写法是补的：模型参数、运镜、负向、画布风格、角色、输入增减。
    - 配置卡上点「当前 take 已过期」会发生什么，没画。
    - 「重新生成」在这些情况下的样子没画：缺 Key、提示词为空、正在生成、价格算不出。
    - 文本节点正文、角色描述改了判不出来，因为快照里没有这两项。
    - 「以该种子重跑」：如果把覆盖后的种子写进快照，这张 take 会立刻被判过期。需要 gen-inputs-snapshot 在快照里区分。 →（已解决：W2 gen-inputs-snapshot 写 `seed_override: true`，W7 见键不比种子（主 Agent 跨批核对补充））

## ImportSearch

18. 舞台拖放（stage-drop-target）
    - 拖动中按 Esc 取消：Flutter 的 Draggable 不认 Esc，本批不做。
    - 拖到空白处时，整个舞台要不要提示，没画。暂定：只高亮泳道。
19. 素材拖到配置节点（rail-drag-assets）
    - 「替换尾帧」没画。暂定：与首帧对称。
    - 同一素材已经以同一角色连在这个配置上。暂定：置灰「已连着」。
    - 解析不出 provider 时，首帧 / 尾帧行的原因没画。暂定：「没有可用的模型」。
    - 新建的素材节点放哪。暂定：配置左侧一列，同道。
    - 除了替换，其他操作要不要提示。暂定：只有替换出撤销卡。

## ShellExport · 菜单栏（win-menubar、lone-alt-menubar、mac-platform-menubar）

20. Windows 菜单栏
    - 标签的悬停态 / 打开态没画。暂定：按 KeyMap altBox，surface5 底 + fg1 字。
    - 下拉与 chrome 下沿的间距没画。暂定：0，贴下沿，左沿对齐标签。
    - 行高两处不一致：b2_shell 注释写 22，mi() 实际画 21。暂定：22。
    - 没有 job 时「窗口 › 任务」怎么显示。暂定：置灰，原因「还没有任务」。
    - 「窗口」里的当前标签：画板画的是前导圆点，InkMenuEntry 只有行尾打勾。暂定：用打勾。
    - 设置浮层开着时菜单栏能不能用。暂定：能用，与 ⌘K 的口径一致。
    - 「导出项目包…」的执行体是 studio 的私有 `_exportProject`。暂定：先登记成禁用。
    - 「退出 Alt F4」：formatShortcutActivator 的键名表里可能没有 F4。
21. 单独按 Alt 聚焦菜单栏
    - 聚焦态下点别处、点标签会怎样，没画。
    - 对话框盖着时单独按 Alt。暂定：不响应。
    - 下拉开着时再单独按 Alt。暂定：关下拉，焦点回原处。
22. macOS 系统菜单
    - 系统菜单没有 Tooltip，「置灰并说原因」做不到。
    - 单键快捷键要不要登记进系统菜单。暂定：只登记带 ⌘ 的。
    - 启动失败页的菜单没画。暂定：只留应用菜单。
    - 对话框盖着时没画。暂定：自定义项全灰。

## ShellExport · 导出历史（export-records-table、export-records-recording、export-tab-history）

23. 表与记录
    - 进不进项目包，没说。暂定：不进。
    - kind 只列了四种。暂定：剪映 / FCPXML 归 delivery，目标软件写进快照。CHECK 合入后就不能改。
    - 交付失败时「文件」一栏写什么。暂定：留空，不量大小。
24. 导出标签
    - 以下状态没画：没有项目、历史为空、本画布为空、加载中、读取失败、来源画布已删除（暂定：写「已删除的画布」，「重新导出」置灰）。
    - 「从历史移除」没有撤销。
    - 历史行的右键菜单没有键盘入口。
    - 跨画布「重新导出」。暂定：先切到那个画布再开对话框。
    - **需要设计确认**：交付行的「重新导出 / 重试」。画板写「用快照重走」，可要自动重跑，就得偷偷改项目的交付设置，或者复制一份交付计划的拼装逻辑。暂定：跳到序列标签的交付面板，由用户确认后再交付。

## 计划层面的约定（不是画板缺口，但偏离了 plan.md，请主 Agent 知悉）

- **撤销命令各自成文件（已按 undo-stack 统一（主 Agent 跨批核对补充））。** `CanvasCommand` 不 sealed、不用 part、没有 label 枚举：每条命令一个 `models/commands/<名>_command.dart`，自带 `label(l)`，`revert` / `apply` 收 `CanvasCommandEnv`、返回 `CanvasCommandOutcome`；入栈用 `record`（只登记、不执行）。`canvas_command.dart` 不再每片追加。
- **新增一张注册表 `widgets/stage_drop/stage_drop_registry.dart`**，由 stage-drop-target 新建。之后 rail-drag-assets、rail-drag-characters、node-library-drag-recents 每片只追加一行，不再碰 canvas_view.dart。
- **`theme/components/ink_menu_panel.dart` 有两波只追加可选参数：**
  - W3 help-actions：disabledReason（置灰原因，唯一叫法）；W4 win-menubar：rowHeight、onArrowOut。
  - W6 cm-edge-menu：note（行尾常显小字）。
  - W7 cm-lane-menu 依赖 note，以及 cm-edge-menu 提供的 `CanvasMenuHost.viewportPointOf`。
- **W7 clipboard-paste 改 canvas_view.dart 一处**：包一层 MouseRegion，记录指针位置。W7 没有别的切片占用这个文件。
- **mac-platform-menubar 挂在 app.dart 的 home 上，不挂 InkShell。** 挂在 InkShell 里，启动失败时 PlatformMenuBar 会被卸掉，系统菜单被清空，⌘Q 也没了。另外核对到：macOS 的 AppDelegate 已经经 `inkframe/lifecycle` channel 跑 AppTeardown，现在的 ⌘Q 并不会让 PG 成为孤儿进程。
- **前序切片的签名本批只能写「以该片为准」**，涉及：W1 AppAction 字段名、replaceRoleEdge、MediaImportService 的「复制进 imports / 删掉复制件」、stripUnmappedGenInputs、canvasCapsuleProvider 的显示方法、MoveNodesCommand 装不装多张卡。 →（已解决：跨批核对后各单已写死前序签名（主 Agent 跨批核对补充））
