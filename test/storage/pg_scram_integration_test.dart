// LB-07 真 PG 集成测：SCRAM initdb 端到端验收。
//   1) pg_hba.conf 全部 scram-sha-256，无 trust 残留；
//   2) 带密码（SecureStorage 取出）连接成功；
//   3) 裸连接（无密码）被拒。
//
// 门控：TEST_PG_SCRAM=1 且本机可定位 PG 二进制（INKFRAME_PG_BIN /
// 仓库 resources，见 PgBinaryLocator）。未满足时 markTestSkipped，
// 不阻塞默认测试运行。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/secure_storage_keys.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

import '../_harness/fake_secure_storage.dart';

void main() {
  test(
    'SCRAM initdb：pg_hba 无 trust、带密码可连、裸连被拒',
    () async {
      if (Platform.environment['TEST_PG_SCRAM'] != '1') {
        markTestSkipped('TEST_PG_SCRAM != 1');
        return;
      }
      final locator = DefaultPgBinaryLocator();
      try {
        locator.locate();
      } on PgBinaryNotFoundError {
        markTestSkipped('PG binaries not found (INKFRAME_PG_BIN / repo resources)');
        return;
      }

      final tempRoot = await Directory.systemTemp.createTemp('pg_scram_');
      final paths = DefaultAppPaths.forRoot(tempRoot);
      await paths.ensureInitialized();
      final storage = FakeSecureStorage();
      final ctl = PgController(
        paths: paths,
        locator: locator,
        secureStorage: storage,
      );

      try {
        final rt = await ctl.start();

        // 1) pg_hba.conf：全部 scram-sha-256，无 trust。
        final hba = File(p.join(paths.database.path, 'pg_hba.conf'))
            .readAsStringSync();
        final activeLines = hba
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .toList();
        expect(activeLines, isNotEmpty);
        expect(activeLines.where((l) => l.endsWith('trust')), isEmpty,
            reason: 'pg_hba 不得残留 trust 规则');
        expect(
            activeLines.where((l) => l.endsWith('scram-sha-256')).length,
            activeLines.length,
            reason: '所有生效规则必须是 scram-sha-256');

        // 2) 密码在 SecureStorage、runtime 携带同一密码，可正常连接。
        final stored = storage.snapshot[SecureStorageKeys.databasePassword];
        expect(stored, isNotNull);
        expect(rt.password, stored);

        final conn = await Connection.open(
          Endpoint(
            host: rt.host,
            port: rt.port,
            database: kPgDatabaseName,
            username: kPgSuperuser,
            password: rt.password,
          ),
          settings: const ConnectionSettings(sslMode: SslMode.disable),
        );
        final rs = await conn.execute('SELECT 1');
        expect(rs.first.first, 1);
        await conn.close();

        // 3) 裸连接（无密码）被拒——SCRAM 生效的直接证据。
        await expectLater(
          Connection.open(
            Endpoint(
              host: rt.host,
              port: rt.port,
              database: kPgDatabaseName,
              username: kPgSuperuser,
            ),
            settings: const ConnectionSettings(sslMode: SslMode.disable),
          ),
          throwsA(isA<PgException>()),
        );
      } finally {
        try {
          await ctl.stop();
        } on PgLifecycleError {
          // 清理路径的失败不掩盖断言结果。
        }
        await tempRoot.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
