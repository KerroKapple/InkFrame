// XM-2 PNG 像素尺寸解析。
//
// 只认 PNG 且只读文件头——生成产物落盘时顺手取尺寸，不为此引入图片解码库。
// 判定必须**严格**：认错了会把垃圾尺寸写进库，而库里的 width/height 后续要拿去
// 排版和算比例。宁可返回 null（前端退回默认比例），也不猜。

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/media/png_dimensions.dart';

List<int> _be32(int v) =>
    <int>[(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

const List<int> _signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// 拼一个合法（或按参数故意不合法）的 PNG 文件头。
List<int> _png({
  int width = 1536,
  int height = 864,
  String chunkType = 'IHDR',
  int ihdrLength = 13,
  List<int> signature = _signature,
}) {
  final b = BytesBuilder();
  b.add(signature);
  b.add(_be32(ihdrLength));
  b.add(ascii.encode(chunkType));
  b.add(_be32(width));
  b.add(_be32(height));
  b.add(<int>[8, 6, 0, 0, 0]); // 位深/色彩类型/压缩/滤波/隔行
  b.add(_be32(0)); // CRC 占位
  return b.toBytes();
}

void main() {
  group('识别合法 PNG', () {
    test('读出 IHDR 里的宽高', () {
      expect(pngDimensions(_png(width: 1536, height: 864)),
          (width: 1536, height: 864));
    });

    test('大于 16 位的边长按 32 位大端读', () {
      expect(pngDimensions(_png(width: 70000, height: 100000)),
          (width: 70000, height: 100000));
    });

    test('尾部还有其他 chunk 不影响（传整个文件也行）', () {
      final withTail = <int>[..._png(width: 8, height: 9), ...List.filled(500, 0)];
      expect(pngDimensions(withTail), (width: 8, height: 9));
    });

    test('正方形 1x1 也认', () {
      expect(pngDimensions(_png(width: 1, height: 1)), (width: 1, height: 1));
    });
  });

  group('拒绝非 PNG / 可疑头部 —— 一律 null，不猜', () {
    test('JPEG 头', () {
      expect(pngDimensions(<int>[0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(40, 0)]),
          isNull);
    });

    test('签名对不上（改了一个字节）', () {
      final bad = <int>[..._signature]..[3] = 0x00;
      expect(pngDimensions(_png(signature: bad)), isNull);
    });

    test('第一个 chunk 不是 IHDR', () {
      expect(pngDimensions(_png(chunkType: 'iTXt')), isNull);
    });

    test('IHDR 声明长度不是 13', () {
      expect(pngDimensions(_png(ihdrLength: 9)), isNull);
    });

    test('宽或高为 0（PNG 规范禁止，出现即文件坏）', () {
      expect(pngDimensions(_png(width: 0, height: 100)), isNull);
      expect(pngDimensions(_png(width: 100, height: 0)), isNull);
    });

    test('头部被截断', () {
      final full = _png();
      expect(pngDimensions(full.sublist(0, 23)), isNull);
      expect(pngDimensions(full.sublist(0, 8)), isNull);
    });

    test('空输入', () {
      expect(pngDimensions(const <int>[]), isNull);
    });
  });

  test('接受任意 List<int>（Uint8List 与普通 List 同解）', () {
    final bytes = _png(width: 42, height: 24);
    expect(pngDimensions(Uint8List.fromList(bytes)), (width: 42, height: 24));
    expect(pngDimensions(bytes.toList()), (width: 42, height: 24));
  });
}
