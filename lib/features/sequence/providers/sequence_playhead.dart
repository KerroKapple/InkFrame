// 序列播放头（P2）：当前镜 + 镜内偏移，纯 UI 态，不落库（拍板：跳转只改 Player 位置，不写库）。
//
// 两种写入者：
//   - 监视器按播放进度 report()：只更新位置，不动 seekToken；
//   - 用户点链表行 / 点或拖轨道 seek()：位置 + seekToken 自增——监视器监听 token 变化去
//     真正换镜 / seek 播放器，自己上报的进度不会回环触发自己。
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sequence_lens.dart';

@immutable
class SequencePlayhead {
  const SequencePlayhead({this.index = 0, this.offsetMs = 0, this.seekToken = 0});
  final int index;
  final int offsetMs;
  final int seekToken;

  SequencePlayhead copyWith({int? index, int? offsetMs, int? seekToken}) => SequencePlayhead(
        index: index ?? this.index,
        offsetMs: offsetMs ?? this.offsetMs,
        seekToken: seekToken ?? this.seekToken,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SequencePlayhead && index == other.index && offsetMs == other.offsetMs && seekToken == other.seekToken;

  @override
  int get hashCode => Object.hash(index, offsetMs, seekToken);
}

final sequencePlayheadProvider =
    AutoDisposeNotifierProviderFamily<SequencePlayheadController, SequencePlayhead, String>(
  SequencePlayheadController.new,
  name: 'sequencePlayheadProvider',
);

class SequencePlayheadController extends AutoDisposeFamilyNotifier<SequencePlayhead, String> {
  @override
  SequencePlayhead build(String canvasId) => const SequencePlayhead();

  /// 监视器上报播放进度。
  void report(int index, int offsetMs) {
    if (state.index == index && state.offsetMs == offsetMs) return;
    state = state.copyWith(index: index, offsetMs: offsetMs);
  }

  /// 用户跳到某一镜的起点（链表行 / 片段点击）。
  void selectShot(int index) => state = SequencePlayhead(index: index, offsetMs: 0, seekToken: state.seekToken + 1);

  /// 用户按全局毫秒跳转（点 / 拖轨道）。
  void seekGlobal(int ms, SequenceLens lens) {
    final ({int index, int offsetMs}) at = lens.locate(ms);
    state = SequencePlayhead(index: at.index, offsetMs: at.offsetMs, seekToken: state.seekToken + 1);
  }
}
