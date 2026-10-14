// 新建菜单项判据（util/create_menu_model.dart）：带不带连线上下文、源是什么，菜单就出哪些项；
// 每一项建什么节点、连什么线；搜索过滤。
//
// 钉的几条：图像源出首帧 / 尾帧 / 参考（拿掉 sourceCarriesImage 的判断，视频产物那条红）；
// 「下一镜」只给配置节点（叙事链只连配置节点，见 create_menu_model 头注）；空组不出、不留孤立分隔线。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/create_menu_model.dart';

CanvasNode _node(
  String id,
  CanvasNodeType type, {
  NodeRole role = NodeRole.config,
  String? sourceNodeId,
  Map<String, Object?> typeConfig = const <String, Object?>{},
  DateTime? createdAt,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: type,
      role: role,
      sourceNodeId: sourceNodeId,
      typeConfig: typeConfig,
      createdAt: createdAt,
    );

const List<CreateMenuAction> _imageThree = <CreateMenuAction>[
  CreateMenuAction.asFirstFrame,
  CreateMenuAction.asLastFrame,
  CreateMenuAction.asReference,
];

void main() {
  group('createMenuGroups', () {
    test('不带上下文：图像配置 · 视频配置 · 文本 · 镜头 · 泳道，一组', () {
      expect(createMenuGroups(), <List<CreateMenuAction>>[
        <CreateMenuAction>[
          CreateMenuAction.imageConfig,
          CreateMenuAction.videoConfig,
          CreateMenuAction.text,
          CreateMenuAction.shot,
          CreateMenuAction.lane,
        ],
      ]);
    });

    test('图像配置源：首帧 / 尾帧 / 参考一组，「下一镜」另一组', () {
      final CanvasNode src = _node('img', CanvasNodeType.image);
      expect(
        createMenuGroups(source: src, nodes: <CanvasNode>[src]),
        <List<CreateMenuAction>>[
          _imageThree,
          <CreateMenuAction>[CreateMenuAction.nextShot],
        ],
      );
    });

    test('图像产物源：首帧 / 尾帧 / 参考；产物不在叙事链上，不出「下一镜」', () {
      final CanvasNode cfg = _node('cfg', CanvasNodeType.image);
      final CanvasNode res = _node(
        'res',
        CanvasNodeType.image,
        role: NodeRole.result,
        sourceNodeId: 'cfg',
        typeConfig: const <String, Object?>{'image_url': 'a.png'},
      );
      expect(
        createMenuGroups(source: res, nodes: <CanvasNode>[cfg, res]),
        <List<CreateMenuAction>>[_imageThree],
      );
    });

    test('视频产物源：不出首帧 / 尾帧 / 参考（那是图像语义），也不出「下一镜」', () {
      final CanvasNode cfg = _node('cfg', CanvasNodeType.video);
      final CanvasNode res = _node(
        'res',
        CanvasNodeType.video,
        role: NodeRole.result,
        sourceNodeId: 'cfg',
        typeConfig: const <String, Object?>{'video_url': 'a.mp4'},
      );
      final List<List<CreateMenuAction>> groups =
          createMenuGroups(source: res, nodes: <CanvasNode>[cfg, res]);
      for (final CreateMenuAction a in _imageThree) {
        expect(groups.expand((List<CreateMenuAction> g) => g), isNot(contains(a)));
      }
      expect(groups, isEmpty);
    });

    test('视频配置 / 镜头源：只有「下一镜」', () {
      for (final CanvasNodeType type in <CanvasNodeType>[
        CanvasNodeType.video,
        CanvasNodeType.shot,
      ]) {
        final CanvasNode src = _node('s', type);
        expect(
          createMenuGroups(source: src, nodes: <CanvasNode>[src]),
          <List<CreateMenuAction>>[
            <CreateMenuAction>[CreateMenuAction.nextShot],
          ],
          reason: type.name,
        );
      }
    });

    test('文本源：一项都没有（文本进了叙事链也成不了一镜，又不是图）', () {
      final CanvasNode src = _node('t', CanvasNodeType.text);
      expect(createMenuGroups(source: src, nodes: <CanvasNode>[src]), isEmpty);
    });

    test('名下最新的产物是一张图 ⇒ 带图像产物；最新的是视频 ⇒ 不算', () {
      final CanvasNode cfg = _node('cfg', CanvasNodeType.shot);
      CanvasNode result(String id, {required bool image, required int day}) => _node(
            id,
            image ? CanvasNodeType.image : CanvasNodeType.video,
            role: NodeRole.result,
            sourceNodeId: 'cfg',
            typeConfig: image
                ? const <String, Object?>{'image_url': 'a.png'}
                : const <String, Object?>{'video_url': 'a.mp4'},
            createdAt: DateTime.utc(2026, 1, day),
          );

      final List<CanvasNode> imageLatest = <CanvasNode>[
        cfg,
        result('old', image: false, day: 1),
        result('new', image: true, day: 2),
      ];
      expect(sourceCarriesImage(cfg, imageLatest), isTrue);

      final List<CanvasNode> videoLatest = <CanvasNode>[
        cfg,
        result('old', image: true, day: 1),
        result('new', image: false, day: 2),
      ];
      expect(sourceCarriesImage(cfg, videoLatest), isFalse);
    });
  });

  group('canContinueNarrative', () {
    test('shot / image / video 的配置节点能续一镜；产物与文本不能', () {
      expect(canContinueNarrative(_node('a', CanvasNodeType.shot)), isTrue);
      expect(canContinueNarrative(_node('a', CanvasNodeType.image)), isTrue);
      expect(canContinueNarrative(_node('a', CanvasNodeType.video)), isTrue);
      expect(canContinueNarrative(_node('a', CanvasNodeType.text)), isFalse);
      expect(
        canContinueNarrative(
          _node('a', CanvasNodeType.image, role: NodeRole.result, sourceNodeId: 'x'),
        ),
        isFalse,
      );
    });
  });

  group('createdNodeType / createdEdge', () {
    test('首帧 / 尾帧 → 视频配置 + 对应角色的 data 边；参考 → 图像配置 + data 参考边', () {
      expect(createdNodeType(CreateMenuAction.asFirstFrame), CanvasNodeType.video);
      expect(createdNodeType(CreateMenuAction.asLastFrame), CanvasNodeType.video);
      expect(createdNodeType(CreateMenuAction.asReference), CanvasNodeType.image);
      expect(
        createdEdge(CreateMenuAction.asFirstFrame),
        (type: EdgeType.data, role: EdgeRole.firstFrame),
      );
      expect(
        createdEdge(CreateMenuAction.asLastFrame),
        (type: EdgeType.data, role: EdgeRole.lastFrame),
      );
      expect(
        createdEdge(CreateMenuAction.asReference),
        (type: EdgeType.data, role: EdgeRole.reference),
      );
    });

    test('下一镜 → 与源同类型的配置节点 + narrative 边；没有源就不建', () {
      expect(
        createdNodeType(
          CreateMenuAction.nextShot,
          source: _node('s', CanvasNodeType.shot),
        ),
        CanvasNodeType.shot,
      );
      expect(
        createdNodeType(
          CreateMenuAction.nextShot,
          source: _node('v', CanvasNodeType.video),
        ),
        CanvasNodeType.video,
      );
      expect(createdNodeType(CreateMenuAction.nextShot), isNull);
      expect(
        createdEdge(CreateMenuAction.nextShot),
        (type: EdgeType.narrative, role: EdgeRole.reference),
      );
    });

    test('不带上下文的项：建对应类型、不连线；泳道不建节点', () {
      expect(createdNodeType(CreateMenuAction.imageConfig), CanvasNodeType.image);
      expect(createdNodeType(CreateMenuAction.videoConfig), CanvasNodeType.video);
      expect(createdNodeType(CreateMenuAction.text), CanvasNodeType.text);
      expect(createdNodeType(CreateMenuAction.shot), CanvasNodeType.shot);
      expect(createdNodeType(CreateMenuAction.lane), isNull);
      for (final CreateMenuAction a in kPlainCreateActions) {
        expect(createdEdge(a), isNull, reason: a.name);
      }
    });
  });

  group('filterMenuGroups', () {
    final List<List<String>> groups = <List<String>>[
      <String>['Alpha', 'Beta'],
      <String>['Gamma'],
    ];
    String label(String s) => s;

    test('不区分大小写的包含匹配', () {
      expect(filterMenuGroups<String>(groups, 'LPH', label), <List<String>>[
        <String>['Alpha'],
      ]);
      expect(filterMenuGroups<String>(groups, 'a', label), groups);
    });

    test('整组都没匹配上的组不出（不留孤立的分隔线）', () {
      expect(filterMenuGroups<String>(groups, 'gam', label), <List<String>>[
        <String>['Gamma'],
      ]);
    });

    test('一项都没匹配上 ⇒ 空；空白查询原样返回', () {
      expect(filterMenuGroups<String>(groups, 'zzz', label), isEmpty);
      expect(filterMenuGroups<String>(groups, '   ', label), groups);
    });
  });
}
