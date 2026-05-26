// NodeCard 三态 golden test：idle / selected / link-source。
//
// 视觉密度高，token 体系（amber accent / surface2 / borderSubtle / brand）全覆盖。
// 后续 Inspector / EmptyState 增量加 golden 时复用 pumpGoldenScene。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/services/file_resolver_service.dart';

import '../../../_harness/golden_scaffold.dart';

class _StubFileResolver implements FileResolverService {
  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File(relativePath);

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      source.path;

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory.systemTemp;
}

const CanvasNode _sample = CanvasNode(
  id: 'n1',
  label: 'Mountains at dawn',
  type: CanvasNodeType.image,
  typeConfig: <String, Object?>{
    'prompt': 'an ink wash painting of mountains at dawn',
  },
  size: Size(220, 180),
);

const Size _surface = Size(320, 260);

void main() {
  testWidgets('NodeCard idle: 默认边框 + surface2 背景', (tester) async {
    await pumpGoldenScene(
      tester,
      NodeCard(
        node: _sample,
        selected: false,
        onTap: () {},
        onPanUpdate: (_) {},
      ),
      size: _surface,
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(_StubFileResolver()),
      ],
    );
    await expectLater(
      find.byType(NodeCard),
      matchesGoldenFile('goldens/node_card_idle.png'),
    );
  });

  testWidgets('NodeCard selected: accent 边框 + elevated shadow + link/delete 锚点',
      (tester) async {
    await pumpGoldenScene(
      tester,
      NodeCard(
        node: _sample,
        selected: true,
        onTap: () {},
        onPanUpdate: (_) {},
        onStartLink: () {},
        onDelete: () {},
      ),
      size: _surface,
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(_StubFileResolver()),
      ],
    );
    await expectLater(
      find.byType(NodeCard),
      matchesGoldenFile('goldens/node_card_selected.png'),
    );
  });

  testWidgets('NodeCard link source: brand 粗边框 + elevated shadow', (tester) async {
    await pumpGoldenScene(
      tester,
      NodeCard(
        node: _sample,
        selected: true,
        isLinkSource: true,
        onTap: () {},
        onPanUpdate: (_) {},
      ),
      size: _surface,
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(_StubFileResolver()),
      ],
    );
    await expectLater(
      find.byType(NodeCard),
      matchesGoldenFile('goldens/node_card_link_source.png'),
    );
  });
}
