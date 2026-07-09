// DiskOrphanFileReaper 单测（LB-13 slice B，DRY-RUN v1）。
//
// 覆盖：识别逻辑（恰好命中未引用 AND >7d）、mtime 守卫、目录白名单安全、
// 引用集构建（含软删节点）、节流、以及 dry-run「绝不删除 + 记 orphan.reap.dryrun」。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/orphan_file_reaper.dart';

import '../_harness/fake_batch_result.dart';
import '../_harness/fake_clock.dart';
import '../_harness/fake_repositories.dart';
import '../helpers/recording_logger.dart';

void main() {
  late Directory tempRoot;
  late AppPaths paths;
  late FakeClock clock;
  late RecordingLogger logger;
  late InMemoryNodeRepository nodes;
  late FakeBatchResultRepo batch;

  final DateTime t0 = DateTime.utc(2026, 7, 9, 12);

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('orphan_reap_test');
    paths = DefaultAppPaths.forRoot(tempRoot);
    clock = FakeClock(t0);
    logger = RecordingLogger();
    nodes = InMemoryNodeRepository();
    batch = FakeBatchResultRepo();
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  DiskOrphanFileReaper buildReaper() => DiskOrphanFileReaper(
        paths: paths,
        nodeRepo: nodes,
        batchResultRepo: batch,
        clock: clock,
        logger: logger,
      );

  // 在 projects/<project>/canvases/<canvas>/<subdir>/<name> 落一个文件并设 mtime。
  File seed(
    String subdir,
    String name, {
    required Duration age,
    String project = 'p1',
    String canvas = 'c1',
  }) {
    final f = File(
      '${tempRoot.path}/projects/$project/canvases/$canvas/$subdir/$name',
    );
    f.parent.createSync(recursive: true);
    f.writeAsStringSync('x' * 16);
    f.setLastModifiedSync(clock.nowUtc().subtract(age));
    return f;
  }

  Set<String> relPaths(List<OrphanCandidate> cs) =>
      cs.map((c) => c.relativePath).toSet();

  group('identifyOrphans', () {
    test('恰好命中「未引用 AND >7d」的文件', () {
      seed('images', 'keep.png', age: const Duration(days: 20)); // 已引用
      seed('images', 'orphan.png', age: const Duration(days: 8)); // 孤儿
      seed('images', 'fresh.png', age: const Duration(days: 1)); // 新文件
      seed('videos', 'vorphan.mp4', age: const Duration(days: 10)); // 孤儿

      final orphans = buildReaper().identifyOrphans(
        referenceSet: <String>{'images/keep.png'},
        now: clock.nowUtc(),
      );

      expect(
        relPaths(orphans),
        <String>{'images/orphan.png', 'videos/vorphan.mp4'},
      );
    });

    test('mtime 守卫：未引用但 mtime ≤7d 不被标记（安全#1）', () {
      seed('images', 'young.png', age: const Duration(days: 5));
      seed('images', 'old.png', age: const Duration(days: 8));

      final orphans = buildReaper().identifyOrphans(
        referenceSet: const <String>{},
        now: clock.nowUtc(),
      );

      expect(relPaths(orphans), <String>{'images/old.png'});
    });

    test('目录白名单：images/videos 之外的文件从不被扫描/标记（安全#3）', () {
      // 画布根直挂、以及非白名单子目录，皆早于阈值且无引用——但都不该被碰。
      final atRoot = File(
        '${tempRoot.path}/projects/p1/canvases/c1/loose.png',
      )..parent.createSync(recursive: true);
      atRoot.writeAsStringSync('x');
      atRoot.setLastModifiedSync(clock.nowUtc().subtract(const Duration(days: 30)));

      seed('exports', 'movie.mp4', age: const Duration(days: 30));
      seed('characters', 'ref.png', age: const Duration(days: 30));
      // 一个真正的孤儿作对照，证明扫描本身在工作。
      seed('images', 'orphan.png', age: const Duration(days: 30));

      final orphans = buildReaper().identifyOrphans(
        referenceSet: const <String>{},
        now: clock.nowUtc(),
      );

      expect(relPaths(orphans), <String>{'images/orphan.png'});
    });
  });

  group('reap (DRY-RUN)', () {
    test('绝不删除任何文件，且对每个孤儿记 orphan.reap.dryrun', () async {
      // 引用集：节点引用 images/keep.png；batch_result 引用 videos/vkeep.mp4。
      await nodes.create(
        canvasId: 'c1',
        type: 'image',
        nodeRole: 'result',
        typeConfig: const <String, Object?>{'image_url': 'images/keep.png'},
      );
      batch.rows['b1'] = <String, Object?>{
        'id': 'b1',
        'output_url': 'videos/vkeep.mp4',
        'status': 'success',
      };

      final keep = seed('images', 'keep.png', age: const Duration(days: 20));
      final vkeep = seed('videos', 'vkeep.mp4', age: const Duration(days: 20));
      final orphan = seed('images', 'orphan.png', age: const Duration(days: 9));

      final report = await buildReaper().reap();

      // 识别正确。
      expect(report.throttledSkip, isFalse);
      expect(report.dryRun, isTrue);
      expect(report.orphanCount, 1);

      // 关键：dry-run 绝不删除——所有文件仍在。
      expect(keep.existsSync(), isTrue);
      expect(vkeep.existsSync(), isTrue);
      expect(orphan.existsSync(), isTrue);

      // 记了恰好一条 orphan.reap.dryrun，指向那个孤儿。
      final dryRuns = logger.records
          .where((r) => r.msg == 'orphan.reap.dryrun')
          .toList();
      expect(dryRuns, hasLength(1));
      expect(dryRuns.single.level, InkLogLevel.info);
      expect(dryRuns.single.extra?['path'], 'images/orphan.png');
      expect(dryRuns.single.extra?['size_bytes'], isA<int>());
      expect(dryRuns.single.extra?['age_days'], isA<int>());

      // 汇总日志也在。
      final summary =
          logger.records.where((r) => r.msg == 'orphan.reap.summary').toList();
      expect(summary, hasLength(1));
      expect(summary.single.extra?['orphan_count'], 1);
      expect(summary.single.extra?['dry_run'], true);
    });

    test('节流：7 天内二次 reap 为 no-op', () async {
      seed('images', 'orphan.png', age: const Duration(days: 9));

      final first = await buildReaper().reap();
      expect(first.throttledSkip, isFalse);
      expect(first.orphanCount, 1);
      final dryRunsAfterFirst =
          logger.records.where((r) => r.msg == 'orphan.reap.dryrun').length;

      // 3 天后：仍在节流窗口内 → 跳过，不再产生 dryrun 日志。
      clock.advance(const Duration(days: 3));
      final second = await buildReaper().reap();
      expect(second.throttledSkip, isTrue);
      expect(second.orphanCount, 0);
      expect(
        logger.records.where((r) => r.msg == 'orphan.reap.dryrun').length,
        dryRunsAfterFirst,
      );

      // 距上次成功回收满 7 天后：再次执行。
      clock.advance(const Duration(days: 8));
      final third = await buildReaper().reap();
      expect(third.throttledSkip, isFalse);
    });
  });

  group('引用集构建（fakes）', () {
    test('listAllMediaUrls 含软删节点的 url（安全#2）', () async {
      final live = await nodes.create(
        canvasId: 'c1',
        type: 'image',
        nodeRole: 'result',
        typeConfig: const <String, Object?>{'image_url': 'images/live.png'},
      );
      final gone = await nodes.create(
        canvasId: 'c1',
        type: 'video',
        nodeRole: 'result',
        typeConfig: const <String, Object?>{
          'video_url': 'videos/gone.mp4',
          'thumbnail_url': 'videos/gone.jpg',
        },
      );
      await nodes.softDelete(gone);
      expect(await nodes.findById(gone), isNull); // 确已软删。

      final urls = (await nodes.listAllMediaUrls()).toSet();
      expect(urls, contains('images/live.png'));
      // 软删节点产物仍在引用集内——不会被当孤儿删。
      expect(urls, contains('videos/gone.mp4'));
      expect(urls, contains('videos/gone.jpg'));
      expect(live, isNotEmpty);
    });

    test('listAllOutputUrls 返回全部非空 output_url', () async {
      batch.rows['b1'] = <String, Object?>{
        'id': 'b1',
        'output_url': 'images/a.png',
        'status': 'success',
      };
      batch.rows['b2'] = <String, Object?>{
        'id': 'b2',
        'output_url': '',
        'status': 'error',
      };
      batch.rows['b3'] = <String, Object?>{
        'id': 'b3',
        'output_url': 'images/b.png',
        'status': 'success',
      };

      final urls = (await batch.listAllOutputUrls()).toSet();
      expect(urls, <String>{'images/a.png', 'images/b.png'});
    });
  });
}
