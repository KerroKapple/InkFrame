# rail-drag-characters · 角色行拖到图像 / 视频配置：追加进 character_ids，超配额按 ref_image_budget 点名
- 波次 W9 / lane E / 基底：origin/main（W0–W8 已合入）；依赖切片：stage-drop-target（W4）、undo-params（W5）、rail-drag-assets（W5，左栏 Draggable 的写法）、canvas-capsule（W1）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
- 在左栏角色页按住一行角色，拖到画布上的图像配置或视频配置卡上。目标卡出现琥珀色虚线高亮，松手后这个角色就挂到节点上，等同于在检查器角色区点亮它的 chip。
- 胶囊会说明结果：「已挂上角色「渔夫」」。如果参考图超了上限，会点名哪些角色不会被完整使用。如果当前模型不用参考图，也直说。
- 按一次 Ctrl Z 撤掉这次挂载；左栏「M 处引用」随即更新。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ImportSearch.dc.html`「从左栏拖进画布 · 素材格、角色行都能拖」：
  - 角色行拖到图像 / 视频配置：直接追加进 character_ids，超配额按 ref_image_budget 点名；
  - 「需要：左栏包 Draggable、舞台加 DragTarget，不用新依赖」。
  - 示意里的角色行是「渔夫 · 3 张 · 2 处」。
- 同板「提示词里 @角色」：character_ids 仍是唯一来源（IS-Q3 A），本片只写 character_ids，不写 @ 记号。
- `lib/features/canvas/widgets/characters_section.dart`，以下行号均为现状：
  - `_toggle` 第 89–110 行：写入走 `inspectorSubmitControllerProvider(nodeId).notifier.saveConfig({'character_ids': …})`，落库后 `ref.invalidate(galleryGraphProvider(projectId))`。这就是「定点 invalidate characterUsage」：`characterUsageProvider` 由 galleryGraphProvider 派生，见 `providers/character_usage.dart` 第 50–56 行。
  - `_supportsRefs` 第 82–87 行：image 要求 maxRefImages > 0 且有 imageToImage 模式；video 只要求 maxRefImages > 0。
  - `_inputsView` 第 124–152 行：只数「有图的 data / reference 入边」。
  - `_refBudget` 第 155–171 行。
- 设计缺口：拖到空白处、文本 / 镜头卡、产物卡上怎么办，画板没写。本片规定：不高亮、松手不写，胶囊「角色只能放到图像或视频配置上」。
- 设计缺口：角色已经挂在这张卡上又拖一次，画板没写。本片规定：不写库、不进栈，胶囊「「渔夫」已挂在这个节点上」。
- 设计缺口：拖动时左栏行本身的样子（原位变淡与否、拖影大小），画板没画。本片沿用 rail-drag-assets（W5）素材格的拖影写法，以落地为准；拖影是 36 缩略 + 名字的小胶囊。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/widgets/character_library_panel.dart`：
  - `CharacterLibraryRow`（第 201 行起）的行体外包 `Draggable<CanvasDragPayload>`，data 是 W4 的角色载荷（构造名以落地为准，形如 `CanvasDragPayload.character(characterId: ch.id)`）；
  - feedback 是新私有 widget `_CharacterDragFeedback`（缩略 + 名字，样式全取 tokens）；
  - 点按 = 编辑的语义不变，⋯ 菜单不参与拖动；
  - 加测试锚点 `ValueKey('character-drag-${ch.id}')`。
- 新 `lib/features/canvas/util/canvas_character_drop_actions.dart`：判据纯函数 + 落下动作，签名见下。舞台分派里角色分支调用 `dropCharacterOnStage`。
- `lib/features/canvas/util/ref_image_budget.dart`：只在文件尾追加点名辅助：`extension RefImageBudgetNaming on RefImageBudgetPlan`，不改 `planRefImageBudget`。
- `lib/features/canvas/widgets/characters_section.dart`（主 Agent 已准许，W9 别片不拥有）：只给 `_CharactersSectionState` 加 `didUpdateWidget`。当 `widget.targetNode.id` 变了，或者 `widget.targetNode.typeConfig['character_ids']` 与 `oldWidget` 不同（按 `_readAttached` 读出的集合比较）时，`setState` 重读 `_attachedIds`。不改 `_toggle` 或其他任何逻辑。
- 新测试：`test/features/canvas/util/canvas_character_drop_test.dart`、`test/features/canvas/widgets/character_drag_to_config_test.dart`、`test/features/canvas/widgets/characters_section_resync_test.dart`。`test/features/canvas/util/ref_image_budget_test.dart` 只追加用例。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- os-drop-paste-image：`widgets/canvas_view.dart`（W9 归它；本片不碰，处理办法见「风险」）、`widgets/os_file_drop_overlay.dart`、`util/import_drop_summary.dart`、`util/canvas_import_drop_actions.dart`、`widgets/shortcuts/clipboard_keys.dart`、`util/canvas_paste_actions.dart`。
- dep-drop-pasteboard：`pubspec.yaml`、`pubspec.lock`、平台注册文件、`lib/core/di/clipboard_image.dart`。
- canvas-find-bar：`widgets/canvas_screen.dart`、`widgets/node_card_slot.dart`、`widgets/node_card.dart`（W4 的琥珀虚线高亮已在里面，本片不改）、`util/escape_ladder.dart`。
- multi-select-inspector：`widgets/canvas_inspector_panel.dart`、`widgets/image_config_inspector.dart`、`widgets/video_config_inspector.dart`、`util/provider_capability_fields.dart`。
- outline-rename-menu（同 lane 下一片）：`widgets/left_rail/outline_panel.dart`、`providers/canvas_nodes_controller.dart`、`models/canvas_command.dart`（本片不加命令子类，复用 W5 undo-params 的 type_config 命令）。
- job-eta：`lib/storage/repositories/postgres_job_repository.dart`。
- 通用：
  - `util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`widgets/canvas_shortcuts.dart` 骨架与注册表；
  - `models/canvas_drag_payload.dart`、`providers/canvas_drop_hover.dart`、`util/drop_placement.dart`；
  - `providers/inspector_submit_controller.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/canvas_character_drop_actions.dart
enum CharacterDropVerdict { attach, alreadyAttached, notConfigTarget }
bool characterDropAccepts(CanvasNode? node);       // node != null && role == config && type ∈ {image, video}
CharacterDropVerdict characterDropVerdict({required CanvasNode? target, required String characterId});
List<String> appendCharacterId(Iterable<String> current, String id);   // 保序、去重，追加在末尾
int edgeReferenceImageCount({required String targetNodeId, required List<CanvasEdge> edges,
    required Map<String, CanvasNode> nodesById});  // 与 CharactersSection._inputsView 同口径：data + reference + 源有 imageUrl
bool characterRefsSupported(ProviderCapabilities? caps, {required CanvasNodeType type});
    // image：maxRefImages > 0 && modes 含 imageToImage；video：maxRefImages > 0（同 CharactersSection._supportsRefs）
Future<void> dropCharacterOnStage(BuildContext context, WidgetRef ref,
    {required String canvasId, required String? targetNodeId, required String characterId});
// util/ref_image_budget.dart（追加）
extension RefImageBudgetNaming on RefImageBudgetPlan {
  CharacterRefOutcome? outcomeOf(String characterId);
  String shortfallNames({String separator = ' / '});   // 与 inspectorCharactersOverLimit 的 names 同拼法
}
```
- `dropCharacterOnStage` 流程：
  1. 文案和控制器都在 await 之前取，与 addNodeFromMenu 同一写法。
  2. 判据用画布控制器内存里的节点。`notConfigTarget` → 胶囊返回。
  3. 用 `ref.read(nodeRepositoryProvider.future)` 的 `findById(nodeId)` + `CanvasNode.fromRow` 取库里最新的 `character_ids`。原因是检查器 `_toggle` 只写库、不回写画布内存，拿内存当基准会把刚在检查器挂上的角色冲掉。
  4. 用 `characterIdsOf`（character_usage.dart）读出旧列表。已包含该角色 → `alreadyAttached` 胶囊返回。
  5. `newIds = appendCharacterId(old, id)`，然后 `await inspectorSubmitControllerProvider(nodeId).notifier.saveConfig({'character_ids': newIds})`。
  6. 读 `inspectorAutoSaveStatusProvider(nodeId)`：
     - 是 `InspectorAutoSaveClean` → 往 W5 undo-params 的 type_config 命令里记一步 `{character_ids: old} → {character_ids: newIds}`（API 以落地为准；若 W5 把记栈做进 saveConfig 链，这一步自然得到）；然后 `ref.invalidate(galleryGraphProvider(projectId))`、`ref.invalidate(canvasNodesControllerProvider(canvasId))`；再按规则 4–6 出胶囊。
     - 不是 Clean → 胶囊「挂载还没保存上，正在重试」，不记栈、不 invalidate。
- 配额：
  - `limit` 取节点当前 provider 的 `maxRefImages`。provider 用 `resolveConfigProviderId(savedProviderId: tc['provider_id'], lastUsedProviderId: prefs.lastImageProviderId / lastVideoProviderId, candidates: configProviderCandidates(type, ref.read(providerCapabilitiesListProvider)))`（util/generate_gate.dart 第 56 行）解析。
  - `edgeRefCount` 取 `edgeReferenceImageCount`。
  - characters 按 `newIds` 顺序，从 `charactersControllerProvider(projectId)` 取名字（为空回落到 id）和参考图路径。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 把「渔夫」拖到一个 `character_ids == ['a']` 的图像配置卡上：库里变成 `['a', '渔夫id']`，顺序保留，新的在末尾。胶囊「已挂上角色「渔夫」」。
2. 悬停高亮只给合法目标：`characterDropAccepts` 对 image / video config 为 true，对 text / shot config、所有 result 卡为 false。不合法的卡不出虚线框（W4 高亮读这个判据，见「风险」接线）。
3. 拖到空白处或不合法的卡上松手：不写库、不进栈，胶囊「角色只能放到图像或视频配置上」。
4. 已经挂过：不调 saveConfig、不进栈，胶囊「「渔夫」已挂在这个节点上」。
5. 超配额：`planRefImageBudget(...).overflows` 且 `shortfall` 非空时，照样挂上。胶囊「已挂上「渔夫」· 参考图超出上限（{requested}/{max}），{names} 不会被完整使用」，names 用 `shortfallNames()`，与检查器 `inspectorCharactersOverLimit` 的 names 同一拼法。
6. 当前 provider 不使用参考图（`characterRefsSupported == false`）：照样挂上，胶囊「已挂上「渔夫」· 当前模型不使用参考图，角色不会生效」。这种情况不再算配额。
7. 写库失败（saveConfig 后状态是 Retrying / Failed）：胶囊「挂载还没保存上，正在重试」。不 invalidate、不进栈。检查器自动保存行照常显示重试，由 InspectorSubmitController 负责。
8. 基准取库：检查器刚把 `b` 挂上（库里 `['b']`，画布内存仍是 `[]`），这时拖入 `c`，结果是 `['b', 'c']`，不是 `['c']`。
9. 撤销：松手成功后 Ctrl Z 一次，库里回到旧列表，左栏该角色「M 处引用」减 1。Ctrl Y 又挂回去。栈里只有一步。
10. 引用计数：成功后 `galleryGraphProvider(projectId)` 被 invalidate 恰好一次，左栏行的「M 处引用」从 2 变 3。
11. 取消：拖出窗口、或拖回左栏松手（舞台 DragTarget 没接）时，不写库、不出胶囊。在舞台上按 Esc 取消拖动的行为由 Flutter Draggable 和 esc-ladder 决定，本片不另加。
12. 并发：同一张卡先后落下两个角色（第二次在第一次的 `dropCharacterOnStage` 返回之后），最终列表包含两者。写入经 InspectorSubmitController 的串行链（`_writeTail`）按发起顺序落库。单指针拖放不会出现两次落下重叠；若出现重叠（读库都发生在写库之前），后写的那次会覆盖前一次，这个窗口写进风险，不另加锁。
13. 角色在拖动途中被删（charactersControllerProvider 里已经没有该 id）：不写库、不进栈，胶囊「这个角色已被删除」。
14. 左栏行的点按 = 编辑不受影响：点一下不出拖影、照常打开编辑框。拖动起始阈值沿用 Flutter `Draggable` 默认。
15. mac / Windows 无差异：都是指针拖放，不涉及系统拖放，也不受 desktop_drop 影响。触控板三指拖动与鼠标按住拖动走同一条 Draggable 路径。
16. 检查器开着目标节点时（CharactersSection 已挂载），拖入成功后画布节点被 invalidate、检查器拿到新节点，chip 立即点亮。之后在检查器里点任何 chip，写入的集合都包含拖入的角色。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| canvasCharacterAttached（String name） | Attached character “{name}” | 已挂上角色「{name}」 |
| canvasCharacterAttachedOverLimit（String name, int requested, int max, String names） | Attached “{name}” · reference images over limit ({requested}/{max}); {names} won't be fully used | 已挂上「{name}」· 参考图超出上限（{requested}/{max}），{names} 不会被完整使用 |
| canvasCharacterAttachedUnsupported（String name） | Attached “{name}” · this model ignores reference images | 已挂上「{name}」· 当前模型不使用参考图，角色不会生效 |
| canvasCharacterAlreadyAttached（String name） | “{name}” is already attached to this node | 「{name}」已挂在这个节点上 |
| canvasCharacterDropTargetInvalid | Characters can only be dropped on image or video configs | 角色只能放到图像或视频配置上 |
| canvasCharacterDropDeleted | This character has been deleted | 这个角色已被删除 |
| canvasCharacterAttachUnsaved | The attachment isn't saved yet; retrying | 挂载还没保存上，正在重试 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/canvas_character_drop_test.dart`（新，纯函数）：
  - `accepts image and video config only`（规则 2）；
  - `verdict alreadyAttached`（规则 4）；
  - `append keeps order and dedupes`（规则 1）；
  - `edge ref count only counts data/reference edges with image`（与 `_inputsView` 同口径）；
  - `refs supported: image needs imageToImage, video does not`（规则 6）。
- `test/features/canvas/util/ref_image_budget_test.dart`（追加）：`outcomeOf finds character`、`shortfallNames joins in injection order`。
- `test/features/canvas/widgets/character_drag_to_config_test.dart`（新；ProviderScope + fake NodeRepository（记录 patchTypeConfig、findById 返回库里的 row）+ fake 角色控制器 + 能力表）。被测是「左栏 CharacterLibraryPanel + 一个测试用 DragTarget<CanvasDragPayload>，它的 onAccept 调 `dropCharacterOnStage`」，因为 canvas_view 的接线不在本片，用来模拟 W4 的分派。用例：
  - `drag row onto image config appends id and shows attached capsule`（规则 1）；
  - `drop on text node writes nothing, shows invalid-target capsule`（规则 3）；
  - `already attached writes nothing`（规则 4）；
  - `over limit still attaches and names shortfall`（规则 5：limit = 2、边连 1 张、角色 2 张）；
  - `unsupported provider attaches with unsupported capsule`（规则 6）；
  - `write failure shows unsaved capsule, no gallery invalidate`（规则 7）；
  - `base is repository row, not stale in-memory node`（规则 8）；
  - `Ctrl Z restores previous character_ids`（规则 9）；
  - `gallery graph invalidated once → usage count +1`（规则 10）；
  - `drop back on rail does nothing`（规则 11）；
  - `deleted character shows deleted capsule`（规则 13）；
  - `tap row still opens edit dialog`（规则 14）。
- `test/features/canvas/widgets/characters_section_resync_test.dart`（新；直接挂 `CharactersSection`，fake 角色表 + 记录型 fake NodeRepository）：
  - `inspector open on target: chip lights after drop, later toggle keeps dropped id`。步骤：先用 `character_ids: ['a']` 的节点挂载；换成 `['a', 'c']` 的同 id 节点重建 widget，断言 c 的 chip 处于选中态；再点 b 的 chip，断言最后一次 patchTypeConfig 写的是 `['a', 'c', 'b']`。
  - `typeConfig unchanged → no resync`：重建时传入相同的列表，本地刚点亮、还在写的选中态不被打回（规则 16）。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. `appendCharacterId` 改成把新 id 插到最前 → `append keeps order` 和 widget 用例 1 变红。
2. 基准改用画布内存节点、不读 `findById` → `base is repository row, not stale in-memory node` 变红。
3. 去掉 `ref.invalidate(galleryGraphProvider(projectId))` → `gallery graph invalidated once → usage count +1` 变红。
4. `characterDropAccepts` 放行 shot / text → `accepts image and video config only` 和 `drop on text node writes nothing` 变红。
5. 不判已挂过、照写 → `already attached writes nothing` 变红（patchTypeConfig 被调用）。
6. 超配额时拒绝挂载 → `over limit still attaches and names shortfall` 变红。
7. `characterRefsSupported` 对 video 也要求 imageToImage → `refs supported … video does not` 变红。
8. 不看自动保存状态、失败也出「已挂上」→ `write failure shows unsaved capsule` 变红。
9. 不记撤销命令 → `Ctrl Z restores previous character_ids` 变红。
10. `edgeReferenceImageCount` 把 firstFrame / lastFrame 也算进去 → `edge ref count only counts data/reference edges with image` 变红。
11. 删掉 `CharactersSection.didUpdateWidget`，或者让它不比较 `character_ids` → `inspector open on target: chip lights after drop, later toggle keeps dropped id` 变红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/features/canvas --exclude-tags golden`；逐条跑上面 11 个变异。
- 接线前（canvas_view.dart 两处还没接）只验两样：一是纯函数用例，二是面板侧用例，即左栏 Draggable + 测试用 DragTarget 调 `dropCharacterOnStage` + characters_section 重读。舞台上真实拖放这时还不可用，属预期。
- 截图：`CanvasScreen`，左栏开在角色页，有「渔夫（3 张 · 2 处）」「老渔翁（1 张）」。画布上有「镜头 02 · 江上孤舟」视频配置（万相 2.2，maxRefImages = 2，已连 1 张参考）和一个文本节点。截四张：
  1. 拖着「渔夫」悬停在视频配置上：卡片出琥珀虚线框，拖影跟着指针；
  2. 松手后：超配额胶囊点名「渔夫」；
  3. 拖到文本节点上松手：胶囊「角色只能放到图像或视频配置上」；
  4. 成功后：左栏「渔夫」那一行显示「3 张参考图 · 3 处引用」。
- 主 Agent 接线（本片合入、os-drop-paste-image 合入之后）：在 canvas_view.dart 的 W4 分派里，角色分支改调 `dropCharacterOnStage(context, ref, canvasId:, targetNodeId: 命中的卡 id, characterId:)`；W4 的悬停高亮判据对角色载荷改用 `characterDropAccepts`。接线后由主 Agent 补跑舞台集成测试：拿 `character_drag_to_config_test.dart` 的用例 1 和 2，以及规则 2 的高亮，把被测换成真 `CanvasView` 舞台再跑一遍。不过就回到本片修。

## 风险与不确定
- **canvas_view.dart 归 os-drop-paste-image**，本片不碰。W4 分派里角色分支现在做什么以 W4 落地为准，可能是空实现或「即将推出」胶囊。处理办法：本片只交付 `dropCharacterOnStage` 和 `characterDropAccepts`，用测试用 DragTarget 模拟分派；接线那两行由主 Agent 在 os-drop-paste-image 合入后补，见「验收」。在接线前，用户在真舞台上还拖不进去。
- characters_section.dart 原先只在 initState 读一次挂载集合（第 64–68 行）。检查器开着目标节点时，拖入的角色会被后续点击冲掉。主 Agent 已准许本片加 didUpdateWidget 修掉这个问题（规则 16、变异 11）。改动必须只限于这一个方法。
- `characterRefsSupported` 和 `edgeReferenceImageCount` 与 CharactersSection 的私有判据各有一份。同波的 multi-select-inspector 会新建 `provider_capability_fields.dart` 收能力位判据，两片合入后由主 Agent 决定是否把这两份并过去，本片不跨片依赖。
- W5 undo-params 的 type_config 命令 API、W4 角色载荷的构造名、W5 拖影写法都以落地为准。
