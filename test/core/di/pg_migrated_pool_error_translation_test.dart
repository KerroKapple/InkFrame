// LB-09：pgMigratedPoolProvider 在 DI 边界把 PG 生命周期 / 迁移 StateError 系
// 翻成可渲染的 LocalIOError（AsyncError 因此携带 InkError，供启动失败 surface 呈现）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/database.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/storage/database_bootstrap.dart';
import 'package:inkframe/storage/pg_controller.dart';

void main() {
  test('PgLifecycleError（StateError 系）→ LocalIOError', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        pgPoolProvider.overrideWith(
          (ref) async => throw PgLifecycleError('pg_ctl start failed'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(pgMigratedPoolProvider.future),
      throwsA(isA<LocalIOError>()),
    );
  });

  test('DatabaseBootstrapError（StateError 系）→ LocalIOError', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        pgPoolProvider.overrideWith(
          (ref) async => throw DatabaseBootstrapError('migration failed'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(pgMigratedPoolProvider.future),
      throwsA(isA<LocalIOError>()),
    );
  });

  test('翻译保留原始 StateError 作 cause + localIOError 错误码', () async {
    final PgLifecycleError original = PgLifecycleError('boom');
    final container = ProviderContainer(
      overrides: <Override>[
        pgPoolProvider.overrideWith((ref) async => throw original),
      ],
    );
    addTearDown(container.dispose);

    try {
      await container.read(pgMigratedPoolProvider.future);
      fail('expected LocalIOError');
    } on LocalIOError catch (e) {
      expect(e.cause, same(original));
      expect(e.code, InkErrorCode.localIOError);
    }
  });
}
