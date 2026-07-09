# ADR-0001: 使用嵌入式 PostgreSQL 作为本地存储

- **Status**: accepted
- **Date**: 2026-04-15
- **Deciders**: P9 (Tech Lead)
- **Related**: PRD §3.2 / §21 / ARCHITECTURE §1 / DATABASE.md
- **Revised**: 2026-07-07（端口文件实际路径勘误——见文末修订记录）

---

## Context

InkFrame 是桌面单机应用（macOS + Windows），用户本地存储：

- **数据量**：单项目 100+ 节点、上万张图片路径、批量生成的 batch_results slot 表
- **关系复杂度**：8 张表、跨表 CHECK 约束、多组 ON DELETE 级联（§4.6.1 九宫格一致性、§4.5.1 孤儿 result 节点）
- **事务需求**：节点创建 + 连线 + Job 入队必须原子（避免悬空引用）
- **查询模式**：按画布筛选节点、按父 grid 聚合子 slot、按 job 状态分组

**约束：**

- 零运维：用户不安装 PG，双击 app 即用
- 跨平台：同一套代码在 macOS 和 Windows 上行为一致
- 可审计：Schema 迁移必须可追溯、可回滚（受 CLAUDE.md §"Zero Backward Compatibility"约束——仅指不写兼容代码，不等于放弃 migration）
- 线程安全：Flutter isolate + 长事务 + 并发写

**假设：**

- 单用户，本机 1 个数据库实例
- 数据量不会膨胀到云 DB 级（单用户项目数 < 100，总大小 < 10GB）

---

## Decision

**决定：** 采用 PostgreSQL 17.2 二进制嵌入分发（`resources/pg/{platform}/`），由 `PgController` 管理 `initdb / pg_ctl start/stop` 生命周期，强制绑定 `127.0.0.1`。

**理由：**

1. **关系完整性落在 DDL 里，不在应用层裸奔**——CHECK 约束 + ON DELETE 级联由数据库保证（§21.9 九宫格一致性、§4.5.1 孤儿 result）；换 SQLite 这些得在应用层重写一遍，而应用层 bug 就是一个用户项目数据损坏的路
2. **同一套 SQL 在 dev / CI / 生产完全一致**——避免 SQLite 子方言陷阱（部分 ALTER TABLE、JSONB 语义、并发 WAL 行为差异）
3. **团队熟悉度 / 工具链成熟**：`pg_dump` / `psql` / 迁移工具现成，migration_runner 扫 `schema/00X_*.sql` 递增即可
4. **JSONB + partial index** 直接支持 `type_config` 半结构化字段（节点参数、批量结果 metadata）

---

## Consequences

**好的：**

- Schema v=1 的 CHECK 矩阵测试 22 case 100% 通过（T2 DoD 证据）
- 本地开发与 CI 共享同一 `postgres:17-alpine`，无环境漂移
- JSONB 支撑 `parameters` / `type_config` 等演进字段，不必因新字段改表结构
- `pg_dump` 天然是备份/导出格式

**坏的 / 欠的债：**

- 包体增大：每平台 ~60MB 嵌入二进制（见 `scripts/pg/fetch-binaries.sh`）——这是用户一次性下载成本
- 冷启动付成本：首次 `initdb + pg_ctl start + schema_version=1` ≤ 8s（DoD 门槛）
- 进程管理复杂度：崩溃恢复要处理 `postmaster.pid` 三种状态（PgController 已覆盖）
- 需自己写 binary 分发、校验、升级路径；后续大版本升级（17→18）要 `pg_upgrade`，比 SQLite `ATTACH` 迁移重
- **TD-001**：`jobs.result_node_id` 缺 ON DELETE，schema v=2 修

**中性的（需观察）：**

- 磁盘占用：空库 ~50MB，100 项目预估 ~500MB——在用户可接受范围内，但需 §11.3 存储面板暴露
- 端口占用：127.0.0.1:随机高位端口，首次启动挑选后写 `~/InkFrame/.pg_port`

---

## Alternatives Considered

### 方案 A: SQLite（`sqflite_common_ffi`）

- **优势**：零进程、单文件、Flutter 生态默认、包体小
- **否决理由**：
  - CHECK 约束跨表不可行——九宫格一致性（`parent_grid_id IS NOT NULL` ⇒ `is_grid_generation = false AND grid_children = []`）必须写成触发器，复杂度远超 PG 的 `CHECK (...)`
  - 并发写只有单一 writer lock；批量生成（9 slot 并发写 batch_results）会阻塞
  - JSONB 替代是 `json1` 扩展，查询性能与 PG 的 GIN 索引不在一个量级
  - `pragma foreign_keys = ON` 必须每次连接显式开——易忘

### 方案 B: DuckDB

- **优势**：OLAP 友好、列存、嵌入式
- **否决理由**：
  - 主打分析型负载，我们是 OLTP（频繁小事务）
  - 生态尚未成熟（Dart 绑定质量）
  - 并发模型不适配多 Flutter isolate 写入

### 方案 C: 用户侧安装 PostgreSQL

- **优势**：无分发成本
- **否决理由**：消费级桌面产品不能要求用户装 PG；安装失败率会杀死激活

### 方案 D: Isar / Hive 等 NoSQL

- **优势**：Flutter 原生、快
- **否决理由**：无关系约束，8 张表的级联一致性要全靠应用代码保证——T2 测的 22 case 就会变成应用层的 22 个断言，每个都是 bug 温床

---

## Revisit Triggers

- 若 100 项目平均冷启动 > 5s，考虑 lazy init 或换 SQLite + app 层约束
- 若未来上云同步（跨设备），PG 嵌入不再合适，需要走服务端方案
- PostgreSQL 18 发布后评估升级路径
- 至迟在 v0.2.0 Sprint 启动前重审

---

## 修订记录

### 2026-07-07 — 端口文件实际路径勘误（不改决策）

Consequences 中性段所写端口文件 `~/InkFrame/.pg_port` 与实现不符：实际落地为
**`~/InkFrame/config/pg.port`**（`lib/storage/pg_controller.dart` 的 `portFile`，与其他
config 文件同目录）。决策本体（随机高位端口 + 强制 127.0.0.1）不变，仅路径以代码为准；
DATABASE.md「嵌入式 PG 运维」一节记载的即为正确路径。
