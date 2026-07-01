import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/character_asset_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/character_asset_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late DefaultCharacterAssetService svc;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('char_assets_');
    svc = DefaultCharacterAssetService(DefaultAppPaths.forRoot(tmp));
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('importImage 复制源图进 characters/ 并返回项目相对路径', () async {
    final src = File(p.join(tmp.path, 'src.png'))..writeAsBytesSync([1, 2, 3]);
    final rel = await svc.importImage(
      projectId: 'p1',
      sourceAbsolutePath: src.path,
      fileBaseName: 'char-1-0',
    );
    expect(rel, 'characters/char-1-0.png');
    final abs = svc.absolutePathOf(projectId: 'p1', relativePath: rel);
    expect(File(abs).existsSync(), isTrue);
    expect(File(abs).readAsBytesSync(), [1, 2, 3]);
  });

  test('importImage 源缺失 → CharacterAssetError', () {
    expect(
      () => svc.importImage(
        projectId: 'p1',
        sourceAbsolutePath: p.join(tmp.path, 'nope.png'),
        fileBaseName: 'x',
      ),
      throwsA(isA<CharacterAssetError>()),
    );
  });

  test('resolveExisting 只回存在的绝对路径，缺文件跳过', () async {
    final src = File(p.join(tmp.path, 's.jpg'))..writeAsBytesSync([9]);
    final rel = await svc.importImage(
      projectId: 'p1',
      sourceAbsolutePath: src.path,
      fileBaseName: 'a',
    );
    final out = await svc.resolveExisting(
      projectId: 'p1',
      relativePaths: [rel, 'characters/ghost.png'],
    );
    expect(out, hasLength(1));
    expect(out.single, endsWith('a.jpg'));
  });

  test('absolutePathOf 拒绝 traversal', () {
    expect(
      () =>
          svc.absolutePathOf(projectId: 'p1', relativePath: '../../etc/passwd'),
      throwsA(isA<CharacterAssetError>()),
    );
  });

  test('delete 移除文件，缺失静默', () async {
    final src = File(p.join(tmp.path, 's.png'))..writeAsBytesSync([1]);
    final rel = await svc.importImage(
      projectId: 'p1',
      sourceAbsolutePath: src.path,
      fileBaseName: 'a',
    );
    final abs = svc.absolutePathOf(projectId: 'p1', relativePath: rel);
    expect(File(abs).existsSync(), isTrue);
    await svc.delete(projectId: 'p1', relativePath: rel);
    expect(File(abs).existsSync(), isFalse);
    await svc.delete(projectId: 'p1', relativePath: rel); // 再删静默不抛
  });

  test('absolutePathOf 拒绝越权 relativePath（跨平台向量）', () {
    // 平台无关向量：POSIX 绝对路径、上跳、内嵌上跳、空串——两平台均拒。
    for (final bad in <String>[
      '/etc/passwd',
      '../secret.png',
      'characters/../../secret',
      '',
    ]) {
      expect(
        () => svc.absolutePathOf(projectId: 'p1', relativePath: bad),
        throwsA(isA<CharacterAssetError>()),
        reason: 'should reject relativePath: "$bad"',
      );
    }
  });

  test('absolutePathOf 拒绝越权 projectId', () {
    for (final bad in <String>['..', '../x', 'a/b', '']) {
      expect(
        () => svc.absolutePathOf(
          projectId: bad,
          relativePath: 'characters/a.png',
        ),
        throwsA(isA<CharacterAssetError>()),
        reason: 'should reject projectId: "$bad"',
      );
    }
  });
}
