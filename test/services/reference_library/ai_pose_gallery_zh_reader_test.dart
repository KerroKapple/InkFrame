// AiPoseGalleryZhReader 单测：四个数据文件的解析、成人向过滤、路径拼接、
// 坏文件只跳过那一类、文件夹选错一级时认作「不是参考库」。
//
// fixture 在 test/fixtures/reference_library/：ok = 四个文件齐全（图片是 1×1 PNG）；
// broken_costume = pose 正常（含两条坏记录），costume-zh.json 是截断的 JSON。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/reference_library_reader.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/models/reference_item.dart';
import 'package:inkframe/services/reference_library/ai_pose_gallery_zh_reader.dart';
import 'package:path/path.dart' as p;

import '../../helpers/recording_logger.dart';

final String _fixtures = p.absolute('test', 'fixtures', 'reference_library');
final String _ok = p.join(_fixtures, 'ok');
final String _brokenCostume = p.join(_fixtures, 'broken_costume');

List<ReferenceItem> _of(ReferenceLibraryLoad load, ReferenceCategory c) {
  expect(load, isA<ReferenceLibraryLoaded>());
  return (load as ReferenceLibraryLoaded)
      .items
      .where((ReferenceItem i) => i.category == c)
      .toList();
}

void main() {
  late RecordingLogger logger;
  late AiPoseGalleryZhReader reader;

  setUp(() {
    logger = RecordingLogger();
    reader = AiPoseGalleryZhReader(logger: logger);
  });

  group('四个文件齐全', () {
    test('读出 Loaded；成人向被滤掉；skippedFiles 为空；不记 warn', () async {
      final ReferenceLibraryLoad load = await reader.load(_ok);

      expect(load, isA<ReferenceLibraryLoaded>());
      expect((load as ReferenceLibraryLoaded).skippedFiles, isEmpty);
      expect(
        _of(load, ReferenceCategory.pose).map((ReferenceItem i) => i.id),
        <String>['pose_std_P001_front', 'pose_std_P001_side'],
      );
      expect(
        _of(load, ReferenceCategory.portrait).map((ReferenceItem i) => i.id),
        <String>['pt0000001', 'pt0000002'],
      );
      // 春季穿搭 + 历代（内衣・睡衣、性感穿搭被滤掉）。
      expect(
        _of(load, ReferenceCategory.costume).map((ReferenceItem i) => i.id),
        <String>['SPR-0001', 'shisei-C001'],
      );
      expect(logger.byLevel(InkLogLevel.warn), isEmpty);
    });

    test('pose 条目：name = 姿势名称、group = 分类、angle = 角度、searchText = 检索',
        () async {
      final ReferenceItem front =
          _of(await reader.load(_ok), ReferenceCategory.pose).first;

      expect(front.name, '自然站立・双手垂放');
      expect(front.group, '站姿');
      expect(front.angle, '正面');
      expect(
        front.searchText,
        'pose_std_P001_front 全身单人・标准系站姿自然站立・双手垂放正面',
      );
    });

    test('portrait：name = 标题、group = 分区、无 angle', () async {
      final List<ReferenceItem> portraits =
          _of(await reader.load(_ok), ReferenceCategory.portrait);

      expect(portraits.first.name, '短发・标准款');
      expect(portraits.first.group, '正脸参考');
      expect(portraits.first.angle, isNull);
      expect(portraits.last.group, '造型氛围');
    });

    test('costume：name = 服装名称、group = 分类；历代没有原图时取预览图', () async {
      final List<ReferenceItem> costumes =
          _of(await reader.load(_ok), ReferenceCategory.costume);
      final ReferenceItem spring = costumes.first;
      final ReferenceItem shisei = costumes.last;

      expect(spring.name, '象牙白针织衫・牛仔半身裙');
      expect(spring.group, '春季穿搭');
      expect(spring.angle, isNull);
      expect(shisei.group, '中国历代');
      expect(
        shisei.originalPath,
        p.join(_ok, 'img', 'costumes', 'shisei', 'costume_C001_front.png'),
      );
    });

    test('每条的缩略图、原图都是绝对路径，且文件真的打得开（JSON 里是正斜杠）', () async {
      final ReferenceLibraryLoad load = await reader.load(_ok);
      final List<ReferenceItem> items = (load as ReferenceLibraryLoaded).items;

      expect(items, hasLength(6));
      for (final ReferenceItem item in items) {
        expect(p.isAbsolute(item.thumbPath), isTrue, reason: item.thumbPath);
        expect(p.isAbsolute(item.originalPath), isTrue,
            reason: item.originalPath);
        expect(File(item.thumbPath).existsSync(), isTrue,
            reason: item.thumbPath);
        expect(File(item.originalPath).existsSync(), isTrue,
            reason: item.originalPath);
      }
      // 嵌套目录按平台分隔符拼：Windows 上不能留下 `thumbs/costume/…` 的正斜杠段。
      final ReferenceItem spring = items
          .firstWhere((ReferenceItem i) => i.id == 'SPR-0001');
      expect(spring.thumbPath, p.join(_ok, 'thumbs', 'costume', 'SPR-0001.png'));
    });
  });

  group('一个类别的文件坏了', () {
    test('costume-zh.json 截断：pose 照常、costume 0 条、skippedFiles 点名、记一条 warn',
        () async {
      final ReferenceLibraryLoad load = await reader.load(_brokenCostume);

      expect(load, isA<ReferenceLibraryLoaded>());
      expect((load as ReferenceLibraryLoaded).skippedFiles,
          <String>['costume-zh.json']);
      expect(_of(load, ReferenceCategory.pose), hasLength(1));
      expect(_of(load, ReferenceCategory.costume), isEmpty);

      final List<LogRecord> warns = logger.byLevel(InkLogLevel.warn);
      expect(warns, hasLength(1));
      expect(warns.single.extra?['file'], 'costume-zh.json');
    });

    test('字段缺失或类型不对的单条记录跳过，不算整个文件坏', () async {
      final ReferenceLibraryLoad load = await reader.load(_brokenCostume);

      expect(
        _of(load, ReferenceCategory.pose).map((ReferenceItem i) => i.id),
        <String>['pose_std_P002_front'],
      );
      expect((load as ReferenceLibraryLoaded).skippedFiles,
          isNot(contains('pose-zh.json')));
    });
  });

  group('不是参考库', () {
    test('空文件夹 ⇒ NotFound', () async {
      final Directory empty =
          Directory.systemTemp.createTempSync('inkframe_reflib_empty_');
      addTearDown(() => empty.deleteSync(recursive: true));

      expect(await reader.load(empty.path), isA<ReferenceLibraryNotFound>());
    });

    test('选成了下一级（…/data）⇒ NotFound', () async {
      expect(
        await reader.load(p.join(_ok, 'data')),
        isA<ReferenceLibraryNotFound>(),
      );
    });

    test('选成了上一级（几个图库的父目录）⇒ NotFound', () async {
      expect(await reader.load(_fixtures), isA<ReferenceLibraryNotFound>());
    });

    test('路径不存在 ⇒ NotFound，不抛', () async {
      final Directory tmp =
          Directory.systemTemp.createTempSync('inkframe_reflib_gone_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      expect(
        await reader.load(p.join(tmp.path, 'does-not-exist')),
        isA<ReferenceLibraryNotFound>(),
      );
    });

    test('空字符串 ⇒ NotFound', () async {
      expect(await reader.load(''), isA<ReferenceLibraryNotFound>());
    });
  });
}
