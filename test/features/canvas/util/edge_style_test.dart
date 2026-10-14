// 连线外观判据（util/edge_style.dart）：画布重设计稿 › 画布交互那张表逐格钉死。
//
// 表的要点是「颜色之外还靠线型和标签区分」：任何一格塌回「全是同一种灰线」，
// 这里当场红。当前链路只换颜色、不换线型 / 线宽 / 标签，也在这里锁。
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/util/edge_style.dart';

void main() {
  group('resolveEdgeStyle：语义 → 外观（不在当前链路）', () {
    test('叙事线：实线 2.0、叙事色、常规箭头、不标', () {
      final EdgeStyle s = resolveEdgeStyle(type: EdgeType.narrative);
      expect(s.colorSlot, EdgeColorSlot.narrative);
      expect(s.strokeWidth, 2.0);
      expect(s.dash, isNull, reason: '叙事线是实线');
      expect(s.dotted, isFalse);
      expect(s.arrow, EdgeArrow.regular);
      expect(s.label, EdgeLabelKind.none);
    });

    test('数据 · 首帧：实线 1.75、首帧色、常规箭头、标「首帧」', () {
      final EdgeStyle s =
          resolveEdgeStyle(type: EdgeType.data, role: EdgeRole.firstFrame);
      expect(s.colorSlot, EdgeColorSlot.firstFrame);
      expect(s.strokeWidth, 1.75);
      expect(s.dash, isNull);
      expect(s.dotted, isFalse);
      expect(s.arrow, EdgeArrow.regular);
      expect(s.label, EdgeLabelKind.firstFrame);
    });

    test('数据 · 尾帧：实线 1.75、尾帧色、常规箭头、标「尾帧」', () {
      final EdgeStyle s =
          resolveEdgeStyle(type: EdgeType.data, role: EdgeRole.lastFrame);
      expect(s.colorSlot, EdgeColorSlot.lastFrame);
      expect(s.strokeWidth, 1.75);
      expect(s.dash, isNull);
      expect(s.dotted, isFalse);
      expect(s.arrow, EdgeArrow.regular);
      expect(s.label, EdgeLabelKind.lastFrame);
    });

    test('数据 · 参考：虚线 5 / 4、1.5、参考色、常规箭头、标「参考」', () {
      final EdgeStyle s =
          resolveEdgeStyle(type: EdgeType.data, role: EdgeRole.reference);
      expect(s.colorSlot, EdgeColorSlot.reference);
      expect(s.strokeWidth, 1.5);
      expect(s.dash, (on: 5.0, off: 4.0));
      expect(s.dotted, isFalse, reason: '参考线是虚线，不是点线');
      expect(s.arrow, EdgeArrow.regular);
      expect(s.label, EdgeLabelKind.reference);
    });

    test('data 线缺省 role = 参考', () {
      expect(
        resolveEdgeStyle(type: EdgeType.data),
        resolveEdgeStyle(type: EdgeType.data, role: EdgeRole.reference),
      );
    });

    test('产出线（generation_source）：点线 1.5 / 3.5 圆头、1.25、产出色、小箭头、不标', () {
      final EdgeStyle s = resolveEdgeStyle(type: EdgeType.generationSource);
      expect(s.colorSlot, EdgeColorSlot.lineage);
      expect(s.strokeWidth, 1.25);
      expect(s.dash, (on: 1.5, off: 3.5));
      expect(s.dotted, isTrue, reason: '点线靠圆头才显成点');
      expect(s.arrow, EdgeArrow.small);
      expect(s.label, EdgeLabelKind.none);
    });

    test('非 data 线不看 role（库里恒为 reference，传什么都一样）', () {
      for (final EdgeType t in <EdgeType>[
        EdgeType.narrative,
        EdgeType.generationSource,
      ]) {
        final EdgeStyle base = resolveEdgeStyle(type: t);
        for (final EdgeRole r in EdgeRole.values) {
          expect(resolveEdgeStyle(type: t, role: r), base, reason: '$t / $r');
        }
      }
    });

    test('五种语义两两可分：颜色槽各不相同', () {
      final Set<EdgeColorSlot> slots = <EdgeColorSlot>{
        resolveEdgeStyle(type: EdgeType.narrative).colorSlot,
        resolveEdgeStyle(type: EdgeType.generationSource).colorSlot,
        for (final EdgeRole r in EdgeRole.values)
          resolveEdgeStyle(type: EdgeType.data, role: r).colorSlot,
      };
      expect(slots, hasLength(5));
      expect(slots, isNot(contains(EdgeColorSlot.accent)));
    });

    test('箭头：小号比常规短、窄', () {
      expect(EdgeArrow.small.length, lessThan(EdgeArrow.regular.length));
      expect(EdgeArrow.small.halfWidth, lessThan(EdgeArrow.regular.halfWidth));
    });
  });

  group('当前链路：只换颜色，线型 / 线宽 / 箭头 / 标签照旧', () {
    final List<(EdgeType, EdgeRole)> all = <(EdgeType, EdgeRole)>[
      (EdgeType.narrative, EdgeRole.reference),
      (EdgeType.generationSource, EdgeRole.reference),
      (EdgeType.data, EdgeRole.firstFrame),
      (EdgeType.data, EdgeRole.lastFrame),
      (EdgeType.data, EdgeRole.reference),
    ];

    for (final (EdgeType type, EdgeRole role) in all) {
      test('${type.name} / ${role.name}', () {
        final EdgeStyle off = resolveEdgeStyle(type: type, role: role);
        final EdgeStyle on =
            resolveEdgeStyle(type: type, role: role, onChain: true);
        expect(on.colorSlot, EdgeColorSlot.accent);
        expect(on.strokeWidth, off.strokeWidth);
        expect(on.dash, off.dash);
        expect(on.dotted, off.dotted);
        expect(on.arrow, off.arrow);
        expect(on.label, off.label);
      });
    }
  });

  group('EdgePalette', () {
    const EdgePalette palette = EdgePalette(
      narrative: Color(0xFF010101),
      lineage: Color(0xFF020202),
      firstFrame: Color(0xFF030303),
      lastFrame: Color(0xFF040404),
      reference: Color(0xFF050505),
      accent: Color(0xFF060606),
      chipFill: Color(0xFF070707),
    );

    test('颜色槽一一落到各自的颜色', () {
      expect(palette.colorOf(EdgeColorSlot.narrative), palette.narrative);
      expect(palette.colorOf(EdgeColorSlot.lineage), palette.lineage);
      expect(palette.colorOf(EdgeColorSlot.firstFrame), palette.firstFrame);
      expect(palette.colorOf(EdgeColorSlot.lastFrame), palette.lastFrame);
      expect(palette.colorOf(EdgeColorSlot.reference), palette.reference);
      expect(palette.colorOf(EdgeColorSlot.accent), palette.accent);
    });

    test('值相等：任一颜色不同就不等（EdgePainter.shouldRepaint 靠它）', () {
      const EdgePalette same = EdgePalette(
        narrative: Color(0xFF010101),
        lineage: Color(0xFF020202),
        firstFrame: Color(0xFF030303),
        lastFrame: Color(0xFF040404),
        reference: Color(0xFF050505),
        accent: Color(0xFF060606),
        chipFill: Color(0xFF070707),
      );
      expect(same, palette);
      expect(same.hashCode, palette.hashCode);
      const EdgePalette otherChip = EdgePalette(
        narrative: Color(0xFF010101),
        lineage: Color(0xFF020202),
        firstFrame: Color(0xFF030303),
        lastFrame: Color(0xFF040404),
        reference: Color(0xFF050505),
        accent: Color(0xFF060606),
        chipFill: Color(0xFF080808),
      );
      expect(otherChip, isNot(palette));
    });
  });
}
