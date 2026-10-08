// 设置「网络」页的数据源：env 代理的只读快照（纯函数）。
//
// 本仓库的代理支持就是 env（LB-24 P0：HTTPS_PROXY / HTTP_PROXY / ALL_PROXY /
// NO_PROXY），没有「在设置里填代理」这个后端——所以这一页只读：把进程启动时
// 读到的四个变量摆出来，并告诉用户此刻到底走不走代理。能填的那一版是 LB-24 P1。
//
// 「走不走代理」刻意复用 core/net/proxy_env.dart 的 [proxyRuleFor]：空串=显式
// 禁用、loopback 恒直连、NO_PROXY 后缀匹配这些约定只许有一处实现，页面再抄一遍
// 必然和实际连接行为分叉。
import 'package:flutter/foundation.dart';

import '../../../core/net/proxy_env.dart';

/// 判定「此刻走不走代理」用的探针 URL：一个中立的 https 目标。
/// 用真实厂商域名会被 NO_PROXY 的某条规则意外命中，读数就不再代表通例。
const String _probeUrl = 'https://api.example.com/v1';

/// 页面列出的四个环境变量。声明序 == 显示序，也是 proxyRuleFor 的回落序。
enum ProxyVar { httpsProxy, httpProxy, allProxy, noProxy }

/// 变量名是协议字面量，不进 ARB（CLAUDE.md i18n 规则第 2 条）。
String proxyVarName(ProxyVar v) => switch (v) {
      ProxyVar.httpsProxy => 'HTTPS_PROXY',
      ProxyVar.httpProxy => 'HTTP_PROXY',
      ProxyVar.allProxy => 'ALL_PROXY',
      ProxyVar.noProxy => 'NO_PROXY',
    };

@immutable
class ProxyVarRow {
  const ProxyVarRow({required this.variable, required this.value});

  final ProxyVar variable;

  /// null = 未设置；'' = 存在但为空串（curl 约定的「显式禁用该档」）；
  /// 其余为掩码后的原值。
  final String? value;
}

/// 四行只读快照。大小写双查（与 proxy_env 同约定）；凭据掩码后才出函数。
List<ProxyVarRow> readProxyVars(Map<String, String> env) => <ProxyVarRow>[
      for (final ProxyVar v in ProxyVar.values)
        ProxyVarRow(variable: v, value: _read(env, proxyVarName(v))),
    ];

/// 此刻一次代表性 https 请求会不会走代理：返回掩码后的 `host:port`，null = 直连。
String? effectiveHttpsProxyTarget(Map<String, String> env) {
  const String prefix = 'PROXY ';
  final String rule = proxyRuleFor(Uri.parse(_probeUrl), env);
  if (!rule.startsWith(prefix)) return null;
  return maskProxyCredentials(rule.substring(prefix.length));
}

/// `[scheme://][user:pass@]host:port` → 把凭据换成 `•••`。
/// 代理串里的口令和 API Key 一样不许上屏（诊断包同口径）。
String maskProxyCredentials(String raw) {
  final int at = raw.lastIndexOf('@');
  if (at < 0) return raw;
  final int schemeEnd = raw.indexOf('//');
  final int start = schemeEnd < 0 ? 0 : schemeEnd + 2;
  if (at <= start) return raw; // '@' 落在 scheme 里：不是凭据
  return '${raw.substring(0, start)}•••${raw.substring(at)}';
}

/// 变量存在即返回（空串照原样回，空串自己就是一种语义）；大小写双查，值 trim。
String? _read(Map<String, String> env, String upperName) {
  final String? raw = env.containsKey(upperName)
      ? env[upperName]
      : env[upperName.toLowerCase()];
  if (raw == null) return null;
  final String trimmed = raw.trim();
  return trimmed.isEmpty ? '' : maskProxyCredentials(trimmed);
}
