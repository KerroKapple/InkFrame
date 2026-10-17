# undo-params · 改参数 / 改文本正文 / 挂·摘角色进栈：一次聚焦编辑算一步，记旧值，原来没有的键撤销时删掉
- 波次 W5 / lane C / 基底 origin/main〔W0–W4 已合入〕（shot_config_inspector.dart 叠在 W4 undo-node-create-move 之后）
- 依赖切片：undo-stack（W0）、nodes-batch-ops（W1，replaceTypeConfig）、undo-shortcuts-ui（W2）
- 阻塞决定：无

> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改「允许改的文件」；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行，canvas_command.dart 每片只追加一行 part + 一个 label 枚举值；CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 在检查器里改供应商 / 分辨率 / 比例 / 批量 / 时长 / 运镜 / 镜头语言 / 忽略泳道风格（离散控件）：每改一次是一步，Ctrl Z 回到改之前。
- 在提示词条、负向提示词、种子、镜头备注、文本节点正文里打字：从获得焦点到失焦这一整段算一步（文本框有焦点时 Ctrl Z 归文本框自己）。
- 挂上 / 摘下角色、应用提示词预设：各一步。
- 撤销时原来没有的键被删掉（不是写成 null）；撤销前先把 500ms 防抖里还没发出的写冲掉，不会撤到旧值上。

## 设计依据
- 画板 UndoClipboard.dc.html（b2_history.js）「什么进栈」：「改参数 / 改名 / 改文本正文 / 挂摘角色 → 修改 比例 · 重命名」。
- 同画板入口区规则：「文本框有焦点时 Ctrl Z 归文本框；离开后这段修改在画布栈里算一步」。
- 「要补的底座」：「改参数记旧值；旧值不存在要能删键 → removeTypeConfigKeys」「撤销前冲掉检查器 500ms 防抖 patch」。按 nodes-batch-ops notes：不给 NodeRepository 加 removeTypeConfigKeys，用 CanvasNodesController.replaceTypeConfig（UoW 里 findById + update(type_config) 整列覆盖）。
- 不进栈：提交生成 / 取消 / 重跑 slot、自动保存时机。所以 submit 写进去的终稿里**会话外的键**（检查器裁剪补上的 provider_id 等）不算这一步。
- slices.json notes：代码里还没有节点改名，「重命名」步名等改名入口落地再接（本片不做）。
- 设计缺口：①画板没说写库失败的那段编辑进不进栈——按「库里没变就不进栈」写；②没说同一节点上文本会话还开着时又点了下拉——按「先结束文本会话成一步，下拉再单独一步」写；③泳道风格在泳道编辑框里改，归 undo-lanes，不在这里。

## 允许改的文件
- lib/features/canvas/providers/inspector_submit_controller.dart：编辑会话（见下）；flushPendingWrites（第 303–325 行）末尾结束开着的会话；新增 settle()。
- lib/features/canvas/models/commands/param_patch_command.dart（新建，`part of '../canvas_command.dart';`）：PatchTypeConfigCommand。
- lib/features/canvas/models/canvas_command.dart（由 undo-stack 新建）：追加一行 part + 枚举值 `CanvasCommandLabel.editParams`。
- lib/features/canvas/util/param_edit_field.dart（新建）：enum ParamEditField + `String paramEditFieldLabel(AppLocalizations l, ParamEditField f)`（全部复用现有检查器标签键）。
- lib/features/canvas/providers/inspector_revision.dart（新建）：`inspectorRevisionProvider`（family(nodeId) 的计数器，撤销 / 重做改了 type_config 就 +1）。
- lib/features/canvas/widgets/image_config_inspector.dart：第 238 / 266 / 290 / 313 / 381 行离散控件改走 saveConfigStep；负向提示词（第 352 行）和种子（第 369 行）InkInput 加 FocusNode，获焦 beginEdit、失焦 endEdit；_applyPreset（第 82–90 行）走 saveConfigStep(field: prompt)。
- lib/features/canvas/widgets/video_config_inspector.dart：第 111 行 _saveLang、第 156 / 185 / 243 行改走 saveConfigStep。
- lib/features/canvas/widgets/shot_config_inspector.dart：_save（第 93–99 行）改走 saveConfigStep；镜头备注 _onChanged（第 101–106 行）所在 InkInput 加 FocusNode 走会话。不碰 _generateFromNotes（W4 已改）。
- lib/features/canvas/widgets/text_node_inspector.dart：_focus（第 44 行）获焦 beginEdit；_onFocusChanged / _commitAndRefresh（第 73–86 行）失焦写完之后 endEdit。
- lib/features/canvas/widgets/characters_section.dart：_toggle（第 89–108 行）改走 saveConfigStep(field: characters)。
- lib/features/canvas/widgets/canvas_prompt_bar.dart（本波无人占用，见风险）：提示词输入框（第 189 行 _prompt、第 345 行 savePromptDebounced）加 FocusNode 走会话；第 94 行 `ValueKey<String>(target.id)` 改成带 inspectorRevisionProvider 的值。
- lib/features/canvas/widgets/canvas_inspector_panel.dart（本波无人占用，见风险）：第 88 行 `NodeInspectorRouter(key: ValueKey<String>(node.id)…)` 的 key 并上 revision——撤销后检查器按新 type_config 重建本地状态。
- 测试：test/features/canvas/providers/inspector_submit_controller_test.dart、test/features/canvas/providers/inspector_undo_session_test.dart（新建）、test/features/canvas/widgets/text_node_inspector_test.dart、test/features/canvas/widgets/image_config_inspector_test.dart（顶层 test/features/canvas/ 下那份）。

## 不许碰的文件
- 同波：canvas_edges_controller.dart、link_action_controller.dart、node_inputs_section.dart、canvas_tool_actions.dart（undo-edges）；node_card.dart、node_card_slot.dart、node_drag_delta.dart、drop_placement.dart、edge_painter.dart、stage_edge_layer.dart（group-drag）；left_rail/assets_*、canvas_menu_host.dart（rail-drag-assets）；current_take_controller.dart、generation_controller.dart、canvas_job_listener.dart（tc-take-edge-follow）。
- canvas_nodes_controller.dart（用 W1 的 replaceTypeConfig，不改）；canvas_history_controller.dart（只用）；node_inspector_router.dart。

## 具体改动
```dart
// InspectorSubmitController 新增
void beginEdit({required String canvasId, required ParamEditField field}); // 已开着同一会话 ⇒ 不动；开着别的字段的会话 ⇒ 先 endEdit 那个
Future<void> endEdit();   // 没开会话 ⇒ 立即返回
Future<void> saveConfigStep(Map<String, Object?> patch,
    {required String canvasId, required ParamEditField field}); // = beginEdit + saveConfig + endEdit
Future<void> settle();    // 冲掉 _pendingDebounced（正常语义写，不是退出语义）+ 等 _writeTail 落完

// 会话内部状态（私有）
//   _sessionCanvasId / _sessionField / _sessionKeys: Set<String>
//   _sessionBefore: Future<Map<String, Object?>>  —— beginEdit 时排进 _serialized：findById(arg) 读 type_config 快照
// saveConfig / saveDebounced / savePromptDebounced：会话开着时把 patch.keys 并进 _sessionKeys

// models/commands/param_patch_command.dart
final class PatchTypeConfigCommand extends CanvasCommand {
  PatchTypeConfigCommand({required String canvasId, required String nodeId,
      required ParamEditField field,
      required Map<String, Object?> before, required Set<String> beforeAbsent,
      required Map<String, Object?> after,  required Set<String> afterAbsent});
  // label = editParams；affectedNodeIds = {nodeId}
}
```
- endEdit 顺序（顺序就是变异点）：① settle()——冲掉防抖并等写入链；② 在 _serialized 里 findById 读现值；③ 对 _sessionKeys 逐键比 before / 现值（List 用 listEquals，Map 用 mapEquals；「键不存在」与「值为 null」是两种状态）；④ 有差异 ⇒ push PatchTypeConfigCommand（只装有差异的键）；⑤ 清会话。没差异（含写失败、库里没变）⇒ 不 push。
- 快照取库不取内存节点：提示词条只经 savePromptDebounced 落库、不回写画布节点（canvas_tool_actions.dart:418 的注释），内存里的 promptText 可能是旧的。
- submit（第 494 行）在会话开着时照旧写终稿；会话的 after 在 endEdit 时从库里读，所以只认 _sessionKeys 里的键，终稿补写的会话外键不进这一步。
- flushPendingWrites（退出 / undo-stack 撤销前冲刷都会调）：现有冲刷之后，若会话开着 ⇒ 执行 endEdit 的 ②–⑤（不再写）。于是「打完字没失焦就点了 ⌘K 撤销」时，这段编辑先进栈、再被撤掉。
- PatchTypeConfigCommand.revert：① 节点不在画布节点表 ⇒ 对象已消失；② `await inspectorSubmitControllerProvider(nodeId).notifier.settle()`；③ `CanvasNodesController.replaceTypeConfig`：现值上，before 里的键写回 before 值，beforeAbsent 里的键删掉，别的键不动；④ `inspectorRevisionProvider(nodeId)` +1；⑤ text / prompt / character_ids 变了的话 invalidate galleryGraphProvider(projectId)（同 characters_section.dart:104 的理由）。apply（重做）同理用 after / afterAbsent。
- replaceTypeConfig 的签名以 W1 为准：若接受 `Map Function(Map current)` 就在它的事务里做③；若只接受整张 Map，就在②之后 findById 读现值、算好再传（风险里写了）。
- 步名：「修改 {field}」；field 文案取现有键：provider→inspectorProviderLabel、resolution→inspectorResolutionLabel、aspectRatio→inspectorAspectRatioLabel、batchSize→inspectorBatchLabel、negativePrompt→inspectorNegativePromptLabel、seed→inspectorSeedLabel、ignoreLaneStyle→inspectorIgnoreLaneStyle、duration→inspectorVideoDurationLabel / inspectorShotDurationLabel、camera→inspectorVideoCameraLabel、shotLanguage→inspectorShotSizeLabel、shotNotes→inspectorShotNotesLabel、text→inspectorTextContentLabel、characters→新键、prompt→新键。
- 控件接线：每个 InkInput 的 FocusNode 在 State 里建、dispose 里销毁；监听里获焦 ⇒ beginEdit，失焦 ⇒ unawaited(endEdit())。State 在 initState 缓存 notifier 实例（`ref.read(...notifier)`），dispose 里直接调实例的 endEdit()（不经 ref——widget 卸载时 ref 不可用，见 inspector_submit_controller.dart:453–460 的注释）。

## 行为规则与边界情况
1. 下拉 / 开关 / 角色勾选 / 应用预设：一次操作一步；选回原值（库里没变）不进栈。
2. 文本框：获焦到失焦期间不论打多少字、防抖发射几次，只进一步；撤销回到获焦前的值。
3. 文本框有焦点时 Ctrl Z 归文本框（undo-shortcuts-ui 的 _EditingAwareAction），画布栈不动。
4. 原来没有的键（新节点第一次设 seed）⇒ 撤销后 type_config 里没有 seed 键（不是 seed: null）；原来是 null 的键 ⇒ 撤销回 null（键在）。
5. 失焦后 500ms 防抖还没发射就撤销 ⇒ 先冲掉防抖再撤；600ms 后库里仍是旧值（不会被晚到的防抖盖回新值）。
6. 一段编辑没失焦就从 ⌘K / 菜单撤销 ⇒ undo-stack 撤销前冲刷 ⇒ 这段编辑先成一步再被撤掉。
7. 写库失败（自动保存进 Retrying / Failed）⇒ 库里没变，会话不进栈；用户之后点「重试」成功也不补进栈（缺口①）。
8. 同节点文本会话开着时点下拉 ⇒ 两步：先文本那步，后下拉那步。
9. 换选中节点 / 检查器卸载 ⇒ dispose 里 endEdit，这段编辑照样进栈。
10. 撤销 / 重做后检查器与提示词条显示新值（revision 变 ⇒ 按 key 重建）；画布卡片文字随画布节点表更新。
11. 撤销时节点已删 ⇒ 对象已消失、丢步。
12. revert 写失败 ⇒ 由 undo-stack 留栈顶 + 提示；本片不吞 InkError。
13. 只撤这一步的键：撤销「修改 比例」不动同节点后来改的 seed。
14. 生成（submit）本身不进栈；会话外键（终稿补写的 provider_id 等）不进这一步。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasCommandEditParam | Edit {field} | 修改 {field} |
| canvasCommandParamFieldPrompt | prompt | 提示词 |
| canvasCommandParamFieldCharacters | characters | 角色 |

## 测试
test/features/canvas/providers/inspector_undo_session_test.dart（新建；ProviderContainer + InMemoryNodeRepository（findById / patchTypeConfig / update 真实现）+ FakeUnitOfWork + 真的 CanvasNodesController / CanvasHistoryController；防抖用 fake_async 或真 500ms + pump）
- 「一次聚焦编辑只进一步」：beginEdit(prompt) → savePromptDebounced 5 次、跨过两次防抖发射 → endEdit ⇒ 栈深 1，before.prompt == 'A'，after.prompt == 'ABCDE'。
- 「endEdit 先冲防抖」：savePromptDebounced('B') 后立即 endEdit、立即 undo ⇒ 等 600ms 后库里 prompt == 'A'。
- 「撤销前冲掉别的会话的防抖」：上一步已在栈；新会话 savePromptDebounced('C') 不结束 → 走 history undo（它先 flushPendingWrites）⇒ 撤掉的是 C 那步，库里 prompt == 'B'，再等 600ms 仍是 'B'。
- 「原来没有的键撤销后删掉」：type_config 无 seed → saveConfigStep({'seed': 7}) → undo ⇒ containsKey('seed') == false。
- 「原来是 null 的键撤销回 null」：type_config {'camera': null} → 改成 'dolly' → undo ⇒ containsKey 且值 null。
- 「写失败不进栈」：patchTypeConfig 抛 InkError ⇒ 栈深 0。
- 「选回原值不进栈」。
- 「只撤这一步的键」：改 aspect_ratio、再改 seed → 撤一步 ⇒ seed 回去、aspect_ratio 仍是新值。
- 「submit 补写的会话外键不进这一步」：会话里只打 prompt，submit({'prompt':..,'provider_id':'x'}) → endEdit → undo ⇒ provider_id 仍是 'x'。
- 「节点已删丢步」。
- 「重做回到 after」。
test/features/canvas/providers/inspector_submit_controller_test.dart（追加）
- 「settle 冲掉防抖并等写入链落完」；「flushPendingWrites 结束开着的会话」。
test/features/canvas/widgets/text_node_inspector_test.dart（追加）
- 「失焦后一步、撤销后输入框显示旧文本」（revision 重建）。
test/features/canvas/image_config_inspector_test.dart（追加）
- 「切比例是一步，撤销后下拉显示旧比例」。

## 变异点
1. endEdit 去掉 ① settle ⇒「endEdit 先冲防抖」红（撤到旧值上后又被晚到的防抖盖回 'B'）。
2. revert 去掉 ② settle ⇒「撤销前冲掉别的会话的防抖」红。
3. revert 把 beforeAbsent 的键写成 null 而不是删掉 ⇒「原来没有的键撤销后删掉」红。
4. 把「键不存在」与「值为 null」合并成一种 ⇒「原来是 null 的键撤销回 null」红。
5. 每次防抖发射都 push ⇒「一次聚焦编辑只进一步」红。
6. 快照改成取内存节点的 typeConfig ⇒「一次聚焦编辑只进一步」的 before 断言红（测试里内存节点 prompt 故意是旧值 'Z'）。
7. after 取终稿全部键而不是 _sessionKeys ⇒「submit 补写的会话外键不进这一步」红。
8. revert 整列覆盖成 before（不保留别的键）⇒「只撤这一步的键」红。
9. flushPendingWrites 不结束会话 ⇒「flushPendingWrites 结束开着的会话」红。
10. 去掉 revision 自增 ⇒ text_node_inspector「撤销后输入框显示旧文本」红。

## 验收
- flutter analyze lib test；flutter test test/features/canvas --exclude-tags golden；逐条变异。
- 截图：CanvasScreen，选中一个 image config 节点（prompt「拂晓雾江」、比例 16:9）；①把比例改 9:16 ②Ctrl Z 后检查器比例回 16:9、胶囊「已撤销 · 修改 比例」③在提示词条里加一句再点画布空白处 → 空白处右键菜单首项「撤销 修改 提示词」。

## 风险与不确定
- canvas_prompt_bar.dart 与 canvas_inspector_panel.dart 不在本波归属表里（本波也没人占），本片需要它们：提示词是最主要的参数，没有失焦钩子就做不到「一次聚焦一步」；检查器 key 不并 revision，撤销后面板显示旧值。已在回报里提给主 Agent。
- 依赖 undo-stack 的 undo() 先 await 冲刷、再取栈顶；若它先取栈顶再冲刷，规则 6 会撤错步——需在 canvas_history_controller 调整一行（不归本片，回报已提）。
- replaceTypeConfig 若只收整张 Map，「读现值 → 覆盖」之间有极小竞态窗口（同节点并发写只来自本控制器，settle 之后窗口里没有本控制器的写）。
- 每个会话开头多一次 findById；离散控件每次也多一次，可接受。
