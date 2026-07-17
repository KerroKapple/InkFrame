// ZipProjectImportService 编排测试（LB-12）：安全门/限额/补偿零残留/落位正确性。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/project_import_service.dart';
import 'package:inkframe/core/interfaces/project_import_writer.dart';
import 'package:inkframe/core/models/import_plan_data.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/import/archive_import_guard.dart';
import 'package:inkframe/services/project_import_service.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:path/path.dart' as p;

const _c1 = '11111111-1111-1111-1111-111111111111';
const _unknownCanvas = '99999999-9999-9999-9999-999999999999';

class _FakeWriter implements ProjectImportWriter {
  final List<ImportPlanData> plans = [];
  InkError? error;

  @override
  Future<void> writeAll(ImportPlanData plan) async {
    plans.add(plan);
    final e = error;
    if (e != null) throw e;
  }
}

Map<String, Object?> _manifest({int? format, int? schema}) => {
      'formatVersion': format ?? 1,
      'schemaVersion': schema ?? kAppMigrations.last.version,
      'appVersion': '9.9.9',
    };

Map<String, Object?> _data() => {
      'project': {'id': 'P', 'name': 'demo'},
      'canvases': [
        {'id': _c1, 'project_id': 'P', 'name': 'A'},
      ],
      'nodes': [
        {'id': 'n1', 'canvas_id': _c1, 'type': 'image', 'node_role': 'config'},
      ],
    };

List<int> _zip({
  Map<String, Object?>? manifest,
  Map<String, Object?>? data,
  Map<String, List<int>> files = const {},
  List<String> extraRawNames = const [],
}) {
  final a = Archive();
  a.add(ArchiveFile.string('manifest.json', jsonEncode(manifest ?? _manifest())));
  a.add(ArchiveFile.string('data.json', jsonEncode(data ?? _data())));
  files.forEach((name, bytes) => a.add(ArchiveFile.bytes(name, bytes)));
  for (final n in extraRawNames) {
    a.add(ArchiveFile.string(n, 'x'));
  }
  return ZipEncoder().encode(a);
}

void main() {
  late Directory tmp;
  late AppPaths paths;
  late _FakeWriter writer;
  var idSeq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_import_');
    paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'root')));
    paths.projects.createSync(recursive: true);
    writer = _FakeWriter();
    idSeq = 0;
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // archive 句柄泄漏已知问题（BOARD 债），不影响断言。
    }
  });

  ZipProjectImportService build({int? entryLimit}) => ZipProjectImportService(
        paths: paths,
        writer: writer,
        newIdFactory: () => 'ID-${++idSeq}',
        entryLimitBytes: entryLimit ?? kImportMaxEntryBytes,
      );

  String writeZip(List<int> bytes, [String name = 'p.zip']) {
    final f = File(p.join(tmp.path, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  /// projects/ 下除给定外无任何残留（staging/半成品全无）。
  void expectNoResidue({String? except}) {
    final names = paths.projects
        .listSync()
        .map((e) => p.basename(e.path))
        .where((n) => n != except)
        .toList();
    expect(names, isEmpty, reason: '残留:$names');
  }

  test('成功导入：files 改名落位、writer 收 plan、零 staging、无 Link', () async {
    final zip = _zip(files: {
      'files/canvases/$_c1/images/a.png': [1, 2, 3],
      'files/characters/hero.png': [4],
    });
    final result = await build().importArchive(zipPath: writeZip(zip));

    expect(result.outcome, ImportOutcome.imported);
    final newId = result.newProjectId!;
    expect(writer.plans, hasLength(1));
    final newC1 = writer.plans.single.canvasIdMap[_c1]!;
    final img =
        File(p.join(paths.projects.path, newId, 'canvases', newC1, 'images', 'a.png'));
    expect(img.readAsBytesSync(), [1, 2, 3]);
    expect(
      File(p.join(paths.projects.path, newId, 'characters', 'hero.png'))
          .existsSync(),
      isTrue,
    );
    expectNoResidue(except: newId);
    // 全程不创建 Link。
    final links = Directory(p.join(paths.projects.path, newId))
        .listSync(recursive: true, followLinks: false)
        .whereType<Link>();
    expect(links, isEmpty);
  });

  test('恶意条目（../）→ failedCorrupt，writer 零调用零残留', () async {
    final zip = _zip(extraRawNames: ['files/../evil']);
    final result = await build().importArchive(zipPath: writeZip(zip));
    expect(result.outcome, ImportOutcome.failedCorrupt);
    expect(result.reason, 'dot_segment');
    expect(writer.plans, isEmpty);
    expectNoResidue();
  });

  test('谎报无效防线：声明过粗筛但实测超限 → failedCorrupt 零残留', () async {
    // 1MB 高压缩内容；服务注入 8KB 实测上限（声明 1MB < 2GB 粗筛放行）——
    // 计数 sink 在提取层截停。
    final zip = _zip(files: {
      'files/canvases/$_c1/big.bin': List<int>.filled(1024 * 1024, 0),
    });
    final result =
        await build(entryLimit: 8 * 1024).importArchive(zipPath: writeZip(zip));
    expect(result.outcome, ImportOutcome.failedCorrupt);
    expect(result.reason, 'limit_entry');
    expectNoResidue();
  });

  test('重名条目（raw 中央目录）→ failedCorrupt', () async {
    // Archive.add 会去重——用 ZipFileEncoder 顺序写出真重名条目。
    final path = p.join(tmp.path, 'dup.zip');
    final enc = ZipFileEncoder()..create(path);
    enc.addArchiveFile(
        ArchiveFile.string('manifest.json', jsonEncode(_manifest())));
    enc.addArchiveFile(ArchiveFile.string('data.json', jsonEncode(_data())));
    enc.addArchiveFile(ArchiveFile.string('data.json', '{"evil":1}'));
    await enc.close();

    final result = await build().importArchive(zipPath: path);
    expect(result.outcome, ImportOutcome.failedCorrupt);
    expect(result.reason, 'duplicate_entry');
    expectNoResidue();
  });

  test('损坏 zip → failedCorrupt 零残留', () async {
    final good = _zip();
    final result = await build()
        .importArchive(zipPath: writeZip(good.sublist(0, 40), 'bad.zip'));
    expect(result.outcome, ImportOutcome.failedCorrupt);
    expectNoResidue();
  });

  test('formatVersion / schemaVersion 门', () async {
    final r1 = await build()
        .importArchive(zipPath: writeZip(_zip(manifest: _manifest(format: 2))));
    expect(r1.outcome, ImportOutcome.failedFormat);
    final r2 = await build().importArchive(
        zipPath: writeZip(
            _zip(manifest: _manifest(schema: kAppMigrations.last.version + 1)),
            'v.zip'));
    expect(r2.outcome, ImportOutcome.failedVersionNewer);
    expectNoResidue();
  });

  test('files/canvases/{UUID 形但不在清单} → failedCorrupt（孤儿目录注入关死）',
      () async {
    final zip = _zip(files: {
      'files/canvases/$_unknownCanvas/x.png': [1],
    });
    final result = await build().importArchive(zipPath: writeZip(zip));
    expect(result.outcome, ImportOutcome.failedCorrupt);
    expect(result.reason, 'unknown_canvas_dir');
    expectNoResidue();
  });

  test('writer 抛错 → failed，已落位目录被补偿删除（零残留）', () async {
    writer.error = const LocalIOError();
    final zip = _zip(files: {
      'files/canvases/$_c1/images/a.png': [1],
    });
    final result = await build().importArchive(zipPath: writeZip(zip));
    expect(result.outcome, ImportOutcome.failed);
    expectNoResidue();
  });

  test('stale .import-* 启动清扫', () async {
    Directory(p.join(paths.projects.path, '.import-stale'))
        .createSync(recursive: true);
    await build().importArchive(zipPath: writeZip(_zip()));
    expect(
      Directory(p.join(paths.projects.path, '.import-stale')).existsSync(),
      isFalse,
    );
  });
}
