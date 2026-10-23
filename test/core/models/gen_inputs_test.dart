// gen_inputs（生成快照）的值对象与重映射：GenInputSource 往返 + stripUnmappedGenInputs。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/take_keys.dart';
import 'package:inkframe/core/models/gen_inputs.dart';

/// 一份典型的快照：两条源 + 两个角色，外加 prompt 等与 id 无关的键。
Map<String, Object?> _snapshot() => <String, Object?>{
      'prompt': 'a cat',
      'provider_id': 'gemini-image',
      'character_ids': <Object?>['ch1', 'ch2'],
      'sources': <Object?>[
        <String, Object?>{'node_id': 's1', 'role': 'reference', 'image_url': 'images/a.png'},
        <String, Object?>{'node_id': 's2', 'role': 'reference', 'text': 'with fog'},
      ],
    };

Map<String, Object?> _typeConfig({Object? genInputs, Object? pinned, bool withPinned = false}) =>
    <String, Object?>{
      'image_url': 'images/out.png',
      TakeKeys.genInputs: genInputs ?? _snapshot(),
      if (withPinned) TakeKeys.pinnedResultId: pinned,
    };

void main() {
  group('GenInputSource', () {
    test('GenInputSource toJson / fromJson 往返；null 字段不写', () {
      const full = GenInputSource(nodeId: 'n1', role: 'first_frame', imageUrl: 'images/a.png', text: 'fog');
      expect(full.toJson(), <String, Object?>{
        'node_id': 'n1',
        'role': 'first_frame',
        'image_url': 'images/a.png',
        'text': 'fog',
      });
      expect(GenInputSource.fromJson(full.toJson()), full);

      const bare = GenInputSource(nodeId: 'n2', role: 'reference');
      expect(bare.toJson(), <String, Object?>{'node_id': 'n2', 'role': 'reference'},
          reason: 'image_url / text 为 null 时键都不写');
      expect(GenInputSource.fromJson(bare.toJson()), bare);

      // JSON 解码出来的是 Map<String, dynamic>，也要认。
      final Map<String, dynamic> decoded = <String, dynamic>{'node_id': 'n3', 'role': 'last_frame'};
      expect(GenInputSource.fromJson(decoded), const GenInputSource(nodeId: 'n3', role: 'last_frame'));
    });

    test('fromJson 形状不对 → null', () {
      expect(GenInputSource.fromJson(null), isNull);
      expect(GenInputSource.fromJson('n1'), isNull);
      expect(GenInputSource.fromJson(<Object?>['n1']), isNull);
      expect(GenInputSource.fromJson(<String, Object?>{'role': 'reference'}), isNull, reason: '缺 node_id');
      expect(GenInputSource.fromJson(<String, Object?>{'node_id': '', 'role': 'reference'}), isNull,
          reason: 'node_id 空串');
      expect(GenInputSource.fromJson(<String, Object?>{'node_id': 42, 'role': 'reference'}), isNull,
          reason: 'node_id 不是字符串');
      expect(GenInputSource.fromJson(<String, Object?>{'node_id': 'n1'}), isNull, reason: '缺 role');
      expect(GenInputSource.fromJson(<String, Object?>{'node_id': 'n1', 'role': 'reference', 'image_url': 7}),
          isNull,
          reason: 'image_url 不是字符串');
      expect(GenInputSource.fromJson(<String, Object?>{'node_id': 'n1', 'role': 'reference', 'text': false}),
          isNull,
          reason: 'text 不是字符串');
    });
  });

  group('stripUnmappedGenInputs', () {
    const Map<String, String> nodes = <String, String>{'s1': 'N1', 's2': 'N2', 'r1': 'R1'};
    const Map<String, String> chars = <String, String>{'ch1': 'C1', 'ch2': 'C2'};

    test('stripUnmappedGenInputs：全映射得到 → 改写源 id 与角色 id', () {
      final GenInputsRemap r = stripUnmappedGenInputs(
        _typeConfig(),
        mapNode: (String o) => nodes[o],
        mapCharacter: (String o) => chars[o],
      );
      expect(r.dropped, 0);
      final Map<String, Object?> gi = r.typeConfig[TakeKeys.genInputs]! as Map<String, Object?>;
      expect(gi['character_ids'], <String>['C1', 'C2'], reason: '角色 id 按原序改写');
      expect(gi['sources'], <Map<String, Object?>>[
        <String, Object?>{'node_id': 'N1', 'role': 'reference', 'image_url': 'images/a.png'},
        <String, Object?>{'node_id': 'N2', 'role': 'reference', 'text': 'with fog'},
      ]);
      expect(gi['prompt'], 'a cat', reason: '与 id 无关的键原样');
      expect(gi['provider_id'], 'gemini-image');
      expect(r.typeConfig['image_url'], 'images/out.png');
    });

    test('任一源映射不到 → 整份 gen_inputs 删掉，dropped=1', () {
      final GenInputsRemap r = stripUnmappedGenInputs(
        _typeConfig(),
        mapNode: (String o) => o == 's2' ? null : nodes[o],
        mapCharacter: (String o) => chars[o],
      );
      expect(r.typeConfig.containsKey(TakeKeys.genInputs), isFalse,
          reason: '只剥一个源会让快照「看起来完整」却少了一条输入——宁可当没快照');
      expect(r.dropped, 1);
      expect(r.typeConfig['image_url'], 'images/out.png', reason: '其余键原样');
    });

    test('角色映射不到 → 整份删掉', () {
      final GenInputsRemap r = stripUnmappedGenInputs(
        _typeConfig(),
        mapNode: (String o) => nodes[o],
        mapCharacter: (String o) => o == 'ch2' ? null : chars[o],
      );
      expect(r.typeConfig.containsKey(TakeKeys.genInputs), isFalse);
      expect(r.dropped, 1);
    });

    test('形状不对 → 整份删掉并计数', () {
      Map<String, Object?> withSnapshot(Object? gi) => <String, Object?>{TakeKeys.genInputs: gi};
      String? mapN(String o) => nodes[o];
      String? mapC(String o) => chars[o];
      final List<Object?> bad = <Object?>[
        'not a map',
        <String, Object?>{..._snapshot(), 'sources': 'nope'},
        <String, Object?>{..._snapshot(), 'character_ids': 'ch1'},
        <String, Object?>{
          ..._snapshot(),
          'sources': <Object?>[
            <String, Object?>{'role': 'reference'}, // 缺 node_id
          ],
        },
        <String, Object?>{
          ..._snapshot(),
          'character_ids': <Object?>[42],
        },
      ];
      for (final Object? gi in bad) {
        final GenInputsRemap r = stripUnmappedGenInputs(withSnapshot(gi), mapNode: mapN, mapCharacter: mapC);
        expect(r.typeConfig.containsKey(TakeKeys.genInputs), isFalse, reason: '$gi');
        expect(r.dropped, 1, reason: '$gi');
      }
    });

    test('JSON 解码出来的宽类型（Map<String, dynamic> / List<dynamic>）照样改写', () {
      final Map<String, dynamic> gi = <String, dynamic>{
        'character_ids': <dynamic>['ch1'],
        'sources': <dynamic>[
          <String, dynamic>{'node_id': 's1', 'role': 'reference'},
        ],
      };
      final GenInputsRemap r = stripUnmappedGenInputs(
        <String, Object?>{TakeKeys.genInputs: gi},
        mapNode: (String o) => nodes[o],
        mapCharacter: (String o) => chars[o],
      );
      expect(r.dropped, 0);
      final Map<String, Object?> out = r.typeConfig[TakeKeys.genInputs]! as Map<String, Object?>;
      expect(out['character_ids'], <String>['C1']);
      expect(out['sources'], <Map<String, Object?>>[
        <String, Object?>{'node_id': 'N1', 'role': 'reference'},
      ]);
    });

    test('pinned_result_id 映射得到改写、映射不到删键', () {
      final GenInputsRemap hit = stripUnmappedGenInputs(
        <String, Object?>{'prompt': 'x', TakeKeys.pinnedResultId: 'r1'},
        mapNode: (String o) => nodes[o],
        mapCharacter: (String o) => chars[o],
      );
      expect(hit.typeConfig[TakeKeys.pinnedResultId], 'R1');
      expect(hit.dropped, 0);

      final GenInputsRemap miss = stripUnmappedGenInputs(
        <String, Object?>{'prompt': 'x', TakeKeys.pinnedResultId: 'gone'},
        mapNode: (String o) => nodes[o],
        mapCharacter: (String o) => chars[o],
      );
      expect(miss.typeConfig.containsKey(TakeKeys.pinnedResultId), isFalse,
          reason: '留着旧 id 会指向别的项目里的节点（或谁也不是）');
      expect(miss.typeConfig['prompt'], 'x');
      expect(miss.dropped, 1);
    });

    test('pinned_result_id 为 null / 空串（= 没固定）→ 不当引用，原样、不计数', () {
      for (final Object? v in <Object?>[null, '']) {
        final GenInputsRemap r = stripUnmappedGenInputs(
          <String, Object?>{TakeKeys.pinnedResultId: v},
          mapNode: (_) => null,
          mapCharacter: (_) => null,
        );
        expect(r.typeConfig, <String, Object?>{TakeKeys.pinnedResultId: v});
        expect(r.dropped, 0);
      }
    });

    test('模板插入 (_) => null：两个键都剥掉，其余键原样', () {
      final GenInputsRemap r = stripUnmappedGenInputs(
        _typeConfig(pinned: 'r1', withPinned: true),
        mapNode: (_) => null,
        mapCharacter: (_) => null,
      );
      expect(r.typeConfig, <String, Object?>{'image_url': 'images/out.png'});
      expect(r.dropped, 2);
    });

    test('没有这两个键 → 原样、dropped=0、不改入参', () {
      final Map<String, Object?> input = <String, Object?>{'prompt': 'x', 'seed': 7};
      final GenInputsRemap r = stripUnmappedGenInputs(input, mapNode: (_) => null, mapCharacter: (_) => null);
      expect(r.typeConfig, <String, Object?>{'prompt': 'x', 'seed': 7});
      expect(r.dropped, 0);

      // 有键时也不改入参：改写 / 剥掉都落在返回的新 Map 上。
      final Map<String, Object?> withKeys = _typeConfig(pinned: 'r1', withPinned: true);
      final String before = withKeys.toString();
      stripUnmappedGenInputs(withKeys, mapNode: (String o) => nodes[o], mapCharacter: (String o) => chars[o]);
      expect(withKeys.toString(), before);
      stripUnmappedGenInputs(withKeys, mapNode: (_) => null, mapCharacter: (_) => null);
      expect(withKeys.toString(), before);
    });
  });
}
