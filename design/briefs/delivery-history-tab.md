# delivery-history-tab · 交付面板「历史」页签：本画布的交付记录、打开文件夹、跳到导出标签看全部
- 波次：W15 / lane：E / 基底：origin/main（W14 已合入，含 delivery-clips-tab）
- 依赖切片：delivery-clips-tab（W14，页签切换骨架 `DeliveryPanelTab` / `DeliveryPanel.tabKey`）、export-records-table（W4，表 + 仓储 + `ExportRecord`）、export-records-recording（W6，交付终态写记录）、export-tab-history（W6，`export_history_provider.dart`）
- 阻塞决定：无（SE-Q3 已按建议 A：记录一直保留，只有手动「从历史移除」——本片不提供移除）

## 执行约定
1. 在你自己的工作树里，从 origin/main（前序波已合入）起新分支 `feat/delivery-history-tab`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片一行都不加。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片不涉及节点。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 本片补充：`export_history_provider.dart` 由 export-tab-history（W6）新建，**只引用不改**；不给 `ExportRecordRepository` 加方法（筛选在本片的纯函数里做）。同 lane 后序 image-zip-export 会改 `export_new_cards.dart`，本片不碰。

## 目标
交付面板的「历史」页签能点了：列出**这张画布**做过的交付（今天 11:05 · Resolve · 8 镜），每行「打开文件夹」；失败的交付标红写原因；底部一行「全部导出历史 →」跳到导出标签。页签条下的结果条仍只回执最近一次交付，与历史列表互不替代。

## 设计依据
- 画板 `b2/project/ShellExport.dc.html` 「导出第二批」小节右下第二张交付面板（「历史」选中）。
- 规则原文：「历史 = export_records 里本画布的交付行；结果条仍只回执最近一次」；面板底部「全部导出历史 → 导出标签」。
- 行几何（画板 html）：行高 30 + 1px 下沿（surface1）；padding 0 10；左侧 11px 浅色一行文本「今天 11:05 · Resolve · 8 镜」（flex 1）；右侧 10.5px accent「打开文件夹」。底部链接行高 24、10px fg 灰、左对齐。
- 导出标签历史的统一规则（同画板「导出历史」）：「三条路径完成或失败各记一行，取消不记」。
- 设计缺口：①没画失败的交付行——按 R4（左文案后接「失败 · 原因」danger 色，右侧不给「打开文件夹」）；②没画空态；③没画「文件夹已不在」——本片不做存在性检查（R6）；④行数上限没写——全部列出，区域可滚动。

## 允许改的文件
- `lib/features/export/widgets/delivery_panel.dart`：把 `DeliveryPanelTab.history` 加进可点集合；body 切换加 history → `DeliveryHistoryTab`；文件头注释同步。
- `lib/features/export/widgets/delivery_history_tab.dart`（新建）：`DeliveryHistoryTab` + 行组件 + 纯函数 `deliveryHistoryRows`。
- `lib/theme/tokens.dart`：只追加（若 delivery-clips-tab 加的 `InkDeliveryListSize.rowHeight` 已够用就不加；需要的话追加 `linkRowHeight = 24`）。
- `test/features/export/widgets/delivery_history_tab_test.dart`（新建）

## 不许碰的文件
- 同 lane 后序 image-zip-export：`core/interfaces/image_zip_export_service.dart`、`services/archive_image_zip_export_service.dart`、`core/di/image_zip_export.dart`、`export/util/image_zip_manifest.dart`、`export/widgets/image_zip_export_dialog.dart`、`export/widgets/export_new_cards.dart`。
- `export/providers/export_history_provider.dart`、`export_history_recorder.dart`、`export/widgets/export_history_list.dart`、`export_history_row.dart`、`shell/widgets/tabs/export_tab.dart`（W6 的，只引用）。
- W15 其他 lane：`widgets/node_card.dart`、`node_card_slot.dart`、`widgets/text_node_inspector.dart`、`providers/inspector_submit_controller.dart`、`providers/left_rail_state.dart`、`widgets/canvas_inspector_panel.dart`、`widgets/canvas_screen.dart`、`left_rail/script_panel.dart`、`storyboard/providers/script_document_controller.dart`、`providers/characters_controller.dart`、`widgets/character_edit_dialog.dart`、`widgets/character_library_panel.dart`、`providers/character_usage.dart`。
- `export/widgets/delivery_clips_tab.dart`、`export/util/delivery_clip_rows.dart`（W14 已定，不改）、`export/providers/delivery_controller.dart`、`export/widgets/delivery_result_bar.dart`、`core/interfaces/export_record_repository.dart`、`storage/repositories/postgres_export_record_repository.dart`、`export/models/export_record.dart`。
- `create_node_menu.dart`、`canvas_node.dart`、ARB / generated / docs/CLAUDE.md。

**同波（W15）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- text-inline-edit：`lib/features/canvas/providers/inline_edit_node.dart`、`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/node_card_slot.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`test/features/canvas/providers/inline_edit_node_test.dart`、`test/features/canvas/providers/inspector_submit_controller_test.dart`、`test/features/canvas/widgets/text_inline_edit_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`
- collapse-all-panels：`lib/features/canvas/providers/inspector_expanded.dart`、`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/widgets/canvas_inspector_panel.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`lib/features/canvas/widgets/shortcuts/collapse_panels_keys.dart`、`test/features/canvas/providers/inspector_expanded_test.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/widgets/canvas_collapse_panels_test.dart`
- script-characters-row：`lib/core/interfaces/script_repository.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_document_controller.dart`、`lib/features/storyboard/util/script_character_match.dart`、`lib/storage/repositories/postgres_script_repository.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_document_controller_test.dart`、`test/features/storyboard/util/script_character_match_test.dart`
- character-usage-links：`lib/features/canvas/providers/character_usage.dart`、`lib/features/canvas/widgets/character_edit_dialog.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`test/features/canvas/providers/character_usage_test.dart`、`test/features/canvas/widgets/character_edit_dialog_test.dart`、`test/features/canvas/widgets/character_library_panel_test.dart`
- image-zip-export：`lib/core/di/image_zip_export.dart`、`lib/core/interfaces/image_zip_export_service.dart`、`lib/features/export/providers/image_zip_export_controller.dart`、`lib/features/export/util/export_order.dart`、`lib/features/export/util/image_zip_manifest.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/image_zip_export_dialog.dart`、`lib/services/archive_image_zip_export_service.dart`、`test/features/export/providers/image_zip_export_controller_test.dart`、`test/features/export/util/export_order_test.dart`、`test/features/export/util/image_zip_manifest_test.dart`、`test/features/export/widgets/image_zip_export_dialog_test.dart`、`test/services/archive_image_zip_export_service_test.dart`

## 具体改动
已有 API（main 上已核对）：
- `final shellControllerProvider = NotifierProvider<ShellNavigator, ShellState>`（`shell/providers/shell_controller.dart` 约第 76 行）；`void goTab(ShellTab t)`（约第 54 行）；`enum ShellTab { studio, canvas, sequence, gallery, export }`（`shell/models/shell_state.dart` 第 32 行）。
- `final folderOpenerProvider = Provider<FolderOpener>`（`core/di/folder_opener.dart`）；`Future<void> open(String path)`（`core/interfaces/folder_opener.dart` 第 10 行）。现有 `_openFolder` 写法：`ref.read(folderOpenerProvider).open(path).ignore();`（`delivery_panel.dart` 约第 207 行）。
- `DeliveryTarget.fromWire(Object? wire)`（`delivery_settings.dart` 约第 39 行）、`DeliverySettings.toMap()` 的 `'target'` 键（约第 100 行）、`String deliveryTargetLabel(AppLocalizations l, DeliveryTarget t)`（`util/delivery_target_labels.dart` 第 10 行）。
- `deliveryControllerProvider` 的终态 `DeliverySucceeded` / `DeliveryFailed`（`delivery_controller.dart`）。
- `fileResolverServiceProvider.resolveInProject({required String projectId, required String relativePath})`（相对路径 → 绝对 File）。
前序 API（名字以合入后为准）：
- `ExportRecord`（export-records-table 新建，`features/export/models/export_record.dart`）：字段 id、projectId、canvasId?、kind（wire：`mp4` / `delivery` / `pdf` / `zip`）、filePath、shotCount、durationMs、sizeBytes、status、errorCode?、settings（Map 快照）、createdAt。
- export_history_provider（export-tab-history 新建，`features/export/providers/export_history_provider.dart`，签名以合入后为准）：按项目列出 export_records。
- 若 export-tab-history 已有公共的行时间格式函数（「今天 14:20 / 昨天」）与失败原因文案函数，直接复用；没有公共的再用本片下表的键在本文件里写私有函数。

新增：
```dart
// delivery_history_tab.dart
@immutable class DeliveryHistoryRow {
  final String recordId;
  final DateTime createdAt;
  final DeliveryTarget? target;  // 快照里没有 / 认不出 → null（不写软件名）
  final int shotCount;
  final bool failed;
  final String? errorCode;
  final String? folderPath;      // 交付目录绝对路径；解析不了 → null
}
/// export_records → 本画布的交付行，新→旧。纯函数，可单测。
List<DeliveryHistoryRow> deliveryHistoryRows(List<ExportRecord> records, {required String canvasId, required String? Function(ExportRecord) folderOf});
class DeliveryHistoryTab extends ConsumerWidget {
  const DeliveryHistoryTab({super.key, required this.canvasId, required this.projectId});
  static Key rowKey(String recordId);       // ValueKey('delivery.history.row.$id')
  static Key openFolderKey(String recordId);
  static const Key allHistoryLink;          // Key('delivery.history.all')
  static const Key emptyState;              // Key('delivery.history.empty')
}
```
`folderOf`：记录的 `filePath` 若是目录（交付记录指向交付目录）就用它，若是文件（如 EDL）取 `p.dirname`；相对路径先经 `resolveInProject` 转绝对，`PathSecurityError` → null。

## 行为规则与边界情况
- R1 只列 `kind == 'delivery'` 且 `canvasId == 当前画布` 的记录；其他 kind（mp4 / pdf / zip）、其他画布、`canvasId == null` 的都不列。
- R2 顺序：`createdAt` 新→旧；相同时按 id 稳定。
- R3 成功行左文案 = `deliveryHistoryRowLabel(time, target, count)`：时间是「今天 HH:mm / 昨天 HH:mm / M月d日 HH:mm」（本地时区，`clockProvider.nowUtc()` 取「现在」，测试可注入）；`target == null` 时用不带软件名的 `deliveryHistoryRowLabelNoTarget`。
- R4 `status` 为失败：左文案后接 ` · ` + `deliveryHistoryFailed(reason)`（danger 色，reason 走现有 InkError → 文案映射；只有 errorCode 时用 errorCode 对应文案，查不到写通用失败），右侧不给「打开文件夹」。
- R5 点「打开文件夹」= `folderOpenerProvider.open(folderPath).ignore()`（best-effort，与结果条同款）；`folderPath == null` 时不画按钮。
- R6 不做「文件夹是否还在」检查（与导出标签的划掉规则不同，见风险）；打开失败只是没反应，不弹错。
- R7 底部固定一行「全部导出历史 →」（不随列表滚动），点击 = `ref.read(shellControllerProvider.notifier).goTab(ShellTab.export)`；空态时也在。
- R8 空态（本画布没有交付记录）：居中 `deliveryHistoryEmpty`，Key `emptyState`。
- R9 结果条照旧只显示最近一次交付（`deliveryControllerProvider` 的终态），**不从**历史记录里推；历史页里结果条照常显示在页签条下。
- R10 新交付完成后列表自动出现新行：在 `DeliveryHistoryTab` 里 `ref.listen(deliveryControllerProvider, ...)`，进入 `DeliverySucceeded` / `DeliveryFailed` 时 `ref.invalidate(<export_history_provider>)`（若 W6 的 provider 已被 recorder 主动刷新，这一步保留也无害）。取消不产生记录，也不刷新。
- R11 provider 加载中：不画转圈占位，保留上一帧数据（`valueOrNull`）；错误（读库失败）：显示 `deliveryHistoryLoadFailed`，不抛。
- R12 无项目：沿用 W14 规则——页签全部不可点，不碰仓储。
- R13 无平台差异：打开文件夹走已有 FolderOpener（它内部处理 explorer / open 的差异），本片不碰进程。

## 新文案键
| key | en | zh |
|---|---|---|
| deliveryHistoryRowLabel | {time} · {target} · {count} shots | {time} · {target} · {count} 镜 |
| deliveryHistoryRowLabelNoTarget | {time} · {count} shots | {time} · {count} 镜 |
| deliveryHistoryOpenFolder | Open folder | 打开文件夹 |
| deliveryHistoryFailed | Failed · {reason} | 失败 · {reason} |
| deliveryHistoryAll | All export history → | 全部导出历史 → |
| deliveryHistoryEmpty | No deliveries from this canvas yet. | 这张画布还没有交付记录。 |
| deliveryHistoryLoadFailed | Couldn't load delivery history. | 读取交付记录失败。 |
| deliveryHistoryToday（仅 W6 无公共函数时） | Today {time} | 今天 {time} |
| deliveryHistoryYesterday（同上） | Yesterday {time} | 昨天 {time} |

占位符：time / target / reason 为 String，count 为 int（ICU `{count}` 直接数字，不做复数分支——中文无复数，英文 `1 shots` 可接受与现有 `deliveryIncludeSummary` 同口径；若主 Agent 要复数则改 `{count, plural, =1{1 shot} other{{count} shots}}`）。

## 测试
先写、先红。`test/features/export/widgets/delivery_history_tab_test.dart`（项目上下文用 `shellControllerProvider.overrideWith(() => ShellNavigator(initial: ShellState(...)))` 播种，**不 override activeProjectProvider**；export_history_provider 覆写成固定记录列表；`folderOpenerProvider` 覆写成记录调用的 fake；`clockProvider` 用 `test/_harness/fake_clock.dart`）
- `rows keep only delivery records of this canvas`（纯函数）：混入 mp4 / zip / 另一画布 / canvasId null → 只剩本画布 delivery。
- `rows are newest first`（纯函数）。
- `unknown target in snapshot yields null target`（纯函数）：settings 无 `target` 或 wire 不认识 → target null。
- `history tab is clickable and shows rows`：点 `DeliveryPanel.tabKey(history)` → 见 2 行，文案含 `Resolve` 与 `8 shots`。
- `open folder calls folder opener with record folder`：点 `openFolderKey(id)` → fake 收到目录路径（文件路径时为其父目录）。
- `failed row shows reason and no open-folder button`。
- `all history link goes to export tab`：点 `allHistoryLink` → `container.read(shellControllerProvider).tab == ShellTab.export`。
- `empty state when no delivery for this canvas`。
- `finishing a delivery refreshes the list`：把 deliveryControllerProvider 推到 DeliverySucceeded，同时记录源多一行 → pump 后出现新行。
- `result bar still shows only the latest delivery`：结果条与历史第一行同时在，结果条内容来自 controller 而不是记录。

## 变异点
- M1 `deliveryHistoryRows` 去掉 `kind == 'delivery'` 判据 → `rows keep only delivery records of this canvas` 变红。
- M2 去掉 canvasId 判据 → `rows keep only delivery records of this canvas` 变红（另一画布与 canvasId null 的 delivery 行混进来）。
- M3 排序改成旧→新 → `rows are newest first` 变红。
- M4 `folderOf` 不取 dirname 直接传文件路径 → `open folder calls folder opener with record folder` 变红。
- M5 失败行也画「打开文件夹」→ `failed row shows reason and no open-folder button` 变红。
- M6 「全部导出历史」改成 `goTab(ShellTab.sequence)` 或空实现 → `all history link goes to export tab` 变红。
- M7 删掉 R10 的 `ref.listen` + invalidate → `finishing a delivery refreshes the list` 变红（若 W6 provider 是 recorder 主动推送的 stream，此变异不红——执行时先确认 provider 形态，不红就在回报里说明并删掉这条用例）。
- M8 可点集合去掉 history → `history tab is clickable and shows rows` 变红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/export test/features/shell test/quality`（排除 golden）。
- 逐条做 M1–M8。
- 截图：`DeliveryPanel(canvasId: 'c1')`，shellController 播种项目 Alpha，历史记录 3 条（今天 Resolve 8 镜成功、昨天 Premiere 7 镜成功、昨天失败 1 条）；截①历史页 ②历史页空态 ③历史页 + 顶部成功结果条。

## 风险与不确定
- `export_history_provider` 的名字 / 参数（按项目还是按「全部 / 本画布」筛选）、`ExportRecord` 的字段名与 status 字面量（`succeeded` / `failed`？）都以 W4 / W6 合入后为准；本片的筛选写在自己的纯函数里，换 provider 形态只改一处。
- 交付记录的 `file_path` 存的是交付目录还是 EDL 文件、是相对还是绝对，取决于 export-records-recording 的实现；`folderOf` 两种都兼容，执行时核对 recorder 写法并在回报里写明。
- 导出标签历史对「文件已不在」划掉并只给「重新导出」，交付页签本片不检查存在性（R6）——两处表现不一致，画板没要求交付页签检查；若主 Agent 要统一，可复用 W6 的存在性判据（若它是公共函数）。
- 「全部导出历史 →」只切标签，不把导出标签的筛选切到「本画布」；如需要，得改 W6 的 export_tab（不在本片范围）。
