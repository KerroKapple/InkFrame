// LaneCollapseController — 泳道折叠状态，纯 UI，不持久化。

import 'package:flutter_riverpod/flutter_riverpod.dart';

final laneCollapseProvider = AutoDisposeNotifierProviderFamily<
    LaneCollapseController, Set<String>, String>(
  LaneCollapseController.new,
  name: 'laneCollapseProvider',
);

class LaneCollapseController
    extends AutoDisposeFamilyNotifier<Set<String>, String> {
  @override
  Set<String> build(String arg) => const <String>{};

  void toggle(String laneId) {
    final next = {...state};
    if (!next.remove(laneId)) next.add(laneId);
    state = next;
  }

  bool isCollapsed(String laneId) => state.contains(laneId);
}
