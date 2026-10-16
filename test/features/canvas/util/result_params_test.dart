// resultParamsOf / resultSourceNode：产物检查器「生成参数」的取值口径。
//   - 供应商 / 分辨率 / 画幅 / 运镜 / 提示词取自来源 config；
//   - 尺寸 / 种子取自产物自己；时长产物优先、config 兜底；
//   - 孤儿产物（来源已删）只剩产物自己那几项。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/result_params.dart';

void main() {
  const CanvasNode source = CanvasNode(
    id: 'cfg',
    label: '',
    type: CanvasNodeType.video,
    typeConfig: <String, Object?>{
      'provider_id': 'wanx-t2v',
      'resolution': 'p1080',
      'aspect_ratio': 'r16x9',
      'camera': 'orbit',
      'duration_ms': 10000,
      'prompt': '  dusk over the harbor ',
      'seed': 7, // config 上的种子不算：产物落盘时写的才是这一次真正用到的
    },
  );
  const CanvasNode result = CanvasNode(
    id: 'res',
    label: '',
    type: CanvasNodeType.video,
    role: NodeRole.result,
    sourceNodeId: 'cfg',
    typeConfig: <String, Object?>{
      'video_url': 'videos/j.mp4',
      'width': 1280,
      'height': 720,
      'duration_ms': 5040,
      'seed': 41207,
    },
  );

  test('resultSourceNode：按 sourceNodeId 找来源；config 节点 / 来源不在 ⇒ null', () {
    expect(resultSourceNode(result, const <CanvasNode>[source, result]), same(source));
    expect(resultSourceNode(result, const <CanvasNode>[result]), isNull);
    expect(resultSourceNode(source, const <CanvasNode>[source, result]), isNull);
  });

  test('来源在：参数取来源 config + 产物自己的尺寸 / 种子 / 时长', () {
    final ResultParams p = resultParamsOf(result, source);
    expect(p.providerId, 'wanx-t2v');
    expect(p.resolution, 'p1080');
    expect(p.aspectRatio, AspectRatio.r16x9);
    expect(p.camera, CameraMovement.orbit);
    expect(p.prompt, 'dusk over the harbor');
    expect(p.hasDimensions, isTrue);
    expect(p.width, 1280);
    expect(p.height, 720);
    expect(p.durationMs, 5040);
    expect(p.seed, 41207);
  });

  test('产物没有时长 ⇒ 退回 config 的时长', () {
    const CanvasNode bare = CanvasNode(
      id: 'res',
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      sourceNodeId: 'cfg',
    );
    expect(resultParamsOf(bare, source).durationMs, 10000);
    expect(resultParamsOf(bare, source).seed, isNull);
  });

  test('孤儿产物：只剩产物自己那几项', () {
    final ResultParams p = resultParamsOf(result, null);
    expect(p.providerId, isNull);
    expect(p.prompt, isNull);
    expect(p.camera, isNull);
    expect(p.aspectRatio, isNull);
    expect(p.width, 1280);
    expect(p.durationMs, 5040);
    expect(p.seed, 41207);
  });
}
