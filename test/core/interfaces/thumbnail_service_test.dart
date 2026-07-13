// VideoProbeResult.fromProbe 纯映射单测（media_kit player.state 归一逻辑的可测种子）。
//
// media_kit 的 Player 需原生库、headless 下会挂（TD-003），故把"原始时长/宽/高 →
// VideoProbeResult"这段纯逻辑抽成 fromProbe 工厂在此直接测，不触碰真实 player。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/thumbnail_service.dart';

void main() {
  final thumb = File('thumb.jpg');

  group('VideoProbeResult.fromProbe', () {
    test('全部可得 → 元数据填充；thumbnail 保留', () {
      final r = VideoProbeResult.fromProbe(
        thumbnail: thumb,
        duration: const Duration(milliseconds: 5000),
        width: 1920,
        height: 1080,
      );
      expect(r.thumbnail, thumb);
      expect(r.durationMs, 5000);
      expect(r.width, 1920);
      expect(r.height, 1080);
    });

    test('全部 null → 元数据全 null（绝不臆造）', () {
      final r = VideoProbeResult.fromProbe(thumbnail: thumb);
      expect(r.thumbnail, thumb);
      expect(r.durationMs, isNull);
      expect(r.width, isNull);
      expect(r.height, isNull);
    });

    test('零值（未解码占位）→ 归一为 null', () {
      final r = VideoProbeResult.fromProbe(
        thumbnail: thumb,
        duration: Duration.zero,
        width: 0,
        height: 0,
      );
      expect(r.durationMs, isNull);
      expect(r.width, isNull);
      expect(r.height, isNull);
    });

    test('负值（异常探针）→ 归一为 null', () {
      final r = VideoProbeResult.fromProbe(
        thumbnail: thumb,
        duration: const Duration(milliseconds: -1),
        width: -1,
        height: -1,
      );
      expect(r.durationMs, isNull);
      expect(r.width, isNull);
      expect(r.height, isNull);
    });

    test('部分可得 → 仅可得项填充，其余 null', () {
      final r = VideoProbeResult.fromProbe(
        thumbnail: thumb,
        duration: const Duration(milliseconds: 3200),
        width: 1280,
      );
      expect(r.durationMs, 3200);
      expect(r.width, 1280);
      expect(r.height, isNull);
    });
  });

  group('VideoProbeResult 直接构造', () {
    test('保留传入值', () {
      final r = VideoProbeResult(
        thumbnail: thumb,
        durationMs: 42,
        width: 7,
        height: 9,
      );
      expect(r.thumbnail, thumb);
      expect(r.durationMs, 42);
      expect(r.width, 7);
      expect(r.height, 9);
    });
  });
}
