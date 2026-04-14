# InkFrame Database Reference

> 目标：一处阅读就能还原 DB 全景。PRD §21 / §21.9 / §22.0 / §22.1 / §4.5.1 / §4.6.1 的运维视角映射。

## Schema 版本管理

- 首版 `schema_version.version = 1`
- 真相源：`lib/storage/schema/schema_v1.dart`
- 文档镜像：`lib/storage/schema/001_init.sql`（不被运行时加载）
- `MigrationRunner`（`lib/storage/migrations/migration_runner.dart`）按版本扫描 `002_*.sql`、`003_*.sql`……
- 数据库版本 > 应用期望 → 抛 `SchemaMigrationError`，提示升级应用
- 数据库版本 < 应用期望 → 按序执行，每步单独事务，v ≥ 2 由 runner 统一 UPSERT `schema_version`

`CREATE EXTENSION IF NOT EXISTS pgcrypto` 在 `pgMigratedConnectionProvider` 里独立执行，DDL 本身不含扩展语句——并发情形下减少 `23505 duplicate_object` 冲突。

## 表关系图

```mermaid
erDiagram
  projects ||--o{ canvases : "ON DELETE CASCADE"
  canvases ||--o{ nodes : "ON DELETE CASCADE"
  canvases ||--o{ edges : "ON DELETE CASCADE"
  canvases ||--o{ style_lanes : "ON DELETE CASCADE"
  canvases ||--o{ jobs : "ON DELETE CASCADE"
  nodes ||--o{ edges : "source/target ON DELETE CASCADE"
  nodes }o--o| nodes : "source_node_id ON DELETE SET NULL"
  style_lanes }o--o{ nodes : "lane_id ON DELETE SET NULL"
  nodes ||--o{ jobs : "source_node_id ON DELETE CASCADE"
  jobs ||--o{ batch_results : "ON DELETE CASCADE"
  nodes ||--o{ batch_results : "ON DELETE CASCADE"
  nodes }o--o| batch_results : "promoted_node_id ON DELETE SET NULL"
```

## ON DELETE 策略矩阵

| 父表 | 子表 | 列 | 策略 | 备注 |
|------|------|----|------|------|
| projects | canvases | project_id | CASCADE | 项目删除级联删画布 |
| canvases | nodes | canvas_id | CASCADE |  |
| canvases | edges | canvas_id | CASCADE |  |
| canvases | style_lanes | canvas_id | CASCADE |  |
| canvases | jobs | canvas_id | CASCADE |  |
| nodes | edges | source_node_id | CASCADE | 节点级连线双向清 |
| nodes | edges | target_node_id | CASCADE |  |
| nodes | nodes | source_node_id | SET NULL | §4.5.1 孤儿 result 节点 |
| style_lanes | nodes | lane_id | SET NULL |  |
| nodes | jobs | source_node_id | CASCADE |  |
| nodes | jobs | result_node_id | **NO ACTION** | **TD-001** — v=2 应改为 SET NULL |
| jobs | batch_results | job_id | CASCADE |  |
| nodes | batch_results | node_id | CASCADE |  |
| nodes | batch_results | promoted_node_id | SET NULL |  |

## CHECK 约束清单

### 枚举白名单

| 表 | 列 | 允许值 |
|----|----|--------|
| nodes | type | image / video / text / shot（shot 为 P1 预留） |
| nodes | node_role | config / result |
| nodes | status | idle / uploading / generating / success / error / cancelled |
| edges | edge_type | data / narrative / generation_source |
| edges | role | reference / first_frame / last_frame |
| jobs | job_type | image / video |
| jobs | status | pending / submitted / polling / success / error / cancelled / timeout |
| batch_results | status | generating / success / error / cancelled |
| canvases | lane_direction | horizontal / vertical |
| schema_version | id | `CHECK (id = 1)` — 单行约束 |

### 字段长度约束（PRD §21.9）

| 表.字段 | DB 上限 | 应用层上限 |
|---------|---------|-----------|
| projects.name | 200 | 同 |
| canvases.name | 200 | 同 |
| canvases.base_style_prefix | 4096 | 同 |
| canvases.base_style_suffix | 4096 | 同 |
| style_lanes.label | 100 | 同 |
| style_lanes.style_prompt | 4096 | 同 |
| nodes.label | 200 | 同 |
| jobs.full_prompt | 131072 | 128KB 硬截断 |
| nodes.type_config.prompt | — | 32KB |
| nodes.type_config.negative_prompt | — | 8KB |
| nodes.type_config.text (type=text) | — | 64KB |
| jobs.error_message | — | 2KB |

JSONB 内字段长度不落 DB CHECK（路径查询开销大），由 freezed + assert 保障。

### 其他

| 约束 | 含义 |
|------|------|
| jobs.progress CHECK BETWEEN 0.0 AND 1.0 | 进度必须在 [0,1] |
| nodes chk_grid_consistency | `parent_grid_id IS NOT NULL` 蕴含 `is_grid_generation=false` 且 `grid_children=[]`（PRD §4.6.1） |
| edges UNIQUE(source_node_id, target_node_id, edge_type) | 同向同类型连线唯一 |
| batch_results UNIQUE(node_id, slot_index) | 同 batch 节点内 slot 不重复 |

## 索引

| 索引 | 表 | 列 | 类型 |
|------|----|-----|------|
| idx_canvases_project_id | canvases | project_id | 常规 |
| idx_canvases_deleted | canvases | deleted_at | 部分（WHERE deleted_at IS NOT NULL） |
| idx_style_lanes_canvas_id | style_lanes | canvas_id | 常规 |
| idx_style_lanes_deleted | style_lanes | deleted_at | 部分 |
| idx_nodes_canvas_id | nodes | canvas_id | 常规 |
| idx_nodes_source | nodes | source_node_id | 常规 |
| idx_nodes_lane | nodes | lane_id | 常规 |
| idx_nodes_deleted | nodes | deleted_at | 部分 |
| idx_edges_canvas_id / source / target / deleted | edges | canvas_id / source_node_id / target_node_id / deleted_at | 常规 / 常规 / 常规 / 部分 |
| idx_jobs_status | jobs | status | 常规 |
| idx_jobs_canvas_id | jobs | canvas_id | 常规 |
| idx_jobs_next_poll | jobs | next_poll_at | 部分（WHERE status='polling'） |
| idx_jobs_completed | jobs | completed_at | 部分（WHERE completed_at IS NOT NULL） |
| idx_batch_results_node_id / job_id | batch_results | node_id / job_id | 常规 |
| idx_projects_deleted | projects | deleted_at | 部分 |

## updated_at 维护

PRD §21 硬规则：**应用层维护，禁止 DB trigger**。

- `BaseRepository.withUpdatedAt(patch)` 统一注入时间戳
- `BaseRepository.buildUpdate(table, id, patch)` 自动拼 `updated_at = @p_updated_at`
- CI `scripts/hooks/check-updated-at.sh` 扫描 `lib/storage/*.dart`，`UPDATE <table> SET` 若缺少 `updated_at` 即 exit 1
- 白名单：`edges` / `jobs` / `batch_results` / `schema_version` 表无 `updated_at` 列，天然豁免

## Retention 策略（PRD §21）

Jobs 表的 30 天保留 + 单 canvas 500 条上限：

- 启动时异步执行，不阻塞主流程
- 排除"孤儿 result 节点依赖"的 job（§4.5.1 要求 jobs 是真相源）
- 实现：`PostgresJobRepository.purgeExpired` + `purgePerCanvasCap`

## Migration 命名规范

```
lib/storage/schema/001_init.sql         # v=1 文档镜像（运行时不加载）
lib/storage/migrations/002_xxx.sql      # v=2 首个增量
lib/storage/migrations/003_yyy.sql
```

文件名格式：`<三位版本号>_<短描述>.sql`，版本号必须单调递增无缺口。

## 嵌入式 PG 运维（PRD §22.1）

- 版本锁：`scripts/pg/pg-version.txt` = 17.2
- 启动目录：`~/InkFrame/database/`（PGDATA）
- 端口：`ServerSocket.bind(0)` 派随机端口，写入 `~/InkFrame/config/pg.port`
- 崩溃恢复：`postmaster.pid` 存在但进程死 → 删 pid 文件后重启
- 强制绑定 `127.0.0.1`，`unix_socket_directories=` 空（规避 socket 目录权限）
- 数据目录搬迁：见 PRD §12.6 八步流程（暂停 → stop → 原子 rename → 重启）

## 技术债

见 `docs/internal/tech-debt.md`。T2 新增：
- **TD-001**: `jobs.result_node_id` 缺 `ON DELETE SET NULL`
