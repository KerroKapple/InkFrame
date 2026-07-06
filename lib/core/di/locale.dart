// LocaleController：用户偏好语言。null 表示跟随系统。
//
// 仅承载 UI 文案语言；不影响 LLM prompt 或日志（按 CLAUDE.md i18n 规则）。
// 后续可加持久化（Postgres user_prefs / SharedPreferences），当前内存态即可。
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'preferences.dart';

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    // 启动 seed：恢复持久化语言（null=跟随系统）。
    final code = ref.read(preferencesServiceProvider).current.localeCode;
    return code == null ? null : Locale(code);
  }

  /// `locale == null` → 跟随系统。否则取传入的 Locale；非支持值忽略。
  void setLocale(Locale? locale) {
    if (locale == null) {
      state = null;
      _persist(null);
      return;
    }
    final supported = AppLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
    if (!supported) return;
    state = locale;
    _persist(locale.languageCode);
  }

  void _persist(String? code) {
    unawaited(
      ref.read(preferencesServiceProvider).update(
            (p) => p.copyWith(localeCode: code, clearLocale: code == null),
          ),
    );
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
  name: 'localeControllerProvider',
);
