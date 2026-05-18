# InkFrame — 发酵文案草稿（不入仓库公开目录，仅 internal）

> 草稿，未发布。3 套：(1) X/Twitter 推文串；(2) 掘金/少数派长文；(3) HN Show 帖。
> 发布前请人工核对：链接、版本号、Provider 名称是否最新。

---

## 1. X / Twitter 推文串（英文，5 条）

**1/5**
🎬 Open-sourced InkFrame today — a local-first AI filmmaking workstation.

Flutter Desktop. Node-based canvas. Wires Aliyun wanx / Kling / Gemini into a traceable text→image→video pipeline. Your API keys + data never leave the box.

macOS + Windows.
👉 https://github.com/KerroKapple/InkFrame

**2/5**
Why local-first?
• Embedded Postgres 17 for state
• System Keychain / Credential Manager for keys
• Generated assets on disk, never uploaded
• Direct provider calls — no middleman server, no telemetry

If you've ever been nervous about a SaaS UI holding your sk- keys: this is the alternative.

**3/5**
Architecture is opinionated:
• SOLID red lines (every injectable has an abstract interface)
• Riverpod DI, no static singletons
• Zero hardcoded strings (i18n red line, en/zh parity enforced in CI)
• Zero hardcoded styles (design tokens only)
• freezed everywhere

docs/CLAUDE.md + docs/ARCHITECTURE.md spell it out.

**4/5**
Stage: alpha (v0.1.0-alpha.8). Video loop works. UI is mid-rework toward a unified token system.

Looking for first contributors. 5 issues tagged `good first issue`, scoped 30 min – 2 h:
• .editorconfig
• README Quickstart
• zh-CN ARB native review
• i18n unused-keys reporter
• Windows dev-env doc
• dio_error_mapper unit tests

https://github.com/KerroKapple/InkFrame/issues?q=is%3Aopen+label%3A%22good+first+issue%22

**5/5**
If you build with AI image/video models and have ever wished the tool around them wasn't a SaaS — try it, file issues, send PRs.

Stars help, but issues + PRs help more.
🔗 https://github.com/KerroKapple/InkFrame
🇨🇳 README.zh-CN.md is in the repo.

---

## 2. 掘金 / 少数派长文骨架（中文，~1500 字）

**标题候选：**
- 《我把 AI 影视工作流做成了纯本地桌面应用 —— 开源 InkFrame v0.1-alpha》
- 《不再把 sk- key 交给 SaaS：InkFrame 的本地优先设计》
- 《Flutter Desktop + 嵌入式 Postgres + 节点画布 —— 一个独立创作者的工具栈》

**结构：**

### 引子（200 字）
- 痛点：用 ComfyUI 太重，用 SaaS 担心 key 和素材；想要的工具不存在，所以做了一个
- 一句话定位：**InkFrame = 节点画布 + 多 Provider 串联 + 本地存储 + Flutter 桌面**

### 它能做什么（300 字 + 1 张截图）
- 节点画布：text → image → video 链式生成，每个节点保留输入/参数/输出/状态
- 6 个 Provider 已接入：通义万相系列（image / i2v / r2v / t2v）、Kling v3 / v3-Omni、Gemini Image
- 数据：嵌入式 Postgres 17 持久化；API Key 走系统钥匙串
- 双平台：macOS + Windows，单 Dart 代码库

### 为什么本地优先（300 字）
- 隐私：素材不上传、Key 不离机
- 可控：直连 Provider 官方 API，没有中间服务器、没有遥测
- 可移植：所有数据在本地目录，搬机器就是搬文件夹

### 技术栈（300 字，给开发者看的）
- Flutter Desktop + Riverpod（带代码生成）
- freezed 全量不可变模型
- 嵌入式 Postgres 17（pg_binary_locator + pg_controller 管生命周期）
- dio + 自实现的 DioException → InkError 错误映射层
- i18n / 设计 token 双红线：CI 卡 ARB 键集对齐

### 我学到了什么（200 字）
- 桌面 + 嵌入式数据库的体验比想象中好
- Riverpod 的 `autoDispose` 几乎杀死了所有内存泄漏的可能
- 设计 token 系统不是过度工程，是让多人开发时颜色不发散的唯一手段

### 欢迎来贡献（200 字）
- 当前 6 个 `good first issue`，最快 30 min 一个 PR
- 列出标题 + 工时估算（直接复制 Issue 列表）
- CONTRIBUTING.md 已写齐 PR 流程
- 链接：https://github.com/KerroKapple/InkFrame

### 路线图（100 字）
- 短期：UI 设计 token 系统收口、剧本编辑器、storyboard 表
- 中期：视频导出（ffmpeg）、资产浏览器
- 长期：插件机制让 Provider 用户自接

**配图建议：**
- 节点画布工作中的截图（带连线 + result 节点）
- 设置页 API Key 区域（局部，掩码态）
- README 顶部 badge 行

**首发平台优先级：**
1. 少数派（首发，正文 + 评论区可控）
2. 掘金（同步发，技术读者）
3. V2Ph / V2EX 帖（短版）

---

## 3. Hacker News Show 帖（英文，简短）

**标题：** Show HN: InkFrame — local-first AI filmmaking workstation in Flutter Desktop

**正文（约 150 字）：**

I built InkFrame because every "AI filmmaking" tool I tried was either a SaaS that wanted my sk- keys, or ComfyUI bent into a shape it wasn't built for.

InkFrame is a Flutter Desktop app (macOS + Windows) with a node-based canvas. You drop in text/image/video nodes, wire them up, and they call providers (Aliyun wanx, Kling, Gemini) directly from your machine. Embedded Postgres for state, system keychain for keys, generated assets on local disk. No middleman server.

Currently alpha — video loop works, UI is mid-rework. Six `good first issue`s up if anyone wants to try contributing.

Stack notes for HN crowd: Riverpod DI, freezed everywhere, SOLID enforced via abstract interfaces, i18n + design tokens both treated as CI red lines.

Repo: https://github.com/KerroKapple/InkFrame
Architecture rationale: docs/ARCHITECTURE.md
Contributing on-ramp: docs/CLAUDE.md

Curious what people think — especially anyone who's been frustrated with SaaS-only AI workflows.

---

## 发布前 checklist

- [ ] 给少数派/掘金各准备 3-4 张高质量截图（不带任何真实 API key / 素材）
- [ ] X 推文串前 5 分钟先发到自己 GitHub Discussions 留底（防止后续修改痕迹）
- [ ] HN 发帖时间窗：北京时间 21:00-23:00（对应 SF 早上 6-8 点）
- [ ] 发完所有渠道后，盯 6 小时回应评论 —— 第一波回应延迟 > 1 小时基本就死了
- [ ] 如果 HN 上首页：准备 README 顶部加 "🎉 As seen on HN" 反向引流
