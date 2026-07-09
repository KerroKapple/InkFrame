// GithubUpdateCheckService 单测（UPD-1）。
//
// 关键设计（release plan UPD-1 卡面）：不用 GitHub /releases/latest——该端点
// 不含 prerelease 且当前错挂旧版;改用 /releases?per_page=10 全列表,自比 semver max。
// 错误路径走 InkError 体系（NetworkError / ProviderError）。
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/services/github_update_check_service.dart';

const String _kPath = '/repos/KerroKapple/InkFrame/releases';
const Map<String, Object?> _kQuery = <String, Object?>{'per_page': 10};

(Dio, DioAdapter) _mockDio() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'));
  return (dio, DioAdapter(dio: dio));
}

GithubUpdateCheckService _service(Dio dio, {String version = '0.1.0-alpha.10'}) {
  return GithubUpdateCheckService(
    dio: dio,
    versionSource: () async => version,
  );
}

Map<String, Object?> _release(
  String tag, {
  bool draft = false,
  bool prerelease = true,
  String? htmlUrl,
}) =>
    <String, Object?>{
      'tag_name': tag,
      'draft': draft,
      'prerelease': prerelease,
      'html_url':
          htmlUrl ?? 'https://github.com/KerroKapple/InkFrame/releases/tag/$tag',
    };

void main() {
  test('有更新：取列表 semver 最大版,跳过 draft,带回发布页链接', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, <Object?>[
        _release('v0.1.0-alpha.9'),
        _release('v0.1.0-alpha.11'),
        _release('v0.1.0-alpha.12', draft: true), // draft 不算已发布
      ]),
      queryParameters: _kQuery,
    );

    final result = await _service(dio).check();

    expect(result.updateAvailable, isTrue);
    expect(result.latestVersion, '0.1.0-alpha.11');
    expect(
      result.releaseUrl,
      'https://github.com/KerroKapple/InkFrame/releases/tag/v0.1.0-alpha.11',
    );
    expect(result.currentVersion, '0.1.0-alpha.10');
  });

  test('最新即当前 → 无更新', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, <Object?>[
        _release('v0.1.0-alpha.10'),
        _release('v0.1.0-alpha.9'),
      ]),
      queryParameters: _kQuery,
    );

    final result = await _service(dio).check();

    expect(result.updateAvailable, isFalse);
    expect(result.latestVersion, isNull);
    expect(result.releaseUrl, isNull);
  });

  test('prerelease 数值序：当前 alpha.10 > 列表最高 alpha.9 → 无更新', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, <Object?>[_release('v0.1.0-alpha.9')]),
      queryParameters: _kQuery,
    );

    final result = await _service(dio).check();
    expect(result.updateAvailable, isFalse);
  });

  test('正式版高于当前 prerelease → 有更新', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, <Object?>[
        _release('v0.1.0', prerelease: false),
      ]),
      queryParameters: _kQuery,
    );

    final result = await _service(dio).check();
    expect(result.updateAvailable, isTrue);
    expect(result.latestVersion, '0.1.0');
  });

  test('非 semver tag 与非对象项被跳过', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, <Object?>[
        _release('nightly'),
        'garbage',
        _release('v0.1.0-alpha.11'),
      ]),
      queryParameters: _kQuery,
    );

    final result = await _service(dio).check();
    expect(result.latestVersion, '0.1.0-alpha.11');
  });

  test('空列表 → 无更新', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, const <Object?>[]),
      queryParameters: _kQuery,
    );

    final result = await _service(dio).check();
    expect(result.updateAvailable, isFalse);
  });

  test('html_url 非 https → 报可用但不带链接', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, <Object?>[
        _release('v0.1.0-alpha.11', htmlUrl: 'file:///etc/passwd'),
      ]),
      queryParameters: _kQuery,
    );

    final result = await _service(dio).check();
    expect(result.updateAvailable, isTrue);
    expect(result.releaseUrl, isNull);
  });

  test('连接超时 → NetworkError(networkTimeout)', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.throws(
        504,
        DioException(
          requestOptions: RequestOptions(path: _kPath),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      queryParameters: _kQuery,
    );

    await expectLater(
      _service(dio).check(),
      throwsA(isA<NetworkError>()
          .having((e) => e.code, 'code', InkErrorCode.networkTimeout)),
    );
  });

  test('连接失败 → NetworkError(networkOffline)', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.throws(
        503,
        DioException(
          requestOptions: RequestOptions(path: _kPath),
          type: DioExceptionType.connectionError,
        ),
      ),
      queryParameters: _kQuery,
    );

    await expectLater(
      _service(dio).check(),
      throwsA(isA<NetworkError>()
          .having((e) => e.code, 'code', InkErrorCode.networkOffline)),
    );
  });

  test('403（匿名限流）→ ProviderError(providerBusy)', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(403, <String, Object?>{'message': 'rate limit'}),
      queryParameters: _kQuery,
    );

    await expectLater(
      _service(dio).check(),
      throwsA(isA<ProviderError>()
          .having((e) => e.code, 'code', InkErrorCode.providerBusy)),
    );
  });

  test('500 → ProviderError(providerServer)', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(500, <String, Object?>{'message': 'boom'}),
      queryParameters: _kQuery,
    );

    await expectLater(
      _service(dio).check(),
      throwsA(isA<ProviderError>()
          .having((e) => e.code, 'code', InkErrorCode.providerServer)),
    );
  });

  test('响应体不是列表 → ProviderError(providerInvalidResponse)', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, <String, Object?>{'message': 'not a list'}),
      queryParameters: _kQuery,
    );

    await expectLater(
      _service(dio).check(),
      throwsA(isA<ProviderError>()
          .having((e) => e.code, 'code', InkErrorCode.providerInvalidResponse)),
    );
  });

  test('当前版本不可解析 → UnknownError', () async {
    final (dio, adapter) = _mockDio();
    adapter.onGet(
      _kPath,
      (server) => server.reply(200, <Object?>[_release('v0.1.0-alpha.11')]),
      queryParameters: _kQuery,
    );

    await expectLater(
      _service(dio, version: 'not-a-version').check(),
      throwsA(isA<UnknownError>()),
    );
  });
}
