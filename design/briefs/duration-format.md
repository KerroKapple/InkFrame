# duration-format · 统一时长 / 耗时格式函数

- 波次 W0 · lane E · 基底：叠在 multi-select-core 之后（`feat/multi-select-core` 分支；两片文件不相交，只是同 lane 串行）
- 依赖切片：无（multi-select-core 只是同 lane 前序）
- 阻塞决定：无

> **执行代理约定**
> - 在自己的工作树里、从「基底」写的前序切片分支（`feat/multi-select-core`；它若已合入则从 origin/main）起分支 `feat/duration-format`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `l.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（本片不碰）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart（本片不涉及）。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（本片不涉及）。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`（本片不涉及）。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
全应用只有一份「时长 / 耗时」写法：不到 60 秒写「N 秒」，满 60 秒写 m:ss，估算值前加「~」。本片只交付纯函数和测试，**不改任何调用方**——产物检查器片长（W11 result-inspector-align）、剧本面板 / 导入对话框（W11 script-import、W12 rail-script-panel）、任务弹层 / 通知 / 系统通知（W8 job-timing、W10 system-notifications）、批量运行「预计 4:10」（W9 job-eta）、花费明细里的「5 秒」（W2 node-cost）后续各自接上。用户这一片看不到变化。

## 设计依据
- **RailScript.dc.html · 剧本面板**：「时长：有 `duration_ms` 用实数，否则按字数估（中文 4 字/秒，英文 2.5 词/秒，最少 2 秒）；显示走统一时长格式：不满 60 秒「N 秒」，满 60 秒 m:ss」。段落行示例「4 秒」（实数）、「~5 秒」「~2 秒」「~14 秒」（估算，前缀 `~`）。
- **GapsPanels.dc.html · 产物检查器三处对齐 ②**：片长「00:00:05」改统一格式「5 秒」。**剧本导入对话框**：「估时长 … 显示走统一时长格式（不到 60 秒「N 秒」，否则 m:ss）」；行内「2 秒 / 4 秒 / 3 秒」。
- **ShellExport.dc.html · 任务弹层显示耗时**：「一个格式函数（`formatElapsed`，纯函数）：不到 60 秒写「N 秒」，满 60 秒写 m:ss；任务弹层、通知卡、系统通知都用它」；示例「1:12」「8 秒」「2:03」「用时 18 秒」。critic 第 20 条：系统通知曾写「1 分 12 秒」，改为共用此函数（板上已是「用时 1:12」）。
- **TakesCost.dc.html · 花费预告**：「耗时 … 格式全应用共用：不到 60 秒写「N 秒」，满 60 秒写 m:ss」，「预计 4 分钟」已改「预计 4:10」。
- 本片定下的合并规则（四块板一致处 + 补齐缺口）：
  1. 秒数 < 60 →「N 秒」/ en `Ns`；60 ≤ 秒数 < 3600 → `m:ss`（分不补零，秒补两位）。
  2. **设计缺口：满 1 小时的写法四块板都没画**。按建议：写 `h:mm:ss`（与 m:ss 同族、等宽对齐不跳）。
  3. 估算值前缀「~」（RailScript 段落行的写法）。**设计缺口**：GapsPanels 导入对话框汇总行写「约 9 秒」——那是整句文案（「3 镜 · 约 9 秒 · …」），归 W11 script-import 自己的 ARB 键，不走本函数的 `estimated`。
  4. **设计缺口：舍入方式没画**。按建议：`formatDurationLabel`（片长、估时长）四舍五入到秒，且 >0ms 至少写 1 秒；`formatElapsed`（计时器，弹层每秒刷新）向下取整，避免「59.6 秒」提前跳成 1:00 又停一秒。
  5. 负数 / 0：写「0 秒」，不抛。
- `gallery_time.galleryFormatDuration`（00:00:05）这片不动；`storyboard/util/duration_estimate.dart`（按字数估）归 W11 script-import；`sequence/util/timecode.dart`（时间码 HH:MM:SS:FF）不是同一件事，不动。

## 允许改的文件
- `lib/l10n/duration_format.dart`（新建）：`formatDurationLabel`、`formatElapsed` 两个纯函数（只依赖 `AppLocalizations`，无 Flutter widget 依赖）。
- `test/l10n/duration_format_test.dart`（新建）：见「测试」。

## 不许碰的文件
- W0 menu-split：`lib/features/canvas/widgets/create_node_menu.dart`、`lib/features/canvas/widgets/canvas_menu/**`、`lib/theme/components/ink_menu_panel.dart`。
- W0 canvas-view-split：`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/stage/**`。
- W0 esc-ladder → zoom-reset-100：`lib/features/canvas/widgets/canvas_shortcuts.dart`、`lib/features/canvas/widgets/shortcuts/**`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/canvas/util/canvas_zoom.dart`、`lib/features/canvas/util/escape_ladder.dart`、`lib/features/canvas/providers/canvas_escape_ladder.dart`。
- W0 undo-stack → naming-shot-unify：`lib/features/canvas/providers/canvas_history_controller.dart`、`lib/features/canvas/models/canvas_command.dart`、`lib/features/canvas/models/edge_endpoints.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`。
- W0 multi-select-core（同 lane 前序）：`lib/features/canvas/providers/canvas_selection_controller.dart`、`lib/features/canvas/util/selection_geometry.dart`。
- 本片额外不碰：`lib/features/gallery/util/gallery_time.dart`、`lib/features/sequence/util/timecode.dart`、`lib/features/canvas/widgets/canvas_prompt_bar.dart`（里面的 `'${…}s'` 摘要归后续片）。

## 具体改动
```dart
// lib/l10n/duration_format.dart
import 'generated/app_localizations.dart';

/// 片长 / 估时长：四舍五入到秒（>0ms 至少 1 秒）；<60 →「N 秒」，<3600 → m:ss，否则 h:mm:ss；
/// [estimated] 时整体套 l.durationEstimated(...)（「~5 秒」「~1:12」）。
String formatDurationLabel(AppLocalizations l, int ms, {bool estimated = false});

/// 计时（已用 / 排队 / 用时）：向下取整到秒；负值当 0；分档同上；不带 ~。
String formatElapsed(AppLocalizations l, Duration d);
```
- 两个函数共用一个私有 `String _tiered(AppLocalizations l, int seconds)`；m:ss / h:mm:ss 是格式量（同 `formatCostUsd` 的口径，不入 ARB），「N 秒」与「~」前缀走 ARB。
- 不新增 provider、不新增依赖。

## 行为规则与边界情况
1. `formatDurationLabel(l, 5000)` → zh「5 秒」/ en「5s」。
2. 59 499ms → 「59 秒」；59 500ms → 四舍五入成 60 → 「1:00」（档位按舍入**之后**的秒数判）。
3. 72 000ms → 「1:12」；600 000ms → 「10:00」（分不补零）；3 599 000ms → 「59:59」。
4. 3 600 000ms → 「1:00:00」；3 723 000ms → 「1:02:03」。
5. 1ms ~ 499ms → 「1 秒」（有时长就不写 0）；0ms 与负数 → 「0 秒」。
6. `estimated: true`：5 000 → 「~5 秒」；74 000 → 「~1:14」；0 → 「~0 秒」。
7. `formatElapsed(l, Duration(milliseconds: 59 999))` → 「59 秒」（向下取整，不进位）；60 000 → 「1:00」；`Duration(seconds: -3)` → 「0 秒」。
8. `formatElapsed` 与 `formatDurationLabel` 对整秒输入结果完全一致（同一个 `_tiered`）。
9. 纯函数：不读时钟、不读 locale 之外的任何状态；同一输入在 mac / Windows 结果一致（无平台差异）。
10. 与撤销栈、并发无关（纯格式化）。

## 新文案键
| key | en | zh |
|---|---|---|
| `durationSeconds`（placeholder `seconds`: int） | `{seconds}s` | `{seconds} 秒` |
| `durationEstimated`（placeholder `duration`: String） | `~{duration}` | `~{duration}` |

（en 用 `{seconds}s` 与现有 `inspectorVideoDurationOption` 同风格；不走 plural——「1s / 5s」无单复数差异。）

## 测试
文件 `test/l10n/duration_format_test.dart`（新建）。用 `lookupAppLocalizations(const Locale('zh'))` / `Locale('en')` 直接拿 `AppLocalizations`，不起 widget。先写，在函数为空实现时全部红。
- `group('formatDurationLabel')`
  - `'不到 60 秒写 N 秒'`：5000 → zh「5 秒」、en「5s」。
  - `'满 60 秒写 m:ss，分不补零'`：72000 →「1:12」；600000 →「10:00」；3599000 →「59:59」。
  - `'档位按四舍五入后的秒数判'`：59499 →「59 秒」；59500 →「1:00」。
  - `'满 1 小时写 h:mm:ss'`：3600000 →「1:00:00」；3723000 →「1:02:03」。
  - `'有时长至少写 1 秒，0 与负数写 0 秒'`：1 →「1 秒」；499 →「1 秒」；0 →「0 秒」；-500 →「0 秒」。
  - `'estimated 加 ~ 前缀'`：(5000, estimated) →「~5 秒」；(74000, estimated) →「~1:14」。
- `group('formatElapsed')`
  - `'向下取整，不提前进位'`：59999ms →「59 秒」；60000 →「1:00」；72999 →「1:12」。
  - `'负值当 0'`：-3s →「0 秒」。
  - `'整秒输入与 formatDurationLabel 同结果'`：对 [0, 8, 59, 60, 72, 123, 3600] 秒逐个断言两者相等。

## 变异点
1. 把 `< 60` 改成 `<= 60` → `'档位按四舍五入后的秒数判'`（59500 期望「1:00」会变「60 秒」）与 `'向下取整，不提前进位'`（60000 期望「1:00」）红。
2. 档位改为按舍入**前**的毫秒判（`ms < 60000`）→ `'档位按四舍五入后的秒数判'` 红（59500 会写成「60 秒」）。
3. m:ss 的分补零（`padLeft(2,'0')`）→ `'满 60 秒写 m:ss，分不补零'` 红（「01:12」）。
4. 删掉小时档（一律 m:ss）→ `'满 1 小时写 h:mm:ss'` 红（「60:00」）。
5. `formatDurationLabel` 去掉「>0 至少 1 秒」→ `'有时长至少写 1 秒…'` 红（499 →「0 秒」）。
6. `estimated` 分支不套 `durationEstimated` → `'estimated 加 ~ 前缀'` 红。
7. `formatElapsed` 改成 `.round()` → `'向下取整，不提前进位'` 红（59999 →「1:00」）。
8. `formatElapsed` 去掉负值钳制 → `'负值当 0'` 红（「-3 秒」）。

## 验收
- 主 Agent 加两个 ARB 键并 `flutter gen-l10n` 后跑：`flutter analyze lib test`、`flutter test test/l10n/`、上面 8 条变异。
- 无 UI，不截图。
- `git diff --stat` 只有两个新文件。

## 风险与不确定
- 「满 1 小时写 h:mm:ss」与舍入方式是本片补的缺口（四块板都没画），若主 Agent / 设计要改，只改 `_tiered` 与对应用例。
- en 文案「5s」与系统通知（W10）在英文下是否要「5 sec」读屏友好，留给 W10 再议；本片只给一个键。
- `lib/l10n/` 下新增 dart 文件：`no_magic_strings_test` 对 `l10n/` 路径整体跳过，不受影响；docs/CLAUDE.md 的目录说明由主 Agent 补一行。
