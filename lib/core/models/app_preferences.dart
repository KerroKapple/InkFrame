// AppPreferences：应用级 UI 偏好（主题/对比度/缩放/语言/上次会话）。
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
    this.lastImageProviderId,
    this.lastVideoProviderId,
    this.lastCanvasId,
    this.lastProjectId,
  });

  /// 'dark' | 'light' | 'system'
  final String themePreference;
  final bool highContrast;
  final double textScale;

  /// 'en' | 'zh' | null（跟随系统）
  final String? localeCode;

  /// 上次使用的 provider（image/video 能力集不相交，按节点类型分开记）。
  /// 指向的 provider 可能已被移除（如自定义 provider 删配置），读取方须校验存在性。
  final String? lastImageProviderId;
  final String? lastVideoProviderId;

  /// 上次打开的画布 + 所属项目（恢复时两者都要校验：画布/项目任一软删即失效）。
  final String? lastCanvasId;
  final String? lastProjectId;

  AppPreferences copyWith({
    String? themePreference,
    bool? highContrast,
    double? textScale,
    String? localeCode,
    bool clearLocale = false,
    String? lastImageProviderId,
    String? lastVideoProviderId,
    String? lastCanvasId,
    String? lastProjectId,
    bool clearLastCanvas = false,
  }) {
    return AppPreferences(
      themePreference: themePreference ?? this.themePreference,
      highContrast: highContrast ?? this.highContrast,
      textScale: textScale ?? this.textScale,
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
      lastImageProviderId: lastImageProviderId ?? this.lastImageProviderId,
      lastVideoProviderId: lastVideoProviderId ?? this.lastVideoProviderId,
      lastCanvasId:
          clearLastCanvas ? null : (lastCanvasId ?? this.lastCanvasId),
      lastProjectId:
          clearLastCanvas ? null : (lastProjectId ?? this.lastProjectId),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'theme_preference': themePreference,
        'high_contrast': highContrast,
        'text_scale': textScale,
        'locale_code': localeCode,
        'last_image_provider_id': lastImageProviderId,
        'last_video_provider_id': lastVideoProviderId,
        'last_canvas_id': lastCanvasId,
        'last_project_id': lastProjectId,
      };

  /// 容错解析：缺失/类型不符/非法值一律退默认，绝不抛——损坏的偏好文件不该炸启动。
  factory AppPreferences.fromMap(Map<String, Object?> m) {
    const allowedTheme = <String>{'dark', 'light', 'system'};
    final pref = m['theme_preference'];
    final hc = m['high_contrast'];
    final ts = m['text_scale'];
    final lc = m['locale_code'];
    final lip = m['last_image_provider_id'];
    final lvp = m['last_video_provider_id'];
    final lcv = m['last_canvas_id'];
    final lpj = m['last_project_id'];
    return AppPreferences(
      themePreference:
          pref is String && allowedTheme.contains(pref) ? pref : 'dark',
      highContrast: hc is bool ? hc : false,
      textScale: ts is num ? ts.toDouble() : 1.0,
      localeCode: lc is String ? lc : null,
      lastImageProviderId: lip is String ? lip : null,
      lastVideoProviderId: lvp is String ? lvp : null,
      lastCanvasId: lcv is String ? lcv : null,
      lastProjectId: lpj is String ? lpj : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppPreferences &&
          other.themePreference == themePreference &&
          other.highContrast == highContrast &&
          other.textScale == textScale &&
          other.localeCode == localeCode &&
          other.lastImageProviderId == lastImageProviderId &&
          other.lastVideoProviderId == lastVideoProviderId &&
          other.lastCanvasId == lastCanvasId &&
          other.lastProjectId == lastProjectId;

  @override
  int get hashCode => Object.hash(
        themePreference,
        highContrast,
        textScale,
        localeCode,
        lastImageProviderId,
        lastVideoProviderId,
        lastCanvasId,
        lastProjectId,
      );
}
