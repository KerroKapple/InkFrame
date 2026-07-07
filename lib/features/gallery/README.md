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
  （canvasId/canvasName/nodeId/slotIndex?）+ createdAt/durationMs

## providers
- `gallery_controller.dart` — project 维度聚合（autoDispose family）：
  各画布 result 节点的 `image_url`/`video_url` + `batch_results` 成功 slot 的
  `output_url`（`listSuccessByProject`，一次跨画布查询）；slot 与节点主图同
  (canvasId, path) 去重只留节点一条；createdAt 倒序
- `current_gallery_project.dart` — 画廊浏览目标 (id+name)；null=关闭。
  路由语义同 `currentCanvasIdProvider`（`app.dart` 顶层切换）

## widgets
- `gallery_screen.dart` — 整屏骨架：InkWindowChrome（返回+面包屑）+ 网格，
  loading / error / empty / data 四态
- `gallery_tile.dart` — 网格单元：图片经 `fileResolverServiceProvider` 解析渲染
  （同 `BatchResultsGrid`）；视频为图标+时长占位；caption 带类型/画布名
- `gallery_image_lightbox.dart` — 图片放大预览 Dialog（视频版见 canvas 的 `video_lightbox`）

## 入口
Studio 项目卡右上菜单「Gallery」→ 写 `currentGalleryProjectProvider` →
`app.dart` `_UnlockedShell` 切到 `GalleryScreen`；返回按钮清空该状态回 Studio。
路由优先级：`currentCanvasId` 优先于 gallery——画布打开时画廊被遮蔽（`app.dart`
先判画布再判画廊）。

## 首切片不做（后续切片）
拖入画布 / 存为角色（`characterAssetServiceProvider` 复用点）/ 筛选与搜索 /
视频缩略图与播放（media_kit 接入）/ 删除产物。

## 约束
- 文案走 `context.l10n.*`，样式走 token（ADR-0010）
- 路径解析只经 `FileResolverService`，只捕 `PathSecurityError`（不裸 catch）
