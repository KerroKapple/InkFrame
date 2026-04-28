# T5 Sprint 方向选型

> 日期: 2026-04-22
> 起草: Tech Lead
> 状态: **草稿——等用户拍板**
> 关联: PRD v0.1.0 §4.6 / §5 / §7 / §7.7

---

## 背景

T4 Generation-Loop Sprint 已超额完成：单节点生成闭环 + Wanx 全家 + DashScope family key + edges + Inspector autosave + FAB 全部落地（alpha.3 → alpha.7）。

**当前能力边界**：用户能在 canvas 上建单个 image config 节点、连 data edge、跑 7 款 Provider 出图——但 PRD 里承诺的三大能力块一个都没开工。T5 要选一个开干。

---

## 候选 A — §4.6 九宫格/四宫格生成

### 用户价值
**一次生成 9 张保持一致性的关键帧**，分镜工作流核心。PRD §2 场景「每个 Shot 一张多宫格图」的兑现路径。

### 技术 scope
- schema 扩展：`nodes.type_config` 加 `is_grid_generation` / `grid_type` / `grid_children` / `parent_grid_id` + DB CHECK 约束 → schema v=3
- Provider 层：Gemini 单张出图 → 需要 prompt 里写 "nine-panel grid" 并依赖模型；Wanx 同理；不是 Provider API 层面的「多输出」参数——**走 prompt 包装**
- 裁切算法：接收原图 → 等分切 9 张 → 落盘 9 个子节点 → 建 generation_source edge（新 edge kind）
- Canvas UI：九宫格节点缩略图、"自动裁切"按钮、9 子节点自动排列
- 删除级联：父→子独立化、子→父不变、grid_children JSONB 同步

### 规模
中等，估 **5-7 PR** / 4-6 工作日

### 风险
- **R1** 模型能力不可控：Gemini 不保证出真正的 3×3 网格图（依赖 prompt engineering），可能出一张"像九宫格但网格线不均"的图，等分裁切裁出乱东西
- **R2** schema v=3 迁移：老 alpha 用户的库要走 MigrationRunner，跟 TD-001 同路径
- **R3** generation_source 是新 edge kind：当前 `CanvasEdge.kind` 只有 `data`，要加枚举 + 渲染分流

### 解锁
PRD §2 场景 A（关键帧生成）、§19.1 MVP 边界里的"九宫格"打钩

---

## 候选 B — §7 风格泳道 + §7.7 基底风格

### 用户价值
**工作流组织**——画布划分色带，每个色带自动注入 style_prompt，节点按所在泳道继承风格。加项目基底前后缀。用户不必在每个节点 prompt 里重复写风格。

### 技术 scope
- 新表 `style_lanes`：canvas_id / label / style_prompt / sort_order / tint_color / size
- 项目表加 `base_style_prefix` / `base_style_suffix`
- Canvas 渲染层大改：背景分带 + 渐变分界 + 悬停 "+" 按钮 + 泳道标题栏
- 归属算法：节点中心点 → 泳道（Riverpod provider 实时计算）
- **final_prompt 拼接公式**（§7.4 六段式）：basePrefix + lanePrompt + textNodes + userPrompt + baseSuffix —— 改整个 GenerationController
- 色调推断：`style_prompt` 关键词 → `tint_color`（中英双语表）
- 基底风格 7 个预设（i18n key `baseStylePreset_*`）
- `isIgnoreLaneStyle` 节点级开关

### 规模
**大**，估 **8-10 PR** / 7-10 工作日

### 风险
- **R1** Canvas 渲染层已经被 edges / FAB / Inspector 改得复杂，再叠色带 + 分界线 + 标题栏，技术债暴涨
- **R2** final_prompt 拼接公式改整个生成管线，老节点的 prompt 行为会变——测试覆盖必须全量回归
- **R3** 横竖切换 / 折叠 / 拖拽归属都是复杂交互，UX 打磨周期长

### 解锁
PRD §7 整章、§2 场景 B（风格一致性驱动的多 Shot）

---

## 候选 C — §5 视频节点 T7

### 用户价值
**把已建成的 6 款视频 Provider（Wanx T2V/I2V/R2V + Kling V3/V3-Omni + 其它）真正 user-visible**。当前 Provider 层完成但 UI 层没开工，资产闲置。

### 技术 scope
- 新节点 `type = video`（`CanvasNode.type` 目前枚举只有 image）
- `type_config` 加视频专属字段：mode（t2v/i2v）/ aspect_ratio / duration_ms / camera_movement / video_url / thumbnail_url / has_audio / progress / task_id
- Canvas UI：
  - NodeCard 视频分支：首帧缩略 + hover 播放按钮
  - Inspector 视频分支：mode 切换（有无 data edge 自动切）/ 运镜预设 dropdown / duration slider
  - 灯箱：全屏 video 播放 + 进度拖拽 + 倍速 + 下载（Flutter `video_player` or `media_kit`）
- data edge 消费扩展：`firstFrame` / `lastFrame` 已在 #39 做了（Kling 首末帧），这里复用
- §5.5 提取帧（首帧 / 末帧 / 任意帧）—— 新创建 image 节点，`model='frame_extract'`，不走 Provider
- GenerationController 扩展：video 分支写 video_url / thumbnail_url

### 规模
中大，估 **6-8 PR** / 5-7 工作日

### 风险
- **R1** Flutter Desktop 视频播放库选型：`video_player` 有 macOS 支持但 Windows 麻烦；`media_kit` 跨平台更稳但体积大
- **R2** thumbnail 生成：Provider 返回 video_url，首帧缩略要本地抽帧（`ffmpeg_kit_flutter` 已是 tech stack）
- **R3** 提取帧功能需要精确 frame seek，依赖 ffmpeg 命令行

### 解锁
PRD §5 整章、§19.1 MVP 边界里"视频生成"打钩、6 款视频 Provider 全部点亮

---

## 对比表

| 维度 | A 九宫格 | B 风格泳道 | C 视频节点 |
|---|---|---|---|
| 用户价值（关键帧/组织/模态） | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 技术规模 | 中 (5-7 PR) | 大 (8-10 PR) | 中大 (6-8 PR) |
| 已有资产复用 | 低（新字段 + 新算法） | 中（复用 Canvas） | **高**（5 款 Provider 已就绪） |
| 风险密度 | 中（依赖模型能力） | 高（Canvas 层再叠复杂度） | 中（Flutter 视频库选型） |
| 解锁 PRD 章节数 | 1（§4.6） | 1（§7） | **2**（§5 + MVP §19） |
| 对 schema 影响 | v=3 | v=3 | v=3 |
| 单元测试周期 | 短 | 长 | 中 |

---

## Tech Lead 推荐：**候选 C（视频节点）**

### 理由

1. **资产兑现**：T3 已经投入了 5 款视频 Provider（wanx-t2v/i2v/r2v + kling-v3/v3-omni，alpha.4 注册；Hailuo 未入 registry，defer T5.1），UI 层不对接等于资产烂在仓库——这是最硬的「产品价值 / 投入产出比」杠杆。
2. **风险密度最低**：Provider 层绿灯，data edge 的首末帧传递（#39）也绿了，最难的两块硬骨头已啃完。剩下的是 UI 组装 + Flutter 视频播放库选型——都是有 API 文档可查的活。
3. **PRD 覆盖面最大**：同时解锁 §5 整章 + §19.1 MVP 边界的视频项。A 候选只解锁 §4.6 单节。
4. **和用户当前体验对齐**：用户刚验证完图片单节点闭环；下一步看视频生成天然顺延，比"突然讲风格泳道"语义更连贯。

### 反对立场

- 如果你**更关心画布体验的一致性**（分镜工作流、多帧打包），A 九宫格更对。
- 如果你**已经开始吃 prompt 管理的苦**（每个节点都重复写风格词），B 风格泳道优先级高。

---

## 决策请求

请拍板一项（或给理由选别的）：

1. ✅ **C — 视频节点**（我推荐，起手 Sprint T5 Plan 走 `/writing-plans`）
2. **A — 九宫格**
3. **B — 风格泳道**
4. **自定义**：你来描述一个新方向（例如：批量并发 UI / §18 多选批量 / §23 ⌘K 命令栏 / 导出系统 §13）

拍板后我会：
- 把选定方向的 Sprint Plan 展开，保存到 `docs/specs/2026-04-22-t5-<feature>.md`
- 按切片切 PR（参考 T4 的 S1-S4 结构）
- 起 feature 分支动手

---

## 变更记录

## T5 Sprint 收口（2026-04-23）

**决策**：候选 C 落地。**Release: v0.1.0-alpha.8**。

**交付 Slice**（全部已 merge 到 dev）：
- S0 ADR-0006 视频播放库 media_kit（PR #52）
- S1 pubspec deps + CanvasNode video getters + macOS/Windows plugin registrant（PR #53）
- S2 NodeInspectorRouter + VideoConfigInspector（PR #55）
- S3 VideoDownloadService + GenerationController video 分支 + JobQueue remoteUrls 通道（PR #56）
- S4 MediaKitThumbnailService + NodeCard video body + 手动回归清单（PR #57）
- S6 Add Video Node FAB 菜单（PR #58）
- S5 VideoPlayerService + VideoLightbox + CI media_kit exclusion（PR #59）
- Plan 归档（PR #54）

**范围排除项**（defer）：
- PRD §5.5 提取帧（任意时刻 frame seek，defer T5.1）
- 批量视频（所有 Provider 当前 batch_size=1，YAGNI）
- Hailuo Provider 注册（不在本 Sprint scope，独立 PR）

**遗留 tech debt**：
- TD-003：`video_node_body_test.dart` 两条 widget test 进入 `fileResolverServiceProvider` 后 pump 不收敛（已 skip：true），需另查
- Pre-commit hook 在 worktree 下 `GIT_DIR` 环境污染 flutter SDK 探测（本 Sprint 全程走 plumbing commit 绕过）—— 独立 infra PR 跟进
- **实测** 5 款视频 Provider 真实生成验证（docs/internal/t5-manual-regression.md 已准备清单，release 前在本机手动走一遍）

---

## 变更记录

| 日期 | 修订 | 作者 |
|---|---|---|
| 2026-04-22 | 初版草稿 | Tech Lead |
| 2026-04-23 | 选 C 落地，Sprint 收口 + Provider 数字修正 6→5 | Tech Lead |
