// ZipProjectArchiveService 单测：zip 布局 / 全保真行 / 原子落盘 / 失败清理。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/project_archive_reader.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/project_archive_service.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';

class _FakeReader implements ProjectArchiveReader {
  _FakeReader({this.project, this.throwOnNodes = false});

  Map<String, Object?>? project;
  bool throwOnNodes;

  @override
  Future<Map<String, Object?>?> projectRow(String projectId) async => project;

  @override
  Future<List<Map<String, Object?>>> canvasRows(String p) async =>
      <Map<String, Object?>>[
        <String, Object?>{'id': 'c1', 'project_id': p, 'deleted_at': null},
      ];

  @override
  Future<List<Map<String, Object?>>> nodeRows(String p) async {
    if (throwOnNodes) throw const LocalIOError();
    return <Map<String, Object?>>[
      <String, Object?>{
        'id': 'n1',
        'canvas_id': 'c1',
        // DateTime 必须被 ISO 化，否则 jsonEncode 直接炸。
        'created_at': DateTime.utc(2026, 7, 16),
        'type_config': <String, Object?>{'image_url': 'images/a.png'},
      },
    ];
  }

  @override
  Future<List<Map<String, Object?>>> edgeRows(String p) async => const [];

  @override
  Future<List<Map<String, Object?>>> laneRows(String p) async => const [];

  @override
  Future<List<Map<String, Object?>>> characterRows(String p) async => const [];

  @override
  Future<List<Map<String, Object?>>> presetRows(String p) async => const [];

  @override
  Future<List<Map<String, Object?>>> successJobRows(String p) async =>
      const [];

  @override
  Future<List<Map<String, Object?>>> batchResultRows(String p) async =>
      const [];
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('archive_test');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  ZipProjectArchiveService build(_FakeReader reader) {
    final paths = DefaultAppPaths.forRoot(Directory('${temp.path}/root'));
    return ZipProjectArchiveService(
      reader: reader,
      paths: paths,
      clock: const SystemClock(),
      appVersion: '9.9.9',
    );
  }

  List<int> entryBytes(Archive archive, String name) {
    final f = archive.files.firstWhere((f) => f.name == name);
    return (f.content as List<int>).toList();
  }

  test('导出 zip：manifest/data/files 齐全，路径用 /，DateTime ISO 化', () async {
    final reader = _FakeReader(
      project: <String, Object?>{'id': 'p1', 'name': 'demo'},
    );
    final svc = build(reader);
    // 种子磁盘产物：projects/p1/canvases/c1/images/a.png + exports/out.mp4。
    Directory('${temp.path}/root/projects/p1/canvases/c1/images')
        .createSync(recursive: true);
    File('${temp.path}/root/projects/p1/canvases/c1/images/a.png')
        .writeAsBytesSync(<int>[1, 2, 3]);
    Directory('${temp.path}/root/projects/p1/exports')
        .createSync(recursive: true);
    File('${temp.path}/root/projects/p1/exports/out.mp4')
        .writeAsBytesSync(<int>[4]);

    final target = '${temp.path}/demo.zip';
    await svc.exportProject(projectId: 'p1', targetPath: target);

    final archive = ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    expect(
      names,
      containsAll(<String>{
        'manifest.json',
        'data.json',
        'files/canvases/c1/images/a.png',
        'files/exports/out.mp4',
      }),
    );
    expect(names.any((n) => n.contains('\\')), isFalse);
    expect(entryBytes(archive, 'files/canvases/c1/images/a.png'),
        <int>[1, 2, 3]);

    final manifest =
        jsonDecode(utf8.decode(entryBytes(archive, 'manifest.json')))
            as Map<String, dynamic>;
    expect(manifest['formatVersion'], 1);
    expect(manifest['schemaVersion'], kAppMigrations.last.version);
    expect(manifest['appVersion'], '9.9.9');
    expect(manifest['exportedAt'], isA<String>());

    final data = jsonDecode(utf8.decode(entryBytes(archive, 'data.json')))
        as Map<String, dynamic>;
    expect((data['project'] as Map)['id'], 'p1');
    expect(data['nodes'] as List, hasLength(1));
    expect(
      ((data['nodes'] as List).first as Map)['created_at'],
      '2026-07-16T00:00:00.000Z',
    );
    for (final key in <String>[
      'canvases',
      'edges',
      'lanes',
      'characters',
      'prompt_presets',
      'jobs',
      'batch_results',
    ]) {
      expect(data, contains(key));
    }
    // 未产生 .partial 残留。
    expect(File('$target.partial').existsSync(), isFalse);
  });

  test('无磁盘产物的空项目：zip 只有 manifest/data，合法', () async {
    final reader = _FakeReader(project: <String, Object?>{'id': 'p1'});
    final svc = build(reader);
    final target = '${temp.path}/empty.zip';
    await svc.exportProject(projectId: 'p1', targetPath: target);

    final archive = ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    expect(
      archive.files.map((f) => f.name).toSet(),
      <String>{'manifest.json', 'data.json'},
    );
  });

  test('项目不存在 → LocalIOError，且不产生任何文件', () async {
    final svc = build(_FakeReader(project: null));
    final target = '${temp.path}/none.zip';
    await expectLater(
      svc.exportProject(projectId: 'nope', targetPath: target),
      throwsA(isA<LocalIOError>()),
    );
    expect(File(target).existsSync(), isFalse);
    expect(File('$target.partial').existsSync(), isFalse);
  });

  test('读侧中途抛错 → 清 partial、错误冒泡', () async {
    final reader = _FakeReader(
      project: <String, Object?>{'id': 'p1'},
      throwOnNodes: true,
    );
    final svc = build(reader);
    final target = '${temp.path}/boom.zip';
    await expectLater(
      svc.exportProject(projectId: 'p1', targetPath: target),
      throwsA(isA<LocalIOError>()),
    );
    expect(File(target).existsSync(), isFalse);
    expect(File('$target.partial').existsSync(), isFalse);
  });

  test('目标已存在 → 覆盖为新内容', () async {
    final reader = _FakeReader(project: <String, Object?>{'id': 'p1'});
    final svc = build(reader);
    final target = '${temp.path}/exists.zip';
    File(target).writeAsBytesSync(<int>[9, 9, 9]);
    await svc.exportProject(projectId: 'p1', targetPath: target);
    final archive = ZipDecoder().decodeBytes(File(target).readAsBytesSync());
    expect(archive.files.map((f) => f.name), contains('manifest.json'));
  });

  test('suggestedArchiveName：非法字符剥离、空名兜底', () {
    expect(suggestedArchiveName('My: Film/Take*2'), 'My FilmTake2.zip');
    expect(suggestedArchiveName('   '), 'project.zip');
    expect(suggestedArchiveName('简单名'), '简单名.zip');
  });
}
