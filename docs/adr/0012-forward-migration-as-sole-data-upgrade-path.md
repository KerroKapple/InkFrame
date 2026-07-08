# ADR-0012: 单线前向迁移是用户数据的唯一升级路径

- **Status**: proposed（本 ADR 是 D-4 / U7 / QG-5 的拍板载体，合并即视为 accepted；待 张文开（KPM）审核）
- **Date**: 2026-07-08
- **Deciders**: 张文开（KPM）— 终审拍板；起草依据 MASTERPLAN §9 D-4 推荐项 A
- **Related**: MASTERPLAN §9 D-4（= U7 = QG-5）· PRD §22.0（`schema_version` 规则）· LB-07（PG trust→SCRAM）· LB-11/LB-12（项目导出/导入）· QG-4/QG-5（升级演练）· `docs/CLAUDE.md` › Zero Backward Compatibility

---

## Context

InkFrame 存在一处**治理层面的硬矛盾**，卡住 beta 前的多条数据安全线（MASTERPLAN §9 列为 D-4，"beta 前必须拍；不拍则每次 schema PR 都在灰区"）：

1. **铁律文本说"不迁移"**。`docs/CLAUDE.md` › Zero Backward Compatibility 明文规定：
   > NO migration scripts for old data formats · If a schema changes, the old version is dead. Period.

   全局规则同调，但留了口子——"No compatibility, migration, or legacy support **unless explicitly requested**"。

2. **但代码早已在做前向迁移，且已随 alpha.9 上线**：
   - `lib/storage/migrations/migration_runner.dart` + `app_migrations.dart` 实现了一条 **v1→v7、单调递增、原子（DDL + `schema_version` UPSERT 同一事务，ME-31）、有缺口校验、显式拒绝降级（`SchemaDowngradeError`）** 的前向迁移链。
   - `schema_version` 单行表（`CHECK(id = 1)`）记录库版本：库版本 < 应用期望 → 顺序补跑缺失迁移；> 期望 → 抛"请升级应用，不支持降级"。
   - 这套规则的来源就是 PRD §22.0。
   - `v0.1.0-alpha.9` 已公开分发，**真实用户数据在外**（release-engineering 调研 §0 实锤）。

3. **矛盾的下游代价**——只要政策不拍板，以下卡全部悬在灰区：
   - **LB-07（PG trust→SCRAM）**：能否对**存量库**加固（而非"清库重来"），取决于是否承认存量数据与迁移的合法性。
   - **LB-12（项目导入，全计划最大风险卡）**：导入包 manifest 要不要带 schema 版本、导入时是否跑前向迁移到目标版本，取决于本政策。
   - **QG-4 / QG-5（数据升级演练）**：alpha.9 → 当前 的升级回归要不要作为 beta 门槛。
   - **每一个 schema 变更 PR**：加迁移 vs 改旧迁移 vs 弃数据，无统一裁决。

> 本 ADR 只解决"用户持久化数据跨版本如何演进"这一个问题；**不**讨论代码 / API 的兼容策略——那部分 Zero-BC 铁律不变。

## Decision

**决定（MASTERPLAN §9 D-4 推荐项 A）：把"零向后兼容"重新精确界定——`单线前向迁移（single-line forward migration）是用户持久化数据（嵌入式 PostgreSQL 工作区）跨应用版本的唯一、且受支持的升级路径`。**

边界精确化：

- **Zero-BC 继续禁止**：保留旧数据格式的并行解析路径、为"以防万一"保留的弃用 API / 僵尸代码、旧格式回退分支、**降级**（旧版应用打开新版库——已由 `SchemaDowngradeError` 硬拒）。
- **Zero-BC 不等于销毁用户数据**：schema 变更**不得**删库 / 重置用户工作区；库通过前向迁移链推进到当前版本，用户数据**必须存活**。
- **唯一升级路径**：任何 schema 变更 = **追加一条编号连续的新前向迁移**；**已发布的迁移不可变**（不得事后编辑 v3 的 DDL，只能再加 `v_next` 修正）。
- **本 ADR 即那次"explicitly requested"**：全局铁律留的口子，在**存储层**由本决策显式行使。

**理由（底层逻辑）：**

1. **代码 / PRD / 已上线事实三方本就是 A**。迁移链、`schema_version`、降级拒绝均已实现、已测试、已随 alpha.9 分发。这里不是"选方向"，而是**让铁律文本追认既成且正确的工程事实**；字面 B 会让 alpha.9 存量用户每次升级丢工程。
2. **公开测试期的数据可信度是信任资产**。一个"schema 一变就清空你项目"的桌面工具，在 beta 期不可接受，且正面摧毁 local-first / 数据主权 的核心叙事。
3. **一条规则解四处灰区**。A 一拍，LB-07 对存量库加固、LB-12 导入版本策略、QG-4 升级演练门槛、每个 schema PR 的"加迁移、不改旧迁移"约束，全部有确定答案。

## Consequences

**好的：**
- 解锁 LB-07 / LB-12 / QG-4 / QG-5，beta 数据安全线可开工。
- 每个 schema PR 有确定规程：追加编号连续的前向迁移 + roundtrip / 升级测试；禁止编辑已发布迁移。
- `docs/CLAUDE.md` 铁律文本与真实实现对齐，消除"文档说不迁移、代码在迁移"的认知分裂。

**坏的 / 欠的债：**
- `kAppMigrations` 只增不减，迁移列表长期单调增长；旧迁移永久保留（历史包袱换数据安全，值得）。
- 需补一条 **QG-4 真实升级演练**（alpha.9 库 → 当前版本）作为 beta 门槛，此后每个 schema PR 都欠一条升级测试。
- 需同步微调 `docs/CLAUDE.md` › Zero Backward Compatibility（本 PR 已含该改动）。

**中性的（需持续观察）：**
- 降级仍显式不支持（`SchemaDowngradeError`）；若将来要支持"新版库被旧版应用打开"，须另立 ADR。
- 多写入 / 同步 / 局域网 场景会改变数据耐久模型，届时本 ADR 的单机假设需重审（与 LB-07 SCRAM 的"多用户即强制"触发条件同源）。

## Alternatives Considered

### 方案 B：字面零兼容（schema 变更即弃旧数据）
- 优势：与 `docs/CLAUDE.md` 现有文本零冲突；实现最简单（不留迁移）。
- 否决理由：**alpha.9 已有真实用户数据**，B 等于每次升级清空用户工程——公开测试期直接自毁信任，且与已实现的迁移链、降级拒绝逻辑正面冲突。不可接受。

### 方案 C：alpha 期用 B、beta.1 起用 A
- 优势：表面上"渐进过渡"。
- 否决理由：alpha.9 **事实上已在用 A**（迁移链已上线、已有存量数据），C 是伪命题；徒增"哪个版本用哪套规则"的复杂度，无任何收益。

## Revisit Triggers

- 需要支持**降级**（新版库被旧版应用打开）时。
- 某条迁移被证明**不可逆地破坏数据**、需引入备份 / 回滚语义时（与 LB-22 备份还原联动）。
- 引入**多写入 / 同步 / 局域网**特性，单机数据耐久假设不再成立时。
- 至迟在 **beta.1 准入评审**时复核本 ADR 状态（proposed → accepted 是否已由 KPM 拍板）。
