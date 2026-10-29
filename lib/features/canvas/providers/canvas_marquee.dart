// CanvasMarqueeController — 框选进行中的状态（Selection 稿「框选与加减选」）。纯 UI 态，不落库、不进撤销栈。
//
// 命中在这里一处算（主 Agent 决定 1 → A）：拖动（StageMarqueeDetector）、修饰键变化与贴边自动平移
// （MarqueeLayer）三个入口都只调本控制器，控制器用 ref.read 现取节点 / 泳道 / 方向 / 折叠集 / 相机，
// 按 util/selection_geometry.dart 的 marqueeHits + applyMarquee 算，结果实时写回选中控制器（replace）。
// 每次 update 都按此刻的节点集重算——框选途中别处删了节点，被删的 id 不会留在选中里（规则 15）。
//
// 状态机：null（没在框选）→ begin（快照按下前的选中、清选中连线）→ update / setMode（实时写回选中）→
// commit（收框、选中保留）或 cancel（Esc / 指针取消：恢复按下前的选中，滤掉已删节点）→ null。
// 收框之后指针还按着（cancelled）：update 一律不理，不重新起框——起框只有 begin 一个入口。
//
// autoDispose + 按画布分族：MarqueeLayer watch 它（画框要用），画布卸载即回收。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import '../util/lane_geometry.dart';
import '../util/selection_geometry.dart';
import 'canvas_lanes_controller.dart';
import 'canvas_nodes_controller.dart';
import 'canvas_selection_controller.dart';
import 'canvas_transform_controller.dart';
import 'lane_collapse_controller.dart';
import 'selected_edge_controller.dart';

/// 屏幕逻辑 px：按下到松手挪动没到它 = 点（KeyMap「4px 内松开算点」）；到了就起框。
const double kMarqueeClickSlop = 4;

/// 一次框选的快照。框是舞台坐标：起点钉在世界里，缩放 / 平移时框跟着内容走。
@immutable
class MarqueeState {
  const MarqueeState({
    required this.startStage,
    required this.currentStage,
    required this.pointerGlobal,
    required this.before,
    required this.mode,
    required this.selectedCount,
  });

  /// 按下点（舞台坐标）。
  final Offset startStage;

  /// 框的另一角（舞台坐标）：指针此刻所在的舞台点。
  final Offset currentStage;

  /// 指针此刻的全局坐标——贴边自动平移判离视口边多远用；起框那一刻还没收到 move 时为 null。
  final Offset? pointerGlobal;

  /// 按下前的节点选中（Esc 恢复的就是它；加选 / 反选在它上面算）。
  final Set<String> before;

  /// 此刻的选择方式（随修饰键实时变）。
  final MarqueeMode mode;

  /// 写回之后的选中数（「已选 N」）：加选 / 反选时含 [before]。
  final int selectedCount;

  Rect get stageRect => Rect.fromPoints(startStage, currentStage);

  MarqueeState _copyWith({
    Offset? currentStage,
    Offset? pointerGlobal,
    MarqueeMode? mode,
    int? selectedCount,
  }) =>
      MarqueeState(
        startStage: startStage,
        currentStage: currentStage ?? this.currentStage,
        pointerGlobal: pointerGlobal ?? this.pointerGlobal,
        before: before,
        mode: mode ?? this.mode,
        selectedCount: selectedCount ?? this.selectedCount,
      );
}

/// 修饰键 → 选择方式。mac：⌘ 反选（Ctrl + 点在 mac 上是右键，不参与）；其余平台：Ctrl 反选。
/// 再看 Shift = 加选；都没按 = 替换。反选与加选同时按住 → 反选优先（设计缺口，本片拍板）。
MarqueeMode marqueeModeFor({
  required bool shift,
  required bool control,
  required bool meta,
  required TargetPlatform platform,
}) {
  final bool invert = platform == TargetPlatform.macOS ? meta : control;
  if (invert) return MarqueeMode.invert;
  if (shift) return MarqueeMode.add;
  return MarqueeMode.replace;
}

/// 按此刻按住的修饰键与当前平台取选择方式（起框时与修饰键变化时用）。
MarqueeMode currentMarqueeMode() {
  final HardwareKeyboard keyboard = HardwareKeyboard.instance;
  return marqueeModeFor(
    shift: keyboard.isShiftPressed,
    control: keyboard.isControlPressed,
    meta: keyboard.isMetaPressed,
    platform: defaultTargetPlatform,
  );
}

/// 画布 [canvasId] 的框选状态；null = 没在框选。
final canvasMarqueeProvider = AutoDisposeNotifierProviderFamily<
    CanvasMarqueeController, MarqueeState?, String>(
  CanvasMarqueeController.new,
  name: 'canvasMarqueeProvider',
);

class CanvasMarqueeController
    extends AutoDisposeFamilyNotifier<MarqueeState?, String> {
  @override
  MarqueeState? build(String canvasId) => null;

  /// 起框：快照按下前的选中、清掉选中连线（与点空白一致；Esc 不恢复连线选中）。
  /// 选中此刻不动——紧跟着的第一次 [update] 才按框写回。
  void begin(Offset startStage, {required MarqueeMode mode}) {
    final Set<String> before =
        Set<String>.of(ref.read(canvasSelectionControllerProvider(arg)));
    ref.read(selectedEdgeControllerProvider(arg).notifier).clear();
    state = MarqueeState(
      startStage: startStage,
      currentStage: startStage,
      pointerGlobal: null,
      before: before,
      mode: mode,
      selectedCount: before.length,
    );
  }

  /// 指针挪到 [currentStage]（舞台坐标，全局坐标 [pointerGlobal]）：按当前相机重算命中并写回选中。
  ///
  /// 没在框选（没起框，或已被 Esc / 指针取消收掉——cancelled 态）⇒ 什么都不做：收框之后指针还按着
  /// 继续拖，不重新起框。
  void update(Offset currentStage, {required Offset pointerGlobal}) {
    final MarqueeState? s = state;
    if (s == null) return;
    _apply(s._copyWith(currentStage: currentStage, pointerGlobal: pointerGlobal));
  }

  /// 修饰键变了：立即按新方式重算（不等指针再动）。没在框选或方式没变 ⇒ 不动。
  void setMode(MarqueeMode mode) {
    final MarqueeState? s = state;
    if (s == null || s.mode == mode) return;
    _apply(s._copyWith(mode: mode));
  }

  /// 松手：收框，选中保持此刻的样子。
  void commit() {
    if (state == null) return;
    state = null;
  }

  /// Esc / 指针取消：选中恢复成按下前（先滤掉已被删掉的节点），收框。
  /// 原来不在框选中 ⇒ false（Esc 阶梯据此知道这一层没东西可退）。
  bool cancel() {
    final MarqueeState? s = state;
    if (s == null) return false;
    ref
        .read(canvasSelectionControllerProvider(arg).notifier)
        .replace(_alive(s.before));
    state = null;
    return true;
  }

  void _apply(MarqueeState s) {
    final Set<String> next =
        applyMarquee(_alive(s.before), _hits(s.stageRect), s.mode);
    ref.read(canvasSelectionControllerProvider(arg).notifier).replace(next);
    state = s._copyWith(
      selectedCount: ref.read(canvasSelectionControllerProvider(arg)).length,
    );
  }

  /// [ids] 里此刻还在画布上的那些。节点集还没载入（拿不到）时原样返回——不知道谁被删了，就不删。
  Set<String> _alive(Set<String> ids) {
    final List<CanvasNode>? nodes =
        ref.read(canvasNodesControllerProvider(arg)).valueOrNull;
    if (nodes == null) return ids;
    final Set<String> present = <String>{for (final CanvasNode n in nodes) n.id};
    return ids.where(present.contains).toSet();
  }

  /// 舞台坐标的框 [stageRect] 此刻碰到哪些卡：按当前节点集、泳道有效厚度、方向、折叠集与相机现算。
  Set<String> _hits(Rect stageRect) {
    final List<CanvasNode> nodes =
        ref.read(canvasNodesControllerProvider(arg)).valueOrNull ??
            const <CanvasNode>[];
    final List<StyleLane> lanes =
        ref.read(canvasLanesControllerProvider(arg)).valueOrNull ??
            const <StyleLane>[];
    final LaneDirection direction =
        ref.read(canvasLaneDirectionProvider(arg)).valueOrNull ??
            LaneDirection.horizontal;
    final Set<String> collapsed = ref.read(laneCollapseProvider(arg));
    final Matrix4 transform =
        ref.read(canvasTransformControllerProvider(arg)).value;
    return marqueeHits(
      stageRect: stageRect,
      nodes: nodes,
      lanes: collapseLaneSlices(
        <({String id, double size})>[
          for (final StyleLane l in lanes) (id: l.id, size: l.size),
        ],
        collapsed,
      ),
      direction: direction,
      transform: transform,
      // 折叠道里的卡看不见，不参与命中（Selection 稿）。
      collapsedLaneIds: collapsed,
    );
  }
}
