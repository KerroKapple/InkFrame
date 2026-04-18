// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_quota.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProviderQuota {

/// 原始币种（USD / CNY / credits 等）。
 String get currency;/// 剩余额度（可能是金额，也可能是 credits）。null 表示 Provider 未暴露。
 double? get remaining;/// 总额度（周期内）。null 表示无此概念。
 double? get total;/// 额度重置时间（若 Provider 返回）。
 DateTime? get resetAt;/// Provider 原始响应的人类可读摘要，UI 直接展示。
 String? get rawSummary;
/// Create a copy of ProviderQuota
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderQuotaCopyWith<ProviderQuota> get copyWith => _$ProviderQuotaCopyWithImpl<ProviderQuota>(this as ProviderQuota, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderQuota&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.total, total) || other.total == total)&&(identical(other.resetAt, resetAt) || other.resetAt == resetAt)&&(identical(other.rawSummary, rawSummary) || other.rawSummary == rawSummary));
}


@override
int get hashCode => Object.hash(runtimeType,currency,remaining,total,resetAt,rawSummary);

@override
String toString() {
  return 'ProviderQuota(currency: $currency, remaining: $remaining, total: $total, resetAt: $resetAt, rawSummary: $rawSummary)';
}


}

/// @nodoc
abstract mixin class $ProviderQuotaCopyWith<$Res>  {
  factory $ProviderQuotaCopyWith(ProviderQuota value, $Res Function(ProviderQuota) _then) = _$ProviderQuotaCopyWithImpl;
@useResult
$Res call({
 String currency, double? remaining, double? total, DateTime? resetAt, String? rawSummary
});




}
/// @nodoc
class _$ProviderQuotaCopyWithImpl<$Res>
    implements $ProviderQuotaCopyWith<$Res> {
  _$ProviderQuotaCopyWithImpl(this._self, this._then);

  final ProviderQuota _self;
  final $Res Function(ProviderQuota) _then;

/// Create a copy of ProviderQuota
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currency = null,Object? remaining = freezed,Object? total = freezed,Object? resetAt = freezed,Object? rawSummary = freezed,}) {
  return _then(_self.copyWith(
currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as double?,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double?,resetAt: freezed == resetAt ? _self.resetAt : resetAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rawSummary: freezed == rawSummary ? _self.rawSummary : rawSummary // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderQuota].
extension ProviderQuotaPatterns on ProviderQuota {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderQuota value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderQuota() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderQuota value)  $default,){
final _that = this;
switch (_that) {
case _ProviderQuota():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderQuota value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderQuota() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String currency,  double? remaining,  double? total,  DateTime? resetAt,  String? rawSummary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderQuota() when $default != null:
return $default(_that.currency,_that.remaining,_that.total,_that.resetAt,_that.rawSummary);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String currency,  double? remaining,  double? total,  DateTime? resetAt,  String? rawSummary)  $default,) {final _that = this;
switch (_that) {
case _ProviderQuota():
return $default(_that.currency,_that.remaining,_that.total,_that.resetAt,_that.rawSummary);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String currency,  double? remaining,  double? total,  DateTime? resetAt,  String? rawSummary)?  $default,) {final _that = this;
switch (_that) {
case _ProviderQuota() when $default != null:
return $default(_that.currency,_that.remaining,_that.total,_that.resetAt,_that.rawSummary);case _:
  return null;

}
}

}

/// @nodoc


class _ProviderQuota implements ProviderQuota {
  const _ProviderQuota({required this.currency, this.remaining, this.total, this.resetAt, this.rawSummary});
  

/// 原始币种（USD / CNY / credits 等）。
@override final  String currency;
/// 剩余额度（可能是金额，也可能是 credits）。null 表示 Provider 未暴露。
@override final  double? remaining;
/// 总额度（周期内）。null 表示无此概念。
@override final  double? total;
/// 额度重置时间（若 Provider 返回）。
@override final  DateTime? resetAt;
/// Provider 原始响应的人类可读摘要，UI 直接展示。
@override final  String? rawSummary;

/// Create a copy of ProviderQuota
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderQuotaCopyWith<_ProviderQuota> get copyWith => __$ProviderQuotaCopyWithImpl<_ProviderQuota>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderQuota&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.total, total) || other.total == total)&&(identical(other.resetAt, resetAt) || other.resetAt == resetAt)&&(identical(other.rawSummary, rawSummary) || other.rawSummary == rawSummary));
}


@override
int get hashCode => Object.hash(runtimeType,currency,remaining,total,resetAt,rawSummary);

@override
String toString() {
  return 'ProviderQuota(currency: $currency, remaining: $remaining, total: $total, resetAt: $resetAt, rawSummary: $rawSummary)';
}


}

/// @nodoc
abstract mixin class _$ProviderQuotaCopyWith<$Res> implements $ProviderQuotaCopyWith<$Res> {
  factory _$ProviderQuotaCopyWith(_ProviderQuota value, $Res Function(_ProviderQuota) _then) = __$ProviderQuotaCopyWithImpl;
@override @useResult
$Res call({
 String currency, double? remaining, double? total, DateTime? resetAt, String? rawSummary
});




}
/// @nodoc
class __$ProviderQuotaCopyWithImpl<$Res>
    implements _$ProviderQuotaCopyWith<$Res> {
  __$ProviderQuotaCopyWithImpl(this._self, this._then);

  final _ProviderQuota _self;
  final $Res Function(_ProviderQuota) _then;

/// Create a copy of ProviderQuota
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currency = null,Object? remaining = freezed,Object? total = freezed,Object? resetAt = freezed,Object? rawSummary = freezed,}) {
  return _then(_ProviderQuota(
currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as double?,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double?,resetAt: freezed == resetAt ? _self.resetAt : resetAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rawSummary: freezed == rawSummary ? _self.rawSummary : rawSummary // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
