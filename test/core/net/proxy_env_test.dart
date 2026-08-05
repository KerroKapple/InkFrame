// proxyRuleFor 纯函数矩阵（LB-24 P0）：HTTPS_PROXY/HTTP_PROXY/NO_PROXY
// 大小写双查、scheme 分流与回落、NO_PROXY 精确/后缀/通配、代理串形态容错。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/net/proxy_env.dart';

void main() {
  final httpsUrl = Uri.parse('https://api.openai.com/v1/images');
  final httpUrl = Uri.parse('http://example.com/x');

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

  test('https 请求在 HTTPS_PROXY 缺失时回落 HTTP_PROXY（常见工具约定）', () {
    expect(
      proxyRuleFor(httpsUrl, const <String, String>{
        'HTTP_PROXY': 'http://10.0.0.1:8080',
      }),
      'PROXY 10.0.0.1:8080',
    );
  });

  test('NO_PROXY：精确 host / 域后缀（.前缀或裸后缀）/ 通配 * / 大小写不敏感', () {
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
      proxyRuleFor(httpsUrl, {...env, 'no_proxy': 'openai.com'}),
      'DIRECT',
    );
    expect(
      proxyRuleFor(httpsUrl, {...env, 'NO_PROXY': 'localhost,example.com'}),
      'PROXY 127.0.0.1:7890',
      reason: '不命中列表 → 照走代理',
    );
    expect(
      proxyRuleFor(httpsUrl, {...env, 'NO_PROXY': '*'}),
      'DIRECT',
    );
    expect(
      proxyRuleFor(
        Uri.parse('https://API.OpenAI.com/v1'),
        {...env, 'NO_PROXY': 'api.openai.com'},
      ),
      'DIRECT',
    );
  });

  test('代理串非法（无 host:port 可提取）→ 安全直连不炸', () {
    expect(
      proxyRuleFor(httpsUrl, const <String, String>{'HTTPS_PROXY': ' '}),
      'DIRECT',
    );
    expect(
      proxyRuleFor(httpsUrl, const <String, String>{'HTTPS_PROXY': '://'}),
      'DIRECT',
    );
  });

  test('代理串缺省端口补 scheme 缺省（http→80）;带端口原样', () {
    expect(
      proxyRuleFor(httpsUrl, const <String, String>{
        'HTTPS_PROXY': 'http://proxy.corp',
      }),
      'PROXY proxy.corp:80',
    );
  });
}
