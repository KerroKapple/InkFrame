// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'generation_task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GenerationTask {

/// 目标 Provider ID（kebab-case，与 capabilities.providerId 一致）。
 String get providerId;/// 业务侧 jobId（对应 jobs.id）。Provider 层只读不写。
 String get jobId;/// 模式（决定调用哪个 Provider 端点）。
 GenerationMode get mode;/// 已完成风格注入的完整 prompt。
 String get prompt;/// 负向 prompt（若 Provider 支持）。
 String? get negativePrompt;/// 分辨率。
 Resolution get resolution;/// 比例。
 AspectRatio get aspectRatio;/// 视频时长（秒）。图片 Provider 传 0。
 int get durationSeconds;/// 运镜（视频）。
 CameraMovement? get camera;/// 参考图绝对路径列表（首尾帧单独字段）。
 List<String> get refImagePaths;/// 首帧图（视频）。
 String? get firstFramePath;/// 末帧图（视频）。
 String? get lastFramePath;/// 随机种子（若 Provider 支持）。
 int? get seed;/// 批量张数（图片 Provider）。视频固定 1。
 int get batchSize;
/// Create a copy of GenerationTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GenerationTaskCopyWith<GenerationTask> get copyWith => _$GenerationTaskCopyWithImpl<GenerationTask>(this as GenerationTask, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GenerationTask&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.negativePrompt, negativePrompt) || other.negativePrompt == negativePrompt)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.aspectRatio, aspectRatio) || other.aspectRatio == aspectRatio)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.camera, camera) || other.camera == camera)&&const DeepCollectionEquality().equals(other.refImagePaths, refImagePaths)&&(identical(other.firstFramePath, firstFramePath) || other.firstFramePath == firstFramePath)&&(identical(other.lastFramePath, lastFramePath) || other.lastFramePath == lastFramePath)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.batchSize, batchSize) || other.batchSize == batchSize));
}


@override
int get hashCode => Object.hash(runtimeType,providerId,jobId,mode,prompt,negativePrompt,resolution,aspectRatio,durationSeconds,camera,const DeepCollectionEquality().hash(refImagePaths),firstFramePath,lastFramePath,seed,batchSize);

@override
String toString() {
  return 'GenerationTask(providerId: $providerId, jobId: $jobId, mode: $mode, prompt: $prompt, negativePrompt: $negativePrompt, resolution: $resolution, aspectRatio: $aspectRatio, durationSeconds: $durationSeconds, camera: $camera, refImagePaths: $refImagePaths, firstFramePath: $firstFramePath, lastFramePath: $lastFramePath, seed: $seed, batchSize: $batchSize)';
}


}

/// @nodoc
abstract mixin class $GenerationTaskCopyWith<$Res>  {
  factory $GenerationTaskCopyWith(GenerationTask value, $Res Function(GenerationTask) _then) = _$GenerationTaskCopyWithImpl;
@useResult
$Res call({
 String providerId, String jobId, GenerationMode mode, String prompt, String? negativePrompt, Resolution resolution, AspectRatio aspectRatio, int durationSeconds, CameraMovement? camera, List<String> refImagePaths, String? firstFramePath, String? lastFramePath, int? seed, int batchSize
});




}
/// @nodoc
class _$GenerationTaskCopyWithImpl<$Res>
    implements $GenerationTaskCopyWith<$Res> {
  _$GenerationTaskCopyWithImpl(this._self, this._then);

  final GenerationTask _self;
  final $Res Function(GenerationTask) _then;

/// Create a copy of GenerationTask
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providerId = null,Object? jobId = null,Object? mode = null,Object? prompt = null,Object? negativePrompt = freezed,Object? resolution = null,Object? aspectRatio = null,Object? durationSeconds = null,Object? camera = freezed,Object? refImagePaths = null,Object? firstFramePath = freezed,Object? lastFramePath = freezed,Object? seed = freezed,Object? batchSize = null,}) {
  return _then(_self.copyWith(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as GenerationMode,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,negativePrompt: freezed == negativePrompt ? _self.negativePrompt : negativePrompt // ignore: cast_nullable_to_non_nullable
as String?,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as Resolution,aspectRatio: null == aspectRatio ? _self.aspectRatio : aspectRatio // ignore: cast_nullable_to_non_nullable
as AspectRatio,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,camera: freezed == camera ? _self.camera : camera // ignore: cast_nullable_to_non_nullable
as CameraMovement?,refImagePaths: null == refImagePaths ? _self.refImagePaths : refImagePaths // ignore: cast_nullable_to_non_nullable
as List<String>,firstFramePath: freezed == firstFramePath ? _self.firstFramePath : firstFramePath // ignore: cast_nullable_to_non_nullable
as String?,lastFramePath: freezed == lastFramePath ? _self.lastFramePath : lastFramePath // ignore: cast_nullable_to_non_nullable
as String?,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,batchSize: null == batchSize ? _self.batchSize : batchSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GenerationTask].
extension GenerationTaskPatterns on GenerationTask {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GenerationTask value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GenerationTask() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GenerationTask value)  $default,){
final _that = this;
switch (_that) {
case _GenerationTask():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GenerationTask value)?  $default,){
final _that = this;
switch (_that) {
case _GenerationTask() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String providerId,  String jobId,  GenerationMode mode,  String prompt,  String? negativePrompt,  Resolution resolution,  AspectRatio aspectRatio,  int durationSeconds,  CameraMovement? camera,  List<String> refImagePaths,  String? firstFramePath,  String? lastFramePath,  int? seed,  int batchSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GenerationTask() when $default != null:
return $default(_that.providerId,_that.jobId,_that.mode,_that.prompt,_that.negativePrompt,_that.resolution,_that.aspectRatio,_that.durationSeconds,_that.camera,_that.refImagePaths,_that.firstFramePath,_that.lastFramePath,_that.seed,_that.batchSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String providerId,  String jobId,  GenerationMode mode,  String prompt,  String? negativePrompt,  Resolution resolution,  AspectRatio aspectRatio,  int durationSeconds,  CameraMovement? camera,  List<String> refImagePaths,  String? firstFramePath,  String? lastFramePath,  int? seed,  int batchSize)  $default,) {final _that = this;
switch (_that) {
case _GenerationTask():
return $default(_that.providerId,_that.jobId,_that.mode,_that.prompt,_that.negativePrompt,_that.resolution,_that.aspectRatio,_that.durationSeconds,_that.camera,_that.refImagePaths,_that.firstFramePath,_that.lastFramePath,_that.seed,_that.batchSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String providerId,  String jobId,  GenerationMode mode,  String prompt,  String? negativePrompt,  Resolution resolution,  AspectRatio aspectRatio,  int durationSeconds,  CameraMovement? camera,  List<String> refImagePaths,  String? firstFramePath,  String? lastFramePath,  int? seed,  int batchSize)?  $default,) {final _that = this;
switch (_that) {
case _GenerationTask() when $default != null:
return $default(_that.providerId,_that.jobId,_that.mode,_that.prompt,_that.negativePrompt,_that.resolution,_that.aspectRatio,_that.durationSeconds,_that.camera,_that.refImagePaths,_that.firstFramePath,_that.lastFramePath,_that.seed,_that.batchSize);case _:
  return null;

}
}

}

/// @nodoc


class _GenerationTask implements GenerationTask {
  const _GenerationTask({required this.providerId, required this.jobId, required this.mode, required this.prompt, this.negativePrompt, required this.resolution, required this.aspectRatio, this.durationSeconds = 0, this.camera, final  List<String> refImagePaths = const <String>[], this.firstFramePath, this.lastFramePath, this.seed, this.batchSize = 1}): _refImagePaths = refImagePaths;
  

/// 目标 Provider ID（kebab-case，与 capabilities.providerId 一致）。
@override final  String providerId;
/// 业务侧 jobId（对应 jobs.id）。Provider 层只读不写。
@override final  String jobId;
/// 模式（决定调用哪个 Provider 端点）。
@override final  GenerationMode mode;
/// 已完成风格注入的完整 prompt。
@override final  String prompt;
/// 负向 prompt（若 Provider 支持）。
@override final  String? negativePrompt;
/// 分辨率。
@override final  Resolution resolution;
/// 比例。
@override final  AspectRatio aspectRatio;
/// 视频时长（秒）。图片 Provider 传 0。
@override@JsonKey() final  int durationSeconds;
/// 运镜（视频）。
@override final  CameraMovement? camera;
/// 参考图绝对路径列表（首尾帧单独字段）。
 final  List<String> _refImagePaths;
/// 参考图绝对路径列表（首尾帧单独字段）。
@override@JsonKey() List<String> get refImagePaths {
  if (_refImagePaths is EqualUnmodifiableListView) return _refImagePaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_refImagePaths);
}

/// 首帧图（视频）。
@override final  String? firstFramePath;
/// 末帧图（视频）。
@override final  String? lastFramePath;
/// 随机种子（若 Provider 支持）。
@override final  int? seed;
/// 批量张数（图片 Provider）。视频固定 1。
@override@JsonKey() final  int batchSize;

/// Create a copy of GenerationTask
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GenerationTaskCopyWith<_GenerationTask> get copyWith => __$GenerationTaskCopyWithImpl<_GenerationTask>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GenerationTask&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.negativePrompt, negativePrompt) || other.negativePrompt == negativePrompt)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.aspectRatio, aspectRatio) || other.aspectRatio == aspectRatio)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.camera, camera) || other.camera == camera)&&const DeepCollectionEquality().equals(other._refImagePaths, _refImagePaths)&&(identical(other.firstFramePath, firstFramePath) || other.firstFramePath == firstFramePath)&&(identical(other.lastFramePath, lastFramePath) || other.lastFramePath == lastFramePath)&&(identical(other.seed, seed) || other.seed == seed)&&(identical(other.batchSize, batchSize) || other.batchSize == batchSize));
}


@override
int get hashCode => Object.hash(runtimeType,providerId,jobId,mode,prompt,negativePrompt,resolution,aspectRatio,durationSeconds,camera,const DeepCollectionEquality().hash(_refImagePaths),firstFramePath,lastFramePath,seed,batchSize);

@override
String toString() {
  return 'GenerationTask(providerId: $providerId, jobId: $jobId, mode: $mode, prompt: $prompt, negativePrompt: $negativePrompt, resolution: $resolution, aspectRatio: $aspectRatio, durationSeconds: $durationSeconds, camera: $camera, refImagePaths: $refImagePaths, firstFramePath: $firstFramePath, lastFramePath: $lastFramePath, seed: $seed, batchSize: $batchSize)';
}


}

/// @nodoc
abstract mixin class _$GenerationTaskCopyWith<$Res> implements $GenerationTaskCopyWith<$Res> {
  factory _$GenerationTaskCopyWith(_GenerationTask value, $Res Function(_GenerationTask) _then) = __$GenerationTaskCopyWithImpl;
@override @useResult
$Res call({
 String providerId, String jobId, GenerationMode mode, String prompt, String? negativePrompt, Resolution resolution, AspectRatio aspectRatio, int durationSeconds, CameraMovement? camera, List<String> refImagePaths, String? firstFramePath, String? lastFramePath, int? seed, int batchSize
});




}
/// @nodoc
class __$GenerationTaskCopyWithImpl<$Res>
    implements _$GenerationTaskCopyWith<$Res> {
  __$GenerationTaskCopyWithImpl(this._self, this._then);

  final _GenerationTask _self;
  final $Res Function(_GenerationTask) _then;

/// Create a copy of GenerationTask
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providerId = null,Object? jobId = null,Object? mode = null,Object? prompt = null,Object? negativePrompt = freezed,Object? resolution = null,Object? aspectRatio = null,Object? durationSeconds = null,Object? camera = freezed,Object? refImagePaths = null,Object? firstFramePath = freezed,Object? lastFramePath = freezed,Object? seed = freezed,Object? batchSize = null,}) {
  return _then(_GenerationTask(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as GenerationMode,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,negativePrompt: freezed == negativePrompt ? _self.negativePrompt : negativePrompt // ignore: cast_nullable_to_non_nullable
as String?,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as Resolution,aspectRatio: null == aspectRatio ? _self.aspectRatio : aspectRatio // ignore: cast_nullable_to_non_nullable
as AspectRatio,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,camera: freezed == camera ? _self.camera : camera // ignore: cast_nullable_to_non_nullable
as CameraMovement?,refImagePaths: null == refImagePaths ? _self._refImagePaths : refImagePaths // ignore: cast_nullable_to_non_nullable
as List<String>,firstFramePath: freezed == firstFramePath ? _self.firstFramePath : firstFramePath // ignore: cast_nullable_to_non_nullable
as String?,lastFramePath: freezed == lastFramePath ? _self.lastFramePath : lastFramePath // ignore: cast_nullable_to_non_nullable
as String?,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,batchSize: null == batchSize ? _self.batchSize : batchSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
