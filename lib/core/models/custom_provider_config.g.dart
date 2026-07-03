// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_provider_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CustomProviderConfig _$CustomProviderConfigFromJson(
  Map<String, dynamic> json,
) => _CustomProviderConfig(
  id: json['id'] as String,
  displayName: json['display_name'] as String,
  template: json['template'] as String,
  baseUrl: json['base_url'] as String,
  modelId: json['model_id'] as String,
);

Map<String, dynamic> _$CustomProviderConfigToJson(
  _CustomProviderConfig instance,
) => <String, dynamic>{
  'id': instance.id,
  'display_name': instance.displayName,
  'template': instance.template,
  'base_url': instance.baseUrl,
  'model_id': instance.modelId,
};
