// Schema v=1 — InkFrame 数据库首版 DDL。
//
// 真相源；`lib/storage/schema/001_init.sql` 是文档镜像，不参与运行时加载。
// 生命周期：MigrationRunner 在应用启动时检测 schema_version = 0（空库）→ 执行本 SQL 一次，
// 完成后 UPSERT schema_version.version = 1。零向后兼容；schema 升级走 002_*.sql。
//
// 字段/约束全量覆盖 PRD：
//   §21   projects / canvases / style_lanes / nodes / edges / jobs / batch_results / schema_version
//   §21.9 12 个字段长度 CHECK
//   §4.6.1 九宫格一致性 chk_grid_consistency
//   §4.5.1 孤儿 result：nodes.source_node_id ON DELETE SET NULL
//   §22.0 schema_version 单行约束 id=1
//
// 历史：v=1 里 jobs.result_node_id 按 PRD §21 字面量落 NO ACTION（无 ON DELETE）。
//   schema v=2（TD-001 修复）将其重建为 ON DELETE SET NULL，见 schema_v2.dart。
//   本文件保留 v=1 原貌，不做字面量追改——升级路径走 MigrationRunner。
//
// 注意：PG 17 gen_random_uuid() 内置于 pgcrypto。initdb 后 postgres 默认包含 pgcrypto 扩展，
// 若版本不带，需 CREATE EXTENSION IF NOT EXISTS pgcrypto——MigrationRunner 执行前插入。

const String kSchemaV1 = r'''
-- NOTE: pgcrypto（gen_random_uuid 来源）由上层 MigrationRunner 或测试 harness
-- 先行安装一次，避免并发 CREATE EXTENSION 竞争。schema_v1 DDL 本身假设扩展已存在。

-- =====================================================================
-- schema_version（单行表，约束 id=1）
-- =====================================================================
CREATE TABLE IF NOT EXISTS schema_version (
  id         INTEGER PRIMARY KEY DEFAULT 1
             CHECK (id = 1),
  version    INTEGER NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- projects
-- =====================================================================
CREATE TABLE projects (
  id               UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT    NOT NULL,
  cover_node_id    UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at       TIMESTAMPTZ,
  CONSTRAINT chk_projects_name CHECK (char_length(name) <= 200)
);

CREATE INDEX idx_projects_deleted ON projects(deleted_at) WHERE deleted_at IS NOT NULL;

-- =====================================================================
-- canvases
-- =====================================================================
CREATE TABLE canvases (
  id                 UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id         UUID    NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name               TEXT    NOT NULL,
  base_style_prefix  TEXT    NOT NULL DEFAULT '',
  base_style_suffix  TEXT    NOT NULL DEFAULT '',
  viewport_x         REAL    NOT NULL DEFAULT 0.0,
  viewport_y         REAL    NOT NULL DEFAULT 0.0,
  viewport_scale     REAL    NOT NULL DEFAULT 1.0,
  default_node_width REAL    NOT NULL DEFAULT 240.0,
  lane_direction     TEXT    NOT NULL DEFAULT 'horizontal'
                     CHECK (lane_direction IN ('horizontal','vertical')),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at         TIMESTAMPTZ,
  CONSTRAINT chk_canvases_name CHECK (char_length(name) <= 200),
  CONSTRAINT chk_base_style_len CHECK (
    char_length(base_style_prefix) <= 4096
    AND char_length(base_style_suffix) <= 4096
  )
);

CREATE INDEX idx_canvases_project_id ON canvases(project_id);
CREATE INDEX idx_canvases_deleted ON canvases(deleted_at) WHERE deleted_at IS NOT NULL;

-- =====================================================================
-- style_lanes
-- =====================================================================
CREATE TABLE style_lanes (
  id            UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  canvas_id     UUID    NOT NULL REFERENCES canvases(id) ON DELETE CASCADE,
  label         TEXT    NOT NULL DEFAULT '',
  style_prompt  TEXT    NOT NULL DEFAULT '',
  sort_order    INTEGER NOT NULL DEFAULT 0,
  tint_color    TEXT,
  size          REAL    NOT NULL DEFAULT 400.0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ,
  CONSTRAINT chk_lane_label_len  CHECK (char_length(label) <= 100),
  CONSTRAINT chk_lane_prompt_len CHECK (char_length(style_prompt) <= 4096)
);

CREATE INDEX idx_style_lanes_canvas_id ON style_lanes(canvas_id);
CREATE INDEX idx_style_lanes_deleted   ON style_lanes(deleted_at) WHERE deleted_at IS NOT NULL;

-- =====================================================================
-- nodes
-- =====================================================================
CREATE TABLE nodes (
  id             UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  canvas_id      UUID    NOT NULL REFERENCES canvases(id) ON DELETE CASCADE,
  type           TEXT    NOT NULL
                 CHECK (type IN ('image','video','text','shot')),
  label          TEXT    NOT NULL DEFAULT '',
  node_role      TEXT    NOT NULL DEFAULT 'config'
                 CHECK (node_role IN ('config','result')),
  status         TEXT    NOT NULL DEFAULT 'idle'
                 CHECK (status IN ('idle','uploading','generating',
                                   'success','error','cancelled')),
  source_node_id UUID    REFERENCES nodes(id) ON DELETE SET NULL,
  position_x     REAL    NOT NULL DEFAULT 0.0,
  position_y     REAL    NOT NULL DEFAULT 0.0,
  width          REAL    NOT NULL DEFAULT 240.0,
  height         REAL    NOT NULL DEFAULT 240.0,
  z_index        INTEGER NOT NULL DEFAULT 0,
  lane_id        UUID    REFERENCES style_lanes(id) ON DELETE SET NULL,
  type_config    JSONB   NOT NULL DEFAULT '{}'::jsonb,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at     TIMESTAMPTZ,
  CONSTRAINT chk_node_label_len CHECK (char_length(label) <= 200),
  CONSTRAINT chk_grid_consistency CHECK (
    (type_config->>'parent_grid_id' IS NULL)
    OR (
      (type_config->>'is_grid_generation')::bool = false
      AND jsonb_array_length(
        COALESCE(type_config->'grid_children','[]'::jsonb)
      ) = 0
    )
  )
);

CREATE INDEX idx_nodes_canvas_id  ON nodes(canvas_id);
CREATE INDEX idx_nodes_source     ON nodes(source_node_id);
CREATE INDEX idx_nodes_lane       ON nodes(lane_id);
CREATE INDEX idx_nodes_deleted    ON nodes(deleted_at) WHERE deleted_at IS NOT NULL;

-- =====================================================================
-- edges
-- =====================================================================
CREATE TABLE edges (
  id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  canvas_id       UUID    NOT NULL REFERENCES canvases(id) ON DELETE CASCADE,
  source_node_id  UUID    NOT NULL REFERENCES nodes(id)    ON DELETE CASCADE,
  target_node_id  UUID    NOT NULL REFERENCES nodes(id)    ON DELETE CASCADE,
  edge_type       TEXT    NOT NULL
                  CHECK (edge_type IN ('data','narrative','generation_source')),
  role            TEXT    NOT NULL DEFAULT 'reference'
                  CHECK (role IN ('reference','first_frame','last_frame')),
  sort_order      INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ,
  UNIQUE (source_node_id, target_node_id, edge_type)
);

CREATE INDEX idx_edges_canvas_id ON edges(canvas_id);
CREATE INDEX idx_edges_source    ON edges(source_node_id);
CREATE INDEX idx_edges_target    ON edges(target_node_id);
CREATE INDEX idx_edges_deleted   ON edges(deleted_at) WHERE deleted_at IS NOT NULL;

-- =====================================================================
-- jobs
-- =====================================================================
-- 注意：result_node_id 在 v=1 落 NO ACTION（无 ON DELETE 子句）。
-- v=2（TD-001 修复）改为 ON DELETE SET NULL，见 schema_v2.dart。
CREATE TABLE jobs (
  id             UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  canvas_id      UUID    NOT NULL REFERENCES canvases(id) ON DELETE CASCADE,
  source_node_id UUID    NOT NULL REFERENCES nodes(id)    ON DELETE CASCADE,
  result_node_id UUID    REFERENCES nodes(id),
  provider_id    TEXT    NOT NULL,
  job_type       TEXT    NOT NULL
                 CHECK (job_type IN ('image','video')),
  status         TEXT    NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','submitted','polling',
                                   'success','error','cancelled','timeout')),
  remote_task_id TEXT,
  full_prompt    TEXT    NOT NULL,
  user_prompt    TEXT    NOT NULL,
  parameters     JSONB   NOT NULL DEFAULT '{}'::jsonb,
  batch_size     INTEGER NOT NULL DEFAULT 1,
  progress       REAL    NOT NULL DEFAULT 0.0
                 CHECK (progress BETWEEN 0.0 AND 1.0),
  error_code     TEXT,
  error_message  TEXT,
  retry_count    INTEGER NOT NULL DEFAULT 0,
  max_retries    INTEGER NOT NULL DEFAULT 3,
  next_poll_at   TIMESTAMPTZ,
  timeout_at     TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  submitted_at   TIMESTAMPTZ,
  completed_at   TIMESTAMPTZ,
  CONSTRAINT chk_job_prompt_len CHECK (char_length(full_prompt) <= 131072)
);

CREATE INDEX idx_jobs_status    ON jobs(status);
CREATE INDEX idx_jobs_canvas_id ON jobs(canvas_id);
CREATE INDEX idx_jobs_next_poll ON jobs(next_poll_at) WHERE status = 'polling';
CREATE INDEX idx_jobs_completed ON jobs(completed_at) WHERE completed_at IS NOT NULL;

-- =====================================================================
-- batch_results
-- =====================================================================
CREATE TABLE batch_results (
  id               UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  node_id          UUID    NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  job_id           UUID    NOT NULL REFERENCES jobs(id)  ON DELETE CASCADE,
  slot_index       INTEGER NOT NULL,
  status           TEXT    NOT NULL
                   CHECK (status IN ('generating','success','error','cancelled')),
  output_url       TEXT,
  thumbnail_url    TEXT,
  width            INTEGER,
  height           INTEGER,
  file_size_bytes  BIGINT,
  seed             BIGINT,
  error_code       TEXT,
  error_message    TEXT,
  promoted         BOOLEAN NOT NULL DEFAULT false,
  promoted_node_id UUID    REFERENCES nodes(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at     TIMESTAMPTZ,
  UNIQUE (node_id, slot_index)
);

CREATE INDEX idx_batch_results_node_id ON batch_results(node_id);
CREATE INDEX idx_batch_results_job_id  ON batch_results(job_id);

-- =====================================================================
-- schema_version 写入首版
-- =====================================================================
INSERT INTO schema_version (id, version) VALUES (1, 1)
ON CONFLICT (id) DO UPDATE
  SET version    = EXCLUDED.version,
      applied_at = now();
''';
