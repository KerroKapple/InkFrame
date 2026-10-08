// 交付前检查（P6 §2.5）——五条，顺序固定，`✕` 阻断、`!` 警告、`✓` 过。
//
// 这五条里只有四条**真能算**：
//   1 帧率：仓库里**没有 fps 字段**（kSequenceFps = 24 是常量）。这一条因此永远为真，
//     文案只能写「按 24 fps 统一处理」，不能假装它在比对什么——它也永远不会成为阻断原因。
//   2 画幅：算得出，取 result 节点 type_config 的 width/height（抽帧探针写的）。
//     **抽帧失败这两个键就是缺的** ⇒ 算「未知」，不算「不一致」。
//   3 缺失产物 / 4 项目上下文 / 5 输出目录：都算得出。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/export/models/delivery_plan.dart';
import 'package:inkframe/features/export/models/delivery_settings.dart';
import 'package:inkframe/features/export/util/delivery_preflight.dart';

DeliveryShotPlan _video({
  required int index,
  int? width = 1920,
  int? height = 1080,
  String name = 'shot',
}) =>
    DeliveryShotPlan(
      index: index,
      nodeId: 'n$index',
      name: name,
      durationMs: 1000,
      durationFrames: 24,
      isPlaceholder: false,
      fileName: '${index.toString().padLeft(3, '0')}_$name.mp4',
      sourceRelativePath: 'canvases/c1/videos/$index.mp4',
      width: width,
      height: height,
    );

DeliveryShotPlan _gap({required int index, String name = 'gap', int ms = 4000}) =>
    DeliveryShotPlan(
      index: index,
      nodeId: 'n$index',
      name: name,
      durationMs: ms,
      durationFrames: 96,
      isPlaceholder: true,
    );

DeliveryPlan _plan(List<DeliveryShotPlan> shots) => DeliveryPlan(
      projectName: 'P',
      shots: shots,
      settings: DeliverySettings.defaults,
    );

DeliveryPreflight _run(
  List<DeliveryShotPlan> shots, {
  bool hasProject = true,
  bool outputWritable = true,
}) =>
    runDeliveryPreflight(
      plan: _plan(shots),
      hasProject: hasProject,
      outputWritable: outputWritable,
    );

DeliveryCheck _check(DeliveryPreflight p, DeliveryCheckId id) =>
    p.checks.firstWhere((DeliveryCheck c) => c.id == id);

void main() {
  test('五条、顺序固定（稿上从上到下）', () {
    expect(
      _run(<DeliveryShotPlan>[_video(index: 1)])
          .checks
          .map((DeliveryCheck c) => c.id)
          .toList(),
      <DeliveryCheckId>[
        DeliveryCheckId.frameRate,
        DeliveryCheckId.frameSize,
        DeliveryCheckId.missingArtifacts,
        DeliveryCheckId.projectContext,
        DeliveryCheckId.outputWritable,
      ],
    );
  });

  group('1 帧率：没有字段，恒过（不假装在比对）', () {
    test('有镜 / 无镜都是 ✓，且带上参与的镜数', () {
      final DeliveryCheck c =
          _check(_run(<DeliveryShotPlan>[_video(index: 1), _gap(index: 2)]),
              DeliveryCheckId.frameRate);
      expect(c.level, DeliveryCheckLevel.ok);
      expect(c.shotCount, 2);
      expect(
        _check(_run(const <DeliveryShotPlan>[]), DeliveryCheckId.frameRate).level,
        DeliveryCheckLevel.ok,
      );
    });

    test('它永远不可能是阻断原因', () {
      // 全盘最糟的一组输入：没项目、目录不可写、全是占位。
      final DeliveryPreflight p = _run(
        <DeliveryShotPlan>[_gap(index: 1)],
        hasProject: false,
        outputWritable: false,
      );
      expect(p.firstBlocking?.id, isNot(DeliveryCheckId.frameRate));
      expect(_check(p, DeliveryCheckId.frameRate).level, DeliveryCheckLevel.ok);
    });
  });

  group('2 画幅：宽高比一致否', () {
    test('全一致 → ✓ 并给出比值', () {
      final DeliveryCheck c = _check(
        _run(<DeliveryShotPlan>[_video(index: 1), _video(index: 2)]),
        DeliveryCheckId.frameSize,
      );
      expect(c.level, DeliveryCheckLevel.ok);
      expect(c.aspectLabel, '16:9');
      expect(c.unknownSizeCount, 0);
    });

    test('不一致 → ! 警告（EDL 照写，剪辑软件里会出黑边），列出两种比', () {
      final DeliveryCheck c = _check(
        _run(<DeliveryShotPlan>[
          _video(index: 1),
          _video(index: 2, width: 1080, height: 1920),
        ]),
        DeliveryCheckId.frameSize,
      );
      expect(c.level, DeliveryCheckLevel.warn);
      expect(c.aspectLabels, <String>['16:9', '9:16']);
      expect(c.aspectLabel, isNull);
    });

    test('宽高缺失 → 未知，仍是 ✓（抽帧失败不该变成「不一致」）', () {
      final DeliveryCheck c = _check(
        _run(<DeliveryShotPlan>[_video(index: 1, width: null, height: null)]),
        DeliveryCheckId.frameSize,
      );
      expect(c.level, DeliveryCheckLevel.ok);
      expect(c.aspectLabel, isNull);
      expect(c.unknownSizeCount, 1);
    });

    test('一部分已知且一致、一部分未知 → ✓ + 未知计数', () {
      final DeliveryCheck c = _check(
        _run(<DeliveryShotPlan>[
          _video(index: 1),
          _video(index: 2, width: null, height: null),
        ]),
        DeliveryCheckId.frameSize,
      );
      expect(c.level, DeliveryCheckLevel.ok);
      expect(c.aspectLabel, '16:9');
      expect(c.unknownSizeCount, 1);
    });

    test('占位镜不参与画幅判定（它没有产物）', () {
      final DeliveryCheck c = _check(
        _run(<DeliveryShotPlan>[_video(index: 1), _gap(index: 2)]),
        DeliveryCheckId.frameSize,
      );
      expect(c.unknownSizeCount, 0);
      expect(c.aspectLabel, '16:9');
    });

    test('比值按最大公约数约分', () {
      expect(aspectRatioLabel(1920, 1080), '16:9');
      expect(aspectRatioLabel(1024, 1024), '1:1');
      expect(aspectRatioLabel(1280, 720), '16:9');
      expect(aspectRatioLabel(null, 1080), isNull);
      expect(aspectRatioLabel(1920, 0), isNull);
    });
  });

  group('3 缺失产物', () {
    test('一个都不缺 → ✓', () {
      final DeliveryCheck c = _check(
        _run(<DeliveryShotPlan>[_video(index: 1)]),
        DeliveryCheckId.missingArtifacts,
      );
      expect(c.level, DeliveryCheckLevel.ok);
      expect(c.missing, isEmpty);
    });

    test('有缺 → ! 警告，每个缺失镜一条', () {
      final DeliveryCheck c = _check(
        _run(<DeliveryShotPlan>[
          _video(index: 1),
          _gap(index: 2, name: '收尾空镜'),
        ]),
        DeliveryCheckId.missingArtifacts,
      );
      expect(c.level, DeliveryCheckLevel.warn);
      expect(c.missing.length, 1);
      expect(c.missing.single.name, '收尾空镜');
      expect(c.missing.single.index, 2);
    });

    test('超过 3 个折叠为「另有 N 个」', () {
      final List<DeliveryShotPlan> five = <DeliveryShotPlan>[
        for (int i = 1; i <= 5; i++) _gap(index: i),
      ];
      final DeliveryCheck c =
          _check(_run(five), DeliveryCheckId.missingArtifacts);
      expect(c.missing.length, 5, reason: '检查项本身不折叠，折叠是呈现的事');
      final shown = collapseMissingShots(c.missing);
      expect(shown.shown.length, 3);
      expect(shown.extra, 2);
      expect(
        shown.shown.map((DeliveryShotPlan s) => s.index).toList(),
        <int>[1, 2, 3],
        reason: '折叠保留前三条的链上顺序',
      );
    });

    test('正好 3 个不折叠', () {
      final shown = collapseMissingShots(<DeliveryShotPlan>[
        for (int i = 1; i <= 3; i++) _gap(index: i),
      ]);
      expect(shown.shown.length, 3);
      expect(shown.extra, 0);
    });
  });

  group('4 项目上下文（BOARD 210 同一判据）', () {
    test('有项目 → ✓；没有 → ✕ 阻断', () {
      expect(
        _check(_run(<DeliveryShotPlan>[_video(index: 1)]),
                DeliveryCheckId.projectContext)
            .level,
        DeliveryCheckLevel.ok,
      );
      final DeliveryPreflight p =
          _run(<DeliveryShotPlan>[_video(index: 1)], hasProject: false);
      expect(
        _check(p, DeliveryCheckId.projectContext).level,
        DeliveryCheckLevel.block,
      );
      expect(p.canDeliver, isFalse);
    });
  });

  group('5 输出目录可写', () {
    test('可写 → ✓；不可写 → ✕ 阻断', () {
      expect(
        _check(_run(<DeliveryShotPlan>[_video(index: 1)]),
                DeliveryCheckId.outputWritable)
            .level,
        DeliveryCheckLevel.ok,
      );
      final DeliveryPreflight p =
          _run(<DeliveryShotPlan>[_video(index: 1)], outputWritable: false);
      expect(
        _check(p, DeliveryCheckId.outputWritable).level,
        DeliveryCheckLevel.block,
      );
      expect(p.canDeliver, isFalse);
    });
  });

  group('汇总：计数 / 可交付 / 第一条阻断原因', () {
    test('全过 → 0 项待处理、可交付、无阻断', () {
      final DeliveryPreflight p = _run(<DeliveryShotPlan>[_video(index: 1)]);
      expect(p.pendingCount, 0);
      expect(p.canDeliver, isTrue);
      expect(p.firstBlocking, isNull);
    });

    test('待处理计数 = 警告 + 阻断的条数', () {
      final DeliveryPreflight p = _run(
        <DeliveryShotPlan>[
          _video(index: 1),
          _video(index: 2, width: 1080, height: 1920),
          _gap(index: 3),
        ],
        outputWritable: false,
      );
      // 画幅不一致（!）+ 缺失产物（!）+ 目录不可写（✕）。
      expect(p.pendingCount, 3);
      expect(p.canDeliver, isFalse);
    });

    test('第一条阻断原因按稿上的顺序取——项目上下文在输出目录之前', () {
      final DeliveryPreflight p = _run(
        <DeliveryShotPlan>[_video(index: 1)],
        hasProject: false,
        outputWritable: false,
      );
      expect(p.firstBlocking?.id, DeliveryCheckId.projectContext);
    });

    test('一条镜都没有：不阻断（空交付由按钮那层挡，不是检查项的事）', () {
      final DeliveryPreflight p = _run(const <DeliveryShotPlan>[]);
      expect(p.canDeliver, isTrue);
      expect(p.pendingCount, 0);
    });
  });
}
