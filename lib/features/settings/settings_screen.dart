// SettingsScreen — 设置浮层（Screens 稿第 3 屏）：盖在被遮暗的原界面上的居中对话框。
//
// 结构：40 标题栏（设置 | Esc | ✕）| 左导航 200 + 页面内容 | 44 底部条（说明 | 导出诊断包 | 完成）。
// 展示由 ShellState.overlay == ShellOverlay.settings 驱动（shellControllerProvider）；
// 遮罩 + 点穿拦截在 ShellOverlayLayer，本组件只画对话框本身。
//
// 导航只列有后端的页：常规（主题 / 语言 / 启动开关）、API 密钥（Key 表 + 自定义服务商）、
// 节点布局（画布外观）、存储（目录 + 备份）、关于（版本 / 探测 / 诊断）。
// 稿上的「快捷键 / 性能 / 网络」没有可配置的字段，不画；「语言」并入常规页（用户 2026-09-24）。
//
// Esc 分层：本组件自己持焦（post-frame 夺焦，晚于 ShellContentStack 的兜底夺焦 ⇒ 赢），
// CallbackShortcuts 挂在焦点节点之上。设置内部用 showDialog 弹出的编辑框（自定义服务商）
// 走 Navigator 的另一条路由——它的焦点不在本子树下，Esc 由对话框自己的 DismissIntent
// 处理、根本到不了这里；关掉编辑框后焦点回到本子树，再按一次 Esc 才关浮层。
// 打开 / 关闭浮层都不写路由：不清 canvasId、不切标签（ShellState.openOverlay / closeOverlay）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/ink_button.dart';
import '../../theme/tokens.dart';
import '../shell/providers/shell_controller.dart';
import 'providers/settings_page.dart';
import 'widgets/about_section.dart';
import 'widgets/api_keys_section.dart';
import 'widgets/backup_section.dart';
import 'widgets/canvas_appearance_section.dart';
import 'widgets/custom_providers_section.dart';
import 'widgets/diagnostics_section.dart';
import 'widgets/language_section.dart';
import 'widgets/startup_section.dart';
import 'widgets/storage_path_section.dart';
import 'widgets/theme_section.dart';

export 'providers/settings_page.dart' show SettingsPage;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  /// 稿：对话框 1120×740（content-box），外加 1px 边框。
  static const double dialogWidth = 1120;
  static const double dialogHeight = 740;

  static const Key titleBarKey = Key('settings.titleBar');
  static const Key closeKey = Key('settings.close');
  static const Key doneKey = Key('settings.done');
  static Key navKey(SettingsPage page) => Key('settings.nav.${page.name}');

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'SettingsOverlay');

  @override
  void initState() {
    super.initState();
    // post-frame：与 CanvasShortcuts 同一套路——祖先 ShellContentStack 的兜底夺焦先注册，
    // 本回调后注册，FIFO ⇒ 这里赢。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _close() => ref.read(shellControllerProvider.notifier).closeOverlay();

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final SettingsPage page = ref.watch(settingsPageProvider);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        focusNode: _focusNode,
        skipTraversal: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(InkSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: SettingsScreen.dialogWidth + 2,
                maxHeight: SettingsScreen.dialogHeight + 2,
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.surface3,
                  border: Border.all(color: c.control),
                  borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
                  boxShadow: InkShadow.overlay,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TitleBar(onClose: _close),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _Nav(
                            selected: page,
                            onSelect: (SettingsPage p) => ref.read(settingsPageProvider.notifier).state = p,
                          ),
                          Expanded(child: _PageBody(page: page)),
                        ],
                      ),
                    ),
                    _Footer(onDone: _close),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 稿：40 高 + 1px 下沿，surface2；「设置」500 | 撑开 | Esc 等宽 10 | ✕。
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      key: SettingsScreen.titleBarKey,
      height: 41,
      padding: const EdgeInsets.only(left: InkSpacing.md, right: InkSpacing.sm),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Text(context.l10n.settingsTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
          const Spacer(),
          Text(context.l10n.settingsEscHint, style: t.monoSmall.copyWith(color: c.fg6)),
          const SizedBox(width: InkSpacing.xs),
          IconButton(
            key: SettingsScreen.closeKey,
            tooltip: context.l10n.settingsCloseTooltip,
            icon: Icon(Icons.close, size: InkSpacing.md, color: c.fg5),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// 稿：宽 200 + 右沿 1，surface2，padding 10 0；行 30 高 padding 0 16，选中 surface5 + 2px 琥珀左边框。
class _Nav extends StatelessWidget {
  const _Nav({required this.selected, required this.onSelect});
  final SettingsPage selected;
  final ValueChanged<SettingsPage> onSelect;

  static String _label(BuildContext context, SettingsPage p) => switch (p) {
        SettingsPage.general => context.l10n.settingsNavGeneral,
        SettingsPage.apiKeys => context.l10n.settingsApiKeysSection,
        SettingsPage.nodeLayout => context.l10n.settingsNavNodeLayout,
        SettingsPage.storage => context.l10n.settingsStorageSection,
        SettingsPage.about => context.l10n.settingsAboutSection,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: 201,
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s10),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final SettingsPage p in SettingsPage.values)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: SettingsScreen.navKey(p),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(p),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.only(left: InkSpacing.md),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: p == selected ? c.surface5 : null,
                    border: Border(
                      left: BorderSide(width: 2, color: p == selected ? c.accent : c.surface2),
                    ),
                  ),
                  child: Text(_label(context, p), style: t.body.copyWith(color: p == selected ? c.fg1 : c.fg4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 稿：页头 padding 18 22 14（标题 15/500 + 说明 fg5）+ 下沿 1；正文可滚动。
class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});
  final SettingsPage page;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final (String title, String? note) = switch (page) {
      SettingsPage.general => (l.settingsNavGeneral, null),
      SettingsPage.apiKeys => (l.settingsApiKeysSection, l.settingsApiKeysHint),
      SettingsPage.nodeLayout => (l.settingsNavNodeLayout, null),
      SettingsPage.storage => (l.settingsStorageSection, null),
      SettingsPage.about => (l.settingsAboutSection, null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(InkSpacing.s22, InkSpacing.s18, InkSpacing.s22, InkSpacing.s14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: t.sectionTitle.copyWith(color: c.fg1)),
              if (note != null) ...<Widget>[
                const SizedBox(height: InkSpacing.s6),
                Text(note, style: t.body.copyWith(color: c.fg5, height: 1.5)),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            // 每页一个 PageStorageKey：切页再切回来滚动位置各自保留。
            key: PageStorageKey<SettingsPage>(page),
            padding: const EdgeInsets.all(InkSpacing.s22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: switch (page) {
                SettingsPage.general => const <Widget>[
                    ThemeSection(),
                    SizedBox(height: InkSpacing.xl),
                    LanguageSection(),
                    SizedBox(height: InkSpacing.xl),
                    // 稿上没有这一行：启动开关按稿的分组行样式补在语言下面（用户 2026-09-24）。
                    StartupSection(),
                  ],
                SettingsPage.apiKeys => const <Widget>[
                    ApiKeysSection(),
                    SizedBox(height: InkSpacing.xl),
                    CustomProvidersSection(),
                  ],
                SettingsPage.nodeLayout => const <Widget>[CanvasAppearanceSection()],
                SettingsPage.storage => const <Widget>[
                    StoragePathSection(),
                    SizedBox(height: InkSpacing.xl),
                    BackupSection(),
                  ],
                SettingsPage.about => const <Widget>[
                    AboutSection(),
                    SizedBox(height: InkSpacing.xl),
                    DiagnosticsSection(),
                  ],
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 稿：44 高 + 上沿 1，surface2；11px 说明 | 撑开 | 导出诊断包（次级）| 完成（主）。
class _Footer extends StatelessWidget {
  const _Footer({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          Text(context.l10n.settingsFooterNote, style: t.meta.copyWith(color: c.fg6)),
          const Spacer(),
          const DiagnosticsExportButton(variant: InkButtonVariant.secondary),
          const SizedBox(width: InkSpacing.s10),
          KeyedSubtree(
            key: SettingsScreen.doneKey,
            child: InkButton(label: context.l10n.settingsDone, onPressed: onDone),
          ),
        ],
      ),
    );
  }
}
