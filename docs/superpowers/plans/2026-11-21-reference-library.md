# 参考库（素材页第三段）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> 本仓库的执行方式：生成型 executor 只写代码、提交，不跑任何 flutter / dart 命令；主会话集中跑 analyze、测试和变异实测（全局 CLAUDE.md 第 2 节）。下面每个任务里的「运行」步骤由主会话执行。

**Goal：** 在画布左栏素材页加上第三段「参考库」，用来浏览本机的 ai-pose-gallery-zh 图库。点一张图可以当参考连到选中的那一镜（同类别替换），也可以只放进画布，人像还能存为角色。

**Architecture：** core 层放值对象和读取接口；services 层是 ai-pose-gallery-zh 格式的读取适配器（在后台 isolate 里解析 JSON）；core/di 负责把偏好设置里的文件夹路径接成条目 provider。features/canvas 里，可用判据和替换规则都是纯函数，动作只调现有的导入、连线、角色接口；面板只加一个分段。

**Tech Stack：** Flutter / Dart、Riverpod（手写 provider）、file_selector（`getDirectoryPath`）、flutter_test。

**Spec：** `docs/superpowers/specs/2026-11-21-reference-library-design.md`

## Global Constraints

- 图片不进仓库、不进安装包；测试 fixture 只放几条假 JSON 和 1×1 的 PNG。
- 只读 `data/pose-zh.json`、`data/portrait-zh.json`、`data/costume-zh.json`、`data/costume-shisei-zh.json`。动漫服装、CharaDB、深度图都不读。
- 成人向默认隐藏：pose 的 `体系` ∈ {`全身单人・性感系`, `双人缠绵`}；costume 的 `分类` ∈ {`内衣・睡衣`, `性感穿搭`}。不做开关。
- 不改数据库 schema、不写迁移。偏好设置新键是 `reference_library_root`（字符串，可为空）。
- 导入节点的 `type_config` 新增两个键：`reference_item_id`、`reference_category`，取值 `pose` / `portrait` / `costume`。
- 「当参考」只对**图像或视频配置节点**可用，并且当前服务商要收参考图（`maxRefImages > 0`）、配额没满（同类别替换不判配额）。
- 同一配置节点上每个类别最多一张参考库图，换一张 = 在一个事务里删旧边、建新边（`applySplice`）。旧节点不删。
- 所有界面文案走 ARB，中英两份同时改，跑 `flutter gen-l10n` 并提交生成物。不写内联颜色、字号、间距，一律用 token。
- JSON 字段名（中文）作为协议字面量放进常量，不进 ARB。条目名、分类名属于内容数据，原样显示。
- 错误一律走 InkError 子类，不 `catch (e)` 兜底。
- 代码注释用中文。

## Review Focus

1. **文件夹是图库的上一级或下一级**（用户选成 `D:\Projects\reference-libraries`，或选成 `…\ai-pose-gallery-zh\data`）：应当显示「这个文件夹里没找到参考库」并给「重新选择」，不能显示一个空网格。由 Task 2 的 `notALibrary` 用例和 Task 6 的空态用例钉住。
2. **JSON 里路径是正斜杠**（`thumbs/costume/SPR-0001.webp`），在 Windows 上拼接要得到能打开的路径：Task 2 用 `p.joinAll(root, ...relative.split('/'))` 拼，并加用例断言 `File(item.originalPath).existsSync()`（fixture 里放真文件）。
- 3. **选中的节点在点菜单的这一刻被删了，或者画布换了**：动作开头重新按 id 取节点，取不到就出「目标已不在」卡，不导入。由 Task 5 用例钉住。
- 4. **同一张图第二次「当参考」**：什么也不改，出胶囊「已经是这张」。由 Task 4 的纯函数用例和 Task 5 的动作用例钉住。
- 5. **一个类别的 JSON 坏了**（例如 costume-zh.json 被截断）：其余类别照常显示，只记一条 warn。由 Task 2 用例钉住。

---

### Task 1：值对象和读取接口

**Files:**
- Create: `lib/core/models/reference_item.dart`
- Create: `lib/core/interfaces/reference_library_reader.dart`
- Modify: `lib/core/constants/import_keys.dart`（加两个键和三个取值）

**Interfaces:**
- Produces:
  - `enum ReferenceCategory { pose, portrait, costume }`（`.name` 就是写进 type_config 的取值）
  - `@immutable class ReferenceItem { const ReferenceItem({required String id, required ReferenceCategory category, required String name, required String group, String? angle, required String thumbPath, required String originalPath, required String searchText}); }`：手写值对象，带 `==` / `hashCode`。路径是绝对路径；`group`：pose 取 `分类`，portrait 取 `分区`，costume 取 `分类`；`angle` 只有 pose 有。
  - `sealed class ReferenceLibraryLoad`，两个子类：`ReferenceLibraryLoaded(List<ReferenceItem> items, List<String> skippedFiles)` 和 `ReferenceLibraryNotFound()`。
  - `abstract class ReferenceLibraryReader { Future<ReferenceLibraryLoad> load(String rootPath); }`
  - `ImportKeys.referenceItemId = 'reference_item_id'`、`ImportKeys.referenceCategory = 'reference_category'`

- [ ] **Step 1：** 写上面这些类型，不写测试（纯数据声明，由 Task 2、Task 4 的测试覆盖）。
- [ ] **Step 2：** 提交 `feat(reference-library): 值对象与读取接口`。

### Task 2：ai-pose-gallery-zh 读取适配器

**Files:**
- Create: `lib/services/reference_library/ai_pose_gallery_zh_keys.dart`（JSON 字段名、文件名、成人向分类常量）
- Create: `lib/services/reference_library/ai_pose_gallery_zh_reader.dart`
- Create: `test/fixtures/reference_library/ok/data/{pose-zh,portrait-zh,costume-zh,costume-shisei-zh}.json` 以及它们引用到的 `img/…`、`thumbs/…` 小 PNG
- Create: `test/fixtures/reference_library/broken_costume/`（pose 正常，costume-zh.json 内容是截断的 JSON）
- Test: `test/services/reference_library/ai_pose_gallery_zh_reader_test.dart`

**Interfaces:**
- Consumes：Task 1 的全部类型。
- Produces：`class AiPoseGalleryZhReader implements ReferenceLibraryReader { AiPoseGalleryZhReader({required InkLogger logger}); }`

fixture 内容：pose 4 条（`全身单人・标准系` 正面、`全身单人・标准系` 侧面、`全身单人・性感系`、`双人缠绵` 各一条），portrait 2 条，costume 3 条（`春季穿搭`、`内衣・睡衣`、`性感穿搭` 各一条），shisei 1 条。shisei 的图片路径取 `原图`，没有的话取 `预览图`。

- [ ] **Step 1：写失败的测试**
  - `load(ok)`：返回 `ReferenceLibraryLoaded`；pose 2 条（性感系、双人缠绵被滤掉），portrait 2 条，costume 2 条（春季 + shisei）；`skippedFiles` 为空。
  - pose 条目：`name` = `姿势名称`，`group` = `分类`，`angle` = `角度`，`searchText` = `检索`。
  - 每一条的 `originalPath`、`thumbPath` 都是绝对路径，并且 `File(...).existsSync()` 为 true（Review Focus 2）。
  - `load(broken_costume)`：pose 照常，costume 0 条，`skippedFiles` 包含 `costume-zh.json`，logger 记了一条 warn（Review Focus 5）。
  - `load(<空临时目录>)` 和 `load(ok/data)`（选成了下一级）：都返回 `ReferenceLibraryNotFound`（Review Focus 1）。
  - `load(<不存在的路径>)`：返回 `ReferenceLibraryNotFound`，不抛异常。
- [ ] **Step 2：** 主会话运行 `flutter test test/services/reference_library/`，预期 FAIL（类不存在）。
- [ ] **Step 3：实现**。用 `Isolate.run` 读文件并解析（isolate 里只做纯解析，返回可传递的数据；logger 留在主 isolate）。路径用 `p.joinAll(<String>[root, ...rel.split('/')])` 拼。字段缺失或类型不对的单条记录跳过，不算整个文件坏。
- [ ] **Step 4：** 主会话运行同一命令，预期 PASS。
- [ ] **Step 5：** 提交 `feat(reference-library): ai-pose-gallery-zh 读取适配器`。

### Task 3：偏好设置和 DI

**Files:**
- Modify: `lib/core/models/app_preferences.dart`（字段 `referenceLibraryRoot`，键 `reference_library_root`；`copyWith` 加参数 `referenceLibraryRoot`；`toMap` / `fromMap` / `==` / `hashCode` / `toString` 都要加）
- Create: `lib/core/di/reference_library.dart`
- Test: `test/core/models/app_preferences_test.dart`（在原文件里加用例）、`test/core/di/reference_library_test.dart`

**Interfaces:**
- Consumes：Task 1、Task 2。
- Produces:
  - `final referenceLibraryReaderProvider = Provider<ReferenceLibraryReader>(...)`
  - `typedef ReferenceFolderPicker = Future<String?> Function();` 和 `final referenceFolderPickerProvider = Provider<ReferenceFolderPicker>(...)`（用 `getDirectoryPath()`，取消时返回 null）
  - `final referenceLibraryRootProvider = NotifierProvider<ReferenceLibraryRootController, String?>(...)`：`build()` 读 `preferencesServiceProvider.current.referenceLibraryRoot`；`Future<void> set(String path)` 写偏好设置并更新 state。
  - `final referenceLibraryProvider = FutureProvider<ReferenceLibraryLoad?>(...)`：root 为 null 时返回 null，否则 `reader.load(root)`。它 watch root，所以换文件夹就会重读。

- [ ] **Step 1：写失败的测试**
  - AppPreferences：`fromMap({'reference_library_root': 'D:/x'})` 往返后值不变；缺这个键时为 null；值不是字符串时为 null。
  - DI：用 `InMemoryPreferencesService` 和 fake reader 覆盖。root 为 null 时 `referenceLibraryProvider` 是 null；调 `set('D:/lib')` 之后 reader 收到 `'D:/lib'`，偏好设置里也存下了它。
- [ ] **Step 2：** 主会话运行这两个测试文件，预期 FAIL。
- [ ] **Step 3：** 实现。
- [ ] **Step 4：** 主会话运行，预期 PASS。
- [ ] **Step 5：** 提交 `feat(reference-library): 偏好设置键与 DI`。

### Task 4：纯函数（筛选、可用判据、替换规则）

**Files:**
- Create: `lib/features/canvas/widgets/left_rail/reference_library_model.dart`
- Test: `test/features/canvas/widgets/left_rail/reference_library_model_test.dart`

**Interfaces:**
- Consumes：Task 1 的类型；现有的 `CanvasNode`、`CanvasEdge`、`ProviderCapabilities`、`configProviderCandidates`、`resolveConfigProviderId`、`ImportKeys`。
- Produces:
  - `List<ReferenceItem> filterReferenceItems(List<ReferenceItem> all, {required ReferenceCategory category, String query = '', String? angle})`：query 先 trim；为空就不过滤，否则按 `searchText.contains` 匹配，大小写不敏感。
  - `Map<ReferenceCategory, int> referenceCounts(List<ReferenceItem> all, {String query = ''})`
  - `List<String> referenceAngles(List<ReferenceItem> all)`：pose 里实际出现的角度，按首次出现的顺序排。
  - `enum ReferenceAttachBlock { noSelection, notConfig, providerNoRefs, budgetFull }`
  - `typedef ReferenceAttachPlan = ({String targetNodeId, Set<String> replaceEdgeIds, bool alreadyAttached});`
  - `({ReferenceAttachBlock? block, ReferenceAttachPlan? plan}) planReferenceAttach({required ReferenceItem item, required Set<String> selectedIds, required List<CanvasNode> nodes, required List<CanvasEdge> edges, required List<ProviderCapabilities> capabilities, required String? lastUsedImageProviderId, required String? lastUsedVideoProviderId})`

  判据，按顺序判：
  1. 选中数不是 1，或者选中的 id 在 `nodes` 里找不到 ⇒ `noSelection`。
  2. 选中的不是 `role == config` 且 `type ∈ {image, video}` ⇒ `notConfig`（shot 也算这一种）。
  3. 用 `resolveConfigProviderId(savedProviderId: typeConfig['provider_id'], lastUsed…, candidates: configProviderCandidates(type, capabilities))` 算出服务商，它的 `maxRefImages <= 0`，或者找不到这个服务商 ⇒ `providerNoRefs`。
  4. 目标的在世 data/reference 入边里，源节点 `typeConfig[ImportKeys.referenceCategory] == item.category.name` 的边构成 `replaceEdgeIds`。其中某条源节点的 `reference_item_id == item.id` ⇒ `alreadyAttached = true`。
  5. `replaceEdgeIds` 为空，且现有 data/reference 入边数 ≥ `maxRefImages` ⇒ `budgetFull`。只按边数算，与生成侧截断同一口径；角色图的配额在检查器里另外提示，这里不重复算。

- [ ] **Step 1：写失败的测试**。每个 block 一条用例：shot 节点 ⇒ `notConfig`；默认服务商 `gemini-image` ⇒ `providerNoRefs`；`wanx-image`（上限 1）且已有一条普通参考边 ⇒ `budgetFull`；`wanx-image` 且已有一条 pose 参考库边 ⇒ plan 的 `replaceEdgeIds` = {那条}，不报 `budgetFull`；同一 `reference_item_id` ⇒ `alreadyAttached`；costume 参考库边不在 pose 的替换集里。另外筛选：query 大小写、angle、counts。
- [ ] **Step 2：** 主会话运行，预期 FAIL。
- [ ] **Step 3：** 实现。
- [ ] **Step 4：** 主会话运行，预期 PASS。
- [ ] **Step 5：** 提交 `feat(reference-library): 筛选与当参考判据`。

### Task 5：三个动作

**Files:**
- Create: `lib/features/canvas/widgets/left_rail/reference_item_actions.dart`
- Test: `test/features/canvas/widgets/left_rail/reference_item_actions_test.dart`

**Interfaces:**
- Consumes：Task 4 的 `planReferenceAttach`；现有的 `mediaImportControllerProvider(canvasId).importFiles(projectId:, requests:)`、`canvasNodesControllerProvider(canvasId).notifier.patchTypeConfigMany`、`canvasEdgesControllerProvider(canvasId).notifier.applySplice(SplicePlan(...))`、`charactersControllerProvider(projectId).notifier.createFromImage(name:, sourceAbsolutePath:)`、`viewportCenteredNodeOrigin`、`kNodeCardSize`、`kResultColumnGap`、`InkNameDialog`、通知卡（`toastServiceProvider`）、胶囊（`canvasCapsuleProvider`）。
- Produces:
  - `Future<void> placeReferenceOnCanvas(WidgetRef ref, {required String canvasId, required String projectId, required ReferenceItem item})`
  - `Future<void> attachReferenceToSelected(WidgetRef ref, {required String canvasId, required String projectId, required ReferenceItem item})`
  - `Future<void> saveReferenceAsCharacter(BuildContext context, WidgetRef ref, {required String projectId, required ReferenceItem item})`

行为：
- 放置：`importFiles` 导入 `item.originalPath`，落点 = `viewportCenteredNodeOrigin`，`laneId` 为 null。导入成功后对新节点调 `patchTypeConfigMany`，写入两个标记键。被跳过（文件不存在、读不出来）⇒ 出错误卡。
- 当参考：
  1. 先**重新**读取选中集、节点、边，调 `planReferenceAttach`。有 block ⇒ 出说明卡并返回（菜单里本来就是置灰的，这里防竞态，Review Focus 3）。`alreadyAttached` ⇒ 胶囊「已经是这张」并返回。
  2. 导入，落点 = 目标的 `position - Offset(kNodeCardSize.width + kResultColumnGap, 0)`，`laneId` = 目标的 laneId。导入后写标记键。
  3. 调 `applySplice(SplicePlan(removeEdgeIds: plan.replaceEdgeIds, addEdges: [(sourceNodeId: 新节点, targetNodeId: 目标, edgeType: EdgeType.data, role: EdgeRole.reference, sortOrder: 0)]))`。抛 InkError ⇒ 出错误卡，导入的节点保留。
- 存为角色：只对 portrait 可调用（调用方保证）。弹 `InkNameDialog`，默认名 = `item.name`；用户取消 ⇒ 什么也不做。调 `createFromImage`，失败的捕获集与 `canvas_tool_actions.saveNodeAsCharacter` 相同。

- [ ] **Step 1：写失败的测试**（ProviderScope 覆盖成 fake 的导入、节点、边、角色控制器）：
  - 当参考（wanx-image，目标没有参考边）⇒ 导入一次，标记键写进新节点，`applySplice` 收到 1 条新边、0 条删除。
  - 已经挂了一张 pose ⇒ `applySplice` 的 removeEdgeIds 恰好是旧那条，旧节点没被删。
  - 同一张 ⇒ 不导入，出胶囊。
  - 点之前目标被删了 ⇒ 不导入，出卡（Review Focus 3）。
  - `applySplice` 抛 InkError ⇒ 出错误卡，导入的节点还在。
  - 存为角色取消 ⇒ 不调 `createFromImage`；确认 ⇒ 用原图绝对路径调用。
- [ ] **Step 2：** 主会话运行，预期 FAIL。
- [ ] **Step 3：** 实现。
- [ ] **Step 4：** 主会话运行，预期 PASS。
- [ ] **Step 5：** 提交 `feat(reference-library): 放进画布 / 当参考（同类替换）/ 存为角色`。

### Task 6：素材页第三段

**Files:**
- Modify: `lib/features/canvas/widgets/left_rail/assets_model.dart`（`AssetScope` 加 `reference`）
- Modify: `lib/features/canvas/widgets/left_rail/assets_panel.dart`（分段加第三项；scope 为 reference 时 body 换成 `ReferenceLibrarySection`，原来的画廊逻辑不动）
- Create: `lib/features/canvas/widgets/left_rail/reference_library_section.dart`
- Modify: `lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`、`lib/l10n/generated/*`
- Modify: `docs/CLAUDE.md`（项目结构里 left_rail / core / services / di 各补一行）
- Test: `test/features/canvas/widgets/left_rail/reference_library_section_test.dart`

**Interfaces:**
- Consumes：Task 3 的 provider、Task 4 的纯函数、Task 5 的动作；现有的 `LeftPanelHeader` 等 `left_panel_parts.dart` 部件、`InkMenuPanel` / `InkMenuEntry`、`CanvasMenuPopover`。
- Produces：`class ReferenceLibrarySection extends ConsumerStatefulWidget { const ReferenceLibrarySection({super.key, required String canvasId}); }`，带测试锚点 `static Key categoryKey(ReferenceCategory c)`、`static const Key pickFolderKey`、`static Key tileKey(String itemId)`。

界面（照概念图 A）：搜索框 → 类别 chip「姿势 N / 人像 N / 服装 N」→（pose 才有）视角行 → `GridView.builder`，两列，`Image.file(thumb, cacheWidth: 按格宽 × devicePixelRatio)` → 底部一行「路径 · 换文件夹」。空态分三种：没设文件夹、`ReferenceLibraryNotFound`、加载失败。三种都带「选择参考库文件夹」按钮。

点格子开菜单，菜单项及其可用判据：
- 「当〈类别〉参考 → 〈节点名〉」：按 `planReferenceAttach` 的 block 置灰，原因写在副标题里。
- 「只放进画布」：一直可用。
- 「存为角色」：只有 portrait 可用。

ARB 键（en / zh），值照下表：

| key | en | zh |
|---|---|---|
| `assetsScopeReference` | Reference | 参考库 |
| `referenceCategoryPose` | Poses {count} | 姿势 {count} |
| `referenceCategoryPortrait` | Portraits {count} | 人像 {count} |
| `referenceCategoryCostume` | Costumes {count} | 服装 {count} |
| `referenceAngleAll` | All angles | 全部视角 |
| `referenceSearchHint` | Search poses, hairstyles, outfits… | 搜索：站姿、回眸、短发… |
| `referencePickFolder` | Choose reference folder | 选择参考库文件夹 |
| `referenceChangeFolder` | Change folder | 换文件夹 |
| `referenceEmptyNoFolder` | Point InkFrame at a downloaded reference library (ai-pose-gallery-zh). | 选一个已下载的参考库文件夹（ai-pose-gallery-zh）。 |
| `referenceEmptyNotFound` | No reference library found in this folder. | 这个文件夹里没找到参考库。 |
| `referenceMenuAttachPose` | Use as pose reference → {node} | 当姿势参考 → {node} |
| `referenceMenuAttachPortrait` | Use as face reference → {node} | 当长相参考 → {node} |
| `referenceMenuAttachCostume` | Use as outfit reference → {node} | 当服装参考 → {node} |
| `referenceMenuPlace` | Place on canvas | 只放进画布 |
| `referenceMenuSaveCharacter` | Save as character | 存为角色 |
| `referenceBlockNoSelection` | Select one image or video config first | 先选中一镜的图像或视频配置 |
| `referenceBlockNotConfig` | Select this shot's image or video config | 选中这一镜的图像或视频配置 |
| `referenceBlockProviderNoRefs` | {provider} doesn't take reference images — switch model | {provider} 不支持参考图，换一个模型再试 |
| `referenceBlockBudgetFull` | Reference images full ({max}/{max}) | 参考图已满 {max} / {max} |
| `referenceAlreadyAttached` | Already using this one | 已经是这张 |
| `referenceTargetGone` | That node is no longer on the canvas | 目标已不在画布上 |
| `referenceImportFailed` | Couldn't import this reference image | 这张参考图导入失败 |
| `referenceAttachFailed` | Couldn't connect the reference | 参考图连线失败 |

- [ ] **Step 1：写失败的测试**
  - 没设文件夹 ⇒ 出现 `pickFolderKey`，没有网格；点它会调 picker，再调 `set(path)`。
  - fake 加载返回 `ReferenceLibraryNotFound` ⇒ 显示 `referenceEmptyNotFound` 文案（Review Focus 1）。
  - 加载成功 ⇒ 默认是 pose，chip 计数正确；切到 portrait 后只剩人像格子；搜索能过滤。
  - 没有选中节点时点格子 ⇒ 菜单里「当姿势参考」置灰，「只放进画布」可点。
  - 切回「本画布」⇒ 原来的画廊网格还在（不串）。
- [ ] **Step 2：** 主会话运行，预期 FAIL。
- [ ] **Step 3：** 实现，写 ARB，跑 `flutter gen-l10n`，补 docs/CLAUDE.md。
- [ ] **Step 4：** 主会话运行 `flutter analyze lib test`（必须干净），再跑 left_rail 下的全部测试，预期 PASS。
- [ ] **Step 5：** 提交 `feat(reference-library): 素材页第三段「参考库」`。

### 收尾（主会话）

- [ ] 全量 `flutter test -j 4 --exclude-tags golden`，按 NO_PROXY 前缀运行。
- [ ] 变异实测：每个任务至少挑一条关键用例，把实现改回去，确认它变红。结果写进 PR 正文。
- [ ] 截图：素材页「参考库」段，含有图和空态两张，用 fixture 数据、中性路径，附进 PR。
- [ ] 开 PR 对 `main`。

## 派工表（主会话维护，换会话照此续做）

| 任务 | 工作树 / 分支 | 基底 | 状态 |
|---|---|---|---|
| Task 1 | `.claude/worktrees/reference-library` / `feat/reference-library` | origin/main 2509c93 | ✅ 2c892d9 |
| Task 2–3 | `.claude/worktrees/reference-library-reader` / `feat/reference-library-reader` | 2c892d9 | ✅ 已 cherry-pick 为 3583eed、7250b5a；analyze 干净，测试全绿；变异 M1 M2 M6 均红 |
| Task 4 | `.claude/worktrees/reference-library-model` / `feat/reference-library-model` | 2c892d9 | ✅ 已 cherry-pick 为 c5efbe0；变异 M3 M4 M5 均红 |
| Task 5–6 | `.claude/worktrees/reference-library` / `feat/reference-library` | c5efbe0 之后 | 🔵 executor |
