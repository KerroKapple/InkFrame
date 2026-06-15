// 应用 schema 迁移全链——唯一真相源。
// DI（database.dart）与测试 harness（pg_test_harness.dart）共用，
// 保证新增迁移时两边自动同步，杜绝 harness 落后于生产链。
import '../schema/schema_v1.dart';
import '../schema/schema_v2.dart';
import '../schema/schema_v3.dart';
import 'migration_runner.dart';

const List<Migration> kAppMigrations = [
  Migration(version: 1, sql: kSchemaV1),
  Migration(version: 2, sql: kSchemaV2),
  Migration(version: 3, sql: kSchemaV3),
];
