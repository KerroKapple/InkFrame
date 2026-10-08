// Schema v=8 — projects.delivery_settings（P6 交付设置按项目持久化）。
//
// 真相源；无 SQL 文档镜像（v6 起不再落 .sql 镜像）。
// 生命周期：MigrationRunner 在 schema_version = 7 时于单事务内执行本 SQL，
// 并在同事务 UPSERT schema_version.version = 8。
//
// 为什么加一列而不是建一张表：要存的只有六项标量（目标软件 / 时间码起点 /
// 四个开关），且与项目一对一、随项目删除而消失。建表要多一条 FK、一个索引、
// 一套仓储，换来的只是同一份数据换个地方放。
//
// 为什么是 JSONB 而不是六个列：交付设置还会随 P6 后续切片长（导出历史、版本号
// 都排在后面），一次加一列要一条迁移；JSONB 下加字段只改应用层的容错解析，
// 不再动 schema。与 nodes.type_config 是同一套路子。
//
// `NOT NULL DEFAULT '{}'`：存量项目读出来是空对象，`DeliverySettings.fromMap`
// 对空对象返回全默认——不需要回填，也不会有 null 分支。
const String kSchemaV8 = r'''
ALTER TABLE projects
  ADD COLUMN delivery_settings JSONB NOT NULL DEFAULT '{}'::jsonb;
''';
