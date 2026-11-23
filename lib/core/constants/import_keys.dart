// 导入媒体节点的 type_config JSONB 键（只是键名常量，无副作用）。
//
// 放在 core 而不放 features/canvas：storage（listOrphanResults 的 SQL 排除）、services
// （媒体导入服务）与 features（卡片显示、导入控制器）三层都要用，storage / services
// 不能反向 import features。做法同 take_keys.dart。
abstract final class ImportKeys {
  /// 节点从哪来：取值 [originImport] = 用户导入的媒体（无来源配置节点，不是孤儿结果）。
  static const String origin = 'origin';

  /// 导入时的原文件名（含扩展名）；只用于显示，磁盘上的文件名一律是 `<uuid>.<ext>`。
  static const String originalName = 'original_name';

  /// [origin] 的取值：导入。
  static const String originImport = 'import';

  /// 从参考库导入时：参考库条目 id（ReferenceItem.id）。普通导入不写。
  /// 「当参考」靠它认出「已经是这张」。
  static const String referenceItemId = 'reference_item_id';

  /// 从参考库导入时：类别（ReferenceCategory.name：pose / portrait / costume）。普通导入不写。
  /// 「当参考」靠它找同类别的旧参考边来替换。
  static const String referenceCategory = 'reference_category';
}
