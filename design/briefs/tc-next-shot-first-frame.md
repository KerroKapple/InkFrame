# tc-next-shot-first-frame · 节点右键「当下一镜的首帧 ›」
- 波次 W10 / lane C / 基底：origin/main（W0–W9 已合入）；依赖切片：
  - menu-split（W0：InkMenuPanel 子菜单、menu_registry）、undo-stack（W0）、current-take（W1：`currentResultFor`）。
  - narrative-splice（W1：`replaceRoleEdge` / `addEdgesInTx`）、undo-node-create-move（W4：「建好并连线」算一步的命令）、undo-edges（W5：连线 / 替换的命令）、tc-take-edge-follow（W5）、canvas-capsule（W1）。
  - 阻塞决定：无（TakesCost Q7 → A：下一镜是图像配置时置灰说明；首帧边跟着当前 take 走依赖 TC-Q1 → A，已在 W5 落地）

## 目标（用户看到什么变化，2–4 行）
在一张图像 take 上右键，或者在有当前 take 的图像配置卡上右键，菜单里多一项「当下一镜的首帧 ›」。子菜单列出叙事链上的下一镜，选一个，就把这张图接成那一镜的首帧。
链尾没有下一镜时，自动在右侧同一条泳道里建一个视频配置，连好叙事线和首帧线。
整组操作是一个事务，Ctrl Z（mac 上是 ⌘Z）一次撤掉。
视频配置检查器在模型不支持首帧、却连了首帧时，模型行下面出一行黄字。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
`b2/project/TakesCost.dc.html`「当下一镜的首帧」：
- 下一镜 = 来源配置节点的叙事后继。在 take 卡上右键用这张 take；在配置卡上右键用它的当前 take。
- 子菜单示例：「02 · 江上孤舟」「02b · 远景分支」，多个后继按 sortOrder 列出。
- 按下一镜的情况分别处理：

  | 下一镜 | 处理 |
  |---|---|
  | 没有（链尾） | 右侧同泳道建视频配置，连好叙事 + 首帧 |
  | 视频配置，没首帧 | 连一条首帧边 |
  | 视频配置，已有首帧 | 确认后替换；已经是这张 → 打勾置灰 |
  | 镜头节点（剧本） | 走「用本镜备注生成」，建视频配置再连 |
  | 图像配置 | 置灰并说明（Q7） |
  | 模型不支持首帧 | 照连，不换模型；检查器模型行出黄字 |
- 一次 Ctrl Z 撤掉整组（节点 + 边）。视频 take 不出这一项；「尾帧当首帧」要先抽帧，放到 P2。
- `b2/project/Selection.dc.html`：单选产物时，浮动条上的「当下一镜的首帧」归 W13 selection-toolbar，本片只提供动作函数。
- `revise-summary.txt`：节点右键的整体顺序是「设为当前 · 当下一镜的首帧 ›」放在同一组。
- 设计缺口：链尾时子菜单里写什么，画板没画。本片定为子菜单只有一行「新建下一镜（视频配置）」，保持「›」的一致性。
- 设计缺口：配置卡还没有成片时，画板没画。本片定为这一项置灰，原因写「这一镜还没有成片」。
- 设计缺口：下一镜是镜头节点、但它没写备注时，画板没画。本片定为那一行置灰，原因写「这一镜还没有备注」（与 shot_config_inspector 的生成按钮同一判据）。
- 设计缺口：下一镜是镜头节点、它后面已经接着一个视频配置时，画板没画。本片定为直接对那个视频配置按「视频配置」那几种情况处理，不再新建。
- 设计缺口：模型不支持首帧时，菜单这一行要不要提示，画板只说了检查器。本片在那一行尾加一个小字「模型不支持首帧」，这一行仍然可点。
- 设计缺口：接好以后有没有反馈，画板没画。本片用画布胶囊写「已当作『02 · 江上孤舟』的首帧」，带「撤销」按钮。
- 设计缺口：导入的图片（没有来源配置）出不出这一项，画板没说。本片定为不出，因为找不到下一镜。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/util/next_shot_frame.dart`（新建）：纯计划函数 `nextFrameMenuFor` 和落点、typeConfig 的纯函数。
- `lib/features/canvas/util/canvas_next_frame_actions.dart`（新建）：`applyNextFrame`，负责执行、确认、事务、入撤销栈、胶囊。
- `lib/features/canvas/widgets/canvas_menu/next_frame_menu_entries.dart`（新建）：父项 + 子菜单行，交回 pick。
- `lib/features/canvas/widgets/canvas_menu/menu_registry.dart`（W0 menu-split / esc-ladder 新建，以落地为准）：节点菜单在「设为当前」所在的那一组里追加一行（只追加，不动别的行）。
- `lib/features/canvas/widgets/video_config_inspector.dart`：模型分组里，在供应商下拉那一行（`InspectorRow(label: l.inspectorProviderLabel…)`，第 132 行起）之后加一行黄字提示。为此要 watch 本节点的 data 入边，用的是 `canvasEdgesControllerProvider(canvasId)` 的 select。
- 测试：
  - `test/features/canvas/util/next_shot_frame_test.dart`（新建）。
  - `test/features/canvas/util/canvas_next_frame_actions_test.dart`（新建）。
  - `test/features/canvas/widgets/next_frame_menu_test.dart`（新建）。
  - `test/features/canvas/widgets/video_config_inspector_first_frame_test.dart`（新建）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- next-shot：`util/next_shot.dart`、`providers/next_shot_controller.dart`、`util/create_menu_model.dart`（`nextNarrativeSortOrder`、`narrativeAnchorOf` 只 import 调用）、`canvas_menu/create_menu_entries.dart`、`shortcuts/next_shot_keys.dart`、`widgets/shot_config_inspector.dart`（「用本镜备注生成」只照抄判据，不改它）。
- batch-run-executor：`lib/features/generation/providers/batch_run_controller.dart`、`lib/features/generation/generation_controller.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`shell_task_capsule.dart`。
- script-tables：`lib/core/db/columns.dart`、`lib/core/interfaces/unit_of_work.dart`、`lib/storage/postgres_unit_of_work.dart`、`lib/core/di/repositories.dart`、`lib/storage/**`、`lib/services/import/import_remapper.dart`（只读用，不改）。
- system-notifications：`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`、`lib/features/notifications/**`、`lib/main.dart`、`pubspec.yaml`。
- 全波禁区：
  - `models/canvas_command.dart`（复用已有命令）。
  - `util/canvas_tool_actions.dart`、`util/node_menu_model.dart`、`canvas_menu/node_menu_entries.dart`、`widgets/canvas_shortcuts.dart`（骨架和注册表）。
  - `providers/canvas_edges_controller.dart`、`providers/canvas_nodes_controller.dart`（只调用）、`util/result_placement.dart`（只调用）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：script-tables：`lib/core/interfaces/project_archive_reader.dart`、`lib/core/models/import_plan_data.dart`、`lib/services/project_archive_service.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/repositories/postgres_project_archive_reader.dart`、`lib/storage/repositories/postgres_project_import_writer.dart`；system-notifications：`lib/core/interfaces/toast_service.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/models/toast_entry.dart`、`lib/features/notifications/providers/toast_center.dart`、`lib/features/notifications/widgets/job_notification_listener.dart`、`lib/features/settings/widgets/notifications_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/next_shot_frame.dart
enum NextFrameCase { createAtChainEnd, linkFirstFrame, replaceFirstFrame, alreadyThis, viaShot, blockedImageConfig, blockedOther, blockedNoNotes }

@immutable class NextFrameRow {
  final NextFrameCase kind;
  final CanvasNode? successor;          // createAtChainEnd 时为 null
  final CanvasNode? targetVideoConfig;  // 要接首帧的视频配置（viaShot 新建时为 null）
  final String? existingFirstFrameEdgeId;
  final bool modelLacksFirstFrame;      // 目标视频配置的 provider 不支持首帧
  final int sortOrder;                  // 子菜单排序：对应叙事边的 sortOrder
  bool get enabled;                     // blocked* / alreadyThis 为 false
}

@immutable class NextFrameMenu {
  final CanvasNode? take;               // null ⇒ 父项置灰（配置还没有图像 take）
  final CanvasNode sourceConfig;
  final List<NextFrameRow> rows;        // 按 (sortOrder, 边 id) 排；链尾时只有一行 createAtChainEnd
}

/// targets 不是恰好一张、视频 take / 视频配置 / 文本 / 镜头、没有来源配置的产物 ⇒ null（这一项不出）。
NextFrameMenu? nextFrameMenuFor({
  required List<CanvasNode> targets,
  required List<CanvasNode> nodes,
  required List<CanvasEdge> edges,
  required bool Function(String? providerId) supportsFirstFrame,
});

/// 链尾新视频配置的落点：来源配置产物列（resultNodePosition index 0）再往右一个卡宽 + xxl，y 与来源配置一致。
Offset chainEndVideoConfigPosition(CanvasNode sourceConfig);
/// 镜头 → 视频配置：位置 = 镜头位置 + (kNodeCardSize.width + InkSpacing.xxl, 0)；typeConfig = {prompt: shot_notes, duration_ms?, camera?}。
/// 判据照抄 shot_config_inspector._generateVideoFromNotes（第 124–132、47 行）。
Offset videoFromShotPosition(CanvasNode shot);
Map<String, Object?> videoConfigFromShot(CanvasNode shot);

// util/canvas_next_frame_actions.dart
/// 执行之前用最新的 nodes / edges 重算一次 row（菜单开着的时候状态可能变了）。replaceFirstFrame 先弹确认框。
Future<void> applyNextFrame(BuildContext context, WidgetRef ref, {required String canvasId, required String targetNodeId, required String? successorId});
```
各情况怎么写库：
- createAtChainEnd、viaShot（新建）：一次 `UnitOfWork.run`。事务里：
  1. `scope.nodes.create`：视频配置节点。label 用 `canvasNodeDefaultLabel`；链尾时 laneId 取来源配置的，镜头情况取镜头的。
  2. 叙事边：源是来源配置（或镜头）→ 新节点，sortOrder 用 `nextNarrativeSortOrder`。
  3. data 首帧边：take → 新节点。

  边可以走 W1 的 `addEdgesInTx`，也可以直接 `scope.edges.create`，以落地为准。提交后：
  - invalidate `canvasNodesControllerProvider(canvasId)` 和 `canvasEdgesControllerProvider(canvasId)`，与 script_import_controller 第 81–82 行同一写法。
  - 用 W4「建好并连线」的那个命令，以「已执行」形态入 `CanvasHistoryController(canvasId)`；它的撤销等于删掉新节点，边跟着级联软删。
  - `canvasFocusRequestProvider.request(center: false)` 单选新节点。
- linkFirstFrame：`CanvasEdgesController.addEdge(edgeType: data, role: firstFrame)`，入栈用 W5 的连线命令。
- replaceFirstFrame：先确认（`showDialog<bool>` + AlertDialog，与 character_library_panel 第 375 行同一写法），再调 `replaceRoleEdge`（W1，单事务），入栈用 W5 对应的命令。
- 成功后发画布胶囊 `nextFrameDone(name)`，带「撤销」动作，点了走 `undoSpecific(stepId)`。
- 视频配置检查器：`hasFirstFrameIn && selected != null && !selected.supportsFirstFrame` 时，在供应商那一行下面画 `Text(l.inspectorModelNoFirstFrame, style: meta + c.accent)`。写法与 characters_section 第 224 行的 `inspectorCharactersUnsupported` 一样，警告色就是 accent。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 在图像 take（role = result，有 imageUrl，sourceNodeId 指向还在的配置）上右键：take = 这一张。在图像配置上右键：take = `currentResultFor`，固定了就是固定的那张，不是最新的那张。
2. 这一项不出：在视频 take、视频配置、文本、镜头、导入的（没有来源配置的）图片上右键；多选的时候。
3. 图像配置没有图像 take：父项照常出，但置灰，原因写「这一镜还没有成片」。
4. 后继 = 来源配置的叙事出边指向的节点，按 (sortOrder, 边 id) 排，与 `orderByNarrativeChain` 同一口径；一条后继一行。
5. 后继是视频配置、没有首帧入边：linkFirstFrame。已经有首帧，并且源就是这张 take：alreadyThis，打勾、置灰。已经有首帧，但源不是这张：replaceFirstFrame，确认后替换；在确认框里点取消，什么都不改。
6. 后继是镜头：
   - 镜头后面已经接着视频配置：按第 5 条处理那个视频配置。
   - 镜头后面没有视频配置，而且有备注：viaShot，新建视频配置（prompt 用备注，片长、运镜照搬），连上叙事线和首帧线。
   - 镜头没有备注：blockedNoNotes。
7. 后继是图像配置：blockedImageConfig，置灰，写「下一镜是图像配置，不接首帧」。后继是别的类型：blockedOther。
8. 没有后继：只有一行 createAtChainEnd。新视频配置落在来源配置的产物列右侧、同一条泳道，自己不带提示词（是一张草稿）。
9. 目标视频配置的模型不支持首帧：照样连，不换模型。子菜单那一行尾写「模型不支持首帧」；接上以后，检查器的模型行下面出黄字。连着首帧时，生成侧会抛 `first_frame_unsupported`，黄字就是在提前说这件事。
10. 事务：新建的那几种情况（节点 + 叙事边 + 首帧边）全在一个事务里。任一步失败，整体回滚，画布上什么都不多，出错误卡「没接上首帧，画布没有改动」。
11. 撤销：任何一种情况都只入栈一步。Ctrl Z（Windows）或 ⌘Z（mac）撤一次就回到右键之前的样子（新节点和两条边一起消失；替换的情况，原来的首帧边回来）。重做恢复同样的那一步。
12. 执行前重算：菜单开着的时候，别处已经给目标连上了首帧，那么点「连首帧」时实际走 replace，先弹确认框。目标已经被删了，什么都不做，胶囊写「下一镜已经不在了」。
13. 并发：同一张画布上有一次 applyNextFrame 还在途时，再点一次直接忽略（每个画布一个在途标志），不会建出两个视频配置。
14. 撤销栈的交互：W5 的边跟随规则以后再挪这条首帧边（换了当前 take）时，算 edge-follow 自己的那一步，不并进本片这一步。
15. mac 和 Windows：右键都开菜单（mac 上 Ctrl + 点击也算右键，现有行为）；本片不加快捷键。确认框里按钮的顺序用 AlertDialog 的默认排法。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| nodeMenuNextShotFirstFrame | Use as next shot's first frame | 当下一镜的首帧 |
| nextFrameCreateAtEnd | New next shot (video config) | 新建下一镜（视频配置） |
| nextFrameViaShot | {shot} · build video config from notes | {shot} · 按备注建视频配置 |
| nextFrameBlockedImage | Next shot is an image config; it takes no first frame | 下一镜是图像配置，不接首帧 |
| nextFrameBlockedOther | Next shot is not a video config | 下一镜不是视频配置 |
| nextFrameBlockedNoNotes | This shot has no notes yet | 这一镜还没有备注 |
| nextFrameNoTake | This shot has no take yet | 这一镜还没有成片 |
| nextFrameModelNoFirstFrame | Model has no first-frame support | 模型不支持首帧 |
| nextFrameReplaceTitle | Replace first frame? | 替换首帧？ |
| nextFrameReplaceBody | "{shot}" already has a first frame. Use this image instead? | 「{shot}」已经有首帧，换成这张？ |
| nextFrameReplaceConfirm | Replace | 替换 |
| nextFrameDone | Now the first frame of "{shot}" | 已当作「{shot}」的首帧 |
| nextFrameFailed | Couldn't connect the first frame; canvas unchanged | 没接上首帧，画布没有改动 |
| nextFrameTargetGone | The next shot is no longer there | 下一镜已经不在了 |
| inspectorModelNoFirstFrame | ! This model takes no first frame; generating will fail. Pick a model that does, or remove the first-frame link. | ! 这个模型不接首帧，生成时会报错：换一个支持首帧的模型，或删掉首帧线 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
`test/features/canvas/util/next_shot_frame_test.dart`（纯函数）：
- `视频 take 不出`、`多选不出`、`导入图片不出`、`文本 / 镜头不出`。
- `配置卡用当前 take 而不是最新`：两张 take，固定在较旧的那张 → `menu.take` 是旧的那张。
- `配置没有成片父项置灰`：take == null。
- `链尾一行 createAtChainEnd`；`chainEndVideoConfigPosition` 落在产物列右侧、同 laneId。
- `视频配置没首帧 → linkFirstFrame`、`已有首帧来自别处 → replace 且带 existingFirstFrameEdgeId`、`已是这张 → alreadyThis 且 enabled 为假`。
- `镜头有备注 → viaShot，videoConfigFromShot 带 prompt / duration_ms / camera`、`镜头没备注 → blockedNoNotes`、`镜头后面已有视频配置 → 按那个视频配置判`。
- `图像配置 → blockedImageConfig`。
- `多个后继按 sortOrder 排`：两条叙事边，sortOrder 是 1、0，id 顺序反着 → rows 先 0 后 1。
- `模型不支持首帧 → modelLacksFirstFrame 为真，enabled 仍为真`。

`test/features/canvas/util/canvas_next_frame_actions_test.dart`（ProviderContainer + fake 仓 + 真 UnitOfWork 替身，可以让第 N 次写失败）：
- `链尾：一个事务里一节点两边`：成功后节点 + 叙事边 + 首帧边各一条，history 栈深 +1。
- `链尾：第三次写失败整批回滚`：没有残留的节点或边，出错误卡，栈深不变。
- `撤一次全没`：undo 之后新节点和两条边都不在了。
- `replace 先确认，取消不改`、`replace 确认后原首帧被换掉，撤一次复原`。
- `执行前重算：菜单开着时别处已连首帧 → 走确认`。
- `目标已删 → 胶囊提示且不写库`。
- `在途时再点被忽略`：用 Completer 挂住 uow，连点两次 → 只建出一个节点。

`test/features/canvas/widgets/next_frame_menu_test.dart`：
- 在 take 卡上右键 → 有「当下一镜的首帧 ›」，子菜单行的文字和置灰对得上画板几种情况。
- 视频 take 上没有这一项。

`test/features/canvas/widgets/video_config_inspector_first_frame_test.dart`：
- `模型不支持且连了首帧 → 出黄字`。
- `支持首帧 → 不出`。
- `不支持但没连首帧 → 不出`。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 「视频 take 不出」的判据删掉 → 「视频 take 不出」红。
2. 配置卡的 take 改用 `latestResultFor` → 「配置卡用当前 take 而不是最新」红。
3. alreadyThis 判成 replace（不比较边的源）→ 「已是这张 → alreadyThis」红。
4. 图像配置后继判成 linkFirstFrame → 「图像配置 → blockedImageConfig」红。
5. rows 不按 sortOrder 排 → 「多个后继按 sortOrder 排」红。
6. 链尾少连叙事边（或少连首帧边）→ 「链尾：一个事务里一节点两边」红。
7. 把事务拆成 addNode + addEdge 两次独立写 → 「第三次写失败整批回滚」红（会留下残留节点）。
8. 每条边各入栈一步 → 「撤一次全没」红。
9. replace 去掉确认框 → 「replace 先确认，取消不改」红。
10. 执行时不重算、直接用菜单打开时的 row → 「执行前重算」红。
11. 去掉在途标志 → 「在途时再点被忽略」红。
12. 检查器去掉 `!supportsFirstFrame` 条件（总是出黄字）→ 「支持首帧 → 不出」红。
13. modelLacksFirstFrame 时把行置灰 → 「模型不支持首帧 → enabled 仍为真」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test` 干净；`test/features/canvas/` 全绿；上面 13 条变异逐条变红。
- 截图（CanvasScreen + 示例数据：镜头 01 图像配置带两张 take，叙事链上分出 02 视频配置〔已有别的首帧〕和 02b 视频配置〔模型不支持首帧〕两个分支）：
  - ① 在 take 2 上右键，展开子菜单（两行，第二行带「模型不支持首帧」小字）。
  - ② 替换确认框。
  - ③ 接好之后的胶囊和画布。
  - ④ 链尾的子菜单（只有一行「新建下一镜」），以及新建出来的视频配置的位置。
  - ⑤ 02b 的视频配置检查器，模型行下的黄字。

## 风险与不确定
- 同一波的 next-shot 在做 `createNextShot`（新建下一镜、继承键白名单）。本片不能依赖它，所以链尾新建的视频配置不继承任何键，落点也是本片自己用 `resultNodePosition` 算的。两片都合入以后，主 Agent 要把 createAtChainEnd 统一改走 `createNextShot`（落点、继承、sortOrder 用一套），并把这件事记进 BOARD。
- 镜头 → 视频配置这一段，照抄的是 shot_config_inspector 里的私有 `_generateVideoFromNotes` 判据（那个文件这一波归 next-shot）。原代码新建节点时不传 laneId；本片传镜头的 laneId。合入后应抽成一个共享函数。
- 撤销：要把「已经在事务里写好的节点 + 两条边」作为一步入栈，依赖 W4「建好并连线」那个命令能接受已执行的形态，并且它的撤销能级联删边。如果做不到，这里就需要一个新命令，而 canvas_command.dart 这一波不归本片。遇到这种情况，执行代理停下来回报主 Agent，不要自己改。
- `replaceRoleEdge` 换下来的旧首帧边是删掉还是降成参考，以 W1 的落地为准；确认框的文案只说「换成这张」，不承诺旧边去了哪里。
- `menu_registry` 的分组表结构、InkMenuPanel 子菜单行能不能带「置灰原因」和行尾小字，以 W0 落地为准。不支持行尾小字的话，「模型不支持首帧」改放在 tooltip 里。
