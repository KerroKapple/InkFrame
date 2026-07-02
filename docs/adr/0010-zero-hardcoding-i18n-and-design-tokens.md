# ADR-0010: 两条硬约束——i18n 零硬编码文案 + design-token 零硬编码样式

- **Status**: accepted
- **Date**: 2026-07-01
- **Deciders**: P9 (Tech Lead)
- **Related**: ADR-0002 (Riverpod / ThemeExtension) / `docs/CLAUDE.md` / `lib/l10n/app_en.arb` + `app_zh.arb` / `lib/theme/tokens.dart` / `lib/theme/app_theme.dart`

---

## Context

桌面应用要支持 en/zh 双语与深色/浅色/高对比三套主题 + 字号 a11y 缩放。"先写死、以后再抽"是最常见也最致命的做法——later 永远不来，漂移和缺翻译到用户那才暴露。需要把"文案走 i18n、样式走 token"确立为**硬约束**而非风格偏好。

**约束：**

- 双语必须键集一致（CI 校验 `app_en.arb` 与 `app_zh.arb` key set 相同，否则构建失败）
- 三套主题 + 字号缩放要求所有视觉量可切换、可缩放
- 部分字符串**不该** i18n：日志 module 名、错误码标识、SQL/JSON/协议字面量——它们是内部常量
- **LLM/系统提示词不该 i18n**：本地化 prompt = 每个语言一套模型行为，无法 A/B 归因

**假设：**

- 开发语言是英文（ARB 键与默认值英文），中文是对照翻译

---

## Decision

**决定：** 两条零硬编码硬约束，写进 `docs/CLAUDE.md` 并由 CI/评审守。

**① i18n**
- 所有终端用户可见文案走 ARB（`context.l10n.xxx`），en/zh 键集一致，CI 强校验
- 内部字符串保持英文常量：log module、`InkErrorCode` 标识、SQL/JSON keys、协议字面量
- **LLM/系统提示词保持英文常量**，不入 ARB；若要 prompt 内注入语言，把 locale code 作为参数传入，模板本身仍英文

**② design token**
- 每个颜色/字号/间距/圆角/阴影/动效来自 token 系统；**`lib/theme/tokens.dart` 是唯一允许出现字面量 hex/数值的文件**（见文件头注释）
- 访问方式固定：`context.inkColors` / `context.inkTypography`（`InkThemeX` 扩展，`lib/theme/app_theme.dart`）+ 静态 `InkSpacing` / `InkRadius` / `InkShadow` / `InkMotion`
- widget 内**禁止** `Color(0xFF..)` / `fontSize: 14`
- 字号必须支持 a11y 缩放：文本样式经 `InkTypography.defaults(scale:)` / `scaled()`；widget 只允许 `copyWith(color:)`，**不许** `copyWith(fontSize:)`

**理由：** 约束前置到编译/CI，把"later 再抽"的债堵死；主题变体与 a11y 缩放要求样式必须 token 化才可能实现。

---

## Consequences

**好的：**

- 双语覆盖由 CI 保证，不会漏键；新增文案强制同时补 en/zh（本迭代新增 6 个 inspector 键即遵此）
- 深/浅/高对比三主题 + 字号缩放"免费"生效——因为一切读 token
- LLM prompt 行为跨语言一致，可复现、可 A/B
- 视觉改版集中在 `tokens.dart`

**坏的 / 欠的债：**

- 每加一个文案要动两个 ARB + 跑 gen-l10n，略繁（但换来零漂移）
- token 间接层让"随手调个颜色"要走 token；这是刻意的
- 需要 lint/CI 持续把守，否则约束会被"就这一次"侵蚀

**中性的（需观察）：**

- 新增 locale 只是加 ARB 文件，键集一致规则自然推广
- 若某处确需 locale-aware 的 prompt 片段，用参数注入而非翻译模板

---

## Alternatives Considered

### 方案 A: 先硬编码文案，之后统一抽取
- **优势**：眼前快
- **否决理由**：later 不来；漂移 + 缺翻译到用户端才暴露；无 CI 兜底

### 方案 B: 连 LLM prompt 一起本地化
- **优势**：看似"更本地化"
- **否决理由**：每语言一套模型行为，A/B 与回归无从谈起（这是本 ADR 特别点名要避免的）

### 方案 C: 内联样式 / 随手 `Color(0xFF..)`
- **优势**：写起来直接
- **否决理由**：三主题切换 + 字号 a11y 缩放直接做不到；改版要全仓库搜替

### 方案 D: 只用 lint 提示、不阻断 CI
- **优势**：宽松
- **否决理由**：非阻断的规范会腐烂；硬约束必须能让构建失败

---

## Revisit Triggers

- 引入第 3+ 种语言或 RTL 语言时，重审 ARB 组织与排版 token
- 若 gen-l10n / ARB 维护成本显著上升，考虑键管理工具
- 出现确需运行时主题（用户自定义主题/插件主题，见 ADR-0011）时，重审 token 的开放面
- 至迟在首个非 en/zh locale 接入前重审
