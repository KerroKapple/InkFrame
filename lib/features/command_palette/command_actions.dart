// 命令面板的动作组：全部来自应用级动作表（app_actions/app_action_catalog.dart 的 kAppActions），按上下文过滤。
//
// 上下文规则（设置浮层 / 画布 / 有项目的画廊 / 其余）编码在动作表各行的 inPalette 里，顺序 = 表的顺序；
// 这里只做「inPalette 命中、可用且启用」的过滤（⌘K 不画禁用行：PaletteEntry 没有禁用态）。
// label 经 context.l10n 解析后快照进 CommandAction，执行闭包在面板关闭后由调用方以 (context, ref) 触发，
// 那一刻重新取外壳状态（AppActionContext.read）；await 之后一律先查 context.mounted（在各动作的执行体里）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_x.dart';
import '../app_actions/app_action.dart';
import '../app_actions/app_action_catalog.dart';

/// 单个可执行命令：图标 + 已本地化 label + 执行闭包。
@immutable
class CommandAction {
  const CommandAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.run,
  });

  final String id;
  final IconData icon;
  final String label;
  final Future<void> Function(BuildContext context, WidgetRef ref) run;
}

/// 组装当前上下文可用的命令：动作表里 inPalette 命中、此刻可用且启用的行，按表的顺序。
List<CommandAction> buildCommandActions(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final AppActionContext c = AppActionContext.read(context, ref);
  return <CommandAction>[
    for (final AppAction a in kAppActions)
      if (a.inPalette?.call(c) == true && a.isAvailable(c) && a.isEnabled(c))
        CommandAction(
          id: a.id,
          icon: a.icon ?? Icons.bolt_outlined,
          label: a.labelFor(c, l),
          run: (BuildContext ctx, WidgetRef r) async {
            await a.run(AppActionContext.read(ctx, r));
          },
        ),
  ];
}
