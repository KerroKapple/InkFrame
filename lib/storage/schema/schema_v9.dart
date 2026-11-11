// Schema v=9 — 导演会话与事件日志（A2，ADR-0015）。
//
// 真相源；无 SQL 文档镜像（v6 起不再落 .sql 镜像）。
// 生命周期：MigrationRunner 在 schema_version = 8 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 9。
//
// director_sessions：一次导演会话（目前 = 一次 AI 拆分镜导入），绑定项目与画布；
//   content_language 是 BCP-47 码（空串 = 还没识别），setting 是会话设定（JSONB）。
// director_events：会话内只追加的事件日志，是导演一切状态的唯一事实源。
//   seq 会话内从 1 连续递增（唯一索引兜底，分配在仓储里锁会话行完成）；
//   parent_seq = 本事件接在哪个事件之后（NULL = 接在空根上），分叉即两个事件同父。
//   无 updated_at / deleted_at：事件不改不删，随会话软删隐藏、随会话硬删级联。
// 两表都是新表，旧项目包里没有它们的行，导入不受 BOARD 188 纪律影响。
const String kSchemaV9 = r'''
CREATE TABLE director_sessions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id       UUID        NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  canvas_id        UUID        NOT NULL REFERENCES canvases(id) ON DELETE CASCADE,
  content_language TEXT        NOT NULL DEFAULT '',
  setting          JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at       TIMESTAMPTZ,
  CONSTRAINT chk_director_sessions_language CHECK (char_length(content_language) <= 35)
);

CREATE INDEX idx_director_sessions_project_id ON director_sessions(project_id);
CREATE INDEX idx_director_sessions_canvas_id  ON director_sessions(canvas_id);
CREATE INDEX idx_director_sessions_deleted    ON director_sessions(deleted_at) WHERE deleted_at IS NOT NULL;

CREATE TABLE director_events (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  UUID        NOT NULL REFERENCES director_sessions(id) ON DELETE CASCADE,
  seq         INTEGER     NOT NULL,
  kind        TEXT        NOT NULL,
  parent_seq  INTEGER,
  payload     JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_director_events_seq    CHECK (seq >= 1),
  CONSTRAINT chk_director_events_kind   CHECK (char_length(kind) BETWEEN 1 AND 64),
  CONSTRAINT chk_director_events_parent CHECK (parent_seq IS NULL OR (parent_seq >= 1 AND parent_seq < seq))
);

CREATE UNIQUE INDEX uq_director_events_session_seq ON director_events(session_id, seq);
''';
