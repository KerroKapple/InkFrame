# ADR-0011: 面向插件的扩展点——现在守住接缝，运行时插件系统延后到 ROADMAP

- **Status**: accepted（"design-for, defer-implementation" 立场）
- **Date**: 2026-07-01
- **Deciders**: P9 (Tech Lead)
- **Related**: ADR-0007 (Node type/role) / ADR-0009 (Provider 能力 + registry) / ADR-0010 (token 契约) / `ROADMAP.md` / `docs/CLAUDE.md`

---

## Context

InkFrame 的形态天然适合插件生态：新的 AI Provider、工作流、节点类型、主题都可以是"外挂"。诱惑是现在就做一个第三方插件运行时（装个插件就能加 Provider）。但真正的第三方插件运行时是一项重承诺：稳定公开 API、版本兼容、加载机制，以及**安全沙箱**——第三方代码会与"能访问用户 API Key 的进程"同栈运行。

**约束：**

- `docs/CLAUDE.md`：未实现的模块归 `ROADMAP.md`，本仓库文档只记已存在的东西
- 现状已具备"软插件"接缝：Provider registry（ADR-0009）、Node type/role 开放模型（ADR-0007）、design token 契约（ADR-0010）
- API Key 存于系统钥匙串，任何"可执行第三方代码"的能力都直接放大攻击面

**假设：**

- 短期内没有外部第三方插件的真实需求；内部加 Provider/节点是主要扩展场景
- 过早固化公开 API 的成本 > 收益

---

## Decision

**决定：** 采取"为插件而设计、但延后实现运行时"的立场。

**现在就守住的接缝（保持干净 + 文档化，但仍是内部 API）：**

1. **Provider registry 为唯一 Provider 接入点** + `ProviderCapabilities` 契约（ADR-0009）——加 Provider 已经"基本不动主程序"
2. **Node 的 type/role 为开放分类**（ADR-0007）——新节点种类沿两维度扩展
3. **design token / 主题契约**（ADR-0010）——主题是一组 token，天然是未来"主题插件"的接口面

**显式延后到 ROADMAP（不 now 实现）：**

- 运行时插件加载机制（manifest、发现、生命周期）
- 稳定的**公开** API 与版本兼容策略
- **安全沙箱 / 权限模型**（尤其是隔离第三方代码对 API Key 的访问）——这是延后的头号理由

**理由：** 低成本保留未来可能性（守接缝）；把高风险高成本的运行时留到有真实需求且能认真做安全时再上，符合 CLAUDE.md 的 ROADMAP 规矩。

---

## Consequences

**好的：**

- 现在几乎零成本地为未来插件化铺路（接缝已在，只是不对外）
- 不背上"过早公开 API + 沙箱"的巨大包袱
- 内部扩展（加 Provider/节点/主题）今天就顺滑

**坏的 / 欠的债：**

- 接缝目前是内部 API，未来对外时仍需一次"内部→公开"的稳定化 + 版本化工作
- "为插件设计"的纪律需要持续守（评审时留意别把这些接缝改脏）

**中性的（需观察）：**

- 何时从"design-for"转"implement"取决于外部需求信号与安全方案成熟度
- 运行时插件一旦上马，需要单独的 ADR（加载机制 + 沙箱 + 公开 API 版本策略）

---

## Alternatives Considered

### 方案 A: 现在就建完整插件运行时（动态加载 + manifest）
- **优势**：一步到位
- **否决理由**：过早——API 稳定性/版本/沙箱/Key 安全面巨大，且无外部需求；Flutter 桌面动态加载本身就难

### 方案 B: 什么都不做，Provider 用 if-else 写死
- **优势**：最省事
- **否决理由**：连内部扩展都昂贵，且直接关死未来（违反 OCP）；与 ADR-0009 冲突

### 方案 C: 立刻把内部 registry 当公开 API 暴露
- **优势**：显得"开放"
- **否决理由**：在 API 尚未稳定时锁死契约，后续改动即 breaking

---

## Revisit Triggers

- 出现明确的第三方插件需求（社区/商业）时
- 有了可接受的沙箱 / 权限方案（能隔离第三方代码对 API Key 的访问）时
- 内部接缝已足够稳定、且愿意承担版本兼容承诺时
- 届时为"插件运行时"单开 ADR，本 ADR 作为其前置背景
