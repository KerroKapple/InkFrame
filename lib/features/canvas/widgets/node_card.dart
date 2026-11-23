// NodeCard：画布上的单个节点卡片（Workspace v2 稿）。
//
// 224 宽：18px 标题行（名称 500 + 类型 10px）| 6 | 16:9 图区（4px 圆角 + 1px outline，
// 选中 accent；outline 画在盒子外一圈）| 6 | 16px 状态行（状态文字 + 等宽 meta）。
// 无外框、无阴影、无标题条底色。端口在图区垂直中心向外偏移 5px：入=空心，出=实心。
//
// 端口按需显示（画布重设计稿 › 画布交互）：悬停 / 选中 / 连线模式（起点或候选）时两侧
// 都亮出来，供连线；平时只留真挂着连线的那一侧（[NodeCard.hasInEdge] /
// [NodeCard.hasOutEdge]，由画布按存量边 + 产出线算好传进来）——没连线的卡片不再
// 挂着两颗悬空的小圆点。悬停态是本卡片的局部状态（MouseRegion），不进 provider。
//
// 稿上没有卡片角落的连线 / 删除小圆钮：连线走工具条「连线」（选中节点后），
// 删除走 Delete 键——[onStartLink] / [onDelete] 保留在 API 上供上层继续持有，
// 本卡片不再渲染它们。
//
// 图区内容：result 节点 = 缩略图（image / video）；还没出图 / 文件丢了的 result 占位 =
// 左下角一行 11px 小字（[_ThumbLabel]）。导入的媒体（type_config.origin = import）复制中时图区底部
// 叠一条进度条、状态行写「复制中 48%」，复制完状态行写「导入」、右侧写宽高；进度只订
// mediaImportControllerProvider 里自己那一格。
// config 节点（提示词条与节点文字稿）：正文（提示词 / 文本 / 镜头备注）贴图区顶部、最多三行，
// 12/1.55 fg2；图区底部另起一行 10px fg5 摘要——video config 是「起始帧 ← X · 结束帧 ← Y ·
// 运镜」，image config 是镜头语言摘要（设了才画）。以前 video 有入边时摘要会顶掉提示词，
// 现在两样都画。画布缩到 kCompactCardScale（0.6）以下时正文与摘要都收起，只留居中的类型
// 图标——那个缩放下几行小字糊成一团，谁也读不了。
//
// take 状态（TakesCost 稿「当前 take · 固定」）：同一配置名下有 ≥ 2 个产物时，result 卡按 util/take_status.dart 的
// resultTakeStatusOf 画——当前那张描边 accent（未选中时；选中本来就是 accent，选中优先、图钉照画），被固定时图区
// 右上角一枚图钉；非当前的图区半透明；状态行「take N / M」，当前的加「· 当前」，比当前新而当前是固定的加「· 未采用」。
// 只有一个产物的卡照旧。只订节点控制器里与自己有关的那份记录（select，记录结构相等，兄弟状态不变就不重建）；
// 节点控制器还没人起的时候（单独挂的卡：单测 / golden）不为一张卡去起它——那会去连库。
//
// 拖拽（HI-13）：位移累积在本卡片局部状态（Transform.translate），每帧只重建
// 自身；onPanEnd 把累计位移一次性回调 onDragEnd，由上层提交 controller。
//
// 出端口可拖（画布重设计稿 › 拖线到空白处 → 建节点）：按住出端口拖出去是拖线、不是拖卡片——端口上
// 的拖拽手势比卡片的更深，先过触摸阈值、先赢手势竞技场。卡片只管把指针的全局坐标经 [PortDragCallbacks]
// 交出去，落在哪、连不连线、开不开新建菜单都归画布（stage/node_card_slot.dart 的 NodeCardSlot）。外观一点没动：圆点还是
// 10px，只是外面多了一圈透明的命中区。从在端口上按下起端口就钉住、一直亮到松手（[_NodeCardState._portPressed]），
// 拖线期间同样亮着——它一收起来，上面的拖拽手势就跟着拆掉：没选中的卡端口只在悬停时亮，按下后慢慢往外拖，
// 指针先越出卡片盒、悬停态先掉，端口一拆，接着过阈值的就成了卡片自己的拖动（卡片被拖走、落库）。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../core/models/shot_language.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/components/ink_progress_bar.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/canvas_node_import.dart';
import '../models/style_lane.dart';
import '../providers/canvas_compact_cards.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/media_import_controller.dart';
import '../providers/node_active_job.dart';
import '../providers/node_drag_delta.dart';
import '../util/camera_labels.dart';
import '../util/lane_tint.dart';
import '../util/take_status.dart';
import 'video_node_body.dart';

/// 从出端口拖线的四个回调。坐标一律是指针的**全局**坐标——卡片不知道舞台的变换，换算归画布。
@immutable
class PortDragCallbacks {
  const PortDragCallbacks({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// 拖动被认出来（过了触摸阈值）的那一刻。
  final ValueChanged<Offset> onStart;

  /// 每次移动。
  final ValueChanged<Offset> onUpdate;

  /// 松手。
  final VoidCallback onEnd;

  /// 手势被系统取消。卡片在拖线途中被拆掉（节点被删）不归这里：手势跟着拆、这里回调不到，画布层看着节点集
  /// 取消拖线（canvas_view 的 _CanvasBody）。
  final VoidCallback onCancel;
}

class NodeCard extends ConsumerStatefulWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onDragEnd,
    this.lane,
    this.onStartLink,
    this.onDelete,
    this.isLinkSource = false,
    this.isLinkCandidate = false,
    this.hasInEdge = false,
    this.hasOutEdge = false,
    this.portDrag,
  });

  final CanvasNode node;

  /// 所在泳道（Lanes 稿改动 3）：卡片底部一行 6px 色点 + 「继承 X」——跨道拖动改写 lane_id 时
  /// 用户能立刻看见风格变了。无道节点为 null，该行留空（高度照旧预留，卡片尺寸恒定）。
  final StyleLane? lane;
  final bool selected;
  final VoidCallback onTap;

  /// 拖拽结束时回调一次累计位移（落点提交）；拖拽中不触发。
  final void Function(Offset totalDelta) onDragEnd;

  /// 进入连线模式的入口（本卡片不渲染，见头注）。
  final VoidCallback? onStartLink;

  /// 删除入口（本卡片不渲染，见头注）。
  final VoidCallback? onDelete;

  /// 本节点是否为当前连线模式的起点（UI 高亮）。
  final bool isLinkSource;

  /// 连线模式下此节点是否为合法目标（非起点 → 高亮为点击候选）。
  final bool isLinkCandidate;

  /// 入口这一侧真挂着一条画出来的线（存量边或推导的产出线）→ 入端口常驻。
  final bool hasInEdge;

  /// 出口这一侧真挂着一条画出来的线 → 出端口常驻。
  final bool hasOutEdge;

  /// 从出端口拖线（见 [PortDragCallbacks]）。null = 端口只是个圆点、按住拖动拖的是卡片。
  final PortDragCallbacks? portDrag;

  static const double thumbHeight = 126; // 224 × 9 / 16

  /// 出端口的拖线命中区边长：以圆点为中心的方块（圆点本身 10px，按不准）。卡片盒外的那一半点不到——
  /// 命中先按卡片盒界筛——所以真正按得住的是卡片右缘内侧那一条。
  static const double portHitExtent = 20;

  /// 入 / 出端口圆点的测试锚点（每张卡片内唯一）。
  static const Key inPortKey = ValueKey<String>('node-card-in-port');
  static const Key outPortKey = ValueKey<String>('node-card-out-port');

  /// config 卡图区正文（提示词 / 文本 / 镜头备注）的测试锚点。
  static const Key configTextKey = ValueKey<String>('node-card-config-text');

  /// config 卡图区底部摘要行的测试锚点。
  static const Key configSummaryKey = ValueKey<String>('node-card-config-summary');

  /// 缩小态居中类型图标的测试锚点。
  static const Key compactGlyphKey = ValueKey<String>('node-card-compact-glyph');

  /// 导入节点复制中叠在图区底部的进度条的测试锚点。
  static const Key importProgressKey = ValueKey<String>('node-card-import-progress');

  /// 被固定的当前 take 图区右上角图钉的测试锚点。
  static const Key takePinKey = ValueKey<String>('node-card-take-pin');

  /// 非当前 take 图区那层半透明的测试锚点。
  static const Key takeDimKey = ValueKey<String>('node-card-take-dim');

  @override
  ConsumerState<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends ConsumerState<NodeCard> {
  bool _dragging = false;

  /// 鼠标悬停在卡片上——两侧端口都亮出来（供连线）。
  bool _hovered = false;

  /// 拖拽中的累计位移——只重建本卡片，不推全画布 state。
  Offset _dragOffset = Offset.zero;

  /// 拖拽期捕获的广播口——dispose 兜底清残留用（dispose 后 ref 不可用）。
  StateController<NodeDragDelta?>? _dragBroadcast;

  /// 正从出端口往外拖线：拖线期间端口一直亮着（见头注）。
  bool _portDragging = false;

  /// 指针正按在出端口的命中区里（还没过拖动阈值也算）：端口钉住不收，抬起 / 取消才放（见头注）。
  bool _portPressed = false;

  @override
  void dispose() {
    // 拖线途中卡片被拆掉（节点被删）：拖线状态归画布层收（canvas_view 的 _CanvasBody 看着节点集）——
    // 这里收不了，回调要用的是卡片插槽的 ref，插槽已经卸载。
    // 拖拽中被删（如 Delete 快捷键）不会走 onPanEnd，广播会残留脏值；
    // 微任务延后清理避开 widget 树锁，容器已销毁时静默放弃。
    final broadcast = _dragBroadcast;
    final nodeId = widget.node.id;
    if (_dragging && broadcast != null) {
      scheduleMicrotask(() {
        try {
          if (broadcast.state?.nodeId == nodeId) broadcast.state = null;
        } on StateError {
          // ProviderContainer 已 dispose（应用退出/测试收尾）——无需清理。
        }
      });
    }
    super.dispose();
  }

  void _endDrag({required bool commit}) {
    final total = _dragOffset;
    setState(() {
      _dragging = false;
      _dragOffset = Offset.zero;
    });
    // 先清广播再提交落点：连线层切回 controller 座标，避免一帧双重位移。
    ref.read(nodeDragDeltaProvider.notifier).state = null;
    if (commit && total != Offset.zero) {
      widget.onDragEnd(total);
    }
  }

  void _broadcastDrag() {
    final broadcast = ref.read(nodeDragDeltaProvider.notifier);
    _dragBroadcast = broadcast;
    broadcast.state = (nodeId: widget.node.id, delta: _dragOffset);
  }

  void _setHovered(bool value) {
    if (_hovered == value || !mounted) return;
    setState(() => _hovered = value);
  }

  void _setPortDragging(bool value) {
    if (_portDragging == value || !mounted) return;
    setState(() => _portDragging = value);
  }

  void _setPortPressed(bool value) {
    if (_portPressed == value || !mounted) return;
    setState(() => _portPressed = value);
  }

  /// 出端口：10px 圆点居中放在 [NodeCard.portHitExtent] 见方的透明命中区里；可拖时命中区收拖拽手势。
  Widget _outPort(Color color) {
    final Widget dot = Center(
      child: Container(
        key: NodeCard.outPortKey,
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
    final PortDragCallbacks? drag = widget.portDrag;
    if (drag == null) return dot;
    return MouseRegion(
      cursor: SystemMouseCursors.precise,
      // 按下就钉住端口（不等拖动被认出来）：只听原始指针事件、不进手势竞技场，下面的拖线手势照旧。
      // 端口钉住期间这一层一直在树上，抬起 / 取消事件一定送得到（按下时的命中结果按指针缓存着）。
      child: Listener(
        onPointerDown: (PointerDownEvent _) => _setPortPressed(true),
        onPointerUp: (PointerUpEvent _) => _setPortPressed(false),
        onPointerCancel: (PointerCancelEvent _) => _setPortPressed(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) {
            _setPortDragging(true);
            drag.onStart(d.globalPosition);
          },
          onPanUpdate: (DragUpdateDetails d) => drag.onUpdate(d.globalPosition),
          onPanEnd: (DragEndDetails _) {
            _setPortDragging(false);
            drag.onEnd();
          },
          onPanCancel: () {
            _setPortDragging(false);
            drag.onCancel();
          },
          child: dot,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final highlighted =
        widget.selected || widget.isLinkSource || widget.isLinkCandidate;
    // 同源 ≥ 2 个 take 才画 take 状态；只有一个的卡照旧。
    final ResultTakeStatus? rawTake = _watchTakeStatus(ref, node);
    final ResultTakeStatus? take = rawTake != null && rawTake.total >= 2 ? rawTake : null;
    final bool currentTake = take?.current ?? false;
    final bool dimTake = take != null && !take.current;
    // 当前 take 描边 accent；选中也是 accent，选中优先（区分不了，图钉照画）。
    final Color edge = highlighted || currentTake ? colors.accent : colors.outline;
    final Color outPort = highlighted ? colors.accent : colors.fg5;
    // 稿：shot 节点只有出端口。
    final bool hasIn =
        !(node.type == CanvasNodeType.shot && node.role == NodeRole.config);
    // 端口按需显示：悬停 / 选中 / 连线模式两侧都亮；平时只留挂着线的那一侧。按在出端口上、拖线途中也亮着（见头注）。
    final bool revealPorts = _hovered || highlighted || _portDragging || _portPressed;
    final bool showInPort = hasIn && (revealPorts || widget.hasInEdge);
    final bool showOutPort = revealPorts || widget.hasOutEdge;

    return Transform.translate(
      offset: _dragOffset,
      child: MouseRegion(
        cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          // opaque：卡片内任何位置（含空图区）都可点选 / 拖拽。
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanStart: (_) {
            setState(() {
              _dragging = true;
              _dragOffset = Offset.zero;
            });
            _broadcastDrag();
          },
          onPanUpdate: (d) {
            setState(() => _dragOffset += d.delta);
            _broadcastDrag();
          },
          onPanEnd: (_) => _endDrag(commit: true),
          onPanCancel: () => _endDrag(commit: false),
          child: SizedBox(
            width: kNodeCardSize.width,
            height: kNodeCardSize.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 18,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            nodeDisplayName(context, node),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typo.bodyStrong.copyWith(color: colors.fg1),
                          ),
                        ),
                        const SizedBox(width: InkSpacing.sm),
                        Text(node.type.name, style: typo.micro.copyWith(color: colors.fg5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: InkSpacing.s6),
                SizedBox(
                  height: NodeCard.thumbHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: _dimIf(
                          dimTake,
                          ClipRRect(
                            borderRadius: BorderRadius.circular(InkRadius.sm),
                            child: ColoredBox(
                              color: colors.thumbFill,
                              child: _NodeBody(
                                node: node,
                                resolver: ref.watch(fileResolverServiceProvider),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 稿用的是 CSS outline：画在盒子【外】一圈，不占布局。
                      Positioned(
                        left: -1,
                        top: -1,
                        right: -1,
                        bottom: -1,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: edge),
                              borderRadius: BorderRadius.circular(InkRadius.s5),
                            ),
                          ),
                        ),
                      ),
                      if (take != null && take.pinned)
                        Positioned(
                          top: InkSpacing.xs,
                          right: InkSpacing.xs,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surface1,
                                borderRadius: BorderRadius.circular(InkRadius.s3),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(InkSpacing.s2),
                                child: InkIcon(
                                  InkGlyph.pin,
                                  key: NodeCard.takePinKey,
                                  size: InkIconSize.s14,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showInPort)
                        Positioned(
                          left: -5,
                          top: NodeCard.thumbHeight / 2 - 5,
                          child: Container(
                            key: NodeCard.inPortKey,
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.surface1,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.fg5, width: 1.5),
                            ),
                          ),
                        ),
                      if (showOutPort)
                        Positioned(
                          right: -NodeCard.portHitExtent / 2,
                          top: NodeCard.thumbHeight / 2 - NodeCard.portHitExtent / 2,
                          width: NodeCard.portHitExtent,
                          height: NodeCard.portHitExtent,
                          child: _outPort(outPort),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s6),
                SizedBox(
                  height: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
                    child: _StatusRow(node: node, take: take),
                  ),
                ),
                const SizedBox(height: 5),
                // 稿：14 高继承行——6px 方色点（道的 tint）+ 「继承 X」10px fg5。
                SizedBox(
                  height: 14,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s2),
                    child: widget.lane == null ? const SizedBox.shrink() : _InheritRow(lane: widget.lane!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 泳道继承行：色点取道的有效 tint（没有则 fg6），文字「继承 <道名>」。
class _InheritRow extends StatelessWidget {
  const _InheritRow({required this.lane});
  final StyleLane lane;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final Color? tint = effectiveLaneTint(tintColor: lane.tintColor, stylePrompt: lane.stylePrompt);
    final String name = lane.label.isEmpty ? context.l10n.laneUntitled : lane.label;
    return Row(
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: tint ?? colors.fg6,
            borderRadius: BorderRadius.circular(InkRadius.s1),
          ),
        ),
        const SizedBox(width: InkSpacing.s6),
        Expanded(
          child: Text(
            context.l10n.laneInherits(name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.micro.copyWith(color: colors.fg5),
          ),
        ),
      ],
    );
  }
}

/// 显示名：空标题回退类型名。
String nodeDisplayName(BuildContext context, CanvasNode node) =>
    node.label.isEmpty ? nodeTypeLabel(context, node.type) : node.label;

/// 引用名（用户拍板）：别处引用一个节点时不重复它的类型——「镜头 01 · 图像」引用为「镜头 01」。
/// 规则：label 以「 · <本地化类型名>」结尾时去掉该尾段；其余原样。
String nodeRefName(BuildContext context, CanvasNode node) {
  final String name = nodeDisplayName(context, node);
  final String suffix = ' · ${nodeTypeLabel(context, node.type)}';
  return name.endsWith(suffix) && name.length > suffix.length
      ? name.substring(0, name.length - suffix.length)
      : name;
}

String nodeTypeLabel(BuildContext context, CanvasNodeType type) => switch (type) {
      CanvasNodeType.image => context.l10n.canvasNodeImageType,
      CanvasNodeType.text => context.l10n.canvasNodeTextType,
      CanvasNodeType.video => context.l10n.canvasNodeVideoType,
      CanvasNodeType.shot => context.l10n.canvasNodeShotType,
    };

/// 节点状态的种类。判据只有 [nodeStatusOf] 一份：节点卡状态行与左栏大纲行共用，两处不会走岔。
enum NodeStatusKind { running, queued, done, pending, ready, draft }

/// 节点此刻的状态；[percent] 只在 running 时有值（进度 × 100 四舍五入）。
typedef NodeStatus = ({NodeStatusKind kind, int? percent});

/// 节点状态判据。
///
/// - [job]：nodeActiveJobProvider 的值（只会是非终态）。running → 进行中带百分比；
///   queued / submitting → 排队中。终态在那条 provider 里到不了，真来了按「就绪」报（与抽出前同口径）。
/// - 没有活动 job：result 节点看自己有没有产物 url（完成 / 等待中）；config 节点看
///   [hasArtifact]（名下已有产物 = 完成），再看正文（[configMainText]）——有 = 就绪、空 = 草稿。
///
/// [hasArtifact] 只有左栏大纲会传 true：节点卡的产物另有成片卡，config 卡的状态行只说草稿 / 就绪。
NodeStatus nodeStatusOf(
  CanvasNode node, {
  required JobState? job,
  bool hasArtifact = false,
}) {
  if (job != null) {
    return switch (job) {
      JobRunning(:final double progress) => (
          kind: NodeStatusKind.running,
          percent: (progress * 100).round(),
        ),
      JobQueued() || JobSubmitting() => (kind: NodeStatusKind.queued, percent: null),
      JobSucceeded() || JobFailed() || JobCancelled() => (
          kind: NodeStatusKind.ready,
          percent: null,
        ),
    };
  }
  if (node.role == NodeRole.result) {
    return (
      kind: (node.imageUrl ?? node.videoUrl) != null
          ? NodeStatusKind.done
          : NodeStatusKind.pending,
      percent: null,
    );
  }
  if (hasArtifact) return (kind: NodeStatusKind.done, percent: null);
  return (
    kind: configMainText(node) == null ? NodeStatusKind.draft : NodeStatusKind.ready,
    percent: null,
  );
}

/// 本卡（result）在同源兄弟里的 take 状态；不是 result / 没有 canvasId / 节点控制器还没人起 ⇒ null。
/// 只订与自己有关的那份记录（select，记录结构相等）。节点控制器不存在时不去起它：单独挂的卡（单测 / golden）
/// 起它会去连库；画布上它一直被画布看着。
ResultTakeStatus? _watchTakeStatus(WidgetRef ref, CanvasNode node) {
  final String? canvasId = node.canvasId;
  if (canvasId == null || node.role != NodeRole.result || node.sourceNodeId == null) return null;
  final provider = canvasNodesControllerProvider(canvasId);
  if (!ref.exists(provider)) return null;
  return ref.watch(
    provider.select(
      (AsyncValue<List<CanvasNode>> v) =>
          resultTakeStatusOf(node, v.valueOrNull ?? const <CanvasNode>[]),
    ),
  );
}

/// 非当前 take 的图区半透明（[dim] 为假原样返回）。
Widget _dimIf(bool dim, Widget child) =>
    dim ? Opacity(key: NodeCard.takeDimKey, opacity: 0.5, child: child) : child;

/// take 卡的状态行文案：「take N / M」，当前加「· 当前」，比固定的当前新加「· 未采用」。
String _takeCaption(AppLocalizations l, ResultTakeStatus take) {
  // 进到这里的都是 total ≥ 2，号一定有；?? 1 只为类型。
  final int n = take.number ?? 1;
  if (take.current) return l.takeCardCaptionCurrent(n, take.total);
  if (take.notAdopted) return l.takeCardCaptionNotAdopted(n, take.total);
  return l.takeCardCaption(n, take.total);
}

/// 状态行：左状态文字（进行中 accent，其余 fg4），右等宽 meta（provider id / camera / txt）。
/// [take] 非空（同源 ≥ 2 个 take）时，完成态的文字换成 take 文案（导入复制中 / 导入完成两支不动）。
class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.node, this.take});
  final CanvasNode node;
  final ResultTakeStatus? take;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final NodeStatus s = nodeStatusOf(
      node,
      job: ref.watch(nodeActiveJobProvider(node.id)),
    );
    // 导入的媒体：复制中「复制中 48%」（accent），复制完「导入」+ 右侧宽高（有才写）。
    // 进度只订自己那一格（select），一张卡的进度跳动不会把整张画布的卡拖进重建。
    final bool imported = node.isImported;
    final double? importProgress = imported ? _watchImportProgress(ref, node) : null;
    final bool importDone = imported && (node.imageUrl ?? node.videoUrl) != null;

    final String status;
    final Color statusColor;
    if (importProgress != null) {
      status = l.nodeStatusImporting((importProgress * 100).round());
      statusColor = colors.accent;
    } else if (importDone) {
      status = l.nodeStatusImported;
      statusColor = colors.fg4;
    } else {
      final ResultTakeStatus? t = take;
      status = switch (s.kind) {
        NodeStatusKind.running => l.inspectorStatusRunningWithProgress(s.percent ?? 0),
        NodeStatusKind.queued => l.canvasRenderQueueStatusQueued,
        NodeStatusKind.done => t == null ? l.nodeStatusDone : _takeCaption(l, t),
        NodeStatusKind.pending => l.nodeStatusPending,
        NodeStatusKind.ready => l.nodeStatusReady,
        NodeStatusKind.draft => l.nodeStatusDraft,
      };
      statusColor = s.kind == NodeStatusKind.running ? colors.accent : colors.fg4;
    }

    final String meta = imported
        ? _importedSizeMeta(node)
        : switch (node.type) {
            CanvasNodeType.text => 'txt',
            CanvasNodeType.shot => 'txt',
            _ => (node.typeConfig['provider_id'] as String?) ?? '',
          };

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.meta.copyWith(color: statusColor),
          ),
        ),
        const SizedBox(width: InkSpacing.sm),
        Text(meta, style: typo.monoSmall.copyWith(color: colors.fg5)),
      ],
    );
  }
}

/// 导入节点此刻的复制进度（0..1）；不在复制中 / 节点没有 canvasId（单测节点）⇒ null。
double? _watchImportProgress(WidgetRef ref, CanvasNode node) {
  final String canvasId = node.canvasId ?? '';
  if (canvasId.isEmpty) return null;
  return ref.watch(
    mediaImportControllerProvider(canvasId).select((Map<String, double> m) => m[node.id]),
  );
}

/// 导入节点状态行右侧的宽高「1920×1080」；没有宽高 ⇒ 空串。视频不写时长（交给统一的时长格式）。
String _importedSizeMeta(CanvasNode node) {
  final Object? w = node.typeConfig['width'];
  final Object? h = node.typeConfig['height'];
  if (w is int && h is int && w > 0 && h > 0) return '$w×$h';
  return '';
}

/// 图区内容。result 节点里的导入节点在复制中时，底部再叠一条进度条——叠在这里而不是
/// [_ResultBody] 里：视频产物走 [VideoNodeBody]（另一个文件），只叠一处两种卡都看得到。
class _NodeBody extends ConsumerWidget {
  const _NodeBody({required this.node, required this.resolver});

  final CanvasNode node;
  final FileResolverService resolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (node.role == NodeRole.result) {
      final double? progress =
          node.isImported ? _watchImportProgress(ref, node) : null;
      if (progress == null) {
        return node.type == CanvasNodeType.video
            ? VideoNodeBody(node: node)
            : _ResultBody(node: node, resolver: resolver);
      }
      // 复制中：壳还没有 url，_ResultBody / VideoNodeBody 会画「等待生成」——导入的媒体不是
      // 生成出来的，且与状态行「复制中 N%」矛盾。图区只留卡片底色，叠进度条。
      return Stack(
        children: <Widget>[
          const Positioned.fill(child: SizedBox.expand()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: InkProgressBar(key: NodeCard.importProgressKey, value: progress),
          ),
        ],
      );
    }
    return _ConfigBody(node: node);
  }
}

/// 图区左下角 11px fg6 说明文字（稿：padding 8 10，行高 1.45）——只剩 result 占位在用
/// （还没出图 / 文件丢了）；config 卡的正文与摘要走 [_ConfigText]。
class _ThumbLabel extends StatelessWidget {
  const _ThumbLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(InkSpacing.s10, InkSpacing.sm, InkSpacing.s10, InkSpacing.sm),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: typo.meta.copyWith(color: colors.fg6),
        ),
      ),
    );
  }
}

/// config 卡图区：常态画正文 + 底部摘要行，缩小态只画居中的类型图标。
///
/// 缩小态读 [canvasCompactCardsProvider]——它只在越过阈值那一下翻转，缩放的每一帧不会
/// 把卡片拖进重建。单测里的节点可以没有 canvasId（见 CanvasNode 头注）：没有画布就谈不上
/// 缩放，按常态画。
class _ConfigBody extends ConsumerWidget {
  const _ConfigBody({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String canvasId = node.canvasId ?? '';
    final bool compact = canvasId.isNotEmpty && ref.watch(canvasCompactCardsProvider(canvasId));
    if (compact) {
      return Center(
        child: InkIcon(
          _configGlyph(node.type),
          key: NodeCard.compactGlyphKey,
          size: InkIconSize.md,
          color: context.inkColors.fg6,
        ),
      );
    }
    if (node.type == CanvasNodeType.video) return _VideoConfigText(node: node);
    final ShotLanguage lang = node.shotLanguage;
    return _ConfigText(
      text: configMainText(node),
      // 底部行：image config = 镜头语言摘要（设了才画）；text / shot 没有底部行。
      summary: node.type == CanvasNodeType.image && !lang.isEmpty
          ? shotLanguageSummary(context, lang)
          : null,
    );
  }
}

/// config 卡的正文：shot = 镜头备注，text = 正文，image / video = 提示词。
/// 去首尾空白；空串归 null（= 不画正文）。
///
/// 公开：状态判据（[nodeStatusOf] 的草稿 / 就绪）与左栏大纲的「按提示词筛选」都读这一份。
String? configMainText(CanvasNode node) {
  final String? raw = switch (node.type) {
    CanvasNodeType.shot => node.typeConfig['shot_notes'] as String?,
    CanvasNodeType.text => node.textContent,
    CanvasNodeType.image || CanvasNodeType.video => node.promptText,
  };
  final String? trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// 缩小态的类型图标：image / video / text 与工具条新建节点同一枚；shot 用「剧本」——
/// 镜头卡的正文就是从剧本拆出来的镜头备注。
InkGlyph _configGlyph(CanvasNodeType type) => switch (type) {
      CanvasNodeType.image => InkGlyph.imageConfig,
      CanvasNodeType.video => InkGlyph.videoConfig,
      CanvasNodeType.text => InkGlyph.text,
      CanvasNodeType.shot => InkGlyph.shot,
    };

/// config 卡图区的文字排布：正文贴顶、最多三行省略，摘要单行贴底；两样都没有时图区留空。
class _ConfigText extends StatelessWidget {
  const _ConfigText({required this.text, required this.summary});

  /// 正文（已去首尾空白）；null = 不画。
  final String? text;

  /// 底部摘要行；null = 不画。
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final String? body = text;
    final String? line = summary;
    if (body == null && line == null) return const SizedBox.shrink();
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s10, horizontal: InkSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 正文占满摘要行以外的高度并贴顶；没有正文时这块空着，摘要照样贴底。
          // 放大界面字号后三行放不下时按这块的高度裁掉，不会把摘要行挤出图区。
          Expanded(
            child: body == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      body,
                      key: NodeCard.configTextKey,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: typo.body.copyWith(color: colors.fg2, height: 1.55),
                    ),
                  ),
          ),
          if (line != null)
            Text(
              line,
              key: NodeCard.configSummaryKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.micro.copyWith(color: colors.fg5),
            ),
        ],
      ),
    );
  }
}

/// video config：正文 = 提示词；底部摘要行 = 起始帧 ← X · 结束帧 ← Y · 运镜（稿）。
/// 以前有入边时摘要会顶掉提示词；现在两样都画，摘要只占底部一行。
class _VideoConfigText extends ConsumerWidget {
  const _VideoConfigText({required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final String canvasId = node.canvasId ?? '';
    final List<CanvasEdge> edges = canvasId.isEmpty
        ? const <CanvasEdge>[]
        : (ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ?? const <CanvasEdge>[]);
    final List<CanvasNode> nodes = canvasId.isEmpty
        ? const <CanvasNode>[]
        : (ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[]);
    final Map<String, CanvasNode> byId = <String, CanvasNode>{for (final n in nodes) n.id: n};

    final List<String> parts = <String>[];
    for (final CanvasEdge e in edges) {
      if (e.targetNodeId != node.id || e.edgeType != EdgeType.data) continue;
      final CanvasNode? src = byId[e.sourceNodeId];
      if (src == null) continue;
      final String roleLabel = switch (e.role) {
        EdgeRole.firstFrame => l.inspectorRoleFirstFrame,
        EdgeRole.lastFrame => l.inspectorRoleLastFrame,
        EdgeRole.reference => l.inspectorRoleReference,
      };
      parts.add('$roleLabel ← ${nodeRefName(context, src)}');
    }
    final CameraMovement? camera = parseCameraMovement(node.cameraName);
    if (camera != null) parts.add(cameraMovementLabel(context, camera));

    return _ConfigText(
      text: configMainText(node),
      summary: parts.isEmpty ? null : parts.join(' · '),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.node, required this.resolver});

  final CanvasNode node;
  final FileResolverService resolver;

  @override
  Widget build(BuildContext context) {
    final url = node.imageUrl;
    if (url == null) {
      return _ThumbLabel(context.l10n.resultNodePending);
    }
    // 单测允许 projectId/canvasId 为空 → 退化为占位（避免 PathSecurityError）。
    if (node.projectId == null || node.canvasId == null) {
      return _ThumbLabel(url);
    }

    File file;
    try {
      file = resolver.resolve(
        projectId: node.projectId!,
        canvasId: node.canvasId!,
        relativePath: url,
      );
    } on PathSecurityError {
      return _ThumbLabel(context.l10n.resultNodeImageMissing);
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // ME-26：按卡片宽度解码，避免原图全尺寸进 image cache。
      cacheWidth: (kNodeCardSize.width * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (_, _, _) => _ThumbLabel(context.l10n.resultNodeImageMissing),
    );
  }
}
