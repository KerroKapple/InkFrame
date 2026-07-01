// Schema v=6 — characters 表（项目级角色一致性）。
//
// 真相源；`lib/storage/schema/006_characters.sql` 是文档镜像（若存在）。
// 生命周期：MigrationRunner 在 schema_version = 5 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 6。
//
// 动机：项目级可复用「角色」——命名的参考图集合 + 描述，挂到 config 节点后
// 生成时按 provider 能力注入 refImagePaths（角色一致性，M2）。
// reference_image_paths 用 JSONB 数组（对齐 jobs.parameters / nodes.type_config
// 既有惯例，路径是不可查询的不透明串，无需 join 表）。
// project_id FK ON DELETE CASCADE：删项目连带清角色，与 canvases 一致。

const String kSchemaV6 = r'''
CREATE TABLE characters (
  id                    UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id            UUID    NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name                  TEXT    NOT NULL DEFAULT '',
  reference_image_paths JSONB   NOT NULL DEFAULT '[]'::jsonb,
  description           TEXT    NOT NULL DEFAULT '',
  sort_order            INTEGER NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at            TIMESTAMPTZ,
  CONSTRAINT chk_characters_name CHECK (char_length(name) <= 200),
  CONSTRAINT chk_characters_desc CHECK (char_length(description) <= 4096)
);

CREATE INDEX idx_characters_project_id ON characters(project_id);
CREATE INDEX idx_characters_deleted    ON characters(deleted_at) WHERE deleted_at IS NOT NULL;
''';
