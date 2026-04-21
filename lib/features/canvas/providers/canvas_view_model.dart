// CanvasViewModel：画布节点集合 + 选中态 + 增删改。
//
// screen-scoped autoDispose；只管 UI state，不触网络/DB。

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/canvas_node.dart';

final canvasViewModelProvider =
    AutoDisposeNotifierProvider<CanvasViewModel, CanvasState>(
  CanvasViewModel.new,
);

class CanvasState {
  const CanvasState({
    this.nodes = const [],
    this.selectedIds = const {},
  });

  final List<CanvasNode> nodes;
  final Set<String> selectedIds;

  CanvasState copyWith({
    List<CanvasNode>? nodes,
    Set<String>? selectedIds,
  }) =>
      CanvasState(
        nodes: nodes ?? this.nodes,
        selectedIds: selectedIds ?? this.selectedIds,
      );
}

class CanvasViewModel extends AutoDisposeNotifier<CanvasState> {
  static const _uuid = Uuid();

  @override
  CanvasState build() => const CanvasState();

  void addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? projectId,
    String? canvasId,
    String? sourceNodeId,
    Offset position = Offset.zero,
  }) {
    assert(
      role != NodeRole.result || sourceNodeId != null,
      'result 节点必须带 sourceNodeId（§4.5.1）',
    );
    final node = CanvasNode(
      id: _uuid.v4(),
      label: label,
      type: type,
      role: role,
      projectId: projectId,
      canvasId: canvasId,
      sourceNodeId: sourceNodeId,
      position: position,
    );
    state = state.copyWith(nodes: [...state.nodes, node]);
  }

  void removeNode(String id) {
    state = state.copyWith(
      nodes: state.nodes.where((n) => n.id != id).toList(),
      selectedIds: Set.of(state.selectedIds)..remove(id),
    );
  }

  void select(String id, {bool toggle = false}) {
    final selected = Set.of(state.selectedIds);
    if (toggle) {
      selected.contains(id) ? selected.remove(id) : selected.add(id);
    } else {
      selected
        ..clear()
        ..add(id);
    }
    state = state.copyWith(selectedIds: selected);
  }

  void clearSelection() {
    if (state.selectedIds.isEmpty) return;
    state = state.copyWith(selectedIds: const {});
  }

  void moveNode(String id, Offset delta) {
    state = state.copyWith(
      nodes: [
        for (final n in state.nodes)
          if (n.id == id) n.copyWith(position: n.position + delta) else n,
      ],
    );
  }
}
