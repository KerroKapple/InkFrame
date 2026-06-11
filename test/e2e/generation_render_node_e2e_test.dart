// E2E 主链路渲染支（DoD-5 支2）：节点渲染"已落盘产物"。
//
// 与 generation_pipeline_e2e_test.dart 共同覆盖 生成→落盘→渲染：
//   支1 验证 落盘 + type_config.image_url 持久化；
//   本支接力：给定一个已落盘产物（真实 PNG 写在临时 canvas 目录）+ 一个带相对
//   image_url 的 result 节点，NodeCard 经真实 DefaultFileResolverService 把相对路径
//   解析为绝对路径并渲染 Image.file。
//
// 用真实 FileResolverService（非 stub）确保"相对→绝对"这段链路是真装配。
// 断言落在 Image.file 的目标绝对路径 == 落盘文件绝对路径（链路闭环的关键不变量）。
// 注：Image.file 的异步解码/绘制在 test 环境不稳定（见 node_card_test.dart 注释），
//     故断言 Image widget 存在 + 其 FileImage.file 指向落盘绝对路径，不依赖解码完成。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:path/path.dart' as p;

import '../_harness/test_app.dart';

// 最小合法 1x1 PNG（透明像素），让 Image.file 真有可解码字节。
final Uint8List _kPng1x1 = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9c, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
]);

void main() {
  const projectId = 'proj-render';
  const canvasId = 'canvas-render';
  const relPath = 'images/job-render-1-0.png';

  late Directory tmp;
  late DefaultFileResolverService fileResolver;
  late File landed;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('ink_e2e_render_');
    fileResolver = DefaultFileResolverService(DefaultAppPaths.forRoot(tmp));
    // 模拟上一支已落盘：真把 PNG 写到 canvas/images 下。
    landed = fileResolver.resolve(
      projectId: projectId,
      canvasId: canvasId,
      relativePath: relPath,
    );
    await landed.parent.create(recursive: true);
    await landed.writeAsBytes(_kPng1x1);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets(
    'result 节点带已落盘 image_url → NodeCard 经真实 FileResolver 渲染 Image.file（绝对路径闭环）',
    (tester) async {
      // result 节点持有相对 image_url（即上一支写入 type_config 的值）。
      const node = CanvasNode(
        id: 'render-1',
        label: '',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        projectId: projectId,
        canvasId: canvasId,
        typeConfig: <String, Object?>{'image_url': relPath},
      );

      await pumpInkApp(
        tester,
        Scaffold(
          body: Center(
            child: NodeCard(
              node: node,
              selected: false,
              onTap: () {},
              onPanUpdate: (_) {},
            ),
          ),
        ),
        overrides: [
          // 真实 resolver（指向临时根），不是 stub —— 验证相对→绝对的真链路。
          fileResolverServiceProvider.overrideWithValue(fileResolver),
        ],
      );
      // 不 pumpAndSettle：Image.file 异步解码在 test 环境不稳定，pump 一帧即可拿到
      // 已挂载的 Image widget（其 provider 在 build 时即确定）。
      await tester.pump();

      // 渲染出 Image widget（而非 "等待生成" / "图像文件缺失" 占位）。
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget,
          reason: '已落盘产物的 result 节点应渲染 Image，而非占位');
      expect(find.text('Waiting for generation'), findsNothing);
      expect(find.text('Image file missing'), findsNothing);

      // 关键链路不变量：Image 的 FileImage 目标绝对路径 == 落盘文件绝对路径。
      final image = tester.widget<Image>(imageFinder);
      final provider = image.image;
      expect(provider, isA<FileImage>());
      final resolvedPath = (provider as FileImage).file.path;
      expect(p.equals(resolvedPath, landed.path), isTrue,
          reason: 'FileResolver 必须把相对 image_url 解析回落盘绝对路径');
      // 绝对路径确实指向真实存在的文件（链路端到端可读）。
      expect(File(resolvedPath).existsSync(), isTrue);
    },
  );
}
