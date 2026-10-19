// estimateNodeCost / formatNodeCost / sumNodeCosts / resolutionShortLabel：
// 检查器「预估费用」与提示词条金额共用的唯一算法（TakesCost 稿「花费预告」）。
//
// 钉的几件：自定义接口（perCall 0）写「—」不写 $0.00；取参口径与 GenerationController 同
// （缺 resolution 按 p1080、视频不吃 batch_size）；缺时长取供应商第一档、仍无 ⇒ 价格未知；
// 本地未落库的值（pending）盖在 typeConfig 上；供应商解析链与「生成」判 Key 同一条。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/models/provider_protocol_template.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/generation/services/node_cost.dart';
import 'package:inkframe/providers/wanx_i2v_provider.dart';
import 'package:inkframe/providers/wanx_image_provider.dart';

final ProviderCapabilities _custom = kOpenAIImageTemplateCapabilities.copyWith(
  providerId: 'custom:acme',
  displayName: 'Acme',
);

/// 第二个图像供应商：单价 0.5，用来区分「用的是谁的价目」。
final ProviderCapabilities _pricey = kWanxImageCapabilities.copyWith(
  providerId: 'pricey',
  costModel: const CostModel.perCall(usdPerCall: 0.5),
);

CanvasNode _image(Map<String, Object?> tc, {NodeRole role = NodeRole.config}) => CanvasNode(
      id: 'n1',
      label: 'Shot',
      type: CanvasNodeType.image,
      role: role,
      typeConfig: tc,
    );

CanvasNode _video(Map<String, Object?> tc) => CanvasNode(
      id: 'n1',
      label: 'Clip',
      type: CanvasNodeType.video,
      typeConfig: tc,
    );

void main() {
  test('自定义接口（perCall 0）→ usd 为 null、unknown=customEndpoint、formatNodeCost 是 —', () {
    final NodeCostEstimate? e = estimateNodeCost(
      node: _image(<String, Object?>{'provider_id': 'custom:acme'}),
      capabilities: <ProviderCapabilities>[_custom],
    );

    expect(e, isNotNull);
    expect(e!.usd, isNull);
    expect(e.unknown, NodeCostUnknown.customEndpoint);
    expect(formatNodeCost(e), '—');
    expect(formatNodeCost(e), isNot(r'$0.00'));
  });

  test(r'万相图像 batch 4 → 0.128，formatNodeCost=$0.13', () {
    final NodeCostEstimate e = estimateNodeCost(
      node: _image(<String, Object?>{'provider_id': 'wanx-image', 'batch_size': 4}),
      capabilities: <ProviderCapabilities>[kWanxImageCapabilities],
    )!;

    expect(e.usd, closeTo(0.128, 1e-9));
    expect(e.batch, 4);
    expect(e.unknown, isNull);
    expect(e.costModel, kWanxImageCapabilities.costModel);
    expect(formatNodeCost(e), r'$0.13');
  });

  test('video 不吃 batch_size', () {
    final NodeCostEstimate e = estimateNodeCost(
      node: _video(<String, Object?>{
        'provider_id': 'wanx-i2v',
        'duration_ms': 5000,
        'batch_size': 4,
      }),
      capabilities: <ProviderCapabilities>[kWanxI2VCapabilities],
    )!;

    expect(e.batch, 1, reason: 'GenerationController 对视频强制单张，估算也得是 1');
    expect(e.isVideo, isTrue);
    expect(e.usd, closeTo(1.5, 1e-9));
  });

  test('视频 5 秒 720p → 0.75，resolution=p720', () {
    final NodeCostEstimate e = estimateNodeCost(
      node: _video(<String, Object?>{
        'provider_id': 'wanx-i2v',
        'duration_ms': 5000,
        'resolution': 'p720',
      }),
      capabilities: <ProviderCapabilities>[kWanxI2VCapabilities],
    )!;

    expect(e.resolution, Resolution.p720);
    expect(e.durationSeconds, 5);
    expect(e.usd, closeTo(0.75, 1e-9));
    expect(formatNodeCost(e), r'$0.75');
  });

  test('缺 resolution 按 p1080（与 GenerationController 同）', () {
    // wanx-i2v 的 supportedResolutions 第一项是 p720：按「第一项」算就会是 0.75。
    final NodeCostEstimate e = estimateNodeCost(
      node: _video(<String, Object?>{'provider_id': 'wanx-i2v', 'duration_ms': 5000}),
      capabilities: <ProviderCapabilities>[kWanxI2VCapabilities],
    )!;

    expect(e.resolution, Resolution.p1080);
    expect(e.usd, closeTo(1.5, 1e-9));
  });

  test('缺 duration_ms 取 supportedDurations.first；仍无 → noDuration', () {
    final NodeCostEstimate first = estimateNodeCost(
      node: _video(<String, Object?>{'provider_id': 'wanx-i2v'}),
      capabilities: <ProviderCapabilities>[kWanxI2VCapabilities],
    )!;
    expect(first.durationSeconds, 5);
    expect(first.usd, closeTo(1.5, 1e-9));

    final NodeCostEstimate none = estimateNodeCost(
      node: _video(<String, Object?>{'provider_id': 'wanx-i2v'}),
      capabilities: <ProviderCapabilities>[
        kWanxI2VCapabilities.copyWith(supportedDurations: const <int>[]),
      ],
    )!;
    expect(none.durationSeconds, 0);
    expect(none.usd, isNull, reason: r'按秒计价、时长 0：算出来的 $0.00 是假的');
    expect(none.unknown, NodeCostUnknown.noDuration);
    expect(formatNodeCost(none), '—');
  });

  test('pending 盖在 typeConfig 上', () {
    // 节点存的是万相（0.032），检查器本地刚换成 pricey（0.5）还没落库。
    final NodeCostEstimate e = estimateNodeCost(
      node: _image(<String, Object?>{'provider_id': 'wanx-image'}),
      capabilities: <ProviderCapabilities>[kWanxImageCapabilities, _pricey],
      pending: const <String, Object?>{'provider_id': 'pricey'},
    )!;
    expect(e.providerId, 'pricey');
    expect(e.usd, closeTo(0.5, 1e-9));

    // 视频检查器本地改了时长：5 秒 → 10 秒。
    final NodeCostEstimate v = estimateNodeCost(
      node: _video(<String, Object?>{'provider_id': 'wanx-i2v', 'duration_ms': 5000}),
      capabilities: <ProviderCapabilities>[kWanxI2VCapabilities],
      pending: const <String, Object?>{'duration_ms': 10000},
    )!;
    expect(v.durationSeconds, 10);
    expect(v.usd, closeTo(3.0, 1e-9));

    // 提示词条打字：字数取 pending 的 prompt（去首尾空白）。
    final NodeCostEstimate p = estimateNodeCost(
      node: _image(<String, Object?>{'provider_id': 'wanx-image', 'prompt': 'a'}),
      capabilities: <ProviderCapabilities>[kWanxImageCapabilities],
      pending: const <String, Object?>{'prompt': '  a cat  '},
    )!;
    expect(p.promptChars, 5);
  });

  test('供应商解析链：已存 > 上次使用 > 候选第一个', () {
    final List<ProviderCapabilities> caps = <ProviderCapabilities>[kWanxImageCapabilities, _pricey];

    expect(
      estimateNodeCost(
        node: _image(<String, Object?>{'provider_id': 'pricey'}),
        capabilities: caps,
        lastUsedProviderId: 'wanx-image',
      )!.providerId,
      'pricey',
      reason: '节点已存的优先',
    );
    expect(
      estimateNodeCost(
        node: _image(const <String, Object?>{}),
        capabilities: caps,
        lastUsedProviderId: 'pricey',
      )!.providerId,
      'pricey',
      reason: '没存过：用上次使用的',
    );
    expect(
      estimateNodeCost(
        node: _image(const <String, Object?>{}),
        capabilities: caps,
        lastUsedProviderId: 'gone',
      )!.providerId,
      'wanx-image',
      reason: '上次使用的已不在候选里：候选第一个',
    );
  });

  test('供应商已不在列表 → providerMissing', () {
    final NodeCostEstimate e = estimateNodeCost(
      node: _image(<String, Object?>{'provider_id': 'custom:deleted'}),
      capabilities: <ProviderCapabilities>[kWanxImageCapabilities],
    )!;

    expect(e.providerId, 'custom:deleted');
    expect(e.usd, isNull);
    expect(e.unknown, NodeCostUnknown.providerMissing);
    expect(e.costModel, isNull);
    expect(formatNodeCost(e), '—');
  });

  test('非配置节点 / text → null', () {
    final List<ProviderCapabilities> caps = <ProviderCapabilities>[kWanxImageCapabilities];

    expect(
      estimateNodeCost(
        node: _image(<String, Object?>{'provider_id': 'wanx-image'}, role: NodeRole.result),
        capabilities: caps,
      ),
      isNull,
      reason: '产物节点不发起生成',
    );
    for (final CanvasNodeType type in <CanvasNodeType>[CanvasNodeType.text, CanvasNodeType.shot]) {
      expect(
        estimateNodeCost(
          node: CanvasNode(id: 'n1', label: '', type: type),
          capabilities: caps,
        ),
        isNull,
        reason: '$type 没有「生成」',
      );
    }
    expect(
      estimateNodeCost(
        node: _image(const <String, Object?>{}),
        capabilities: const <ProviderCapabilities>[],
      ),
      isNull,
      reason: '一个候选供应商都没有',
    );
  });

  test('sumNodeCosts：已知求和、未知计数、null 跳过', () {
    const NodeCostEstimate a = NodeCostEstimate(providerId: 'a', usd: 0.128);
    const NodeCostEstimate b = NodeCostEstimate(providerId: 'b', usd: 0.75);
    const NodeCostEstimate u = NodeCostEstimate(
      providerId: 'c',
      usd: null,
      unknown: NodeCostUnknown.customEndpoint,
    );

    final NodeCostTotal total = sumNodeCosts(<NodeCostEstimate?>[a, null, u, b, u]);
    expect(total.usd, closeTo(0.878, 1e-9));
    expect(total.known, 2);
    expect(total.unknown, 2);

    final NodeCostTotal allUnknown = sumNodeCosts(<NodeCostEstimate?>[u, null]);
    expect(allUnknown.usd, 0);
    expect(allUnknown.known, 0);
    expect(allUnknown.unknown, 1);
  });

  test('resolutionShortLabel', () {
    expect(resolutionShortLabel(Resolution.p720), '720p');
    expect(resolutionShortLabel(Resolution.p1080), '1080p');
    expect(resolutionShortLabel(Resolution.k2), '2K');
    expect(resolutionShortLabel(Resolution.k4), '4K');
  });
}
