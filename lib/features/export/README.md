# features/export

导出 UI 首切片（features/export 模块首件）——把当前画布的 video result 节点
按序拼接为单个 mp4。服务层为 `VideoExportService.concat`（concat demuxer
流拷贝，见 `docs/M3-SKELETON.md` §2），本模块只做编排与交互，**无新表**。

> 相关 ADR：[0007 节点 type×role + JSONB](../../../docs/adr/0007-node-type-role-jsonb-config.md) · [0010 i18n/token 零硬编码](../../../docs/adr/0010-zero-hardcoding-i18n-and-design-tokens.md)

## 分层

```
providers/  Riverpod 控制器（autoDispose）
util/       纯函数（文件名预校验）
widgets/    纯 UI（读 provider、走 token/l10n）
```

## providers
- `export_controller.dart` — `ExportController`：状态机
  idle/busy(progress?)/success/failure；**路径根换算**在此层——节点
  `type_config.video_url` 是画布根相对路径，concat 收项目根相对路径，统一补
  `canvases/<canvasId>/` 前缀（`projectRelativeVideoPath`）。进度分母 =
  Σ所选节点 `duration_ms`（任一缺失 → null=indeterminate）；`cancelExport()`
  经 `ExportCancelToken` 传导，`CancelledError` 收敛为 idle（非 failure）。
  只捕 `InkError` 子类 + 防御性 `PathSecurityError`（翻译为 invalidParameter）。

## util
- `export_file_name.dart` — `isValidExportBaseName`：与服务端
  `_assertPlainFileName` 同规则的本地预校验（分隔符/盘符冒号/`..`/控制字符/
  Windows 非法字符 `* ? " < > |`/Windows 保留名，含 `con.backup` 带扩展名
  形态），非法即禁用导出按钮，避免提交后才收 PathSecurityError。
  两侧规则逐字等价是契约，改一侧必改另一侧。
- `export_take_selection.dart` — `currentTakeNodeIds`：**默认勾选**集（BOARD 194）
  = 每个 source 节点名下当前那一个 take（固定的 `pinned_result_id` ?? 最新的，
  最新的判据 `created_at`；复用 `canvas/util/node_artifacts.dart` 的
  `currentResultFor`，固定表由 `pinnedBySource` 传入）。`sourceNodeId` 为空的孤儿产物各自成镜、
  全部入选。**只改默认勾选，不改候选集**——旧 take 照样列出、可手动勾回。
  为什么不用 promoted 选 take：那是 slot 级标记（只在一个容器内单选、只写
  `image_url`），而批量被收口成「仅图片」，video take 在数据上不可能有 slot。
  完整论证在文件头。

## widgets
- `export_video_dialog.dart` — 导出对话框：video result 节点列表
  （默认序=narrative 链序，无链退回 `position.x` 升序=分镜从左到右；
  默认勾选=每镜当前一个 take，其余 take 列出但不勾并带「旧 take」标记）
  + 复选/上移下移手动排序 +
  输出文件名（留空=服务端时间戳默认名；同名已存在给覆盖警示行，不阻断）+
  busy 态（EX-3：分母=Σ所选 `duration_ms` 时 determinate 进度条，任一缺失
  → indeterminate；「取消导出」按钮 → `cancelExport()`，取消收敛回可编辑态，
  不视为错误；kill 迟到、ffmpeg 已 exit 0 时按成功收尾——已成功不误删；
  覆盖警示在 busy 期屏蔽）。成功：关对话框 + snackbar 相对路径 + 「复制路径」
  （复制绝对路径）；失败：**内嵌 `InkErrorBanner`**（不再用 barrier 之下的
  SnackBar），`InkError.messageKey` 走 l10n，**特例** ffmpeg_not_found 用
  专门文案（含 INKFRAME_FFMPEG 提示）。服务侧产物走 `.partial`→rename，
  失败/取消不触碰既有同名旧导出。

「导出」标签（`features/shell/widgets/tabs/export_tab.dart`）：当前画布存在
video result 节点（`videoUrl` 非空）时可用，否则禁用 + 说明 tooltip。判据是
`features/shell/util/tab_availability.dart` 的 `canExportVideo`（T7 从已删除的
`canvas_top_chrome.dart` 原样搬运，未重写）。

## 排序（EX-1′）
默认序 = narrative 链序，算在 `util/export_order.dart`（`orderVideoNodesForExport`），
**不在对话框内**——链序需要全量节点与边，对话框只拿得到 video result 子集。
两个入口（导出标签 + ⌘K 命令面板）走同一条路径，对话框照单全收传入顺序。
**两处的 `projectId` 都取自 `ShellState.project`**，不从 `videoNodes.first.projectId`
摸：启用判据看的是**原序**首个（`exportableVideoNodes(...).first`），排序看的是
**链序**首个，两者不同源时就会出现「看着能点、点了没反应」（R86）。

video result 节点挂在 config 节点下（`sourceNodeId`），自己不在 narrative 链上，
所以不能把 result 集合直接喂给 `orderByNarrativeChain`——那会一条边都找不到、
静默退化成 position.x。正解是先按链排 config/shot 节点，再经
`canvas/util/node_artifacts.dart` 映射到各自产物。画布没有 narrative 边时，
结果等价于旧的 position.x 升序。

**候选集不收窄**：同一镜重跑的多个 take 仍全部列出（成组跟在该镜位置、新→旧）。

## 默认勾选（BOARD 194）
EX-1′ 只定了序，默认全选于是会把同一镜的多个 take 一起导出，用户必须手动取消
勾选旧 take。现在默认勾选 = **每镜当前一个 take**（`util/export_take_selection.dart`
的 `currentTakeNodeIds`：配置节点固定了 `pinned_result_id` 且那条还在候选里就是它，
否则最新的，判据 `created_at`）；其余 take 仍在列表里、带「旧 take」标记、
一键就能勾回来——**改的是默认勾选，不是候选集**，所以「我就是想导出上一版」不是死路。

默认勾选算在**对话框内**（而不是像排序那样算在调用方）：它只需要 video result
子集，而对话框是两个入口（导出标签走 `open_export_dialog.dart`、⌘K 走
`command_actions._openExport`）唯一的汇合点，放这里两条入口自动一致。
例外是固定表：video result 子集里没有配置节点，`pinnedBySource` 得由调用方从全量
节点算（`open_export_dialog.dart` 用 `pinnedResultIdsBySource`）；不传 = 没有固定、
默认勾最新。

**为什么是「最新」而不是「promoted」**：promoted 住在 `batch_results` 行上、键是
容器 result 节点，`promote()` 只清同一容器内的旧标记、只写 `image_url`；而批量在
`generation_controller` 被收口成「仅图片节点」。⇒ video take 在数据上不可能有 slot，
promoted 在导出路径上无定义。全仓「一镜取哪个产物」的既有判官是
`canvas/util/node_artifacts.dart`（序列播放 / P6 交付计划 / 画廊选定产物 / ⌘K 产物组
都走它），导出默认勾选是唯一漏网的一处，这里是补齐口径而非新规则。

## 本切片不做（后续切片）
转码与分辨率归一（EX-2，依赖 D-M4-6 拍板）/ 导出历史列表 /
打包 ffmpeg 二进制评估。

## 约束
- 文案走 `context.l10n.*`，样式走 token（ADR-0010）
- 路径解析只经 `FileResolverService`；绝对路径不落 DB/状态，仅剪贴板一次性使用
