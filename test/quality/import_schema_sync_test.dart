// 项目包导入链上「必须跟 schema 同步的清单」，逐一对着 schema 钉死。
//
// 由来（2026-10-13）：v8 给 projects 加了 `delivery_settings`，导入链上有两份清单
// 都没人同步——`import_remapper` 的列白名单、`PostgresProjectImportWriter` 的 JSONB
// 列表。导出是 `SELECT *`，带着这一列；导入把它当未知列丢掉。**导出再导入一个
// 项目，交付设置静默清零**，什么都不报。
//
// 根因不是那一次漏改，而是「加一列时有好几份清单要手动同步」这件事本身没有闸。
// 本文件三组：
//   A  每张表的导入白名单 == columns.dart 里该表的全部列（减去写明理由的豁免）
//   B  写入端的 JSONB 列表 == 迁移里声明为 JSONB、且至今没被删掉的全部列
//   C  迁移纪律（BOARD 188）：v2 起不许出现会让**旧项目包**导入必炸的改动
//
// 口径限制：全是逐行 / 逐语句的正则，不是 Dart 或 SQL 解析器。抓得到本仓现有的
// 全部写法；把一条语句拆成多段字符串拼接、或把列名放进变量再展开，抓不到。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _columnsFile = 'lib/core/db/columns.dart';
const String _remapperFile = 'lib/services/import/import_remapper.dart';
const String _writerFile =
    'lib/storage/repositories/postgres_project_import_writer.dart';

bool _isComment(String line) {
  final String t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('--') || t.startsWith('*');
}

String _stripComments(String src) =>
    src.split(RegExp(r'\r?\n')).where((String l) => !_isComment(l)).join('\n');

/// columns.dart 里 [cls] 的全部常量：常量名 → SQL 列名。
Map<String, String> _columnsOf(String cls) {
  final String src = File(_columnsFile).readAsStringSync();
  final RegExpMatch? m = RegExp(
    'class\\s+$cls\\s*\\{([\\s\\S]*?)\\n\\}',
  ).firstMatch(src);
  expect(m, isNotNull, reason: 'columns.dart 里没找到 $cls');
  return <String, String>{
    for (final RegExpMatch c in RegExp(r"static const (\w+)\s*=\s*'([^']+)'")
        .allMatches(_stripComments(m!.group(1)!)))
      c.group(1)!: c.group(2)!,
  };
}

/// [file] 里名为 [setName] 的 `Set<String>` 字面量引用到的 `XxxCol.yyy`（去注释）。
Set<String> _setMembers(String file, String setName) {
  final String src = File(file).readAsStringSync();
  final RegExpMatch? m = RegExp(
    '\\b$setName\\s*=\\s*(?:<String>)?\\{([\\s\\S]*?)\\};',
  ).firstMatch(src);
  expect(m, isNotNull, reason: '$file 里没找到 $setName');
  return <String>{
    for (final RegExpMatch r in RegExp(r'\b(\w+Col)\.(\w+)\b')
        .allMatches(_stripComments(m!.group(1)!)))
      '${r.group(1)}.${r.group(2)}',
  };
}

final RegExp _versionPattern = RegExp(r'schema_v(\d+)\.dart$');

int _versionOf(File f) =>
    int.parse(_versionPattern.firstMatch(f.path.replaceAll(r'\', '/'))!.group(1)!);

/// schema_vN.dart，按 N 升序。
List<File> _migrations() => Directory('lib/storage/schema')
    .listSync()
    .whereType<File>()
    .where((File f) => _versionPattern.hasMatch(f.path.replaceAll(r'\', '/')))
    .toList()
  ..sort((File a, File b) => _versionOf(a).compareTo(_versionOf(b)));

// ---- A ----

/// 导入白名单 Set → 它对应的列类。
const Map<String, String> _whitelistOf = <String, String>{
  '_projectCols': 'ProjectCol',
  '_canvasCols': 'CanvasCol',
  '_laneCols': 'StyleLaneCol',
  '_nodeCols': 'NodeCol',
  '_edgeCols': 'EdgeCol',
  '_characterCols': 'CharacterCol',
  '_presetCols': 'PromptPresetCol',
  '_jobCols': 'JobCol',
  '_batchCols': 'BatchResultCol',
};

/// 列类里刻意**不**进导入白名单的常量。每条都要说清为什么。
const Map<String, String> _notImported = <String, String>{
  'NodeCol.projectId': 'join 派生列：nodes 表没有这一列，值来自 JOIN canvases',
};

/// columns.dart 里不对应项目包中任何一张表的类。
const Map<String, String> _notTables = <String, String>{
  'SchemaVersionCol': 'schema_version 是库级元数据，不随项目导出',
  'CommonCol': '跨表公共列名的辅助常量，不是一张表',
};

void main() {
  group('A 导入白名单 == 该表全部列', () {
    for (final MapEntry<String, String> e in _whitelistOf.entries) {
      test('${e.key} 覆盖 ${e.value} 的全部列', () {
        final Set<String> all = <String>{
          for (final String k in _columnsOf(e.value).keys) '${e.value}.$k',
        };
        final Set<String> expected = all.difference(_notImported.keys.toSet());
        final Set<String> actual = _setMembers(_remapperFile, e.key);

        expect(actual, isNotEmpty, reason: '${e.key} 一列都没抽到 ⇒ 正则失效');
        expect(
          actual,
          unorderedEquals(expected),
          reason: '漏掉的列，导出时（SELECT *）带着、导入时被当未知列丢掉——'
              '用户的数据在「导出再导入」之后静默消失。\n'
              '漏掉：${expected.difference(actual)}\n'
              '多出：${actual.difference(expected)}\n'
              '真不该导入的列，连同理由登记进 _notImported。',
        );
      });
    }

    // 自证：上表必须覆盖 remapper 里**全部**白名单 Set，以及 columns.dart 里**全部**
    // 表——加一张新表或新白名单而不登记，上面那组就悄悄少测一张表。
    test('白名单 Set 清单与列类清单都没有漏登（自证）', () {
      final Set<String> declaredSets = <String>{
        for (final RegExpMatch m in RegExp(r'const Set<String> (_\w+Cols)\b')
            .allMatches(File(_remapperFile).readAsStringSync()))
          m.group(1)!,
      };
      expect(declaredSets, unorderedEquals(_whitelistOf.keys),
          reason: 'import_remapper 里的白名单 Set 与本测试的登记表不一致');

      final Set<String> declaredClasses = <String>{
        for (final RegExpMatch m in RegExp(r'class\s+(\w+Col)\s*\{')
            .allMatches(File(_columnsFile).readAsStringSync()))
          m.group(1)!,
      };
      expect(
        declaredClasses,
        unorderedEquals(<String>{..._whitelistOf.values, ..._notTables.keys}),
        reason: 'columns.dart 多了 / 少了列类：新表要么进导入白名单，'
            '要么连同理由登记进 _notTables',
      );
    });
  });

  group('B 写入端 JSONB 列表 == 迁移里的全部 JSONB 列', () {
    test('_jsonbCols 与迁移逐一对应', () {
      // 按版本顺序回放：定义时加入，DROP COLUMN 时移除。
      final Set<String> fromMigrations = <String>{};
      final RegExp defined = RegExp(r'^\s*(\w+)\s+JSONB\b', multiLine: true);
      final RegExp added = RegExp(r'\bADD\s+(?:COLUMN\s+)?(\w+)\s+JSONB\b');
      final RegExp dropped =
          RegExp(r'\bDROP\s+COLUMN\s+(?:IF\s+EXISTS\s+)?(\w+)');
      for (final File f in _migrations()) {
        final String sql = _stripComments(f.readAsStringSync());
        for (final RegExpMatch m in defined.allMatches(sql)) {
          fromMigrations.add(m.group(1)!);
        }
        for (final RegExpMatch m in added.allMatches(sql)) {
          fromMigrations.add(m.group(1)!);
        }
        for (final RegExpMatch m in dropped.allMatches(sql)) {
          fromMigrations.remove(m.group(1)!);
        }
      }
      expect(fromMigrations, isNotEmpty, reason: '一个 JSONB 列都没抽到 ⇒ 正则失效');

      final Set<String> fromWriter = <String>{
        for (final String ref in _setMembers(_writerFile, '_jsonbCols'))
          _columnsOf(ref.split('.').first)[ref.split('.').last]!,
      };
      expect(
        fromWriter,
        unorderedEquals(fromMigrations),
        reason: '迁移里是 JSONB、写入端却不在 _jsonbCols 的列，导入时走驱动的类型推断：'
            'Map 值碰巧能落成 JSONB，List 值会被推成 PG 数组、写进 JSONB 列直接报错，'
            '整个导入失败（真 PG 实测）。\n'
            '漏掉：${fromMigrations.difference(fromWriter)}\n'
            '多出：${fromWriter.difference(fromMigrations)}',
      );
    });
  });

  group('C 迁移纪律：旧项目包必须还能导入（BOARD 188）', () {
    // 导入按白名单过滤、**不补缺列**：旧包里没有的列，INSERT 就不带它。所以 v2 起的
    // 迁移若让某列「不带值就插不进去」，所有在它之前导出的项目包从此导入必炸。
    //
    // 真有必须这么做的那天：先在导入侧加填充逻辑，再把这里登记上，写明填充在哪。
    const Map<String, String> allowed = <String, String>{};

    test('v2 起不出现：加 NOT NULL 无默认的列 / SET NOT NULL / DROP DEFAULT', () {
      final List<String> violations = <String>[];
      int addClauses = 0;
      for (final File f
          in _migrations().where((File f) => _versionOf(f) >= 2)) {
        final String sql = _stripComments(f.readAsStringSync());
        final String where = 'v${_versionOf(f)}';
        for (final RegExpMatch m in RegExp(
          r'\bADD\s+(?!CONSTRAINT\b)(?:COLUMN\s+)?(?:IF\s+NOT\s+EXISTS\s+)?(\w+)\s+([^,;]*)',
          caseSensitive: false,
        ).allMatches(sql)) {
          addClauses++;
          final String def = m.group(2)!.toUpperCase();
          if (def.contains('NOT NULL') && !def.contains('DEFAULT')) {
            violations.add('$where ADD COLUMN ${m.group(1)}（NOT NULL 无 DEFAULT）');
          }
        }
        for (final RegExpMatch m in RegExp(
          r'\bALTER\s+COLUMN\s+(\w+)\s+SET\s+NOT\s+NULL\b',
          caseSensitive: false,
        ).allMatches(sql)) {
          violations.add('$where ALTER COLUMN ${m.group(1)} SET NOT NULL');
        }
        for (final RegExpMatch m in RegExp(
          r'\bALTER\s+COLUMN\s+(\w+)\s+DROP\s+DEFAULT\b',
          caseSensitive: false,
        ).allMatches(sql)) {
          violations.add('$where ALTER COLUMN ${m.group(1)} DROP DEFAULT');
        }
      }

      // 正控：v8 那条 `ADD COLUMN delivery_settings` 必须被认出来，否则正则失效。
      expect(addClauses, greaterThanOrEqualTo(1),
          reason: '一条 ADD COLUMN 都没认出来 ⇒ 正则失效，本闸形同不存在');
      expect(
        violations.where((String v) => !allowed.containsKey(v)).toList(),
        isEmpty,
        reason: '这些迁移会让此前导出的项目包导入必炸（导入不补缺列）。'
            '要么给列加 DEFAULT，要么先在导入侧补填充逻辑并登记进 allowed。',
      );
    });
  });
}
