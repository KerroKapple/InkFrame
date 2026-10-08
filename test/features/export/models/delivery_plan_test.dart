// 交付计划（P6）：序列 lens + 画布节点 + 交付设置 → 「每镜导出成什么文件、EDL 里写什么」。
//
// 钉的是三类容易错的换算：
//   - 序号 / 文件名：1 起、三位补零、镜头名清洗成**合法单层文件名**（CJK 超长名也要能落盘）；
//   - 占位：没有**视频** result 的镜一律是占位（只有图片的也算），不出文件、照占时间；
//   - 元数据取向：provider / seed / 提示词在 **config 节点**上，不在 shot 节点、也不在 result 节点上。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/provider_capabilities.dart'
    show CameraMovement;
import 'package:inkframe/core/models/shot_language.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/export/models/delivery_plan.dart';
import 'package:inkframe/features/export/models/delivery_settings.dart';
import 'package:inkframe/features/export/util/export_file_name.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';

CanvasNode _shot(String id, {required String label, int ms = 2000}) =>
    CanvasNode(
      id: id,
      label: label,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      typeConfig: <String, Object?>{
        'shot_notes': 'notes-$id',
        'duration_ms': ms,
      },
    );

CanvasNode _videoConfig(
  String id, {
  String? providerId,
  int? seed,
  String? prompt,
  String? laneId,
  bool ignoreLaneStyle = false,
  Map<String, Object?> extra = const <String, Object?>{},
}) =>
    CanvasNode(
      id: id,
      label: 'cfg-$id',
      type: CanvasNodeType.video,
      role: NodeRole.config,
      canvasId: 'c1',
      laneId: laneId,
      typeConfig: <String, Object?>{
        'provider_id': ?providerId,
        'seed': ?seed,
        'prompt': ?prompt,
        if (ignoreLaneStyle) 'ignore_lane_style': true,
        ...extra,
      },
    );

CanvasNode _videoResult(
  String id, {
  required String sourceNodeId,
  String file = 'videos/v.mp4',
  int durationMs = 2000,
  int? width,
  int? height,
}) =>
    CanvasNode(
      id: id,
      label: 'res-$id',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: sourceNodeId,
      createdAt: DateTime.utc(2026, 1, 1),
      typeConfig: <String, Object?>{
        'video_url': file,
        'duration_ms': durationMs,
        'width': ?width,
        'height': ?height,
      },
    );

CanvasEdge _narr(String id, String from, String to) => CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: from,
      targetNodeId: to,
      edgeType: EdgeType.narrative,
    );

/// 两镜链：s1 借 cfg1 的视频产物，s2 什么都没有 ⇒ 占位。
({List<CanvasNode> nodes, List<CanvasEdge> edges}) _twoShots({
  int? width,
  int? height,
  Map<String, Object?> cfgExtra = const <String, Object?>{},
  String? laneId,
  bool ignoreLaneStyle = false,
}) {
  final List<CanvasNode> nodes = <CanvasNode>[
    _shot('s1', label: '山径入镜'),
    _videoConfig(
      'cfg1',
      providerId: 'kling-v3',
      seed: 41207,
      prompt: 'a misty trail',
      laneId: laneId,
      ignoreLaneStyle: ignoreLaneStyle,
      extra: cfgExtra,
    ),
    _videoResult(
      'r1',
      sourceNodeId: 'cfg1',
      durationMs: 5000,
      width: width,
      height: height,
    ),
    _shot('s2', label: '收尾空镜', ms: 3000),
  ];
  return (
    nodes: nodes,
    edges: <CanvasEdge>[_narr('e1', 's1', 'cfg1'), _narr('e2', 'cfg1', 's2')],
  );
}

DeliveryPlan _plan({
  DeliverySettings settings = DeliverySettings.defaults,
  int? width = 1920,
  int? height = 1080,
  Map<String, Object?> cfgExtra = const <String, Object?>{},
  String? laneId,
  bool ignoreLaneStyle = false,
  Map<String, String> laneStylePrompts = const <String, String>{},
  String projectName = '山径破晓',
}) {
  final g = _twoShots(
    width: width,
    height: height,
    cfgExtra: cfgExtra,
    laneId: laneId,
    ignoreLaneStyle: ignoreLaneStyle,
  );
  return buildDeliveryPlan(
    projectName: projectName,
    lens: buildSequenceLens(nodes: g.nodes, edges: g.edges),
    nodes: g.nodes,
    settings: settings,
    laneStylePrompts: laneStylePrompts,
  );
}

void main() {
  group('文件名：{序号3位}_{镜头名}.mp4', () {
    test('序号 1 起、三位补零；占位镜没有文件名', () {
      final DeliveryPlan p = _plan();
      expect(p.shots.length, 2);
      expect(p.shots[0].index, 1);
      expect(p.shots[0].fileName, '001_山径入镜.mp4');
      expect(p.shots[1].index, 2);
      expect(p.shots[1].fileName, isNull, reason: '占位镜不出媒体文件');
    });

    test('非法字符被清洗，结果必须是合法单层文件名', () {
      // 路径分隔符 / 盘符冒号 / Windows 非法字符 / 尾点全在里面。
      const String nasty = 'a/b\\c:d*e?f"g<h>i|j..k ';
      final String name = deliveryMediaFileName(index: 7, shotName: nasty);
      expect(name.startsWith('007_'), isTrue);
      expect(name.endsWith('.mp4'), isTrue);
      expect(
        isValidExportBaseName(name),
        isTrue,
        reason: '清洗后仍非法 ⇒ 落盘会被路径守卫拦掉',
      );
    });

    test('CJK 超长名被截断，仍是合法单层名', () {
      final String long = '晨' * 60;
      final String name = deliveryMediaFileName(index: 1, shotName: long);
      expect(isValidExportBaseName(name), isTrue);
      expect(
        name.length,
        lessThan(44),
        reason: 'Windows MAX_PATH：名字不能把路径顶爆',
      );
    });

    test('名字清洗后为空 → 只留序号', () {
      expect(deliveryMediaFileName(index: 3, shotName: '///'), '003.mp4');
      expect(deliveryMediaFileName(index: 3, shotName: '   '), '003.mp4');
    });

    test('工程文件名取项目名，同样清洗', () {
      expect(deliveryProjectFileBaseName('山径破晓'), '山径破晓');
      expect(deliveryProjectFileBaseName('a/b:c'), 'a_b_c');
      expect(deliveryProjectFileBaseName('   '), 'delivery');
    });
  });

  group('占位：没有视频 result 的镜', () {
    test('无任何产物 → 占位，时长仍是该镜时长', () {
      final DeliveryPlan p = _plan();
      expect(p.shots[1].isPlaceholder, isTrue);
      expect(p.shots[1].durationMs, 3000);
      expect(p.shots[1].sourceRelativePath, isNull);
    });

    test('只有图片产物也算占位——交付的是视频时间线', () {
      final List<CanvasNode> nodes = <CanvasNode>[
        _shot('s1', label: '图镜'),
        _videoConfig('cfg1'),
        CanvasNode(
          id: 'r1',
          label: 'img',
          type: CanvasNodeType.image,
          role: NodeRole.result,
          canvasId: 'c1',
          sourceNodeId: 'cfg1',
          createdAt: DateTime.utc(2026, 1, 1),
          typeConfig: const <String, Object?>{'image_url': 'images/a.png'},
        ),
        _shot('s2', label: '尾'),
      ];
      final List<CanvasEdge> edges = <CanvasEdge>[
        _narr('e1', 's1', 'cfg1'),
        _narr('e2', 'cfg1', 's2'),
      ];
      final DeliveryPlan p = buildDeliveryPlan(
        projectName: 'P',
        lens: buildSequenceLens(nodes: nodes, edges: edges),
        nodes: nodes,
        settings: DeliverySettings.defaults,
      );
      expect(p.shots.first.isPlaceholder, isTrue);
      expect(p.shots.first.fileName, isNull);
    });

    test('mp4Count 只数真有视频产物的镜', () {
      expect(_plan().mp4Count, 1);
    });
  });

  group('源路径：项目根相对（画布相对要补 canvases/<id>/）', () {
    test('视频镜给出项目根相对路径', () {
      expect(_plan().shots.first.sourceRelativePath, 'canvases/c1/videos/v.mp4');
    });
  });

  group('时长 → 帧：与 EDL 同一换算', () {
    test('帧数按毫秒就近取整，总帧是逐镜累加', () {
      final DeliveryPlan p = _plan();
      // 5000ms @24fps = 120 帧；3000ms = 72 帧。
      expect(p.shots[0].durationFrames, 120);
      expect(p.shots[1].durationFrames, 72);
      expect(p.totalFrames, 192);
    });
  });

  group('像素尺寸：抽帧探针写的 width/height 透传上来', () {
    test('有就给，没有就是 null（未知，不是 0）', () {
      final DeliveryPlan withSize = _plan(width: 1920, height: 1080);
      expect(withSize.shots.first.width, 1920);
      expect(withSize.shots.first.height, 1080);
      final DeliveryPlan noSize = _plan(width: null, height: null);
      expect(noSize.shots.first.width, isNull);
      expect(noSize.shots.first.height, isNull);
    });
  });

  group('片段备注：镜头语言开关', () {
    test('开 → 英文镜头语言串（与注入提示词同一套术语，不随界面语言变）', () {
      final DeliveryPlan p = _plan(
        cfgExtra: <String, Object?>{
          ShotLanguage.keyShotSize: 'mediumShot',
          ShotLanguage.keyCameraAngle: 'eyeLevel',
          ShotLanguage.keyFocalLength: 35,
          'camera': 'pushIn',
        },
      );
      expect(
        p.shots.first.comment,
        'medium shot, dolly in, eye level, 35mm lens',
      );
      expect(p.shots.first.cameraMovement, CameraMovement.pushIn);
    });

    test('关 → 不写备注', () {
      final DeliveryPlan p = _plan(
        settings:
            DeliverySettings.defaults.copyWith(shotLanguageInComments: false),
        cfgExtra: <String, Object?>{ShotLanguage.keyShotSize: 'closeUp'},
      );
      expect(p.shots.first.comment, isNull);
    });

    test('开但一项镜头语言都没设 → 也不写空备注', () {
      expect(_plan().shots.first.comment, isNull);
    });
  });

  group('标记：场次 → 时间线标记开关', () {
    test('开 → 链上 shot 节点各起一个标记，标签是节点名', () {
      final DeliveryPlan p = _plan();
      expect(p.shots[0].marker, '山径入镜');
      expect(p.shots[1].marker, '收尾空镜');
    });

    test('关 → 一个标记都不写', () {
      final DeliveryPlan p = _plan(
        settings:
            DeliverySettings.defaults.copyWith(markersFromScenes: false),
      );
      expect(
        p.shots.every((DeliveryShotPlan s) => s.marker == null),
        isTrue,
      );
    });
  });

  group('元数据取向：config 节点是提示词 / provider / seed 的住所', () {
    test('provider / seed / prompt 取自 config 节点（不是 shot、不是 result）', () {
      final DeliveryShotPlan s = _plan().shots.first;
      expect(s.providerId, 'kling-v3');
      expect(s.seed, 41207);
      expect(s.prompt, 'a misty trail');
    });

    test('风格提示词取自 config 所在泳道；ignoreLaneStyle 时为 null', () {
      final DeliveryPlan on = _plan(
        laneId: 'lane-1',
        laneStylePrompts: const <String, String>{'lane-1': 'ink wash'},
      );
      expect(on.shots.first.stylePrompt, 'ink wash');
      final DeliveryPlan off = _plan(
        laneId: 'lane-1',
        ignoreLaneStyle: true,
        laneStylePrompts: const <String, String>{'lane-1': 'ink wash'},
      );
      expect(off.shots.first.stylePrompt, isNull);
    });

    test('占位镜没有 config ⇒ 这些字段全 null，不抛', () {
      final DeliveryShotPlan s = _plan().shots[1];
      expect(s.providerId, isNull);
      expect(s.seed, isNull);
      expect(s.prompt, isNull);
      expect(s.stylePrompt, isNull);
      expect(s.shotLanguage, ShotLanguage.empty);
    });
  });

  group('空链', () {
    test('没有镜 → 空计划，不抛', () {
      final DeliveryPlan p = buildDeliveryPlan(
        projectName: 'P',
        lens: SequenceLens.empty,
        nodes: const <CanvasNode>[],
        settings: DeliverySettings.defaults,
      );
      expect(p.isEmpty, isTrue);
      expect(p.mp4Count, 0);
      expect(p.totalFrames, 0);
    });
  });
}
