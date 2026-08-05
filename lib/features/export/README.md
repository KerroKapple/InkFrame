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

## widgets
- `export_video_dialog.dart` — 导出对话框：video result 节点列表
  （默认按 `position.x` 升序=分镜从左到右，默认全选）+ 复选/上移下移手动排序 +
  输出文件名（留空=服务端时间戳默认名；同名已存在给覆盖警示行，不阻断）+
  busy 态（EX-3：分母=Σ所选 `duration_ms` 时 determinate 进度条，任一缺失
  → indeterminate；「取消导出」按钮 → `cancelExport()`，取消收敛回可编辑态，
  不视为错误；kill 迟到、ffmpeg 已 exit 0 时按成功收尾——已成功不误删；
  覆盖警示在 busy 期屏蔽）。成功：关对话框 + snackbar 相对路径 + 「复制路径」
  （复制绝对路径）；失败：**内嵌 `InkErrorBanner`**（不再用 barrier 之下的
  SnackBar），`InkError.messageKey` 走 l10n，**特例** ffmpeg_not_found 用
  专门文案（含 INKFRAME_FFMPEG 提示）。服务侧产物走 `.partial`→rename，
  失败/取消不触碰既有同名旧导出。

## 入口
画布顶栏（`canvas_top_chrome.dart` 的 `_ExportVideoButton`）：当前画布存在
video result 节点（`videoUrl` 非空）时可用，否则禁用 + 说明 tooltip。

## 本切片不做（后续切片）
narrative 链自动排序（EX-1′，依赖 SB-5）/ 转码与分辨率归一（EX-2，依赖
D-M4-6 拍板）/ 导出历史列表 / 打包 ffmpeg 二进制评估。

## 约束
- 文案走 `context.l10n.*`，样式走 token（ADR-0010）
- 路径解析只经 `FileResolverService`；绝对路径不落 DB/状态，仅剪贴板一次性使用
