// CharacterAssetService 契约：项目级角色参考图的落盘 / 解析。
//
// 角色是项目级（跨画布复用），故参考图存在项目根下的 `characters/` 子目录，
// 而非画布作用域的 FileResolverService。DB 只存项目相对路径（characters/{base}.ext，
// 正斜杠），由本服务解析为绝对路径供生成注入。
abstract class CharacterAssetService {
  /// 把绝对源图复制进 `{projects}/{projectId}/characters/`，命名为 {fileBaseName}{源扩展}，
  /// 返回项目相对路径（characters/{fileBaseName}{ext}，正斜杠）。源缺失/越权 → 抛错。
  Future<String> importImage({
    required String projectId,
    required String sourceAbsolutePath,
    required String fileBaseName,
  });

  /// 项目相对路径 → 绝对路径（纯拼接，不校验存在）。越权路径抛 [CharacterAssetError]。
  String absolutePathOf({
    required String projectId,
    required String relativePath,
  });

  /// 批量解析为「确实存在的」绝对路径；缺文件 / 解析失败静默跳过。生成注入用。
  Future<List<String>> resolveExisting({
    required String projectId,
    required List<String> relativePaths,
  });

  /// 删除相对路径对应文件（缺文件静默）。角色删除时清理磁盘。
  Future<void> delete({
    required String projectId,
    required String relativePath,
  });
}

/// 角色资产路径越权 / 非法。
class CharacterAssetError implements Exception {
  const CharacterAssetError(this.message);
  final String message;
  @override
  String toString() => 'CharacterAssetError: $message';
}
