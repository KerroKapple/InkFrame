// 挂起的「在画布中定位」请求：先切画布，再由目标画布挂载后落地（单选 + 移到视口中心）。
//
// 为什么不在切画布的同一刻直接写目标画布的选中：那一刻目标画布还没挂载，它的选中 provider
// （canvasSelectionControllerProvider，autoDispose）没有订阅者——写进去的值在帧末就被回收，
// 画布挂上来是空选中。画廊「在画布中定位」、⌘K 产物定位、左栏素材格跨画布定位原先都这样丢选中。
//
// 本 provider 不随画布走（非 autoDispose、不分画布），请求只活到被消费：CanvasView 在节点载入、
// 视口上报尺寸之后落地并消费（canvas_view.dart 的 _PendingFocusApplier）。
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一条定位请求：在 [canvasId] 上单选 [nodeId]；[center] 为真时再把它移到视口中心。
@immutable
class CanvasFocusRequest {
  const CanvasFocusRequest({required this.canvasId, required this.nodeId, this.center = true});

  final String canvasId;
  final String nodeId;

  /// 落地时要不要把节点移到视口中心。「定位」类入口要（节点可能在视口外）；新建菜单建出来的
  /// 节点就落在用户刚点的地方，挪相机只会让人找不着北——那里传 false，只单选。
  final bool center;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasFocusRequest &&
          other.canvasId == canvasId &&
          other.nodeId == nodeId &&
          other.center == center;

  @override
  int get hashCode => Object.hash(canvasId, nodeId, center);

  @override
  String toString() => 'CanvasFocusRequest($canvasId, $nodeId, center: $center)';
}

final canvasFocusRequestProvider =
    NotifierProvider<CanvasFocusRequestController, CanvasFocusRequest?>(
  CanvasFocusRequestController.new,
  name: 'canvasFocusRequestProvider',
);

class CanvasFocusRequestController extends Notifier<CanvasFocusRequest?> {
  @override
  CanvasFocusRequest? build() => null;

  /// 挂起一条请求；已有未消费的请求时以新的为准（用户最后一次点的那个）。
  void request({required String canvasId, required String nodeId, bool center = true}) =>
      state = CanvasFocusRequest(canvasId: canvasId, nodeId: nodeId, center: center);

  /// 消费 [request]：只清它自己——落地在帧后，期间可能已经挂起了新的一条。
  void consume(CanvasFocusRequest request) {
    if (state == request) state = null;
  }
}
