// 应用级动作的类型：一行动作 = id + 文案 + 每平台一个主键 + 可用 / 启用判据 + 禁用原因 + 执行。
//
// 菜单栏、右键菜单、⌘K、快捷键页共用一张动作表（app_action_catalog.dart 的 kAppActions），改一处处处变。
// 不可用的灰着不藏：[AppAction.isAvailable] 为假才不画；[AppAction.isEnabled] 为假画灰行，悬停出
// [AppAction.disabledReason]。⌘K 只列 inPalette 命中、可用且启用的行（PaletteEntry 没有禁用态）。
//
// 判据都在执行那一刻用 ref.read 现算（菜单打开时 / ⌘K 打开时），不订阅——调用方要跟着变就自己 watch 源头。
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../settings/util/shortcut_catalog.dart';
import '../shell/models/shell_state.dart';
import '../shell/providers/shell_controller.dart';

/// 动作归哪个菜单：与外壳顶部菜单栏六个菜单（shell_chrome.dart）一一对应。
enum AppActionGroup { file, edit, canvas, node, window, help }

/// 判据与执行的上下文：调用方的 context / ref + 此刻的外壳状态。
@immutable
class AppActionContext {
  const AppActionContext({
    required this.context,
    required this.ref,
    required this.shell,
  });

  /// 现取外壳状态（shellControllerProvider）。菜单 / ⌘K 执行一律走这里：`a.run(AppActionContext.read(context, ref))`。
  factory AppActionContext.read(BuildContext context, WidgetRef ref) =>
      AppActionContext(
        context: context,
        ref: ref,
        shell: ref.read(shellControllerProvider),
      );

  final BuildContext context;
  final WidgetRef ref;
  final ShellState shell;

  /// 此刻看得见的画布：画布标签在前台、没有浮层盖着时才是外壳的 canvasId，否则 null。
  /// 等价于 shell.isTabVisible(ShellTab.canvas)——标签保活时切走的画布还在，但动作不能对着看不见的画布动刀。
  String? get canvasId =>
      shell.overlay == null && shell.tab == ShellTab.canvas ? shell.canvasId : null;
}

/// 动作表里的一行。
@immutable
class AppAction {
  const AppAction({
    required this.id,
    required this.group,
    required this.label,
    this.macKey,
    this.otherKey,
    this.icon,
    required this.isAvailable,
    required this.isEnabled,
    required this.disabledReason,
    required this.run,
    this.contextualLabel,
    this.inPalette,
  });

  /// 见 AppActionIds。
  final String id;
  final AppActionGroup group;

  /// 静态文案；要上下文的走 [contextualLabel]。调用方一律用 [labelFor]。
  final String Function(AppLocalizations l) label;

  /// 每平台一个主键（null = 没有键）。取用一律走 [keyFor] / [keyLabel]。
  final ShortcutActivator? macKey;
  final ShortcutActivator? otherKey;

  /// ⌘K 行首图标（null ⇒ 调用方给默认图标）。
  final IconData? icon;

  /// 假 ⇒ 菜单里不画这一行。
  final bool Function(AppActionContext c) isAvailable;

  /// 假 ⇒ 灰着，悬停出 [disabledReason]。
  final bool Function(AppActionContext c) isEnabled;

  /// [isEnabled] 为假时的原因；为真时返回 null。
  final String? Function(AppActionContext c, AppLocalizations l) disabledReason;

  /// 执行。跨 await 之后先查 `c.context.mounted`。
  final FutureOr<void> Function(AppActionContext c) run;

  /// 要上下文的文案（如「有新版本 x.y.z · 下载」）；null ⇒ 用 [label]。
  final String Function(AppActionContext c, AppLocalizations l)? contextualLabel;

  /// 进不进 ⌘K 的上下文判据；null = 不进 ⌘K。进 ⌘K 还要 [isAvailable] 与 [isEnabled] 都为真。
  final bool Function(AppActionContext c)? inPalette;

  /// 此刻该显示的文案。
  String labelFor(AppActionContext c, AppLocalizations l) =>
      contextualLabel?.call(c, l) ?? label(l);

  /// 本平台的主键。
  ShortcutActivator? keyFor({required bool isMac}) => isMac ? macKey : otherKey;

  /// 本平台主键的展示串（与设置「快捷键」页同一个格式器）；没有键 / 出不了字 ⇒ null。
  String? keyLabel({required bool isMac}) {
    final ShortcutActivator? key = keyFor(isMac: isMac);
    return key == null ? null : formatShortcutActivator(key, isMac: isMac);
  }
}
