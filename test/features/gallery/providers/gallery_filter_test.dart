// GalleryFilter 纯函数过滤矩阵（GA-3）：kind/canvas/query 三轴组合 + 大小写。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';

GalleryItem _item({
  GalleryItemKind kind = GalleryItemKind.image,
  String canvasId = 'c1',
  String canvasName = 'Alpha',
  String path = 'images/a.png',
}) =>
    GalleryItem(
      kind: kind,
      relativePath: path,
      canvasId: canvasId,
      canvasName: canvasName,
      nodeId: 'n-$path',
      createdAt: DateTime.utc(2026, 8, 1),
    );

void main() {
  final items = <GalleryItem>[
    _item(),
    _item(kind: GalleryItemKind.video, path: 'videos/v.mp4'),
    _item(canvasId: 'c2', canvasName: 'Beta scene', path: 'images/b.png'),
  ];

  test('默认筛选（全空）→ 原列表原序', () {
    expect(filterGalleryItems(items, const GalleryFilter()), items);
  });

  test('kind 轴：只留 video', () {
    final out = filterGalleryItems(
      items,
      const GalleryFilter(kind: GalleryItemKind.video),
    );
    expect(out.map((i) => i.relativePath), <String>['videos/v.mp4']);
  });

  test('canvas 轴：只留 c2', () {
    final out = filterGalleryItems(items, const GalleryFilter(canvasId: 'c2'));
    expect(out.map((i) => i.relativePath), <String>['images/b.png']);
  });

  test('query 轴：匹配 canvasName,大小写不敏感,前后空白 trim', () {
    final out = filterGalleryItems(
      items,
      const GalleryFilter(query: '  beta '),
    );
    expect(out.map((i) => i.relativePath), <String>['images/b.png']);
  });

  test('三轴组合：kind=image + canvas=c2 + query 命中', () {
    final out = filterGalleryItems(
      items,
      const GalleryFilter(
        kind: GalleryItemKind.image,
        canvasId: 'c2',
        query: 'SCENE',
      ),
    );
    expect(out.map((i) => i.relativePath), <String>['images/b.png']);
  });

  test('无命中 → 空列表;isActive 语义', () {
    expect(
      filterGalleryItems(items, const GalleryFilter(query: 'nope')),
      isEmpty,
    );
    expect(const GalleryFilter().isActive, isFalse);
    expect(const GalleryFilter(query: ' ').isActive, isFalse,
        reason: '纯空白 query 不算激活');
    expect(const GalleryFilter(kind: GalleryItemKind.image).isActive, isTrue);
  });
}
