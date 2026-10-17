# help-actions · 帮助动作组 + 左栏帮助弹层（菜单栏帮助 = 快捷键 + 同一组动作）
- 波次 W3 / lane E / 基底：叠在 app-action-table 之后（W2 全部合入后的 origin/main）；依赖：app-action-table（`AppAction` / `AppActionIds.help*` / `kAppActions` 由它新建）、menu-split（`InkMenuEntry` / `InkMenuPanel` / `CanvasMenuPopover` 由它新建）；阻塞决定：RailScript R8 → 按建议 A（弹出菜单）。合并了原始条目 help-actions（ShellExport）与 help-actions-menu（RailScript）。

> **执行代理约定**
> - 在自己的工作树里、从基底起分支 `feat/help-actions`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加（含**删除** `startupErrorOpenLogDir`、docs/CLAUDE.md 项目结构加 `app_actions/help_actions.dart` 与 `left_rail/help_menu_popover.dart`）；代码里照常用 `context.l10n.<key>`。
> - 四张注册表每片只追加一行：本片只在 `app_action_catalog.dart` 追加 `...helpAppActions,` 一行。
> - CanvasNode 新派生属性写成新文件 extension；不给 Node/Edge/StyleLaneRepository 加抽象方法。
> - 本片不碰 canvas_tool_actions.dart。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
1. 画布左栏导航条底部多一个「帮助」键（快捷键与收起之间）。点开是锚在键右侧的弹出菜单：新手引导 · 打开示例项目 | 版本说明 ↗ · 反馈问题 ↗ · 用户手册 ↗（灰） | 导出诊断包… · 打开日志目录 | 检查更新… · 关于 InkFrame。
2. 有新版本时「检查更新…」这一行变成「有新版本 x.y.z · 下载」，帮助键挂琥珀点；结果与设置 › 关于页同一次检查。
3. 这些动作同时进 ⌘K；W4 的菜单栏「帮助」= 快捷键 + 同一组 id、同序同名。
4. 「打开日志目录」全应用只剩一个文案、一个实现（设置诊断区、启动失败页、帮助弹层同一条路）。

## 设计依据
- RailScript.dc.html ›「帮助 · 弹出菜单，不占面板」：项与分组如上；规则：「锚在帮助键右侧；点外面 / Esc 关，焦点回帮助键；不动 LeftRailState」「同一组动作：菜单栏『帮助』= 快捷键 + 这里各项，同序同名」「只放有后端的项：用户手册要先有文档站 URL，没有就灰着」「外链走 UrlOpenerService；版本说明 / 反馈问题用更新检查的 repo slug 拼 releases / issues 地址」「新手引导 = showOnboardingDialog，不改 onboardingCompleted；示例项目 = createStudioSampleProject」「导出诊断包 = 设置底部条同一动作；打开日志目录 = 启动失败页同一动作」「检查更新 = 关于页同一次检查；有新版本时换成『有新版本 · 下载』、帮助键挂琥珀点；关于 InkFrame = 打开设置 · 关于页」「各项同时进 ⌘K」。导航条规则：「帮助是动作键，不点亮、不开面板」。
- ShellExport.dc.html ›「帮助」菜单：快捷键 | 新手引导 · 打开示例项目 | 版本说明 ↗ · 反馈问题 ↗ · 用户手册 ↗（缺 URL）| 导出诊断包… · 打开日志目录 | 检查更新… · 关于 InkFrame；规则「帮助 = 左栏帮助弹层同一组动作 + 快捷键」。
- critic.txt 第二节第 15 条：两套帮助合成一组动作。revise-summary #15：「打开日志文件夹」改名「打开日志目录」，文案共用 `settingsOpenLogDir`；「关于 InkFrame」行尾显示版本号。
- 按建议：R8 → A（弹出菜单）。
- 设计缺口：① 「检查更新…」点下去后的进行中 / 已是最新 / 失败三态在弹层里怎么呈现没画——本片定为：点了就关弹层，进行中这一行灰着写「正在检查更新…」，结果用通知卡说（已是最新 = info；有新版本 = 带「下载」主按钮；失败 = error）。② 帮助键在 Studio 等非画布标签没有入口（左栏只在画布标签），等 W4 菜单栏补。③ 禁用行「悬停说原因」需要 `InkMenuEntry` 有 tooltip，menu-split 的组件没有这个字段。

## 允许改的文件
- `lib/features/app_actions/help_actions.dart`（新）：帮助组 id 序、`helpAppActions`、两个 URL 纯函数。
- `lib/features/app_actions/app_action_catalog.dart`（由 app-action-table 新建）：追加一行 `...helpAppActions,`。
- `lib/core/constants/app_repo.dart`（新，偏离：contract 未列）：`const String kInkFrameRepoSlug = 'KerroKapple/InkFrame';`——让 features 不 import services 拿常量。
- `lib/services/github_update_check_service.dart`：第 21 行默认参数改为 `repoSlug = kInkFrameRepoSlug`。
- `lib/features/settings/providers/update_check_controller.dart`：加 `availableUpdateProvider`。
- `lib/features/settings/providers/settings_page.dart`：加 `openSettingsPage`。
- `lib/features/settings/util/diagnostics_actions.dart`（新，偏离：contract 写的是把函数抽在 diagnostics_section.dart 里；放 util 免得启动失败页与帮助动作 import 一个 widget 文件）：`diagnosticsExportBusyProvider`、`exportDiagnosticsBundle`、`openLogDirectory`。
- `lib/features/settings/widgets/diagnostics_section.dart`：`_openLogs`（第 65–68 行）改调 `openLogDirectory`；`_DiagnosticsExportButtonState._export`（第 94–133 行）的主体搬到 `exportDiagnosticsBundle`，按钮 `onPressed` 看 `diagnosticsExportBusyProvider`。
- `lib/features/startup/widgets/startup_error_view.dart`：第 162 行文案换 `settingsOpenLogDir`；第 256–258 行 `_openLogs` 改调 `openLogDirectory(ref)`。
- `lib/features/canvas/widgets/left_rail/help_menu_popover.dart`（新）：`HelpMenuButton`（帮助键 + 琥珀点 + 弹层）。
- `lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`：第 96–97 行之间插入 `HelpMenuButton`；`_openShortcutSettings`（第 112–117 行）改调 `openSettingsPage`；改头注第 10 行（「帮助」现在画了）。
- `lib/theme/primitives/ink_activatable.dart`：加可选 `FocusNode? focusNode`（为空时沿用内部节点），弹层关后把焦点还给帮助键要用。
- `lib/theme/components/ink_menu_panel.dart`（由 menu-split 新建）：`InkMenuEntry` 加可选 `String? tooltip`，行外包 Tooltip（禁用行显示原因）。
- 测试：`test/features/app_actions/help_actions_test.dart`（新）、`test/features/canvas/widgets/left_rail/help_menu_popover_test.dart`（新）、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`（追加）、`test/features/settings/update_check_controller_test.dart`（追加）、`test/features/startup/startup_error_view_test.dart`（第 171、218、406 行 `startupErrorOpenLogDir` → `settingsOpenLogDir`）。

## 不许碰的文件
- undo-adopt-existing：`util/canvas_node_delete.dart`、`util/canvas_snackbars.dart`、`widgets/stage/stage_edge_layer.dart`、`widgets/stage/node_card_slot.dart`、`node_inputs_section.dart`、`models/commands/**`。
- marquee-select：`widgets/stage/stage_pointer_layer.dart`、`widgets/canvas_view.dart`、`widgets/marquee_layer.dart`、`providers/canvas_marquee.dart`、`providers/canvas_tool_mode.dart`。
- tc-set-current：`providers/current_take_controller.dart`、`inspector_history_panel.dart`、`image_result_inspector.dart`、`video_result_inspector.dart`、`result_inspector_parts.dart`、`node_card.dart`、`canvas_menu/set_current_menu_items.dart`、`notifications/widgets/job_notification_listener.dart`、`export/widgets/export_video_dialog.dart`。
- import-media-command：`shortcuts/import_media_keys.dart`、`util/canvas_import_actions.dart`、`canvas_menu/import_media_menu_items.dart`。
- `providers/left_rail_state.dart`（不加页、不加状态）、`command_palette/command_actions.dart` 与 `palette_search.dart`（⌘K 已经按表过滤，`labelFor` 已接好，不必改）、`studio/widgets/onboarding_dialog.dart`、`settings/widgets/about_section.dart`。

## 具体改动
```dart
// app_actions/help_actions.dart
const List<List<String>> kHelpPopoverGroups = <List<String>>[
  <String>[AppActionIds.helpOnboarding, AppActionIds.openSampleProject],          // openSampleProject 复用 file 组那一行
  <String>[AppActionIds.helpReleaseNotes, AppActionIds.helpFeedback, AppActionIds.helpManual],
  <String>[AppActionIds.helpExportDiagnostics, AppActionIds.helpOpenLogDir],
  <String>[AppActionIds.helpCheckUpdate, AppActionIds.helpAbout],
];
const List<List<String>> kHelpMenuGroups = <List<String>>[<String>[AppActionIds.helpShortcuts], ...kHelpPopoverGroups]; // W4/W7 菜单栏读它
Uri releaseNotesUri(String repoSlug);   // https://github.com/<slug>/releases
Uri feedbackUri(String repoSlug);       // https://github.com/<slug>/issues/new
final List<AppAction> helpAppActions;   // 9 行：helpShortcuts / helpOnboarding / helpReleaseNotes / helpFeedback / helpManual /
                                        // helpExportDiagnostics / helpOpenLogDir / helpCheckUpdate / helpAbout；group = help；inPalette = overlay == null
// settings/providers/update_check_controller.dart
final availableUpdateProvider = Provider<UpdateCheckResult?>(...); // updateCheckControllerProvider 的值 updateAvailable 时给结果，否则 null
// settings/providers/settings_page.dart
void openSettingsPage(WidgetRef ref, SettingsPage page); // 先置 settingsPageProvider，再 openOverlay(ShellOverlay.settings)
// settings/util/diagnostics_actions.dart
final diagnosticsExportBusyProvider = StateProvider<bool>(...);
Future<void> exportDiagnosticsBundle(BuildContext context, WidgetRef ref); // 在途时直接返回；成败卡与现按钮一致
void openLogDirectory(WidgetRef ref);                                       // appPathsProvider.logs → folderOpenerProvider.open(..).ignore()
// canvas/widgets/left_rail/help_menu_popover.dart
class HelpMenuButton extends ConsumerStatefulWidget { static Key get key; static Key entryKey(String actionId); }
```
- 各行执行：helpShortcuts → `openSettingsPage(ref, SettingsPage.shortcuts)`；helpOnboarding → `showOnboardingDialog(context)`（不碰 `onboardingCompleted`）；helpReleaseNotes / helpFeedback → `urlOpenerServiceProvider.openExternal(..)`，打不开出 error 卡（复用 `settingsAboutUpdateOpenFailed`，dedupeKey 各一个）；helpManual → isEnabled 恒假、原因 `helpManualNoUrl`；helpExportDiagnostics → `exportDiagnosticsBundle`，`isEnabled = !busy`、原因 `helpReasonExporting`；helpOpenLogDir → `openLogDirectory`；helpAbout → `openSettingsPage(ref, SettingsPage.about)`。
- helpCheckUpdate：`contextualLabel` = 有新版本 ⇒ `helpUpdateAvailable(version)`，检查中 ⇒ `settingsAboutUpdateChecking`，否则 `helpCheckUpdate`；`isEnabled` = 不在检查中；`run` = 有新版本 ⇒ 打开 `releaseUrl ?? releaseNotesUri(slug)`；否则 `await checkNow()` 后按结果出卡：最新 ⇒ info `settingsAboutUpdateUpToDate`；有新版 ⇒ info `settingsAboutUpdateAvailable(v)` + 主按钮「下载」（`helpUpdateDownload`）；失败 ⇒ error `settingsAboutUpdateCheckFailed`。
- 弹层：`HelpMenuButton` = `_RailKey` 同款外观（glyph `InkGlyph.help`、idleColor fg5、不点亮）+ 右上 `InkSpacing.s6` 圆点（`c.accent`，同 notification_bell.dart 第 175–179 行写法，`availableUpdateProvider != null` 才画）；点开用 menu-split 的 `CanvasMenuPopover` 锚在键右缘（左对齐键右沿 + `InkSpacing.xs`，顶对齐键顶），内容 `InkMenuPanel<String>`：groups = `kHelpPopoverGroups` 映射成 `InkMenuEntry(value: id, label: a.labelFor(c, l), enabled: a.isEnabled(c), tooltip: a.disabledReason(c, l), keyHint: 外链三行 '↗'、关于行 = packageInfoProvider 的版本号)`；选中 → 先关弹层再 `a.run(AppActionContext.read(context, ref))`；Esc / 点外面 / 选中后焦点都回帮助键（`focusNode.requestFocus()`）。

## 行为规则与边界情况
1. 帮助键不点亮、不改 `leftRailProvider`（展开 / 收起、停在哪页都不变）。
2. 弹层开着再点帮助键 = 关；点弹层外 = 关；Esc = 关；三种都把焦点还给帮助键。弹层不在 Esc 阶梯上（它自己持焦）。
3. 用户手册：灰着，悬停「还没有在线手册」，点不动、↑↓ 跳过。
4. 有新版本：行文案「有新版本 0.9.4 · 下载」、点 = 打开发布页（不再检查）；帮助键琥珀点；设置 › 关于页显示同一结果（同一个 controller）。启动静默检查得到的新版本也触发琥珀点。
5. 检查中再点：该行灰着不可点；失败不改 state 以外的东西（失败后琥珀点不出现）。
6. 导出诊断包在途（无论是从设置按钮还是帮助弹层发起）：另一个入口灰着，原因「正在导出…」；取消选位置 = 零调用零卡（同现状）。
7. 新手引导：再看一次向导，`onboardingCompleted` 已是 true 时保持 true；向导内建项目照常可用。
8. ⌘K：设置浮层没开时，9 个帮助动作 + 打开示例项目都可搜到（在表序末尾，原有动作排在前面不变）；禁用的（手册、在途的诊断包）不进 ⌘K。
9. 外链只走 `UrlOpenerService`（http/https），打不开出 error 卡，不崩。
10. macOS / Windows：帮助弹层两平台一样；W4/W7 菜单栏在 mac 进系统菜单栏「帮助」、在 Windows 进自绘菜单栏，二者都读 `kHelpMenuGroups`。键位：只有「快捷键」一项没有快捷键，帮助组本片不注册任何新键。
11. 不进撤销栈。

## 新文案键
| key | en | zh |
|---|---|---|
| leftRailHelp | Help | 帮助 |
| helpShortcuts | Keyboard shortcuts | 快捷键 |
| helpOnboarding | Getting started | 新手引导 |
| helpReleaseNotes | Release notes | 版本说明 |
| helpFeedback | Report an issue | 反馈问题 |
| helpManual | User guide | 用户手册 |
| helpManualNoUrl | The user guide isn't online yet | 还没有在线手册 |
| helpCheckUpdate | Check for updates… | 检查更新… |
| helpUpdateAvailable | New version {version} · Download | 有新版本 {version} · 下载 |
| helpUpdateDownload | Download | 下载 |
| helpAbout | About InkFrame | 关于 InkFrame |
| helpReasonExporting | Exporting… | 正在导出… |
| helpUpdateDotLabel | Help · update available | 帮助 · 有新版本 |
复用：`studioCreateSampleProject`（打开示例项目，菜单文案统一由 W4 定）、`settingsExportDiagnostics`、`settingsOpenLogDir`、`settingsAboutUpdate*`。删除：`startupErrorOpenLogDir`（及其 `@` 描述）。

## 测试
先写 1–4、9（URL 函数 / provider / 帮助键不存在 = 红）。
- `test/features/app_actions/help_actions_test.dart`（新）：
  1. 「两个入口同一组动作」：`kHelpMenuGroups.first == [helpShortcuts]`、`kHelpMenuGroups.skip(1) == kHelpPopoverGroups`；每个 id `appActionById != null`。
  2. 「URL 用 repo slug 拼」：`releaseNotesUri(kInkFrameRepoSlug).toString() == 'https://github.com/KerroKapple/InkFrame/releases'`；feedback 同理 `/issues/new`；GithubUpdateCheckService 默认 slug == `kInkFrameRepoSlug`（构造后经 fake dio 请求路径断言）。
  3. 「手册灰着有原因」：isEnabled 假、原因 == `helpManualNoUrl`。
  4. 「检查更新的文案跟结果走」：override `updateCheckControllerProvider` 为三态（null / AsyncLoading / 有 0.9.4）→ `labelFor` 依次 == `helpCheckUpdate` / `settingsAboutUpdateChecking` / `helpUpdateAvailable('0.9.4')`；Loading 时 isEnabled 假。
  5. 「有新版本时点 = 打开发布页，不再检查」：fake UrlOpener 收到 releaseUrl；fake 服务 `check` 调用次数 0。
  6. 「诊断包在途时另一个入口灰着」：`diagnosticsExportBusyProvider` = true → helpExportDiagnostics isEnabled 假、原因 == `helpReasonExporting`。
  7. 「新手引导不改完成标记」：prefs.onboardingCompleted = true → run → 出 OnboardingDialog、prefs 仍 true。
- `test/features/canvas/widgets/left_rail/help_menu_popover_test.dart`（新）：
  8. 「点帮助键开弹层，项与分组按 kHelpPopoverGroups」：四组、按序文案；`leftRailProvider` 前后相等。
  9. 「Esc 关弹层、焦点回帮助键」：Esc → 弹层消失、帮助键的 FocusNode `hasPrimaryFocus`。
  10. 「点关于 → 设置浮层停在关于页」。
- `canvas_left_rail_test.dart` 追加 11.「有新版本挂琥珀点，没有不挂」：override `availableUpdateProvider` → 点的 Container 存在 / 不存在；12.「快捷键键仍落在快捷键页」= 现有第 161 行用例不改、仍绿。
- `update_check_controller_test.dart` 追加 13.「availableUpdateProvider：只有 updateAvailable 时非空」。
- `startup_error_view_test.dart`：三处换键后原断言全绿（14. 启动页按钮文案 == `settingsOpenLogDir`，点它 FolderOpener 收到 logs 路径——现第 218 行用例）。
- 现有 `diagnostics_section_test.dart`（含「busy 防重入」）、`command_palette_test.dart` 一行不改、全绿。

## 变异点
1. help_actions.dart：`kHelpMenuGroups` 去掉开头的 `[helpShortcuts]` → 用例 1 红。
2. help_actions.dart：`releaseNotesUri` 路径写成 `/releases/latest` → 用例 2 红。
3. help_actions.dart：helpManual 的 isEnabled 改真 → 用例 3 红。
4. help_actions.dart：helpCheckUpdate 去掉 `contextualLabel` → 用例 4 红。
5. help_actions.dart：helpCheckUpdate 的 run 不判有新版本、一律 `checkNow()` → 用例 5 红。
6. help_actions.dart：helpExportDiagnostics 的 isEnabled 不看 busy → 用例 6 红。
7. help_menu_popover.dart：关弹层时不调 `focusNode.requestFocus()` → 用例 9 红。
8. help_menu_popover.dart：琥珀点条件改成恒真 → 用例 11 红。
9. startup_error_view.dart：第 162 行文案换成 `settingsExportDiagnostics` → 用例 14 红。
10. diagnostics_actions.dart：`exportDiagnosticsBundle` 去掉在途判断 → diagnostics_section_test「busy 防重入」红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/app_actions test/features/canvas/widgets/left_rail test/features/settings test/features/startup test/features/command_palette --exclude-tags golden`；逐条跑 10 个变异。
- 截图（test/_harness/screenshot.dart，CanvasScreen + fake_canvas，Windows 与 macOS 各一套）：① 导航条底部三键「快捷键 · 帮助 · 收起」；② 弹层展开（无新版本）：四组、手册灰、关于行尾版本号 0.9.3；③ 悬停手册行出「还没有在线手册」；④ override 有新版本 0.9.4：帮助键琥珀点 + 弹层里「有新版本 0.9.4 · 下载」；⑤ ⌘K 输入「log」出「打开日志目录」；⑥ 启动失败页按钮文案「打开日志目录」。

## 风险与不确定
- 改了两个 theme 层文件（`ink_activatable.dart` 加可选 focusNode、`ink_menu_panel.dart` 加可选 tooltip）：都是可选参数、默认行为不变；若主 Agent 判定 W3 有别的切片同时改它们，tooltip 可降级为把原因写进 `keyHint`。
- `CanvasMenuPopover` 的定位 API 以 menu-split 合入版为准；若它只支持舞台坐标，就在 help_menu_popover.dart 里用 `OverlayPortal` + `CompositedTransformFollower` 自己锚。
- 帮助项进 ⌘K 后 Studio 上下文从 3 条变 13 条：`command_palette_test`「studio 上下文 … 点 Open settings」靠位置点击，原动作在表序前面，应仍在可视区；若红，不改该测试，回报主 Agent 决定是否收窄帮助行的 `inPalette`。
- 删除 `startupErrorOpenLogDir` 是 ARB 变更，由主 Agent 同提交做；英文因此从「Open log directory」变成「Open log folder」。
