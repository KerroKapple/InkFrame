// DefaultCharacterAssetService：CharacterAssetService 的磁盘实现。
//
// 存储布局：`{projects}/{projectId}/characters/{base}.ext`。
// DB 存正斜杠项目相对路径（characters/{base}.ext），解析时按 '/' 切分再拼绝对路径，
// 并做越权（traversal）防护。
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/character_asset_service.dart';
import '../core/paths/app_paths.dart';

class DefaultCharacterAssetService implements CharacterAssetService {
  const DefaultCharacterAssetService(this._paths);

  final AppPaths _paths;

  static const String _subdir = 'characters';
  static final RegExp _controlChar = RegExp(r'[\x00-\x1f\x7f]');

  Directory _projectDir(String projectId) {
    _assertSafeSegment(projectId, 'projectId');
    return Directory(p.join(_paths.projects.path, projectId, _subdir));
  }

  @override
  Future<String> importImage({
    required String projectId,
    required String sourceAbsolutePath,
    required String fileBaseName,
  }) async {
    _assertSafeSegment(fileBaseName, 'fileBaseName');
    final source = File(sourceAbsolutePath);
    if (!await source.exists()) {
      throw CharacterAssetError('source image not found: $sourceAbsolutePath');
    }
    final ext = _sanitizeExt(p.extension(sourceAbsolutePath));
    final dir = _projectDir(projectId);
    await dir.create(recursive: true);
    final fileName = '$fileBaseName$ext';
    await source.copy(p.join(dir.path, fileName));
    // DB 存正斜杠项目相对路径。
    return '$_subdir/$fileName';
  }

  @override
  String absolutePathOf({
    required String projectId,
    required String relativePath,
  }) {
    _assertSafeSegment(projectId, 'projectId');
    if (relativePath.isEmpty || _controlChar.hasMatch(relativePath)) {
      throw const CharacterAssetError('relativePath empty / control chars');
    }
    if (p.isAbsolute(relativePath) || relativePath.contains('..')) {
      throw CharacterAssetError('relativePath not safe: $relativePath');
    }
    final segments = relativePath.split('/').where((s) => s.isNotEmpty);
    return p.normalize(
      p.joinAll(<String>[_paths.projects.path, projectId, ...segments]),
    );
  }

  @override
  Future<List<String>> resolveExisting({
    required String projectId,
    required List<String> relativePaths,
  }) async {
    final out = <String>[];
    for (final rel in relativePaths) {
      final String abs;
      try {
        abs = absolutePathOf(projectId: projectId, relativePath: rel);
      } on CharacterAssetError {
        continue;
      }
      if (await File(abs).exists()) out.add(abs);
    }
    return out;
  }

  @override
  Future<void> delete({
    required String projectId,
    required String relativePath,
  }) async {
    final String abs;
    try {
      abs = absolutePathOf(projectId: projectId, relativePath: relativePath);
    } on CharacterAssetError {
      return;
    }
    final f = File(abs);
    if (await f.exists()) {
      try {
        await f.delete();
      } on FileSystemException {
        // 清理尽力而为——Windows 句柄释放滞后等不阻断。
      }
    }
  }

  String _sanitizeExt(String ext) {
    // 只留字母数字扩展（含点）；异常一律回退 .png。
    if (ext.isEmpty) return '.png';
    final lower = ext.toLowerCase();
    if (RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(lower)) return lower;
    return '.png';
  }

  void _assertSafeSegment(String value, String label) {
    if (value.isEmpty) {
      throw CharacterAssetError('$label must not be empty');
    }
    if (_controlChar.hasMatch(value) ||
        value.contains('/') ||
        value.contains(r'\') ||
        value.contains('..')) {
      throw CharacterAssetError('$label must be a plain segment: $value');
    }
  }
}
