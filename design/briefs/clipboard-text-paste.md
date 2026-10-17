# clipboard-text-paste · 从别的软件粘贴文字 → 文本节点；文字指纹对得上 → 按节点粘贴；长段落给「按剧本拆镜…」
- 波次 W8 / lane D / 基底：origin/main（W0–W7 已合入）；依赖切片：clipboard-paste（W7）、canvas-clipboard-core（W7）、canvas-capsule（W1）、undo-stack（W0）、naming-shot-unify（W0）；阻塞决定：无（UndoClipboard Q5 按建议 A：Ctrl V 只建一个文本节点、不弹对话框）

## 目标（用户看到什么变化，2–4 行）
- 在别的软件里复制一段文字，回到画布按 Ctrl V（mac ⌘V），画布上出现一个文本节点，正文就是这段文字，新节点被选中。按一次 Ctrl Z 就撤掉。
- 在本应用里复制节点，然后直接粘贴，仍然粘出节点。判据是系统剪贴板里的文字和复制时写进去的那段对得上。如果中途在别处复制过别的文字，就按文字粘贴。
- 粘进来的文字有两段以上时，画布胶囊会给一个动作「按剧本拆镜…」。点它打开剧本导入对话框，文字已经填好。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/UndoClipboard.dc.html`「系统剪贴板 · 从别的软件贴进来」：文字 → 文本节点（typeConfig.text）；若是本应用复制出去的节点（文字指纹对得上）→ 按节点粘贴；复制节点时往系统剪贴板写一份纯文字（标签 + 提示词，W7 已做）。示意卡写的是「文本 · 可连到配置当提示词」。
- 同板「需要你定 5 · 粘贴一大段分段文字」：A 一个文本节点 + 胶囊「按剧本拆镜…」（建议 A，「Ctrl V 不该突然弹对话框」）。
- 同板「粘贴到哪 · 带什么」：指针在画布上 → 包围盒中心对准指针；右键「粘贴」→ 按下点；泳道按落点重判（resolveLaneDrop）。
- 同板「一次用户编辑 = 一步」：粘贴算一步。
- `b2/project/GapsCanvas.dc.html` 胶囊规则（canvas-capsule）：带动作的胶囊停 4 s，dedupeKey 相同就原地改字。
- 设计缺口：系统剪贴板为空、只有空白、或者读取失败时，画板没有画反馈。本片按「胶囊一句话」处理，见规则 9、10。
- 设计缺口：点「按剧本拆镜…」建出镜头链之后，原来那个文本节点留不留，画板没说。本片保留它，因为用户可以手动删，而且这样拆镜和粘贴是两步撤销，互不牵连。
- 设计缺口：「长段落」的判据画板没给。本片规定：用剧本导入默认策略 `splitScript(text)`（空行分段）切出 ≥ 2 块就算长段落，和对话框预览用同一个拆分口径。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/util/clipboard_snapshot.dart`（canvas-clipboard-core 新建）：
  - 加指纹判据 `clipboardFingerprintMatches`。它必须和 W7 往系统剪贴板写纯文字的那个函数共用同一个出字函数，下文叫 `snapshotPlainText`，名字以落地为准。
  - 加 `ClipboardSnapshot textNodeSnapshot(String text)`：造一个只含一个文本节点的快照，没有边、没有媒体、没有源画布。
  - 保证 `snapshotPlainText` 永远不返回空串：节点标签为空时回落到类型名。
- `lib/features/canvas/util/canvas_paste_actions.dart`（clipboard-paste 新建）：
  - 把 Ctrl V / 右键「粘贴」的入口改成先分派，再执行。分派是纯函数 `resolvePasteSource`。
  - 文字分支走 `textNodeSnapshot` + W7 现有的 `pasteSnapshot` 路径，所以落点、泳道、选中、撤销命令都和粘节点是同一条。
  - 长段落时发胶囊动作。
- `lib/features/canvas/widgets/shortcuts/clipboard_keys.dart`（clipboard-paste 新建）：粘贴键不新增，只把 Ctrl V 的 invoke 改调新入口。确认它带 `includeRepeats: false`，没有就补上。
- `lib/features/storyboard/widgets/script_import_dialog.dart`：
  - `showScriptImportDialog` 和 `ScriptImportDialog` 加可选参数 `initialText`（默认 `''`）。
  - `_ctrl` 改在 `initState` 里用 `TextEditingController(text: widget.initialText)` 创建，光标放在文末。
- `test/features/canvas/util/canvas_paste_actions_test.dart`（W7 的）：只允许给现有用例补系统剪贴板 mock（见「风险」），不删用例、不改断言。
- 新测试文件见「测试」。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- node-disabled-flag：`widgets/node_card.dart`、`widgets/left_rail/outline_panel.dart`、`models/canvas_node_disabled.dart`、`util/canvas_disable_actions.dart`、`canvas_menu/disable_menu_entries.dart`。
- align-distribute-arrange：`util/node_arrange.dart`、`util/canvas_arrange_actions.dart`、`shortcuts/arrange_keys.dart`、`canvas_menu/align_menu_entries.dart`。
- wrap-in-lane：`providers/canvas_lanes_controller.dart`、`widgets/lane_title_bar.dart`、`models/canvas_command.dart`（本片不加命令子类，复用 W7 的粘贴命令）、`util/lane_wrap.dart`、`providers/lane_rename_request.dart`。
- job-timing：`lib/services/job_queue_service.dart`、`lib/core/di/job_queue.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`lib/features/notifications/widgets/job_notification_listener.dart`。
- 通用：
  - `util/canvas_tool_actions.dart`（只允许调用 `viewportCenteredNodeOrigin`，不改它）。
  - `canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_menu/blank_menu_entries.dart`、`canvas_menu/create_menu_entries.dart`、`util/create_menu_model.dart`。
  - `widgets/canvas_shortcuts.dart` 骨架，以及 `canvas_shortcut_registry.dart` 里除追加一行以外的内容（本片连一行都不用追加）。
  - `providers/canvas_clipboard.dart`、`util/paste_placement.dart`、`providers/canvas_nodes_controller.dart`、`providers/canvas_capsule.dart`、`lib/features/storyboard/util/script_splitter.dart`（W11 script-import 的）。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// util/clipboard_snapshot.dart
String normalizeClipboardText(String raw);            // \r\n、\r → \n；去掉末尾空白（行内不动）
bool clipboardFingerprintMatches(ClipboardSnapshot snapshot, String? systemText);
    // systemText 为 null / 规范化后为空 → false；否则比较 normalize(systemText) == normalize(snapshotPlainText(snapshot))
ClipboardSnapshot textNodeSnapshot(String text);       // 一个 CanvasNodeType.text 节点，typeConfig {'text': text}，
                                                       // sourceCanvasId / projectId = null（按「别的画布」落点：视口中心）
// util/canvas_paste_actions.dart
sealed class PasteSource {}
final class PasteNodes extends PasteSource { final ClipboardSnapshot snapshot; }
final class PasteText extends PasteSource { final String text; final int paragraphCount; }
final class PasteNothing extends PasteSource {}
final class PasteReadFailed extends PasteSource {}
PasteSource resolvePasteSource({ClipboardSnapshot? appSnapshot, required String? systemText, required bool readFailed});
Future<void> pasteFromClipboard(BuildContext context, WidgetRef ref, {required String canvasId, PasteAnchor? anchor});
    // 现有入口（W7 名字以落地为准）：读 Clipboard.getData(Clipboard.kTextPlain) → resolvePasteSource → 分支执行
const int kSplitSuggestParagraphs = 2;                 // splitScript(text).length ≥ 2 → 给「按剧本拆镜…」
// storyboard/widgets/script_import_dialog.dart
Future<void> showScriptImportDialog(BuildContext context, {required String canvasId, Offset origin = Offset.zero, String initialText = ''});
```
- 分派顺序（纯函数，可单测）：
  1. readFailed → PasteReadFailed。
  2. appSnapshot 不为空且指纹对得上 → PasteNodes。
  3. normalize(systemText) 非空 → PasteText。
  4. 其余 → PasteNothing。W9 os-drop-paste-image 会在第 2、3 步之间插「文件 / 图片」分支。本片把分派写成有序的 if 链，并在注释里留出那个插入位。
- 文字分支：
  - `pasteSnapshot(textNodeSnapshot(text), anchor)`，这是 W7 那条单事务 + 一步撤销 + 粘出节点成为选中的路径。
  - 指针不在画布、也没有右键锚点时，落点用 `viewportCenteredNodeOrigin(ref, canvasId:, type: CanvasNodeType.text)`，即视口中心 + 散布，这样连按两次不会叠成一摞。
  - 节点标签用 `l.canvasNodeDefaultLabel`，与 T 键同口径。
- 胶囊：
  - 调用 `canvasCapsuleProvider(canvasId).notifier.show(...)`，签名以 W1 落地为准。dedupeKey `'paste-text-split'`。
  - 动作 = `showScriptImportDialog(context, canvasId:, origin: 文本节点左下方 (x, y + height + InkSpacing.lg), initialText: text)`。
  - 点动作时 context 已卸载就什么都不做。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 系统剪贴板是外部文字 "第三场。夜，江边客栈。"，应用内剪贴板为空。按 Ctrl V 后：画布多 1 个 `type == text` 节点，`typeConfig['text']` 等于该文字，`label == canvasNodeDefaultLabel`，选中集 = {新节点}。
2. 应用内复制了 2 个节点（W7 往系统剪贴板写了 `snapshotPlainText`），之后没有别的复制。Ctrl V 粘出 2 个节点，不建文本节点。
3. 应用内复制节点后，又在别的软件复制了别的文字。Ctrl V 建文本节点，正文是那段别的文字，不粘节点。应用内快照不清空。
4. 指纹对比前先做规范化：系统文字是快照文字把 `\n` 换成 `\r\n`、末尾多一个换行（Windows 常见），仍算对得上，结果是粘节点。
5. 文字只有一段（`splitScript` < 2 块）时不出胶囊。≥ 2 块时出胶囊「已粘贴为文本节点 · 共 N 段」+ 动作「按剧本拆镜…」，N = 块数。
6. 点「按剧本拆镜…」：对话框打开，输入框内容 = 粘贴的文字，预览已经列出 N 镜。在对话框里按取消，画布只剩那个文本节点，栈里只有「粘贴」一步。
7. 拆镜建链成功后，文本节点仍在。撤销栈顺序是「粘贴」→ 剧本导入那一步（导入是否进栈以 W4 / W0 落地为准）。
8. 撤销：粘贴文字后 Ctrl Z 一次，文本节点消失；Ctrl Y 又回来。栈里这一步的标签与粘节点同一个（「粘贴 1 个节点」）。
9. 空态：系统文字为 null、""、或全是空白，且没有对得上的快照时，不建节点。胶囊「剪贴板里没有能粘贴的内容」。
10. 读取失败：`Clipboard.getData` 抛 `PlatformException`（Windows 剪贴板被别的进程占用）时，不建节点，胶囊「读取剪贴板失败，再试一次」。只捕 `PlatformException`，不捕 Exception。
11. 让位：焦点在任何文本框里（提示词条、检查器正文、对话框输入框）时，Ctrl V 归文本框，画布不建节点。沿用 W7 键的让位 Action（`isEditingText()`，canvas_shortcuts.dart:219）。
12. 按住 Ctrl V 不放只粘一次（`includeRepeats: false`）。快速按两次建两个文本节点，散布后位置不同、各自一步撤销。
13. 泳道：指针在某条泳道的带里时，文本节点 `laneId` = 该道，判据是 W7 paste_placement 的 resolveLaneDrop。
14. 写库失败：W7 的 `pasteSnapshot` 抛 InkError 时，画布节点数不变，弹 W7 的失败卡，栈里不留这一步，也不出拆镜胶囊。
15. mac / Windows：mac 是 ⌘V，Windows 是 Ctrl V（键位沿用 W7 clipboard_keys，不新增）。mac 菜单栏「编辑 › 粘贴」走同一个入口（W7 mac-platform-menubar 接线，以落地为准）。
16. 超长文字（例如 200 KB）原样进 `typeConfig['text']`，不截断。卡片正文由 node_card 现有截断负责。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| canvasPasteTextSplitHint（int count） | Pasted as a text node · {count} paragraphs | 已粘贴为文本节点 · 共 {count} 段 |
| canvasPasteTextSplitAction | Split into shots… | 按剧本拆镜… |
| canvasPasteNothing | Nothing on the clipboard to paste | 剪贴板里没有能粘贴的内容 |
| canvasPasteReadFailed | Couldn't read the clipboard. Try again. | 读取剪贴板失败，再试一次 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/clipboard_fingerprint_test.dart`（新）：
  - `matches identical text` → true。
  - `CRLF and trailing newline still match` → true（规则 4）。
  - `different text does not match` → false。
  - `null or blank system text never matches` → false。
  - `snapshotPlainText never empty for unlabeled node` → 非空。
  - `textNodeSnapshot carries one text node, no edges, no media, no source canvas`。
- `test/features/canvas/util/canvas_paste_source_test.dart`（新，纯函数 `resolvePasteSource`）：
  - `fingerprint match → PasteNodes`。
  - `stale snapshot + foreign text → PasteText`（规则 3）。
  - `no snapshot + text → PasteText with paragraphCount = splitScript length`。
  - `blank → PasteNothing`。
  - `readFailed wins → PasteReadFailed`。
- `test/features/canvas/widgets/canvas_paste_text_shortcut_test.dart`（新，ProviderScope + fake NodeRepository；mock `SystemChannels.platform` 的 `Clipboard.getData` / `Clipboard.setData`）：
  - `Ctrl V with external text creates one selected text node`（规则 1）。
  - `Ctrl V after in-app copy pastes nodes`（规则 2）。
  - `Ctrl V inside prompt bar does nothing on canvas`（规则 11）。
  - `two-paragraph paste shows split capsule; tapping it opens dialog prefilled`（规则 5、6）。
  - `single paragraph shows no capsule`。
  - `Ctrl Z removes pasted text node, Ctrl Y restores`（规则 8）。
  - `blank clipboard shows nothing-to-paste capsule, node count unchanged`（规则 9）。
  - `PlatformException shows read-failed capsule`（规则 10）。
  - `held key pastes once`（规则 12，发 repeat 事件）。
  - `repository failure leaves no node and no capsule`（规则 14）。
- `test/features/storyboard/widgets/script_import_dialog_prefill_test.dart`（新）：
  - `initialText fills input and preview lists N shots`。
  - `default initialText keeps empty input`（老入口不变）。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. `resolvePasteSource` 去掉指纹判断，改成「有快照就 PasteNodes」→ `stale snapshot + foreign text → PasteText` 和 shortcut 用例「外部文字建文本节点」变红。
2. `normalizeClipboardText` 去掉 `\r\n` 归一 → `CRLF and trailing newline still match` 变红。
3. `kSplitSuggestParagraphs` 改成 1 → `single paragraph shows no capsule` 变红。
4. 文字分支改成直接 `nodes.addNode`、不走 `pasteSnapshot` → `Ctrl Z removes pasted text node` 变红（栈里没这一步）。
5. 去掉 `includeRepeats: false` → `held key pastes once` 变红。
6. 去掉对文本编辑的让位 → `Ctrl V inside prompt bar does nothing on canvas` 变红。
7. `ScriptImportDialog` 忽略 `initialText` → `initialText fills input` 变红。
8. 读取失败分支删掉、让 PlatformException 冒出去 → `PlatformException shows read-failed capsule` 变红。
9. 空白文字也建节点 → `blank clipboard shows nothing-to-paste capsule` 变红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/features/canvas test/features/storyboard --exclude-tags golden`；逐条跑上面 9 个变异。
- 截图：`CanvasScreen`，画布有 1 个图像配置节点，mock 剪贴板文字为两段（「第三场。夜，江边客栈。…」+ 空行 + 「第四场。…」）。截三张：
  1. Ctrl V 后：文本节点被选中，胶囊带「按剧本拆镜…」；
  2. 点动作后：剧本导入对话框，已填入文字，预览列 2 镜；
  3. 剪贴板全是空白时按 Ctrl V：胶囊「剪贴板里没有能粘贴的内容」。

## 风险与不确定
- W7 的函数名（`snapshotPlainText`、`pasteSnapshot`、`pasteFromClipboard`、粘贴命令标签）以落地为准。如果 W7 把纯文字出字函数放在 canvas_paste_actions.dart，就挪到 clipboard_snapshot.dart，或原地复用。要守住的是「写和比用同一个函数」。
- 改成「只有指纹对得上才粘节点」之后，W7 的测试如果没 mock 系统剪贴板，Ctrl V 就不再粘节点，测试会红。这类用例只补 mock，在 `setMockMethodCallHandler(SystemChannels.platform)` 里把 setData 写进去的文字原样还给 getData，不改断言。
- 外部软件恰好复制了一模一样的文字时会被当成本应用的节点。这种情况概率极低，可以接受。
- W9 os-drop-paste-image 会在分派链里插入文件 / 图片分支并改这两个文件。本片要把分派写成一处有序 if 链，方便它插入。
