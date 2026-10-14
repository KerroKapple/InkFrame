// InkNameDialog：「给它起个名字」对话框的**唯一**一份。
//
// 由来（CH-2 残留④，BOARD 199）：同一个框此前在仓库里有两份近似件——
// `characters_section.dart` 的 `InspectorNameDialog`（新建角色 / 改名 / 存预设共用，
// 文案参数化）与 `gallery_actions.dart` 的 `GalleryCharacterNameDialog`
// （画廊「存为角色」，文案写死）。两份逐行比过，差别只有三处，而且**三处都是画廊那份
// 更对**：底色走 token、确认键用 FilledButton、空名字时确认键真禁用。
// 标题 / 提示 / 两个按钮文案本来就一致（画廊那份读的就是 inspector 的 ARB 键），
// 默认值（空）与取消语义（返回 null）两份完全相同——所以这是能合的，不是硬合。
//
// 空名字禁用是**收紧**而不是改语义：五个调用点此前统统是
// `if (name == null || name.trim().isEmpty) return;`——点下去也等于取消。禁用只是
// 把那条死路从界面上拿掉（与 test/quality/no_dead_interactive_test.dart 同一个主张：
// 不可用就别装得可用），没有任何调用点的行为因此改变。
//
// 【它不认识任何 feature】文案全部由调用方给，theme 层不碰 ARB
//（分层闸：test/quality/no_reverse_layer_import_test.dart）。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'ink_input.dart';

class InkNameDialog extends StatefulWidget {
  const InkNameDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<InkNameDialog> createState() => _InkNameDialogState();
}

class _InkNameDialogState extends State<InkNameDialog> {
  /// controller 的生命周期归 dialog 自身——退场动画期间 TextField 仍引用它，
  /// 调用方在 showDialog 返回后立即 dispose 会炸。
  final TextEditingController _ctrl = TextEditingController();

  /// 一打开焦点就在输入框里（autofocus）：框是从画布菜单之类的地方开的，按键不能穿到框后面去。
  /// InkInput 不收 autofocus 参数，就照 Focus(autofocus: true) 的做法排一次 FocusScope.autofocus——
  /// 作用域里还没有别的焦点才生效，不从已经持焦的控件手里抢。
  final FocusNode _focus = FocusNode(debugLabel: 'InkNameDialog');
  bool _didAutofocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didAutofocus) return;
    _didAutofocus = true;
    FocusScope.of(context, createDependency: false).autofocus(_focus);
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm = _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      backgroundColor: context.inkColors.surface1,
      title: Text(widget.title),
      content: InkInput(
        controller: _ctrl,
        focusNode: _focus,
        hintText: widget.hint,
        // 每次输入重建一次，确认键的可用态才跟得上（禁用态的唯一依据）。
        onChanged: (_) => setState(() {}),
      ),
      actions: <Widget>[
        TextButton(
          // 取消 = 返回 null，与"空名字"区分得开（调用方据此分流）。
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          // 不可用就给 null，不给空闭包。返回原始输入，trim 归调用方
          //（它们本来就要 trim 一次再落库）。
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_ctrl.text)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
