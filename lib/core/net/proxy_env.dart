// 网络代理 env 支持（LB-24 P0）。
//
// 为什么：dio/dart:io 默认不读系统代理——中文用户连 OpenAI/Gemini 的现实
// 障碍。P0 = `HTTPS_PROXY`/`HTTP_PROXY`/`ALL_PROXY`/`NO_PROXY` 环境变量
//（大小写双查）；P1（设置页网络区/系统代理读取）另卡。
//
// 语义（对齐 curl 系工具约定；PR-7 评审后收敛）：
// - https 请求 → HTTPS_PROXY，缺失回落 HTTP_PROXY，再回落 ALL_PROXY；
//   http 请求 → HTTP_PROXY，缺失回落 ALL_PROXY。
// - **变量存在但为空串 = 显式禁用该档**（curl 约定），不再向后回落。
// - loopback 目标（localhost/127.x/::1）恒直连——本机端点（自定义
//   OpenAI 兼容 endpoint/LM Studio/ComfyUI）不受企业代理劫持（评审 P2-2）。
// - NO_PROXY 逗号分隔：精确 host / 域后缀（`.foo.com`、`*.foo.com` 或裸
//   `foo.com`）/ `*` 全直连。**不支持** 端口段（`host:port`）与 CIDR
//   （`10.0.0.0/8`）——出现时按普通 host 字面匹配（通常不命中），见 SETUP.md。
// - 代理串支持 `http://user:pass@host:port`（凭据透传给 dart:io 的
//   Proxy-Authorization Basic 通道，评审 P1-1）；`socks5://` 等非 http(s)
//   scheme 本实现说不了该协议 → 直连（好过对 SOCKS 端口说 HTTP）。
// - 解析不出 host（或 host 含 %——dart:io 会抛 FormatException）→ 直连。
//   注意：能解析、但指向不可达/非代理地址的值会得到连接错误——与 curl
//   一致，本实现不做（也做不了）连通性预检。
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 纯函数：按 [env] 决定 [url] 的代理串——`PROXY [user:pass@]host:port` 或 `DIRECT`。
String proxyRuleFor(Uri url, Map<String, String> env) {
  if (_isLoopback(url.host)) return 'DIRECT';
  final noProxy = _readEnv(env, 'NO_PROXY');
  if (noProxy != null && _noProxyMatches(url.host, noProxy)) {
    return 'DIRECT';
  }
  final String? raw = url.scheme == 'https'
      ? _firstSet(env, const ['HTTPS_PROXY', 'HTTP_PROXY', 'ALL_PROXY'])
      : _firstSet(env, const ['HTTP_PROXY', 'ALL_PROXY']);
  if (raw == null) return 'DIRECT';
  final target = _proxyTarget(raw);
  return target == null ? 'DIRECT' : 'PROXY $target';
}

/// 给 [dio] 挂 env 代理（IOHttpClientAdapter；注入自定义 adapter 的测试零扰动）。
/// 无任何代理变量时不动 adapter——保 dio 默认工厂行为（idleTimeout 3s 等，
/// 评审 P2-1：不为没人用的功能改变 100% 用户的连接行为）。
/// [environment] 缺省读 [Platform.environment]（进程启动快照——改 env 需重启）。
void applyEnvProxy(Dio dio, {Map<String, String>? environment}) {
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;
  final env = environment ?? Platform.environment;
  final hasAny = _firstSet(
        env,
        const ['HTTPS_PROXY', 'HTTP_PROXY', 'ALL_PROXY'],
      ) !=
      null;
  if (!hasAny) return;
  adapter.createHttpClient = () => HttpClient()
    // 对齐 dio 默认工厂的 idleTimeout,不因代理接管而放宽连接持有。
    ..idleTimeout = const Duration(seconds: 3)
    ..findProxy = (url) => proxyRuleFor(url, env);
}

/// 变量存在即返回（含空串——空串语义=显式禁用,由 [_firstSet] 判定）；
/// 大小写双查，值 trim。
String? _readEnvRaw(Map<String, String> env, String upperName) =>
    env.containsKey(upperName)
        ? env[upperName]!.trim()
        : env[upperName.toLowerCase()]?.trim();

String? _readEnv(Map<String, String> env, String upperName) {
  final v = _readEnvRaw(env, upperName);
  return (v == null || v.isEmpty) ? null : v;
}

/// 回落链：遇到「存在但为空」的变量即停（显式禁用该档，curl 约定）。
String? _firstSet(Map<String, String> env, List<String> names) {
  for (final name in names) {
    final raw = _readEnvRaw(env, name);
    if (raw == null) continue;
    return raw.isEmpty ? null : raw;
  }
  return null;
}

bool _isLoopback(String host) {
  final h = host.toLowerCase();
  return h == 'localhost' ||
      h == '::1' ||
      h.startsWith('127.') ||
      h == '[::1]';
}

bool _noProxyMatches(String host, String noProxyList) {
  final h = host.toLowerCase();
  for (final rawEntry in noProxyList.split(',')) {
    var entry = rawEntry.trim().toLowerCase();
    if (entry.isEmpty) continue;
    if (entry == '*') return true;
    if (entry.startsWith('*.')) entry = entry.substring(1); // `*.foo` → `.foo`
    final suffix = entry.startsWith('.') ? entry.substring(1) : entry;
    if (h == suffix || h.endsWith('.$suffix')) return true;
  }
  return false;
}

/// `http://[user:pass@]host[:port]` / `host:port` → `[user:pass@]host:port`；
/// 非 http(s) scheme / 无 host / host 含 %（percent-encoded，dart:io 连接层
/// 会抛 FormatException）→ null。
String? _proxyTarget(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'http://$s';
  final Uri uri;
  try {
    uri = Uri.parse(s);
  } on FormatException {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty || uri.host.contains('%')) return null;
  final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
  final auth = uri.userInfo.isEmpty ? '' : '${uri.userInfo}@';
  return '$auth${uri.host}:$port';
}
