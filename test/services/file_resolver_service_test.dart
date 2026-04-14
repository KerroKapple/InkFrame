// FileResolverService 边界测试：覆盖 Sprint 1 DoD FileResolverService 清单。
//   - 相对 ↔ 绝对转换正确
//   - 拒绝 '..' 穿越（含多层）
//   - 拒绝绝对路径、空串、Unicode 非打印控制字符、Windows drive letter
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileResolverService', () {
    late Directory tempRoot;
    late AppPaths paths;
    late DefaultFileResolverService svc;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('frs_');
      paths = DefaultAppPaths.forRoot(tempRoot);
      await paths.ensureInitialized();
      svc = DefaultFileResolverService(paths);
    });

    tearDown(() async {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('canvasRoot 拼接出 ~/InkFrame/projects/{p}/canvases/{c}', () {
      final dir = svc.canvasRoot(projectId: 'p1', canvasId: 'c1');
      expect(
        dir.path,
        p.join(paths.projects.path, 'p1', 'canvases', 'c1'),
      );
    });

    test('resolve 正常相对路径 → 拼接出绝对 File', () {
      final f = svc.resolve(
        projectId: 'p1',
        canvasId: 'c1',
        relativePath: p.join('images', 'node-42.png'),
      );
      expect(f.path, endsWith(p.join('p1', 'canvases', 'c1', 'images', 'node-42.png')));
    });

    test("resolve 拒绝 '..' 单层穿越", () {
      expect(
        () => svc.resolve(
          projectId: 'p1',
          canvasId: 'c1',
          relativePath: '../escape.png',
        ),
        throwsA(isA<PathSecurityError>()),
      );
    });

    test("resolve 拒绝多层 '..' 穿越", () {
      expect(
        () => svc.resolve(
          projectId: 'p1',
          canvasId: 'c1',
          relativePath: 'images/../../../etc/passwd',
        ),
        throwsA(isA<PathSecurityError>()),
      );
    });

    test('resolve 拒绝绝对路径', () {
      expect(
        () => svc.resolve(
          projectId: 'p1',
          canvasId: 'c1',
          relativePath: '/etc/passwd',
        ),
        throwsA(isA<PathSecurityError>()),
      );
    });

    test('resolve 拒绝空串', () {
      expect(
        () => svc.resolve(
          projectId: 'p1',
          canvasId: 'c1',
          relativePath: '',
        ),
        throwsA(isA<PathSecurityError>()),
      );
    });

    test('resolve 拒绝控制字符（U+0000 / U+001F / DEL）', () {
      for (final bad in <String>['img\u0000.png', 'img\u001F.png', 'img\u007F.png']) {
        expect(
          () => svc.resolve(
            projectId: 'p1',
            canvasId: 'c1',
            relativePath: bad,
          ),
          throwsA(isA<PathSecurityError>()),
          reason: 'should reject: ${bad.codeUnits}',
        );
      }
    });

    test('resolve 合法 Unicode 文件名放行', () {
      final f = svc.resolve(
        projectId: 'p1',
        canvasId: 'c1',
        relativePath: 'images/水墨.png',
      );
      expect(f.path, contains('水墨.png'));
    });

    test('toRelative 将画布内绝对路径归一化', () {
      final root = svc.canvasRoot(projectId: 'p1', canvasId: 'c1');
      root.createSync(recursive: true);
      final abs = File(p.join(root.path, 'images', 'a.png'));
      expect(
        svc.toRelative(projectId: 'p1', canvasId: 'c1', source: abs),
        p.join('images', 'a.png'),
      );
    });

    test('toRelative 拒绝画布外的绝对路径', () {
      final outside = File(p.join(tempRoot.path, 'outside.png'));
      expect(
        () => svc.toRelative(projectId: 'p1', canvasId: 'c1', source: outside),
        throwsA(isA<PathSecurityError>()),
      );
    });

    test('projectId / canvasId 不能含分隔符或 ..', () {
      expect(
        () => svc.canvasRoot(projectId: 'a/b', canvasId: 'c'),
        throwsA(isA<PathSecurityError>()),
      );
      expect(
        () => svc.canvasRoot(projectId: '..', canvasId: 'c'),
        throwsA(isA<PathSecurityError>()),
      );
      expect(
        () => svc.canvasRoot(projectId: 'a', canvasId: ''),
        throwsA(isA<PathSecurityError>()),
      );
    });

    test("'images/./x.png' 规范化后仍在画布内 → 放行", () {
      final f = svc.resolve(
        projectId: 'p1',
        canvasId: 'c1',
        relativePath: p.join('images', '.', 'x.png'),
      );
      expect(f.path, contains(p.join('images', 'x.png')));
    });
  });
}
