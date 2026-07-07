// 导出文件名本地预校验——与 FfmpegVideoExportService._assertPlainFileName
// 同规则（契约：两侧逐字等价，改一侧必改另一侧），UI 侧提前拦截，
// 避免提交后才收 PathSecurityError。
// 保留名按首个点段匹配：`con.backup` 拒绝，`console` 放行。
final RegExp _kWinReservedName = RegExp(
  r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
  caseSensitive: false,
);
final RegExp _kWinIllegalChars = RegExp(r'[*?"<>|]');

/// [name] 是否为合法单层文件名段。
/// 拒绝：空串 / 控制字符 / 路径分隔符 / 盘符冒号 / Windows 非法字符
/// `* ? " < > |` / `..` / Windows 保留设备名（含带扩展名形态）。
/// 「留空=服务端时间戳默认名」由调用方在校验前处理（空串不经本函数放行）。
bool isValidExportBaseName(String name) {
  if (name.isEmpty) return false;
  final hasControlChar = name.codeUnits.any((u) => u < 0x20 || u == 0x7f);
  return !hasControlChar &&
      !name.contains('/') &&
      !name.contains('\\') &&
      !name.contains(':') &&
      !name.contains('..') &&
      !_kWinIllegalChars.hasMatch(name) &&
      !_kWinReservedName.hasMatch(name);
}
