# InkFrame 视觉层全量重做 · 实施提示词

> 交给 Claude Code 的一次性任务书。目标：**把 lib/ 下所有界面的视觉层按 design_handoff_inkframe_ui/ 重做**，而不是在旧视觉上修补。结构层（PR #234 的标签外壳、ShellState、保活与焦点）保留，不回退。

---

## 0. 先读，再动手

按顺序读完，确认理解后才开第一个 commit：

1. `design_handoff_inkframe_ui/README.md` 全文——这是唯一真相源。旧仓库 token、旧 chrome、旧衬线标题都不是参考。
2. `design_handoff_inkframe_ui/*.dc.html`——用浏览器打开逐屏对照。它们是 HTML 制作的设计参考，不是可移植代码。
3. `docs/superpowers/specs/2026-09-20-shell-tab-navigation-design.md`——结构层规格，本任务**不得违反**其中的保活、焦点、Scaffold 唯一性、`skipOffstage` 断言等约束。
4. `lib/theme/tokens.dart`、`lib/theme/typography.dart`、`lib/theme/app_theme.dart`——要被替换的对象。

读完输出一段 ≤ 300 字的理解摘要给用户确认，列出你识别到的与 README 冲突的现有实现（至少应包含：56px 标题行、衬线 Logo、胶囊选中标签、设置壳内层、暖色 token）。用户确认后再动。

## 1. 硬约束

- **中性灰是唯一色彩体系。** 暖色 ramp（`#0B0908 / #100C0A / #15110E / #1C1814 / #2A2520 / #36302A`）整体废弃，不保留别名、不做兼容层。
- **强调色只有一个：琥珀 `#C9A85B`。** 语义色（成功 `#7FB069` / 错误 `#B04030` / 音频轨绿系）只用于状态文字与标记，不用于容器底色。
- **无衬线。** 界面字体 Noto Sans SC（回落 PingFang SC / Microsoft YaHei UI），等宽 JetBrains Mono（回落 Consolas / Menlo）。`Cormorant Garamond`、`Noto Serif SC` 及任何 serif 家族从 typography.dart 删除，pubspec 的字体声明同步清理。
- **不写任何 hex 到 widget 里。** 全部经 `InkColors` 槽位；README「Design Tokens」表是槽位清单，仓库缺的槽位补进去。
- **控件高度、行高、面板宽度按 README 表**，不四舍五入到 Material 默认值（不是 48/56，是 22/24/26/28/30/34）。
- **不改数据层、不改 provider 语义、不改 ShellState。** 这是纯视觉任务。发现结构问题记 BOARD，不顺手修。
- **每个 PR 附关键界面截图**（Windows 实机或 golden）到 PR 描述，用户按图验收。

## 2. Token 三套变体

`InkColors` 从 28 槽扩到以下清单。dark 值直接取 README；light / highContrast 是从同一语义推导的，不要自行调色。

### dark（主变体）

| 槽位 | 值 | 语义 |
|---|---|---|
| surface0 | `#141414` | 窗口外底（仅画布模式 / 浮层遮罩下可见） |
| surface1 | `#1A1A1A` | 中央工作区 |
| surface2 | `#1D1D1D` | 应用主体默认底 |
| surface3 | `#232323` | 侧栏 / 底栏面板 |
| surface4 | `#262626` | 菜单栏 / 状态栏 / 节点头部 / 浮层 |
| surface5 | `#2E2E2E` | 选中行 / 激活标签底 / 次级按钮悬停 |
| borderStrong | `#0F0F0F` | 面板之间、标题栏下沿 |
| borderSubtle | `#1F1F1F` | 列表行间 |
| outline | `#2C2C2C` | 缩略图 / 图区默认描边 |
| control | `#3A3A3A` | 输入底线 / 分组框 / 分隔竖线 |
| controlStrong | `#3F3F3F` | 次级按钮边框 |
| overlayBorder | `#4A4A4A` | 浮层边框 |
| fg1 | `#E8E8E8` | 标题 / 选中项 |
| fg2 | `#D6D6D6` | 正文 |
| fg3 | `#C8C8C8` | 菜单项 / 未选中标签 |
| fg4 | `#9E9E9E` | 字段标签 |
| fg5 | `#8A8A8A` | 元信息 |
| fg6 | `#6B6B6B` | 占位 / 快捷键提示 |
| accent | `#C9A85B` | 唯一强调 |
| accentHover | `#D8B96C` | |
| onAccent | `#1D1D1D` | 琥珀底上的文字，**禁止白色** |
| accentWash | `#2A2318` | 提示条底 / 选中 Provider 行 |
| accentWashBorder | `#6B5A38` | 提示条内次级按钮边 |
| success | `#7FB069` | |
| danger | `#B04030` | |
| audioFill / audioBorder / audioFg | `#22301F` / `#3A5334` / `#8FB07E` | 序列 A1 轨 |

### light

同一语义、反向 ramp。fg 与 surface 互换方向，accent 压暗保对比。

| 槽位 | 值 |
|---|---|
| surface0 | `#E4E4E4` |
| surface1 | `#F4F4F4` |
| surface2 | `#F8F8F8` |
| surface3 | `#EFEFEF` |
| surface4 | `#FFFFFF` |
| surface5 | `#E2E2E2` ← **比 surface3 更深**：浅色主题选中态靠压暗 |
| borderStrong | `#C8C8C8` |
| borderSubtle | `#E6E6E6` |
| outline | `#D4D4D4` |
| control | `#C4C4C4` |
| controlStrong | `#B8B8B8` |
| overlayBorder | `#A8A8A8` |
| fg1 | `#1A1A1A` |
| fg2 | `#2E2E2E` |
| fg3 | `#444444` |
| fg4 | `#5E5E5E` |
| fg5 | `#767676` |
| fg6 | `#8E8E8E` |
| accent | `#8C6A30` |
| accentHover | `#7A5C28` |
| onAccent | `#FFFFFF` |
| accentWash | `#F3ECDC` |
| accentWashBorder | `#C9B689` |
| success | `#3E7A34` |
| danger | `#A03028` |
| audioFill / audioBorder / audioFg | `#E3EEDF` / `#A9C49E` / `#3E6B34` |

### highContrast（基于 dark）

surface 全部塌到两档，border 纯白，fg 纯白/纯黑。

| 槽位 | 值 |
|---|---|
| surface0–2 | `#000000` |
| surface3–4 | `#0A0A0A` |
| surface5 | `#2A2A2A` |
| borderStrong / borderSubtle / outline / control / controlStrong / overlayBorder | `#FFFFFF` ← 全部同值，刻意；注释写明「HC 下分隔线不可能比纯白更强」 |
| fg1–fg3 | `#FFFFFF` |
| fg4–fg6 | `#D0D0D0` |
| accent | `#FFD060` |
| accentHover | `#FFE08A` |
| onAccent | `#000000` |
| accentWash | `#332A10` |
| accentWashBorder | `#FFD060` |
| success | `#6BFF6B` |
| danger | `#FF6B6B` |
| audioFill / audioBorder / audioFg | `#0A1A0A` / `#6BFF6B` / `#6BFF6B` |

### tokens_test 必补

1. 三变体槽位齐全（现有）。
2. **方向性**：dark / hc 的 surface5 亮于 surface4；light 的 surface5 暗于 surface3。
3. **防复制**：三变体各自 surface5 ≠ surface4，fg1 ≠ fg2。
4. **对比**：`wcagContrast(fg2, surface3) ≥ 4.5`、`wcagContrast(onAccent, accent) ≥ 4.5`，三变体都跑。
5. **无暖色残留**：全 lib/ 扫描，旧 ramp 六个 hex 与 `#E8DFD0 / #B5A89A / #8A7E70` 零命中（测试用正则，命中即红）。

## 3. Typography

`typography.dart` 重写为以下样式集，其余删除：

| 名 | 字体 | 字号/字重/行高 |
|---|---|---|
| body | Noto Sans SC | 12 / 400 / 1.45 |
| bodyStrong | Noto Sans SC | 12 / 500 / 1.45 |
| meta | Noto Sans SC | 11 / 400 / 1.45 |
| micro | Noto Sans SC | 10 / 400 / 1.3 |
| sectionTitle | Noto Sans SC | 15 / 500 / 1.3 |
| dialogTitle | Noto Sans SC | 17 / 500 / 1.3 |
| mono | JetBrains Mono | 11 / 400 / 1.0 |
| monoSmall | JetBrains Mono | 10 / 400 / 1.0 |

Logo 用 16×16 琥珀方块 + 无衬线「If」+「InkFrame」12/500。衬线「Ink/Frame」删除。

## 4. 壳 Chrome（改口：设置改浮层）

按 `InkFrame Workspace v2.dc.html` 与 README §1：

- **菜单栏 30px**，surface4 底，下沿 borderStrong。左：Logo；中：菜单项（文件 / 编辑 / 画布 / 节点 / 窗口 / 帮助，水平内边距 10，悬停 surface5）；右：⌘K 搜索入口 260px（无底色、1px control 底线）+ 连接状态。
  - **Windows / Linux**：窗口控件（最小化 / 最大化 / 关闭）占菜单栏最右，各 46×30，`DragToMoveArea` 只包菜单项与空白区，**不包 ⌘K 入口和标签栏**。⌘K 入口在窄于 1100 时收成图标。
  - **macOS**：左侧预留 78px 给交通灯，Logo 右移。
- **标签栏 34px**，surface2 底，下沿 borderStrong。五个标签水平内边距 16，未选中 fg4，选中 fg1 + 500 + **2px accent 下边框，无底色**（废弃胶囊）。标签右侧 1px control 竖线 → 面包屑（各级可点）→ 最右三按钮（导入脚本 / 序列预览 = 次级；导出视频 = 主）。三按钮只在画布标签可见。
  - 窄屏 < 560（LayoutBuilder）：标签收成图标 + Tooltip，选中态加 surface5 底（纯图标条上下边框太弱）。
  - 画布标签在后台保活且 canvasId ≠ null 时，标签文字右侧 4px accent 圆点。
  - 导出进行中：导出标签显示进度环，**其余标签禁用**（替代原 barrierDismissible）。
- **设置 = 浮层对话框** 1120×740，遮罩 `rgba(10,10,10,0.55)`，surface3 底，overlayBorder 边，圆角 6，阴影 `0 24px 64px rgba(0,0,0,0.6)`。40px 标题栏 + 左导航 200px（九项，选中 surface5 底 + 2px accent 左边）+ 内容区 + 44px 底部条。Esc 关闭的 DismissIntent 冲突：**本 PR 解决**——`_EditorDialog` 打开时拦截 Esc，只关编辑框；否则关浮层。补测试两条。
- **状态栏 22px** 移到壳级，surface4 底，上沿 borderStrong。内容由当前标签提供（画布：项目 · 画布 / 节点边数 / 选中数；Studio：项目数 / 存储；画廊：项数 / 已选）。
- `InkWindowChrome` 四处全删；壳持唯一 chrome。golden 全部重铸（含 canvas_empty——这次它**应该**变，因为 token 全换了）。

## 5. 逐屏重做清单（按 PR 切）

每个 PR：一屏、附截图、golden 重铸限该屏。

| # | PR | 参照稿 | 要点 |
|---|---|---|---|
| V0 | token + typography + 全局扫描 | README §Design Tokens | 只换值，不动布局。所有界面同时变灰。这是第一个 PR。 |
| V1 | 壳 chrome + 设置浮层 + 状态栏 | Workspace v2 / Screens §3 | 见 §4 |
| V2 | Studio 首页 | Screens §1 | 无 Key 引导条 accentWash；「上次离开时」恢复条；4 列 16:10 封面；虚线新建格；删衬线「Recent Projects」 |
| V3 | 画布：节点与连线 | Workspace v2 | 节点无外框无阴影；16:9 图区 + 1px outline；端口空心入/实心出；连线带箭头 marker；多入边标注角色 |
| V4 | 画布：左栏 + 检查器 + 渲染队列 | Workspace v2 | 工具条 36；项目面板 240；检查器 300 三分组（模型 / 关键帧 / 镜头运动，术语按 README）；队列 172 表格 |
| V5 | 画布：底部提示词条 | Workspace v2 | 640px 悬浮，两行；⌘↵ 生成；从检查器迁出 |
| V6 | 风格泳道 | Lanes | 标题栏两行含 stylePrompt；3px 色轨；节点继承标注；折叠 36px；栏宽脱离道厚；编辑框四项含「自动」 |
| V7 | 画廊 | Screens §2 | 左筛选四组；5 列 16:9；当前线徽标；右信息 + 血缘（只当前线，分支折叠） |
| V8 | 批量结果 + 角色 | Batch & Characters | slot 16:9 + seed + 显式动作；对比浮层；角色库 + 编辑框（接已有 rename / delete） |
| V9 | 首启向导 + 命令面板 | Screens §4 | 三步进度；Provider 单选；⌘K 分组结果（镜头 / 产物 / 设置项 / 动作） |
| V10 | 序列与交付 | Timeline | 第 5/6 步结构工作完成后再做；本清单只登记 |

V0 → V1 严格串行；V2–V9 可并行但每个独立 PR；V10 等结构。

## 6. 每个 PR 的验收（自动化部分）

除 CI 外，PR 描述里必须回答：

1. 截图：该屏在 1600×1000 与 960×600 两个尺寸下各一张，dark 变体；V0 另附 light / hc 各一张。
2. 一句话说明本屏与参照稿的**已知偏离**及理由（没有就写「无」）。
3. `grep -rn` 旧暖色 hex 与 serif 家族名的结果为空（贴命令与输出）。
4. 不动结构层：`git diff --stat` 里 `shell_*.dart`、`*_controller.dart`、`*_repository.dart` 为零改动（V1 的设置浮层除外，需列出改了哪些行及原因）。

## 7. 禁止事项

- 禁止「保留旧样式作为可选主题」。
- 禁止用 Material 默认 `AppBar` / `NavigationRail` / `TabBar` / `Chip` 替代稿上的自绘组件——它们的默认尺寸和 README 冲突。
- 禁止把 hex 写进 widget。
- 禁止在视觉 PR 里顺手修结构 bug；记 BOARD。
- 禁止跳过 V0 直接做后续屏。
- 禁止对稿上没有的元素做「合理补充」；缺什么问用户。
