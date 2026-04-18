// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cost_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CostModel {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CostModel);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CostModel()';
}


}

/// @nodoc
class $CostModelCopyWith<$Res>  {
$CostModelCopyWith(CostModel _, $Res Function(CostModel) __);
}


/// Adds pattern-matching-related methods to [CostModel].
extension CostModelPatterns on CostModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PerCall value)?  perCall,TResult Function( PerSecondVideo value)?  perSecondVideo,TResult Function( PerCharInput value)?  perCharInput,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PerCall() when perCall != null:
return perCall(_that);case PerSecondVideo() when perSecondVideo != null:
return perSecondVideo(_that);case PerCharInput() when perCharInput != null:
return perCharInput(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PerCall value)  perCall,required TResult Function( PerSecondVideo value)  perSecondVideo,required TResult Function( PerCharInput value)  perCharInput,}){
final _that = this;
switch (_that) {
case PerCall():
return perCall(_that);case PerSecondVideo():
return perSecondVideo(_that);case PerCharInput():
return perCharInput(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PerCall value)?  perCall,TResult? Function( PerSecondVideo value)?  perSecondVideo,TResult? Function( PerCharInput value)?  perCharInput,}){
final _that = this;
switch (_that) {
case PerCall() when perCall != null:
return perCall(_that);case PerSecondVideo() when perSecondVideo != null:
return perSecondVideo(_that);case PerCharInput() when perCharInput != null:
return perCharInput(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( double usdPerCall)?  perCall,TResult Function( double usdPerSecondAt1080p,  Map<Resolution, double> resolutionMultiplier)?  perSecondVideo,TResult Function( double usdPerKChar,  double usdPerImageOutput)?  perCharInput,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PerCall() when perCall != null:
return perCall(_that.usdPerCall);case PerSecondVideo() when perSecondVideo != null:
return perSecondVideo(_that.usdPerSecondAt1080p,_that.resolutionMultiplier);case PerCharInput() when perCharInput != null:
return perCharInput(_that.usdPerKChar,_that.usdPerImageOutput);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( double usdPerCall)  perCall,required TResult Function( double usdPerSecondAt1080p,  Map<Resolution, double> resolutionMultiplier)  perSecondVideo,required TResult Function( double usdPerKChar,  double usdPerImageOutput)  perCharInput,}) {final _that = this;
switch (_that) {
case PerCall():
return perCall(_that.usdPerCall);case PerSecondVideo():
return perSecondVideo(_that.usdPerSecondAt1080p,_that.resolutionMultiplier);case PerCharInput():
return perCharInput(_that.usdPerKChar,_that.usdPerImageOutput);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( double usdPerCall)?  perCall,TResult? Function( double usdPerSecondAt1080p,  Map<Resolution, double> resolutionMultiplier)?  perSecondVideo,TResult? Function( double usdPerKChar,  double usdPerImageOutput)?  perCharInput,}) {final _that = this;
switch (_that) {
case PerCall() when perCall != null:
return perCall(_that.usdPerCall);case PerSecondVideo() when perSecondVideo != null:
return perSecondVideo(_that.usdPerSecondAt1080p,_that.resolutionMultiplier);case PerCharInput() when perCharInput != null:
return perCharInput(_that.usdPerKChar,_that.usdPerImageOutput);case _:
  return null;

}
}

}

/// @nodoc


class PerCall implements CostModel {
  const PerCall({required this.usdPerCall});
  

 final  double usdPerCall;

/// Create a copy of CostModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PerCallCopyWith<PerCall> get copyWith => _$PerCallCopyWithImpl<PerCall>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PerCall&&(identical(other.usdPerCall, usdPerCall) || other.usdPerCall == usdPerCall));
}


@override
int get hashCode => Object.hash(runtimeType,usdPerCall);

@override
String toString() {
  return 'CostModel.perCall(usdPerCall: $usdPerCall)';
}


}

/// @nodoc
abstract mixin class $PerCallCopyWith<$Res> implements $CostModelCopyWith<$Res> {
  factory $PerCallCopyWith(PerCall value, $Res Function(PerCall) _then) = _$PerCallCopyWithImpl;
@useResult
$Res call({
 double usdPerCall
});




}
/// @nodoc
class _$PerCallCopyWithImpl<$Res>
    implements $PerCallCopyWith<$Res> {
  _$PerCallCopyWithImpl(this._self, this._then);

  final PerCall _self;
  final $Res Function(PerCall) _then;

/// Create a copy of CostModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? usdPerCall = null,}) {
  return _then(PerCall(
usdPerCall: null == usdPerCall ? _self.usdPerCall : usdPerCall // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class PerSecondVideo implements CostModel {
  const PerSecondVideo({required this.usdPerSecondAt1080p, required final  Map<Resolution, double> resolutionMultiplier}): _resolutionMultiplier = resolutionMultiplier;
  

 final  double usdPerSecondAt1080p;
 final  Map<Resolution, double> _resolutionMultiplier;
 Map<Resolution, double> get resolutionMultiplier {
  if (_resolutionMultiplier is EqualUnmodifiableMapView) return _resolutionMultiplier;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_resolutionMultiplier);
}


/// Create a copy of CostModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PerSecondVideoCopyWith<PerSecondVideo> get copyWith => _$PerSecondVideoCopyWithImpl<PerSecondVideo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PerSecondVideo&&(identical(other.usdPerSecondAt1080p, usdPerSecondAt1080p) || other.usdPerSecondAt1080p == usdPerSecondAt1080p)&&const DeepCollectionEquality().equals(other._resolutionMultiplier, _resolutionMultiplier));
}


@override
int get hashCode => Object.hash(runtimeType,usdPerSecondAt1080p,const DeepCollectionEquality().hash(_resolutionMultiplier));

@override
String toString() {
  return 'CostModel.perSecondVideo(usdPerSecondAt1080p: $usdPerSecondAt1080p, resolutionMultiplier: $resolutionMultiplier)';
}


}

/// @nodoc
abstract mixin class $PerSecondVideoCopyWith<$Res> implements $CostModelCopyWith<$Res> {
  factory $PerSecondVideoCopyWith(PerSecondVideo value, $Res Function(PerSecondVideo) _then) = _$PerSecondVideoCopyWithImpl;
@useResult
$Res call({
 double usdPerSecondAt1080p, Map<Resolution, double> resolutionMultiplier
});




}
/// @nodoc
class _$PerSecondVideoCopyWithImpl<$Res>
    implements $PerSecondVideoCopyWith<$Res> {
  _$PerSecondVideoCopyWithImpl(this._self, this._then);

  final PerSecondVideo _self;
  final $Res Function(PerSecondVideo) _then;

/// Create a copy of CostModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? usdPerSecondAt1080p = null,Object? resolutionMultiplier = null,}) {
  return _then(PerSecondVideo(
usdPerSecondAt1080p: null == usdPerSecondAt1080p ? _self.usdPerSecondAt1080p : usdPerSecondAt1080p // ignore: cast_nullable_to_non_nullable
as double,resolutionMultiplier: null == resolutionMultiplier ? _self._resolutionMultiplier : resolutionMultiplier // ignore: cast_nullable_to_non_nullable
as Map<Resolution, double>,
  ));
}


}

/// @nodoc


class PerCharInput implements CostModel {
  const PerCharInput({required this.usdPerKChar, required this.usdPerImageOutput});
  

 final  double usdPerKChar;
 final  double usdPerImageOutput;

/// Create a copy of CostModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PerCharInputCopyWith<PerCharInput> get copyWith => _$PerCharInputCopyWithImpl<PerCharInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PerCharInput&&(identical(other.usdPerKChar, usdPerKChar) || other.usdPerKChar == usdPerKChar)&&(identical(other.usdPerImageOutput, usdPerImageOutput) || other.usdPerImageOutput == usdPerImageOutput));
}


@override
int get hashCode => Object.hash(runtimeType,usdPerKChar,usdPerImageOutput);

@override
String toString() {
  return 'CostModel.perCharInput(usdPerKChar: $usdPerKChar, usdPerImageOutput: $usdPerImageOutput)';
}


}

/// @nodoc
abstract mixin class $PerCharInputCopyWith<$Res> implements $CostModelCopyWith<$Res> {
  factory $PerCharInputCopyWith(PerCharInput value, $Res Function(PerCharInput) _then) = _$PerCharInputCopyWithImpl;
@useResult
$Res call({
 double usdPerKChar, double usdPerImageOutput
});




}
/// @nodoc
class _$PerCharInputCopyWithImpl<$Res>
    implements $PerCharInputCopyWith<$Res> {
  _$PerCharInputCopyWithImpl(this._self, this._then);

  final PerCharInput _self;
  final $Res Function(PerCharInput) _then;

/// Create a copy of CostModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? usdPerKChar = null,Object? usdPerImageOutput = null,}) {
  return _then(PerCharInput(
usdPerKChar: null == usdPerKChar ? _self.usdPerKChar : usdPerKChar // ignore: cast_nullable_to_non_nullable
as double,usdPerImageOutput: null == usdPerImageOutput ? _self.usdPerImageOutput : usdPerImageOutput // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
