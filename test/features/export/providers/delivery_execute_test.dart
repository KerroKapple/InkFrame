// 交付执行（P6 §3）：真临时目录、真文件系统，跑完整一次交付。
//
// 只有 DeliveryService 是真的；其余（画布、仓储）都不进来——这条测试要钉的是
// 「交付目录里最后到底有哪些文件、它们的内容是什么」。
//
// 媒体夹具就是「往 .mp4 里写任意字节」（与 export_video_dialog_test 同款）：
// 交付的转码是「保持源 · 不重编码」= 字节拷贝，不需要真视频、也不需要 ffmpeg。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/clock.dart';
import 'package:inkframe/core/di/delivery.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/delivery_service.dart';
import 'package:inkframe/core/interfaces/video_export_service.dart'
    show ExportCancelToken;
import 'package:inkframe/core/models/shot_language.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/export/models/delivery_plan.dart';
import 'package:inkframe/features/export/models/delivery_settings.dart';
import 'package:inkframe/features/export/providers/delivery_controller.dart';
import 'package:inkframe/features/export/util/edl_cmx3600.dart';
import 'package:path/path.dart' as p;

import '../../../_harness/fake_clock.dart';

const String _kProjectId = 'p1';
const String _kCanvasId = 'c1';

/// 24fps 下用帧数反推毫秒。
int ms(int frames) => (frames * 1000 / 24).round();

/// 夹具 .mp4：内容是任意字节，只要能被拷贝就行。
File _writeFixtureVideo(AppPaths paths, String name, String bytes) {
  final Directory dir = Directory(
    p.join(paths.projects.path, _kProjectId, 'canvases', _kCanvasId, 'videos'),
  )..createSync(recursive: true);
  final File f = File(p.join(dir.path, name))..writeAsStringSync(bytes);
  return f;
}

DeliveryShotPlan _video({
  required int index,
  required String name,
  required String sourceFile,
  int frames = 24,
  ShotLanguage lang = ShotLanguage.empty,
  String? comment,
  String? marker,
}) =>
    DeliveryShotPlan(
      index: index,
      nodeId: 'n$index',
      name: name,
      durationMs: ms(frames),
      durationFrames: frames,
      isPlaceholder: false,
      fileName: deliveryMediaFileName(index: index, shotName: name),
      sourceRelativePath: 'canvases/$_kCanvasId/videos/$sourceFile',
      width: 1920,
      height: 1080,
      comment: comment,
      marker: marker,
      providerId: 'kling-v3',
      seed: 41207,
      prompt: 'a misty trail',
      shotLanguage: lang,
    );

DeliveryShotPlan _gap({required int index, required String name, int frames = 96}) =>
    DeliveryShotPlan(
      index: index,
      nodeId: 'n$index',
      name: name,
      durationMs: ms(frames),
      durationFrames: frames,
      isPlaceholder: true,
      marker: name,
    );

/// 第 [n] 次被问「取消了吗」时才说是——用来把取消精确地卡在某个落盘动作中间。
class _CancelOnNthCheck extends ExportCancelToken {
  _CancelOnNthCheck(this.n);

  final int n;
  int checks = 0;

  @override
  bool get isCancelled {
    checks++;
    return checks >= n;
  }
}

Future<AppPaths> _tempPaths() async {
  final Directory tmp = Directory.systemTemp.createTempSync('ink_delivery_');
  addTearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });
  final AppPaths paths = DefaultAppPaths.forRoot(tmp);
  await paths.ensureInitialized();
  return paths;
}

ProviderContainer _container(AppPaths paths, {FakeClock? clock}) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      appPathsProvider.overrideWithValue(paths),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Directory _exportsDir(AppPaths paths) =>
    Directory(p.join(paths.projects.path, _kProjectId, 'exports'));

List<String> _namesIn(Directory d) =>
    d.listSync().map((FileSystemEntity e) => p.basename(e.path)).toList()
      ..sort();

void main() {
  group('完整一次交付：产出清单 / EDL 逐字 / metadata 结构', () {
    test('两镜 + 一个占位镜 → 2 mp4 + 1 edl + metadata.json', () async {
      final AppPaths paths = await _tempPaths();
      _writeFixtureVideo(paths, 'a.mp4', 'AAAA');
      _writeFixtureVideo(paths, 'b.mp4', 'BBBB');
      final ProviderContainer c =
          _container(paths, clock: FakeClock(DateTime.utc(2026, 10, 8, 9)));

      final DeliveryPlan plan = DeliveryPlan(
        projectName: '山径破晓',
        settings: DeliverySettings.defaults,
        shots: <DeliveryShotPlan>[
          _video(
            index: 1,
            name: '山径入镜',
            sourceFile: 'a.mp4',
            frames: 24,
            comment: 'medium shot, dolly in',
            marker: '山径入镜',
            lang: const ShotLanguage(
              shotSize: ShotSize.mediumShot,
              focalLengthMm: 35,
            ),
          ),
          _gap(index: 2, name: '收尾空镜'),
          _video(index: 3, name: '破晓', sourceFile: 'b.mp4', frames: 36),
        ],
      );

      await c
          .read(deliveryControllerProvider.notifier)
          .run(projectId: _kProjectId, plan: plan);

      final DeliveryState s = c.read(deliveryControllerProvider);
      expect(s, isA<DeliverySucceeded>());
      final DeliveryOutcome outcome = (s as DeliverySucceeded).outcome;

      // ① 落盘清单 == 底部摘要「包含」行：N mp4 · 1 edl · metadata.json
      expect(outcome.mediaCount, 2);
      expect(outcome.mediaCount, plan.mp4Count, reason: '摘要行的 N 与真实落盘数同源');
      expect(_namesIn(_exportsDir(paths)), <String>[
        '001_山径入镜.mp4',
        '003_破晓.mp4',
        'metadata.json',
        '山径破晓.edl',
      ]);
      expect(outcome.outputDirRelative, 'exports');
      expect(
        Directory(outcome.outputDirAbsolutePath).existsSync(),
        isTrue,
        reason: '「打开文件夹」要能直接用这个路径',
      );

      // ② 媒体是字节拷贝（保持源 · 不重编码）
      expect(
        File(p.join(_exportsDir(paths).path, '001_山径入镜.mp4'))
            .readAsStringSync(),
        'AAAA',
      );

      // ③ EDL 与写出器直调逐字相等（黄金文本同源，不另存一份快照）
      final String edl =
          File(p.join(_exportsDir(paths).path, '山径破晓.edl')).readAsStringSync();
      final String golden = buildCmx3600(
        title: '山径破晓',
        handleFrames: 0,
        recordStartFrames: kDeliveryDefaultTcStartFrames,
        clips: <DeliveryClip>[
          DeliveryClip(
            fileName: '001_山径入镜.mp4',
            durationMs: ms(24),
            comment: 'medium shot, dolly in',
            marker: '山径入镜',
          ),
          DeliveryClip(
            fileName: '',
            durationMs: ms(96),
            marker: '收尾空镜',
            placeholder: true,
          ),
          DeliveryClip(fileName: '003_破晓.mp4', durationMs: ms(36)),
        ],
      );
      expect(edl, golden);
      // 记录时间码首尾相接，占位镜照占 96 帧（4 秒）。
      expect(edl, contains('01:00:00:00 01:00:01:00'));
      expect(edl, contains('01:00:05:00 01:00:06:12'));
      expect(edl, contains('* LOC: 01:00:01:00 WHITE  收尾空镜'));

      // ④ metadata.json 结构 + 占位镜 file 为 null
      final Map<String, Object?> meta = jsonDecode(
        File(p.join(_exportsDir(paths).path, 'metadata.json'))
            .readAsStringSync(),
      ) as Map<String, Object?>;
      expect(meta['project'], '山径破晓');
      expect(meta['fps'], 24);
      expect(meta['timecodeStart'], '01:00:00:00');
      expect(meta['exportedAt'], '2026-10-08T09:00:00.000Z');
      final List<Object?> shots = meta['shots']! as List<Object?>;
      expect(shots.length, 3);
      final Map<String, Object?> second = shots[1]! as Map<String, Object?>;
      expect(second['isPlaceholder'], true);
      expect(second.containsKey('file'), isTrue);
      expect(second['file'], isNull);
      final Map<String, Object?> first = shots.first! as Map<String, Object?>;
      expect(first['file'], '001_山径入镜.mp4');
      expect(first['shotLanguage'], <String, Object?>{
        'shotSize': 'MS',
        'focalLengthMm': 35,
      });
    });

    test('全是占位镜：没有 mp4，但 EDL 与 metadata 照出', () async {
      final AppPaths paths = await _tempPaths();
      final ProviderContainer c = _container(paths);
      await c.read(deliveryControllerProvider.notifier).run(
            projectId: _kProjectId,
            plan: DeliveryPlan(
              projectName: 'P',
              settings: DeliverySettings.defaults,
              shots: <DeliveryShotPlan>[_gap(index: 1, name: '空')],
            ),
          );
      expect(c.read(deliveryControllerProvider), isA<DeliverySucceeded>());
      expect(_namesIn(_exportsDir(paths)), <String>['P.edl', 'metadata.json']);
    });

    test('已存在的交付目录：只覆盖同名文件，用户自己放的东西不动', () async {
      final AppPaths paths = await _tempPaths();
      _writeFixtureVideo(paths, 'a.mp4', 'NEW');
      final Directory dir = _exportsDir(paths)..createSync(recursive: true);
      File(p.join(dir.path, 'notes.txt')).writeAsStringSync('mine');
      File(p.join(dir.path, '001_a.mp4')).writeAsStringSync('OLD');

      final ProviderContainer c = _container(paths);
      await c.read(deliveryControllerProvider.notifier).run(
            projectId: _kProjectId,
            plan: DeliveryPlan(
              projectName: 'P',
              settings: DeliverySettings.defaults,
              shots: <DeliveryShotPlan>[
                _video(index: 1, name: 'a', sourceFile: 'a.mp4'),
              ],
            ),
          );

      expect(File(p.join(dir.path, 'notes.txt')).readAsStringSync(), 'mine');
      expect(File(p.join(dir.path, '001_a.mp4')).readAsStringSync(), 'NEW');
    });
  });

  group('进度', () {
    test('分母是媒体数，逐文件推进；结束落在成功态', () async {
      final AppPaths paths = await _tempPaths();
      _writeFixtureVideo(paths, 'a.mp4', 'A');
      _writeFixtureVideo(paths, 'b.mp4', 'B');
      final ProviderContainer c = _container(paths);
      final List<String> seen = <String>[];
      c.listen<DeliveryState>(deliveryControllerProvider, (_, DeliveryState s) {
        if (s is DeliveryRunning) seen.add('${s.done}/${s.total}');
      }, fireImmediately: false);

      await c.read(deliveryControllerProvider.notifier).run(
            projectId: _kProjectId,
            plan: DeliveryPlan(
              projectName: 'P',
              settings: DeliverySettings.defaults,
              shots: <DeliveryShotPlan>[
                _video(index: 1, name: 'a', sourceFile: 'a.mp4'),
                _video(index: 2, name: 'b', sourceFile: 'b.mp4'),
              ],
            ),
          );

      expect(seen, <String>['0/2', '1/2', '2/2']);
      expect(c.read(deliveryControllerProvider), isA<DeliverySucceeded>());
    });
  });

  group('相对路径开关：EDL 里的媒体引用', () {
    test('开（默认）→ 只写文件名；关 → 写交付目录的绝对路径', () async {
      final AppPaths paths = await _tempPaths();
      _writeFixtureVideo(paths, 'a.mp4', 'A');
      final ProviderContainer c = _container(paths);
      DeliveryPlan planWith(bool relative) => DeliveryPlan(
            projectName: 'P',
            settings:
                DeliverySettings.defaults.copyWith(relativePaths: relative),
            shots: <DeliveryShotPlan>[
              _video(index: 1, name: 'a', sourceFile: 'a.mp4'),
            ],
          );

      await c
          .read(deliveryControllerProvider.notifier)
          .run(projectId: _kProjectId, plan: planWith(true));
      final File edl = File(p.join(_exportsDir(paths).path, 'P.edl'));
      expect(edl.readAsStringSync(), contains('* FROM CLIP NAME: 001_a.mp4'));

      c.read(deliveryControllerProvider.notifier).dismissResult();
      await c
          .read(deliveryControllerProvider.notifier)
          .run(projectId: _kProjectId, plan: planWith(false));
      expect(
        edl.readAsStringSync(),
        contains('* FROM CLIP NAME: ${_exportsDir(paths).path}'),
      );
    });
  });

  group('中断：半写的 EDL 不留在目录里，媒体保留', () {
    test('拷完媒体后取消 → 只有 mp4，没有 edl / metadata / .partial', () async {
      final AppPaths paths = await _tempPaths();
      _writeFixtureVideo(paths, 'a.mp4', 'A');
      final ProviderContainer c = _container(paths);
      // 令牌在「媒体拷完、文本未写」之间被取消：服务在每个检查点查令牌。
      final ExportCancelToken token = ExportCancelToken();
      final DeliveryService svc = c.read(deliveryServiceProvider);
      final Future<DeliveryOutcome> run = svc.deliver(
        projectId: _kProjectId,
        media: const <DeliveryMediaCopy>[
          DeliveryMediaCopy(
            sourceRelativePath: 'canvases/$_kCanvasId/videos/a.mp4',
            fileName: '001_a.mp4',
          ),
        ],
        textFiles: const <DeliveryTextFile>[
          DeliveryTextFile(fileName: 'P.edl', contents: 'TITLE: P'),
          DeliveryTextFile(fileName: 'metadata.json', contents: '{}'),
        ],
        onProgress: (int done, int total) {
          if (done == total) token.cancel();
        },
        cancelToken: token,
      );

      await expectLater(run, throwsA(isA<CancelledError>()));
      expect(_namesIn(_exportsDir(paths)), <String>['001_a.mp4'],
          reason: '媒体保留，半写的工程文件一个都不留');
    });

    test('取消卡在「工程文件已写一半、还没改名」那一刻 → .partial 被清掉', () async {
      final AppPaths paths = await _tempPaths();
      _writeFixtureVideo(paths, 'a.mp4', 'A');
      final ProviderContainer c = _container(paths);
      // 服务在每个落盘动作前后都查令牌：媒体循环 1 次 + 文本循环（写前 / 改名前）
      // 各 1 次。第 3 次查到取消 ⇒ 此刻 `P.edl.partial` 已经躺在目录里了，
      // 正是「半写的 EDL」那个瞬间。
      final _CancelOnNthCheck token = _CancelOnNthCheck(3);
      await expectLater(
        c.read(deliveryServiceProvider).deliver(
              projectId: _kProjectId,
              media: const <DeliveryMediaCopy>[
                DeliveryMediaCopy(
                  sourceRelativePath: 'canvases/$_kCanvasId/videos/a.mp4',
                  fileName: '001_a.mp4',
                ),
              ],
              textFiles: const <DeliveryTextFile>[
                DeliveryTextFile(fileName: 'P.edl', contents: 'TITLE: P'),
                DeliveryTextFile(fileName: 'metadata.json', contents: '{}'),
              ],
              cancelToken: token,
            ),
        throwsA(isA<CancelledError>()),
      );
      expect(
        _namesIn(_exportsDir(paths)),
        <String>['001_a.mp4'],
        reason: '媒体保留；半写的 EDL 与它的 .partial 都不许留下',
      );
    });

    test('中途取消不毁掉上一次交付的 EDL（`.partial` 存在的理由）', () async {
      final AppPaths paths = await _tempPaths();
      _writeFixtureVideo(paths, 'a.mp4', 'A');
      final Directory dir = _exportsDir(paths)..createSync(recursive: true);
      final File old = File(p.join(dir.path, 'P.edl'))
        ..writeAsStringSync('TITLE: 上一次交付');
      final ProviderContainer c = _container(paths);
      await expectLater(
        c.read(deliveryServiceProvider).deliver(
              projectId: _kProjectId,
              media: const <DeliveryMediaCopy>[
                DeliveryMediaCopy(
                  sourceRelativePath: 'canvases/$_kCanvasId/videos/a.mp4',
                  fileName: '001_a.mp4',
                ),
              ],
              textFiles: const <DeliveryTextFile>[
                DeliveryTextFile(fileName: 'P.edl', contents: 'TITLE: 新的'),
              ],
              cancelToken: _CancelOnNthCheck(3),
            ),
        throwsA(isA<CancelledError>()),
      );
      expect(
        old.readAsStringSync(),
        'TITLE: 上一次交付',
        reason: '半途而废的交付不许把用户手上那份已经导入过 NLE 的 EDL 弄没',
      );
    });

    test('控制器被回收（关窗）→ 取消在途交付', () async {
      final AppPaths paths = await _tempPaths();
      final ProviderContainer c = _container(paths);
      c.read(deliveryControllerProvider.notifier);
      // 不崩、不抛即可：onDispose 里取消令牌（此刻无在途交付 ⇒ no-op）。
      expect(() => c.dispose(), returnsNormally);
    });
  });

  group('失败', () {
    test('源文件不存在 → LocalIOError（reason=delivery_source_missing）', () async {
      final AppPaths paths = await _tempPaths();
      final ProviderContainer c = _container(paths);
      await c.read(deliveryControllerProvider.notifier).run(
            projectId: _kProjectId,
            plan: DeliveryPlan(
              projectName: 'P',
              settings: DeliverySettings.defaults,
              shots: <DeliveryShotPlan>[
                _video(index: 1, name: 'a', sourceFile: 'missing.mp4'),
              ],
            ),
          );
      final DeliveryState s = c.read(deliveryControllerProvider);
      expect(s, isA<DeliveryFailed>());
      final InkError err = (s as DeliveryFailed).error;
      expect(err, isA<LocalIOError>());
      expect(err.extra['reason'], 'delivery_source_missing');
      expect(err.code, InkErrorCode.localIOError);
    });

    test('目标软件没有写出器 → invalid_parameter，不去碰磁盘', () async {
      final AppPaths paths = await _tempPaths();
      final ProviderContainer c = _container(paths);
      await c.read(deliveryControllerProvider.notifier).run(
            projectId: _kProjectId,
            plan: DeliveryPlan(
              projectName: 'P',
              settings: DeliverySettings.defaults
                  .copyWith(target: DeliveryTarget.finalCut),
              shots: <DeliveryShotPlan>[_gap(index: 1, name: 'x')],
            ),
          );
      final DeliveryState s = c.read(deliveryControllerProvider);
      expect(s, isA<DeliveryFailed>());
      expect(
        (s as DeliveryFailed).error.extra['reason'],
        'delivery_writer_missing',
      );
      expect(_exportsDir(paths).existsSync(), isFalse);
    });

    test('在途再点一次 → 第二次直接返回，不并发写同一个目录', () async {
      final AppPaths paths = await _tempPaths();
      _writeFixtureVideo(paths, 'a.mp4', 'A');
      final ProviderContainer c = _container(paths);
      final DeliveryPlan plan = DeliveryPlan(
        projectName: 'P',
        settings: DeliverySettings.defaults,
        shots: <DeliveryShotPlan>[
          _video(index: 1, name: 'a', sourceFile: 'a.mp4'),
        ],
      );
      final Future<void> first = c
          .read(deliveryControllerProvider.notifier)
          .run(projectId: _kProjectId, plan: plan);
      final Future<void> second = c
          .read(deliveryControllerProvider.notifier)
          .run(projectId: _kProjectId, plan: plan);
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(c.read(deliveryControllerProvider), isA<DeliverySucceeded>());
      expect(
        (c.read(deliveryControllerProvider) as DeliverySucceeded)
            .outcome
            .fileNames
            .length,
        3,
        reason: '只跑了一次：1 mp4 + 1 edl + metadata.json',
      );
    });
  });

  group('可写探测（交付前检查第 5 条的数据源）', () {
    test('项目目录可建 → true，且探针文件不留下', () async {
      final AppPaths paths = await _tempPaths();
      final ProviderContainer c = _container(paths);
      expect(
        await c.read(deliveryServiceProvider).probeWritable(projectId: _kProjectId),
        isTrue,
      );
      expect(_namesIn(_exportsDir(paths)), isEmpty);
    });

    test('projectId 非法（空串）→ false，不抛', () async {
      final AppPaths paths = await _tempPaths();
      final ProviderContainer c = _container(paths);
      expect(
        await c.read(deliveryServiceProvider).probeWritable(projectId: ''),
        isFalse,
      );
    });
  });
}
