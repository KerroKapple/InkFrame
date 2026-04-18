// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JobStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'JobStatus()';
}


}

/// @nodoc
class $JobStatusCopyWith<$Res>  {
$JobStatusCopyWith(JobStatus _, $Res Function(JobStatus) __);
}


/// Adds pattern-matching-related methods to [JobStatus].
extension JobStatusPatterns on JobStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( JobInProgress value)?  inProgress,TResult Function( JobSuccess value)?  success,TResult Function( JobFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case JobInProgress() when inProgress != null:
return inProgress(_that);case JobSuccess() when success != null:
return success(_that);case JobFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( JobInProgress value)  inProgress,required TResult Function( JobSuccess value)  success,required TResult Function( JobFailure value)  failure,}){
final _that = this;
switch (_that) {
case JobInProgress():
return inProgress(_that);case JobSuccess():
return success(_that);case JobFailure():
return failure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( JobInProgress value)?  inProgress,TResult? Function( JobSuccess value)?  success,TResult? Function( JobFailure value)?  failure,}){
final _that = this;
switch (_that) {
case JobInProgress() when inProgress != null:
return inProgress(_that);case JobSuccess() when success != null:
return success(_that);case JobFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( double progress)?  inProgress,TResult Function( List<String> remoteUrls,  DateTime? urlExpiresAt,  List<Uint8List>? inlineBytes)?  success,TResult Function( InkError error)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case JobInProgress() when inProgress != null:
return inProgress(_that.progress);case JobSuccess() when success != null:
return success(_that.remoteUrls,_that.urlExpiresAt,_that.inlineBytes);case JobFailure() when failure != null:
return failure(_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( double progress)  inProgress,required TResult Function( List<String> remoteUrls,  DateTime? urlExpiresAt,  List<Uint8List>? inlineBytes)  success,required TResult Function( InkError error)  failure,}) {final _that = this;
switch (_that) {
case JobInProgress():
return inProgress(_that.progress);case JobSuccess():
return success(_that.remoteUrls,_that.urlExpiresAt,_that.inlineBytes);case JobFailure():
return failure(_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( double progress)?  inProgress,TResult? Function( List<String> remoteUrls,  DateTime? urlExpiresAt,  List<Uint8List>? inlineBytes)?  success,TResult? Function( InkError error)?  failure,}) {final _that = this;
switch (_that) {
case JobInProgress() when inProgress != null:
return inProgress(_that.progress);case JobSuccess() when success != null:
return success(_that.remoteUrls,_that.urlExpiresAt,_that.inlineBytes);case JobFailure() when failure != null:
return failure(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class JobInProgress implements JobStatus {
  const JobInProgress({this.progress = 0.0});
  

@JsonKey() final  double progress;

/// Create a copy of JobStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobInProgressCopyWith<JobInProgress> get copyWith => _$JobInProgressCopyWithImpl<JobInProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobInProgress&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,progress);

@override
String toString() {
  return 'JobStatus.inProgress(progress: $progress)';
}


}

/// @nodoc
abstract mixin class $JobInProgressCopyWith<$Res> implements $JobStatusCopyWith<$Res> {
  factory $JobInProgressCopyWith(JobInProgress value, $Res Function(JobInProgress) _then) = _$JobInProgressCopyWithImpl;
@useResult
$Res call({
 double progress
});




}
/// @nodoc
class _$JobInProgressCopyWithImpl<$Res>
    implements $JobInProgressCopyWith<$Res> {
  _$JobInProgressCopyWithImpl(this._self, this._then);

  final JobInProgress _self;
  final $Res Function(JobInProgress) _then;

/// Create a copy of JobStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? progress = null,}) {
  return _then(JobInProgress(
progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class JobSuccess implements JobStatus {
  const JobSuccess({required final  List<String> remoteUrls, this.urlExpiresAt, final  List<Uint8List>? inlineBytes}): _remoteUrls = remoteUrls,_inlineBytes = inlineBytes;
  

 final  List<String> _remoteUrls;
 List<String> get remoteUrls {
  if (_remoteUrls is EqualUnmodifiableListView) return _remoteUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_remoteUrls);
}

 final  DateTime? urlExpiresAt;
 final  List<Uint8List>? _inlineBytes;
 List<Uint8List>? get inlineBytes {
  final value = _inlineBytes;
  if (value == null) return null;
  if (_inlineBytes is EqualUnmodifiableListView) return _inlineBytes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of JobStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobSuccessCopyWith<JobSuccess> get copyWith => _$JobSuccessCopyWithImpl<JobSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobSuccess&&const DeepCollectionEquality().equals(other._remoteUrls, _remoteUrls)&&(identical(other.urlExpiresAt, urlExpiresAt) || other.urlExpiresAt == urlExpiresAt)&&const DeepCollectionEquality().equals(other._inlineBytes, _inlineBytes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_remoteUrls),urlExpiresAt,const DeepCollectionEquality().hash(_inlineBytes));

@override
String toString() {
  return 'JobStatus.success(remoteUrls: $remoteUrls, urlExpiresAt: $urlExpiresAt, inlineBytes: $inlineBytes)';
}


}

/// @nodoc
abstract mixin class $JobSuccessCopyWith<$Res> implements $JobStatusCopyWith<$Res> {
  factory $JobSuccessCopyWith(JobSuccess value, $Res Function(JobSuccess) _then) = _$JobSuccessCopyWithImpl;
@useResult
$Res call({
 List<String> remoteUrls, DateTime? urlExpiresAt, List<Uint8List>? inlineBytes
});




}
/// @nodoc
class _$JobSuccessCopyWithImpl<$Res>
    implements $JobSuccessCopyWith<$Res> {
  _$JobSuccessCopyWithImpl(this._self, this._then);

  final JobSuccess _self;
  final $Res Function(JobSuccess) _then;

/// Create a copy of JobStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? remoteUrls = null,Object? urlExpiresAt = freezed,Object? inlineBytes = freezed,}) {
  return _then(JobSuccess(
remoteUrls: null == remoteUrls ? _self._remoteUrls : remoteUrls // ignore: cast_nullable_to_non_nullable
as List<String>,urlExpiresAt: freezed == urlExpiresAt ? _self.urlExpiresAt : urlExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,inlineBytes: freezed == inlineBytes ? _self._inlineBytes : inlineBytes // ignore: cast_nullable_to_non_nullable
as List<Uint8List>?,
  ));
}


}

/// @nodoc


class JobFailure implements JobStatus {
  const JobFailure({required this.error});
  

 final  InkError error;

/// Create a copy of JobStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobFailureCopyWith<JobFailure> get copyWith => _$JobFailureCopyWithImpl<JobFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobFailure&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'JobStatus.failure(error: $error)';
}


}

/// @nodoc
abstract mixin class $JobFailureCopyWith<$Res> implements $JobStatusCopyWith<$Res> {
  factory $JobFailureCopyWith(JobFailure value, $Res Function(JobFailure) _then) = _$JobFailureCopyWithImpl;
@useResult
$Res call({
 InkError error
});




}
/// @nodoc
class _$JobFailureCopyWithImpl<$Res>
    implements $JobFailureCopyWith<$Res> {
  _$JobFailureCopyWithImpl(this._self, this._then);

  final JobFailure _self;
  final $Res Function(JobFailure) _then;

/// Create a copy of JobStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(JobFailure(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as InkError,
  ));
}


}

// dart format on
