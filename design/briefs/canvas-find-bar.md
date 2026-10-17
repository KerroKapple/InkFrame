# canvas-find-bar · 画布内查找 Ctrl/⌘ F：工具条下方的查找条，↵ / Shift ↵ 循环跳转，命中描边、其余降到 35%
- 波次 W9 / lane A / 基底：origin/main（W0–W8 已合入）；依赖切片：esc-ladder（W0，Esc 层表 + 快捷键注册表）、canvas-view-split（W0，node_card_slot.dart）、app-action-table（W1，「查找」已登记为禁用）；media-import-service（W2）的 original_name 有则搜、没有就是空，不算依赖；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
在画布上按 Ctrl F（macOS ⌘F），工具条正下方居中弹出一条 300 宽的查找条；打字即在本画布已加载的节点里找标题、提示词、文本正文、镜头备注、导入文件名。
命中的卡片淡琥珀描边、当前那张实琥珀粗描边，其余卡片降到 35%；↵ 下一个、Shift ↵ 上一个，循环，每跳一个单选它并保持缩放移到视口中心。
Esc 关闭，选中停在当前项。⌘K 里「查找」从「即将推出」变为可用。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ImportSearch.dc.html` ›「画布内查找 · Ctrl/⌘ F，和 Ctrl K 分开」：
  - 浮在工具条下方居中；正在编辑文字时也接管。
  - 搜本画布已加载的图像 / 视频配置、镜头、文本、便签、产物：标题、提示词、文本 / 便签正文、shot_notes、导入文件名；不读库。
  - ↵ 下一个、Shift ↵ 上一个，循环；每跳一个单选它，保持缩放移到视口中心。
  - 命中淡琥珀描边（稿：1px washBorder）、当前实色（稿：2px accent），其余降到 35%；Esc 关闭，选中留在当前。
  - 条子样式（b2_import.js mockD）：300×34、s4 底、1px control 边、圆角 6、浮层阴影；左 10 右 4 内边距、间距 6；14 号搜索图标 fg5 | 输入 12 号 fg1 | 计数「2 / 3」等宽 10 号 fg4 | 1×18 control 竖线 | ↑ ↓ 两个 24×24 键（aria「上一个（Shift ↵）」「下一个（↵）」）| 24×24 关闭键（aria「关闭查找（Esc）」）。
  - 分工：Ctrl K 跨实体、选一个就关；Ctrl F 只看本画布、开着逐个过。
- `b2/project/KeyMap.dc.html` ›「Esc 阶梯」：菜单 > @ 弹层 > 查找条（关掉，选中留在当前）> 文字输入框失焦 > 进行中的手势 > 工具回到选择 > 清空选中；›「文字让位」：Ctrl F 属「另有去处」，焦点在输入框里也归画布查找；›「组合键」表：Ctrl F / ⌘F 画布内查找。
- `b2/project/GapsCanvas.dc.html` ›「画布轻提示胶囊」：查找条在顶部，与底部胶囊互不避让。
- 设计缺口：查找条与舞台顶部已有浮层（连线提示、多选计数、错误横幅都用 InkToolbarSize.stageTopInset）同一高度，画板没画叠放。本片定：查找条 top = stageTopInset，那些浮层不动（canvas_view 不归本片），重叠写进风险。
- 设计缺口：零命中时卡片要不要变暗没画。本片按规则字面走「非命中一律 35%」，计数位写「无结果」。
- 设计缺口：折叠泳道里的命中怎么跳没画。本片定：照样算命中，跳到它时先展开那条道再居中。
- 设计缺口：连线、泳道底色在查找时是否跟着变暗没画。本片只暗卡片。
- 设计缺口：画板卡片状态行写着「命中 · 提示词」「当前 · 文件名」，像是标注不是界面；本片不改状态行，命中字段只进模型（便于测试与读屏）。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/util/canvas_find_model.dart`（新）：纯函数 findHits + 命中标记枚举 + 计数文本无关的游标运算（next / previous / clamp）。
- `lib/features/canvas/providers/canvas_find_controller.dart`（新）：每画布一份查找状态（开没开、查询、当前下标、是否已跳过）；派生的 canvasFindViewProvider。
- `lib/features/canvas/widgets/canvas_find_bar.dart`（新）：条子本体（输入框、计数、↑ ↓、关闭），↵ / Shift ↵ 在框内自己接。
- `lib/features/canvas/widgets/canvas_screen.dart`：舞台 Stack 里在工具条之后加一个 `Positioned(top: InkToolbarSize.stageTopInset, left: 0, right: 0, child: Center(child: CanvasFindBar(...)))`，只在开着时画。
- `lib/features/canvas/widgets/node_card_slot.dart`（canvas-view-split 新建）：`.select` 订阅本节点的查找标记；dimmed 时外包 AnimatedOpacity（InkMotion.fast）；把 hit / current 传给 NodeCard。
- `lib/features/canvas/widgets/node_card.dart`：新增可选参数 `findMark`（默认 none）；图区外圈描边按「current > selected > hit > 默认」取色与粗细。
- `lib/features/canvas/util/escape_ladder.dart`（esc-ladder 新建）：在「查找条」登记口填上 active = 查找条开着、dismiss = 关闭查找（以落地为准）。
- `lib/features/canvas/widgets/shortcuts/find_keys.dart`（新）：CanvasFindIntent + 激活键 + Action；`canvas_shortcut_registry.dart` 追加一行。
- `lib/features/app_actions/app_action_catalog.dart`（app-action-table 新建，注册表例外）：「查找」那一行 isEnabled 改为「有当前画布」、run 改为打开查找条（只改这一行）。
- `lib/theme/tokens.dart`（只追加常量）：`InkFindBarSize { width = 300; height = 34; button = 24; currentOutline = 2 }`、`InkOpacity { findDimmed = 0.35 }`。
- 测试：见「测试」小节的 5 个新文件。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- `lib/features/canvas/widgets/canvas_view.dart`（W9 归 os-drop-paste-image）；`widgets/shortcuts/clipboard_keys.dart`、`util/canvas_paste_actions.dart`、新 `os_file_drop_overlay.dart` / `import_drop_summary.dart` / `canvas_import_drop_actions.dart`（os-drop-paste-image）。
- `widgets/canvas_inspector_panel.dart`、`image_config_inspector.dart`、`video_config_inspector.dart`（multi-select-inspector）。
- `widgets/character_library_panel.dart`、`util/ref_image_budget.dart`（rail-drag-characters）；`widgets/left_rail/outline_panel.dart`、`providers/canvas_nodes_controller.dart`、`models/canvas_command.dart`（outline-rename-menu）。
- `pubspec.yaml`、`pubspec.lock`、平台插件注册文件（dep-drop-pasteboard）；`lib/storage/repositories/postgres_job_repository.dart`（job-eta）；`lib/features/generation/services/`（batch-run-planner）。
- `util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_menu/blank_menu_entries.dart`、`widgets/canvas_shortcuts.dart`（骨架；注册表除追加一行外）、`lib/features/settings/util/shortcut_catalog.dart`（从注册表取文案，不用改）、`widgets/canvas_toolbar.dart`（「更多 › 查找」等 W18 more-dropdown-panel）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：rail-drag-characters：`lib/features/canvas/widgets/characters_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/canvas_find_model.dart
enum CanvasFindField { label, prompt, text, shotNotes, originalName }
enum CanvasFindMark { none, hit, current, dimmed }
typedef CanvasFindHit = ({String nodeId, CanvasFindField field});
/// 搜索键：label（非空原文）、type_config 的 'prompt' / 'text' / 'shot_notes' / 'original_name'；
/// 查询去首尾空白、不区分大小写的包含匹配；一张卡只出一条命中（按上面字段顺序取第一个命中的字段）；
/// 排序 (position.dx, position.dy, id)，与 narrative_order 的位置序同口径。空查询 ⇒ 空表。
List<CanvasFindHit> findHits(List<CanvasNode> nodes, String query);
int findStep(int current, int length, {required bool forward}); // 循环
CanvasFindMark findMarkOf(String nodeId, CanvasFindView view);

// providers/canvas_find_controller.dart
@immutable class CanvasFindState { bool open; String query; String? currentId; bool revealed; }
final canvasFindControllerProvider = AutoDisposeNotifierProviderFamily<CanvasFindController, CanvasFindState, String>;
class CanvasFindController { void open(); void close(); void setQuery(String q); void next(); void previous(); }
@immutable class CanvasFindView { bool active; List<CanvasFindHit> hits; String? currentId; int currentIndex; }
final canvasFindViewProvider = AutoDisposeProviderFamily<CanvasFindView, String>; // watch 节点控制器 + 查找状态

// widgets/canvas_find_bar.dart
class CanvasFindBar extends ConsumerStatefulWidget { const CanvasFindBar({super.key, required String canvasId});
  static const Key fieldKey; static const Key countKey; static const Key prevKey; static const Key nextKey; static const Key closeKey; }

// widgets/shortcuts/find_keys.dart
class CanvasFindIntent extends Intent { const CanvasFindIntent(); }
// macOS 主键 ⌘F、Windows 主键 Ctrl+F：主键不对文字让位；另一平台的变体走 esc-ladder 的文字让位 Action（核对真名）。
const SingleActivator findMeta = SingleActivator(LogicalKeyboardKey.keyF, meta: true, includeRepeats: false);
const SingleActivator findControl = SingleActivator(LogicalKeyboardKey.keyF, control: true, includeRepeats: false);
```
跳转（next / previous / 打开后首次 ↵）落地：单选目标（`canvasSelectionControllerProvider.select`）+ 居中走 `left_rail/left_rail_actions.dart` 的 `focusNodeOnCanvas`（内部即 viewport_focus 的 nodeStageRect + transformCenteringRect，缩放不变）；目标在折叠泳道里先 `laneCollapseProvider(canvasId).notifier.toggle(laneId)`。
状态机：closed →（Ctrl F / ⌘K）→ open(query 保留上次, revealed=false) →（打字）→ currentId = 第一条命中、revealed=false、不动相机 →（↵）首次 = 跳到 current，此后 = 下一条 →（Esc / ×）→ closed：current 存在就单选它（不动相机），焦点还给画布（CanvasShortcuts.reclaimFocus）。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. Ctrl F（Windows）/ ⌘F（macOS）在画布可见时打开查找条并让输入框持焦、全选已有文字；已开着再按 = 回到输入框并全选，不开第二条。
2. 焦点在提示词条 / 检查器文本框里按主键（mac ⌘F、Win Ctrl F）也接管：焦点移进查找框，原文本框内容不变。macOS 上 Ctrl F 在文本框里仍归文本框（emacs 前移一格），不开查找条。
3. 画布不可见（别的标签）或没有当前画布时按键不响应；⌘K「查找」在没有画布时置灰，原因沿用表里的禁用原因字段。
4. 搜索只读 `canvasNodesControllerProvider(canvasId)` 的内存节点，不调任何仓储（测试用计数 fake 断言 0 次读库）。
5. 匹配字段：label（为空时不按类型名匹配）、prompt、text（含便签正文）、shot_notes、original_name；不区分大小写；查询只含空白 = 空查询：无命中、不变暗、计数位空。
6. 命中按 (dx, dy, id) 排；计数显示「当前序号 / 总数」，零命中显示「无结果」。
7. ↵ / ↓ 键：未跳过时跳到当前（第 1 条），之后下一条，到尾回到第 1 条；Shift ↵ / ↑ 键反向，未跳过时跳到最后一条。每跳一次单选目标、保持缩放把它移到视口中心。
8. 输入法正在组字（composing 有效）时 ↵ 只确认组字，不跳转（中文输入法 mac / Win 都要测）。
9. 变暗：查找条开着且查询非空时，非命中卡 35%（AnimatedOpacity 120ms，减弱动效时 0ms）；命中 1px accentWashBorder；当前 2px accent（盖过选中的 1px accent）。关闭后全部恢复。
10. 节点在查找中被删除 / 新增 / 改名：命中实时重算；当前项还在命中里就保持，不在了就落到原位置之后的下一条（没有就第 1 条），revealed 不变。
11. 输入只引起标记翻转的那几张卡重建（`.select`），其余卡不重建（重建计数断言）。
12. Esc 顺序：@ 弹层 > 查找条 > 框选进行中 > 工具锁 > 清空选中。查找框持焦时 Esc 关闭查找条（不只是失焦）；菜单开着时第一下 Esc 先关菜单，查找条还在。
13. 关闭（Esc / ×）后：选中 = 当前项（若有）；无命中则选中不变；焦点回画布；状态 open=false，查询保留，下次打开预填并全选。
14. 换画布：查找状态按 canvasId 分家，新画布查找条关着；回到原画布若仍开着（同一会话）照旧显示。
15. 折叠泳道里的命中：跳到它时先展开那条道再居中；变暗规则对折叠道里看不见的卡无副作用。
16. 查找不进撤销栈：跳转只改选中和相机，Ctrl Z 不撤回跳转；查找条开着时 Ctrl Z 在查找框里归文本框。
17. 查找条不进 Tab 遍历以外的特殊链；Tab 在查找框里按默认焦点遍历走到 ↑ ↓ ×。
18. 读屏：查找框 semantics 标签用提示文案；计数变化以 polite 播报「当前 / 总数」或「无结果」。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| canvasFindHint | Find on canvas… | 在画布中查找… |
| canvasFindCount（current:int, total:int） | {current} / {total} | {current} / {total} |
| canvasFindNoResults | No results | 无结果 |
| canvasFindPrevious | Previous (Shift ↵) | 上一个（Shift ↵） |
| canvasFindNext | Next (↵) | 下一个（↵） |
| canvasFindClose | Close find (Esc) | 关闭查找（Esc） |
| shortcutCanvasFind（注册表文案；若 W1 动作表已有「查找」键则复用、不加） | Find on canvas | 画布内查找 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/canvas_find_model_test.dart`（新）
  - 「五个字段都能命中」：label / prompt / text / shot_notes / original_name 各一张卡，断言 5 条且 field 对应。
  - 「不区分大小写、去首尾空白；空白查询 ⇒ 空」。
  - 「label 为空不按类型名匹配」：查「图像」不命中无标题图像卡。
  - 「一张卡多字段命中只出一条，取 label 优先」。
  - 「按 (dx, dy, id) 排序」：乱序输入，断言顺序。
  - 「findStep 循环」：(2,3,forward) ⇒ 0；(0,3,back) ⇒ 2；length 0 ⇒ -1。
- `test/features/canvas/providers/canvas_find_controller_test.dart`（新）
  - 「打字后 current = 第一条、revealed=false」；「首次 next 不前进只揭示」；「previous 未揭示 ⇒ 最后一条」。
  - 「当前项被删 ⇒ 落到下一条」；「节点改名后命中重算」。
  - 「不读库」：计数 NodeRepository fake，开查找、打字、跳转后 listByCanvas 调用次数不增加。
  - 「close 后选中 = current；无命中选中不变」。
- `test/features/canvas/widgets/canvas_find_bar_test.dart`（新）
  - 「Ctrl F 打开、输入框持焦」（Windows 平台覆盖）与「⌘F 打开」（macOS 覆盖）。
  - 「提示词条持焦时 Ctrl F 也接管」：焦点移到 fieldKey。
  - 「macOS 文本框里 Ctrl F 不开查找条」。
  - 「↵ 跳下一个：选中变化且相机平移、缩放不变」；「Shift ↵ 反向」；「组字中 ↵ 不跳」。
  - 「零命中显示无结果」；「计数 2 / 3」。
  - 「Esc 关闭、选中停在当前、焦点回画布」；「菜单开着时第一下 Esc 只关菜单」。
- `test/features/canvas/widgets/node_card_find_mark_test.dart`（新）
  - 「hit = 1px accentWashBorder；current = 2px accent；current 盖过 selected」。
  - 「dimmed 卡 Opacity 0.35；查询为空不变暗」；「输入只重建标记翻转的卡」（计数 builder）。
- `test/features/canvas/util/escape_ladder_find_test.dart`（新）：「查找层排在 @ 层之后、框选层之前」；「查找条开着时 active=true，dismiss 后 false」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. find_keys 主键的 Action 改成对文字让位（用 esc-ladder 的文字让位 Action）⇒「提示词条持焦时 Ctrl F 也接管」红。
2. findHits 去掉 original_name 字段 ⇒「五个字段都能命中」红。
3. 排序改成按 id ⇒「按 (dx, dy, id) 排序」红。
4. findStep 去掉取模（到尾停住）⇒「findStep 循环」红。
5. 跳转里的 focusNodeOnCanvas 换成只 select ⇒「↵ 跳下一个：相机平移」红。
6. 去掉 composing 判断 ⇒「组字中 ↵ 不跳」红。
7. node_card 里 current 与 selected 的优先级对调 ⇒「current 盖过 selected」红。
8. InkOpacity.findDimmed 用处换成 1.0 ⇒「dimmed 卡 Opacity 0.35」红。
9. node_card_slot 改为 watch 整个 CanvasFindView（不 select）⇒「输入只重建标记翻转的卡」红。
10. escape_ladder 里查找层挪到框选层之后 ⇒ 层序单测红。
11. close() 去掉「选中 = current」⇒「Esc 关闭、选中停在当前」红。
12. 控制器里加一次 nodeRepository.listByCanvas ⇒「不读库」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑 `flutter analyze lib test`、`flutter test test/features/canvas --exclude-tags golden`，逐条做上面的变异。
- 截图（CanvasScreen + ProviderScope 覆盖内存仓储，一条水平泳道、三张卡：「镜头 01 · 拂晓」提示词含「雾江」、导入产物 original_name「雾江.jpg」、「镜头 03 · 远山」不含）：
  1. 查找条刚打开、空查询；2. 查「雾江」、计数「1 / 2」、未跳；3. 按两次 ↵ 后「2 / 2」、当前为导入卡、第三张 35%；4. 查「zzz」无结果；5. Esc 后条子消失、导入卡被选中。

## 风险与不确定
- esc-ladder / app-action-table / canvas-view-split 的真实 API 名以落地为准（登记口形状、文字让位 Action 的名字、动作表的 isEnabled/run 字段）；本片只按「每层 active/dismiss」「表里只改一行」去接。
- 查找条与舞台顶部浮层（连线提示、多选计数、错误横幅）同 top，会叠；改那些浮层要动 canvas_view.dart（W9 归 os-drop-paste-image），留给后续片或主 Agent 合入后微调。
- Windows 上 Ctrl F 在查找框外的 Material 文本控件里无默认绑定，接管安全；macOS 主键 ⌘F 在系统层没有冲突。若主 Agent 要求两个修饰键都「文字里接管」，只改 find_keys 一处。
- 「更多 › 查找 Ctrl F」要等 W18 more-dropdown-panel，本片不碰 canvas_toolbar.dart。
- node_card.dart 是最长热点链（W8 disabled → 本片 → W14 note-variant），本片只加一个可选参数和描边取色，rebase 时注意与 W8 停用样式（降透明）叠加：停用 + 变暗取两者乘积，不另加规则。
