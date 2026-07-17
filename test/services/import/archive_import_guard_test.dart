// 导入安全门单测（LB-12 拍板 4 rev2）：条目名正面校验 / manifest 门 / 计数 sink。
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/services/import/archive_import_guard.dart';

ArchiveEntryMeta _e(String name, {int size = 10, bool symlink = false}) =>
    ArchiveEntryMeta(name: name, declaredSize: size, isSymlink: symlink);

const _cid = '11111111-2222-3333-4444-555555555555';

List<ArchiveEntryMeta> _valid([List<ArchiveEntryMeta> extra = const []]) =>
    <ArchiveEntryMeta>[
      _e('manifest.json'),
      _e('data.json'),
      _e('files/canvases/$_cid/images/a.png'),
      _e('files/characters/hero.png'),
      _e('files/exports/out.mp4'),
      ...extra,
    ];

void main() {
  group('validateArchiveEntries', () {
    test('合法清单放行', () {
      expect(validateArchiveEntries(_valid()), isNull);
    });

    test('穿越/绝对/盘符/反斜杠/控制字符全拒', () {
      expect(validateArchiveEntries(_valid([_e('files/../evil')])),
          'dot_segment');
      expect(validateArchiveEntries(_valid([_e('/abs')])), 'absolute_path');
      expect(validateArchiveEntries(_valid([_e('C:evil')])), 'drive_letter');
      expect(validateArchiveEntries(_valid([_e(r'files/a\b')])), 'backslash');
      expect(validateArchiveEntries(_valid([_e('files/a\x01b')])),
          'control_chars');
    });

    test('重名 / symlink / 名单外 / 缺 manifest/data 拒', () {
      expect(validateArchiveEntries(_valid([_e('data.json')])),
          'duplicate_entry');
      expect(
          validateArchiveEntries(_valid([_e('files/x', symlink: true)])),
          'symlink_entry');
      expect(validateArchiveEntries(_valid([_e('foo.txt')])),
          'unexpected_entry');
      expect(validateArchiveEntries(<ArchiveEntryMeta>[_e('data.json')]),
          'missing_manifest');
      expect(validateArchiveEntries(<ArchiveEntryMeta>[_e('manifest.json')]),
          'missing_data');
    });

    test('Windows 保留名（含剥扩展名）/结尾点空格/超长名拒', () {
      expect(validateArchiveEntries(_valid([_e('files/NUL.png')])),
          'reserved_device_name');
      expect(validateArchiveEntries(_valid([_e('files/con')])),
          'reserved_device_name');
      expect(validateArchiveEntries(_valid([_e('files/a.png.')])),
          'trailing_dot_or_space');
      expect(validateArchiveEntries(_valid([_e('files/a.png ')])),
          'trailing_dot_or_space');
      expect(
          validateArchiveEntries(_valid([_e('files/${'a' * 200}.png')])),
          'entry_name_length');
    });

    test('files/canvases 段必须 UUID 形', () {
      expect(
          validateArchiveEntries(_valid([_e('files/canvases/evil-dir/x.png')])),
          'canvas_segment_shape');
      // 非 canvases 子树不受 UUID 约束。
      expect(validateArchiveEntries(_valid([_e('files/exports/x.png')])),
          isNull);
    });

    test('声明尺寸粗筛：单条目/总量超限拒（advisory 层）', () {
      expect(
        validateArchiveEntries(
            _valid([_e('files/big.bin', size: kImportMaxEntryBytes + 1)])),
        'entry_size_declared',
      );
      expect(
        validateArchiveEntries(_valid([
          _e('files/b1.bin', size: kImportMaxEntryBytes),
          _e('files/b2.bin', size: kImportMaxEntryBytes),
          _e('files/b3.bin', size: kImportMaxEntryBytes),
          _e('files/b4.bin', size: kImportMaxEntryBytes),
          _e('files/b5.bin', size: kImportMaxEntryBytes),
          _e('files/b6.bin', size: kImportMaxEntryBytes),
          _e('files/b7.bin', size: kImportMaxEntryBytes),
          _e('files/b8.bin', size: kImportMaxEntryBytes),
          _e('files/b9.bin', size: 1),
        ])),
        'total_size_declared',
      );
    });
  });

  group('validateManifest', () {
    test('formatVersion 严格相等 / schemaVersion 门', () {
      expect(
          validateManifest({'formatVersion': 1, 'schemaVersion': 7},
              currentSchemaVersion: 7),
          isNull);
      expect(
          validateManifest({'formatVersion': 2, 'schemaVersion': 7},
              currentSchemaVersion: 7),
          'format_version');
      expect(
          validateManifest({'formatVersion': 1, 'schemaVersion': 8},
              currentSchemaVersion: 7),
          'schema_version_newer');
      expect(
          validateManifest({'formatVersion': 1, 'schemaVersion': 3},
              currentSchemaVersion: 7),
          isNull);
      expect(validateManifest({'formatVersion': 1}, currentSchemaVersion: 7),
          'schema_version_missing');
    });
  });

  group('CountingLimitOutputStream（实测字节真防线）', () {
    test('实测超单条目上限即抛——声明值谎报为 0 也拦得住', () {
      final inner = OutputMemoryStream();
      final budget = ImportByteBudget(limit: 1000);
      final sink = CountingLimitOutputStream(inner,
          entryLimit: 100, totalCounter: budget);
      // 模拟解压回调持续写出（声明尺寸从未参与）。
      expect(
        () {
          for (var i = 0; i < 200; i++) {
            sink.writeByte(0);
          }
        },
        throwsA(isA<ImportLimitExceeded>()),
      );
      expect(inner.length, lessThanOrEqualTo(101));
    });

    test('跨条目总量预算累计', () {
      final budget = ImportByteBudget(limit: 150);
      final s1 = CountingLimitOutputStream(OutputMemoryStream(),
          entryLimit: 1000, totalCounter: budget);
      s1.writeBytes(List<int>.filled(100, 0));
      final s2 = CountingLimitOutputStream(OutputMemoryStream(),
          entryLimit: 1000, totalCounter: budget);
      expect(
        () => s2.writeBytes(List<int>.filled(100, 0)),
        throwsA(isA<ImportLimitExceeded>()),
      );
      expect(budget.used, greaterThan(150));
    });

    test('真 deflate：小体积大解压流被实测截停', () {
      // 高度可压缩载荷：1MB 零字节 → zip 后极小；解压计数必须按实测拦。
      final payload = List<int>.filled(1024 * 1024, 0);
      final archive = Archive()
        ..add(ArchiveFile.bytes('big.bin', payload));
      final zipped = ZipEncoder().encode(archive);
      final decoded = ZipDecoder().decodeBytes(zipped);
      final entry = decoded.files.single;
      // 声明值即便被信任也无妨——这里直接实测：写出经限 8KB 的 sink。
      final sink = CountingLimitOutputStream(OutputMemoryStream(),
          entryLimit: 8 * 1024, totalCounter: ImportByteBudget());
      expect(() => entry.writeContent(sink),
          throwsA(isA<ImportLimitExceeded>()));
    });
  });
}
