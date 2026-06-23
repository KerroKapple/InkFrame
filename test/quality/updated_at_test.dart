// updated_at 维护回归（PRD §21）：每条业务表的 UPDATE ... SET 必须同窗口 touch updated_at。
// 把原 check-updated-at.sh（python3 + bash 双依赖、Windows 跨平台脆弱）迁为纯 Dart 静态测试，
// 随 flutter test 在全平台稳定执行。
//
// 语义等价复刻：扫 lib/storage 全部 .dart，对每个独立 UPDATE <table> SET 断言邻近含 updated_at；
// 白名单表（DDL 无 updated_at 列）豁免；ON CONFLICT / DO UPDATE 的 UPSERT 子句排除。
// 当前仓库 projects/nodes 等的 UPDATE 经 base_repository.buildUpdate 注入 updated_at，应全绿。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // DDL 无 updated_at 列的表：豁免。
  const whitelist = <String>{'edges', 'jobs', 'batch_results', 'schema_version'};

  final updateRe =
      RegExp(r'UPDATE\s+([A-Za-z_][A-Za-z0-9_]*)\s+SET', caseSensitive: false);
  final upsertRe = RegExp(r'ON\s+CONFLICT|DO\s+UPDATE', caseSensitive: false);

  test('lib/storage 下每条业务表 UPDATE 均 touch updated_at', () {
    final storageDir = Directory('lib/storage');
    expect(storageDir.existsSync(), isTrue, reason: 'lib/storage/ not found');

    final violations = <String>[];

    for (final entity in storageDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (path.endsWith('_test.dart') ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart')) {
        continue;
      }

      final src = entity.readAsStringSync();
      for (final m in updateRe.allMatches(src)) {
        // (1) UPSERT 子句排除：UPDATE 前 80 字符出现 ON CONFLICT / DO UPDATE。
        final preStart = (m.start - 80).clamp(0, src.length);
        final pre = src.substring(preStart, m.start);
        if (upsertRe.hasMatch(pre)) continue;

        // (2) 白名单表豁免。
        final table = m.group(1)!.toLowerCase();
        if (whitelist.contains(table)) continue;

        // (3) UPDATE 起 400 字符窗口内须含 updated_at。
        final winEnd = (m.start + 400).clamp(0, src.length);
        final window = src.substring(m.start, winEnd);
        if (!window.contains('updated_at')) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          final excerpt = src
              .substring(m.start, (m.start + 60).clamp(0, src.length))
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          violations.add('$path:$line  UPDATE $table without updated_at: '
              '$excerpt');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'UPDATE statements missing updated_at touch '
          '(PRD §21):\n${violations.join('\n')}',
    );
  });
}
