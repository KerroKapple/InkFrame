// FileMediaImportService 单测（临时目录 + DefaultFileResolverService）：
// - 复制进 imports/<uuid>.<小写扩展名>，返回相对路径 / 字节数 / 图片宽高；
// - 进度单调不减、最后一次 1.0；
// - 源不在 / 0 字节 / 扩展名不认 / 改名失败 → 各自的 reason，imports/ 里什么都不留；
// - 同名文件导两次落成两个不同文件；
// - 纯函数 importOriginalName / mediaImportKindOf（两种路径分隔符、大小写）。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/media_import_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/file_media_import_service.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:path/path.dart' as p;

const String _pid = 'p1';
const String _cid = 'c1';

/// 一个只有合法 IHDR 头的「PNG」：8 签名 + 长度 13 + IHDR + 宽 + 高 + 5 字节参数 + 4 字节 CRC，
/// 后面再垫 [tail] 个字节。pngDimensions 只看头，不验 CRC。
Uint8List _pngBytes({required int width, required int height, int tail = 16}) {
  final BytesBuilder b = BytesBuilder()
    ..add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(<int>[0, 0, 0, 13])
    ..add(<int>[0x49, 0x48, 0x44, 0x52])
    ..add(_u32(width))
    ..add(_u32(height))
    ..add(<int>[8, 6, 0, 0, 0])
    ..add(<int>[0, 0, 0, 0])
    ..add(List<int>.filled(tail, 7));
  return b.toBytes();
}

List<int> _u32(int v) =>
    <int>[(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

void main() {
  late Directory tmp;
  late Directory srcDir;
  late DefaultFileResolverService resolver;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_media_import_');
    srcDir = Directory(p.join(tmp.path, 'src'))..createSync();
    resolver = DefaultFileResolverService(
      DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'root'))),
    );
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Directory importsDir() => Directory(
        p.join(resolver.canvasRoot(projectId: _pid, canvasId: _cid).path, 'imports'),
      );

  /// imports/ 下的全部文件名（目录不存在 = 空）。
  List<String> importsListing() {
    final Directory d = importsDir();
    if (!d.existsSync()) return const <String>[];
    return d.listSync().map((FileSystemEntity e) => p.basename(e.path)).toList()..sort();
  }

  File source(String name, List<int> bytes) =>
      File(p.join(srcDir.path, name))..writeAsBytesSync(bytes);

  Future<LocalIOError> expectImportError(
    FileMediaImportService service,
    String sourcePath,
  ) async {
    try {
      await service.copyIntoCanvas(projectId: _pid, canvasId: _cid, sourcePath: sourcePath);
    } on LocalIOError catch (e) {
      return e;
    }
    fail('expected LocalIOError');
  }

  group('copyIntoCanvas', () {
    test('png 复制进 imports/<uuid>.png，返回相对路径与字节数，内容一致', () async {
      final Uint8List bytes = _pngBytes(width: 4, height: 3);
      final File src = source('雾江.png', bytes);
      final service = FileMediaImportService(resolver: resolver, newId: () => 'u1');

      final ImportedMedia media =
          await service.copyIntoCanvas(projectId: _pid, canvasId: _cid, sourcePath: src.path);

      expect(media.relativePath, 'imports/u1.png');
      expect(media.kind, MediaImportKind.image);
      expect(media.bytes, bytes.length);
      final File target =
          resolver.resolve(projectId: _pid, canvasId: _cid, relativePath: media.relativePath);
      expect(target.readAsBytesSync(), bytes);
      expect(importsListing(), <String>['u1.png'], reason: '不留 .partial');
      expect(src.existsSync(), isTrue, reason: '源文件不动');
    });

    test('.JPG 落成 .jpg；JPG 宽高走注入的探针（拿到的是目标文件的绝对路径）', () async {
      final File src = source('Photo.JPG', <int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
      final List<String> probed = <String>[];
      final service = FileMediaImportService(
        resolver: resolver,
        newId: () => 'u2',
        imageSizeProbe: (String path) async {
          probed.add(path);
          return (width: 640, height: 480);
        },
      );

      final ImportedMedia media =
          await service.copyIntoCanvas(projectId: _pid, canvasId: _cid, sourcePath: src.path);

      expect(media.relativePath, 'imports/u2.jpg');
      expect(media.kind, MediaImportKind.image);
      expect(importsListing(), <String>['u2.jpg']);
      expect(media.width, 640);
      expect(media.height, 480);
      expect(
        probed,
        <String>[
          resolver.resolve(projectId: _pid, canvasId: _cid, relativePath: 'imports/u2.jpg').path,
        ],
      );
    });

    test('宽高：PNG 读文件头，不调探针', () async {
      final File src = source('a.png', _pngBytes(width: 1920, height: 1080));
      var probeCalls = 0;
      final service = FileMediaImportService(
        resolver: resolver,
        imageSizeProbe: (String path) async {
          probeCalls++;
          return null;
        },
      );

      final ImportedMedia media =
          await service.copyIntoCanvas(projectId: _pid, canvasId: _cid, sourcePath: src.path);

      expect(media.width, 1920);
      expect(media.height, 1080);
      expect(probeCalls, 0);
    });

    test('视频：kind = video，宽高留给抽帧探针（null）', () async {
      final File src = source('船桨.Mp4', List<int>.filled(64, 1));
      final service = FileMediaImportService(resolver: resolver, newId: () => 'v1');

      final ImportedMedia media =
          await service.copyIntoCanvas(projectId: _pid, canvasId: _cid, sourcePath: src.path);

      expect(media.relativePath, 'imports/v1.mp4');
      expect(media.kind, MediaImportKind.video);
      expect(media.width, isNull);
      expect(media.height, isNull);
    });

    test('onProgress 单调递增、最后一次为 1.0', () async {
      final File src = source('big.webp', List<int>.filled(10 * 1024 + 5, 3));
      final List<double> seen = <double>[];
      final service = FileMediaImportService(
        resolver: resolver,
        chunkBytes: 1024,
        imageSizeProbe: (String path) async => null,
      );

      await service.copyIntoCanvas(
        projectId: _pid,
        canvasId: _cid,
        sourcePath: src.path,
        onProgress: seen.add,
      );

      expect(seen.length, greaterThan(1));
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThan(seen[i - 1]), reason: '第 $i 次没有增长：$seen');
      }
      expect(seen.first, greaterThan(0));
      expect(seen.last, 1.0);
    });

    test('源不存在 ⇒ LocalIOError(reason unreadable)，imports/ 为空（无 .partial）', () async {
      final service = FileMediaImportService(resolver: resolver);

      final LocalIOError e =
          await expectImportError(service, p.join(srcDir.path, 'missing.png'));

      expect(e.extra['reason'], kImportReasonUnreadable);
      expect(importsListing(), isEmpty);
    });

    test('0 字节 ⇒ LocalIOError(reason empty)，imports/ 为空', () async {
      final File src = source('empty.jpg', const <int>[]);
      final service = FileMediaImportService(resolver: resolver);

      final LocalIOError e = await expectImportError(service, src.path);

      expect(e.extra['reason'], kImportReasonEmpty);
      expect(importsListing(), isEmpty);
    });

    test('pdf ⇒ LocalIOError(reason unsupported)，不碰盘', () async {
      final File src = source('notes.pdf', <int>[1, 2, 3]);
      final service = FileMediaImportService(resolver: resolver);

      final LocalIOError e = await expectImportError(service, src.path);

      expect(e.extra['reason'], kImportReasonUnsupported);
      expect(importsDir().existsSync(), isFalse);
    });

    test('rename 失败 ⇒ LocalIOError(reason copy_failed)，.partial 被删、imports/ 为空', () async {
      final File src = source('a.png', _pngBytes(width: 2, height: 2));
      final List<String> renamedFrom = <String>[];
      final service = FileMediaImportService(
        resolver: resolver,
        newId: () => 'u3',
        rename: (File partial, String targetPath) async {
          renamedFrom.add(p.basename(partial.path));
          // 改名前 .partial 确实写出来了（证明走的是先写 .partial 再改名）。
          expect(partial.existsSync(), isTrue);
          throw FileSystemException('rename refused', partial.path);
        },
      );

      final LocalIOError e = await expectImportError(service, src.path);

      expect(renamedFrom, <String>['u3.png.partial']);
      expect(e.extra['reason'], kImportReasonCopyFailed);
      expect(e.extra['op'], 'rename');
      expect(importsListing(), isEmpty, reason: '不留 .partial，也不留目标文件');
    });

    test('两次导入同名文件 ⇒ 两个不同 uuid 文件，各自完整', () async {
      final File src = source('same.png', _pngBytes(width: 2, height: 2));
      final service = FileMediaImportService(resolver: resolver);

      final ImportedMedia a =
          await service.copyIntoCanvas(projectId: _pid, canvasId: _cid, sourcePath: src.path);
      final ImportedMedia b =
          await service.copyIntoCanvas(projectId: _pid, canvasId: _cid, sourcePath: src.path);

      expect(a.relativePath, isNot(b.relativePath));
      expect(a.relativePath, isNot(contains('same')));
      expect(importsListing(), hasLength(2));
    });
  });

  group('discard', () {
    test('删掉复制进来的文件；文件不在 / 路径非法都不抛', () async {
      final File src = source('a.png', _pngBytes(width: 2, height: 2));
      final service = FileMediaImportService(resolver: resolver, newId: () => 'd1');
      final ImportedMedia media =
          await service.copyIntoCanvas(projectId: _pid, canvasId: _cid, sourcePath: src.path);
      expect(importsListing(), <String>['d1.png']);

      await service.discard(projectId: _pid, canvasId: _cid, relativePath: media.relativePath);
      expect(importsListing(), isEmpty);

      await service.discard(projectId: _pid, canvasId: _cid, relativePath: media.relativePath);
      await service.discard(projectId: _pid, canvasId: _cid, relativePath: '../escape.png');
    });
  });

  group('纯函数', () {
    test('importOriginalName：p.windows 与 p.posix 都只取 basename，大小写原样', () {
      expect(importOriginalName(r'C:\a\雾江.JPG', context: p.windows), '雾江.JPG');
      expect(importOriginalName(r'c:\Users\x.y\船桨.mp4', context: p.windows), '船桨.mp4');
      expect(importOriginalName('/a/雾江.JPG', context: p.posix), '雾江.JPG');
      expect(importOriginalName('/Users/x.y/船桨.mp4', context: p.posix), '船桨.mp4');
    });

    test('mediaImportKindOf 大小写不敏感、.jpeg 归图片、无扩展名 / 不认的 ⇒ null', () {
      final Map<String, MediaImportKind?> posix = <String, MediaImportKind?>{
        '/a/雾江.JPG': MediaImportKind.image,
        '/a/x.jpg': MediaImportKind.image,
        '/a/x.JPEG': MediaImportKind.image,
        '/a/x.Png': MediaImportKind.image,
        '/a/x.WEBP': MediaImportKind.image,
        '/a/a.Mp4': MediaImportKind.video,
        '/a/a.MOV': MediaImportKind.video,
        '/a/a.webm': MediaImportKind.video,
        '/a/notes.pdf': null,
        '/a/noext': null,
        '/a.png/noext': null,
        '/a/x.gif': null,
      };
      posix.forEach((String path, MediaImportKind? want) {
        expect(mediaImportKindOf(path, context: p.posix), want, reason: path);
      });

      final Map<String, MediaImportKind?> windows = <String, MediaImportKind?>{
        r'C:\a\雾江.JPG': MediaImportKind.image,
        r'd:\Media\a.Mp4': MediaImportKind.video,
        r'C:\a.png\noext': null,
      };
      windows.forEach((String path, MediaImportKind? want) {
        expect(mediaImportKindOf(path, context: p.windows), want, reason: path);
      });
    });
  });
}
