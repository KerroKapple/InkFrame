// 引导失败 → 用户可读 InkError 的映射：口令对不上（28P01）单独标出来。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/storage/database_bootstrap.dart';

void main() {
  test('28P01 → reason = db_auth_failed（启动页据此换掉「磁盘 I/O 错误」）', () {
    final e = bootstrapFailureToInkError(
      DatabaseBootstrapError('auth', sqlState: kPgSqlStateInvalidPassword),
      StackTrace.empty,
    );
    expect(e.extra['reason'], kDbAuthFailedReason);
  });

  test('其它 SQLSTATE / 没有 SQLSTATE → 不带 reason（照旧走泛化文案）', () {
    for (final String? state in <String?>['42P01', '53100', null]) {
      final e = bootstrapFailureToInkError(
        DatabaseBootstrapError('x', sqlState: state),
        StackTrace.empty,
      );
      expect(e.extra.containsKey('reason'), isFalse, reason: 'sqlState=$state');
    }
  });
}
