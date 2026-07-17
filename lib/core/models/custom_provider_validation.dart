// custom provider 字段校验纯函数（PROVIDER-API §13.1）——服务解析与设置页
// 内联校验共用同一事实源，规则改动只此一处。无 IO、无 Flutter 依赖。

import 'custom_provider_config.dart';
import 'provider_protocol_template.dart';

/// 字段级校验失败原因；UI 据此映射 l10n 文案，服务据此写 WARN reason。
enum CustomProviderFieldError {
  emptyField,
  invalidId,
  duplicateId,
  reservedId,
  unknownTemplate,
  invalidBaseUrl,
}

/// `id` 白名单模式——进 SecureStorage key / jobs.provider_id / 日志，收紧字符集。
final RegExp kCustomProviderIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');

/// 非空（trim 后）通用校验。
CustomProviderFieldError? validateRequired(String value) =>
    value.trim().isEmpty ? CustomProviderFieldError.emptyField : null;

/// id 校验：非空 → 模式 → 文件内唯一 → 不撞内置 providerId。
/// [takenIds] 为文件内其他条目的 id 集合（编辑自身时调用方先剔除自身）。
CustomProviderFieldError? validateId(
  String value, {
  required Set<String> takenIds,
  required Set<String> reservedProviderIds,
}) {
  final id = value.trim();
  if (id.isEmpty) return CustomProviderFieldError.emptyField;
  if (!kCustomProviderIdPattern.hasMatch(id)) {
    return CustomProviderFieldError.invalidId;
  }
  if (takenIds.contains(id)) return CustomProviderFieldError.duplicateId;
  if (reservedProviderIds.contains('$kCustomProviderIdPrefix$id')) {
    return CustomProviderFieldError.reservedId;
  }
  return null;
}

/// template 校验：白名单之一。
CustomProviderFieldError? validateTemplate(String value) {
  final t = value.trim();
  if (t.isEmpty) return CustomProviderFieldError.emptyField;
  if (!kProviderProtocolTemplates.containsKey(t)) {
    return CustomProviderFieldError.unknownTemplate;
  }
  return null;
}

/// base_url 校验：绝对 http(s)、有 host、无 query/fragment/userinfo
/// （Dio baseUrl 为字符串拼接，带 query 必产坏请求）。
CustomProviderFieldError? validateBaseUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return CustomProviderFieldError.emptyField;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !uri.isAbsolute ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    return CustomProviderFieldError.invalidBaseUrl;
  }
  return null;
}

/// base_url 规范化：尾部 `/` 剔除（Dio baseUrl + '/path' 拼接避免双斜杠）。
String normalizeBaseUrl(String url) {
  var out = url.trim();
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}
