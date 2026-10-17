// CanvasSelectionController — 画布选中态，纯 UI state。
//
// 与节点集合分离：节点加载/刷新是异步 (AsyncValue)，而选中态只随用户交互变化，
// 独立存活在一个 autoDispose Notifier 中，避免 AsyncValue reload 时丢选择。

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final canvasSelectionControllerProvider =
    AutoDisposeNotifierProviderFamily<CanvasSelectionController, Set<String>, String>(
      CanvasSelectionController.new,
      name: 'canvasSelectionControllerProvider',
    );

class CanvasSelectionController
    extends AutoDisposeFamilyNotifier<Set<String>, String> {
  @override
  Set<String> build(String canvasId) => const <String>{};

  void select(String id, {bool toggle = false}) {
    final next = Set<String>.of(state);
    if (toggle) {
      next.contains(id) ? next.remove(id) : next.add(id);
    } else {
      next
        ..clear()
        ..add(id);
    }
    state = next;
  }

  /// 全选：把选择整体替换为 [ids]（⌘A / Ctrl+A）。集合等价则跳过，避免空重建。
  void selectAll(Iterable<String> ids) => replace(ids);

  void clear() {
    if (state.isEmpty) return;
    state = const <String>{};
  }

  void removed(String id) {
    if (!state.contains(id)) return;
    final next = Set<String>.of(state)..remove(id);
    state = next;
  }

  // 以下批量方法给框选 / 浮动条 / 对齐 / 粘贴等共用：结果与当前集合相等时一律不赋值（不触发重建），
  // 与 selectAll / clear 的约定一致。选中是纯 UI 态，不进撤销栈。

  /// 整体替换为 [ids]；集合相等不改 state 引用。[ids] 为空 = 清空。
  void replace(Iterable<String> ids) {
    final next = ids.toSet();
    if (setEquals(next, state)) return;
    state = next;
  }

  /// 并入 [ids]；没有新增就不改 state 引用。
  void addAll(Iterable<String> ids) {
    final next = Set<String>.of(state)..addAll(ids);
    if (next.length == state.length) return;
    state = next;
  }

  /// 对 [ids] 逐个取反（在的去掉、不在的加上）；[ids] 为空不改 state 引用。
  /// [ids] 里的重复 id 只取反一次（按集合算，与框选的对称差口径一致）。
  void toggleAll(Iterable<String> ids) {
    final flip = ids.toSet();
    if (flip.isEmpty) return;
    state = state.difference(flip)..addAll(flip.difference(state));
  }

  /// 去掉 [ids]；一个都不在选中里就不改 state 引用。
  void removeAll(Iterable<String> ids) {
    final next = Set<String>.of(state)..removeAll(ids);
    if (next.length == state.length) return;
    state = next;
  }
}
