// NotificationsSection — 设置 › 常规 › 通知：提示音（四选一 + 试听 + 自定义文件）与通知卡停留时长。
//
// 样式照 StartupSection 的分组框（surface2 底 + control 边 + 圆角 4，标签 fg4、说明 11px fg6）；
// 选项按钮照 ThemeSection 的 _ChoiceButton（选中 primary、其余 secondary）。
//
// 「试听」在「关闭」时禁用；选了「自定义」但还没选文件时也禁用——那时按下去什么都不会响，
// 按钮亮着就是假交互。
// 导入失败走通知卡（ToastKind.error）：太大单独说一句，其余一律「这个文件用不了」，原因进日志。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/notification_sound_store.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/notification_sound_service.dart';
import '../../../core/interfaces/notification_sound_store.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/tokens.dart';
import '../../notifications/models/notification_prefs.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../providers/notification_prefs_controller.dart';

class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  static Key soundKey(NotificationSound sound) =>
      Key('settings.notifications.sound.${sound.name}');
  static Key dwellKey(ToastDwell dwell) =>
      Key('settings.notifications.dwell.${dwell.name}');
  static const Key previewKey = Key('settings.notifications.preview');
  static const Key chooseFileKey = Key('settings.notifications.chooseFile');

  /// 导入失败的通知卡共用一个去重键：连着失败几次只替换原卡，不叠一摞。
  static const String _importToastKey = 'settings.notificationSound.import';

  static String _soundLabel(AppLocalizations l, NotificationSound sound) =>
      switch (sound) {
        NotificationSound.inkframe => l.settingsNotificationSoundInkframe,
        NotificationSound.system => l.settingsNotificationSoundSystem,
        NotificationSound.custom => l.settingsNotificationSoundCustom,
        NotificationSound.off => l.settingsNotificationSoundOff,
      };

  static String? _soundHint(AppLocalizations l, NotificationSound sound) =>
      switch (sound) {
        NotificationSound.inkframe => l.settingsNotificationSoundInkframeHint,
        NotificationSound.system => l.settingsNotificationSoundSystemHint,
        NotificationSound.custom => l.settingsNotificationSoundCustomHint,
        NotificationSound.off => null,
      };

  static String _dwellLabel(AppLocalizations l, ToastDwell dwell) =>
      switch (dwell) {
        ToastDwell.standard => l.settingsNotificationDwellStandard,
        ToastDwell.long => l.settingsNotificationDwellLong,
        ToastDwell.never => l.settingsNotificationDwellNever,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final NotificationPrefs prefs = ref.watch(notificationPrefsControllerProvider);
    final NotificationPrefsController controller =
        ref.read(notificationPrefsControllerProvider.notifier);

    final bool canPreview = switch (prefs.sound) {
      NotificationSound.off => false,
      NotificationSound.custom => prefs.soundFile != null,
      NotificationSound.inkframe || NotificationSound.system => true,
    };
    final String? hint = _soundHint(l, prefs.sound);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l.settingsNotificationsSection,
          style: t.sectionTitle.copyWith(color: c.fg1),
        ),
        const SizedBox(height: InkSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md, vertical: InkSpacing.s14),
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border.all(color: c.control),
            borderRadius: BorderRadius.circular(InkRadius.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.settingsNotificationSound, style: t.body.copyWith(color: c.fg4)),
              const SizedBox(height: InkSpacing.xs),
              // 选项左起换行排开，「试听」钉在右边——它不是第五个选项，别和选项混在一排里。
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: InkSpacing.sm,
                      runSpacing: InkSpacing.xs,
                      children: <Widget>[
                        for (final NotificationSound s in NotificationSound.values)
                          _ChoiceButton(
                            key: soundKey(s),
                            label: _soundLabel(l, s),
                            selected: prefs.sound == s,
                            onPressed: () => controller.setSound(s),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: InkSpacing.s12),
                  InkButton(
                    key: previewKey,
                    label: l.settingsNotificationSoundPreview,
                    variant: InkButtonVariant.ghost,
                    onPressed: canPreview
                        ? () => unawaited(controller.preview())
                        : null,
                  ),
                ],
              ),
              if (hint != null) ...<Widget>[
                const SizedBox(height: InkSpacing.s6),
                Text(hint, style: t.meta.copyWith(color: c.fg6, height: 1.5)),
              ],
              if (prefs.sound == NotificationSound.custom) ...<Widget>[
                const SizedBox(height: InkSpacing.s10),
                _CustomFileRow(
                  fileName: prefs.soundFile,
                  onChoose: () => unawaited(_chooseFile(context, ref)),
                ),
              ],
              const SizedBox(height: InkSpacing.md),
              Text(l.settingsNotificationDwell, style: t.body.copyWith(color: c.fg4)),
              const SizedBox(height: InkSpacing.xs),
              Wrap(
                spacing: InkSpacing.sm,
                runSpacing: InkSpacing.xs,
                children: <Widget>[
                  for (final ToastDwell d in ToastDwell.values)
                    _ChoiceButton(
                      key: dwellKey(d),
                      label: _dwellLabel(l, d),
                      selected: prefs.dwell == d,
                      onPressed: () => controller.setDwell(d),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 选文件 → 导入数据目录 → 切到「自定义」。
  ///
  /// 依赖全在第一个 await 之前取好：选文件框开着的时候设置浮层可能已经关了，
  /// 之后再碰 ref / context 就是在用已经销毁的东西。
  Future<void> _chooseFile(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l = context.l10n;
    final NotificationSoundFilePicker pick =
        ref.read(notificationSoundFilePickerProvider);
    final NotificationPrefsController controller =
        ref.read(notificationPrefsControllerProvider.notifier);
    final ToastService toast = ref.read(toastServiceProvider);

    void fail(String title) {
      toast.show(title, kind: ToastKind.error, dedupeKey: _importToastKey);
    }

    final String? path;
    try {
      path = await pick(
        l.settingsNotificationSoundFileType,
        kCustomNotificationSoundExtensions,
      );
    } on PlatformException {
      // 系统选文件框自己出错（极少见）：当作这次没选成。
      fail(l.settingsNotificationSoundImportFailed);
      return;
    }
    if (path == null) return;

    try {
      await controller.importCustomSound(path);
    } on LocalIOError catch (e) {
      fail(
        e.extra['reason'] == kNotificationSoundTooLargeReason
            ? l.settingsNotificationSoundTooLarge
            : l.settingsNotificationSoundImportFailed,
      );
    }
  }
}

/// 「自定义」下面那一行：当前文件名（还没选就说还没选）+ 选择 / 更换。
class _CustomFileRow extends StatelessWidget {
  const _CustomFileRow({required this.fileName, required this.onChoose});

  final String? fileName;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final String? name = fileName;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            name ?? l.settingsNotificationSoundNoFile,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: name == null
                ? t.body.copyWith(color: c.fg6)
                : t.mono.copyWith(color: c.fg3),
          ),
        ),
        const SizedBox(width: InkSpacing.s12),
        InkButton(
          key: NotificationsSection.chooseFileKey,
          label: name == null
              ? l.settingsNotificationSoundChooseFile
              : l.settingsNotificationSoundReplaceFile,
          variant: InkButtonVariant.secondary,
          onPressed: onChoose,
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkButton(
      label: label,
      onPressed: onPressed,
      variant:
          selected ? InkButtonVariant.primary : InkButtonVariant.secondary,
    );
  }
}
