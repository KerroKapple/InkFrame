// FileResolverService：唯一拥有绝对路径的服务（PRD §12.6 相对路径契约）。
//
// 约束：
//   - DB 只存 canvas 相对路径（形如 images/{uuid}.png）
//   - Widget / ViewModel 禁止直接 new File(...)；必须经本服务
//   - 所有绝对路径回写必须校验在 canvas 根目录之内，拒绝 '..' 穿越、绝对路径、空串、控制字符
//   - 同盘 rename / 跨盘 copy+verify+rm 由 toRelative 的调用方在迁移流程里处理，本服务不涉
//
// 根目录布局（与 AppPaths.projects 一致）：
//   ~/InkFrame/projects/{project-id}/canvases/{canvas-id}/
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/paths/app_paths.dart';

abstract class FileResolverService {
  /// 相对路径 → 绝对 File。相对路径非法时抛 [PathSecurityError]。
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  });

  /// 绝对路径 → 相对路径；源路径不在指定 canvas 根目录内时抛 [PathSecurityError]。
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  });

  /// 返回 canvas 根目录绝对路径（不保证存在）。
  Directory canvasRoot({required String projectId, required String canvasId});
}

/// 非法路径（穿越 / 绝对 / 空 / 控制字符等）。
class PathSecurityError extends ArgumentError {
  PathSecurityError(super.message);
}

class DefaultFileResolverService implements FileResolverService {
  const DefaultFileResolverService(this._paths);

  final AppPaths _paths;

  static final RegExp _controlChar = RegExp(r'[\x00-\x1f\x7f]');

  @override
  Directory canvasRoot({
    required String projectId,
    required String canvasId,
  }) {
    _assertSafeSegment(projectId, label: 'projectId');
    _assertSafeSegment(canvasId, label: 'canvasId');
    return Directory(
      p.join(_paths.projects.path, projectId, 'canvases', canvasId),
    );
  }

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) {
    if (relativePath.isEmpty) {
      throw PathSecurityError('relativePath must not be empty');
    }
    if (_controlChar.hasMatch(relativePath)) {
      throw PathSecurityError('relativePath contains control characters');
    }
    if (p.isAbsolute(relativePath)) {
      throw PathSecurityError('relativePath must be relative');
    }
    if (RegExp(r'^[a-zA-Z]:').hasMatch(relativePath) && Platform.isWindows) {
      throw PathSecurityError('relativePath must not include drive letter');
    }

    final root = canvasRoot(projectId: projectId, canvasId: canvasId);
    final joined = p.normalize(p.join(root.path, relativePath));
    if (!_within(root.path, joined)) {
      throw PathSecurityError(
        'relativePath escapes canvas root via traversal: $relativePath',
      );
    }
    return File(joined);
  }

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) {
    final root = canvasRoot(projectId: projectId, canvasId: canvasId).path;
    final absolute = p.normalize(
      p.isAbsolute(source.path)
          ? source.path
          : p.join(Directory.current.path, source.path),
    );
    if (!_within(root, absolute)) {
      throw PathSecurityError(
        'source is outside canvas root: ${source.path}',
      );
    }
    return p.relative(absolute, from: root);
  }

  bool _within(String root, String candidate) {
    final normalizedRoot = p.normalize(root);
    final normalized = p.normalize(candidate);
    if (!Platform.isWindows && !normalized.startsWith(normalizedRoot)) {
      return false;
    }
    if (Platform.isWindows &&
        !normalized.toLowerCase().startsWith(normalizedRoot.toLowerCase())) {
      return false;
    }
    if (normalized.length > normalizedRoot.length &&
        normalized[normalizedRoot.length] != p.separator) {
      return false;
    }
    return true;
  }

  void _assertSafeSegment(String value, {required String label}) {
    if (value.isEmpty) {
      throw PathSecurityError('$label must not be empty');
    }
    if (_controlChar.hasMatch(value)) {
      throw PathSecurityError('$label contains control characters');
    }
    if (value.contains(p.separator) ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains('..')) {
      throw PathSecurityError('$label must be a plain segment: $value');
    }
  }
}
