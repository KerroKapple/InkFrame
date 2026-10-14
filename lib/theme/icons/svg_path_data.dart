// SVG path 的 d 字符串 → dart:ui Path。
//
// 只为图标集服务：图标的路径数据原样来自设计稿（ink_glyph.dart），在这里转成
// Path，不引入 SVG 依赖。命令表是完整的 M L H V C S Q T A Z（大小写都认），
// 数字支持 SVG 的紧凑写法（`1.5.5` = 1.5 与 .5，`2-1` = 2 与 -1，指数），
// 弧线的两个标志位可以不带分隔（`a1 1 0 01 2 2`）。
//
// 坏数据直接抛 [FormatException]（带出错位置）——图标数据是编译期常量，
// 出错只会发生在改图标的那次提交，测试里立刻能看到，不做容错。
import 'dart:ui';

/// 把 SVG path 数据解析成 [Path]。坐标不做任何缩放。
Path parseSvgPathData(String data) => _SvgPathParser(data).parse();

class _SvgPathParser {
  _SvgPathParser(this._src);

  final String _src;
  int _pos = 0;

  final Path _path = Path();
  double _x = 0, _y = 0; // 当前点
  double _startX = 0, _startY = 0; // 当前子路径起点（Z 回到这里）
  // 上一条三次 / 二次曲线的控制点；S / T 用它做镜像。非曲线命令后清空。
  double? _lastCubicX, _lastCubicY, _lastQuadX, _lastQuadY;

  Path parse() {
    String? command;
    _skipSeparators();
    while (_pos < _src.length) {
      final String ch = _src[_pos];
      if (_isCommand(ch)) {
        command = ch;
        _pos++;
      } else if (command == null) {
        throw FormatException('path data must start with a command', _src, _pos);
      } else if (command == 'M') {
        command = 'L'; // M 之后的成对坐标按 L 处理
      } else if (command == 'm') {
        command = 'l';
      } else if (command == 'Z' || command == 'z') {
        throw FormatException('unexpected number after Z', _src, _pos);
      }
      _run(command);
      _skipSeparators();
    }
    return _path;
  }

  void _run(String command) {
    final bool rel = command == command.toLowerCase();
    final double ox = rel ? _x : 0, oy = rel ? _y : 0;
    switch (command.toUpperCase()) {
      case 'M':
        _x = ox + _number();
        _y = oy + _number();
        _path.moveTo(_x, _y);
        _startX = _x;
        _startY = _y;
        _clearControls();
      case 'L':
        _x = ox + _number();
        _y = oy + _number();
        _path.lineTo(_x, _y);
        _clearControls();
      case 'H':
        _x = ox + _number();
        _path.lineTo(_x, _y);
        _clearControls();
      case 'V':
        _y = oy + _number();
        _path.lineTo(_x, _y);
        _clearControls();
      case 'C':
        final double x1 = ox + _number(), y1 = oy + _number();
        final double x2 = ox + _number(), y2 = oy + _number();
        _cubicTo(x1, y1, x2, y2, ox + _number(), oy + _number());
      case 'S':
        final double x1 = _lastCubicX == null ? _x : 2 * _x - _lastCubicX!;
        final double y1 = _lastCubicY == null ? _y : 2 * _y - _lastCubicY!;
        final double x2 = ox + _number(), y2 = oy + _number();
        _cubicTo(x1, y1, x2, y2, ox + _number(), oy + _number());
      case 'Q':
        final double x1 = ox + _number(), y1 = oy + _number();
        _quadTo(x1, y1, ox + _number(), oy + _number());
      case 'T':
        final double x1 = _lastQuadX == null ? _x : 2 * _x - _lastQuadX!;
        final double y1 = _lastQuadY == null ? _y : 2 * _y - _lastQuadY!;
        _quadTo(x1, y1, ox + _number(), oy + _number());
      case 'A':
        final double rx = _number().abs(), ry = _number().abs();
        final double rotation = _number();
        final bool largeArc = _flag();
        final bool sweep = _flag();
        final double x = ox + _number(), y = oy + _number();
        if (rx == 0 || ry == 0) {
          _path.lineTo(x, y); // SVG 规范：半径为 0 的弧退化成直线
        } else {
          // SVG 的 sweep=1 是 y 轴朝下坐标系里的顺时针，与 Flutter 的 clockwise 同向；
          // 半径不够连到终点时由 Skia 按 SVG 规范放大，这里不用自己算。
          _path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: sweep,
          );
        }
        _x = x;
        _y = y;
        _clearControls();
      case 'Z':
        _path.close();
        _x = _startX;
        _y = _startY;
        _clearControls();
    }
  }

  void _cubicTo(double x1, double y1, double x2, double y2, double x, double y) {
    _path.cubicTo(x1, y1, x2, y2, x, y);
    _x = x;
    _y = y;
    _lastCubicX = x2;
    _lastCubicY = y2;
    _lastQuadX = _lastQuadY = null;
  }

  void _quadTo(double x1, double y1, double x, double y) {
    _path.quadraticBezierTo(x1, y1, x, y);
    _x = x;
    _y = y;
    _lastQuadX = x1;
    _lastQuadY = y1;
    _lastCubicX = _lastCubicY = null;
  }

  void _clearControls() {
    _lastCubicX = _lastCubicY = _lastQuadX = _lastQuadY = null;
  }

  static bool _isCommand(String ch) => 'MmLlHhVvCcSsQqTtAaZz'.contains(ch);

  void _skipSeparators() {
    while (_pos < _src.length) {
      final String ch = _src[_pos];
      if (ch == ' ' || ch == ',' || ch == '\n' || ch == '\r' || ch == '\t') {
        _pos++;
      } else {
        break;
      }
    }
  }

  double _number() {
    _skipSeparators();
    final int start = _pos;
    if (_pos < _src.length && (_src[_pos] == '-' || _src[_pos] == '+')) _pos++;
    bool digits = false, dot = false;
    while (_pos < _src.length) {
      final int c = _src.codeUnitAt(_pos);
      if (c >= 0x30 && c <= 0x39) {
        digits = true;
        _pos++;
      } else if (c == 0x2E && !dot) {
        dot = true; // 第二个小数点开始下一个数（`1.5.5`）
        _pos++;
      } else {
        break;
      }
    }
    if (!digits) throw FormatException('expected a number', _src, start);
    if (_pos < _src.length && (_src[_pos] == 'e' || _src[_pos] == 'E')) {
      final int save = _pos;
      _pos++;
      if (_pos < _src.length && (_src[_pos] == '-' || _src[_pos] == '+')) _pos++;
      final int expStart = _pos;
      while (_pos < _src.length && _src.codeUnitAt(_pos) >= 0x30 && _src.codeUnitAt(_pos) <= 0x39) {
        _pos++;
      }
      if (_pos == expStart) _pos = save; // `e` 后面没有数字：不算指数，留给下一轮报错
    }
    final double? value = double.tryParse(_src.substring(start, _pos));
    if (value == null) throw FormatException('malformed number', _src, start);
    return value;
  }

  bool _flag() {
    _skipSeparators();
    if (_pos < _src.length && (_src[_pos] == '0' || _src[_pos] == '1')) {
      return _src[_pos++] == '1';
    }
    throw FormatException('expected an arc flag (0 or 1)', _src, _pos);
  }
}
