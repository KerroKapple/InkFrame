# 上线规划:UI/UX 完整性任务卡(2026-07-07)

> MASTERPLAN §4 的明细。基于 main@b2be25e 逐屏核实。规模:S≈半天 / M≈0.5–2天 / L≈2–5天 / XL≈1周+。
> 每卡默认继承铁律:文案/样式零硬编码、ARB 双语同 commit、widget 测试用 ProviderScope overrides、
> golden 走 `test/_harness/golden_scaffold.dart`、错误只捕 InkError 并经 `l10nError` 渲染。
> 开工前先读 `docs/EXECUTION-PLAYBOOK.md`。

## 0. 现状核实关键结论(任务卡引用基础)

1. 首启=空 Studio+无 key 黄条;无语言选择;窗口固定 1536×984 不记忆。
2. 空态质量已达标;**「创建示例画布」能力已实现但入口在不可达路径**(`_NoCanvasOpen` 正常路由到不了)。
3. **⌘K 是纯展示 chip**(`shortcut_labels.dart` 自注"仅展示");全仓唯一键绑定是顶栏返回钮 Enter/Space。
4. **撤销重做零实现**(ROADMAP 自认"从零设计");缓冲垫=节点/边删除是软删(数据层可恢复),
   但节点/边删除**无确认且 UI 不可撤销**。
5. 右键菜单零;文件拖入零(无 desktop_drop 依赖)。
6. 视口:InteractiveViewer(0.1–3.0);无缩放指示/控件/zoom-fit/minimap。
7. 多选:Set+修饰键点选+计数 chip 已有;无框选/群删/群拖。
8. 窗口 bounds/maximized 不持久化。
9. a11y:高对比主题+字号缩放已有;**focusRing token 定义了但全仓零消费**(键盘焦点不可见)。
10. **死 UI 清单**:canvas_left_toolbar 8 个空 onTap 图标、⌘K chip×2、顶栏 ▶、avatar×2、
    sidebar footer 4 icon、ARCHIVE 行硬编码 '0' 不可点、SectionLabel '+'。
11. **渲染队列无取消入口(重要)**:带 cancel 的 `JobQueuePanel` 未在任何屏挂载;实际挂的
    `CanvasRenderQueue` 无 cancel,失败行直接消失。后端 cancel 链路+测试齐全。
12. batch slot error 只有图标无文案(errorCode 字段可映射)。
13. AsyncValue 吞 error 点位:batch_results_grid:25、image_result_inspector:23、canvas_view:390-394、
    node_inputs_section:45-46、image_config_inspector:504/651/654/676/949-968、lane_toolbar:22。
14. custom provider 只能手编 json+重启;API Keys 行对 custom 显示原始 id。
15. gallery 视频 tile 图标占位;thumbnailService 已存在(video_node_body 在用)可复用。
16. ffmpeg 缺失走通用 errorLocalIO 文案;ARB 无 ffmpeg 相关 key;设置页无探测状态。
17. i18n 键集 en/zh 各 273 完全一致;质量(硬翻味/native polish)待人工 pass。
18. camera 运镜:9 个 provider `supportedCameras` 全空,控件永久隐藏(带而不用)。
19. text 节点类型半死:无创建入口、inspector 返回 shrink,但 image inspector 消费其内容。

## 1. Onboarding

### ON-1 首启欢迎流(语言→Key→起步)(L)
- 为什么:首启转化生死线;现状用户不知道要配 key、去哪拿。
- 涉及:新 `lib/features/studio/widgets/onboarding_dialog.dart`;`app_preferences.dart` 加
  `onboardingCompleted`(手写不可变类模式,**勿新增 freezed**——build_runner 债);`app.dart` 首帧判断;
  复用 language_section 的 locale 逻辑与 `ApiKeyScopeController.save` 三态。
- 怎么做:三步向导 Dialog(InkNoirCard,对话框样式仿 `_NewProjectDialog`):①语言二选;②粘 key
  (每 provider 行附"去控制台拿 key"说明,可跳过);③「创建示例项目」(调已有
  `canvasBootstrapControllerProvider.createSample`)或空项目。完成写偏好。
- 验收:删 preferences.json 冷启→向导;全跳过可达 Studio;填 key 后黄条消失;二启不弹;
  widget 测试覆盖流转+跳过(fake PreferencesService/SecureStorage)。
- 依赖:无。风险:与 restore_last_session 启动次序(建议 onboarding 优先、该次跳过恢复)。

### ON-2 示例项目入口常态化(S)
- 空 Studio 加 ghost 按钮「创建示例项目」→ createSample → openProjectCanvas 直达画布;
  顺带审视 sample 内容质量(节点/连线/泳道像不像样)。验收:空库首页两按钮;测试补 finder。

### ON-3 无 ffmpeg 降级提示(S–M,排导出 UI 合入后)
- 设置页 About 区仿"安全存储探测"模式加 ffmpeg 状态行(读 ffmpegLocatorProvider:找到=路径/
  未找到=平台安装指引);错误文案细分(`errorFfmpegNotFound` 键,mac=brew/win=winget + INKFRAME_FFMPEG 兜底)。
  注意与导出 UI 的 ffmpeg 文案收口协调,避免双源。

### ON-4 网络错误文案走查(S,并入 I18N pass)
- `settingsApiKeySavedUnverified`/`errorNetwork*` 双语措辞确认区分"网络不可达 vs key 无效"。

### ON-5 空态/错误态 golden 固化(S)
- 四屏空态 golden(Studio empty/error、Canvas empty、Gallery empty、Settings)入 CI 防回归。

## 2. 已知缺口

### GAP-1 设置页 Custom Provider 编辑 UI(L)
- 为什么:手编 json+重启是 BYO-key 主打定位的体验硬伤。
- 涉及:新 `settings/widgets/custom_providers_section.dart`;`custom_providers_file_service.dart`
  补写侧(序列化回写,校验规则已有);settings_screen 挂载;ARB `settingsCustomProviders*`。
- 怎么做(**守住"重启生效"边界,不碰 registry 变异深水区**):列表+5 字段表单对话框
  (校验即 PROVIDER-API §13.1:id 正则/base_url 无 query/模板白名单下拉)+删除确认;保存后显示
  「重启后生效」warning 条。**顺带修**:API Keys 行对 `custom:*` 显示 capabilities.displayName。
- 验收:不碰 json 完成增删改;非法输入内联报错;重启后下拉出现;损坏 json 不崩;
  fake CustomProviderSource 的 widget 测试。
- 风险:为后续"运行时增删"留接口,本卡明确不做热生效。

### GAP-2 软删项目回收站 UI(M)
- 仓储 restore/listTrashed 已就绪;sidebar ARCHIVE 死行一起还。点 ARCHIVE→已删项目列表
  (菜单:恢复;首版不做永久删除并在卡里显式排除——涉磁盘产物清理策略)+ `_ManageCanvasesDialog`
  加已删画布折叠段。验收:删→计数+1→恢复→回网格;controller+widget 测试;硬编码 '0' 消灭。

### GAP-3 AsyncValue error 态统一(M)
- 新共享件 `theme/components/ink_async_slot.dart`(封装 .when:error=一行 danger caption+retry,
  loading=紧凑)逐点替换 §0.13 全清单;只改 widget 消费侧(providers 内乐观快照是另一条并发债)。
- 验收:override 抛 InkError 的逐文件 error 态断言;上述文件 `valueOrNull ?? const []` 清零。

### GAP-4 batch slot error 可读化(S)
- error tile 包 Tooltip(errorCode→l10nError,未知退 errorUnknown)+一行 danger caption;
  排 GAP-3 后(同文件)。

### GAP-5 Gallery 视频缩略图+播放(M)
- gallery_tile 视频分支接 thumbnailServiceProvider(模式抄 video_node_body);点击复用
  showVideoLightbox;时长写侧若超范围单列小卡(features 规划有对应卡)。
  验收:缩略显示、可播;fake ThumbnailService 测试;真机人工回归(media_kit 测试环境限制)。

### GAP-6 导出接续:narrative 链自动排序(登记,导出 UI 合入后立项)
- 导出片段顺序按 shot→video narrative 边拓扑排序预填;与序列预览共享逻辑。

### GAP-7 Inspector widget 测试欠账(S–M)
- BOARD 行 92:预设点选应用 + 成本文案断言,仿同文件参考图区/角色区测试模式补齐。

### GAP-8 渲染队列取消入口(M,**建议提级上线前**)
- 为什么:跑错 prompt 的长视频任务只能干等烧钱;后端全齐只差 UI。
- 怎么做:canvas_render_queue 的 _JobRow 非终态加 cancel icon(实现参考未挂载的
  job_queue_panel.dart:234-261);**顺带处置 JobQueuePanel:挂载或删除**(死代码;删则 BOARD
  P1-x2 错误映射双源债自动清);失败行保留 N 秒或加"最近失败"折叠段。
- 验收:running 可取消→cancelled→slot 遵守"保留已成功"拍板;widget 测试 override jobsRegistry。

## 3. 画布方向:不是选型,是 V1 保真度收口

**纠正过时认知**:`docs/ui-mockups/index.html` 明标 "Selected: V1 · Amber Noir",附 80KB spec
(canvas-v1-amber-noir-spec.html,14 节);**代码已经就是 Amber Noir**(tokens 三变体/字体/组件族/
frameless chrome 全落地)。V3/V4/V5 换装成本 XL 且与既定反毛玻璃语言冲突,勿再开选型会。

**真正的决策项(→ MASTERPLAN 决策区 D-7,逐项拍板)**:
- d1 Inspector 形态:spec 提议浮动面板 vs 现状固定 320px 右栏。
- d2 节点类型色条(spec §03 的 4px 顶条 type→色映射)批准与否。
- d3 camera 运镜:按 provider 真实能力填表(需查各 API 文档)vs 维持隐藏并从 spec 撤控件。
- d4 左工具栏 8 死图标:A=按 spec 实装第一批(select/pan,联动 PL-2)/ B=裁到只留有功能的。
  **不允许死按钮上线**。
- d5 顶栏死件:⌘K(做真=PL-1/摘牌)、▶(=序列预览入口,属 M4,先裁)、avatar(裁或 tooltip)。
- d6 sidebar footer 4 icon + '+':定义或裁(ARCHIVE 行由 GAP-2 激活,footer settings 可指设置页)。
- d7 text 节点:补全(作 prompt 素材节点,image inspector 已消费其内容)或从语义中确认移除。

**落地切片**:
- CV-1 死件清理(S,**上线前必做**,d4-B/d5/d6 裁撤路径):删/藏一切无功能可交互元素;
  验收可写 quality 测试扫空 onTap。
- CV-2 节点类型色条(S–M,d2 批准后):单一 lookup 进 `canvas/util/`。
- CV-3 Inspector 形态落定(M 浮动/0 维持)。
- CV-4 左工具栏实装第一批(M–L,d4-A 时):select/pan/add-node,其余裁;依赖 PL-2。
- CV-5 视口 chrome(M,不含 minimap):zoom % 指示+[-][+][fit](TransformationController 提升);
  minimap 后置(L)。

## 4. 打磨

### PL-1 命令面板做真或摘牌(M 做真 / S 摘牌,与 CV-1 联动二选一)
- 做真版:app 级 Shortcuts/Actions,⌘K/Ctrl+K 弹搜索 Dialog;首版动作写死 ≤6 个
  (新建项目/打开画布/设置/画布内新建节点)。

### PL-2 画布快捷键基建+第一批(M)
- canvas_screen 包 CallbackShortcuts:Delete/Backspace=删除选中(走 PL-4a 语义)、Esc=退 link 模式/
  清选中、⌘A 全选、⌘+/−/0 缩放(TransformationController 提升为成员/provider)、空格 pan 可后置。
- 验收:五组键位 sendKeyEvent 测试;**inspector 输入框聚焦时不劫持**(焦点链测试必须有——主要坑)。
- 依赖:PL-4a。

### PL-3 右键菜单(M,强烈建议尽早)
- 节点 onSecondaryTapUp→showMenu(删除/开始连线/result 节点查看);空白右键=在鼠标位新建节点
  (顺带优化 pickRandomNodePosition 体验)。与 InteractiveViewer 手势不冲突。

### PL-4a 删除防误伤垫层(S,**上线前必做**)
- 节点/边删除改「已删除 [撤销]」snackbar action(5 秒内调 repo restore——软删已支持,
  是真 undo 的最小子集)。涉及 canvas_view._handleNodeDelete、edge delete、node_card DeleteAnchor。

### PL-4b 通用 undo/redo 栈(XL,**上线后**,勿塞上线范围)
- command 模式逆操作栈,per-canvasId controller,⌘Z/⌘⇧Z 挂 PL-2;首版只覆盖 move/add/remove
  node/edge;inspector 字段不进栈。**前置依赖:canvas_nodes_controller 乐观快照并发债(BOARD 行 87)
  同窗修**,否则 undo 放大丢更新竞态。

### PL-5 多选群体操作(M):计数 chip 扩操作条(群删走 PL-4a);框选 marquee 独立 M 可后置。
### PL-6 窗口状态记忆(S–M):偏好加 windowBounds/maximized(手写类,勿 freezed);teardown 时
  getBounds 一次写入;启动 clamp 到可见显示器(越界退默认,单测覆盖多显示器坐标)。
### PL-7 焦点环第一步(M,上线后首迭代):设计系统组件统一 FocusableActionDetector+focusRing
  border(约 7 个文件);Tab 遍历 Studio 顶栏链路;golden 一张 focused 态。
### PL-8 文件拖入画布(M–L,上线后):desktop_drop 依赖需评审;与 gallery"拖入画布"切片统一设计。

## 5. i18n pass 建议
- 上线前一次人工全量走读(2–3h,S):错误文案有无下一步动作、中英语气、带参键语序、标点风格;
  本轮各卡新键(约 30–60 个)合入后集中第 2 遍,不逐卡审。
- 不做:provider displayName 翻译(有意决策)、快捷键符号进 ARB、第三语言。
- 顺带:标记僵尸键(不可达路径的键)。

## 6. 排序

**上线前必做**(阻断"陌生用户第一天"或伤可信度):
CV-1(先做,纯减法)→ ON-1+ON-2 → GAP-8(资金相关唯一缺口)→ PL-4a → PL-2+PL-1(二选一落定)
→ GAP-3+GAP-4 → GAP-1 → GAP-2 → PL-6 → ON-3(等导出 UI)+ON-4+i18n pass → GAP-7+ON-5(质量闸随窗)。

**上线后首迭代起**:PL-4b(等并发债)、CV-4/CV-5(minimap)、CV-2/CV-3(拍板后随时)、PL-3(尽早)、
PL-5 框选、PL-7、PL-8、GAP-5(视频用户多则提级)、GAP-6(等导出合入)、d3 camera 填表(独立轨道)。

**关键依赖链**:PL-4a → PL-2 → PL-5;CV-1 与 PL-1 先拍板;ON-3/GAP-6 等导出 UI;PL-4b 等 BOARD 行 87。
**风险**:与导出 UI 分支的文件冲突面(排其后);新偏好字段一律手写类避开 build_runner;
勿再为 5 版 mockup 开选型会。
