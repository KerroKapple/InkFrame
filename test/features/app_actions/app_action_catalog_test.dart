// 应用级动作表（kAppActions）：菜单栏 / 右键菜单 / ⌘K / 快捷键页共用的一张表。
//
// 钉住的几件事：
// 1. id 唯一；第二批的占位行（★）每个都在表里。
// 2. 禁用必有原因：isEnabled 为假 ⇔ disabledReason 非 null（四个上下文逐行查）。
// 3. ★ 行恒灰、原因「即将推出」、不进 ⌘K。
// 4. 键位取自快捷键注册表 / kCommandPaletteActivators，不另抄（identical）。
// 5. 重做：Windows Ctrl+Y、macOS ⌘⇧Z；每平台的键位串不带另一平台的修饰键。
// 6. 节点组跟着选中集走（与节点右键菜单同一组判据）；不在画布上时画布 / 节点组灰着，原因「先打开一个画布」。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/app_actions/app_action.dart';
import 'package:inkframe/features/app_actions/app_action_catalog.dart';
import 'package:inkframe/features/app_actions/app_action_ids.dart';
import 'package:inkframe/features/app_actions/planned_keys.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/command_palette/palette_activators.dart';
import 'package:inkframe/features/settings/util/shortcut_catalog.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/test_app.dart';

const String _canvasId = 'c1';
const ProjectRef _project = ProjectRef(id: 'p1', name: 'Alpha');

/// 第二批的占位行（comingSoon）。
const Set<String> _comingSoonIds = <String>{
  AppActionIds.undo,
  AppActionIds.redo,
  AppActionIds.cut,
  AppActionIds.copy,
  AppActionIds.paste,
  AppActionIds.find,
  AppActionIds.importMedia,
  AppActionIds.newNote,
  AppActionIds.wrapInLane,
  AppActionIds.focusNotifications,
};

/// 带非空提示词的图像配置（generationTarget 要求提示词非空）、一张文本节点、一张可导出的视频产物。
final List<CanvasNode> _seed = <CanvasNode>[
  const CanvasNode(
    id: 'img',
    label: 'Shot A',
    type: CanvasNodeType.image,
    canvasId: _canvasId,
    typeConfig: <String, Object?>{'prompt': 'a cat on a roof'},
  ),
  const CanvasNode(
    id: 'txt',
    label: 'Note',
    type: CanvasNodeType.text,
    canvasId: _canvasId,
    position: Offset(300, 0),
  ),
  const CanvasNode(
    id: 'vid',
    label: 'clip',
    type: CanvasNodeType.video,
    role: NodeRole.result,
    projectId: 'p1',
    canvasId: _canvasId,
    position: Offset(600, 0),
    typeConfig: <String, Object?>{'video_url': 'videos/a.mp4'},
  ),
];

const ShellState _studio = ShellState();
const ShellState _onCanvas =
    ShellState(tab: ShellTab.canvas, canvasId: _canvasId, project: _project);
const ShellState _settingsOverCanvas = ShellState(
  tab: ShellTab.canvas,
  overlay: ShellOverlay.settings,
  canvasId: _canvasId,
  project: _project,
);

/// 一个装好的上下文：Consumer 交出来的 context / ref + 容器。
class _Rig {
  _Rig(this.context, this.ref, this.container);

  final BuildContext context;
  final WidgetRef ref;
  final ProviderContainer container;

  AppLocalizations get l => AppLocalizations.of(context);

  AppActionContext get c => AppActionContext.read(context, ref);

  void select(Iterable<String> ids) => container
      .read(canvasSelectionControllerProvider(_canvasId).notifier)
      .selectAll(ids);
}

/// 外壳播种成 [shell]，画布 c1 的节点 = [_seed]；节点 / 边 / 泳道 / 选中都先挂上订阅并预热——判据里的 ref.read
/// 没有订阅者时只拿得到 AsyncLoading（生产里 CanvasScreen 常驻 watch 它们）。
Future<_Rig> _pump(WidgetTester tester, ShellState shell) async {
  late BuildContext captured;
  late WidgetRef capturedRef;
  await pumpInkApp(
    tester,
    Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        captured = context;
        capturedRef = ref;
        return const SizedBox.shrink();
      },
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(() => ShellNavigator(initial: shell)),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(_seed)),
      canvasEdgesControllerProvider.overrideWith(FakeEdgesController.new),
      canvasLanesControllerProvider.overrideWith(EmptyLanesController.new),
    ],
  );
  final ProviderContainer container = ProviderScope.containerOf(captured);
  container.listen(canvasNodesControllerProvider(_canvasId), (_, _) {});
  container.listen(canvasEdgesControllerProvider(_canvasId), (_, _) {});
  container.listen(canvasLanesControllerProvider(_canvasId), (_, _) {});
  container.listen(canvasSelectionControllerProvider(_canvasId), (_, _) {});
  await container.read(canvasNodesControllerProvider(_canvasId).future);
  await container.read(canvasEdgesControllerProvider(_canvasId).future);
  await container.read(canvasLanesControllerProvider(_canvasId).future);
  return _Rig(captured, capturedRef, container);
}

AppAction _row(String id) {
  final AppAction? a = appActionById(id);
  expect(a, isNotNull, reason: '动作表里没有 $id');
  return a!;
}

/// 禁用必有原因：每个可用的行，isEnabled 为假 ⇔ disabledReason 非 null。
void _expectReasonIffDisabled(_Rig rig, String where) {
  final AppActionContext c = rig.c;
  for (final AppAction a in kAppActions) {
    if (!a.isAvailable(c)) continue;
    expect(
      a.disabledReason(c, rig.l) != null,
      !a.isEnabled(c),
      reason: '$where：${a.id} 的启用判据与禁用原因对不上',
    );
  }
}

void main() {
  test('id 唯一，且每个 ★ 占位 id 都有一行', () {
    final List<String> ids = kAppActions.map((AppAction a) => a.id).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'id 有重复');
    for (final String id in _comingSoonIds) {
      expect(ids, contains(id), reason: '占位行 $id 不在表里');
    }
  });

  group('禁用必有原因', () {
    testWidgets('Studio', (tester) async {
      _expectReasonIffDisabled(await _pump(tester, _studio), 'Studio');
    });

    testWidgets('画布、没选中', (tester) async {
      _expectReasonIffDisabled(await _pump(tester, _onCanvas), '画布无选中');
    });

    testWidgets('画布、选中一张图像配置', (tester) async {
      final _Rig rig = await _pump(tester, _onCanvas);
      rig.select(<String>['img']);
      _expectReasonIffDisabled(rig, '画布选中图像配置');
    });

    testWidgets('画布上开着设置浮层', (tester) async {
      _expectReasonIffDisabled(await _pump(tester, _settingsOverCanvas), '设置浮层');
    });
  });

  // 每个上下文单独 pump：同一个用例里重复 pumpInkApp 只会更新 ProviderScope，外壳停在第一次播种的状态。
  for (final (String name, ShellState shell) in <(String, ShellState)>[
    ('画布上', _onCanvas),
    ('Studio', _studio),
  ]) {
    testWidgets('★ 行灰着、原因「即将推出」、不进 ⌘K（$name）', (tester) async {
      final _Rig rig = await _pump(tester, shell);
      final AppActionContext c = rig.c;
      for (final String id in _comingSoonIds) {
        final AppAction a = _row(id);
        expect(a.isAvailable(c), isTrue, reason: '$id 灰着不藏');
        expect(a.isEnabled(c), isFalse, reason: id);
        expect(a.disabledReason(c, rig.l), rig.l.appActionReasonComingSoon, reason: id);
        expect(a.inPalette, isNull, reason: '$id 不进 ⌘K');
      }
    });
  }

  test('键位取自快捷键注册表 / ⌘K 键位表，不另抄', () {
    const Map<String, String> bindingOf = <String, String>{
      AppActionIds.selectAll: 'canvasSelectAll',
      AppActionIds.duplicate: 'canvasDuplicate',
      AppActionIds.generate: 'canvasGenerate',
      AppActionIds.fitAll: 'canvasFitAll',
      AppActionIds.zoomReset: 'canvasZoomReset',
      AppActionIds.toggleLeftRail: 'canvasToggleLeftRail',
    };
    bindingOf.forEach((String actionId, String bindingId) {
      final AppAction a = _row(actionId);
      final ShortcutActivator? mac = canvasBindingActivator(bindingId, isMac: true);
      final ShortcutActivator? other = canvasBindingActivator(bindingId, isMac: false);
      expect(mac, isNotNull, reason: '注册表里没有 $bindingId');
      expect(identical(a.macKey, mac), isTrue, reason: '$actionId 的 macOS 键位不是 $bindingId 那一个');
      expect(identical(a.otherKey, other), isTrue, reason: '$actionId 的其他平台键位不是 $bindingId 那一个');
    });

    final AppAction palette = _row(AppActionIds.commandPalette);
    expect(identical(palette.macKey, kCommandPaletteActivators[0]), isTrue);
    expect(identical(palette.otherKey, kCommandPaletteActivators[1]), isTrue);
  });

  test('重做：Windows Ctrl+Y、macOS ⌘⇧Z；撤销 ⌘Z / Ctrl+Z；两者都不吃自动重复', () {
    final AppAction undo = _row(AppActionIds.undo);
    final AppAction redo = _row(AppActionIds.redo);
    expect(undo.keyLabel(isMac: true), '⌘Z');
    expect(undo.keyLabel(isMac: false), 'Ctrl+Z');
    expect(redo.keyLabel(isMac: true), '⌘⇧Z');
    expect(redo.keyLabel(isMac: false), 'Ctrl+Y');
    expect(identical(redo.macKey, PlannedKeys.redoMac), isTrue);
    expect(identical(redo.otherKey, PlannedKeys.redoOther), isTrue);
    for (final SingleActivator k in <SingleActivator>[
      PlannedKeys.undoMac,
      PlannedKeys.undoOther,
      PlannedKeys.redoMac,
      PlannedKeys.redoOther,
    ]) {
      expect(k.includeRepeats, isFalse, reason: '$k');
    }
  });

  test('每行在两个平台上的键位串：有键就出得了字，且不带另一平台的修饰键', () {
    for (final AppAction a in kAppActions) {
      for (final bool isMac in <bool>[true, false]) {
        final String? label = a.keyLabel(isMac: isMac);
        if (a.keyFor(isMac: isMac) != null) {
          expect(label, isNotNull, reason: '${a.id} 在 isMac=$isMac 下有键却出不了字');
        }
        if (label == null) continue;
        expect(label, isMac ? isNot(contains('Ctrl')) : isNot(contains('⌘')), reason: a.id);
      }
    }
  });

  group('节点组跟着选中走', () {
    testWidgets('选中一张带提示词的图像配置 → 生成可点；存为角色灰着，原因「选中一张图像产物」', (tester) async {
      final _Rig rig = await _pump(tester, _onCanvas);
      rig.select(<String>['img']);
      final AppActionContext c = rig.c;

      final AppAction generate = _row(AppActionIds.generate);
      expect(generate.isEnabled(c), isTrue);
      expect(generate.disabledReason(c, rig.l), isNull);

      final AppAction save = _row(AppActionIds.saveAsCharacter);
      expect(save.isEnabled(c), isFalse);
      expect(save.disabledReason(c, rig.l), rig.l.appActionReasonSelectOneImage);
    });

    testWidgets('没选中 → 生成灰着，原因「选中一个配置节点才能生成」', (tester) async {
      final _Rig rig = await _pump(tester, _onCanvas);
      final AppActionContext c = rig.c;
      final AppAction generate = _row(AppActionIds.generate);
      expect(generate.isEnabled(c), isFalse);
      expect(generate.disabledReason(c, rig.l), rig.l.appActionReasonSelectOneConfig);
    });

    // 「选中非空」不是生成的判据：选中两张（哪怕其中一张能生成）同样不可点——与 Ctrl+↵「恰好选中一张」同口径。
    testWidgets('选中两张（图像配置 + 文本）→ 生成灰着，原因同上', (tester) async {
      final _Rig rig = await _pump(tester, _onCanvas);
      rig.select(<String>['img', 'txt']);
      final AppActionContext c = rig.c;
      final AppAction generate = _row(AppActionIds.generate);
      expect(generate.isEnabled(c), isFalse);
      expect(generate.disabledReason(c, rig.l), rig.l.appActionReasonSelectOneConfig);
    });
  });

  testWidgets('不在画布标签：画布 / 节点组灰着不藏，原因「先打开一个画布」', (tester) async {
    final _Rig rig = await _pump(tester, _studio);
    final AppActionContext c = rig.c;
    for (final AppAction a in kAppActions) {
      if (a.group != AppActionGroup.canvas && a.group != AppActionGroup.node) continue;
      if (_comingSoonIds.contains(a.id)) continue;
      expect(a.isAvailable(c), isTrue, reason: '${a.id} 灰着不藏');
      expect(a.isEnabled(c), isFalse, reason: a.id);
      expect(a.disabledReason(c, rig.l), rig.l.appActionReasonOpenCanvas, reason: a.id);
    }
  });
}
