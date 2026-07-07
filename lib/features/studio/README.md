# features/studio

项目/画布的工作台外壳：首页（项目库）+ 打开/新建画布的入口。是没有打开画布时的落地界面。

> 相关 ADR：[0002 Riverpod 状态/DI](../../../docs/adr/0002-riverpod-for-state-and-di.md) · [0003 Repository 层 Map](../../../docs/adr/0003-freezed-models-map-at-repo-edge.md) · [0010 i18n/token 零硬编码](../../../docs/adr/0010-zero-hardcoding-i18n-and-design-tokens.md)

## 组成

```
studio_home_screen.dart              首页整屏（顶栏 + 侧栏 + 主区项目网格；含画布管理对话框 _ManageCanvasesDialog）
open_canvas.dart                     从 studio 打开/创建画布（同时写偏好 lastCanvasId/lastProjectId 供重启恢复）
controllers/studio_projects_controller  项目列表加载/新建/重命名/删除/归档
controllers/studio_state             studio 视图状态
models/project_with_canvases         项目 + 其画布聚合视图
providers/workspace_projects_provider 工作区项目数据源
providers/restore_last_session       启动恢复上次画布（app.dart 接线；画布/项目任一软删则不恢复）
widgets/library_sidebar              左侧库（Projects / Archive）
widgets/project_card                 项目卡片（名 + 元信息行 + 右上菜单四动作：Gallery / 重命名 / 管理画布 / 删除）
widgets/studio_top_chrome            顶栏（trailing：⌘K + Settings + Avatar）
widgets/studio_provider_banner       "未配置 API Key" 提示条
```

## 数据流
- `workspace_projects_provider` / `studio_projects_controller` 从仓库(Map，ADR-0003)拉项目 → `project_with_canvases` 聚合 → `studio_home_screen` 渲染网格
- 打开画布 → `open_canvas` 设置 `currentCanvasIdProvider`（见 [features/canvas](../canvas/README.md)），app 切到画布屏
- 项目卡菜单「Gallery」→ 写 `currentGalleryProjectProvider`，`app.dart` 切到 `GalleryScreen`（见 [features/gallery](../gallery/README.md)）
- 项目卡菜单「管理画布」→ `_ManageCanvasesDialog`（画布级重命名/软删，controller 走 canvasRepo update/softDelete）
- 空态 / 错误态 / "无 Key" 提示条均走 l10n（`studioEmpty*` / `studioError*` / `studioNoKeyBanner*`）

## 约束
- 顶栏/卡片/侧栏一律 token 化（`context.inkColors` / `InkSpacing`）；所有文案走 `context.l10n.studio*`（ADR-0010）
