// CustomProviderConfig：custom_providers.json 单个条目（PROVIDER-API §13.1）。
//
// 只携带实例化参数——能力位一律由协议模板派生（provider_protocol_template.dart），
// 用户不可自由填写。校验/兜底在 CustomProvidersFileService，本模型假定字段合法。

// freezed 工厂参数上的 @JsonKey 是官方推荐用法，analyzer 误报注解目标。
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_provider_config.freezed.dart';
part 'custom_provider_config.g.dart';

/// providerId 命名空间前缀——与内置 providerId 结构性不冲突。
const String kCustomProviderIdPrefix = 'custom:';

@freezed
abstract class CustomProviderConfig with _$CustomProviderConfig {
  const CustomProviderConfig._();

  const factory CustomProviderConfig({
    /// 文件内唯一；`^[A-Za-z0-9][A-Za-z0-9_-]*$`。
    required String id,

    /// UI 显示名（inspector 下拉 / 设置页）。
    @JsonKey(name: 'display_name') required String displayName,

    /// 协议模板 id（kProviderProtocolTemplates 白名单之一）。
    required String template,

    /// 绝对 http(s) URL，尾部 `/` 已在解析期剔除。
    @JsonKey(name: 'base_url') required String baseUrl,

    /// 透传为请求体 `model` 字段。
    @JsonKey(name: 'model_id') required String modelId,
  }) = _CustomProviderConfig;

  factory CustomProviderConfig.fromJson(Map<String, Object?> json) =>
      _$CustomProviderConfigFromJson(json);

  /// registry / SecureStorage / jobs 表统一使用的 providerId。
  String get providerId => '$kCustomProviderIdPrefix$id';
}
