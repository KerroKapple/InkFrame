// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_capabilities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProviderCapabilities {

 String get providerId; String? get displayName; ProviderRegion get region; List<GenerationMode> get modes; List<AspectRatio> get supportedRatios; List<Resolution> get supportedResolutions; List<int> get supportedDurations; List<CameraMovement> get supportedCameras; int get maxBatchSize; int get maxRefImages; bool get refImagesIncludeKeyframes; bool get supportsFirstFrame; bool get supportsLastFrame; bool get supportsNegativePrompt; bool get supportsSeed; bool get supportsSound; bool get supportsBatch; bool get supportsCancellation; bool get supportsPolling; CostModel get costModel; int get maxConcurrentJobs; int get qps; int get burst; Duration? get pollInterval; Duration? get pollTimeout;
/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderCapabilitiesCopyWith<ProviderCapabilities> get copyWith => _$ProviderCapabilitiesCopyWithImpl<ProviderCapabilities>(this as ProviderCapabilities, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderCapabilities&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.region, region) || other.region == region)&&const DeepCollectionEquality().equals(other.modes, modes)&&const DeepCollectionEquality().equals(other.supportedRatios, supportedRatios)&&const DeepCollectionEquality().equals(other.supportedResolutions, supportedResolutions)&&const DeepCollectionEquality().equals(other.supportedDurations, supportedDurations)&&const DeepCollectionEquality().equals(other.supportedCameras, supportedCameras)&&(identical(other.maxBatchSize, maxBatchSize) || other.maxBatchSize == maxBatchSize)&&(identical(other.maxRefImages, maxRefImages) || other.maxRefImages == maxRefImages)&&(identical(other.refImagesIncludeKeyframes, refImagesIncludeKeyframes) || other.refImagesIncludeKeyframes == refImagesIncludeKeyframes)&&(identical(other.supportsFirstFrame, supportsFirstFrame) || other.supportsFirstFrame == supportsFirstFrame)&&(identical(other.supportsLastFrame, supportsLastFrame) || other.supportsLastFrame == supportsLastFrame)&&(identical(other.supportsNegativePrompt, supportsNegativePrompt) || other.supportsNegativePrompt == supportsNegativePrompt)&&(identical(other.supportsSeed, supportsSeed) || other.supportsSeed == supportsSeed)&&(identical(other.supportsSound, supportsSound) || other.supportsSound == supportsSound)&&(identical(other.supportsBatch, supportsBatch) || other.supportsBatch == supportsBatch)&&(identical(other.supportsCancellation, supportsCancellation) || other.supportsCancellation == supportsCancellation)&&(identical(other.supportsPolling, supportsPolling) || other.supportsPolling == supportsPolling)&&(identical(other.costModel, costModel) || other.costModel == costModel)&&(identical(other.maxConcurrentJobs, maxConcurrentJobs) || other.maxConcurrentJobs == maxConcurrentJobs)&&(identical(other.qps, qps) || other.qps == qps)&&(identical(other.burst, burst) || other.burst == burst)&&(identical(other.pollInterval, pollInterval) || other.pollInterval == pollInterval)&&(identical(other.pollTimeout, pollTimeout) || other.pollTimeout == pollTimeout));
}


@override
int get hashCode => Object.hashAll([runtimeType,providerId,displayName,region,const DeepCollectionEquality().hash(modes),const DeepCollectionEquality().hash(supportedRatios),const DeepCollectionEquality().hash(supportedResolutions),const DeepCollectionEquality().hash(supportedDurations),const DeepCollectionEquality().hash(supportedCameras),maxBatchSize,maxRefImages,refImagesIncludeKeyframes,supportsFirstFrame,supportsLastFrame,supportsNegativePrompt,supportsSeed,supportsSound,supportsBatch,supportsCancellation,supportsPolling,costModel,maxConcurrentJobs,qps,burst,pollInterval,pollTimeout]);

@override
String toString() {
  return 'ProviderCapabilities(providerId: $providerId, displayName: $displayName, region: $region, modes: $modes, supportedRatios: $supportedRatios, supportedResolutions: $supportedResolutions, supportedDurations: $supportedDurations, supportedCameras: $supportedCameras, maxBatchSize: $maxBatchSize, maxRefImages: $maxRefImages, refImagesIncludeKeyframes: $refImagesIncludeKeyframes, supportsFirstFrame: $supportsFirstFrame, supportsLastFrame: $supportsLastFrame, supportsNegativePrompt: $supportsNegativePrompt, supportsSeed: $supportsSeed, supportsSound: $supportsSound, supportsBatch: $supportsBatch, supportsCancellation: $supportsCancellation, supportsPolling: $supportsPolling, costModel: $costModel, maxConcurrentJobs: $maxConcurrentJobs, qps: $qps, burst: $burst, pollInterval: $pollInterval, pollTimeout: $pollTimeout)';
}


}

/// @nodoc
abstract mixin class $ProviderCapabilitiesCopyWith<$Res>  {
  factory $ProviderCapabilitiesCopyWith(ProviderCapabilities value, $Res Function(ProviderCapabilities) _then) = _$ProviderCapabilitiesCopyWithImpl;
@useResult
$Res call({
 String providerId, String? displayName, ProviderRegion region, List<GenerationMode> modes, List<AspectRatio> supportedRatios, List<Resolution> supportedResolutions, List<int> supportedDurations, List<CameraMovement> supportedCameras, int maxBatchSize, int maxRefImages, bool refImagesIncludeKeyframes, bool supportsFirstFrame, bool supportsLastFrame, bool supportsNegativePrompt, bool supportsSeed, bool supportsSound, bool supportsBatch, bool supportsCancellation, bool supportsPolling, CostModel costModel, int maxConcurrentJobs, int qps, int burst, Duration? pollInterval, Duration? pollTimeout
});


$CostModelCopyWith<$Res> get costModel;

}
/// @nodoc
class _$ProviderCapabilitiesCopyWithImpl<$Res>
    implements $ProviderCapabilitiesCopyWith<$Res> {
  _$ProviderCapabilitiesCopyWithImpl(this._self, this._then);

  final ProviderCapabilities _self;
  final $Res Function(ProviderCapabilities) _then;

/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providerId = null,Object? displayName = freezed,Object? region = null,Object? modes = null,Object? supportedRatios = null,Object? supportedResolutions = null,Object? supportedDurations = null,Object? supportedCameras = null,Object? maxBatchSize = null,Object? maxRefImages = null,Object? refImagesIncludeKeyframes = null,Object? supportsFirstFrame = null,Object? supportsLastFrame = null,Object? supportsNegativePrompt = null,Object? supportsSeed = null,Object? supportsSound = null,Object? supportsBatch = null,Object? supportsCancellation = null,Object? supportsPolling = null,Object? costModel = null,Object? maxConcurrentJobs = null,Object? qps = null,Object? burst = null,Object? pollInterval = freezed,Object? pollTimeout = freezed,}) {
  return _then(_self.copyWith(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as ProviderRegion,modes: null == modes ? _self.modes : modes // ignore: cast_nullable_to_non_nullable
as List<GenerationMode>,supportedRatios: null == supportedRatios ? _self.supportedRatios : supportedRatios // ignore: cast_nullable_to_non_nullable
as List<AspectRatio>,supportedResolutions: null == supportedResolutions ? _self.supportedResolutions : supportedResolutions // ignore: cast_nullable_to_non_nullable
as List<Resolution>,supportedDurations: null == supportedDurations ? _self.supportedDurations : supportedDurations // ignore: cast_nullable_to_non_nullable
as List<int>,supportedCameras: null == supportedCameras ? _self.supportedCameras : supportedCameras // ignore: cast_nullable_to_non_nullable
as List<CameraMovement>,maxBatchSize: null == maxBatchSize ? _self.maxBatchSize : maxBatchSize // ignore: cast_nullable_to_non_nullable
as int,maxRefImages: null == maxRefImages ? _self.maxRefImages : maxRefImages // ignore: cast_nullable_to_non_nullable
as int,refImagesIncludeKeyframes: null == refImagesIncludeKeyframes ? _self.refImagesIncludeKeyframes : refImagesIncludeKeyframes // ignore: cast_nullable_to_non_nullable
as bool,supportsFirstFrame: null == supportsFirstFrame ? _self.supportsFirstFrame : supportsFirstFrame // ignore: cast_nullable_to_non_nullable
as bool,supportsLastFrame: null == supportsLastFrame ? _self.supportsLastFrame : supportsLastFrame // ignore: cast_nullable_to_non_nullable
as bool,supportsNegativePrompt: null == supportsNegativePrompt ? _self.supportsNegativePrompt : supportsNegativePrompt // ignore: cast_nullable_to_non_nullable
as bool,supportsSeed: null == supportsSeed ? _self.supportsSeed : supportsSeed // ignore: cast_nullable_to_non_nullable
as bool,supportsSound: null == supportsSound ? _self.supportsSound : supportsSound // ignore: cast_nullable_to_non_nullable
as bool,supportsBatch: null == supportsBatch ? _self.supportsBatch : supportsBatch // ignore: cast_nullable_to_non_nullable
as bool,supportsCancellation: null == supportsCancellation ? _self.supportsCancellation : supportsCancellation // ignore: cast_nullable_to_non_nullable
as bool,supportsPolling: null == supportsPolling ? _self.supportsPolling : supportsPolling // ignore: cast_nullable_to_non_nullable
as bool,costModel: null == costModel ? _self.costModel : costModel // ignore: cast_nullable_to_non_nullable
as CostModel,maxConcurrentJobs: null == maxConcurrentJobs ? _self.maxConcurrentJobs : maxConcurrentJobs // ignore: cast_nullable_to_non_nullable
as int,qps: null == qps ? _self.qps : qps // ignore: cast_nullable_to_non_nullable
as int,burst: null == burst ? _self.burst : burst // ignore: cast_nullable_to_non_nullable
as int,pollInterval: freezed == pollInterval ? _self.pollInterval : pollInterval // ignore: cast_nullable_to_non_nullable
as Duration?,pollTimeout: freezed == pollTimeout ? _self.pollTimeout : pollTimeout // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}
/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CostModelCopyWith<$Res> get costModel {
  
  return $CostModelCopyWith<$Res>(_self.costModel, (value) {
    return _then(_self.copyWith(costModel: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProviderCapabilities].
extension ProviderCapabilitiesPatterns on ProviderCapabilities {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderCapabilities() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _ProviderCapabilities():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderCapabilities() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String providerId,  String? displayName,  ProviderRegion region,  List<GenerationMode> modes,  List<AspectRatio> supportedRatios,  List<Resolution> supportedResolutions,  List<int> supportedDurations,  List<CameraMovement> supportedCameras,  int maxBatchSize,  int maxRefImages,  bool refImagesIncludeKeyframes,  bool supportsFirstFrame,  bool supportsLastFrame,  bool supportsNegativePrompt,  bool supportsSeed,  bool supportsSound,  bool supportsBatch,  bool supportsCancellation,  bool supportsPolling,  CostModel costModel,  int maxConcurrentJobs,  int qps,  int burst,  Duration? pollInterval,  Duration? pollTimeout)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderCapabilities() when $default != null:
return $default(_that.providerId,_that.displayName,_that.region,_that.modes,_that.supportedRatios,_that.supportedResolutions,_that.supportedDurations,_that.supportedCameras,_that.maxBatchSize,_that.maxRefImages,_that.refImagesIncludeKeyframes,_that.supportsFirstFrame,_that.supportsLastFrame,_that.supportsNegativePrompt,_that.supportsSeed,_that.supportsSound,_that.supportsBatch,_that.supportsCancellation,_that.supportsPolling,_that.costModel,_that.maxConcurrentJobs,_that.qps,_that.burst,_that.pollInterval,_that.pollTimeout);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String providerId,  String? displayName,  ProviderRegion region,  List<GenerationMode> modes,  List<AspectRatio> supportedRatios,  List<Resolution> supportedResolutions,  List<int> supportedDurations,  List<CameraMovement> supportedCameras,  int maxBatchSize,  int maxRefImages,  bool refImagesIncludeKeyframes,  bool supportsFirstFrame,  bool supportsLastFrame,  bool supportsNegativePrompt,  bool supportsSeed,  bool supportsSound,  bool supportsBatch,  bool supportsCancellation,  bool supportsPolling,  CostModel costModel,  int maxConcurrentJobs,  int qps,  int burst,  Duration? pollInterval,  Duration? pollTimeout)  $default,) {final _that = this;
switch (_that) {
case _ProviderCapabilities():
return $default(_that.providerId,_that.displayName,_that.region,_that.modes,_that.supportedRatios,_that.supportedResolutions,_that.supportedDurations,_that.supportedCameras,_that.maxBatchSize,_that.maxRefImages,_that.refImagesIncludeKeyframes,_that.supportsFirstFrame,_that.supportsLastFrame,_that.supportsNegativePrompt,_that.supportsSeed,_that.supportsSound,_that.supportsBatch,_that.supportsCancellation,_that.supportsPolling,_that.costModel,_that.maxConcurrentJobs,_that.qps,_that.burst,_that.pollInterval,_that.pollTimeout);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String providerId,  String? displayName,  ProviderRegion region,  List<GenerationMode> modes,  List<AspectRatio> supportedRatios,  List<Resolution> supportedResolutions,  List<int> supportedDurations,  List<CameraMovement> supportedCameras,  int maxBatchSize,  int maxRefImages,  bool refImagesIncludeKeyframes,  bool supportsFirstFrame,  bool supportsLastFrame,  bool supportsNegativePrompt,  bool supportsSeed,  bool supportsSound,  bool supportsBatch,  bool supportsCancellation,  bool supportsPolling,  CostModel costModel,  int maxConcurrentJobs,  int qps,  int burst,  Duration? pollInterval,  Duration? pollTimeout)?  $default,) {final _that = this;
switch (_that) {
case _ProviderCapabilities() when $default != null:
return $default(_that.providerId,_that.displayName,_that.region,_that.modes,_that.supportedRatios,_that.supportedResolutions,_that.supportedDurations,_that.supportedCameras,_that.maxBatchSize,_that.maxRefImages,_that.refImagesIncludeKeyframes,_that.supportsFirstFrame,_that.supportsLastFrame,_that.supportsNegativePrompt,_that.supportsSeed,_that.supportsSound,_that.supportsBatch,_that.supportsCancellation,_that.supportsPolling,_that.costModel,_that.maxConcurrentJobs,_that.qps,_that.burst,_that.pollInterval,_that.pollTimeout);case _:
  return null;

}
}

}

/// @nodoc


class _ProviderCapabilities implements ProviderCapabilities {
  const _ProviderCapabilities({required this.providerId, this.displayName, required this.region, required final  List<GenerationMode> modes, required final  List<AspectRatio> supportedRatios, required final  List<Resolution> supportedResolutions, required final  List<int> supportedDurations, required final  List<CameraMovement> supportedCameras, required this.maxBatchSize, required this.maxRefImages, required this.refImagesIncludeKeyframes, required this.supportsFirstFrame, required this.supportsLastFrame, required this.supportsNegativePrompt, required this.supportsSeed, required this.supportsSound, required this.supportsBatch, required this.supportsCancellation, required this.supportsPolling, required this.costModel, required this.maxConcurrentJobs, required this.qps, required this.burst, this.pollInterval, this.pollTimeout}): _modes = modes,_supportedRatios = supportedRatios,_supportedResolutions = supportedResolutions,_supportedDurations = supportedDurations,_supportedCameras = supportedCameras;
  

@override final  String providerId;
@override final  String? displayName;
@override final  ProviderRegion region;
 final  List<GenerationMode> _modes;
@override List<GenerationMode> get modes {
  if (_modes is EqualUnmodifiableListView) return _modes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modes);
}

 final  List<AspectRatio> _supportedRatios;
@override List<AspectRatio> get supportedRatios {
  if (_supportedRatios is EqualUnmodifiableListView) return _supportedRatios;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedRatios);
}

 final  List<Resolution> _supportedResolutions;
@override List<Resolution> get supportedResolutions {
  if (_supportedResolutions is EqualUnmodifiableListView) return _supportedResolutions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedResolutions);
}

 final  List<int> _supportedDurations;
@override List<int> get supportedDurations {
  if (_supportedDurations is EqualUnmodifiableListView) return _supportedDurations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedDurations);
}

 final  List<CameraMovement> _supportedCameras;
@override List<CameraMovement> get supportedCameras {
  if (_supportedCameras is EqualUnmodifiableListView) return _supportedCameras;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedCameras);
}

@override final  int maxBatchSize;
@override final  int maxRefImages;
@override final  bool refImagesIncludeKeyframes;
@override final  bool supportsFirstFrame;
@override final  bool supportsLastFrame;
@override final  bool supportsNegativePrompt;
@override final  bool supportsSeed;
@override final  bool supportsSound;
@override final  bool supportsBatch;
@override final  bool supportsCancellation;
@override final  bool supportsPolling;
@override final  CostModel costModel;
@override final  int maxConcurrentJobs;
@override final  int qps;
@override final  int burst;
@override final  Duration? pollInterval;
@override final  Duration? pollTimeout;

/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderCapabilitiesCopyWith<_ProviderCapabilities> get copyWith => __$ProviderCapabilitiesCopyWithImpl<_ProviderCapabilities>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderCapabilities&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.region, region) || other.region == region)&&const DeepCollectionEquality().equals(other._modes, _modes)&&const DeepCollectionEquality().equals(other._supportedRatios, _supportedRatios)&&const DeepCollectionEquality().equals(other._supportedResolutions, _supportedResolutions)&&const DeepCollectionEquality().equals(other._supportedDurations, _supportedDurations)&&const DeepCollectionEquality().equals(other._supportedCameras, _supportedCameras)&&(identical(other.maxBatchSize, maxBatchSize) || other.maxBatchSize == maxBatchSize)&&(identical(other.maxRefImages, maxRefImages) || other.maxRefImages == maxRefImages)&&(identical(other.refImagesIncludeKeyframes, refImagesIncludeKeyframes) || other.refImagesIncludeKeyframes == refImagesIncludeKeyframes)&&(identical(other.supportsFirstFrame, supportsFirstFrame) || other.supportsFirstFrame == supportsFirstFrame)&&(identical(other.supportsLastFrame, supportsLastFrame) || other.supportsLastFrame == supportsLastFrame)&&(identical(other.supportsNegativePrompt, supportsNegativePrompt) || other.supportsNegativePrompt == supportsNegativePrompt)&&(identical(other.supportsSeed, supportsSeed) || other.supportsSeed == supportsSeed)&&(identical(other.supportsSound, supportsSound) || other.supportsSound == supportsSound)&&(identical(other.supportsBatch, supportsBatch) || other.supportsBatch == supportsBatch)&&(identical(other.supportsCancellation, supportsCancellation) || other.supportsCancellation == supportsCancellation)&&(identical(other.supportsPolling, supportsPolling) || other.supportsPolling == supportsPolling)&&(identical(other.costModel, costModel) || other.costModel == costModel)&&(identical(other.maxConcurrentJobs, maxConcurrentJobs) || other.maxConcurrentJobs == maxConcurrentJobs)&&(identical(other.qps, qps) || other.qps == qps)&&(identical(other.burst, burst) || other.burst == burst)&&(identical(other.pollInterval, pollInterval) || other.pollInterval == pollInterval)&&(identical(other.pollTimeout, pollTimeout) || other.pollTimeout == pollTimeout));
}


@override
int get hashCode => Object.hashAll([runtimeType,providerId,displayName,region,const DeepCollectionEquality().hash(_modes),const DeepCollectionEquality().hash(_supportedRatios),const DeepCollectionEquality().hash(_supportedResolutions),const DeepCollectionEquality().hash(_supportedDurations),const DeepCollectionEquality().hash(_supportedCameras),maxBatchSize,maxRefImages,refImagesIncludeKeyframes,supportsFirstFrame,supportsLastFrame,supportsNegativePrompt,supportsSeed,supportsSound,supportsBatch,supportsCancellation,supportsPolling,costModel,maxConcurrentJobs,qps,burst,pollInterval,pollTimeout]);

@override
String toString() {
  return 'ProviderCapabilities(providerId: $providerId, displayName: $displayName, region: $region, modes: $modes, supportedRatios: $supportedRatios, supportedResolutions: $supportedResolutions, supportedDurations: $supportedDurations, supportedCameras: $supportedCameras, maxBatchSize: $maxBatchSize, maxRefImages: $maxRefImages, refImagesIncludeKeyframes: $refImagesIncludeKeyframes, supportsFirstFrame: $supportsFirstFrame, supportsLastFrame: $supportsLastFrame, supportsNegativePrompt: $supportsNegativePrompt, supportsSeed: $supportsSeed, supportsSound: $supportsSound, supportsBatch: $supportsBatch, supportsCancellation: $supportsCancellation, supportsPolling: $supportsPolling, costModel: $costModel, maxConcurrentJobs: $maxConcurrentJobs, qps: $qps, burst: $burst, pollInterval: $pollInterval, pollTimeout: $pollTimeout)';
}


}

/// @nodoc
abstract mixin class _$ProviderCapabilitiesCopyWith<$Res> implements $ProviderCapabilitiesCopyWith<$Res> {
  factory _$ProviderCapabilitiesCopyWith(_ProviderCapabilities value, $Res Function(_ProviderCapabilities) _then) = __$ProviderCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 String providerId, String? displayName, ProviderRegion region, List<GenerationMode> modes, List<AspectRatio> supportedRatios, List<Resolution> supportedResolutions, List<int> supportedDurations, List<CameraMovement> supportedCameras, int maxBatchSize, int maxRefImages, bool refImagesIncludeKeyframes, bool supportsFirstFrame, bool supportsLastFrame, bool supportsNegativePrompt, bool supportsSeed, bool supportsSound, bool supportsBatch, bool supportsCancellation, bool supportsPolling, CostModel costModel, int maxConcurrentJobs, int qps, int burst, Duration? pollInterval, Duration? pollTimeout
});


@override $CostModelCopyWith<$Res> get costModel;

}
/// @nodoc
class __$ProviderCapabilitiesCopyWithImpl<$Res>
    implements _$ProviderCapabilitiesCopyWith<$Res> {
  __$ProviderCapabilitiesCopyWithImpl(this._self, this._then);

  final _ProviderCapabilities _self;
  final $Res Function(_ProviderCapabilities) _then;

/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providerId = null,Object? displayName = freezed,Object? region = null,Object? modes = null,Object? supportedRatios = null,Object? supportedResolutions = null,Object? supportedDurations = null,Object? supportedCameras = null,Object? maxBatchSize = null,Object? maxRefImages = null,Object? refImagesIncludeKeyframes = null,Object? supportsFirstFrame = null,Object? supportsLastFrame = null,Object? supportsNegativePrompt = null,Object? supportsSeed = null,Object? supportsSound = null,Object? supportsBatch = null,Object? supportsCancellation = null,Object? supportsPolling = null,Object? costModel = null,Object? maxConcurrentJobs = null,Object? qps = null,Object? burst = null,Object? pollInterval = freezed,Object? pollTimeout = freezed,}) {
  return _then(_ProviderCapabilities(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as ProviderRegion,modes: null == modes ? _self._modes : modes // ignore: cast_nullable_to_non_nullable
as List<GenerationMode>,supportedRatios: null == supportedRatios ? _self._supportedRatios : supportedRatios // ignore: cast_nullable_to_non_nullable
as List<AspectRatio>,supportedResolutions: null == supportedResolutions ? _self._supportedResolutions : supportedResolutions // ignore: cast_nullable_to_non_nullable
as List<Resolution>,supportedDurations: null == supportedDurations ? _self._supportedDurations : supportedDurations // ignore: cast_nullable_to_non_nullable
as List<int>,supportedCameras: null == supportedCameras ? _self._supportedCameras : supportedCameras // ignore: cast_nullable_to_non_nullable
as List<CameraMovement>,maxBatchSize: null == maxBatchSize ? _self.maxBatchSize : maxBatchSize // ignore: cast_nullable_to_non_nullable
as int,maxRefImages: null == maxRefImages ? _self.maxRefImages : maxRefImages // ignore: cast_nullable_to_non_nullable
as int,refImagesIncludeKeyframes: null == refImagesIncludeKeyframes ? _self.refImagesIncludeKeyframes : refImagesIncludeKeyframes // ignore: cast_nullable_to_non_nullable
as bool,supportsFirstFrame: null == supportsFirstFrame ? _self.supportsFirstFrame : supportsFirstFrame // ignore: cast_nullable_to_non_nullable
as bool,supportsLastFrame: null == supportsLastFrame ? _self.supportsLastFrame : supportsLastFrame // ignore: cast_nullable_to_non_nullable
as bool,supportsNegativePrompt: null == supportsNegativePrompt ? _self.supportsNegativePrompt : supportsNegativePrompt // ignore: cast_nullable_to_non_nullable
as bool,supportsSeed: null == supportsSeed ? _self.supportsSeed : supportsSeed // ignore: cast_nullable_to_non_nullable
as bool,supportsSound: null == supportsSound ? _self.supportsSound : supportsSound // ignore: cast_nullable_to_non_nullable
as bool,supportsBatch: null == supportsBatch ? _self.supportsBatch : supportsBatch // ignore: cast_nullable_to_non_nullable
as bool,supportsCancellation: null == supportsCancellation ? _self.supportsCancellation : supportsCancellation // ignore: cast_nullable_to_non_nullable
as bool,supportsPolling: null == supportsPolling ? _self.supportsPolling : supportsPolling // ignore: cast_nullable_to_non_nullable
as bool,costModel: null == costModel ? _self.costModel : costModel // ignore: cast_nullable_to_non_nullable
as CostModel,maxConcurrentJobs: null == maxConcurrentJobs ? _self.maxConcurrentJobs : maxConcurrentJobs // ignore: cast_nullable_to_non_nullable
as int,qps: null == qps ? _self.qps : qps // ignore: cast_nullable_to_non_nullable
as int,burst: null == burst ? _self.burst : burst // ignore: cast_nullable_to_non_nullable
as int,pollInterval: freezed == pollInterval ? _self.pollInterval : pollInterval // ignore: cast_nullable_to_non_nullable
as Duration?,pollTimeout: freezed == pollTimeout ? _self.pollTimeout : pollTimeout // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}

/// Create a copy of ProviderCapabilities
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CostModelCopyWith<$Res> get costModel {
  
  return $CostModelCopyWith<$Res>(_self.costModel, (value) {
    return _then(_self.copyWith(costModel: value));
  });
}
}

// dart format on
