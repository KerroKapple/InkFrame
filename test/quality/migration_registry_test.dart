// 迁移注册表完整性静态测试 —— 纯内存，不连库，无 @Tags(['pg'])。
// 固化 kAppMigrations 不变量：版本连续无缺口/无重复、每条 schema_vN 已注册并对应。
// 与 @Tags(['pg']) 的 migration_chain_test.dart（断 DB schema_version）正交互补，
// 随 flutter test 全平台执行，防 “新增 schema_vN.dart 忘注册” 假绿。
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/schema/schema_v1.dart';
import 'package:inkframe/storage/schema/schema_v2.dart';
import 'package:inkframe/storage/schema/schema_v3.dart';
import 'package:inkframe/storage/schema/schema_v4.dart';
import 'package:inkframe/storage/schema/schema_v5.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('kAppMigrations registry integrity', () {
    test('注册表非空', () {
      expect(kAppMigrations, isNotEmpty);
    });

    test('版本序列从 1 起严格连续递增、无缺口、无重复', () {
      final versions = kAppMigrations.map((m) => m.version).toList();
      expect(
        versions,
        equals(List.generate(kAppMigrations.length, (i) => i + 1)),
        reason: '版本必须恒等于 [1, 2, ..., n]，实际为 $versions',
      );
    });

    test('每条迁移 sql 非空', () {
      for (final m in kAppMigrations) {
        expect(
          m.sql.trim(),
          isNotEmpty,
          reason: 'Migration v${m.version} has empty sql',
        );
      }
    });

    test('每条迁移 queryMode 均为 simple（多语句 DDL 必须 simple 协议）', () {
      expect(
        kAppMigrations.every((m) => m.queryMode == QueryMode.simple),
        isTrue,
        reason: '所有迁移必须使用 QueryMode.simple',
      );
    });

    test('每条迁移引用对应 kSchemaVN 常量（防忘注册假绿）', () {
      // 用 identical：均为顶层 const 字符串引用，能精确锁定注册表确实引用了
      // 对应 schema 常量，而非内容偶然相等的另一份字符串。
      final expected = <int, String>{
        1: kSchemaV1,
        2: kSchemaV2,
        3: kSchemaV3,
        4: kSchemaV4,
        5: kSchemaV5,
      };
      // 注册表条数必须与已知 schema 常量数一致——新增 schema_vN 必须同步建立映射。
      expect(
        kAppMigrations.length,
        equals(expected.length),
        reason: '注册表条数与已知 kSchemaVN 常量数不一致：'
            '新增 schema_vN.dart 后须同步注册并更新本测试映射',
      );
      for (final m in kAppMigrations) {
        final schema = expected[m.version];
        expect(
          schema,
          isNotNull,
          reason: 'Migration v${m.version} 无对应 kSchemaV${m.version} 映射',
        );
        expect(
          identical(m.sql, schema),
          isTrue,
          reason: 'Migration v${m.version}.sql 未引用 kSchemaV${m.version} 常量',
        );
      }
    });
  });
}
