// FakeDio builders：基于 http_mock_adapter 的薄封装，吃掉 provider test 里
// "new Dio + new DioAdapter + onPost(...)" 三行重复。
//
// 不引入新依赖；调用方需要在 pubspec 已有 http_mock_adapter（仓库已有）。
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'fixtures.dart';

/// HTTP method 枚举——避免 string-typing。
enum HttpMethod { get, post, put, patch, delete }

/// 一次回放：method/path + 响应（reply 或 throws）。
class FakeRoute {
  const FakeRoute({
    required this.method,
    required this.path,
    this.replyStatus,
    this.replyBody,
    this.error,
  }) : assert(
          (replyStatus != null && error == null) ||
              (replyStatus == null && error != null),
          'route 必须二选一：reply 或 throws',
        );

  final HttpMethod method;
  final String path;
  final int? replyStatus;
  final Object? replyBody;
  final DioException? error;
}

class FakeDio {
  FakeDio._();

  /// 200 + fixture body。最常见模式。
  static Dio fromFixture(
    String providerId,
    String name, {
    required String baseUrl,
    required String path,
    HttpMethod method = HttpMethod.post,
  }) {
    return _build(
      baseUrl: baseUrl,
      routes: <FakeRoute>[
        FakeRoute(
          method: method,
          path: path,
          replyStatus: 200,
          replyBody: loadProviderFixture(providerId, name),
        ),
      ],
    );
  }

  /// 任意 status + body。
  static Dio respondWith(
    int status,
    Object body, {
    required String baseUrl,
    required String path,
    HttpMethod method = HttpMethod.post,
  }) {
    return _build(
      baseUrl: baseUrl,
      routes: <FakeRoute>[
        FakeRoute(
          method: method,
          path: path,
          replyStatus: status,
          replyBody: body,
        ),
      ],
    );
  }

  /// 触发 DioException——用于错误码映射测试。
  static Dio throwsError(
    DioException error, {
    required String baseUrl,
    required String path,
    HttpMethod method = HttpMethod.post,
  }) {
    return _build(
      baseUrl: baseUrl,
      routes: <FakeRoute>[
        FakeRoute(method: method, path: path, error: error),
      ],
    );
  }

  /// 多路由：同一 dio 实例上挂多条不同路径的回放。
  static Dio routes(List<FakeRoute> routes, {required String baseUrl}) {
    return _build(baseUrl: baseUrl, routes: routes);
  }

  static Dio _build({
    required String baseUrl,
    required List<FakeRoute> routes,
  }) {
    final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
    final DioAdapter adapter =
        DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
    for (final FakeRoute r in routes) {
      _register(adapter, r);
    }
    return dio;
  }

  static void _register(DioAdapter adapter, FakeRoute r) {
    // 不标注参数类型——MockServer 是 http_mock_adapter 内部类型，
    // 公共 API 未导出；用闭包让 Dart 自行推断。
    void reply(dynamic req) {
      if (r.error != null) {
        req.throws(r.error!.response?.statusCode ?? 0, r.error!);
      } else {
        req.reply(r.replyStatus!, r.replyBody);
      }
    }

    switch (r.method) {
      case HttpMethod.get:
        adapter.onGet(r.path, reply);
      case HttpMethod.post:
        adapter.onPost(r.path, reply);
      case HttpMethod.put:
        adapter.onPut(r.path, reply);
      case HttpMethod.patch:
        adapter.onPatch(r.path, reply);
      case HttpMethod.delete:
        adapter.onDelete(r.path, reply);
    }
  }
}
