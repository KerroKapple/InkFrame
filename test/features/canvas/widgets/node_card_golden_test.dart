// NodeCard 三态 golden test：idle / selected / link-source。
//
// 视觉密度高，token 体系（amber accent / surface2 / borderSubtle / brand）全覆盖。
// 后续 Inspector / EmptyState 增量加 golden 时复用 pumpGoldenScene。
//
// 当前状态：基线存在才跑（_goldensPresent），否则 skip——无需手动改常量。
// 基线必须在 canonical 平台（CI ubuntu runner）用 `flutter test --update-goldens` 生成并提交；
// 跨平台字体光栅化差异会让本地 Windows/macOS 生成的 baseline 在 CI 上 false-fail。
// 生成方式：手动触发 .github/workflows/update-goldens.yml（ubuntu 上 --update-goldens 后自动提交 PNG）。
// 提交基线后测试自动激活，无需再改代码。
//
// @Tags(['golden'])：golden 像素基线锁定 canonical 平台（CI ubuntu）。跨平台 smoke
// （mac/win，smoke.yml）以 --exclude-tags golden 排除，否则字体光栅化差异 false-fail。
// ubuntu 的 golden job 按文件 glob 跑、test job 跑全量，均不依赖本 tag。
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';

import '../../../_harness/golden_scaffold.dart';

// 基线存在才跑；缺基线时 skip（--update-goldens 模式下强制运行以生成基线）。详见文件顶部。
final bool _goldensPresent = File(
  'test/features/canvas/widgets/goldens/node_card_idle.png',
).existsSync();
final bool _skipGolden = !_goldensPresent && !autoUpdateGoldenFiles;

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
          onDragEnd: (_) {},
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
    skip: _skipGolden,
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
          onDragEnd: (_) {},
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
    skip: _skipGolden,
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
          onDragEnd: (_) {},
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
    skip: _skipGolden,
  );
}
