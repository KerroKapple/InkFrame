# ADR 索引 — InkFrame

> **Architecture Decision Records**：记录已落地的关键架构决策及其背景、权衡、后果。
> **不记**细枝末节实现选择；**记**具有长期约束力、反悔成本高的决策。

---

## 状态机

```
proposed ──► accepted ──► superseded (by ADR-NNNN)
                └──► deprecated
```

## 目录

| ID | 标题 | 状态 | 日期 |
|---|---|---|---|
| [ADR-0001](0001-embedded-postgresql.md) | 使用嵌入式 PostgreSQL 作为本地存储 | accepted | 2026-04-15 |
| [ADR-0002](0002-riverpod-for-state-and-di.md) | 使用 Riverpod 统一状态管理与依赖注入 | accepted | 2026-04-15 |
| [ADR-0003](0003-freezed-models-map-at-repo-edge.md) | 领域模型用 freezed，Repository 层暴露 `Map<String, Object?>` | accepted | 2026-04-15 |
| [ADR-0004](0004-sync-provider-data-channel.md) | 同步 Provider 通过 Pollable + inline bytes 通道暴露结果 | accepted | 2026-04-18 |
| [ADR-0005](0005-dashscope-async-provider-base.md) | DashScope 异步 Provider 公共基类（Wanx + Kling 6 Provider 共享） | accepted | 2026-04-18 |

---

## 新增 ADR 流程

1. 复制 `TEMPLATE.md` → `NNNN-kebab-case-title.md`（ID 递增，不补全已删 ID）
2. 填：Context / Decision / Consequences / Alternatives Considered
3. 更新本索引
4. PR 评审：**至少一名 P9 或 P10 approve**——这是战略决策，不是实现细节
5. 合并后状态置 `accepted`；未来被推翻时**不删文件**，改状态 + 在新 ADR 里 `Supersedes ADR-NNNN`
