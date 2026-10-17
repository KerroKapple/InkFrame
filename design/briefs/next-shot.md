# next-shot · 新建下一镜：createNextShot 一个函数给 Ctrl→ / ⌘→ 与拖线菜单「下一镜」（继承设定、节点 + 叙事边一个事务）
- 波次 W10 / lane B / 基底：origin/main（W0–W9 已合入）；依赖切片：menu-split（W0，`canvas_menu/create_menu_entries.dart` 的 `runCreateMenuPick(context, ref, {canvasId, request, action})`——新建菜单的执行分派就在这里，不在 host）、esc-ladder（W0，`CanvasKeyBinding` + `CanvasKeyGate.canvasFocused`（即原 `_CanvasFocusedAction`：画布本身持主焦点且不在文字里）+ `kCanvasKeyRegistry`）、undo-stack（W0，`record`）、undo-node-create-move（W4，`models/commands/node_create_move_command.dart` 的 `CreateNodesCommand({kind: NodeCreateKind.linked, nodeIds, nodeType})`，canvasId 从 env 取）、canvas-capsule（W1）；阻塞决定：KM-Q1 / GC-N3 → GC-N3 的 A（锚点已有下一镜时开分叉，排在已有分叉之后，弹胶囊「已新开分叉」；要插中间就拖到线上插入）；继承范围按 KM-Q1 的 A（见「设计依据」裁定）

## 目标（用户看到什么变化，2–4 行）
选中一张镜头 / 图像配置 / 视频配置（或它的产物）按 Ctrl→（macOS ⌘→），右边同一泳道里立刻多一张同类型的空镜，叙事线已连好、模型画幅等设定照抄、提示词留空；焦点留在画布，可以一直按下去。
从出端口拖线到空白处，菜单第一项就是「下一镜（叙事）」并默认高亮，建出来的节点同样继承设定。锚点已有下一镜时新开一个分叉并弹胶囊提示；整个操作 Ctrl Z 一步撤回。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/GapsCanvas.dc.html` ›「新建下一镜 · Ctrl → · ⌘→ · 拖线菜单「下一镜」· 节点右键，三个入口一条路」：
  - 锚点 = 恰好选中的那一张：镜头 / 图像配置 / 视频配置；选中的是产物就用它的来源配置（narrativeAnchorOf）；文本、便签不响应。
  - 建同类型配置节点 + 锚点 → 新节点的叙事边，sortOrder 走 nextNarrativeSortOrder；节点和边一个事务，撤销一步。
  - 落点沿泳道主轴：越过锚点和它名下产物那一列，再空 64（kResultColumnGap）；被占就沿主轴再往后挪（不换横截位置，不出锚点的泳道）；竖向泳道方向随主轴；Ctrl ← ↑ ↓ 不分配；在文字里 Ctrl → 归光标。
  - 新节点单选；跑出视口才平移，缩放不变；焦点留在画布，可连按。
  - 「createNextShot 一个函数给三个入口；现有菜单『下一镜』只建空节点，改成同样继承」。
  - 拖线菜单：源是配置节点时「下一镜（叙事）↵」排第一并高亮，其后才是当首帧 / 当尾帧 / 当参考（N2 建议 A：复用出端口拖线，不加新把手）。
  - N1 建议 A：继承角色和负面提示词（「两样都是设定，不是这一镜的内容」）。N3 建议 A：开分叉 + 胶囊。
  - 胶囊样例「已新开分叉 · 在 02 之后」（›「画布轻提示胶囊」）。
- `b2/project/KeyMap.dc.html` ›「组合键」：Ctrl → / ⌘→ 新建下一镜；「mac 不绑 ⌃←→（所以下一镜用 ⌘→）」；›「文字让位」：Ctrl → 属「交给框」；›「需要你定 Q1」建议 A：继承模型、画幅、分辨率、时长、批量数、角色、负面词、跟不跟泳道风格；不继承提示词、种子、镜头语言、备注、产物、首尾帧；includeRepeats: false。
- **继承键裁定（写死）**：两张板在两处冲突——镜头语言（GapsCanvas 的继承 chip 列了运镜 / 景别 / 机位角度 / 运镜幅度 / 焦段，KeyMap Q1 写不继承）与批量数（GapsCanvas 写「张数（回到 1）」，KeyMap Q1 写继承）。两张板里**明文是「建议」的只有 KeyMap Q1 的 A**，GapsCanvas 的 chip 是正文示意、它的 N1 建议只管角色和负面词；且 N1 自己给的判据是「设定继承、这一镜的内容不继承」——景别 / 机位 / 运镜每镜都在变，属于这一镜的内容；批量数和模型、画幅一样是设定。故按 KeyMap Q1 建议 A：
  - 继承（kNextShotInheritedKeys）：`provider_id` `aspect_ratio` `resolution` `duration_ms` `batch_size` `character_ids` `negative_prompt` `ignore_lane_style`，外加结构上的泳道（laneId = 锚点的道）。
  - 不继承（其余一律不拷，白名单而非黑名单）：`prompt` `seed` `camera` `shot_size` `camera_angle` `camera_motion_strength` `focal_length_mm` `shot_notes` `text` `mode` `image_url` `video_url` `thumbnail_url` 以及 pinned_result_id / gen_inputs / 停用标记 / 首尾帧与参考连线 / label。
- 代码核对：拖线菜单「下一镜」现走 `addNodeFromMenu`（`util/canvas_tool_actions.dart` 第 343 行）：先建节点再连线、失败手工 removeNode 回滚，不继承任何 type_config；`createMenuGroups`（`util/create_menu_model.dart`）把「下一镜」放在最后一组；菜单高亮默认取第一个可点项（`_effectiveHighlight`），所以「置顶」即「默认高亮」。
- 代码核对：`shot_config_inspector.dart` **没有**「下一镜」入口（只有「用本镜备注生成图像 / 视频」，那是 shot → 新配置的另一种叙事边），本片不改它；第三个入口「节点右键 › 新建下一镜」由 W11 node-menu-append-chain 接同一个 createNextShot。
- 设计缺口：「↵ = 光标进提示词条（新键）」要改 `canvas_prompt_bar.dart`（暴露聚焦请求），W10 归属表里没有任何切片拥有它，本片不做，回报主 Agent 另排。
- 设计缺口：锚点在折叠泳道里时新节点落哪、要不要展开没画。本片定：照常落在道里并展开该道。
- 设计缺口：连按时上一笔还没写完又按下一次没画。本片定：在途时丢弃新的按键（规则 12）。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/util/next_shot.dart`（新，纯函数）：`kNextShotInheritedKeys`、`inheritedTypeConfig`、`nextShotPlacement`、`anchorHasNextShot`、`stageRectFullyVisible`。
- `lib/features/canvas/providers/next_shot_controller.dart`（新）：`nextShotControllerProvider`（`Provider.family<NextShotController, String>`，不 autoDispose，理由同 script_import_controller 头注）；`createNextShot` 一个事务写节点 + 叙事边、invalidate 节点 / 边控制器、挂定位请求、推撤销步、弹胶囊；在途标志。
- `lib/features/canvas/util/create_menu_model.dart`：`createMenuGroups` 带上下文时把 `[nextShot]` 组移到第一组；头注同步。
- `lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`（menu-split 新建）：`runCreateMenuPick` 里 `nextShot` 这一支改走 `createNextShot(l, anchorSourceId: request.sourceNodeId, placement: menuNodePlacement(ref, canvasId:, viewportPoint: request.anchor))`，不再走 addNodeFromMenu；其余项不动。
- `lib/features/canvas/widgets/shortcuts/next_shot_keys.dart`（新）：`CanvasNextShotIntent` + 两个激活键 + `final List<CanvasKeyBinding> nextShotKeys`（gate `CanvasKeyGate.canvasFocused`）。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（由 esc-ladder 新建）：`kCanvasKeyRegistry` 只追加一行 `...nextShotKeys,`。
- （不碰 `canvas_menu/canvas_menu_host.dart`：menu-split 已把新建菜单的执行分派放进 create_menu_entries.dart 的 `runCreateMenuPick`，主 Agent 那条「有条件可改 host」的准许用不上。）
- 测试：`test/features/canvas/util/create_menu_model_test.dart`（改分组顺序的 4 处期望）+ 下面 4 个新文件；事务 fake 一律用 `test/_harness/fake_unit_of_work.dart` 的 `FakeUnitOfWork` / `FakeRepositoryScope`（必要时 `GatedFakeUnitOfWork` 测在途），不自写 fake。
- 不改：`widgets/shot_config_inspector.dart`（核对后无「下一镜」入口）、`models/canvas_command.dart`。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- `lib/features/generation/generation_controller.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`shell_task_capsule.dart`、新 `generation/providers/batch_run_controller.dart`（batch-run-executor）。
- `widgets/video_config_inspector.dart`、新 `util/next_shot_frame.dart` / `util/canvas_next_frame_actions.dart` / `canvas_menu/next_frame_menu_entries.dart`（tc-next-shot-first-frame——名字相近，别写进去）。
- storage / schema / migrations、`lib/core/db/columns.dart`、`lib/core/interfaces/unit_of_work.dart`、`lib/storage/postgres_unit_of_work.dart`、`lib/core/di/repositories.dart`、`lib/services/import/import_remapper.dart`、project archive / import writer（script-tables）。
- `pubspec.yaml` / `pubspec.lock` / 插件注册文件、`lib/main.dart`、`toast_center.dart`、`toast_entry.dart`、`notification_prefs.dart`、`app_preferences.dart`、`file_preferences_service.dart`、`job_notification_listener.dart`（system-notifications）。
- 同波新文件：tc-next-shot-first-frame 的 `models/commands/replace_role_edge_command.dart`；script-tables 的 `lib/storage/schema/schema_v10.dart` / `lib/core/interfaces/script_repository.dart` / `lib/storage/repositories/postgres_script_repository.dart` / `lib/features/storyboard/models/script_document.dart`；system-notifications 的 `lib/core/interfaces/system_notification_service.dart` / `lib/services/local_notifier_system_notification_service.dart` / `lib/services/noop_system_notification_service.dart` / `lib/core/di/system_notification.dart` / `lib/features/settings/providers/system_notify_pref_controller.dart`；`canvas_menu/menu_registry.dart`（W10 归 tc-next-shot-first-frame 追加一行）。
- `util/canvas_tool_actions.dart`（addNodeFromMenu 不改）、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_menu/canvas_menu_host.dart`、`models/commands/node_create_move_command.dart`（只 import）、`widgets/canvas_shortcuts.dart` 骨架与注册表、`widgets/canvas_prompt_bar.dart`、`models/canvas_command.dart`、`widgets/canvas_view.dart`、`widgets/node_card.dart`。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：script-tables：`lib/core/interfaces/project_archive_reader.dart`、`lib/core/models/import_plan_data.dart`、`lib/services/project_archive_service.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/repositories/postgres_project_archive_reader.dart`、`lib/storage/repositories/postgres_project_import_writer.dart`；system-notifications：`lib/core/interfaces/toast_service.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/settings/widgets/notifications_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/next_shot.dart
const Set<String> kNextShotInheritedKeys = {'provider_id','aspect_ratio','resolution','duration_ms',
  'batch_size','character_ids','negative_prompt','ignore_lane_style'};
/// 只拷白名单里、锚点上确有的键；列表值（character_ids）深拷一份。
Map<String, Object?> inheritedTypeConfig(Map<String, Object?> anchor);
/// 主轴 = 锚点所在道的方向（不在现存道里 ⇒ 横向）。mainStart = max(锚点 ∪ 锚点名下 result 的主轴末端) + kResultColumnGap；
/// 横截 = 锚点横截不变；候选卡（kNodeCardSize）与同道（同 laneId，含 null）任一卡相交 ⇒ 挪到挡路卡主轴末端 + kResultColumnGap 再判；
/// 最多 200 次 / 超出 ±kWorldReach 即停在最后一个候选。
NodePlacement nextShotPlacement({required CanvasNode anchor, required List<CanvasNode> nodes, required LaneDirection direction});
/// 锚点已有指向现存节点的出向 narrative 边。
bool anchorHasNextShot({required String anchorId, required List<CanvasNode> nodes, required List<CanvasEdge> edges});
bool stageRectFullyVisible(Rect stageRect, Size viewport);

// providers/next_shot_controller.dart
typedef NextShotResult = ({String nodeId, bool forked});
class NextShotController {
  bool get isBusy;
  /// [anchorSourceId]：选中的那张（产物 ⇒ narrativeAnchorOf 取来源配置）；没有锚点 ⇒ 返回 null、什么都不做。
  /// [placement] 为 null ⇒ nextShotPlacement；非 null（拖线松手处）⇒ 用它（泳道按落点判）。
  /// 一个 UnitOfWork：scope.nodes.create(type = 锚点类型, label = l.canvasNodeDefaultLabel, typeConfig = inheritedTypeConfig)
  ///   + scope.edges.create(narrative, role 'reference', sortOrder = nextNarrativeSortOrder)。
  /// 成功：invalidate 节点 / 边控制器 → canvasFocusRequestProvider.notifier.request(canvasId:, nodeId: 新节点, center: !stageRectFullyVisible(...))
  ///   → record(CreateNodesCommand(kind: NodeCreateKind.linked, nodeIds: [新节点], nodeType: 锚点类型))（W4；撤销 = removeNodes 级联软删叙事边）
  ///   → forked 时 canvasCapsuleProvider 弹「已新开分叉 · 在 {shot} 之后」。InkError ⇒ 错误卡 canvasAddNodeFailed，返回 null。
  Future<NextShotResult?> createNextShot(AppLocalizations l, {required String anchorSourceId, NodePlacement? placement});
}
final nextShotControllerProvider = Provider.family<NextShotController, String>(NextShotController.new);

// widgets/shortcuts/next_shot_keys.dart
class CanvasNextShotIntent extends Intent { const CanvasNextShotIntent(); }
const SingleActivator nextShotMeta = SingleActivator(LogicalKeyboardKey.arrowRight, meta: true, includeRepeats: false);
const SingleActivator nextShotControl = SingleActivator(LogicalKeyboardKey.arrowRight, control: true, includeRepeats: false);
final List<CanvasKeyBinding> nextShotKeys; // id 'canvasNextShot'；activators [nextShotMeta, nextShotControl]；gate: CanvasKeyGate.canvasFocused（esc-ladder 的门槛，
// 即原 _CanvasFocusedAction：画布本身持主焦点 + 不在文字里）；group: ShortcutGroup.edit；label: (l) => l.settingsShortcutCanvasNextShot；
// onInvoke：选中集恰好一张 ⇒ nextShotControllerProvider(c.canvasId).createNextShot(l, anchorSourceId: 那一张)。
```
{shot} 取锚点的 `sequenceShotNumbers`（outline_model.dart）两位补零；锚点不在任何一镜里 ⇒ 用锚点 label（空则用 `l.canvasNodeImageType` 等类型名，与 nodeDisplayName 同口径；控制器没有 BuildContext，不直接调 nodeRefName）。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 恰好选中一张镜头 / 图像配置 / 视频配置，按 Ctrl→（Win）/ ⌘→（mac）⇒ 建一张同类型配置节点 + 锚点 → 新节点 narrative 边。选中的是产物 ⇒ 锚点 = 来源配置，新节点类型 = 来源配置类型。
2. 不响应：没选中、多选、选中文本（含便签）、孤儿产物（来源已删）、来源是文本的产物——不建、不报错、不弹提示。
3. 新节点 type_config 恰好等于锚点在白名单内的键（锚点没有的键不出现）；提示词、种子、镜头语言、备注、产物 url、mode 都不出现；label = 「新节点」。
4. 落点：横向道 x = max(锚点右缘, 名下产物右缘) + 64，y = 锚点 y；竖向道同理换 y；laneId = 锚点 laneId。候选与同道已有卡相交 ⇒ 跳到挡路卡之后 + 64 再判，直到不相交。不在道里的锚点按横向算，只与同为无道的卡判占用。
5. sortOrder = 锚点现有 narrative 出边最大值 + 1（无 ⇒ 0）；锚点原来已有下一镜 ⇒ 新边排在已有分叉之后，原有边的 sortOrder 不变，弹胶囊「已新开分叉 · 在 02 之后」；原来没有 ⇒ 不弹胶囊。
6. 节点与边在同一个 UnitOfWork 里；任一步 InkError ⇒ 事务回滚，画布上不多节点也不多边，出错误卡「添加节点失败」，选中不变、撤销栈不变、不弹胶囊。
7. 成功后新节点单选；新卡整张在视口内 ⇒ 不动相机；有任一部分在视口外 ⇒ 保持缩放把它移到视口中心。
8. 焦点：快捷键入口建完焦点仍在画布本身，接着按 Ctrl→ 以新节点为锚继续往后建（连按 3 次 ⇒ 3 镜一条链、无分叉）。
9. 文字让位：焦点在提示词条 / 检查器 / 大纲改名框等任何 EditableText 里，Ctrl→ / ⌘→ 交给文本框（按词 / 行尾移动光标），不建节点。焦点在工具条键、缩放条等非画布控件上也不接管。
10. macOS 只有 ⌘→ 实际可达（⌃→ 被系统切桌面吃掉）；两个变体都注册，快捷键页按平台只显示一套。按住不放不连发（includeRepeats: false）。Ctrl ← ↑ ↓ 不绑定。
11. 拖线菜单：源是配置节点或带来源配置的产物时，「下一镜（叙事）」是第一组第一项并默认高亮，↵ 直接执行；落点 = 松手处（menuNodePlacement，泳道按落点判），继承规则同 3；首帧 / 尾帧 / 参考三项照旧走 addNodeFromMenu。
12. 并发：一笔 createNextShot 在途时再次触发（快捷键或菜单）⇒ 直接丢弃，不排队、不建第二张（避免以旧锚点建出意外分叉）。
13. 撤销：一次操作一步（复用 W4 新建命令：撤销 = 软删新节点并级联它的叙事边，重做 = restore）；撤销后锚点恢复原样，原有分叉不受影响。步名沿用 W4 新建命令的现有标签（「新建下一镜」专属步名需改 canvas_command.dart，见风险）。
14. 锚点在折叠泳道里：照常落在道里，并展开该道让新卡可见。
15. 画布关闭 / 切走时事务仍完成（provider 不 autoDispose）；切走后不弹胶囊、不挂定位请求。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| canvasNextShotForked（shot:String） | New branch · after {shot} | 已新开分叉 · 在 {shot} 之后 |
| settingsShortcutCanvasNextShot（注册表文案，沿用 `settingsShortcutCanvas*` 前缀） | New next shot | 新建下一镜 |

（菜单项沿用现有 canvasCreateMenuNextShot「下一镜（叙事）」；失败沿用 canvasAddNodeFailed。）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/next_shot_test.dart`（新）
  - 「继承键白名单：结果键集 == 锚点 ∩ kNextShotInheritedKeys」：锚点带全部可能键（含 seed、prompt、camera、shot_size、shot_notes、mode、image_url），断言 `keys` 精确等于 8 个继承键。
  - 「不继承镜头语言五键与 seed」逐键 `isNot(contains)`。
  - 「character_ids 是深拷贝」：改结果列表不影响锚点。
  - 「横向落点越过名下产物列 + 64」：锚点 + 2 个产物在 x+288 列 ⇒ 新 x = 产物右缘 + 64，y 不变。
  - 「被占就往后挪」：候选处已有一张卡 ⇒ 落在它之后 + 64；连续两张 ⇒ 跳两次。
  - 「别的道 / 无道的卡不算占用」。「竖向道沿 y 轴」。
  - 「anchorHasNextShot：只认指向现存节点的 narrative 出边」。
  - 「stageRectFullyVisible：贴边算可见、越界 1px 不算」。
- `test/features/canvas/providers/next_shot_controller_test.dart`（新，用 test/_harness/fake_unit_of_work.dart 的 FakeUnitOfWork + FakeRepositoryScope 注入 fake_repositories 的内存仓储，计数 run 次数）
  - 「节点 + 边一个事务」：run 调用 1 次；节点 create 与边 create 都发生在这一次 run 内；边 type narrative、源 = 锚点、sortOrder 正确。
  - 「建边失败：InkError 在 run 内抛出、返回 null、不 invalidate、不挂定位请求、不推撤销步、出错误卡」（真回滚由 UnitOfWork 的 Postgres 实现保证，test/storage/transaction_integration_test.dart 已覆盖）。
  - 「锚点已有下一镜 ⇒ forked=true、sortOrder = max+1、胶囊文本含 02」；「无下一镜 ⇒ 不弹胶囊」。
  - 「产物为锚 ⇒ 来源配置连出、类型取来源」；「文本 / 孤儿产物 ⇒ null、run 0 次」。
  - 「在途时第二次调用被丢弃」：GatedFakeUnitOfWork 卡住第一次，第二次调用 ⇒ run 仍 1 次。
  - 「成功推一条撤销步；undo 后节点与边都不在」。
  - 「新卡在视口内 ⇒ 定位请求 center=false；在外 ⇒ true」。
- `test/features/canvas/widgets/canvas_next_shot_shortcut_test.dart`（新）
  - 「画布持焦 Ctrl→ 建下一镜」（Windows）/「⌘→」（macOS 覆盖）。
  - 「提示词条持焦 Ctrl→ 让给光标：不建节点、光标位置变化」。
  - 「多选 / 选中文本卡不响应」。
  - 「连按三次 ⇒ 三镜一条链、无分叉、焦点始终在画布」。
- `test/features/canvas/util/create_menu_model_test.dart`（改）：第 50、61、79、98 行附近的分组期望改为「下一镜」在第一组；新增「带上下文时下一镜是第一组」。
- `test/features/canvas/widgets/create_menu_next_shot_test.dart`（新）：「拖线菜单默认高亮下一镜，↵ 建出的节点带继承键、落在松手处」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. kNextShotInheritedKeys 加入 'seed' ⇒「继承键白名单」红。
2. 加入 'camera'（或任一镜头语言键）⇒「不继承镜头语言五键」红。
3. inheritedTypeConfig 改成「拷全部再删黑名单」⇒ 白名单用例（锚点带 mode / image_url）红。
4. 落点去掉产物列（只看锚点右缘）⇒「越过名下产物列」红。
5. 占用判断去掉 ⇒「被占就往后挪」红。
6. sortOrder 写死 0 ⇒「sortOrder = max+1」红。
7. 节点与边拆成两个 uow.run（或节点改走 CanvasNodesController.addNode）⇒「节点 + 边一个事务」红。
8. 去掉在途标志 ⇒「第二次调用被丢弃」红。
9. next_shot_keys 的 Action 换成普通 CallbackAction ⇒「提示词条持焦 Ctrl→ 让给光标」红。
10. createMenuGroups 把下一镜组放回最后 ⇒ create_menu_model_test 与「默认高亮下一镜」红。
11. create_menu_entries 的 nextShot 改回 addNodeFromMenu ⇒「↵ 建出的节点带继承键」红。
12. 定位请求恒 center=true ⇒「新卡在视口内 ⇒ center=false」红。
13. 去掉 includeRepeats: false ⇒ esc-ladder 的注册表守卫测试红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑 `flutter analyze lib test`、`flutter test test/features/canvas --exclude-tags golden`，逐条变异。
- 截图（CanvasScreen，水平泳道「水墨风格」：镜头 01 图像配置 → 镜头 02 视频配置〔万相 i2v · 5 秒 · 720p · 推镜，名下一个成片〕）：
  1. 选中镜头 02；2. Ctrl→ 后新卡落在成片列之后 64、叙事线已连、检查器显示继承的模型 / 时长 / 分辨率而运镜为空；3. 再选镜头 02 按 Ctrl→：第二个分叉 + 胶囊「已新开分叉 · 在 02 之后」；4. 从镜头 01 出端口拖到空白：菜单「下一镜（叙事）」置顶高亮；5. 竖向泳道同场景一张。

## 风险与不确定
- 继承键是本片裁定（镜头语言不继承、批量数继承），与 GapsCanvas 的 chip 示意不一致；若主 Agent / 用户改判，只改 kNextShotInheritedKeys 一处 + 两条测试期望。
- 撤销步名（主 Agent 已裁决）：沿用 W4 新建命令的通用标签，不加「新建下一镜」专属步名；与画板文字不一致，记为已知差异。
- W4 的 `CreateNodesCommand` 按派工单收「已建好的节点 id」（`nodeIds`，record 时这一步已生效），撤销走 `removeNodes`（级联软删新叙事边）、重做走 `restoreAll`；本片直接构造它，不改 canvas_command.dart。落地若形状不同，回报主 Agent。
- script-tables（W10）会给 RepositoryScope 加 scripts 仓储；本片测试只用 test/_harness 的共享 FakeRepositoryScope，届时只改那一处。
- 新建菜单的执行分派在 create_menu_entries.dart 的 `runCreateMenuPick`（menu-split 派工单），本片只改那里的 nextShot 一支。
- 「↵ = 光标进提示词条」不在本片（canvas_prompt_bar.dart 无归属）。
- tc-next-shot-first-frame 同波、互不依赖；它若自建「下一镜」节点，合入后可统一到 createNextShot。
- 新节点用 invalidate 重载节点控制器（同 script_import），大画布上会有一次整表重载；如成为性能问题，后续改为控制器内插入（需改 canvas_nodes_controller，W10 无人占用但不在本片清单）。
