// 网络代理 env 支持（LB-24 P0）。
//
// 为什么：dio/dart:io 默认不读系统代理——中文用户连 OpenAI/Gemini 的现实
// 障碍。P0 = `HTTPS_PROXY`/`HTTP_PROXY`/`NO_PROXY` 环境变量（大小写双查，
// Windows 惯例大写、Unix 惯例小写）；P1（设置页网络区/系统代理读取）另卡。
//
// 语义（对齐 curl 系工具约定）：
// - https 请求 → HTTPS_PROXY，缺失回落 HTTP_PROXY；http 请求 → 仅 HTTP_PROXY。
// - NO_PROXY 逗号分隔：精确 host / 域后缀（`.foo.com` 或裸 `foo.com`）/ `*` 全直连。
// - 代理串接受 `http://host:port`、`host:port`、`http://host`（补 scheme 缺省端口）；
//   解析失败安全直连，绝不因坏 env 断网。
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 纯函数：按 [env] 决定 [url] 的代理串——`PROXY host:port` 或 `DIRECT`。
String proxyRuleFor(Uri url, Map<String, String> env) {
  final noProxy = _readEnv(env, 'NO_PROXY');
  if (noProxy != null && _noProxyMatches(url.host, noProxy)) {
    return 'DIRECT';
  }
  final String? raw = url.scheme == 'https'
      ? _readEnv(env, 'HTTPS_PROXY') ?? _readEnv(env, 'HTTP_PROXY')
      : _readEnv(env, 'HTTP_PROXY');
  if (raw == null) return 'DIRECT';
  final hostPort = _proxyHostPort(raw);
  return hostPort == null ? 'DIRECT' : 'PROXY $hostPort';
}

/// 给 [dio] 挂 env 代理（IOHttpClientAdapter；测试注入的 adapter 不受影响）。
/// [environment] 缺省读 [Platform.environment]，测试可注入。
void applyEnvProxy(Dio dio, {Map<String, String>? environment}) {
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;
  final env = environment ?? Platform.environment;
  adapter.createHttpClient = () =>
      HttpClient()..findProxy = (url) => proxyRuleFor(url, env);
}

String? _readEnv(Map<String, String> env, String upperName) {
  final v = env[upperName] ?? env[upperName.toLowerCase()];
  return (v == null || v.trim().isEmpty) ? null : v.trim();
}

bool _noProxyMatches(String host, String noProxyList) {
  final h = host.toLowerCase();
  for (final rawEntry in noProxyList.split(',')) {
    final entry = rawEntry.trim().toLowerCase();
    if (entry.isEmpty) continue;
    if (entry == '*') return true;
    final suffix = entry.startsWith('.') ? entry.substring(1) : entry;
    if (h == suffix || h.endsWith('.$suffix')) return true;
  }
  return false;
}

/// `http://host:port` / `host:port` / `http://host` → `host:port`；非法 → null。
String? _proxyHostPort(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'http://$s';
  final Uri uri;
  try {
    uri = Uri.parse(s);
  } on FormatException {
    return null;
  }
  if (uri.host.isEmpty) return null;
  final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
  return '${uri.host}:$port';
}
