# Roadmap

> 当前阶段: **alpha**。每个里程碑对应一个 minor tag。Help wanted = 维护者欢迎 PR / 协同设计的方向。
>
> 想认领某条？开 issue 或在 Discussions 提问，对齐 scope 后再动手。**不要直接闷头 PR 大功能**——先对齐方向避免白做。
>
> Project stage: **alpha**. Each milestone corresponds to a minor tag. "Help wanted" entries are directions where the maintainer welcomes PRs and co-design.
>
> Want to claim something? File an issue or post in Discussions to align scope first — please **don't write a large PR before alignment**.

---

## ✅ Shipped (v0.1.0-alpha.x)

| Tag | 主题 / Theme | 日期 |
|-----|--------------|------|
| alpha.9 | UI Sprint 1+2 — CineFlow tokens + 9 primitives + 开源准备（README / LICENSE / MIT） | 2026-04 |
| alpha.8 | T5 video node UI loop — 5 款视频 Provider UI 接入 + Lightbox | 2026-04 |
| alpha.7 | canvas UX 收口 — 节点删除 / Inspector autosave / FAB | 2026-04 |
| alpha.6 | secure-storage：DashScope 系 6 款 Provider 共用 Key | 2026-04 |
| alpha.5 | canvas 点击选中连线 + midpoint 删除按钮 | 2026-04 |
| earlier | alpha.1 ~ alpha.4 — 基础 canvas / DI / i18n 骨架（见 `git tag`） | — |

> **已合并 main，未打 tag（→ alpha.10）/ Merged on main, untagged (→ alpha.10):**
> Amber Noir shell 重写（frameless chrome + Studio + Canvas，取代 CineFlow，#100/#101）·
> 生成流程接入 canvas（open-canvas + 实时 job 进度 + 去 mock 渲染队列，#104/#105）·
> 移除 Lock 启动闸门，直接进入 Studio（#108）·
> 后端 P0–P2 加固（UnitOfWork 事务 / 仓储类型化 / SyncProviderBase，#126–#132）·
> **M1「能用起来」**（偏好持久化 / 节点级进度 / 画布性能 / 项目管理 + 正确性簇，#133）·
> **M2「创作者要的」**（参考图/首尾帧 UI / 角色一致性 / 批量变体 / 预设库 / 成本估算，#134/#138）·
> M3 首切片 ×4（Shot 分镜 / ffmpeg 视频导出 / 产物画廊 / custom_providers 聚合器，#134）·
> 内嵌 PG 装进 app bundle（#135）· 双语 README 定位落地（#136）· wanx-i2v wan2.7 契约（#137）。
> 里程碑级实时状态见 [`docs/BOARD.md`](docs/BOARD.md)。

## 🛠 In Progress (Maintainer)

- **M3 差异化深化** — Shot 脚本解析/序列预览 · 视频导出 UI/转码归一 · 画廊拖入画布/筛选 · 自定义 Provider 设置页 UI（见 [`docs/BOARD.md`](docs/BOARD.md) M3 表）
- **发布管线** — 签名/公证/打包（chore/release-pipeline 分支起步）
- **稳定 alpha → beta** — 测试覆盖 / 跨平台烟测 / 性能基线

## 🙋 Help Wanted

按贡献门槛由低到高排列。Sorted by contribution effort, lowest first.

### 📚 文档 / i18n

- 翻译 README / CONTRIBUTING 到第 3 种语言（日 / 韩 / 西班牙语优先）
  Translate README / CONTRIBUTING to a third language (JA / KO / ES preferred)
- ARB 文件中文翻译 review — 当前 `app_zh.arb` 由维护者一人翻译，需要母语者抽查硬翻味
  Native-Chinese review pass on `app_zh.arb` keys
- ARB 文件英文 polish — 同上，但是 native English speaker review

### 🔌 Provider 接入 / Provider integration

新增 AI provider 不需要懂整个 codebase，只需读 [`docs/PROVIDER-API.md`](docs/PROVIDER-API.md) 实现一个文件。
Adding a new AI provider does not require understanding the whole codebase — read [`docs/PROVIDER-API.md`](docs/PROVIDER-API.md) and implement a single file.

| Provider | 类型 / Type | 状态 / Status | 优先级 |
|----------|-------------|---------------|--------|
| Stable Diffusion (local ComfyUI) | image | 🟢 Open | High |
| Midjourney (Discord API) | image | 🟢 Open | Medium |
| OpenAI DALL-E 3（`gpt-image-1` 已内置，此条指 DALL-E 3 专用接入） | image | 🟢 Open | Medium |
| Runway Gen-3 / Gen-4 | video | 🟢 Open | High |
| Pika Labs | video | 🟢 Open | Medium |
| Luma Dream Machine | video | 🟢 Open | Medium |
| Jimeng (Volcengine 即梦) | image | 🟢 Open | Medium |
| Hailuo (MiniMax 海螺) | video | 🟢 Open | Medium |
| Kling 官方 API（非 DashScope 渠道） | image / video | 🟢 Open | Low |

已实现 / Implemented: Gemini Image · OpenAI GPT-Image (`gpt-image-1`) · Stability Stable Image Core · Kling V3 / V3 Omni (DashScope) · Wanx (image / i2v / r2v / t2v)。共 9 款内置，另有 OpenAI 兼容自定义端点（`custom_providers.json`，PROVIDER-API §13）。差异矩阵见 [`docs/PROVIDER-API.md`](docs/PROVIDER-API.md) §9。

> 相关 Planned 基建（设计已写入文档、待实现）：配额展示（原 `QuotaAware` 接口，已删待重立项）· JobQueue **job 级**自动重试与下载续传（poll 级瞬时错误退避已有，ARCHITECTURE §5.3 / §8）· 性能降级控制器（ARCHITECTURE §10）。
> 已从本清单毕业：成本预估 + UI 成本展示（M2 落地）· `custom_providers.json`（M3 首切片落地）。

### 🎨 Canvas / Editor

- Undo/Redo — 画布操作历史（当前无 undo stack，从零设计）
- 节点 group / collapse — 泳道级折叠已落地（lane collapse），节点级 group 未做
- 画布缩放性能优化 — 节点 > 200 时 frame drop

### 💻 平台 / Platform

- Windows 烟测自动化 — macOS 已手动跑，Windows 缺 reproducible 流程
- Linux 桌面端可行性评估 — 社区有需求即启动

### 🧪 测试基建 / Test infrastructure

- Golden test 覆盖扩展 — 基线管线已就绪（CI ubuntu 铸造 + update-goldens workflow），当前仅 NodeCard 3 态，扩到更多组件
- E2E：完整 script → storyboard → export 流程
- Coverage 70% 门槛之上的提升路径

## 🚫 Out of Scope（明确不做 / Explicit non-goals）

- 移动端（iOS/Android）— 项目定位是 desktop workstation
- Web 端 SaaS — 与 local-first 设计哲学冲突
- 闭源 / 商业 license — MIT 不变

## 如何参与 / How to contribute

1. 看到感兴趣的条目 → 开 issue / 在已有 issue 评论"我来" / Comment on an existing issue or open a new one
2. 维护者 24-72h 内 ack 并对齐 scope
3. 切 feature 分支（fork 也行）→ 按 [CONTRIBUTING.md](CONTRIBUTING.md) 规范开 PR
4. CI 绿 + review pass → squash merge

第一次贡献？看 issue tracker 里 [`good first issue`](https://github.com/KerroKapple/InkFrame/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) 标签。
First-time contributor? Look for the `good first issue` label.
