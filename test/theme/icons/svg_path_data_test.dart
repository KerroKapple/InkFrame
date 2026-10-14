// parseSvgPathData：SVG path 的 d 字符串 → dart:ui Path。
//
// 断言只量几何（getBounds / 轮廓长度），不比 Path 内部的命令序列——图标最终只关心
// 画出来的形状落在哪。
//
// getBounds 的口径要小心：dart:ui 文档说它可能按控制点算，而不是曲线的紧包围盒。
// 所以凡是「拆掉某段实现就该变红」的用例，形状都造成两种口径下结论一致：
// 要么拿等价的显式写法比 bounds（同一组控制点 ⇒ 两种口径都相等），
// 要么让被测的那个点成为路径在某个方向上唯一的极值点。
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/icons/svg_path_data.dart';

const double _eps = 0.01;

Rect _bounds(String d) => parseSvgPathData(d).getBounds();

/// 所有轮廓的长度之和；只有 moveTo、没有线段的轮廓贡献 0。
double _length(String d) => parseSvgPathData(d)
    .computeMetrics()
    .fold<double>(0, (double sum, PathMetric m) => sum + m.length);

void _expectRect(Rect actual, Rect expected, {String reason = ''}) {
  expect(actual.left, closeTo(expected.left, _eps), reason: 'left $reason');
  expect(actual.top, closeTo(expected.top, _eps), reason: 'top $reason');
  expect(actual.right, closeTo(expected.right, _eps), reason: 'right $reason');
  expect(actual.bottom, closeTo(expected.bottom, _eps), reason: 'bottom $reason');
}

void main() {
  group('直线命令 M / L / H / V / Z', () {
    test('绝对坐标', () {
      _expectRect(_bounds('M2 3L10 3V9H2Z'), const Rect.fromLTRB(2, 3, 10, 9));
    });

    test('相对坐标：每一步都从当前点算', () {
      _expectRect(_bounds('m1 1l4 0l0 4z'), const Rect.fromLTRB(1, 1, 5, 5));
      _expectRect(_bounds('m1 1h4v4h-4z'), const Rect.fromLTRB(1, 1, 5, 5));
    });

    test('M 之后多出的坐标对按 L 处理，而不是再 moveTo', () {
      _expectRect(_bounds('M0 0 10 0 10 10'), const Rect.fromLTRB(0, 0, 10, 10));
      // bounds 也会算上 moveTo 的点，只有长度能说明这两段真的连成了线。
      expect(_length('M0 0 10 0 10 10'), closeTo(20, _eps));
    });

    test('m 之后多出的坐标对按 l 处理（相对当前点）', () {
      // 若按绝对 L 处理会落到 (4,0)、(0,4)，bounds 变成 0,0,4,4。
      _expectRect(_bounds('m1 1 4 0 0 4'), const Rect.fromLTRB(1, 1, 5, 5));
      expect(_length('m1 1 4 0 0 4'), closeTo(8, _eps));
    });

    test('分隔符：逗号 / 换行 / 制表符与空格等价', () {
      _expectRect(
        _bounds('M2,3 L10,3\nV9\tH2 Z'),
        const Rect.fromLTRB(2, 3, 10, 9),
      );
    });

    test('Z 把当前点拉回子路径起点：其后的相对命令从起点算', () {
      // 起点 (5,5)，Z 之前停在 (10,10)。从起点算，l-5 0 落到 (0,5)；
      // 若 Z 没复位当前点，会落到 (5,10)，left 就停在 5。
      _expectRect(
        _bounds('M5 5L10 5L10 10Zl-5 0'),
        const Rect.fromLTRB(0, 5, 10, 10),
      );
      // m 同理：从起点 (5,5) 挪到 (0,5) 再画到 (1,6)；没复位会挪到 (5,10)、画到 (6,11)。
      _expectRect(
        _bounds('M5 5L10 5L10 10Zm-5 0l1 1'),
        const Rect.fromLTRB(0, 5, 10, 10),
      );
    });
  });

  group('数字的紧凑写法', () {
    test('第二个小数点开始下一个数：1.5.5 = 1.5 与 .5', () {
      _expectRect(_bounds('M0 0L1.5.5'), const Rect.fromLTRB(0, 0, 1.5, 0.5));
      _expectRect(_bounds('M0 0L.5.5'), const Rect.fromLTRB(0, 0, 0.5, 0.5));
    });

    test('负号开始下一个数：2-1 = 2 与 -1', () {
      _expectRect(_bounds('M0 0L2-1'), const Rect.fromLTRB(0, -1, 2, 0));
      _expectRect(_bounds('M0 0L-.5-.5'), const Rect.fromLTRB(-0.5, -0.5, 0, 0));
    });

    test('指数：1e1 = 10，5e-1 = 0.5，大写 E 也认', () {
      _expectRect(_bounds('M0 0L1e1 5'), const Rect.fromLTRB(0, 0, 10, 5));
      _expectRect(_bounds('M0 0L5e-1 1'), const Rect.fromLTRB(0, 0, 0.5, 1));
      _expectRect(_bounds('M0 0L1E1 2'), const Rect.fromLTRB(0, 0, 10, 2));
    });
  });

  group('三次曲线 C / S', () {
    test('S 的第一控制点 = 上一段第二控制点关于当前点的镜像（与显式 C 等价）', () {
      expect(
        _bounds('M0 0C0 10 10 10 10 0S20 -10 20 0'),
        _bounds('M0 0C0 10 10 10 10 0C10 -10 20 -10 20 0'),
      );
      // 这一组让镜像点 (10,10) 成为全路径唯一 y>0 的点：上一段整个在 y≤0，
      // S 段其余控制点都在 y=0 上。拿当前点 (10,0) 顶替镜像点，bottom 就塌成 0
      //（控制点口径下 bottom = 10，紧包围盒口径下 ≈ 4.44，都 > 4）。
      const String smooth = 'M0 0C0 -10 10 -10 10 0S20 0 20 0';
      expect(
        _bounds(smooth),
        _bounds('M0 0C0 -10 10 -10 10 0C10 10 20 0 20 0'),
      );
      expect(_bounds(smooth).bottom, greaterThan(4));
    });

    test('相对 s：镜像点同样从上一段的绝对控制点算，其余坐标相对当前点', () {
      expect(
        _bounds('M0 0c0 -10 10 -10 10 0s10 0 10 0'),
        _bounds('M0 0C0 -10 10 -10 10 0C10 10 20 0 20 0'),
      );
    });

    test('S 紧跟非三次曲线命令：第一控制点就是当前点', () {
      // L 之后没有可镜像的点：S 段四个控制点都在 y=0 上，bottom 恰为 0。
      // 若 L 没清掉上一段 C 的控制点 (10,-10)，镜像会落在 (30,10)，bottom 就不再是 0。
      const String afterLine = 'M0 0C0 -10 10 -10 10 0L20 0S30 0 30 0';
      expect(
        _bounds(afterLine),
        _bounds('M0 0C0 -10 10 -10 10 0L20 0C20 0 30 0 30 0'),
      );
      expect(_bounds(afterLine).bottom, closeTo(0, _eps));
      // Q 之后同理：S 不拿二次曲线的控制点 (5,10) 做镜像，否则会冒出 y<0 的 (15,-10)。
      const String afterQuad = 'M0 0Q5 10 10 0S20 0 20 0';
      expect(_bounds(afterQuad), _bounds('M0 0Q5 10 10 0C10 0 20 0 20 0'));
      expect(_bounds(afterQuad).top, closeTo(0, _eps));
    });
  });

  group('二次曲线 Q / T', () {
    test('T 的控制点 = 上一段控制点关于当前点的镜像（与显式 Q 等价）', () {
      // 镜像点 (15,-10) 是全路径唯一 y<0 的点：拿当前点顶替它，T 段就成了一条平线，
      // top 塌成 0（控制点口径下 top = -10，紧包围盒口径下 = -5，都 < -4）。
      const String smooth = 'M0 0Q5 10 10 0T20 0';
      expect(_bounds(smooth), _bounds('M0 0Q5 10 10 0Q15 -10 20 0'));
      expect(_bounds(smooth).top, lessThan(-4));
    });

    test('连续 T：每一段镜像的都是上一段（含 T 推出来的）控制点', () {
      expect(
        _bounds('M0 0Q5 10 10 0T20 0T30 0'),
        _bounds('M0 0Q5 10 10 0Q15 -10 20 0Q25 10 30 0'),
      );
    });

    test('相对 t', () {
      expect(
        _bounds('M0 0q5 10 10 0t10 0'),
        _bounds('M0 0Q5 10 10 0Q15 -10 20 0'),
      );
    });

    test('T 紧跟非二次曲线命令：控制点就是当前点', () {
      // C 之后：若 T 拿三次曲线的控制点 (10,-10) 去镜像，会得到 (10,10)，bottom 不再是 0。
      const String afterCubic = 'M0 0C0 -10 10 -10 10 0T20 0';
      expect(
        _bounds(afterCubic),
        _bounds('M0 0C0 -10 10 -10 10 0Q10 0 20 0'),
      );
      expect(_bounds(afterCubic).bottom, closeTo(0, _eps));
      _expectRect(_bounds('M0 0L10 0T20 0'), const Rect.fromLTRB(0, 0, 20, 0));
    });
  });

  group('弧线 A', () {
    test('两段半圆拼成整圆', () {
      _expectRect(
        _bounds('M0 10a10 10 0 1 0 20 0a10 10 0 1 0 -20 0z'),
        const Rect.fromLTRB(0, 0, 20, 20),
      );
    });

    test('sweep=1 是 y 轴朝下坐标系里的顺时针：从左端点出发走上半圆', () {
      // 圆心 (10,0)。顺时针从 9 点钟经 12 点钟 (10,-10) 到 3 点钟；
      // 逆时针则经 6 点钟 (10,10)。sweep 与 clockwise 的对应一旦接反，两条同时红。
      _expectRect(
        _bounds('M0 0A10 10 0 0 1 20 0'),
        const Rect.fromLTRB(0, -10, 20, 0),
      );
      _expectRect(
        _bounds('M0 0A10 10 0 0 0 20 0'),
        const Rect.fromLTRB(0, 0, 20, 10),
      );
    });

    test('large-arc：同一对端点与半径，小弧走近路、大弧绕远路', () {
      // 端点 (0,0) → (10,10)，半径 10，顺时针：小弧圆心 (0,10)，只占 0..10 见方；
      // 大弧圆心 (10,0)，绕 270° 经 (10,-10)、(20,0) 才到终点。
      _expectRect(
        _bounds('M0 0A10 10 0 0 1 10 10'),
        const Rect.fromLTRB(0, 0, 10, 10),
      );
      _expectRect(
        _bounds('M0 0A10 10 0 1 1 10 10'),
        const Rect.fromLTRB(0, -10, 20, 10),
      );
    });

    test('标志位不带分隔：a10 10 0 0120 0 = large 0、sweep 1、终点 (20,0)', () {
      expect(_bounds('M0 0a10 10 0 0120 0'), _bounds('M0 0A10 10 0 0 1 20 0'));
      _expectRect(
        _bounds('M0 0a10 10 0 0120 0'),
        const Rect.fromLTRB(0, -10, 20, 0),
      );
    });

    test('任一半径为 0 的弧退化成直线（SVG 规范）', () {
      _expectRect(
        _bounds('M0 0A0 5 0 0 1 10 0'),
        const Rect.fromLTRB(0, 0, 10, 0),
      );
      _expectRect(
        _bounds('M0 0a5 0 0 0 1 10 0'),
        const Rect.fromLTRB(0, 0, 10, 0),
      );
    });
  });

  group('坏数据直接抛 FormatException', () {
    for (final String bad in <String>[
      '5 5', // 不以命令开头
      'M1', // 缺 y
      'M0 0L1', // L 缺 y
      'M0 0Z 1', // Z 后面跟了数字
      'M0 0A1 1 0 2 0 1 1', // 标志位只能是 0 / 1
      'M0 0X1 1', // 不认识的命令字母
      'M- 0', // 只有符号、没有数字
    ]) {
      test('「$bad」', () {
        expect(() => parseSvgPathData(bad), throwsA(isA<FormatException>()));
      });
    }
  });

  test('空串 / 纯分隔符 → 空路径', () {
    expect(_bounds(''), Rect.zero);
    expect(parseSvgPathData('').computeMetrics(), isEmpty);
    expect(parseSvgPathData(' ,\n\t').computeMetrics(), isEmpty);
  });
}
