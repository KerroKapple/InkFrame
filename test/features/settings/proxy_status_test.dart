// 设置「网络」页的数据源：环境变量代理的只读快照。
//
// 两件事必须钉死：① 凭据不上屏（代理串里的 user:pass 必须掩码）；
// ② 「当前是否走代理」复用 core/net 的 proxyRuleFor，不另写一套语义
// （空串=显式禁用、loopback 恒直连这些约定只许有一处实现）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/settings/util/proxy_status.dart';

void main() {
  group('maskProxyCredentials', () {
    test('带 scheme 的凭据被掩码', () {
      expect(
        maskProxyCredentials('http://alice:s3cret@proxy.corp:3128'),
        'http://•••@proxy.corp:3128',
      );
    });

    test('裸 host:port 的凭据被掩码', () {
      expect(maskProxyCredentials('alice:s3cret@proxy.corp:3128'),
          '•••@proxy.corp:3128');
    });

    test('无凭据原样返回', () {
      expect(maskProxyCredentials('http://proxy.corp:3128'),
          'http://proxy.corp:3128');
      expect(maskProxyCredentials('proxy.corp:3128'), 'proxy.corp:3128');
    });
  });

  group('readProxyVars', () {
    test('四个变量按声明序返回；未设置 = null，值做掩码', () {
      final List<ProxyVarRow> rows = readProxyVars(<String, String>{
        'HTTPS_PROXY': 'http://alice:pw@proxy.corp:3128',
        'NO_PROXY': '.corp,localhost',
      });
      expect(rows.map((ProxyVarRow r) => r.variable), ProxyVar.values);
      final Map<ProxyVar, String?> byVar = <ProxyVar, String?>{
        for (final ProxyVarRow r in rows) r.variable: r.value,
      };
      expect(byVar[ProxyVar.httpsProxy], 'http://•••@proxy.corp:3128');
      expect(byVar[ProxyVar.httpProxy], isNull);
      expect(byVar[ProxyVar.allProxy], isNull);
      expect(byVar[ProxyVar.noProxy], '.corp,localhost');
    });

    test('小写变量名同样读到（proxy_env 的大小写双查）', () {
      final List<ProxyVarRow> rows =
          readProxyVars(<String, String>{'https_proxy': 'proxy.corp:3128'});
      expect(rows.first.value, 'proxy.corp:3128');
    });

    test('存在但为空串 = 显式禁用该档，不当未设置', () {
      final List<ProxyVarRow> rows =
          readProxyVars(<String, String>{'HTTPS_PROXY': ''});
      expect(rows.first.value, '');
    });

    test('变量名不进 ARB（环境变量是协议字面量）', () {
      expect(proxyVarName(ProxyVar.httpsProxy), 'HTTPS_PROXY');
      expect(proxyVarName(ProxyVar.noProxy), 'NO_PROXY');
    });
  });

  group('effectiveHttpsProxyTarget', () {
    test('无任何变量 → null（直连）', () {
      expect(effectiveHttpsProxyTarget(const <String, String>{}), isNull);
    });

    test('有 HTTPS_PROXY → 掩码后的 host:port', () {
      expect(
        effectiveHttpsProxyTarget(
          const <String, String>{'HTTPS_PROXY': 'http://u:p@proxy.corp:3128'},
        ),
        '•••@proxy.corp:3128',
      );
    });

    test('NO_PROXY=* → 直连（语义来自 proxyRuleFor，不另写）', () {
      expect(
        effectiveHttpsProxyTarget(const <String, String>{
          'HTTPS_PROXY': 'proxy.corp:3128',
          'NO_PROXY': '*',
        }),
        isNull,
      );
    });
  });
}
