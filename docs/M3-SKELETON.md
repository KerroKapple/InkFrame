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
- **首切片已落地（纯服务层，无 UI）**：接口
  `lib/core/interfaces/video_export_service.dart` +
  实现 `lib/services/ffmpeg_video_export_service.dart`（concat demuxer 流拷贝
  `-c copy`，不转码，要求输入同编码参数）+ 探测
  `lib/services/ffmpeg_locator.dart`（INKFRAME_FFMPEG env → PATH `-version` 探测，
  命中缓存）+ 最小进程抽象 `lib/core/interfaces/process_runner.dart`。
- 签名：`concat({projectId, inputRelativePaths, outputBaseName?})`——输入为
  **项目根相对路径**（`canvases/<c>/videos/<f>.mp4`），经
  `FileResolverService.resolveInProject`（新增，项目根边界安全校验）解析；
  输出落 `projects/<id>/exports/`，返回项目相对路径。导出目录未走 `AppPaths`
  （其方法均为 app 级无 projectId），归口 FileResolverService。
- **不打包 ffmpeg 二进制**（体积/许可评估延后）：系统无 ffmpeg →
  `LocalIOError(reason=ffmpeg_not_found)`；错误全复用现有 InkErrorCode，零 l10n 变更。
- 后续：UI 入口（`lib/features/export/`）、转码/分辨率归一、打包二进制评估。

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
> **2026-07-02 拍板**：配置存 **`custom_providers.json` 文件**（可手编/分享，需校验+损坏
> 兜底）；capabilities 由**协议白名单模板**派生（用户选模板 + 填 base_url/key/model，
> 不自由填能力位）——即 PROVIDER-API §13 现稿方向。开工时重写 §13 为单一方案。

- 原详细设计 `docs/superpowers/plans/2026-05-21-custom-providers.md` 已漂移（写于 5 月），
  开工时按 2026-07-02 就绪度审计校正，要点：
  - 适配器 **extends `SyncProviderBase`**（非手写 Submittable——JobQueue 对非 Pollable
    防御性失败；结果走 inlineBytes poll 通道，请求体 `response_format:'b64_json'`）。
  - 本方案存 json，**无需 schema_v8**；若未来改表，走 `schema_vN.dart` +
    `kAppMigrations` 追加一行（不是 .sql 镜像 + version bump）。
  - key 命名空间复用 `SecureStorageKeys.providerApiKey('custom:<uuid>')`——生成链路
    key 校验/inspector 门控/Studio banner 零改动生效。
  - `providerRegistryProvider` **只能变异、不能 invalidate**（否则 JobQueue 连锁重建、
    运行中任务被打成 cancelled）；配置变更时须驱逐 registry 的旧实例缓存。
  - `providerCapabilitiesListProvider` 改为同步可读的 Notifier（merge 内置 const +
    模板派生），必须保持同步读（image inspector initState 里 `ref.read`）。
  - ADR-0009（const-only capabilities）需小修：协议模板本身仍是代码内 const，
    仅实例化参数（base_url/model_id）来自用户配置，修订幅度小。
- 首个切片：单个硬编码 OpenAI 兼容 provider（base_url/model 从 SecureStorage/config 读），
  跑通「文生图」，再抽象为 json 配置列表。

## 落地顺序建议（价值/风险）
1. **模型聚合器**（差异化最强，已设计，风险中）——先做单端点跑通。
2. **素材库**（复用现有落盘，风险低，纯读）。
3. **分镜流水线**（复用 shot 节点，渐进）。
4. **视频导出**（重原生依赖——服务层骨架已落地，UI 入口/转码/打包评估后续）。
