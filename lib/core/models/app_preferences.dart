// AppPreferences：应用级 UI 偏好（主题/对比度/缩放/语言）。
//
// 持久化到 ~/InkFrame/config/preferences.json——属应用配置、非项目数据，刻意不入 PG。
// 用手写不可变类（与 canvas 模型同例外）：避免为一个配置 DTO 引 freezed/json 代码生成。
import 'package:flutter/foundation.dart';

@immutable
class AppPreferences {
  const AppPreferences({
    this.themePreference = 'dark',
    this.highContrast = false,
    this.textScale = 1.0,
    this.localeCode,
  });

  /// 'dark' | 'light' | 'system'
  final String themePreference;
  final bool highContrast;
  final double textScale;

  /// 'en' | 'zh' | null（跟随系统）
  final String? localeCode;

  AppPreferences copyWith({
    String? themePreference,
    bool? highContrast,
    double? textScale,
    String? localeCode,
    bool clearLocale = false,
  }) {
    return AppPreferences(
      themePreference: themePreference ?? this.themePreference,
      highContrast: highContrast ?? this.highContrast,
      textScale: textScale ?? this.textScale,
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'theme_preference': themePreference,
        'high_contrast': highContrast,
        'text_scale': textScale,
        'locale_code': localeCode,
      };

  /// 容错解析：缺失/类型不符/非法值一律退默认，绝不抛——损坏的偏好文件不该炸启动。
  factory AppPreferences.fromMap(Map<String, Object?> m) {
    const allowedTheme = <String>{'dark', 'light', 'system'};
    final pref = m['theme_preference'];
    final hc = m['high_contrast'];
    final ts = m['text_scale'];
    final lc = m['locale_code'];
    return AppPreferences(
      themePreference:
          pref is String && allowedTheme.contains(pref) ? pref : 'dark',
      highContrast: hc is bool ? hc : false,
      textScale: ts is num ? ts.toDouble() : 1.0,
      localeCode: lc is String ? lc : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppPreferences &&
          other.themePreference == themePreference &&
          other.highContrast == highContrast &&
          other.textScale == textScale &&
          other.localeCode == localeCode;

  @override
  int get hashCode =>
      Object.hash(themePreference, highContrast, textScale, localeCode);
}
