// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JobState {

 String get jobId; String get providerId;
/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobStateCopyWith<JobState> get copyWith => _$JobStateCopyWithImpl<JobState>(this as JobState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobState&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.providerId, providerId) || other.providerId == providerId));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,providerId);

@override
String toString() {
  return 'JobState(jobId: $jobId, providerId: $providerId)';
}


}

/// @nodoc
abstract mixin class $JobStateCopyWith<$Res>  {
  factory $JobStateCopyWith(JobState value, $Res Function(JobState) _then) = _$JobStateCopyWithImpl;
@useResult
$Res call({
 String jobId, String providerId
});




}
/// @nodoc
class _$JobStateCopyWithImpl<$Res>
    implements $JobStateCopyWith<$Res> {
  _$JobStateCopyWithImpl(this._self, this._then);

  final JobState _self;
  final $Res Function(JobState) _then;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? jobId = null,Object? providerId = null,}) {
  return _then(_self.copyWith(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [JobState].
extension JobStatePatterns on JobState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( JobQueued value)?  queued,TResult Function( JobSubmitting value)?  submitting,TResult Function( JobRunning value)?  running,TResult Function( JobSucceeded value)?  succeeded,TResult Function( JobFailed value)?  failed,TResult Function( JobCancelled value)?  cancelled,required TResult orElse(),}){
final _that = this;
switch (_that) {
case JobQueued() when queued != null:
return queued(_that);case JobSubmitting() when submitting != null:
return submitting(_that);case JobRunning() when running != null:
return running(_that);case JobSucceeded() when succeeded != null:
return succeeded(_that);case JobFailed() when failed != null:
return failed(_that);case JobCancelled() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( JobQueued value)  queued,required TResult Function( JobSubmitting value)  submitting,required TResult Function( JobRunning value)  running,required TResult Function( JobSucceeded value)  succeeded,required TResult Function( JobFailed value)  failed,required TResult Function( JobCancelled value)  cancelled,}){
final _that = this;
switch (_that) {
case JobQueued():
return queued(_that);case JobSubmitting():
return submitting(_that);case JobRunning():
return running(_that);case JobSucceeded():
return succeeded(_that);case JobFailed():
return failed(_that);case JobCancelled():
return cancelled(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( JobQueued value)?  queued,TResult? Function( JobSubmitting value)?  submitting,TResult? Function( JobRunning value)?  running,TResult? Function( JobSucceeded value)?  succeeded,TResult? Function( JobFailed value)?  failed,TResult? Function( JobCancelled value)?  cancelled,}){
final _that = this;
switch (_that) {
case JobQueued() when queued != null:
return queued(_that);case JobSubmitting() when submitting != null:
return submitting(_that);case JobRunning() when running != null:
return running(_that);case JobSucceeded() when succeeded != null:
return succeeded(_that);case JobFailed() when failed != null:
return failed(_that);case JobCancelled() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String jobId,  String providerId)?  queued,TResult Function( String jobId,  String providerId)?  submitting,TResult Function( String jobId,  String providerId,  double progress)?  running,TResult Function( String jobId,  String providerId,  String artifactPath)?  succeeded,TResult Function( String jobId,  String providerId,  InkError error)?  failed,TResult Function( String jobId,  String providerId)?  cancelled,required TResult orElse(),}) {final _that = this;
switch (_that) {
case JobQueued() when queued != null:
return queued(_that.jobId,_that.providerId);case JobSubmitting() when submitting != null:
return submitting(_that.jobId,_that.providerId);case JobRunning() when running != null:
return running(_that.jobId,_that.providerId,_that.progress);case JobSucceeded() when succeeded != null:
return succeeded(_that.jobId,_that.providerId,_that.artifactPath);case JobFailed() when failed != null:
return failed(_that.jobId,_that.providerId,_that.error);case JobCancelled() when cancelled != null:
return cancelled(_that.jobId,_that.providerId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String jobId,  String providerId)  queued,required TResult Function( String jobId,  String providerId)  submitting,required TResult Function( String jobId,  String providerId,  double progress)  running,required TResult Function( String jobId,  String providerId,  String artifactPath)  succeeded,required TResult Function( String jobId,  String providerId,  InkError error)  failed,required TResult Function( String jobId,  String providerId)  cancelled,}) {final _that = this;
switch (_that) {
case JobQueued():
return queued(_that.jobId,_that.providerId);case JobSubmitting():
return submitting(_that.jobId,_that.providerId);case JobRunning():
return running(_that.jobId,_that.providerId,_that.progress);case JobSucceeded():
return succeeded(_that.jobId,_that.providerId,_that.artifactPath);case JobFailed():
return failed(_that.jobId,_that.providerId,_that.error);case JobCancelled():
return cancelled(_that.jobId,_that.providerId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String jobId,  String providerId)?  queued,TResult? Function( String jobId,  String providerId)?  submitting,TResult? Function( String jobId,  String providerId,  double progress)?  running,TResult? Function( String jobId,  String providerId,  String artifactPath)?  succeeded,TResult? Function( String jobId,  String providerId,  InkError error)?  failed,TResult? Function( String jobId,  String providerId)?  cancelled,}) {final _that = this;
switch (_that) {
case JobQueued() when queued != null:
return queued(_that.jobId,_that.providerId);case JobSubmitting() when submitting != null:
return submitting(_that.jobId,_that.providerId);case JobRunning() when running != null:
return running(_that.jobId,_that.providerId,_that.progress);case JobSucceeded() when succeeded != null:
return succeeded(_that.jobId,_that.providerId,_that.artifactPath);case JobFailed() when failed != null:
return failed(_that.jobId,_that.providerId,_that.error);case JobCancelled() when cancelled != null:
return cancelled(_that.jobId,_that.providerId);case _:
  return null;

}
}

}

/// @nodoc


class JobQueued implements JobState {
  const JobQueued({required this.jobId, required this.providerId});
  

@override final  String jobId;
@override final  String providerId;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobQueuedCopyWith<JobQueued> get copyWith => _$JobQueuedCopyWithImpl<JobQueued>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobQueued&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.providerId, providerId) || other.providerId == providerId));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,providerId);

@override
String toString() {
  return 'JobState.queued(jobId: $jobId, providerId: $providerId)';
}


}

/// @nodoc
abstract mixin class $JobQueuedCopyWith<$Res> implements $JobStateCopyWith<$Res> {
  factory $JobQueuedCopyWith(JobQueued value, $Res Function(JobQueued) _then) = _$JobQueuedCopyWithImpl;
@override @useResult
$Res call({
 String jobId, String providerId
});




}
/// @nodoc
class _$JobQueuedCopyWithImpl<$Res>
    implements $JobQueuedCopyWith<$Res> {
  _$JobQueuedCopyWithImpl(this._self, this._then);

  final JobQueued _self;
  final $Res Function(JobQueued) _then;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? providerId = null,}) {
  return _then(JobQueued(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class JobSubmitting implements JobState {
  const JobSubmitting({required this.jobId, required this.providerId});
  

@override final  String jobId;
@override final  String providerId;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobSubmittingCopyWith<JobSubmitting> get copyWith => _$JobSubmittingCopyWithImpl<JobSubmitting>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobSubmitting&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.providerId, providerId) || other.providerId == providerId));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,providerId);

@override
String toString() {
  return 'JobState.submitting(jobId: $jobId, providerId: $providerId)';
}


}

/// @nodoc
abstract mixin class $JobSubmittingCopyWith<$Res> implements $JobStateCopyWith<$Res> {
  factory $JobSubmittingCopyWith(JobSubmitting value, $Res Function(JobSubmitting) _then) = _$JobSubmittingCopyWithImpl;
@override @useResult
$Res call({
 String jobId, String providerId
});




}
/// @nodoc
class _$JobSubmittingCopyWithImpl<$Res>
    implements $JobSubmittingCopyWith<$Res> {
  _$JobSubmittingCopyWithImpl(this._self, this._then);

  final JobSubmitting _self;
  final $Res Function(JobSubmitting) _then;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? providerId = null,}) {
  return _then(JobSubmitting(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class JobRunning implements JobState {
  const JobRunning({required this.jobId, required this.providerId, this.progress = 0.0});
  

@override final  String jobId;
@override final  String providerId;
@JsonKey() final  double progress;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobRunningCopyWith<JobRunning> get copyWith => _$JobRunningCopyWithImpl<JobRunning>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobRunning&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,providerId,progress);

@override
String toString() {
  return 'JobState.running(jobId: $jobId, providerId: $providerId, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $JobRunningCopyWith<$Res> implements $JobStateCopyWith<$Res> {
  factory $JobRunningCopyWith(JobRunning value, $Res Function(JobRunning) _then) = _$JobRunningCopyWithImpl;
@override @useResult
$Res call({
 String jobId, String providerId, double progress
});




}
/// @nodoc
class _$JobRunningCopyWithImpl<$Res>
    implements $JobRunningCopyWith<$Res> {
  _$JobRunningCopyWithImpl(this._self, this._then);

  final JobRunning _self;
  final $Res Function(JobRunning) _then;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? providerId = null,Object? progress = null,}) {
  return _then(JobRunning(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class JobSucceeded implements JobState {
  const JobSucceeded({required this.jobId, required this.providerId, required this.artifactPath});
  

@override final  String jobId;
@override final  String providerId;
 final  String artifactPath;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobSucceededCopyWith<JobSucceeded> get copyWith => _$JobSucceededCopyWithImpl<JobSucceeded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobSucceeded&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.artifactPath, artifactPath) || other.artifactPath == artifactPath));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,providerId,artifactPath);

@override
String toString() {
  return 'JobState.succeeded(jobId: $jobId, providerId: $providerId, artifactPath: $artifactPath)';
}


}

/// @nodoc
abstract mixin class $JobSucceededCopyWith<$Res> implements $JobStateCopyWith<$Res> {
  factory $JobSucceededCopyWith(JobSucceeded value, $Res Function(JobSucceeded) _then) = _$JobSucceededCopyWithImpl;
@override @useResult
$Res call({
 String jobId, String providerId, String artifactPath
});




}
/// @nodoc
class _$JobSucceededCopyWithImpl<$Res>
    implements $JobSucceededCopyWith<$Res> {
  _$JobSucceededCopyWithImpl(this._self, this._then);

  final JobSucceeded _self;
  final $Res Function(JobSucceeded) _then;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? providerId = null,Object? artifactPath = null,}) {
  return _then(JobSucceeded(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,artifactPath: null == artifactPath ? _self.artifactPath : artifactPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class JobFailed implements JobState {
  const JobFailed({required this.jobId, required this.providerId, required this.error});
  

@override final  String jobId;
@override final  String providerId;
 final  InkError error;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobFailedCopyWith<JobFailed> get copyWith => _$JobFailedCopyWithImpl<JobFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobFailed&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,providerId,error);

@override
String toString() {
  return 'JobState.failed(jobId: $jobId, providerId: $providerId, error: $error)';
}


}

/// @nodoc
abstract mixin class $JobFailedCopyWith<$Res> implements $JobStateCopyWith<$Res> {
  factory $JobFailedCopyWith(JobFailed value, $Res Function(JobFailed) _then) = _$JobFailedCopyWithImpl;
@override @useResult
$Res call({
 String jobId, String providerId, InkError error
});




}
/// @nodoc
class _$JobFailedCopyWithImpl<$Res>
    implements $JobFailedCopyWith<$Res> {
  _$JobFailedCopyWithImpl(this._self, this._then);

  final JobFailed _self;
  final $Res Function(JobFailed) _then;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? providerId = null,Object? error = null,}) {
  return _then(JobFailed(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as InkError,
  ));
}


}

/// @nodoc


class JobCancelled implements JobState {
  const JobCancelled({required this.jobId, required this.providerId});
  

@override final  String jobId;
@override final  String providerId;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobCancelledCopyWith<JobCancelled> get copyWith => _$JobCancelledCopyWithImpl<JobCancelled>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobCancelled&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.providerId, providerId) || other.providerId == providerId));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,providerId);

@override
String toString() {
  return 'JobState.cancelled(jobId: $jobId, providerId: $providerId)';
}


}

/// @nodoc
abstract mixin class $JobCancelledCopyWith<$Res> implements $JobStateCopyWith<$Res> {
  factory $JobCancelledCopyWith(JobCancelled value, $Res Function(JobCancelled) _then) = _$JobCancelledCopyWithImpl;
@override @useResult
$Res call({
 String jobId, String providerId
});




}
/// @nodoc
class _$JobCancelledCopyWithImpl<$Res>
    implements $JobCancelledCopyWith<$Res> {
  _$JobCancelledCopyWithImpl(this._self, this._then);

  final JobCancelled _self;
  final $Res Function(JobCancelled) _then;

/// Create a copy of JobState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? providerId = null,}) {
  return _then(JobCancelled(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
