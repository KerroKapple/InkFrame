// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'custom_provider_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CustomProviderConfig {

/// 文件内唯一；`^[A-Za-z0-9][A-Za-z0-9_-]*$`。
 String get id;/// UI 显示名（inspector 下拉 / 设置页）。
@JsonKey(name: 'display_name') String get displayName;/// 协议模板 id（kProviderProtocolTemplates 白名单之一）。
 String get template;/// 绝对 http(s) URL，尾部 `/` 已在解析期剔除。
@JsonKey(name: 'base_url') String get baseUrl;/// 透传为请求体 `model` 字段。
@JsonKey(name: 'model_id') String get modelId;
/// Create a copy of CustomProviderConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomProviderConfigCopyWith<CustomProviderConfig> get copyWith => _$CustomProviderConfigCopyWithImpl<CustomProviderConfig>(this as CustomProviderConfig, _$identity);

  /// Serializes this CustomProviderConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomProviderConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.template, template) || other.template == template)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.modelId, modelId) || other.modelId == modelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,template,baseUrl,modelId);

@override
String toString() {
  return 'CustomProviderConfig(id: $id, displayName: $displayName, template: $template, baseUrl: $baseUrl, modelId: $modelId)';
}


}

/// @nodoc
abstract mixin class $CustomProviderConfigCopyWith<$Res>  {
  factory $CustomProviderConfigCopyWith(CustomProviderConfig value, $Res Function(CustomProviderConfig) _then) = _$CustomProviderConfigCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'display_name') String displayName, String template,@JsonKey(name: 'base_url') String baseUrl,@JsonKey(name: 'model_id') String modelId
});




}
/// @nodoc
class _$CustomProviderConfigCopyWithImpl<$Res>
    implements $CustomProviderConfigCopyWith<$Res> {
  _$CustomProviderConfigCopyWithImpl(this._self, this._then);

  final CustomProviderConfig _self;
  final $Res Function(CustomProviderConfig) _then;

/// Create a copy of CustomProviderConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? template = null,Object? baseUrl = null,Object? modelId = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomProviderConfig].
extension CustomProviderConfigPatterns on CustomProviderConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomProviderConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomProviderConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomProviderConfig value)  $default,){
final _that = this;
switch (_that) {
case _CustomProviderConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomProviderConfig value)?  $default,){
final _that = this;
switch (_that) {
case _CustomProviderConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'display_name')  String displayName,  String template, @JsonKey(name: 'base_url')  String baseUrl, @JsonKey(name: 'model_id')  String modelId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomProviderConfig() when $default != null:
return $default(_that.id,_that.displayName,_that.template,_that.baseUrl,_that.modelId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'display_name')  String displayName,  String template, @JsonKey(name: 'base_url')  String baseUrl, @JsonKey(name: 'model_id')  String modelId)  $default,) {final _that = this;
switch (_that) {
case _CustomProviderConfig():
return $default(_that.id,_that.displayName,_that.template,_that.baseUrl,_that.modelId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'display_name')  String displayName,  String template, @JsonKey(name: 'base_url')  String baseUrl, @JsonKey(name: 'model_id')  String modelId)?  $default,) {final _that = this;
switch (_that) {
case _CustomProviderConfig() when $default != null:
return $default(_that.id,_that.displayName,_that.template,_that.baseUrl,_that.modelId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomProviderConfig extends CustomProviderConfig {
  const _CustomProviderConfig({required this.id, @JsonKey(name: 'display_name') required this.displayName, required this.template, @JsonKey(name: 'base_url') required this.baseUrl, @JsonKey(name: 'model_id') required this.modelId}): super._();
  factory _CustomProviderConfig.fromJson(Map<String, dynamic> json) => _$CustomProviderConfigFromJson(json);

/// 文件内唯一；`^[A-Za-z0-9][A-Za-z0-9_-]*$`。
@override final  String id;
/// UI 显示名（inspector 下拉 / 设置页）。
@override@JsonKey(name: 'display_name') final  String displayName;
/// 协议模板 id（kProviderProtocolTemplates 白名单之一）。
@override final  String template;
/// 绝对 http(s) URL，尾部 `/` 已在解析期剔除。
@override@JsonKey(name: 'base_url') final  String baseUrl;
/// 透传为请求体 `model` 字段。
@override@JsonKey(name: 'model_id') final  String modelId;

/// Create a copy of CustomProviderConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomProviderConfigCopyWith<_CustomProviderConfig> get copyWith => __$CustomProviderConfigCopyWithImpl<_CustomProviderConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomProviderConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomProviderConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.template, template) || other.template == template)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.modelId, modelId) || other.modelId == modelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,template,baseUrl,modelId);

@override
String toString() {
  return 'CustomProviderConfig(id: $id, displayName: $displayName, template: $template, baseUrl: $baseUrl, modelId: $modelId)';
}


}

/// @nodoc
abstract mixin class _$CustomProviderConfigCopyWith<$Res> implements $CustomProviderConfigCopyWith<$Res> {
  factory _$CustomProviderConfigCopyWith(_CustomProviderConfig value, $Res Function(_CustomProviderConfig) _then) = __$CustomProviderConfigCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'display_name') String displayName, String template,@JsonKey(name: 'base_url') String baseUrl,@JsonKey(name: 'model_id') String modelId
});




}
/// @nodoc
class __$CustomProviderConfigCopyWithImpl<$Res>
    implements _$CustomProviderConfigCopyWith<$Res> {
  __$CustomProviderConfigCopyWithImpl(this._self, this._then);

  final _CustomProviderConfig _self;
  final $Res Function(_CustomProviderConfig) _then;

/// Create a copy of CustomProviderConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? template = null,Object? baseUrl = null,Object? modelId = null,}) {
  return _then(_CustomProviderConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
