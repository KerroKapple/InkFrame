// Schema v=7 — prompt_presets 表（项目级提示词预设库）。
//
// 真相源；无 SQL 文档镜像（v6 起不再落 .sql 镜像）。
// 生命周期：MigrationRunner 在 schema_version = 6 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 7。
//
// 动机：把 util/base_style_presets.dart 的硬编码前缀预设，扩成项目级、可命名、
// 可持久化的库（prompt/prefix/suffix/negative）。全 TEXT，无 JSONB、无资产。

const String kSchemaV7 = r'''
CREATE TABLE prompt_presets (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  UUID    NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name        TEXT    NOT NULL DEFAULT '',
  prompt      TEXT    NOT NULL DEFAULT '',
  prefix      TEXT    NOT NULL DEFAULT '',
  suffix      TEXT    NOT NULL DEFAULT '',
  negative    TEXT    NOT NULL DEFAULT '',
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at  TIMESTAMPTZ,
  CONSTRAINT chk_prompt_presets_name   CHECK (char_length(name) <= 200),
  CONSTRAINT chk_prompt_presets_prompt CHECK (char_length(prompt) <= 4096)
);

CREATE INDEX idx_prompt_presets_project_id ON prompt_presets(project_id);
CREATE INDEX idx_prompt_presets_deleted    ON prompt_presets(deleted_at) WHERE deleted_at IS NOT NULL;
''';
