// NodeCard 三态 golden test：idle / selected / link-source。
//
// 视觉密度高，token 体系（amber accent / surface2 / borderSubtle / brand）全覆盖。
// 后续 Inspector / EmptyState 增量加 golden 时复用 pumpGoldenScene。
//
// 当前状态：skip = true（_kSkipUntilLinuxBaseline）。
// 原因：golden 基线必须在 canonical 平台（CI Linux runner）首次 --update-goldens 生成，
// 跨平台字体渲染差异会让 Windows / macOS 本地生成的 baseline 在 Linux CI 上失败。
// 解锁：用 workflow_dispatch 在 Linux runner 跑一次 --update-goldens 并提交结果，
// 然后移除 skip 常量即可。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';

import '../../../_harness/golden_scaffold.dart';

// true = 跳过；解锁条件见文件顶部说明。
const bool _kSkipUntilLinuxBaseline = true;

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
  testWidgets(
    'NodeCard idle: 默认边框 + surface2 背景',
    (tester) async {
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
    },
    skip: _kSkipUntilLinuxBaseline,
  );

  testWidgets(
    'NodeCard selected: accent 边框 + elevated shadow + link/delete 锚点',
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
    },
    skip: _kSkipUntilLinuxBaseline,
  );

  testWidgets(
    'NodeCard link source: brand 粗边框 + elevated shadow',
    (tester) async {
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
    },
    skip: _kSkipUntilLinuxBaseline,
  );
}
