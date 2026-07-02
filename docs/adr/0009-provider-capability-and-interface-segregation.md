# ADR-0009: Provider 抽象——能力声明(const) + 接口隔离 + registry 作为唯一接入点

- **Status**: accepted
- **Date**: 2026-07-01
- **Deciders**: P9 (Tech Lead)
- **Related**: ADR-0004 (同步 Provider 数据通道) / ADR-0005 (DashScope 异步基类) / ADR-0011 (插件扩展点) / `lib/core/interfaces/generation_provider.dart` / `lib/core/models/provider_capabilities.dart`

---

## Context

InkFrame 要接入多家异构 AI Provider（Gemini / OpenAI / Stability / Wanx 系 / Kling 系），能力差异巨大：有的支持 seed，有的支持负向词/批量/参考图/首尾帧，有的是同步返回、有的是异步轮询。UI 需要据此**动态显隐控件**，主程序需要**不改核心就能加 Provider**。

**约束：**

- **SOLID-I / -O**：不能让每个 Provider 去实现一堆用不到的方法；UI 不能用 `if (providerId == ...)` 链
- 能力必须**可静态、确定性地**判断（UI 控件显隐、并发/限流参数都依赖它）
- 已有 ADR-0004/0005：同步 Provider 走 Pollable + inline bytes 通道；6 个 DashScope 异步 Provider 共享基类

**假设：**

- Provider 的能力在编译期已知且稳定（不随运行时环境变化）
- 新增 Provider 是常态，应低成本

---

## Decision

**决定：** 三件套。

1. **接口隔离**（`lib/core/interfaces/generation_provider.dart`）：拆成小能力接口 —— `Submittable`（`capabilities` + `submit(GenerationTask) → JobId`）、`Pollable`、`Cancellable`、`KeyValidatable`。Provider 只实现自己支持的，不做空壳方法。
2. **能力 const 声明**（`lib/core/models/provider_capabilities.dart`）：每个 Provider 用一个 **const `ProviderCapabilities`** 声明 `modes / supportedResolutions / supportedRatios / supportedDurations / supportedCameras / supportsSeed / supportsNegativePrompt / supportsBatch + maxBatchSize / maxRefImages / supportsFirstFrame / supportsLastFrame / maxConcurrentJobs / qps / burst / ...`。**禁止**从 .env / DB / 网络下发（见文件头注释）。UI 据这些位 gate 控件。
3. **registry 单一接入点**：`providerId → factory` 注册表（`lib/providers/provider_registry.dart` + `lib/core/di/providers.dart`），`providerCapabilitiesListProvider` 暴露给 UI。加一个 Provider ≈ 写一个类 + 一行注册。

**理由：** ISP 让 Provider 只承诺能做的；const 能力让 UI 确定性自适应；registry 是唯一的开放-封闭接缝。

---

## Consequences

**好的：**

- 加 Provider 不动核心 UI/控制器——只写类 + 注册（这也是 ADR-0011 插件化的基础接缝）
- UI 按能力位显隐（分辨率/比例/时长/运镜/seed/负向/批量/参考图），无 `if providerId` 链
- 能力编译期固定 → 行为可预测、可测试、无运行时探测开销
- ADR-0004/0005 成为本抽象下的两个具体落地实例

**坏的 / 欠的债：**

- 能力位与真实 API 能力需人工对齐；声明错了 UI 会给出错误控件
- const 声明意味着"改能力=改代码+发版"，不能热更（这是刻意取舍）
- 接口拆多了，组合类型（既 Submittable 又 Pollable 又 Cancellable）的书写略繁

**中性的（需观察）：**

- **当前差距（诚实记录）**：图像 inspector 长期只对 `supportedResolutions` 做能力驱动；`seed/negative_prompt/batch_size/aspectRatio` 虽有能力位，直到本迭代才在 UI+控制器端接通（见相应改动）。视频 `supportedCameras` 目前各 Provider 均为空，运镜控件按"空则隐藏"处理
- 若将来确需运行时能力（如账户档位影响可用分辨率），需引入"静态基线 + 运行时覆盖"的显式模型，而非直接改 const

---

## Alternatives Considered

### 方案 A: 单一大接口 `GenerationProvider`（含所有方法，可空实现）
- **优势**：类型单一
- **否决理由**：违反 ISP，强迫每个 Provider 空壳一堆方法；UI 无法可靠判断"到底支持啥"

### 方案 B: 能力从 config/DB/远端下发
- **优势**：可热更
- **否决理由**：UI 行为不确定、无法 A/B 归因；引入刷新/安全/一致性负担；与"编译期固定"约束冲突

### 方案 C: 运行时探测能力（调 API 发现）
- **优势**：最"准"
- **否决理由**：慢、脆、可能产生费用；启动期不可用

### 方案 D: UI 里按 providerId 走 if-else
- **优势**：直接
- **否决理由**：违反 OCP，每加一个 Provider 都要改核心 UI；能力散落各处

---

## Revisit Triggers

- 出现"同一 Provider 能力随账户/区域动态变化"的强需求时，引入静态基线 + 运行时覆盖模型
- 接口组合复杂度上升（出现第 5、6 种能力接口）时，重审拆分粒度
- 正式插件运行时落地（ADR-0011）时，需把 registry + 能力契约提升为稳定公开 API
- 至迟在开放第三方 Provider 前重审
