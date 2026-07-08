// LogSanitizer：敏感串脱敏的单一真相源。
//
// FileLoggerService 与 FileCrashReporter 共用——凡是把 error / stack / extra 落盘的
// 路径，都必须先经此打码，避免 sk-… / Bearer … / AIza… / api_key=… / key/token/
// password/secret 等凭证以明文写入磁盘（崩溃文件同样是攻击面，LB-07 起 PG 口令会
// 流经连接层，其失败正是未捕获崩溃的高发点）。
//
// 位置在 core/logging（而非 services）：logger 属 core 层，不得反向依赖 services；
// crash_reporter 属 services 层，向下依赖 core 合法。
//
// 内部字符串常量（正则 / key 名）为英文，不做 i18n（项目规则：日志/内部串英文常量）。
class LogSanitizer {
  const LogSanitizer._();

  /// 命中即整值打码的敏感字段名（大小写不敏感比较）。
  static const Set<String> redactKeys = <String>{
    'key',
    'api_key',
    'apikey',
    'token',
    'authorization',
    'authorisation',
    'prompt',
    'password',
    'proxy_password',
    'proxypassword',
    'secret',
  };

  // 值里内嵌的凭证形态（sk-xxx / Bearer xxx / key=xxx）也要打码。
  static final List<RegExp> _valuePatterns = <RegExp>[
    RegExp(r'sk-[A-Za-z0-9_\-]{8,}'),
    RegExp(r'[Bb]earer\s+[A-Za-z0-9._~+/\-]+=*'),
    RegExp(r'AIza[0-9A-Za-z_\-]{10,}'),
    RegExp(
      '(api[_-]?key|apikey|token|secret|password|authorization)'
      r'''["']?\s*[=:]\s*["']?[^"'\s,;}&]+''',
      caseSensitive: false,
    ),
  ];

  /// key 形态字符串掩码：把值里内嵌的凭证替换为 `***`。
  static String maskString(String s) {
    var out = s;
    for (final re in _valuePatterns) {
      out = out.replaceAll(re, '***');
    }
    return out;
  }

  /// 递归脱敏：嵌套 Map / List 全深度处理；命中敏感 key 整值置 `***`，
  /// 其余 String 值走 key 形态掩码。
  static Object? redactValue(Object? v) {
    if (v is String) return maskString(v);
    if (v is Map) {
      final out = <String, Object?>{};
      for (final entry in v.entries) {
        final key = entry.key.toString();
        out[key] = redactKeys.contains(key.toLowerCase())
            ? '***'
            : redactValue(entry.value);
      }
      return out;
    }
    if (v is Iterable) {
      return <Object?>[for (final e in v) redactValue(e)];
    }
    return v;
  }
}
