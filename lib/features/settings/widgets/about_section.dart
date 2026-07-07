// AboutSection — 应用信息 + SecureStorage 可用性自检。
//
// SecureStorage 写一条 sentinel 再读再删，三步都成功才视作可用——这种探测
// 比"按平台名字硬编码 backend 字符串"更接近事实，避免给用户假阳性。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/package_info.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/interfaces/secure_storage_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/components/ink_card.dart';
import '../../../theme/tokens.dart';

const _kSecureStoragePingKey = 'inkframe.settings.secure_storage_probe';

final secureStorageProbeProvider = FutureProvider.autoDispose<SecureStorageProbe>(
  (ref) async {
    final storage = ref.watch(secureStorageServiceProvider);
    return _probeSecureStorage(storage);
  },
  name: 'secureStorageProbeProvider',
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
    final packageAsync = ref.watch(packageInfoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsAboutSection,
          style: typo.title.copyWith(color: colors.fg1),
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
      ],
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
            style: typo.caption.copyWith(color: colors.fg3),
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
