# ADR-0012: 单线前向迁移是用户数据的唯一升级路径

- **Status**: accepted
- **Date**: 2026-07-08
- **Deciders**: 仓库维护者（单人项目）；采纳 MASTERPLAN §9 D-4 推荐项 A，经一轮对抗式复审勘正事实后拍板
- **Related**: MASTERPLAN §9 D-4（= U7 = QG-5）· ADR-0001（嵌入式 PostgreSQL，§"仅指不写兼容代码，不等于放弃 migration"）· PRD §22.0（`schema_version` 规则）· LB-07（PG trust→SCRAM）· LB-11/LB-12（项目导出/导入）· QG-4/QG-5（升级演练）· `docs/CLAUDE.md` › Zero Backward Compatibility · `CONTRIBUTING.md` · `docs/EXECUTION-PLAYBOOK.md` 不变量 #11

---

## Context

InkFrame 存在一处**治理层面的矛盾**，卡住 beta 前的多条数据安全线（MASTERPLAN §9 列为 D-4，"beta 前必须拍；不拍则每次 schema PR 都在灰区"）：

1. **`docs/CLAUDE.md` 的铁律文本说"不迁移"**：
   > NO migration scripts for old data formats · If a schema changes, the old version is dead. Period.

   全局规则同调，但留了口子——"No compatibility, migration, or legacy support **unless explicitly requested**"。

2. **但代码实际在做前向迁移**：
   - `lib/storage/migrations/migration_runner.dart` + `app_migrations.dart` 实现了一条 **单调递增、原子（DDL + `schema_version` UPSERT 同一事务，ME-31）、有缺口校验、显式拒绝降级（`SchemaDowngradeError`）** 的前向迁移链，来源是 PRD §22.0。
   - `schema_version` 单行表（`CHECK(id = 1)`）记录库版本：库版本 < 应用期望 → 顺序补跑缺失迁移；> 期望 → 抛"请升级应用，不支持降级"。
   - **勘正（复审）**：`v0.1.0-alpha.9`（2026-04）分发的是这套**迁移机制**，当时 schema 只到 **v2**（仓库仅 `schema_v1.dart`/`schema_v2.dart`，`app_migrations.dart` 尚未拆出，迁移在 `database.dart` 内联组装）；`schema_v6/v7` 是 2026-07-01/02 才加的。**迁移链现已长到 v7**——一个 alpha.9 用户的库停在 v2，升级即需 v2→v7 前向迁移，正是本决策要保障的场景。

3. **这不是新观点**：ADR-0001（2026-04-15，accepted）早已把 Zero-BC 解读为"**仅指不写兼容代码，不等于放弃 migration**"。真正与实现打架的只是 `docs/CLAUDE.md` 那句"NO migration scripts / old version dead. Period."的**孤立措辞**。

4. **不拍板的下游代价**——只要政策悬空，以下卡全部在灰区：LB-07（存量库能否存活而非清库）、LB-12（导入包 manifest 版本策略，全计划最大风险卡）、QG-4/QG-5（升级演练是否进 beta 门槛）、以及**每一个 schema 变更 PR**（加迁移 vs 改旧迁移 vs 弃数据无统一裁决）。

> 数据存在性说明：应用**零遥测**（release-engineering §"Telemetry"），无法观测用户数据，但 alpha.9 已**公开分发**，因此必须**假设真实用户数据在外**。本 ADR 只解决"用户持久化数据跨版本如何演进"这一个问题；**不**动代码 / API 的兼容策略。

## Decision

**决定（MASTERPLAN §9 D-4 推荐项 A）：把"零向后兼容"精确界定——`单线前向迁移（single-line forward migration）是用户持久化数据（嵌入式 PostgreSQL 工作区）跨应用版本的唯一、且受支持的升级路径`。**

边界精确化：

- **Zero-BC 继续禁止**：保留旧数据格式的并行解析路径、为"以防万一"保留的弃用 API / 僵尸代码、旧格式回退分支、**降级**（旧版应用打开新版库——已由 `SchemaDowngradeError` 硬拒）。
- **Zero-BC 不等于销毁用户数据**：schema 变更**不得**删库 / 重置用户工作区；库通过前向迁移链推进到当前版本，用户数据**必须存活**。
- **唯一升级路径**：任何 schema 变更 = **追加一条编号连续的新前向迁移**；**已发布的迁移不可变**。
  > 诚实注记：不可变是**从本 ADR 起新立的纪律**，alpha 期并未执行——`schema_v1.dart` 在 alpha.9 之后仍被语义性修改过（提交 `afeb555` 把首版 DDL 里的 `schema_version` 写入块删除，改由 runner 统一写，ME-31）。这类"重基线"latitude 到此为止。
- **本 ADR 即那次"explicitly requested"**：全局铁律留的口子，在**存储层**由本决策显式行使；与 ADR-0001 早已确立的解读一致。

**理由（底层逻辑）：**

1. **公开分发 + 零遥测 ⇒ 不可逆**。alpha.9 一旦公开分发且无遥测，"清库重来 / 重基线"从那一版起就事实上下不了牌——无法确认没有用户数据，也没有导出逃生舱（LB-11/12 尚是未来功能）。字面 B 从 alpha.9 起就已出局。
2. **代码 / PRD / ADR-0001 本就是 A**。迁移机制、`schema_version`、降级拒绝均已实现并测试；ADR-0001 早已声明 Zero-BC"不等于放弃 migration"。本决策是让 `docs/CLAUDE.md` 的孤立措辞追认既定解读与实现。
3. **一条规则解四处灰区**。A 一拍，LB-07（合法化"存量库存活、不清库"）、LB-12 导入版本策略、QG-4 升级演练门槛、每个 schema PR 的"加迁移、不改旧迁移"约束，全部有确定答案。

## Consequences

**好的：**
- 解锁 LB-07 / LB-12 / QG-4 / QG-5，beta 数据安全线可开工。
- 每个 schema PR 有确定规程：追加编号连续的前向迁移 + roundtrip / 升级测试；不再编辑已发布迁移。
- `docs/CLAUDE.md`、`CONTRIBUTING.md`、`EXECUTION-PLAYBOOK.md` 与实现对齐，消除"文档说不迁移、代码在迁移"的认知分裂。

**坏的 / 欠的债：**
- **一条有缺陷的已发布迁移不可恢复**（本策略制造的最锋利风险）：既已发布，就**不能降级**（`SchemaDowngradeError`）、**不能改**（不可变）、且在 LB-22 备份还原落地前**不能从备份回滚**——只能靠后续 `v_next` 修正；若它损坏 / 打死工作区，用户会卡住。**缓解（硬依赖）**：把"带数据的升级测试（alpha.9 v2 库 → 当前版本）"设为 schema PR 的**合并门禁**；LB-22 备份还原优先级前置。
- `kAppMigrations` 只增不减，迁移列表长期单调增长；旧迁移永久保留（历史包袱换数据安全，值得）。
- **文档对齐清单（本 PR 一并处理）**：`docs/CLAUDE.md`（已改）、`CONTRIBUTING.md:172`（"不许做的"里删"为老 schema 留 migration"）+ `CONTRIBUTING.md:227`（迁移机制描述勘正：runner 不扫 `.sql` 文件）、`docs/EXECUTION-PLAYBOOK.md` 不变量 #11（"schema 改版旧格式即死 / 待拍板"→ 改为本 carve-out 并指向本 ADR）、`MASTERPLAN §9`（D-4 标记已拍）。遗留：`ARCHITECTURE-SURVEY.md` / `AUDIT-REPORT.md` / `PROGRESS.md` 等仍写"v1→v5"的**过期快照**属同一"文档对齐"目标，非本 PR 阻塞项，随后清。

**中性的（需持续观察）：**
- 降级仍显式不支持（`SchemaDowngradeError`）。与 ADR-0001 的"迁移可回滚"不冲突——那里的"可回滚"指**单迁移失败时的事务回滚**（runner 用 `runTx` 单事务包裹，失败不推进版本），**不是** schema 降级。二者是不同维度。
- 多写入 / 同步 / 局域网 场景会改变数据耐久模型，届时本 ADR 的单机假设需重审（与 LB-07 SCRAM 的"多用户即强制"触发条件同源）。

## Alternatives Considered

### 方案 B：字面零兼容（schema 变更即弃旧数据）
- 优势：与 `docs/CLAUDE.md` 原措辞零冲突；实现最简单（不留迁移）。
- 否决理由：alpha.9 已公开分发且零遥测，无法证明没有用户数据，又无导出逃生舱（LB-11/12 未落地）——B 从 alpha.9 起即等于纯数据丢失，且与已实现的迁移链、降级拒绝逻辑正面冲突。不可接受。

### 方案 C：alpha 期用 B、beta.1 起用 A
- steel-man：把"不可变迁移"承诺推迟到 beta，让 alpha 保留重基线 latitude。**仓库历史确实更接近 C**——`schema_v1` 在 alpha.9 后被改过（`afeb555`），"不可变"当时并未执行，所以"alpha.9 已在用完整 A"并不成立。
- 否决理由：C 的成立前提是"alpha 有一个可安全 B / 重基线的窗口"，但该窗口在 **alpha.9 公开分发**那刻就关了（公开物 + 零遥测 = 重基线下不了牌）。真正该做的不是"alpha 松、beta 紧"，而是**从现在起收紧不可变纪律**、承认它是新承诺——这正是本 ADR 采用 A 的方式。C 徒增"哪版用哪套规则"的复杂度而无收益。

## Revisit Triggers

- 需要支持**降级**（新版库被旧版应用打开）时。
- 某条已发布迁移被证明**不可逆地破坏数据**、需引入备份 / 回滚语义时（与 LB-22 备份还原联动——本 ADR 已将其列为硬依赖）。
- 引入**多写入 / 同步 / 局域网**特性，单机数据耐久假设不再成立时。
