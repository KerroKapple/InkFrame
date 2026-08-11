// XM-2：从 PNG 文件头读像素尺寸。纯函数，不引图片解码库。
//
// 生成产物落盘时顺手取一次尺寸，写进 node.type_config / batch_results.width|height，
// 供画廊排版与导出算比例用。判定刻意**严格**：签名、chunk 类型、IHDR 长度、非零边长
// 全对才认。认错的代价是把垃圾尺寸写进库并一路带到排版；返回 null 的代价只是前端
// 退回默认比例——两害相权，宁可不猜。

/// PNG 像素尺寸。
typedef PngSize = ({int width, int height});

/// 读文件头至少需要的字节数：8 签名 + 4 长度 + 4 类型 + 4 宽 + 4 高。
const int _kMinHeaderBytes = 24;

/// 读一次文件头建议取的字节数（完整 IHDR chunk 含 CRC = 8 + 4 + 4 + 13 + 4）。
/// 远端下载路径按此长度回读文件开头，不必把整张图读进内存。
const int kPngHeaderProbeBytes = 33;

const List<int> _kSignature = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
];

/// IHDR 的 ASCII 码。
const List<int> _kIhdr = <int>[0x49, 0x48, 0x44, 0x52];

/// IHDR 数据段固定 13 字节（宽 4 + 高 4 + 位深/色彩/压缩/滤波/隔行 各 1）。
const int _kIhdrLength = 13;

/// 解析 [bytes] 开头的 PNG 文件头，返回像素尺寸；不是 PNG、头部残缺或
/// 尺寸非法一律返回 null（调用方按「没拿到」处理，不要回退成 0）。
PngSize? pngDimensions(List<int> bytes) {
  if (bytes.length < _kMinHeaderBytes) return null;
  for (var i = 0; i < _kSignature.length; i++) {
    if (bytes[i] != _kSignature[i]) return null;
  }
  if (_readUint32(bytes, 8) != _kIhdrLength) return null;
  for (var i = 0; i < _kIhdr.length; i++) {
    if (bytes[12 + i] != _kIhdr[i]) return null;
  }
  final int width = _readUint32(bytes, 16);
  final int height = _readUint32(bytes, 20);
  // PNG 规范：宽高均为非零。见到 0 说明文件坏了或根本不是 PNG。
  if (width <= 0 || height <= 0) return null;
  return (width: width, height: height);
}

/// 大端 32 位无符号整数。
int _readUint32(List<int> b, int offset) =>
    (b[offset] << 24) | (b[offset + 1] << 16) | (b[offset + 2] << 8) | b[offset + 3];
