// LockScreen：应用首屏锁屏，要求用户粘贴至少一把 provider API key 才能进入。
//
// 视觉对齐 docs/superpowers/specs/2026-05-13-ui-redesign/mockups/01-lock.html：
//   - 暗底 surfaceCanvas
//   - 中央 LockLogo + 全大写 mono tagline
//   - 下划线密码输入 + 双行说明 + 实色琥珀 Unlock 按钮
//   - 右上 "中 / EN" InkGhostButton（locale toggle）
//   - 左下版本号 mono
//   - 装饰大 "I" 衬线超大字号溢出左下角
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/package_info.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/ink_window_chrome.dart';
import '../../theme/primitives/ink_amber_button.dart';
import '../../theme/primitives/ink_ghost_button.dart';
import '../../theme/tokens.dart';
import 'controllers/lock_controller.dart';
import 'widgets/lock_logo.dart';
import 'widgets/lock_secure_field.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onUnlock() {
    ref.read(lockControllerProvider.notifier).submit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final state = ref.watch(lockControllerProvider);

    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      body: Column(
        children: <Widget>[
          // Frameless 模式下，每屏必须自带 chrome，否则用户找不到关闭/最小化。
          InkWindowChrome(
            trailing: InkGhostButton(
              label: '中 / EN',
              compact: true,
              onPressed: () {},
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                // 装饰大 "I" 溢出左下角。
                Positioned(
                  left: -80,
                  bottom: -260,
                  child: IgnorePointer(
                    child: Text(
                      'I',
                      style: typo.display.copyWith(
                        fontSize: 720,
                        height: 0.8,
                        color: colors.fg4.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),

                // 左下版本号（PackageInfo 实时读取，loading/error 时显示空字符串）。
          Positioned(
            left: InkSpacing.lg,
            bottom: InkSpacing.md,
            child: Text(
              ref.watch(packageInfoProvider).when(
                    data: (info) => 'v${info.version} -- ${info.buildNumber}',
                    loading: () => '',
                    error: (_, _) => '',
                  ),
              style: typo.caption.copyWith(
                color: colors.fg3,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // 中央 logo + 表单。
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: LockLogo()),
                  const SizedBox(height: InkSpacing.md),
                  Center(
                    child: Text(
                      context.l10n.lockTagline,
                      style: typo.caption.copyWith(
                        color: colors.fg3,
                        letterSpacing: 4.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: InkSpacing.xxl + InkSpacing.md),
                  LockSecureField(
                    controller: _controller,
                    hintText: context.l10n.lockKeyPlaceholder,
                    autofocus: true,
                    onSubmitted: (_) => _onUnlock(),
                  ),
                  const SizedBox(height: InkSpacing.md),
                  Text(
                    context.l10n.lockKeyHelpLine1,
                    style: typo.caption.copyWith(
                      color: colors.fg3,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: InkSpacing.xs),
                  Text(
                    context.l10n.lockKeyHelpLine2,
                    style: typo.caption.copyWith(
                      color: colors.fg3,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (state.hasError) ...<Widget>[
                    const SizedBox(height: InkSpacing.sm),
                    Text(
                      context.l10n.lockKeyInvalid,
                      style: typo.caption.copyWith(color: colors.danger),
                    ),
                  ],
                  const SizedBox(height: InkSpacing.md),
                  InkAmberButton(
                    label: context.l10n.lockUnlock,
                    expand: true,
                    onPressed: state.isLoading ? null : _onUnlock,
                  ),
                ],
              ),
            ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}
