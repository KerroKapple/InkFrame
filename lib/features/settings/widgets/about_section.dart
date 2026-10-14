// AboutSection — 应用信息 + SecureStorage 可用性自检 + 检查更新（UPD-1）。
//
// SecureStorage 写一条 sentinel 再读再删，三步都成功才视作可用——这种探测
// 比"按平台名字硬编码 backend 字符串"更接近事实，避免给用户假阳性。
// 检查更新：手动按钮走 UpdateCheckController.checkNow;结果/失败就地轻呈现,
// 新版给发布页链接（UrlOpenerService）;启动静默检查由偏好开关控制。
// 发布页打不开走失败通知卡（toastServiceProvider，ToastKind.error）。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/package_info.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/di/url_opener.dart';
import '../../../core/di/video_export.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/secure_storage_service.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../core/models/update_check_result.dart';
import '../../../services/ffmpeg_locator.dart' show FfmpegLocator, kFfmpegOnPathExe;
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_card.dart';
import '../../../theme/tokens.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../providers/update_check_controller.dart';

const _kSecureStoragePingKey = 'inkframe.settings.secure_storage_probe';

final secureStorageProbeProvider = FutureProvider.autoDispose<SecureStorageProbe>(
  (ref) async {
    final storage = ref.watch(secureStorageServiceProvider);
    return _probeSecureStorage(storage);
  },
  name: 'secureStorageProbeProvider',
);

/// ON-3：ffmpeg 探测行。null=未找到。
///
/// 【每次进页都强制重探】locator 对**命中**是 app 级缓存的，只有导出失败那条
/// 路径会 `invalidate()`。所以「装好 ffmpeg 后重进设置页即重探」只对 miss 成立；
/// 反过来——用户把 ffmpeg 卸掉之后重进设置页，这一行仍然显示「可用」，直到他
/// 真去导出才发现。设置页的职责就是显示**当下**的事实。
///
/// 代价是每次打开设置页多跑一次 `ffmpeg -version`（几十毫秒），换这一行不骗人。
/// invalidate 动的是共享 locator，但那只会让导出侧下次多探一次，无副作用。
final ffmpegProbeProvider = FutureProvider.autoDispose<String?>(
  (ref) {
    final FfmpegLocator locator = ref.watch(ffmpegLocatorProvider);
    locator.invalidate();
    return locator.locate();
  },
  name: 'ffmpegProbeProvider',
);

@immutable
class SecureStorageProbe {
  const SecureStorageProbe({required this.available, this.errorMessage});
  final bool available;
  final String? errorMessage;
}

Future<SecureStorageProbe> _probeSecureStorage(
  SecureStorageService storage,
) async {
  try {
    await storage.store(_kSecureStoragePingKey, 'ok');
    final read = await storage.retrieve(_kSecureStoragePingKey);
    await storage.delete(_kSecureStoragePingKey);
    if (read != 'ok') {
      return const SecureStorageProbe(
        available: false,
        errorMessage: 'roundtrip mismatch',
      );
    }
    return const SecureStorageProbe(available: true);
  } catch (e) {
    return SecureStorageProbe(available: false, errorMessage: e.toString());
  }
}

/// ffmpeg 命中的呈现：PATH 命中与绝对路径命中是两句话。
///
/// locator 在 PATH 命中时返回的是 [kFfmpegOnPathExe]（交给系统解析的可执行名，
/// **不是路径**）。套进「可用（{path}）」会显示成「可用（ffmpeg）」，读起来像
/// ffmpeg 装在一个叫 ffmpeg 的地方。绝对路径命中（INKFRAME_FFMPEG）才有路径
/// 可显示。
String _ffmpegFoundText(BuildContext context, String located) =>
    located == kFfmpegOnPathExe
        ? context.l10n.settingsAboutFfmpegAvailableOnPath
        : context.l10n.settingsAboutFfmpegAvailable(located);

/// ffmpeg 未找到的平台化指引；mac/win 之外复用导出对话框文案防双源。
String _ffmpegMissingText(BuildContext context) =>
    switch (defaultTargetPlatform) {
      TargetPlatform.windows => context.l10n.settingsAboutFfmpegMissingWindows,
      TargetPlatform.macOS => context.l10n.settingsAboutFfmpegMissingMac,
      _ => context.l10n.exportVideoFfmpegMissing,
    };

String _backendLabel() {
  if (kIsWeb) return 'Web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
      return 'Keychain';
    case TargetPlatform.windows:
      return 'Credential Manager';
    case TargetPlatform.linux:
      return 'libsecret';
    case TargetPlatform.iOS:
      return 'Keychain';
    case TargetPlatform.android:
      return 'Keystore';
    case TargetPlatform.fuchsia:
      return 'Fuchsia';
  }
}

class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final probeAsync = ref.watch(secureStorageProbeProvider);
    final ffmpegAsync = ref.watch(ffmpegProbeProvider);
    final packageAsync = ref.watch(packageInfoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsAboutSection,
          style: typo.sectionTitle.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.sm),
        InkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Row(
                label: context.l10n.settingsAboutAppNameLabel,
                value: context.l10n.appTitle,
              ),
              const SizedBox(height: InkSpacing.xs),
              _Row(
                label: context.l10n.settingsAboutVersionLabel,
                value: packageAsync.when(
                  data: (info) =>
                      info.version.isEmpty ? '—' : '${info.version}+${info.buildNumber}',
                  loading: () => '…',
                  error: (_, _) => '—',
                ),
              ),
              const SizedBox(height: InkSpacing.xs),
              _Row(
                label: context.l10n.settingsAboutSecureStorageLabel,
                // 有意例外（#199 评审 P2-1 拍板）:探测行的 raw 异常文本是
                // 诊断详情（同路径展示类），不走 l10n 映射——用户报障需要原文。
                value: probeAsync.when(
                  data: (probe) => probe.available
                      ? context.l10n
                          .settingsAboutSecureStorageAvailable(_backendLabel())
                      : context.l10n.settingsAboutSecureStorageUnavailable(
                          probe.errorMessage ?? '—',
                        ),
                  loading: () => context.l10n.settingsAboutSecureStorageProbing,
                  error: (e, _) =>
                      context.l10n.settingsAboutSecureStorageUnavailable(
                    e.toString(),
                  ),
                ),
                valueColor: probeAsync.maybeWhen(
                  data: (p) => p.available ? colors.success : colors.danger,
                  orElse: () => colors.fg2,
                ),
              ),
              const SizedBox(height: InkSpacing.xs),
              _Row(
                label: context.l10n.settingsAboutFfmpegLabel,
                value: ffmpegAsync.when(
                  data: (path) => path != null
                      ? _ffmpegFoundText(context, path)
                      : _ffmpegMissingText(context),
                  loading: () => context.l10n.settingsAboutFfmpegProbing,
                  // locator 已吞 ProcessException;兜底按未找到呈现
                  error: (_, _) => _ffmpegMissingText(context),
                ),
                // 缺 ffmpeg 是降级（导出不可用）非故障——warning 而非 danger；
                // error 分支显示 missing 文案,颜色须同步 warning
                valueColor: ffmpegAsync.when(
                  data: (path) =>
                      path != null ? colors.success : colors.accent,
                  loading: () => colors.fg2,
                  error: (_, _) => colors.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: InkSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton(
            label: context.l10n.settingsAboutLicensesButton,
            variant: InkButtonVariant.secondary,
            icon: Icons.description_outlined,
            onPressed: () {
              final String version = packageAsync.maybeWhen(
                data: (info) => info.version.isEmpty
                    ? ''
                    : '${info.version}+${info.buildNumber}',
                orElse: () => '',
              );
              showLicensePage(
                context: context,
                applicationName: context.l10n.appTitle,
                applicationVersion: version,
                applicationLegalese: context.l10n.settingsAboutLegalese,
              );
            },
          ),
        ),
        const SizedBox(height: InkSpacing.md),
        const _UpdateCheckBlock(),
      ],
    );
  }
}

/// 检查更新块：手动按钮 + 状态行 + 启动检查偏好开关。
class _UpdateCheckBlock extends ConsumerWidget {
  const _UpdateCheckBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final updateState = ref.watch(updateCheckControllerProvider);
    final bool autoCheck = ref.watch(updateCheckPrefControllerProvider);
    // AsyncError.value 会 rethrow,必须走 valueOrNull。
    final UpdateCheckResult? result = updateState.valueOrNull;
    final String? releaseUrl =
        (result?.updateAvailable ?? false) ? result?.releaseUrl : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: InkSpacing.sm,
          runSpacing: InkSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            InkButton(
              label: context.l10n.settingsAboutUpdateCheckButton,
              variant: InkButtonVariant.secondary,
              icon: Icons.update_outlined,
              onPressed: updateState.isLoading
                  ? null
                  : () => unawaited(
                        ref
                            .read(updateCheckControllerProvider.notifier)
                            .checkNow(),
                      ),
            ),
            _UpdateStatusText(state: updateState),
            if (releaseUrl != null)
              InkButton(
                label: context.l10n.settingsAboutUpdateViewRelease,
                variant: InkButtonVariant.ghost,
                icon: Icons.open_in_new,
                onPressed: () =>
                    unawaited(_openRelease(context, ref, releaseUrl)),
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Switch(
              value: autoCheck,
              onChanged: ref
                  .read(updateCheckPrefControllerProvider.notifier)
                  .setEnabled,
            ),
            const SizedBox(width: InkSpacing.xs),
            Text(
              context.l10n.settingsAboutUpdateAutoCheckLabel,
              style: typo.body.copyWith(color: colors.fg2),
            ),
          ],
        ),
      ],
    );
  }

  /// 「打不开发布页」卡的去重键：失败卡不自动消失，连点几下只留一张。
  static const String _openReleaseToastKey = 'settings.about.openRelease';

  Future<void> _openRelease(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    // 依赖在 await 之前取好：通知卡不靠 context，await 之后不必再验 mounted。
    final ToastService toast = ref.read(toastServiceProvider);
    final String failedMsg = context.l10n.settingsAboutUpdateOpenFailed;
    try {
      await ref.read(urlOpenerServiceProvider).openExternal(Uri.parse(url));
    } on InkError {
      toast.show(
        failedMsg,
        kind: ToastKind.error,
        dedupeKey: _openReleaseToastKey,
      );
    }
  }
}

/// 检查更新状态行：空闲不占位;checking/最新/新版/失败四态轻呈现。
class _UpdateStatusText extends StatelessWidget {
  const _UpdateStatusText({required this.state});

  final AsyncValue<UpdateCheckResult?> state;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    if (state.isLoading) {
      return Text(
        context.l10n.settingsAboutUpdateChecking,
        style: typo.body.copyWith(color: colors.fg2),
      );
    }
    if (state.hasError) {
      return Text(
        context.l10n.settingsAboutUpdateCheckFailed,
        style: typo.body.copyWith(color: colors.fg3),
      );
    }
    final UpdateCheckResult? result = state.valueOrNull;
    if (result == null) return const SizedBox.shrink();
    if (result.updateAvailable) {
      return Text(
        context.l10n.settingsAboutUpdateAvailable(result.latestVersion!),
        style: typo.body.copyWith(color: colors.success),
      );
    }
    return Text(
      context.l10n.settingsAboutUpdateUpToDate,
      style: typo.body.copyWith(color: colors.fg2),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: typo.meta.copyWith(color: colors.fg3),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: typo.body.copyWith(color: valueColor ?? colors.fg1),
          ),
        ),
      ],
    );
  }
}
