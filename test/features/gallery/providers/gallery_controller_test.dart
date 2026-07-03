// GalleryController 聚合契约：跨画布 result 节点 + 批量成功 slot，去重 + createdAt 倒序。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_controller.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_repositories.dart';

void main() {
  late InMemoryCanvasRepository canvases;
  late InMemoryNodeRepository nodes;
  late FakeBatchResultRepo batch;

  setUp(() {
    canvases = InMemoryCanvasRepository();
    nodes = InMemoryNodeRepository();
    batch = FakeBatchResultRepo();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: <Override>[
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        batchResultRepositoryProvider.overrideWith((_) async => batch),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<String> resultNode(
    String canvasId, {
    required String type,
    Map<String, Object?> typeConfig = const <String, Object?>{},
    required DateTime createdAt,
  }) async {
    final id = await nodes.create(
      canvasId: canvasId,
      type: type,
      nodeRole: 'result',
      typeConfig: typeConfig,
    );
    await nodes.update(id, <String, Object?>{'created_at': createdAt});
    return id;
  }

  test('空项目 → 空列表', () async {
    final items =
        await container().read(galleryControllerProvider('p1').future);
    expect(items, isEmpty);
  });

  test('跨画布聚合：image/video result 节点，createdAt 倒序 + canvasName 映射', () async {
    final ca = await canvases.create(projectId: 'p1', name: 'Alpha');
    final cb = await canvases.create(projectId: 'p1', name: 'Beta');
    // 干扰项：别的项目画布 / config 节点 / 无产物 result 节点
    final other = await canvases.create(projectId: 'p2', name: 'Other');
    await resultNode(
      other,
      type: 'image',
      typeConfig: <String, Object?>{'image_url': 'images/other.png'},
      createdAt: DateTime.utc(2026, 3, 1),
    );
    await nodes.create(
      canvasId: ca,
      type: 'image',
      nodeRole: 'config',
      typeConfig: <String, Object?>{'prompt': 'x'},
    );
    await resultNode(ca, type: 'image', createdAt: DateTime.utc(2026, 2, 1));

    final img = await resultNode(
      ca,
      type: 'image',
      typeConfig: <String, Object?>{'image_url': 'images/a.png'},
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final vid = await resultNode(
      cb,
      type: 'video',
      typeConfig: <String, Object?>{
        'video_url': 'videos/v.mp4',
        'duration_ms': 5000,
      },
      createdAt: DateTime.utc(2026, 1, 2),
    );

    final items =
        await container().read(galleryControllerProvider('p1').future);

    expect(items, hasLength(2));
    expect(items[0].kind, GalleryItemKind.video);
    expect(items[0].nodeId, vid);
    expect(items[0].relativePath, 'videos/v.mp4');
    expect(items[0].canvasId, cb);
    expect(items[0].canvasName, 'Beta');
    expect(items[0].durationMs, 5000);
    expect(items[0].slotIndex, isNull);
    expect(items[1].kind, GalleryItemKind.image);
    expect(items[1].nodeId, img);
    expect(items[1].relativePath, 'images/a.png');
    expect(items[1].canvasId, ca);
    expect(items[1].canvasName, 'Alpha');
  });

  test('批量成功 slot 并入：与节点主图同路径去重，success 无 url 跳过', () async {
    final ca = await canvases.create(projectId: 'p1', name: 'Alpha');
    final nid = await resultNode(
      ca,
      type: 'image',
      typeConfig: <String, Object?>{'image_url': 'images/main.png'},
      createdAt: DateTime.utc(2026, 1, 1),
    );
    batch.rows.addAll(<String, Map<String, Object?>>{
      // 与主图同路径 → 去重只留节点主图一条
      's0': <String, Object?>{
        'id': 's0',
        'node_id': nid,
        'job_id': 'j1',
        'slot_index': 0,
        'status': 'success',
        'output_url': 'images/main.png',
        'canvas_id': ca,
        'project_id': 'p1',
        'created_at': DateTime.utc(2026, 1, 2),
      },
      's1': <String, Object?>{
        'id': 's1',
        'node_id': nid,
        'job_id': 'j1',
        'slot_index': 1,
        'status': 'success',
        'output_url': 'images/s1.png',
        'canvas_id': ca,
        'project_id': 'p1',
        'created_at': DateTime.utc(2026, 1, 3),
      },
      // success 但无 url → 跳过
      's3': <String, Object?>{
        'id': 's3',
        'node_id': nid,
        'job_id': 'j1',
        'slot_index': 3,
        'status': 'success',
        'output_url': null,
        'canvas_id': ca,
        'project_id': 'p1',
        'created_at': DateTime.utc(2026, 1, 5),
      },
      // success 但 url 为空串 → 同样跳过
      's4': <String, Object?>{
        'id': 's4',
        'node_id': nid,
        'job_id': 'j1',
        'slot_index': 4,
        'status': 'success',
        'output_url': '',
        'canvas_id': ca,
        'project_id': 'p1',
        'created_at': DateTime.utc(2026, 1, 6),
      },
    });

    final items =
        await container().read(galleryControllerProvider('p1').future);

    expect(items, hasLength(2));
    expect(items[0].relativePath, 'images/s1.png');
    expect(items[0].slotIndex, 1);
    expect(items[0].kind, GalleryItemKind.image);
    expect(items[0].nodeId, nid);
    expect(items[0].canvasName, 'Alpha');
    expect(items[1].relativePath, 'images/main.png');
    expect(items[1].slotIndex, isNull);
  });
}
