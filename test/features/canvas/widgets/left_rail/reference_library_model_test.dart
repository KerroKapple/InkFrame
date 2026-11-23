// 参考库段的纯函数（reference_library_model.dart）：筛选 / 计数 / 视角，以及「当参考」的可用判据与同类替换规则。
//
// 服务商能力用真实的 kAllProviderCapabilities：默认图像服务商 gemini-image 不收参考图、wanx-image 上限 1 张、
// 视频默认 wanx-t2v 不收、wanx-r2v 收——用例钉的是今天真实的上限，不是自造的假能力。
//
// 变异对照：拿掉「选中数恰好 1」、「role == config」、「type ∈ {image, video}」、按类型取 lastUsed、
// 「maxRefImages <= 0」、替换集里的类别比较、alreadyAttached 的 id 比较、「替换集为空才判配额」，
// 对应用例当场红。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/import_keys.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/models/reference_item.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/reference_library_model.dart';

ReferenceItem _ref(
  String id, {
  ReferenceCategory category = ReferenceCategory.pose,
  String? angle,
  String searchText = '',
}) =>
    ReferenceItem(
      id: id,
      category: category,
      name: id,
      group: 'g',
      angle: angle,
      thumbPath: 'D:/lib/thumbs/$id.webp',
      originalPath: 'D:/lib/img/$id.webp',
      searchText: searchText,
    );

CanvasNode _config(
  String id, {
  CanvasNodeType type = CanvasNodeType.image,
  String? providerId,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: type,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'provider_id': ?providerId},
    );

/// 导入的 result 节点；[refId] / [category] 非空 = 从参考库导入（带两个标记键）。
CanvasNode _imported(String id, {String? refId, ReferenceCategory? category}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      typeConfig: <String, Object?>{
        ImportKeys.origin: ImportKeys.originImport,
        'image_url': 'imports/$id.webp',
        ImportKeys.referenceItemId: ?refId,
        ImportKeys.referenceCategory: ?category?.name,
      },
    );

CanvasEdge _edge(
  String id,
  String source,
  String target, {
  EdgeType type = EdgeType.data,
  EdgeRole role = EdgeRole.reference,
}) =>
    CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: source,
      targetNodeId: target,
      edgeType: type,
      role: role,
    );

ReferenceAttachDecision _plan({
  required ReferenceItem item,
  Set<String> selected = const <String>{'cfg'},
  required List<CanvasNode> nodes,
  List<CanvasEdge> edges = const <CanvasEdge>[],
  String? lastImage,
  String? lastVideo,
}) =>
    planReferenceAttach(
      item: item,
      selectedIds: selected,
      nodes: nodes,
      edges: edges,
      capabilities: kAllProviderCapabilities,
      lastUsedImageProviderId: lastImage,
      lastUsedVideoProviderId: lastVideo,
    );

void main() {
  final ReferenceItem pose1 = _ref('pose-1');
  final ReferenceItem pose2 = _ref('pose-2');

  group('filterReferenceItems', () {
    final List<ReferenceItem> all = <ReferenceItem>[
      _ref('p1', angle: '正面', searchText: 'Standing 站姿 正面'),
      _ref('p2', angle: '侧面', searchText: 'standing 回眸 侧面'),
      _ref('p3', angle: '正面', searchText: 'Sitting 坐姿'),
      _ref('r1', category: ReferenceCategory.portrait, searchText: 'Short hair 短发'),
      _ref('c1', category: ReferenceCategory.costume, searchText: 'spring coat 春季'),
    ];

    List<String> ids(List<ReferenceItem> items) =>
        items.map((ReferenceItem i) => i.id).toList();

    test('只留这个类别；query 为空不过滤，保持原顺序', () {
      expect(ids(filterReferenceItems(all, category: ReferenceCategory.pose)),
          <String>['p1', 'p2', 'p3']);
      expect(ids(filterReferenceItems(all, category: ReferenceCategory.portrait)),
          <String>['r1']);
      expect(ids(filterReferenceItems(all, category: ReferenceCategory.costume)),
          <String>['c1']);
    });

    test('query 先 trim、大小写不敏感，按 searchText 子串匹配', () {
      expect(
        ids(filterReferenceItems(all, category: ReferenceCategory.pose, query: '  STANDING ')),
        <String>['p1', 'p2'],
      );
      expect(
        ids(filterReferenceItems(all, category: ReferenceCategory.pose, query: '回眸')),
        <String>['p2'],
      );
      // 只有空白 = 没有 query。
      expect(
        ids(filterReferenceItems(all, category: ReferenceCategory.pose, query: '   ')),
        <String>['p1', 'p2', 'p3'],
      );
      // 别的类别里能匹配的不跨过来。
      expect(
        filterReferenceItems(all, category: ReferenceCategory.pose, query: 'short hair'),
        isEmpty,
      );
    });

    test('angle 只留这个视角；与 query 同时生效', () {
      expect(
        ids(filterReferenceItems(all, category: ReferenceCategory.pose, angle: '正面')),
        <String>['p1', 'p3'],
      );
      expect(
        ids(filterReferenceItems(all,
            category: ReferenceCategory.pose, query: 'standing', angle: '正面')),
        <String>['p1'],
      );
    });
  });

  group('referenceCounts', () {
    final List<ReferenceItem> all = <ReferenceItem>[
      _ref('p1', searchText: 'Standing'),
      _ref('p2', searchText: 'sitting'),
      _ref('r1', category: ReferenceCategory.portrait, searchText: 'standing portrait'),
      _ref('c1', category: ReferenceCategory.costume, searchText: 'coat'),
      _ref('c2', category: ReferenceCategory.costume, searchText: 'dress'),
    ];

    test('没有 query ⇒ 各类别总数，三个类别都有键', () {
      expect(referenceCounts(all), <ReferenceCategory, int>{
        ReferenceCategory.pose: 2,
        ReferenceCategory.portrait: 1,
        ReferenceCategory.costume: 2,
      });
    });

    test('有 query ⇒ 按同一口径（trim + 大小写不敏感）计数，没命中的类别是 0', () {
      expect(referenceCounts(all, query: ' STANDING'), <ReferenceCategory, int>{
        ReferenceCategory.pose: 1,
        ReferenceCategory.portrait: 1,
        ReferenceCategory.costume: 0,
      });
    });
  });

  group('referenceAngles', () {
    test('只看 pose，按首次出现的顺序去重，没有视角的跳过', () {
      final List<ReferenceItem> all = <ReferenceItem>[
        _ref('r1', category: ReferenceCategory.portrait, angle: '俯视'),
        _ref('p1', angle: '侧面'),
        _ref('p2', angle: '正面'),
        _ref('p3', angle: '侧面'),
        _ref('p4'),
        _ref('p5', angle: '背面'),
      ];
      expect(referenceAngles(all), <String>['侧面', '正面', '背面']);
    });

    test('没有 pose ⇒ 空', () {
      expect(referenceAngles(<ReferenceItem>[_ref('c1', category: ReferenceCategory.costume)]),
          isEmpty);
    });
  });

  group('planReferenceAttach · 不可用', () {
    test('没有选中 ⇒ noSelection', () {
      final r = _plan(
        item: pose1,
        selected: const <String>{},
        nodes: <CanvasNode>[_config('cfg', providerId: 'wanx-image')],
      );
      expect(r.block, ReferenceAttachBlock.noSelection);
      expect(r.plan, isNull);
    });

    test('选中两个 ⇒ noSelection', () {
      final r = _plan(
        item: pose1,
        selected: const <String>{'cfg', 'cfg2'},
        nodes: <CanvasNode>[
          _config('cfg', providerId: 'wanx-image'),
          _config('cfg2', providerId: 'wanx-image'),
        ],
      );
      expect(r.block, ReferenceAttachBlock.noSelection);
    });

    test('选中的 id 已不在节点表里 ⇒ noSelection', () {
      final r = _plan(
        item: pose1,
        selected: const <String>{'gone'},
        nodes: <CanvasNode>[_config('cfg', providerId: 'wanx-image')],
      );
      expect(r.block, ReferenceAttachBlock.noSelection);
    });

    test('shot 节点 ⇒ notConfig', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[
          _config('cfg', type: CanvasNodeType.shot, providerId: 'wanx-image'),
        ],
      );
      expect(r.block, ReferenceAttachBlock.notConfig);
      expect(r.plan, isNull);
    });

    test('文本节点 ⇒ notConfig', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[_config('cfg', type: CanvasNodeType.text)],
      );
      expect(r.block, ReferenceAttachBlock.notConfig);
    });

    test('图像产物节点（role = result）⇒ notConfig', () {
      final r = _plan(item: pose1, nodes: <CanvasNode>[_imported('cfg')]);
      expect(r.block, ReferenceAttachBlock.notConfig);
    });

    test('没存服务商也没上次使用 ⇒ 默认第一个 gemini-image（不收参考图）⇒ providerNoRefs', () {
      final r = _plan(item: pose1, nodes: <CanvasNode>[_config('cfg')]);
      expect(r.block, ReferenceAttachBlock.providerNoRefs);
      expect(r.plan, isNull);
    });

    test('节点存了一个已不存在的服务商 ⇒ providerNoRefs', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[_config('cfg', providerId: 'custom-deleted')],
      );
      expect(r.block, ReferenceAttachBlock.providerNoRefs);
    });

    test('视频节点默认 wanx-t2v（不收参考图）⇒ providerNoRefs；图像的上次使用不串给视频', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[_config('cfg', type: CanvasNodeType.video)],
        lastImage: 'wanx-image',
      );
      expect(r.block, ReferenceAttachBlock.providerNoRefs);
    });

    test('图像节点不读视频的上次使用（wanx-r2v 也在图像候选里，串了就会误判可用）', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[_config('cfg')],
        lastVideo: 'wanx-r2v',
      );
      expect(r.block, ReferenceAttachBlock.providerNoRefs);
    });

    test('wanx-image（上限 1）已有一条普通参考边 ⇒ budgetFull', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[
          _config('cfg', providerId: 'wanx-image'),
          _imported('plain'),
        ],
        edges: <CanvasEdge>[_edge('e-plain', 'plain', 'cfg')],
      );
      expect(r.block, ReferenceAttachBlock.budgetFull);
      expect(r.plan, isNull);
      // 置灰原因「参考图已满 N / N」要的服务商与上限：wanx-image 收 1 张。
      expect(r.providerId, 'wanx-image');
      expect(r.maxRefImages, 1);
    });

    test('wanx-image 已挂一张 costume 参考库图 ⇒ 不在 pose 的替换集里 ⇒ budgetFull', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[
          _config('cfg', providerId: 'wanx-image'),
          _imported('costume', refId: 'costume-1', category: ReferenceCategory.costume),
        ],
        edges: <CanvasEdge>[_edge('e-costume', 'costume', 'cfg')],
      );
      expect(r.block, ReferenceAttachBlock.budgetFull);
    });
  });

  group('planReferenceAttach · 可用', () {
    test('wanx-image、目标没有参考边 ⇒ plan：替换集为空、不是同一张', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[_config('cfg', providerId: 'wanx-image')],
      );
      expect(r.block, isNull);
      expect(r.plan, isNotNull);
      expect(r.plan!.targetNodeId, 'cfg');
      expect(r.plan!.replaceEdgeIds, isEmpty);
      expect(r.plan!.alreadyAttached, isFalse);
    });

    test('没存服务商时按上次使用的图像服务商（wanx-image）判', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[_config('cfg')],
        lastImage: 'wanx-image',
      );
      expect(r.block, isNull);
      expect(r.plan!.targetNodeId, 'cfg');
    });

    test('视频节点按上次使用的视频服务商（wanx-r2v）判', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[_config('cfg', type: CanvasNodeType.video)],
        lastVideo: 'wanx-r2v',
      );
      expect(r.block, isNull);
      expect(r.plan!.targetNodeId, 'cfg');
    });

    test('wanx-image 已挂一张 pose 参考库图 ⇒ 替换集 = {那条}，不报 budgetFull', () {
      final r = _plan(
        item: pose2,
        nodes: <CanvasNode>[
          _config('cfg', providerId: 'wanx-image'),
          _imported('old', refId: 'pose-1', category: ReferenceCategory.pose),
        ],
        edges: <CanvasEdge>[_edge('e-old', 'old', 'cfg')],
      );
      expect(r.block, isNull);
      expect(r.plan!.replaceEdgeIds, <String>{'e-old'});
      expect(r.plan!.alreadyAttached, isFalse);
    });

    test('同一 reference_item_id 已挂着 ⇒ alreadyAttached', () {
      final r = _plan(
        item: pose1,
        nodes: <CanvasNode>[
          _config('cfg', providerId: 'wanx-image'),
          _imported('old', refId: 'pose-1', category: ReferenceCategory.pose),
        ],
        edges: <CanvasEdge>[_edge('e-old', 'old', 'cfg')],
      );
      expect(r.block, isNull);
      expect(r.plan!.alreadyAttached, isTrue);
      expect(r.plan!.replaceEdgeIds, <String>{'e-old'});
    });

    test('pose 与 costume 互不替换：替换集只收同类别的边', () {
      final r = _plan(
        item: pose2,
        nodes: <CanvasNode>[
          _config('cfg', type: CanvasNodeType.video),
          _imported('old-pose', refId: 'pose-1', category: ReferenceCategory.pose),
          _imported('costume', refId: 'pose-2', category: ReferenceCategory.costume),
        ],
        edges: <CanvasEdge>[
          _edge('e-pose', 'old-pose', 'cfg'),
          _edge('e-costume', 'costume', 'cfg'),
        ],
        lastVideo: 'wanx-r2v',
      );
      expect(r.block, isNull);
      expect(r.plan!.replaceEdgeIds, <String>{'e-pose'});
      // costume 那张的条目 id 碰巧也叫 pose-2，但类别不同，不算「已经是这张」。
      expect(r.plan!.alreadyAttached, isFalse);
    });

    test('只认指向目标的 data/reference 边：首帧、叙事、别的目标都不进替换集也不占配额', () {
      final r = _plan(
        item: pose2,
        nodes: <CanvasNode>[
          _config('cfg', providerId: 'wanx-image'),
          _config('other', providerId: 'wanx-image'),
          _imported('first', refId: 'pose-1', category: ReferenceCategory.pose),
          _imported('elsewhere', refId: 'pose-1', category: ReferenceCategory.pose),
        ],
        edges: <CanvasEdge>[
          _edge('e-first', 'first', 'cfg', role: EdgeRole.firstFrame),
          _edge('e-narr', 'first', 'cfg', type: EdgeType.narrative),
          _edge('e-else', 'elsewhere', 'other'),
        ],
      );
      expect(r.block, isNull);
      expect(r.plan!.replaceEdgeIds, isEmpty);
      expect(r.plan!.alreadyAttached, isFalse);
    });
  });
}
