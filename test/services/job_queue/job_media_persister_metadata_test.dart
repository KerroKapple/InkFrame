// XM-2 图片元数据落盘：四个落盘点（inline 单/批、remote 单/批）都要顺手把
// 宽高与 seed 记下来——node.type_config 记主图那一张，batch_results 逐 slot 各记各的。
//
// 硬要求是**拿不到就不写键**。写 0 或写 -1 会被下游当成真实尺寸拿去算比例；
// 列停在 NULL，画廊才知道该退回默认比例。所以每条正向断言都配一条「非 PNG 时
// 这些键根本不出现」的反向断言。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/job_media_persister.dart';
import 'package:inkframe/core/interfaces/video_download_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/services/job_queue/job_media_persister.dart';

import '../../_harness/fake_batch_result.dart';
import '../../_harness/fake_repositories.dart';

class _Cancel implements CancelSignal {
  _Cancel(this.cancelled);
  @override
  bool cancelled;
}

/// 真磁盘、临时目录——本卡断言的就是「写下去的文件能被读回来解析」。
class _TempResolver implements FileResolverService {
  _TempResolver(this.root);
  final Directory root;

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('${root.path}/$projectId/$canvasId/$relativePath');

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// 把给定字节写到目标位置，模拟下载完成。
class _BytesDownloader implements VideoDownloadService {
  _BytesDownloader(this.bytes);
  final List<int> bytes;

  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async {
    await destination.parent.create(recursive: true);
    return destination.writeAsBytes(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

List<int> _be32(int v) =>
    <int>[(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

/// 最小合法 PNG 文件头 + 一点尾巴（内容无所谓，只解析头）。
List<int> _png(int width, int height) => <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ..._be32(13),
      ...ascii.encode('IHDR'),
      ..._be32(width),
      ..._be32(height),
      8, 6, 0, 0, 0,
      ..._be32(0),
      ...List<int>.filled(64, 7),
    ];

/// 不是 PNG——解析必须失败。
final List<int> _notPng = <int>[0xFF, 0xD8, 0xFF, 0xE0, ...List<int>.filled(60, 1)];

void main() {
  late Directory tmp;
  late _TempResolver resolver;
  late InMemoryNodeRepository nodes;
  late FakeBatchResultRepo batch;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('xm2_');
    resolver = _TempResolver(tmp);
    nodes = InMemoryNodeRepository();
    batch = FakeBatchResultRepo();
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> seedResultNode() async => nodes.create(
        canvasId: 'c',
        type: 'image',
        nodeRole: 'result',
        sourceNodeId: null,
      );

  GenerationTask task({
    required String resultNodeId,
    int batchSize = 1,
    int? seed,
    GenerationMode mode = GenerationMode.textToImage,
  }) =>
      GenerationTask(
        providerId: 'fake',
        jobId: 'j1',
        projectId: 'p',
        canvasId: 'c',
        resultNodeId: resultNodeId,
        mode: mode,
        prompt: 'x',
        resolution: Resolution.p1080,
        aspectRatio: AspectRatio.r16x9,
        seed: seed,
        batchSize: batchSize,
      );

  JobMediaPersisterImpl persister({VideoDownloadService? downloader}) =>
      JobMediaPersisterImpl(
        fileResolver: resolver,
        nodeRepo: nodes,
        batchResults: batch,
        downloader: downloader,
      );

  Map<String, Object?> typeConfigOf(String nodeId) =>
      nodes.rows[nodeId]!['type_config']! as Map<String, Object?>;

  group('inlineBytes 单张', () {
    test('宽高与 seed 一并落进 type_config', () async {
      final id = await seedResultNode();
      final err = await persister().persistInlineBytes(
        task(resultNodeId: id, seed: 4242),
        <dynamic>[_png(1536, 864)],
        _Cancel(false),
      );

      expect(err, isNull);
      final tc = typeConfigOf(id);
      expect(tc['image_url'], 'images/j1-0.png');
      expect(tc['width'], 1536);
      expect(tc['height'], 864);
      expect(tc['seed'], 4242);
    });

    test('非 PNG → 宽高键根本不出现（绝不写 0）', () async {
      final id = await seedResultNode();
      await persister().persistInlineBytes(
        task(resultNodeId: id),
        <dynamic>[_notPng],
        _Cancel(false),
      );

      final tc = typeConfigOf(id);
      expect(tc['image_url'], isNotNull, reason: '产物本身照常落地');
      expect(tc.containsKey('width'), isFalse);
      expect(tc.containsKey('height'), isFalse);
    });

    test('task 无 seed → seed 键不出现', () async {
      final id = await seedResultNode();
      await persister().persistInlineBytes(
        task(resultNodeId: id),
        <dynamic>[_png(8, 8)],
        _Cancel(false),
      );

      expect(typeConfigOf(id).containsKey('seed'), isFalse);
    });
  });

  group('inlineBytes 批量', () {
    test('逐 slot 各记各的尺寸；主图取首张', () async {
      final id = await seedResultNode();
      for (var i = 0; i < 2; i++) {
        await batch.create(
            nodeId: id, jobId: 'j1', slotIndex: i, status: 'generating');
      }

      final err = await persister().persistInlineBytes(
        task(resultNodeId: id, batchSize: 2, seed: 7),
        <dynamic>[_png(1024, 1024), _png(640, 360)],
        _Cancel(false),
      );

      expect(err, isNull);
      final slots = await batch.listByNode(id);
      slots.sort((a, b) =>
          (a['slot_index']! as int).compareTo(b['slot_index']! as int));
      expect(slots[0]['width'], 1024);
      expect(slots[0]['height'], 1024);
      expect(slots[0]['seed'], 7);
      expect(slots[1]['width'], 640);
      expect(slots[1]['height'], 360);

      final tc = typeConfigOf(id);
      expect(tc['width'], 1024, reason: '主图=首张成功 slot');
      expect(tc['height'], 1024);
    });

    test('首张解析不出 → 该 slot 与主图都停在 NULL，绝不去借别张的尺寸', () async {
      final id = await seedResultNode();
      for (var i = 0; i < 2; i++) {
        await batch.create(
            nodeId: id, jobId: 'j1', slotIndex: i, status: 'generating');
      }

      // 第 0 张给非 PNG（照样写盘成功，只是解析不出），第 1 张是 800x600。
      await persister().persistInlineBytes(
        task(resultNodeId: id, batchSize: 2),
        <dynamic>[_notPng, _png(800, 600)],
        _Cancel(false),
      );

      final slots = await batch.listByNode(id);
      slots.sort((a, b) =>
          (a['slot_index']! as int).compareTo(b['slot_index']! as int));
      expect(slots[0]['width'], isNull, reason: '解析不出就停在 NULL');
      expect(slots[1]['width'], 800);
      // 首张写盘是成功的，所以主图仍是它——尺寸拿不到就不写键。
      expect(typeConfigOf(id).containsKey('width'), isFalse);
    });
  });

  group('remoteUrls 单张（bytes 不经手，回读文件头）', () {
    test('下载完回读文件头补上宽高与 seed', () async {
      final id = await seedResultNode();
      final err = await persister(downloader: _BytesDownloader(_png(1920, 1080)))
          .persistRemoteUrls(
        task(resultNodeId: id, seed: 99),
        <String>['https://example.com/a.png'],
        _Cancel(false),
      );

      expect(err, isNull);
      final tc = typeConfigOf(id);
      expect(tc['image_url'], 'images/j1.png');
      expect(tc['width'], 1920);
      expect(tc['height'], 1080);
      expect(tc['seed'], 99);
    });

    test('下载到的不是 PNG → 只落 image_url，尺寸键缺席', () async {
      final id = await seedResultNode();
      await persister(downloader: _BytesDownloader(_notPng)).persistRemoteUrls(
        task(resultNodeId: id),
        <String>['https://example.com/a.png'],
        _Cancel(false),
      );

      final tc = typeConfigOf(id);
      expect(tc['image_url'], isNotNull);
      expect(tc.containsKey('width'), isFalse);
      expect(tc.containsKey('height'), isFalse);
    });

    test('视频路径不碰 PNG 解析（宽高归 XM-1 抽帧探针）', () async {
      final id = await seedResultNode();
      await persister(downloader: _BytesDownloader(_png(4, 4))).persistRemoteUrls(
        task(resultNodeId: id, mode: GenerationMode.textToVideo, seed: 5),
        <String>['https://example.com/a.mp4'],
        _Cancel(false),
      );

      final tc = typeConfigOf(id);
      expect(tc['video_url'], 'videos/j1.mp4');
      // 文件字节碰巧是 PNG 也不该被当图片解析——视频元数据是抽帧探针的活。
      expect(tc.containsKey('width'), isFalse);
      expect(tc.containsKey('seed'), isFalse);
    });
  });

  group('remoteUrls 批量', () {
    test('逐 slot 回读各自文件头', () async {
      final id = await seedResultNode();
      for (var i = 0; i < 2; i++) {
        await batch.create(
            nodeId: id, jobId: 'j1', slotIndex: i, status: 'generating');
      }

      await persister(downloader: _BytesDownloader(_png(512, 768)))
          .persistRemoteUrls(
        task(resultNodeId: id, batchSize: 2, seed: 11),
        <String>['https://e/1.png', 'https://e/2.png'],
        _Cancel(false),
      );

      final slots = await batch.listByNode(id);
      expect(slots.map((s) => s['width']), everyElement(512));
      expect(slots.map((s) => s['height']), everyElement(768));
      expect(slots.map((s) => s['seed']), everyElement(11));
      expect(typeConfigOf(id)['width'], 512);
    });
  });

  test('元数据解析绝不把成功的生成拖成失败（文件读不回来也照样 success）', () async {
    final id = await seedResultNode();
    // 下载器什么都不写 → 回读时文件不存在。
    final noop = _NoopDownloader();
    final err = await persister(downloader: noop).persistRemoteUrls(
      task(resultNodeId: id),
      <String>['https://example.com/a.png'],
      _Cancel(false),
    );

    expect(err, isNull, reason: '探针失败必须被吞掉');
    expect(typeConfigOf(id)['image_url'], 'images/j1.png');
    expect(typeConfigOf(id).containsKey('width'), isFalse);
  });
}

/// 什么都不写的下载器——制造「文件不存在」让回读失败。
class _NoopDownloader implements VideoDownloadService {
  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async =>
      destination;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}
