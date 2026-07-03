// DefaultFileResolverService：FileResolverService 的磁盘实现。
//
// 接口契约（含 PathSecurityError）在 lib/core/interfaces/file_resolver_service.dart。
// 实现可依赖 core 接口；本文件只负责落地路径转换 + 边界校验。
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/file_resolver_service.dart';
import '../core/paths/app_paths.dart';

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
    final root = canvasRoot(projectId: projectId, canvasId: canvasId);
    return _resolveWithin(root, relativePath, rootLabel: 'canvas');
  }

  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) {
    _assertSafeSegment(projectId, label: 'projectId');
    final root = Directory(p.join(_paths.projects.path, projectId));
    return _resolveWithin(root, relativePath, rootLabel: 'project');
  }

  File _resolveWithin(
    Directory root,
    String relativePath, {
    required String rootLabel,
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

    final joined = p.normalize(p.join(root.path, relativePath));
    if (!_within(root.path, joined)) {
      throw PathSecurityError(
        'relativePath escapes $rootLabel root via traversal: $relativePath',
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
