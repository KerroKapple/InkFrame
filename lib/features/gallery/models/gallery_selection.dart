// GallerySelection：画廊的选中集 + 锚点（右栏信息面板跟着锚点走）。
//
// 单击 = 只选这一个并设锚点；⌘/Ctrl+单击 = 切换该项（锚点落在最后动的那项）。
// 手写不可变值对象；按 projectId 分键，keepAlive（切标签 / 切项目再回来，选中集还在）。
import 'package:flutter/foundation.dart';

@immutable
class GallerySelection {
  const GallerySelection({this.keys = const <String>{}, this.anchor});

  static const GallerySelection none = GallerySelection();

  /// 选中项的 key（galleryItemKey）。
  final Set<String> keys;

  /// 信息面板展示的那一项；一定在 [keys] 里（空选中集时为 null）。
  final String? anchor;

  bool contains(String key) => keys.contains(key);
  int get count => keys.length;
  bool get isEmpty => keys.isEmpty;

  GallerySelection select(String key) =>
      GallerySelection(keys: <String>{key}, anchor: key);

  GallerySelection toggle(String key) {
    final Set<String> next = Set<String>.of(keys);
    if (!next.remove(key)) {
      next.add(key);
      return GallerySelection(keys: next, anchor: key);
    }
    return GallerySelection(
      keys: next,
      anchor: anchor == key ? (next.isEmpty ? null : next.last) : anchor,
    );
  }

  /// 数据刷新后把已经不存在的 key 剔掉（锚点随之回落）。
  GallerySelection retainOnly(Set<String> alive) {
    final Set<String> next = keys.where(alive.contains).toSet();
    if (next.length == keys.length) return this;
    return GallerySelection(
      keys: next,
      anchor: anchor != null && next.contains(anchor) ? anchor : (next.isEmpty ? null : next.last),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GallerySelection && setEquals(other.keys, keys) && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(keys), anchor);
}
