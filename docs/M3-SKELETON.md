# M3 骨架与落地设计

> 状态：M3「差异化」尚未开工。本文是**可落地的骨架设计**——每项给出模块位置、
> 接口、依赖与首个可编译切片，供后续按 characters/presets 同样的「存储切片 + 控制器 +
> UI」节奏推进。已落地部分见 `docs/BOARD.md`。

## 已落地的 M3 起点
- **shot 分镜节点编辑**（本轮）：`shot` 本就是真实节点类型（`CanvasNodeType.shot`），
  此前无编辑面板。已加 `ShotConfigInspector`（分镜备注 `type_config.shot_notes`）并接入
  `NodeInspectorRouter`。这是 storyboard→shot→序列 流水线的编辑起点。

## 1. 分镜 / Storyboard 流水线
**目标**：脚本 → 分镜（多个 shot 节点）→ 逐镜生成 → 序列。
- 模块：`lib/features/storyboard/`（新）。
- 数据：复用 `nodes(type='shot')` + `type_config.shot_notes`（已在）；镜头顺序用现有
  `edges`（narrative 类型）或 `lane`（泳道=场景）。**无需新表即可起步**。
- 首个切片：`ShotConfigInspector` 增「用本镜备注生成图像」——把 shot_notes 作为 prompt
  预填一个 image config 节点（复用现有生成链路）。
- 后续：脚本解析器（文本→多 shot）、镜头级参数（时长/机位）、序列预览。

## 2. 视频导出 / 拼接
**目标**：把画布上多个 video 结果按序列拼接导出。
- 模块：`lib/features/export/` + 服务 `lib/services/video_export_service.dart`
  （接口 `lib/core/interfaces/video_export_service.dart`）。
- 依赖：ffmpeg（`ffmpeg_kit_flutter` 或打包二进制 + `Process.run`）。**新增原生依赖，
  需评估桌面体积/许可**——与 media_kit 同属重依赖，先做接口 + 假实现骨架，再接真编码。
- 首个切片：`VideoExportService.concat({inputs: List<String>, output})` 接口 +
  一个基于已下载视频文件的顺序拼接假实现（或直接调 ffmpeg），导出到项目目录。
- 复用：`FileResolverService`（解析输入相对路径）、`AppPaths`（导出目录）。

## 3. 素材库 / Asset Gallery
**目标**：跨画布浏览项目已生成的图片/视频 + 复用（拖入画布 / 存为角色）。
- 模块：`lib/features/gallery/`（新）。
- 数据：扫描项目目录产物（`projects/{id}/canvases/*/images|videos/`）或聚合
  `nodes`（result 角色）+ `batch_results` + `characters` 的 `reference_image_paths`。
  优先**读现有落盘 + DB 行**，无需新表。
- 首个切片：`GalleryController`（project 维度，列出 result 节点的 image_url/video_url）
  + 网格 UI（复用 `BatchResultsGrid` 的 slot 渲染思路）。
- 复用点：`characterAssetServiceProvider`（存为角色）、`fileResolverServiceProvider`。

## 4. 模型聚合器 / 自定义 Provider（BYO-key 多模型）
**目标**：用户填 base_url + key + model_id 接任意 OpenAI 兼容端点（fal.ai / OpenRouter /
本地）。**最高杠杆差异化**——一次接入解锁 N 个模型。
- 已有**详细设计**：`docs/superpowers/plans/2026-05-21-custom-providers.md`（OpenAI 兼容
  base_url+key+model_id）。本项按该计划落地即可。
- 模块/文件（按计划）：
  - `lib/core/models/custom_provider_config.dart`（config 模型）
  - `lib/storage/schema/schema_v8.dart` `custom_providers` 表（或 `custom_providers.json`）
  - `lib/features/settings/providers/custom_providers_controller.dart`
  - `lib/features/settings/widgets/custom_providers_section.dart`
  - 适配器 `lib/providers/openai_compatible_provider.dart`，在
    `lib/providers/provider_registry.dart` 动态注册。
- 关键约束：适配器须实现 `Submittable`（+ 可选 `Pollable`），声明 `ProviderCapabilities`
  （`maxRefImages`/`modes` 决定角色一致性等能否生效——见 generation 注入门控）。
- 首个切片：单个硬编码 OpenAI 兼容 provider（base_url/model 从 SecureStorage/config 读），
  跑通「文生图」，再抽象为用户可配置列表。

## 落地顺序建议（价值/风险）
1. **模型聚合器**（差异化最强，已设计，风险中）——先做单端点跑通。
2. **素材库**（复用现有落盘，风险低，纯读）。
3. **分镜流水线**（复用 shot 节点，渐进）。
4. **视频导出**（重原生依赖，最后做，先接口骨架）。
