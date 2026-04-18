// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'key_validation_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$KeyValidationResult {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyValidationResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'KeyValidationResult()';
}


}

/// @nodoc
class $KeyValidationResultCopyWith<$Res>  {
$KeyValidationResultCopyWith(KeyValidationResult _, $Res Function(KeyValidationResult) __);
}


/// Adds pattern-matching-related methods to [KeyValidationResult].
extension KeyValidationResultPatterns on KeyValidationResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( KeyValid value)?  valid,TResult Function( KeyInvalid value)?  invalid,TResult Function( KeyNetworkError value)?  networkError,required TResult orElse(),}){
final _that = this;
switch (_that) {
case KeyValid() when valid != null:
return valid(_that);case KeyInvalid() when invalid != null:
return invalid(_that);case KeyNetworkError() when networkError != null:
return networkError(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( KeyValid value)  valid,required TResult Function( KeyInvalid value)  invalid,required TResult Function( KeyNetworkError value)  networkError,}){
final _that = this;
switch (_that) {
case KeyValid():
return valid(_that);case KeyInvalid():
return invalid(_that);case KeyNetworkError():
return networkError(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( KeyValid value)?  valid,TResult? Function( KeyInvalid value)?  invalid,TResult? Function( KeyNetworkError value)?  networkError,}){
final _that = this;
switch (_that) {
case KeyValid() when valid != null:
return valid(_that);case KeyInvalid() when invalid != null:
return invalid(_that);case KeyNetworkError() when networkError != null:
return networkError(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String? accountInfo)?  valid,TResult Function( KeyInvalidReason reason,  String? detail)?  invalid,TResult Function( String message)?  networkError,required TResult orElse(),}) {final _that = this;
switch (_that) {
case KeyValid() when valid != null:
return valid(_that.accountInfo);case KeyInvalid() when invalid != null:
return invalid(_that.reason,_that.detail);case KeyNetworkError() when networkError != null:
return networkError(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String? accountInfo)  valid,required TResult Function( KeyInvalidReason reason,  String? detail)  invalid,required TResult Function( String message)  networkError,}) {final _that = this;
switch (_that) {
case KeyValid():
return valid(_that.accountInfo);case KeyInvalid():
return invalid(_that.reason,_that.detail);case KeyNetworkError():
return networkError(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String? accountInfo)?  valid,TResult? Function( KeyInvalidReason reason,  String? detail)?  invalid,TResult? Function( String message)?  networkError,}) {final _that = this;
switch (_that) {
case KeyValid() when valid != null:
return valid(_that.accountInfo);case KeyInvalid() when invalid != null:
return invalid(_that.reason,_that.detail);case KeyNetworkError() when networkError != null:
return networkError(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class KeyValid implements KeyValidationResult {
  const KeyValid({this.accountInfo});
  

 final  String? accountInfo;

/// Create a copy of KeyValidationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyValidCopyWith<KeyValid> get copyWith => _$KeyValidCopyWithImpl<KeyValid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyValid&&(identical(other.accountInfo, accountInfo) || other.accountInfo == accountInfo));
}


@override
int get hashCode => Object.hash(runtimeType,accountInfo);

@override
String toString() {
  return 'KeyValidationResult.valid(accountInfo: $accountInfo)';
}


}

/// @nodoc
abstract mixin class $KeyValidCopyWith<$Res> implements $KeyValidationResultCopyWith<$Res> {
  factory $KeyValidCopyWith(KeyValid value, $Res Function(KeyValid) _then) = _$KeyValidCopyWithImpl;
@useResult
$Res call({
 String? accountInfo
});




}
/// @nodoc
class _$KeyValidCopyWithImpl<$Res>
    implements $KeyValidCopyWith<$Res> {
  _$KeyValidCopyWithImpl(this._self, this._then);

  final KeyValid _self;
  final $Res Function(KeyValid) _then;

/// Create a copy of KeyValidationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? accountInfo = freezed,}) {
  return _then(KeyValid(
accountInfo: freezed == accountInfo ? _self.accountInfo : accountInfo // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class KeyInvalid implements KeyValidationResult {
  const KeyInvalid({required this.reason, this.detail});
  

 final  KeyInvalidReason reason;
 final  String? detail;

/// Create a copy of KeyValidationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyInvalidCopyWith<KeyInvalid> get copyWith => _$KeyInvalidCopyWithImpl<KeyInvalid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyInvalid&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode => Object.hash(runtimeType,reason,detail);

@override
String toString() {
  return 'KeyValidationResult.invalid(reason: $reason, detail: $detail)';
}


}

/// @nodoc
abstract mixin class $KeyInvalidCopyWith<$Res> implements $KeyValidationResultCopyWith<$Res> {
  factory $KeyInvalidCopyWith(KeyInvalid value, $Res Function(KeyInvalid) _then) = _$KeyInvalidCopyWithImpl;
@useResult
$Res call({
 KeyInvalidReason reason, String? detail
});




}
/// @nodoc
class _$KeyInvalidCopyWithImpl<$Res>
    implements $KeyInvalidCopyWith<$Res> {
  _$KeyInvalidCopyWithImpl(this._self, this._then);

  final KeyInvalid _self;
  final $Res Function(KeyInvalid) _then;

/// Create a copy of KeyValidationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? detail = freezed,}) {
  return _then(KeyInvalid(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as KeyInvalidReason,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class KeyNetworkError implements KeyValidationResult {
  const KeyNetworkError({required this.message});
  

 final  String message;

/// Create a copy of KeyValidationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyNetworkErrorCopyWith<KeyNetworkError> get copyWith => _$KeyNetworkErrorCopyWithImpl<KeyNetworkError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyNetworkError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'KeyValidationResult.networkError(message: $message)';
}


}

/// @nodoc
abstract mixin class $KeyNetworkErrorCopyWith<$Res> implements $KeyValidationResultCopyWith<$Res> {
  factory $KeyNetworkErrorCopyWith(KeyNetworkError value, $Res Function(KeyNetworkError) _then) = _$KeyNetworkErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$KeyNetworkErrorCopyWithImpl<$Res>
    implements $KeyNetworkErrorCopyWith<$Res> {
  _$KeyNetworkErrorCopyWithImpl(this._self, this._then);

  final KeyNetworkError _self;
  final $Res Function(KeyNetworkError) _then;

/// Create a copy of KeyValidationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(KeyNetworkError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
