// 交付面板（P6 §2）：四段可选性随 registry、禁用段不可点、格式行随目标变、
// 时间码非法回退、开关改动即落库、无项目上下文只剩空态、CJK 超长不溢出。
//
// 这里**不测几何**（那是 #243 静态复刻件的事，接线不该再抄一遍像素），只测
// 「谁决定了什么」与「改了之后库里有没有」。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/db/columns.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/export/delivery_keys.dart';
import 'package:inkframe/features/export/models/delivery_plan.dart';
import 'package:inkframe/features/export/models/delivery_settings.dart';
import 'package:inkframe/features/export/models/delivery_writer_registry.dart';
import 'package:inkframe/features/export/providers/delivery_writers.dart';
import 'package:inkframe/features/export/util/delivery_preflight.dart';
import 'package:inkframe/features/export/widgets/delivery_panel.dart';
import 'package:inkframe/features/export/widgets/delivery_panel_rows.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/test_app.dart';

const String _kProjectId = 'p1';

/// 记录写回的项目仓储——「改动即落库」靠它自证。
class _RecordingProjectRepo implements ProjectRepository {
  _RecordingProjectRepo({Map<String, Object?>? deliverySettings})
      : _row = <String, Object?>{
          ProjectCol.id: _kProjectId,
          ProjectCol.name: 'Alpha',
          ProjectCol.deliverySettings: ?deliverySettings,
        };

  final Map<String, Object?> _row;
  final List<Map<String, Object?>> patches = <Map<String, Object?>>[];

  /// 最后一次写回的交付设置（解析后）。一次都没写 → null。
  DeliverySettings? get lastSaved {
    for (final Map<String, Object?> p in patches.reversed) {
      final Object? v = p[ProjectCol.deliverySettings];
      if (v is Map<String, Object?>) return DeliverySettings.fromMap(v);
    }
    return null;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      id == _kProjectId ? Map<String, Object?>.of(_row) : null;

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    patches.add(patch);
    _row.addAll(patch);
    return 1;
  }

  @override
  Future<String> create({required String name, String? coverNodeId}) =>
      throw UnimplementedError();
  @override
  Future<int> hardDelete(String id) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> listAll() => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> listTrashed() =>
      throw UnimplementedError();
  @override
  Future<int> restore(String id) => throw UnimplementedError();
  @override
  Future<int> softDelete(String id) => throw UnimplementedError();
}

class _Nodes extends CanvasNodesController {
  _Nodes(this.nodes);
  final List<CanvasNode> nodes;
  @override
  Future<List<CanvasNode>> build(String canvasId) async => nodes;
}

class _Edges extends CanvasEdgesController {
  _Edges(this.edges);
  final List<CanvasEdge> edges;
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => edges;
}

class _Lanes extends CanvasLanesController {
  @override
  Future<List<StyleLane>> build(String canvasId) async => const <StyleLane>[];
}

class _FakeJianyingWriter implements DeliveryProjectWriter {
  const _FakeJianyingWriter();
  @override
  String get id => DeliveryWriterIds.jianyingDraft;
  @override
  String get fileExtension => 'json';
  @override
  String write(DeliveryPlan plan) => '{}';
}

CanvasNode _shot(String id, {required String label, int ms = 2000}) =>
    CanvasNode(
      id: id,
      label: label,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'shot_notes': 'n', 'duration_ms': ms},
    );

CanvasEdge _narr(String id, String from, String to) => CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: from,
      targetNodeId: to,
      edgeType: EdgeType.narrative,
    );

AppPaths _tempPaths() {
  final Directory tmp = Directory.systemTemp.createTempSync('ink_panel_');
  addTearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });
  return DefaultAppPaths.forRoot(tmp);
}

Future<_RecordingProjectRepo> _pump(
  WidgetTester tester, {
  bool withProject = true,
  List<CanvasNode> nodes = const <CanvasNode>[],
  List<CanvasEdge> edges = const <CanvasEdge>[],
  DeliveryWriterRegistry? registry,
  Map<String, Object?>? storedSettings,
}) async {
  final _RecordingProjectRepo repo =
      _RecordingProjectRepo(deliverySettings: storedSettings);
  await pumpInkApp(
    tester,
    const Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[DeliveryPanel(canvasId: 'c1')],
      ),
    ),
    surfaceSize: const Size(900, 700),
    overrides: <Override>[
      appPathsProvider.overrideWithValue(_tempPaths()),
      shellControllerProvider.overrideWith(
        () => ShellNavigator(
          initial: ShellState(
            tab: ShellTab.sequence,
            canvasId: 'c1',
            project: withProject
                ? const ProjectRef(id: _kProjectId, name: 'Alpha')
                : null,
          ),
        ),
      ),
      projectRepositoryProvider.overrideWith((_) async => repo),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => _Edges(edges)),
      canvasLanesControllerProvider.overrideWith(_Lanes.new),
      if (registry != null)
        deliveryWriterRegistryProvider.overrideWithValue(registry),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder _tcField() => find.descendant(
      of: find.byKey(DeliveryKeys.tcStartField),
      matching: find.byType(TextField),
    );

String _tcText(WidgetTester tester) =>
    tester.widget<TextField>(_tcField()).controller!.text;

void main() {
  group('目标软件：四段可选性只由写出器 registry 决定', () {
    testWidgets('出厂 registry：Resolve / Premiere 可点，Final Cut / 剪映 onTap 为 null',
        (tester) async {
      await _pump(tester);
      for (final DeliveryTarget t in <DeliveryTarget>[
        DeliveryTarget.resolve,
        DeliveryTarget.premiere,
      ]) {
        expect(
          tester
              .widget<GestureDetector>(find.byKey(DeliveryKeys.segment(t)))
              .onTap,
          isNotNull,
          reason: '$t 有 EDL 写出器，应可选',
        );
      }
      for (final DeliveryTarget t in <DeliveryTarget>[
        DeliveryTarget.finalCut,
        DeliveryTarget.jianying,
      ]) {
        expect(
          tester
              .widget<GestureDetector>(find.byKey(DeliveryKeys.segment(t)))
              .onTap,
          isNull,
          reason: '$t 没有写出器 ⇒ onTap 必须是 null，不是空闭包',
        );
      }
    });

    testWidgets('禁用段的 Tooltip 写「待支持」；可选段不挂 Tooltip', (tester) async {
      await _pump(tester);
      String? tooltipOf(DeliveryTarget t) {
        final Iterable<Tooltip> found = tester.widgetList<Tooltip>(
          find.ancestor(
            of: find.byKey(DeliveryKeys.segment(t)),
            matching: find.byType(Tooltip),
          ),
        );
        return found.isEmpty ? null : found.first.message;
      }

      expect(tooltipOf(DeliveryTarget.finalCut), 'FCPXML support is pending');
      expect(
        tooltipOf(DeliveryTarget.jianying),
        'Jianying draft support is pending',
      );
      expect(tooltipOf(DeliveryTarget.resolve), isNull);
    });

    testWidgets('registry 多一个 jianying-draft ⇒ 剪映当场变可选（枚举没动）',
        (tester) async {
      await _pump(
        tester,
        registry: const MapDeliveryWriterRegistry(<DeliveryProjectWriter>[
          EdlCmx3600Writer(),
          _FakeJianyingWriter(),
        ]),
      );
      expect(
        tester
            .widget<GestureDetector>(
              find.byKey(DeliveryKeys.segment(DeliveryTarget.jianying)),
            )
            .onTap,
        isNotNull,
      );
    });
  });

  group('格式行：由目标推导', () {
    testWidgets('默认 Resolve → EDL CMX3600；切 Premiere 仍是 EDL', (tester) async {
      final _RecordingProjectRepo repo = await _pump(tester);
      expect(
        find.descendant(
          of: find.byKey(DeliveryKeys.formatValue),
          matching: find.text('EDL CMX3600'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(DeliveryKeys.segment(DeliveryTarget.premiere)));
      await tester.pumpAndSettle();
      expect(repo.lastSaved?.target, DeliveryTarget.premiere);
      expect(
        find.descendant(
          of: find.byKey(DeliveryKeys.formatValue),
          matching: find.text('EDL CMX3600'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('切到接了新写出器的段 → 格式行跟着变', (tester) async {
      await _pump(
        tester,
        registry: const MapDeliveryWriterRegistry(<DeliveryProjectWriter>[
          EdlCmx3600Writer(),
          _FakeJianyingWriter(),
        ]),
      );
      await tester.tap(find.byKey(DeliveryKeys.segment(DeliveryTarget.jianying)));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(DeliveryKeys.formatValue),
          matching: find.text('JSON'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('没有写出器的段（库里存着 final_cut）→ 格式行是「—」', (tester) async {
      await _pump(
        tester,
        storedSettings: <String, Object?>{'target': 'final_cut'},
      );
      expect(
        find.descendant(
          of: find.byKey(DeliveryKeys.formatValue),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
    });
  });

  group('时间码起点', () {
    testWidgets('默认 01:00:00:00；合法输入落库', (tester) async {
      final _RecordingProjectRepo repo = await _pump(tester);
      expect(_tcText(tester), '01:00:00:00');
      await tester.enterText(_tcField(), '02:00:00:12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repo.lastSaved?.timecodeStartFrames, 24 * 7200 + 12);
    });

    testWidgets('非法输入 → 回退原值，且一个字都不写库', (tester) async {
      final _RecordingProjectRepo repo = await _pump(tester);
      await tester.enterText(_tcField(), '乱写的');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_tcText(tester), '01:00:00:00', reason: '非法即回退');
      expect(repo.lastSaved, isNull, reason: '非法值不该进库');
    });

    testWidgets('越界帧位（24fps 没有第 24 帧）也算非法', (tester) async {
      final _RecordingProjectRepo repo = await _pump(tester);
      await tester.enterText(_tcField(), '01:00:00:24');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_tcText(tester), '01:00:00:00');
      expect(repo.lastSaved, isNull);
    });
  });

  group('三个开关：改动即存，无保存按钮', () {
    testWidgets('相对路径 / 场次标记 / 镜头语言各点一次都落库', (tester) async {
      final _RecordingProjectRepo repo = await _pump(tester);
      await tester.tap(find.byKey(DeliveryKeys.relativePathsToggle));
      await tester.pumpAndSettle();
      expect(repo.lastSaved?.relativePaths, isFalse);

      await tester.tap(find.byKey(DeliveryKeys.sceneMarkersToggle));
      await tester.pumpAndSettle();
      expect(repo.lastSaved?.markersFromScenes, isFalse);

      await tester.tap(find.byKey(DeliveryKeys.shotLanguageToggle));
      await tester.pumpAndSettle();
      expect(repo.lastSaved?.shotLanguageInComments, isFalse);
      // 前两次的改动没被后一次覆盖掉。
      expect(repo.lastSaved?.relativePaths, isFalse);
      expect(repo.lastSaved?.markersFromScenes, isFalse);
    });

    testWidgets('库里存着关闭态 → 开关呈现为关，注解文字跟着换', (tester) async {
      await _pump(
        tester,
        storedSettings: <String, Object?>{'relative_paths': false},
      );
      expect(find.text('Off (absolute paths)'), findsOneWidget);
      expect(find.text('On (folder stays portable)'), findsNothing);
    });

    testWidgets('稿上「提示词 → metadata.json」那一行已删（提示词恒写，不给开关）',
        (tester) async {
      await _pump(tester);
      expect(find.text('metadata.json'), findsNothing);
    });
  });

  group('门控：没有项目上下文', () {
    testWidgets('整面板只剩「请先打开一个项目」，不碰仓储', (tester) async {
      final _RecordingProjectRepo repo =
          await _pump(tester, withProject: false);
      expect(find.byKey(DeliveryKeys.panel), findsOneWidget);
      expect(find.byKey(DeliveryKeys.emptyState), findsOneWidget);
      expect(find.text('Open a project first'), findsOneWidget);
      // 检查清单 / 底部摘要都不在树上。
      expect(find.byKey(DeliveryKeys.preflight), findsNothing);
      expect(find.byKey(DeliveryKeys.footerOutput), findsNothing);
      expect(repo.patches, isEmpty);
    });
  });

  group('交付前检查与底部摘要上屏', () {
    testWidgets('两镜一缺 → 检查清单五条在树、摘要「包含」行数与计划一致',
        (tester) async {
      await _pump(
        tester,
        nodes: <CanvasNode>[
          _shot('s1', label: '山径入镜'),
          _shot('s2', label: '收尾空镜'),
        ],
        edges: <CanvasEdge>[_narr('e1', 's1', 's2')],
      );
      expect(find.byKey(DeliveryKeys.preflight), findsOneWidget);
      expect(find.byKey(DeliveryKeys.check(DeliveryCheckId.frameRate)),
          findsOneWidget);
      expect(find.byKey(DeliveryKeys.check(DeliveryCheckId.missingArtifacts)),
          findsOneWidget);
      // 两镜都没有视频产物 ⇒ 2 项待处理里至少有缺失那一条，mp4 数为 0。
      expect(find.text('0 mp4 · 1 edl · metadata.json'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CJK 超长（镜头名 60 字）', () {
    testWidgets('命名预览 / 缺失提示 / 摘要行都不溢出', (tester) async {
      final String long = '晨' * 60;
      await _pump(
        tester,
        nodes: <CanvasNode>[
          _shot('s1', label: long),
          _shot('s2', label: long),
        ],
        edges: <CanvasEdge>[_narr('e1', 's1', 's2')],
      );
      // RenderFlex overflow 在测试里是 FlutterError，takeException 能抓到。
      expect(tester.takeException(), isNull);
      expect(find.byKey(DeliveryKeys.footerInclude), findsOneWidget);
      expect(find.byKey(DeliveryKeys.check(DeliveryCheckId.missingArtifacts)),
          findsOneWidget);
    });

    testWidgets('超长路径在摘要行里中间省略', (tester) async {
      await _pump(tester);
      final String shown = tester
          .widget<Text>(find.byKey(DeliveryKeys.footerOutput))
          .data!;
      // 真实路径（临时目录 + projects/p1/exports）必然超过一行 ⇒ 必有省略号。
      expect(shown.contains('…'), isTrue);
      expect(shown.endsWith('exports'), isTrue, reason: '尾部那一半才有信息');

      // 串对了还不够——它得**放得下**。
      //
      // 只断言串的形状时这条是绿的，而界面上渲染出来却是「C:\Users\Kerro\AppDa…」：
      // 中间省略算出 40 字、盒子只放得下二十几个，Flutter 又从尾部硬裁一刀，
      // 把尾巴连同省略号一起切掉了。拿自然宽度跟分到的宽度比，才钉得住。
      final RenderParagraph para = tester.renderObject<RenderParagraph>(
        find.byKey(DeliveryKeys.footerOutput),
      );
      expect(
        para.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(para.size.width + 0.5),
        reason: '文本的自然宽度超过分到的宽度 ⇒ 渲染时会被裁，中间省略白做',
      );
    });

    test('middleEllipsisPath：短的原样、长的掐中间', () {
      expect(middleEllipsisPath('short', maxChars: 40), 'short');
      const String long = 'C:/Users/x/AppData/Local/InkFrame/projects/abc/exports';
      final String out = middleEllipsisPath(long, maxChars: 20);
      expect(out.length, 20);
      expect(out.startsWith('C:/Users/x'), isTrue);
      expect(out.endsWith('exports'), isTrue);
      expect(out.contains('…'), isTrue);
    });
  });
}
