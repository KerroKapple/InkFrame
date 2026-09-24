// filterGalleryItems 纯函数：四轴（类型 / 画布 / 模型 / 标记）+ isActive 语义。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';
import 'package:inkframe/features/gallery/util/gallery_meta.dart';

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
  // 模型 / 标记轴的信息来自 meta：a = kling 且在当前线上；b = gemini 且已入序列 2。
  GalleryItemMeta metaOf(GalleryItem i) => switch (i.relativePath) {
        'images/a.png' => const GalleryItemMeta(label: 'a', providerId: 'kling-v3', onNarrativeChain: true),
        'images/b.png' => const GalleryItemMeta(label: 'b', providerId: 'gemini-image', sequenceIndex: 2),
        _ => GalleryItemMeta.empty,
      };

  test('默认筛选（全空）→ 原列表原序', () {
    expect(filterGalleryItems(items, const GalleryFilter()), items);
  });

  test('kind 轴：只留 video', () {
    final out = filterGalleryItems(items, const GalleryFilter(kind: GalleryItemKind.video));
    expect(out.map((i) => i.relativePath), <String>['videos/v.mp4']);
  });

  test('canvas 轴：只留 c2', () {
    final out = filterGalleryItems(items, const GalleryFilter(canvasId: 'c2'));
    expect(out.map((i) => i.relativePath), <String>['images/b.png']);
  });

  test('providerId 轴：按 meta 的 providerId', () {
    final out = filterGalleryItems(items, const GalleryFilter(providerId: 'kling-v3'), metaOf: metaOf);
    expect(out.map((i) => i.relativePath), <String>['images/a.png']);
  });

  test('mark 轴：当前线 / 已入序列 都从 meta 推', () {
    expect(
      filterGalleryItems(items, const GalleryFilter(mark: GalleryMark.currentLine), metaOf: metaOf)
          .map((i) => i.relativePath),
      <String>['images/a.png'],
    );
    expect(
      filterGalleryItems(items, const GalleryFilter(mark: GalleryMark.inSequence), metaOf: metaOf)
          .map((i) => i.relativePath),
      <String>['images/b.png'],
    );
  });

  test('没给 metaOf 时模型 / 标记轴零命中（信息缺失不能假装命中）', () {
    expect(filterGalleryItems(items, const GalleryFilter(providerId: 'kling-v3')), isEmpty);
    expect(filterGalleryItems(items, const GalleryFilter(mark: GalleryMark.currentLine)), isEmpty);
  });

  test('多轴组合：kind=image + canvas=c2 + provider=gemini 命中', () {
    final out = filterGalleryItems(
      items,
      const GalleryFilter(kind: GalleryItemKind.image, canvasId: 'c2', providerId: 'gemini-image'),
      metaOf: metaOf,
    );
    expect(out.map((i) => i.relativePath), <String>['images/b.png']);
  });

  test('isActive 语义 + copyWith 可清空', () {
    expect(const GalleryFilter().isActive, isFalse);
    expect(const GalleryFilter(kind: GalleryItemKind.image).isActive, isTrue);
    expect(const GalleryFilter(mark: GalleryMark.inSequence).isActive, isTrue);
    final cleared = const GalleryFilter(canvasId: 'c1', providerId: 'x').copyWith(canvasId: () => null);
    expect(cleared.canvasId, isNull);
    expect(cleared.providerId, 'x');
  });
}
