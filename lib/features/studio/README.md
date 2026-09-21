# features/studio

项目/画布的工作台：首页（项目库）+ 打开/新建画布的入口。是持久标签外壳里的
**Studio 标签**（`ShellTab.studio`，默认落地标签）——不再是"没有打开画布时"的
那个屏：画布开着的时候 Studio 标签照样在，切过去即可，画布在另一槽里保活。

> 相关 ADR：[0002 Riverpod 状态/DI](../../../docs/adr/0002-riverpod-for-state-and-di.md) · [0003 Repository 层 Map](../../../docs/adr/0003-freezed-models-map-at-repo-edge.md) · [0010 i18n/token 零硬编码](../../../docs/adr/0010-zero-hardcoding-i18n-and-design-tokens.md)

## 组成

```
studio_home_screen.dart              首页整屏（侧栏 + 主区项目网格；含画布管理对话框 _ManageCanvasesDialog）。窗口 chrome 与面包屑在外壳 ShellChrome，StudioTopChrome 已随外壳收敛删除
open_canvas.dart                     从 studio 打开/创建画布（同时写偏好 lastCanvasId/lastProjectId 供重启恢复）
project_import_flow.dart             项目包导入流程 runProjectImportFlow（picker → barrier 模态 → service → 选中新项目;FAB / 零项目空态 CTA / ⌘K 三入口共用一条路径;与还原/导出互斥）
controllers/studio_projects_controller  项目列表加载/新建/重命名/删除/归档
controllers/studio_state             studio 视图状态
models/project_with_canvases         项目 + 其画布聚合视图
providers/workspace_projects_provider 工作区项目数据源
providers/restore_last_session       启动恢复上次画布（app.dart 接线；画布/项目任一软删则不恢复）
widgets/library_sidebar              左侧库（Projects / Archive）
widgets/project_card                 项目卡片（名 + 元信息行 + 右上菜单四动作：Gallery / 重命名 / 管理画布 / 删除）
widgets/studio_provider_banner       "未配置 API Key" 提示条
```

## 数据流
- `workspace_projects_provider` / `studio_projects_controller` 从仓库(Map，ADR-0003)拉项目 → `project_with_canvases` 聚合 → `studio_home_screen` 渲染网格
- 打开画布 → `open_canvas` 调 `nav.openCanvas(...)`（`shellControllerProvider`，见 [features/canvas](../canvas/README.md)），外壳切到**画布标签**
- 导入项目 → `project_import_flow.runProjectImportFlow`（FAB、零项目空态 CTA、命令面板三处同一条路径;2026-08-31 审计 P0-3 之前只有 FAB 一处,零项目用户根本够不到）
- 项目卡菜单「Gallery」→ 调 `nav.openGallery(...)`，外壳切到**画廊标签**（见 [features/gallery](../gallery/README.md)）。Studio 与画廊是并存标签，不是互斥路由
- 项目卡菜单「管理画布」→ `_ManageCanvasesDialog`（画布级重命名/软删，controller 走 canvasRepo update/softDelete）
- 空态 / 错误态 / "无 Key" 提示条均走 l10n（`studioEmpty*` / `studioError*` / `studioNoKeyBanner*`）

## 约束
- 卡片/侧栏一律 token 化（`context.inkColors` / `InkSpacing`）；所有文案走 `context.l10n.studio*`（ADR-0010）
