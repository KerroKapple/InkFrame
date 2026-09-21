# features/gallery

项目维度的产物画廊（M3 素材库首切片）——跨画布只读浏览本项目已生成的图片/视频。
数据只读现有 DB 行 + 落盘产物，**无新表**（设计见 `docs/M3-SKELETON.md` §3）。

> 相关 ADR：[0007 节点 type×role + JSONB](../../../docs/adr/0007-node-type-role-jsonb-config.md) · [0010 i18n/token 零硬编码](../../../docs/adr/0010-zero-hardcoding-i18n-and-design-tokens.md)

## 分层

```
models/     不可变领域模型（freezed）
providers/  Riverpod 控制器 + 路由状态（screen-scoped）
widgets/    纯 UI（读 provider、走 token/l10n）
```

## models
- `gallery_item.dart` — `GalleryItem`：kind(image/video) + canvas 相对路径 + 来源
  （canvasId/canvasName/nodeId/slotIndex?）+ createdAt/durationMs +
  thumbnailRelativePath?（GA-1：节点已落库的 thumbnail_url，batch slot 无）

## providers
- `gallery_controller.dart` — project 维度聚合（autoDispose family）：
  各画布 result 节点的 `image_url`/`video_url` + `batch_results` 成功 slot 的
  `output_url`（`listSuccessByProject`，一次跨画布查询）；slot 与节点主图同
  (canvasId, path) 去重只留节点一条；createdAt 倒序
- `gallery_filter.dart` — GA-3：`GalleryFilter{kind?, canvasId?, query}` 手写
  不可变模型 + `filterGalleryItems` 纯函数（三轴 AND；query 只匹配 canvasName，
  prompt 搜索 non-goal）+ `StateProvider.autoDispose.family`（key = projectId）。
  **按项目分键是保活模型下的必需**：全局形态在标签保活后会让项目 A 的筛选条件
  套到项目 B 的产物上（零命中，而三个筛选控件都显示"未筛选"）

> 画廊浏览目标（项目 id + name）不再是本模块的 provider：它是外壳状态的一部分
> （`ShellState.project`），只读投影在 `features/shell/providers/active_project.dart`。
> 原 `current_gallery_project.dart` 已随外壳落地删除。

## widgets
- `gallery_screen.dart` — 整屏骨架：`InkToolBar`（项目名 + 筛选 chip + 去 Studio）+ 筛选条
  （GA-3：类型分段/画布下拉/搜索框）+ 网格，loading / error / empty /
  no-match（含清除筛选）/ data 五态；根为 Material（筛选控件需要）
- `gallery_tile.dart` — 网格单元：图片经 `fileResolverServiceProvider` 解析渲染
  （同 `BatchResultsGrid`）；视频（GA-1/2）有缩略图 → 缩略图+播放/时长角标、
  缩略图缺失回退图标占位；点击经 existsSync 守卫开 `video_lightbox`（canvas
  共用件），视频文件缺失 → broken 态；caption 带类型/画布名 + image 项
  「存为角色」菜单（GA-4：命名对话框 → canvas 的 charactersController
  .createFromImage，补偿在控制器内；操作期 listenManual 保活）
- `gallery_image_lightbox.dart` — 图片放大预览 Dialog（视频版见 canvas 的 `video_lightbox`）

## 入口
Studio 项目卡右上菜单「Gallery」→ 调 `nav.openGallery(ProjectRef(...))`
（`shellControllerProvider`）→ 外壳切到**画廊标签**，`GalleryTab` 把 `project`
透传给 `GalleryScreen`（见 [features/shell](../shell/README.md)）。

**没有"路由优先级"这回事了。** 画廊和画布是持久标签外壳里的两个**并存**标签，
`lib/app.dart` 零判据；哪个在台上只由 `ShellContentStack` 的两级 `IndexedStack`
依 `ShellState.tab` 决定。「`canvasId` 优先于 gallery、画布打开时画廊被遮蔽」是
互斥路由时代的写法，正是本次外壳改造要消灭的那条断点——别照着它重新发明一遍。

## 后续切片
拖入画布（GA-5,D-M4-2 待拍板）/ 删除产物（GA-6,D-M4-3 待拍板）。
已落地：视频缩略图与播放（GA-1/2,读已落库 thumbnail_url）、
筛选与搜索（GA-3）、存为角色（GA-4）。

## 约束
- 文案走 `context.l10n.*`，样式走 token（ADR-0010）
- 路径解析只经 `FileResolverService`，只捕 `PathSecurityError`（不裸 catch）
