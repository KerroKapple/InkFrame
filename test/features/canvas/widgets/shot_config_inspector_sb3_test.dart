// SB-3：shot 面板的镜头级参数（预期时长 / 预期运镜）。
//
// 这两个控件的语义与 video 面板的同名控件**不同**：shot 记录的是导演意图，
// 此刻还没选 provider，所以运镜列**全量枚举**、时长列固定档位，而不是按
// provider 能力表钳制。能不能真做到由生成时 video inspector 的现有钳制收口。
// 下面的用例就是钉这条边界，以及「选回未设置要真能清掉」。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/shot_config_inspector.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

void main() {
  late InMemoryNodeRepository nodeRepo;

  setUp(() => nodeRepo = InMemoryNodeRepository());

  /// 建一个真行再挂面板——保存走 patchTypeConfig，行不存在会静默 no-op，
  /// 断言就永远绿了。
  Future<CanvasNode> seedShot(Map<String, Object?> typeConfig) async {
    final id = await nodeRepo.create(
      canvasId: 'cv1',
      type: 'shot',
      nodeRole: 'config',
      label: '',
      typeConfig: typeConfig,
    );
    return CanvasNode(
      id: id,
      label: '',
      type: CanvasNodeType.shot,
      canvasId: 'cv1',
      typeConfig: typeConfig,
    );
  }

  Future<void> pump(WidgetTester tester, CanvasNode node) async {
    await pumpInkApp(
      tester,
      Scaffold(body: ShotConfigInspector(node: node)),
      overrides: <Override>[
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
      ],
    );
    await tester.pumpAndSettle();
  }

  Map<String, Object?> savedConfig(String id) =>
      nodeRepo.rows[id]!['type_config']! as Map<String, Object?>;

  testWidgets('渲染时长/运镜标签 + 意图说明', (tester) async {
    final node = await seedShot(const <String, Object?>{});
    await pump(tester, node);

    expect(find.text('Intended duration'), findsOneWidget);
    expect(find.text('Intended camera movement'), findsOneWidget);
    expect(
      find.text('Recorded as intent — the provider you pick when generating '
          'decides what is actually supported.'),
      findsOneWidget,
    );
  });

  testWidgets('水化已存的 duration_ms / camera', (tester) async {
    final node = await seedShot(const <String, Object?>{
      'duration_ms': 10000,
      'camera': 'pushIn',
    });
    await pump(tester, node);

    expect(find.text('10s'), findsOneWidget);
    expect(find.text('Push in'), findsOneWidget);
    // 「未设置」占位不应同时被选中显示两次（下拉收起时只渲染选中项）。
    expect(find.text('Not set'), findsNothing);
  });

  testWidgets('运镜列全量枚举——不受 provider supportedCameras 钳制', (tester) async {
    final node = await seedShot(const <String, Object?>{});
    await pump(tester, node);

    // 展开运镜下拉：面板里第二个 DropdownButton。
    await tester.tap(find.byType(DropdownButton<CameraMovement?>));
    await tester.pumpAndSettle();

    // 9 个枚举一个不少。本测试没有注入任何 provider 能力表——video 面板在
    // 这种情况下整段隐藏，shot 面板必须照列。
    expect(CameraMovement.values, hasLength(9));
    for (final c in CameraMovement.values) {
      expect(
        find.byWidgetPredicate(
          (w) => w is DropdownMenuItem<CameraMovement?> && w.value == c,
        ),
        findsOneWidget,
        reason: '缺运镜选项：${c.name}',
      );
    }
  });

  testWidgets('选时长 → 落库 duration_ms = 秒 × 1000（与 video 面板同键同单位）',
      (tester) async {
    final node = await seedShot(const <String, Object?>{});
    await pump(tester, node);

    await tester.tap(find.byType(DropdownButton<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5s').last);
    await tester.pumpAndSettle();

    expect(savedConfig(node.id)['duration_ms'], 5000);
  });

  testWidgets('选运镜 → 落库枚举 name', (tester) async {
    final node = await seedShot(const <String, Object?>{});
    await pump(tester, node);

    await tester.tap(find.byType(DropdownButton<CameraMovement?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orbit').last);
    await tester.pumpAndSettle();

    expect(savedConfig(node.id)['camera'], 'orbit');
  });

  testWidgets('选回「未设置」→ 显式写 null 清掉,而不是被 merge 保留旧值',
      (tester) async {
    // patchTypeConfig 是 jsonb `||` 合并（fake 用 addAll 同构）：省略键会保留
    // 旧值。所以清空必须显式写 null,否则用户点了「未设置」却清不掉。
    final node = await seedShot(const <String, Object?>{
      'duration_ms': 10000,
      'camera': 'orbit',
    });
    await pump(tester, node);

    await tester.tap(find.byType(DropdownButton<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not set').last);
    await tester.pumpAndSettle();

    expect(savedConfig(node.id)['duration_ms'], isNull);
    expect(savedConfig(node.id)['camera'], 'orbit', reason: '不该殃及另一个键');
  });

  testWidgets('不在档位表里的历史 duration_ms 当未设置——不触发下拉断言',
      (tester) async {
    // 7 秒不在 [3,5,10,15] 里。硬塞进 DropdownButton.value 会命中
    // "value 不在 items" 断言直接崩面板。
    final node = await seedShot(const <String, Object?>{'duration_ms': 7000});
    await pump(tester, node);

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<DropdownButton<int?>>(find.byType(DropdownButton<int?>)).value,
      isNull,
    );
  });

  testWidgets('认不出的 camera 值当未设置,不抛', (tester) async {
    final node = await seedShot(const <String, Object?>{'camera': 'zoomBlur'});
    await pump(tester, node);

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<DropdownButton<CameraMovement?>>(
              find.byType(DropdownButton<CameraMovement?>))
          .value,
      isNull,
    );
  });
}
