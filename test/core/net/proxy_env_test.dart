// proxy_env 测试（LB-24 P0;PR-7 评审后加固）：
// proxyRuleFor 纯函数矩阵 + applyEnvProxy 接线 e2e（真 socket fake 代理）。
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/net/proxy_env.dart';

void main() {
  final httpsUrl = Uri.parse('https://api.openai.com/v1/images');
  final httpUrl = Uri.parse('http://example.com/x');

  group('proxyRuleFor', () {
    test('无相关 env → DIRECT', () {
      expect(proxyRuleFor(httpsUrl, const <String, String>{}), 'DIRECT');
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{'PATH': '/usr/bin'}),
        'DIRECT',
      );
    });

    test('HTTPS_PROXY 命中 https 请求；大小写变量名双查', () {
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{
          'HTTPS_PROXY': 'http://127.0.0.1:7890',
        }),
        'PROXY 127.0.0.1:7890',
      );
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{
          'https_proxy': '127.0.0.1:7890', // 无 scheme 形态
        }),
        'PROXY 127.0.0.1:7890',
      );
    });

    test('带凭据代理串透传 user:pass@（评审 P1-1;dart:io Basic 通道）', () {
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{
          'HTTPS_PROXY': 'http://alice:secret@10.0.0.1:3128',
        }),
        'PROXY alice:secret@10.0.0.1:3128',
      );
    });

    test('http 请求走 HTTP_PROXY；仅设 HTTPS_PROXY 时 http 请求直连', () {
      expect(
        proxyRuleFor(httpUrl, const <String, String>{
          'HTTP_PROXY': 'http://10.0.0.1:8080',
        }),
        'PROXY 10.0.0.1:8080',
      );
      expect(
        proxyRuleFor(httpUrl, const <String, String>{
          'HTTPS_PROXY': 'http://127.0.0.1:7890',
        }),
        'DIRECT',
      );
    });

    test('回落链：https→HTTPS_PROXY→HTTP_PROXY→ALL_PROXY;http→HTTP_PROXY→ALL_PROXY',
        () {
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{
          'HTTP_PROXY': 'http://10.0.0.1:8080',
        }),
        'PROXY 10.0.0.1:8080',
      );
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{
          'ALL_PROXY': 'http://10.0.0.2:1080',
        }),
        'PROXY 10.0.0.2:1080',
        reason: 'Clash/v2ray 指南常只导出 ALL_PROXY（评审 P3）',
      );
      expect(
        proxyRuleFor(httpUrl, const <String, String>{
          'ALL_PROXY': 'http://10.0.0.2:1080',
        }),
        'PROXY 10.0.0.2:1080',
      );
    });

    test('变量存在但为空串 = 显式禁用该档,不再回落（curl 约定,评审 P3）', () {
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{
          'HTTPS_PROXY': '',
          'HTTP_PROXY': 'http://10.0.0.1:8080',
        }),
        'DIRECT',
      );
    });

    test('loopback 目标恒直连——本机端点不受代理劫持（评审 P2-2）', () {
      const env = <String, String>{'HTTP_PROXY': 'http://10.0.0.1:8080'};
      expect(
        proxyRuleFor(Uri.parse('http://localhost:8188/prompt'), env),
        'DIRECT',
      );
      expect(
        proxyRuleFor(Uri.parse('http://127.0.0.1:1234/v1'), env),
        'DIRECT',
      );
    });

    test('NO_PROXY：精确 / .后缀 / 裸后缀 / *.glob / 通配 * / 大小写;不过度吞域', () {
      const env = <String, String>{
        'HTTPS_PROXY': 'http://127.0.0.1:7890',
      };
      expect(
        proxyRuleFor(httpsUrl, {...env, 'NO_PROXY': 'api.openai.com'}),
        'DIRECT',
      );
      expect(
        proxyRuleFor(httpsUrl, {...env, 'NO_PROXY': '.openai.com'}),
        'DIRECT',
      );
      expect(
        proxyRuleFor(httpsUrl, {...env, 'NO_PROXY': '*.openai.com'}),
        'DIRECT',
        reason: 'Windows/.NET glob 形态（评审 P2-3）',
      );
      expect(
        proxyRuleFor(httpsUrl, {...env, 'no_proxy': 'openai.com'}),
        'DIRECT',
      );
      expect(
        proxyRuleFor(httpsUrl, {...env, 'NO_PROXY': 'localhost,example.com'}),
        'PROXY 127.0.0.1:7890',
      );
      expect(
        proxyRuleFor(
          Uri.parse('https://notopenai.com/x'),
          {...env, 'NO_PROXY': 'openai.com'},
        ),
        'PROXY 127.0.0.1:7890',
        reason: '裸后缀不得吞非子域',
      );
      expect(proxyRuleFor(httpsUrl, {...env, 'NO_PROXY': '*'}), 'DIRECT');
    });

    test('解析不出 host / host 含 % / 非 http(s) scheme → 直连', () {
      // 注意语义（评审 P1-2 勘正）：这里只兜「解析不出目标」的值;能解析但
      // 指向不可达/非代理地址的值会得到连接错误——同 curl,不做连通性预检。
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{'HTTPS_PROXY': ' '}),
        'DIRECT',
      );
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{'HTTPS_PROXY': '://'}),
        'DIRECT',
      );
      expect(
        proxyRuleFor(
          httpsUrl,
          const <String, String>{'HTTPS_PROXY': 'not a proxy'},
        ),
        'DIRECT',
        reason: '含空格 → host percent-encoded 含 %,dart:io 连接层会抛,直连兜底',
      );
      expect(
        proxyRuleFor(
          httpsUrl,
          const <String, String>{'HTTPS_PROXY': 'socks5://127.0.0.1:7891'},
        ),
        'DIRECT',
        reason: '本实现说不了 SOCKS——直连好过对 SOCKS 端口说 HTTP',
      );
    });

    test('代理串缺省端口按 scheme 补（http→80/https→443）', () {
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{
          'HTTPS_PROXY': 'http://proxy.corp',
        }),
        'PROXY proxy.corp:80',
      );
      expect(
        proxyRuleFor(httpsUrl, const <String, String>{
          'HTTPS_PROXY': 'https://proxy.corp',
        }),
        'PROXY proxy.corp:443',
      );
    });
  });

  group('applyEnvProxy 接线（评审 P1-3）', () {
    // dart HttpServer 会对代理形态的绝对 URI 请求行直接 400——
    // 用裸 ServerSocket 假代理捕请求行并定长代答。
    Future<(ServerSocket, List<String>)> startFakeProxy() async {
      final hits = <String>[];
      final server =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((socket) {
        final buf = StringBuffer();
        socket.listen((data) {
          buf.write(String.fromCharCodes(data));
          if (buf.toString().contains('\r\n\r\n')) {
            hits.add(buf.toString().split('\r\n').first); // 请求行
            socket.write(
              'HTTP/1.1 200 OK\r\n'
              'content-length: 10\r\n'
              'connection: close\r\n'
              '\r\n'
              'proxied-ok',
            );
            socket.flush().then((_) => socket.destroy());
          }
        });
      });
      addTearDown(() => server.close());
      return (server, hits);
    }

    // flutter_test 全局 HttpOverrides 把 HttpClient 换成恒 400 mock——
    // e2e 两例经空 HttpOverrides 子类换回真实现（基类默认即真 HttpClient;
    // 不能用 createHttpClient: (ctx)=>HttpClient(...)——构造器会递归回 overrides）。
    Future<T> withRealHttp<T>(Future<T> Function() body) =>
        HttpOverrides.runWithHttpOverrides<Future<T>>(
          body,
          _RealHttpOverrides(),
        );

    test('经 env 代理可达：fake 代理收到绝对 URI 请求行并代答', () async {
      final (proxy, hits) = await startFakeProxy();

      await withRealHttp(() async {
        final dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            responseType: ResponseType.plain,
          ),
        );
        applyEnvProxy(dio, environment: <String, String>{
          'HTTP_PROXY': 'http://127.0.0.1:${proxy.port}',
        });

        final resp = await dio.get<String>('http://target.example/x');
        expect(resp.statusCode, 200);
        expect(resp.data, 'proxied-ok');
      });
      expect(hits.single, contains('http://target.example/x'),
          reason: '代理形态=请求行带绝对 URI');
    });

    test('NO_PROXY 命中 → 绕过代理直连（代理零流量,DNS 失败即证未走代理）',
        () async {
      final (proxy, hits) = await startFakeProxy();

      await withRealHttp(() async {
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 5)),
        );
        applyEnvProxy(dio, environment: <String, String>{
          'HTTP_PROXY': 'http://127.0.0.1:${proxy.port}',
          'NO_PROXY': 'bypassed.example',
        });

        // 若走了代理,fake 代理会 200 代答;直连则该域名不可解析 → 连接错误。
        await expectLater(
          dio.get<String>('http://no-such.bypassed.example/x'),
          throwsA(isA<DioException>()),
        );
      });
      expect(hits, isEmpty, reason: 'NO_PROXY 命中不得经过代理');
    });

    test('注入自定义 adapter（非 IOHttpClientAdapter）→ 零扰动 no-op', () {
      final fake = _FakeAdapter();
      final dio = Dio()..httpClientAdapter = fake;

      applyEnvProxy(dio, environment: const <String, String>{
        'HTTP_PROXY': 'http://10.0.0.1:8080',
      });

      expect(identical(dio.httpClientAdapter, fake), isTrue);
    });

    test('无任何代理变量 → 不覆盖 createHttpClient（保 dio 默认工厂,评审 P2-1）',
        () {
      final dio = Dio();
      final adapter = dio.httpClientAdapter as IOHttpClientAdapter;

      applyEnvProxy(dio, environment: const <String, String>{});

      expect(adapter.createHttpClient, isNull);
    });
  });
}

/// 基类默认实现即真 HttpClient——用于在 flutter_test 的 400-mock 覆盖下换回真 IO。
class _RealHttpOverrides extends HttpOverrides {}

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      throw UnimplementedError();

  @override
  void close({bool force = false}) {}
}
