// gallerySaveAsCharacter（GA-4 搬到共享动作）：命名确认 → createFromImage + 成功提示；
// 源文件缺失 → 失败提示、不建记录、不逃逸。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/widgets/gallery_actions.dart';

import '../../../_harness/fake_character.dart';
import '../../../_harness/test_app.dart';

class _TempResolver implements FileResolverService {
  _TempResolver(this.root);
  final String root;
  @override
  File resolve({required String projectId, required String canvasId, required String relativePath}) =>
      File('$root/$projectId/canvases/$canvasId/$relativePath');
  @override
  File resolveInProject({required String projectId, required String relativePath}) => throw UnimplementedError();
  @override
  String toRelative({required String projectId, required String canvasId, required File source}) =>
      throw UnimplementedError();
  @override
  Directory canvasRoot({required String projectId, required String canvasId}) => throw UnimplementedError();
}

const List<int> _kPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

GalleryItem _image() => GalleryItem(
      kind: GalleryItemKind.image,
      relativePath: 'images/a.png',
      canvasId: 'c1',
      canvasName: 'Alpha',
      nodeId: 'n-img',
      createdAt: DateTime.utc(2026, 8, 1),
    );

/// 一个按钮：点了就跑 gallerySaveAsCharacter。
class _Host extends ConsumerWidget {
  const _Host();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => gallerySaveAsCharacter(context, ref, projectId: 'p1', item: _image()),
            child: const Text('go'),
          ),
        ),
      );
}

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('gal_act_'));
  tearDown(() => root.deleteSync(recursive: true));

  Future<void> run(WidgetTester tester, FakeCharacterRepo repo, FakeCharacterAssetService assets) async {
    await pumpInkApp(
      tester,
      const _Host(),
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(_TempResolver(root.path)),
        characterRepositoryProvider.overrideWith((_) async => repo),
        characterAssetServiceProvider.overrideWithValue(assets),
      ],
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hero');
    await tester.pump();
    await tester.tap(find.text('Save')); // 对话框确认键（inspectorCharactersSave）
    await tester.pumpAndSettle();
  }

  testWidgets('命名确认 → createFromImage + 成功提示', (tester) async {
    File('${root.path}/p1/canvases/c1/images/a.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(_kPngBytes);
    final repo = FakeCharacterRepo();
    final assets = FakeCharacterAssetService();
    await run(tester, repo, assets);
    expect(repo.rows, hasLength(1), reason: '角色记录已建');
    expect(assets.imported, hasLength(1), reason: '参考图已导入');
    expect(find.text('Character saved'), findsOneWidget);
  });

  testWidgets('源文件缺失 → 失败提示，不逃逸不建记录（P1-2 回归）', (tester) async {
    final repo = FakeCharacterRepo();
    await run(tester, repo, FakeCharacterAssetService());
    expect(repo.rows, isEmpty, reason: '零角色记录');
    expect(find.text('Character saved'), findsNothing);
    expect(tester.takeException(), isNull, reason: '不逃逸为崩溃');
  });
}
