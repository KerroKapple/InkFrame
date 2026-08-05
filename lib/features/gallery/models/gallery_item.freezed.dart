// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gallery_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GalleryItem {

 GalleryItemKind get kind;/// canvas 相对路径（images/... 或 videos/...）。
 String get relativePath;/// 来源画布（路径解析 + caption 展示）。
 String get canvasId; String get canvasName;/// 来源节点；批量 slot 为其挂载的结果节点。
 String get nodeId; DateTime get createdAt;/// 批量 slot 来源时的槽位序号；节点主产物为 null。
 int? get slotIndex;/// 视频时长（毫秒）；未知为 null。
 int? get durationMs;/// 视频首帧缩略图的 canvas 相对路径（GA-1：读节点已落库的
/// thumbnail_url，非现场抽帧）；图片/未抽帧视频为 null。
 String? get thumbnailRelativePath;
/// Create a copy of GalleryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GalleryItemCopyWith<GalleryItem> get copyWith => _$GalleryItemCopyWithImpl<GalleryItem>(this as GalleryItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GalleryItem&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.relativePath, relativePath) || other.relativePath == relativePath)&&(identical(other.canvasId, canvasId) || other.canvasId == canvasId)&&(identical(other.canvasName, canvasName) || other.canvasName == canvasName)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.slotIndex, slotIndex) || other.slotIndex == slotIndex)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.thumbnailRelativePath, thumbnailRelativePath) || other.thumbnailRelativePath == thumbnailRelativePath));
}


@override
int get hashCode => Object.hash(runtimeType,kind,relativePath,canvasId,canvasName,nodeId,createdAt,slotIndex,durationMs,thumbnailRelativePath);

@override
String toString() {
  return 'GalleryItem(kind: $kind, relativePath: $relativePath, canvasId: $canvasId, canvasName: $canvasName, nodeId: $nodeId, createdAt: $createdAt, slotIndex: $slotIndex, durationMs: $durationMs, thumbnailRelativePath: $thumbnailRelativePath)';
}


}

/// @nodoc
abstract mixin class $GalleryItemCopyWith<$Res>  {
  factory $GalleryItemCopyWith(GalleryItem value, $Res Function(GalleryItem) _then) = _$GalleryItemCopyWithImpl;
@useResult
$Res call({
 GalleryItemKind kind, String relativePath, String canvasId, String canvasName, String nodeId, DateTime createdAt, int? slotIndex, int? durationMs, String? thumbnailRelativePath
});




}
/// @nodoc
class _$GalleryItemCopyWithImpl<$Res>
    implements $GalleryItemCopyWith<$Res> {
  _$GalleryItemCopyWithImpl(this._self, this._then);

  final GalleryItem _self;
  final $Res Function(GalleryItem) _then;

/// Create a copy of GalleryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? relativePath = null,Object? canvasId = null,Object? canvasName = null,Object? nodeId = null,Object? createdAt = null,Object? slotIndex = freezed,Object? durationMs = freezed,Object? thumbnailRelativePath = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GalleryItemKind,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,canvasId: null == canvasId ? _self.canvasId : canvasId // ignore: cast_nullable_to_non_nullable
as String,canvasName: null == canvasName ? _self.canvasName : canvasName // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,slotIndex: freezed == slotIndex ? _self.slotIndex : slotIndex // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,thumbnailRelativePath: freezed == thumbnailRelativePath ? _self.thumbnailRelativePath : thumbnailRelativePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GalleryItem].
extension GalleryItemPatterns on GalleryItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GalleryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GalleryItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GalleryItem value)  $default,){
final _that = this;
switch (_that) {
case _GalleryItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GalleryItem value)?  $default,){
final _that = this;
switch (_that) {
case _GalleryItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GalleryItemKind kind,  String relativePath,  String canvasId,  String canvasName,  String nodeId,  DateTime createdAt,  int? slotIndex,  int? durationMs,  String? thumbnailRelativePath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GalleryItem() when $default != null:
return $default(_that.kind,_that.relativePath,_that.canvasId,_that.canvasName,_that.nodeId,_that.createdAt,_that.slotIndex,_that.durationMs,_that.thumbnailRelativePath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GalleryItemKind kind,  String relativePath,  String canvasId,  String canvasName,  String nodeId,  DateTime createdAt,  int? slotIndex,  int? durationMs,  String? thumbnailRelativePath)  $default,) {final _that = this;
switch (_that) {
case _GalleryItem():
return $default(_that.kind,_that.relativePath,_that.canvasId,_that.canvasName,_that.nodeId,_that.createdAt,_that.slotIndex,_that.durationMs,_that.thumbnailRelativePath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GalleryItemKind kind,  String relativePath,  String canvasId,  String canvasName,  String nodeId,  DateTime createdAt,  int? slotIndex,  int? durationMs,  String? thumbnailRelativePath)?  $default,) {final _that = this;
switch (_that) {
case _GalleryItem() when $default != null:
return $default(_that.kind,_that.relativePath,_that.canvasId,_that.canvasName,_that.nodeId,_that.createdAt,_that.slotIndex,_that.durationMs,_that.thumbnailRelativePath);case _:
  return null;

}
}

}

/// @nodoc


class _GalleryItem implements GalleryItem {
  const _GalleryItem({required this.kind, required this.relativePath, required this.canvasId, required this.canvasName, required this.nodeId, required this.createdAt, this.slotIndex, this.durationMs, this.thumbnailRelativePath});
  

@override final  GalleryItemKind kind;
/// canvas 相对路径（images/... 或 videos/...）。
@override final  String relativePath;
/// 来源画布（路径解析 + caption 展示）。
@override final  String canvasId;
@override final  String canvasName;
/// 来源节点；批量 slot 为其挂载的结果节点。
@override final  String nodeId;
@override final  DateTime createdAt;
/// 批量 slot 来源时的槽位序号；节点主产物为 null。
@override final  int? slotIndex;
/// 视频时长（毫秒）；未知为 null。
@override final  int? durationMs;
/// 视频首帧缩略图的 canvas 相对路径（GA-1：读节点已落库的
/// thumbnail_url，非现场抽帧）；图片/未抽帧视频为 null。
@override final  String? thumbnailRelativePath;

/// Create a copy of GalleryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GalleryItemCopyWith<_GalleryItem> get copyWith => __$GalleryItemCopyWithImpl<_GalleryItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GalleryItem&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.relativePath, relativePath) || other.relativePath == relativePath)&&(identical(other.canvasId, canvasId) || other.canvasId == canvasId)&&(identical(other.canvasName, canvasName) || other.canvasName == canvasName)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.slotIndex, slotIndex) || other.slotIndex == slotIndex)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.thumbnailRelativePath, thumbnailRelativePath) || other.thumbnailRelativePath == thumbnailRelativePath));
}


@override
int get hashCode => Object.hash(runtimeType,kind,relativePath,canvasId,canvasName,nodeId,createdAt,slotIndex,durationMs,thumbnailRelativePath);

@override
String toString() {
  return 'GalleryItem(kind: $kind, relativePath: $relativePath, canvasId: $canvasId, canvasName: $canvasName, nodeId: $nodeId, createdAt: $createdAt, slotIndex: $slotIndex, durationMs: $durationMs, thumbnailRelativePath: $thumbnailRelativePath)';
}


}

/// @nodoc
abstract mixin class _$GalleryItemCopyWith<$Res> implements $GalleryItemCopyWith<$Res> {
  factory _$GalleryItemCopyWith(_GalleryItem value, $Res Function(_GalleryItem) _then) = __$GalleryItemCopyWithImpl;
@override @useResult
$Res call({
 GalleryItemKind kind, String relativePath, String canvasId, String canvasName, String nodeId, DateTime createdAt, int? slotIndex, int? durationMs, String? thumbnailRelativePath
});




}
/// @nodoc
class __$GalleryItemCopyWithImpl<$Res>
    implements _$GalleryItemCopyWith<$Res> {
  __$GalleryItemCopyWithImpl(this._self, this._then);

  final _GalleryItem _self;
  final $Res Function(_GalleryItem) _then;

/// Create a copy of GalleryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? relativePath = null,Object? canvasId = null,Object? canvasName = null,Object? nodeId = null,Object? createdAt = null,Object? slotIndex = freezed,Object? durationMs = freezed,Object? thumbnailRelativePath = freezed,}) {
  return _then(_GalleryItem(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GalleryItemKind,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,canvasId: null == canvasId ? _self.canvasId : canvasId // ignore: cast_nullable_to_non_nullable
as String,canvasName: null == canvasName ? _self.canvasName : canvasName // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,slotIndex: freezed == slotIndex ? _self.slotIndex : slotIndex // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,thumbnailRelativePath: freezed == thumbnailRelativePath ? _self.thumbnailRelativePath : thumbnailRelativePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
