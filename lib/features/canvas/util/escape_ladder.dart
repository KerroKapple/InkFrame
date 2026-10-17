// Esc 阶梯（KeyMap.dc.html ›「Esc 阶梯」）：按一张固定层序表，一次只剥一层。
//
// 层序就是 [EscapeRungId] 的声明序——靠前的先剥。谁先登记、Map 里谁排在前面都不影响判序：
// [resolveEscape] 只按 EscapeRungId.values 的顺序走。后续切片（@ 补全弹层、查找条、框选、工具锁）
// 只往表里登记自己那一层（providers/canvas_escape_ladder.dart 的 register / unregister），不改判序代码。
//
// 不在阶梯上：对话框 · ⌘K · 设置 · 任务弹层 · 铃铛——它们开着时自己持焦，Esc 先到它们那儿。
//
// 设计缺口的拍板：KeyMap 第 6 档没排「工具锁 / 平移 / 连线」同时生效时的先后，这里定为
// 连线 > 工具锁 > 平移。
//
// 纯 Dart：不认识 Flutter，也不认识 Riverpod。

/// Esc 阶梯的层（声明序 = 优先级，靠前的先剥）。
enum EscapeRungId {
  /// 菜单（子菜单先关）。菜单自己持焦时由菜单处理；这一层兜的是菜单开着、焦点却在画布上的情形。
  menu,

  /// @ 补全弹层（空位，由后续切片登记）。
  mentionPopup,

  /// 查找条（空位，由后续切片登记）。
  findBar,

  /// 文字输入框失焦、焦点回画布（选中不动）。
  textField,

  /// 进行中的拖线：取消，松手不连线、不开菜单。
  wireDrag,

  /// 进行中的框选（空位，由后续切片登记）：恢复按下前的选中。
  marquee,

  /// 连线模式：退出连线，不动选中。
  linkMode,

  /// 工具锁（空位，由后续切片登记）。
  toolLock,

  /// 平移工具：回到选择，不动选中。
  panTool,

  /// 清空选中（节点和连线）。
  selection,
}

/// 一层：此刻有没有东西可剥（[isActive]）+ 剥掉它（[dismiss]）。
typedef EscapeRung = ({bool Function() isActive, void Function() dismiss});

/// 按层序取第一个此刻生效的层；一层都不生效 ⇒ null（Esc 无事可剥）。
EscapeRungId? resolveEscape(Map<EscapeRungId, EscapeRung> rungs) {
  for (final EscapeRungId id in EscapeRungId.values) {
    final EscapeRung? rung = rungs[id];
    if (rung != null && rung.isActive()) return id;
  }
  return null;
}
