// 口令对不上时，引导失败必须带出结构化的 SQLSTATE 28P01。真 PG。
//
// 嵌入式 PG 的口令随机生成、存在系统凭据里（LB-07）；凭据丢了，库还在、口令却再也
// 对不上。启动失败页靠这个 SQLSTATE 把文案从「磁盘 I/O 错误」换成实话。这一条钉的
// 是「驱动在认证失败时确实抛 ServerException(28P01)，并被引导层原样带出」——
// 2026-10-13 先用 SCRAM 临时集群实测过，这里把它固定下来。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/database_bootstrap.dart';
import 'package:postgres/postgres.dart';

void main() {
  test('错误口令 → DatabaseBootstrapError.sqlState == 28P01', () async {
    final String? url = Platform.environment['TEST_PG_URL'];
    if (url == null || url.isEmpty) {
      markTestSkipped('TEST_PG_URL 未设置，跳过真 PG 集成测试');
      return;
    }
    final Uri u = Uri.parse(url);
    final List<String> userInfo = u.userInfo.split(':');
    final Pool<void> pool = Pool<void>.withEndpoints(
      <Endpoint>[
        Endpoint(
          host: u.host,
          port: u.hasPort ? u.port : 5432,
          database: u.pathSegments.isEmpty ? 'postgres' : u.pathSegments.first,
          username: userInfo.first,
          password: 'definitely-not-the-password',
        ),
      ],
      settings: const PoolSettings(
        sslMode: SslMode.disable,
        maxConnectionCount: 1,
      ),
    );
    try {
      await DatabaseBootstrap(pool).run();
      // 错误口令也连上了 ⇒ 服务器是 trust 认证，造不出 28P01——如实跳过，不硬判。
      markTestSkipped('服务器对错误口令放行（trust 认证），无法验证 28P01');
    } on DatabaseBootstrapError catch (e) {
      expect(e.sqlState, kPgSqlStateInvalidPassword,
          reason: '认证失败必须以结构化 SQLSTATE 带出，启动页才能说实话：$e');
    } finally {
      await pool.close();
    }
  });
}
