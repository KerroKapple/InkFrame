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
| [ADR-0006](0006-video-playback-library.md) | 视频播放库：media_kit | accepted | 2026-04-22 |
| [ADR-0007](0007-node-type-role-jsonb-config.md) | 画布节点用 type × role 双维度建模，参数存 type_config JSONB | accepted | 2026-07-01 |
| [ADR-0008](0008-render-queue-jobstate-vs-jobstatus.md) | 渲染队列分层：JobStatus(瞬时) 与 JobState(UI 状态机) 分离，内存镜像 + jobs 表双层 | accepted | 2026-07-01（rev. 2026-07-07） |
| [ADR-0009](0009-provider-capability-and-interface-segregation.md) | Provider 抽象：能力声明(const) + 接口隔离 + registry 作为唯一接入点 | accepted | 2026-07-01（rev. 2026-07-02） |
| [ADR-0010](0010-zero-hardcoding-i18n-and-design-tokens.md) | 两条硬约束：i18n 零硬编码文案 + design-token 零硬编码样式 | accepted | 2026-07-01 |
| [ADR-0011](0011-plugin-oriented-extension-points.md) | 面向插件的扩展点：现在守住接缝，运行时插件系统延后到 ROADMAP | accepted | 2026-07-01 |
| [ADR-0012](0012-forward-migration-as-sole-data-upgrade-path.md) | 单线前向迁移是用户数据的唯一升级路径（D-4/U7/QG-5 拍板） | proposed | 2026-07-08 |

---

## 新增 ADR 流程

1. 复制 `TEMPLATE.md` → `NNNN-kebab-case-title.md`（ID 递增，不补全已删 ID）
2. 填：Context / Decision / Consequences / Alternatives Considered
3. 更新本索引
4. PR 评审：**至少一名 P9 或 P10 approve**——这是战略决策，不是实现细节
5. 合并后状态置 `accepted`；未来被推翻时**不删文件**，改状态 + 在新 ADR 里 `Supersedes ADR-NNNN`
