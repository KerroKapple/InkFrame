# ADR-0003: 领域模型用 freezed，Repository 层暴露 `Map<String, Object?>`

- **Status**: accepted
- **Date**: 2026-04-15
- **Deciders**: P9 (Tech Lead)
- **Related**: CLAUDE.md §Code Rules / ARCHITECTURE §3 / T2 P7 实现 (`lib/core/interfaces/*.dart`)
- **Revised**: 2026-07-07（updated_at 闸门机制更新——见文末修订记录）

---

## Context

跨层的数据形态至少有三种候选：

1. **Repository 返回 freezed 领域对象**：`Future<Node> findById(String id)`
2. **Repository 返回 `Map<String, Object?>`**：`Future<Map<String, Object?>?> findById(String id)`，Service/ViewModel 层自行转 freezed
3. **Repository 返回 ORM 实体**：类似 Drift/Hibernate 的生成对象

**约束：**

- **CLAUDE.md §Code Rules**：所有模型 freezed；不接受 `Map<String, dynamic>` 作为**模型替代品**
- **SOLID D**：Widget / ViewModel / Service 层禁止 import `postgres` 包
- **T2 落地现状**：7 个 Repository interface 已经写成 `Map<String, Object?>`（`lib/core/interfaces/*.dart`），并通过了 26 case（22 违规 + 4 级联）测试
- **Schema 演进频繁**：v0.1.0 到 v1.0 预计 3-5 次 schema 变化；每次加字段都要同步 freezed 会增大重构面

**假设：**

- Service 层是唯一合理做"DB 行 → 领域模型"转换的地方
- 领域模型是业务规则的聚合（如 `Node` 的 `parentGrid` / `gridChildren` 一致性），不应该和"DB 行"强绑

---

## Decision

**决定：** 分层使用两种数据形态：

| 层 | 形态 | 理由 |
|---|---|---|
| UI / ViewModel / Service | freezed 领域对象 | 不可变、copyWith、sealed union、JSON 序列化 |
| Repository interface | `Map<String, Object?>` | 解耦 schema 演进；零 ORM 依赖；测试友好 |
| DB 驱动 (`package:postgres`) | postgres 原生类型 | 由 Repository 实现承担转换 |

**边界规则：**

1. Service 层第一件事：`Node.fromRow(row)` 把 Map 转 freezed；之后全程 freezed
2. Repository 接口只返回 `Map<String, Object?>` / `List<Map<String, Object?>>`——**禁止**在 interface 里 import freezed 模型
3. `BaseRepository.withUpdatedAt()` 统一维护 `updated_at`，写路径 patch 也是 Map

**freezed 规范**（CLAUDE.md 已约束，此处重申）：

- `@freezed class Node with _$Node { const factory Node({...}) = _Node; }`
- 所有模型字段不可为 `dynamic`；JSON 字段用 `@Default(...) Map<String, Object?>`
- `sealed class` 用于 tagged union（`JobStatus`, `CostModel`, `InkError`, `KeyValidationResult`）

---

## Consequences

**好的：**

- Schema 改字段不 break interface——Service 层的 `fromRow` 扩展即可；已在 T2 落地并通过 `check-updated-at.sh`
- Repository 单测用内存 `Map` 喂数据，不启 PG
- Service 层 `fromRow` 是唯一的"脏"地方，集中校验，易复查
- freezed sealed 类把 14 错误码、3 种 CostModel 表达为穷举——编译器帮忙查漏

**坏的 / 欠的债：**

- `fromRow` 转换样板：每张表一个，共 8 个；可接受
- `Map<String, Object?>` 弱类型：取字段靠字符串键 + `as` 断言——用 Dart 常量 + 小工具函数（`lib/core/db/row_ext.dart`）约束
- ORM 的自动 query builder 用不上；手写 SQL，目前 prepared statement 够
- 字段拼写错在 `fromRow` / patch 里到运行时才暴露——需测试覆盖矩阵（T2 已达 85.0%）

**中性的（需观察）：**

- freezed 的 `@JsonKey` 和 DB 列名映射约定：`createdAt` ↔ `created_at`，Service 层转换层承担
- 若未来引入 codegen 工具从 DDL 生成 Row 常量，可减样板；暂不引入避免依赖

---

## Alternatives Considered

### 方案 A: Repository 直接返回 freezed 模型

- **优势**：Service 不用转换
- **否决理由**：
  - freezed 字段变化 = interface 变化 = 所有实现都要改——schema 演进成本巨大
  - interface 绑 freezed 后测试喂假数据必须 freezed 实例，写测试更重
  - Repository 本质是数据访问，它**不应该**知道业务聚合规则

### 方案 B: Drift 或类似 ORM 生成实体

- **优势**：类型安全 + query builder
- **否决理由**：
  - Drift 面向 SQLite；PG 支持是社区包，非一线
  - 生成实体与 freezed 领域模型是两套类型，仍需转换
  - ORM 对跨表 CHECK / 复杂级联的表达力弱于手写 SQL（详见 ADR-0001）

### 方案 C: 统一用 `Map<String, dynamic>` 到 UI

- **优势**：零样板
- **否决理由**：
  - 直接违反 CLAUDE.md：`NO Map<String, dynamic> as model substitute`
  - Widget 层 `row['title'] as String` 到处写，拼写错到用户那才暴露
  - sealed union / copyWith / == / hashCode 全失去

### 方案 D: 在 interface 里返回强类型 Row DTO（非 freezed 的轻对象）

- **优势**：类型安全，避免 freezed 重量
- **否决理由**：多一层 DTO 反而让 Service 层做双重转换（Row DTO → 领域模型），收益不抵成本

---

## Revisit Triggers

- 若 Service 层 `fromRow` 转换样板积累到 >1000 行，考虑引入 codegen
- 若项目引入大量聚合查询（跨 5+ 表 join）导致 Map 返回膨胀难维护，考虑局部 ORM
- freezed / Dart record 未来演进允许零样板 Row 解构时重审
- 至迟在 v0.2.0 Sprint 启动前重审

---

## 修订记录

### 2026-07-07 — updated_at 闸门机制更新（不改决策）

Consequences 所引 `check-updated-at.sh` bash hook 已删除，闸门迁为
**`test/quality/updated_at_test.dart`**（纯 Dart 静态扫描 `lib/storage/`，随 pre-commit
`flutter test test/quality/` 与 CI 阻断执行），语义等价：`UPDATE <table> SET` 缺
`updated_at` 即红，无列表白名单 + UPSERT 子句豁免。注入点仍是
`BaseRepository.withUpdatedAt / buildUpdate`，决策本体（Map 边界 + freezed 领域层）不变。
