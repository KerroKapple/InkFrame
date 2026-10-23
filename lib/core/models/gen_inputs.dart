// 生成快照 gen_inputs 的契约：result 节点 type_config.gen_inputs 里一条输入源的值对象，
// 以及把快照 / 固定 take（pinned_result_id）里的 id 跟着重映射改写或剥掉的纯函数。
//
// 放 core 而不放 features/generation：services 层的项目包导入（import_remapper）要用，
// services 不能反向 import features。快照怎么「拍」在 features/generation/services/
// gen_inputs_snapshot.dart（它再导出这里的名字）；这里只管形状与改写。
//
// 手写不可变值对象而非 freezed（与 shot_language.dart / window_bounds.dart 同例外）。
import 'package:flutter/foundation.dart';

import '../constants/take_keys.dart';

/// gen_inputs 里的 JSON 键（内部常量，不 i18n）。
abstract final class GenInputsKeys {
  static const String sources = 'sources';
  static const String characterIds = 'character_ids';
  static const String nodeId = 'node_id';
  static const String role = 'role';
  static const String imageUrl = 'image_url';
  static const String text = 'text';
}

/// 一条 data 入边的源：源节点 id + 边的角色，外加生成那一刻源上的图（画布相对路径，原样）
/// 或文本节点正文（正文为空取 label，与并进提示词的口径一致）。
@immutable
class GenInputSource {
  const GenInputSource({required this.nodeId, required this.role, this.imageUrl, this.text});

  final String nodeId;

  /// first_frame / last_frame / reference（edge.role，缺省 reference）。
  final String role;
  final String? imageUrl;
  final String? text;

  /// null 字段不写。
  Map<String, Object?> toJson() => <String, Object?>{
        GenInputsKeys.nodeId: nodeId,
        GenInputsKeys.role: role,
        GenInputsKeys.imageUrl: ?imageUrl,
        GenInputsKeys.text: ?text,
      };

  /// 形状不对（不是 Map、node_id 不是非空字符串、role 不是字符串、image_url / text 有值却不是
  /// 字符串）⇒ null，不抛。
  static GenInputSource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? nodeId = raw[GenInputsKeys.nodeId];
    final Object? role = raw[GenInputsKeys.role];
    final Object? imageUrl = raw[GenInputsKeys.imageUrl];
    final Object? text = raw[GenInputsKeys.text];
    if (nodeId is! String || nodeId.isEmpty) return null;
    if (role is! String) return null;
    if (imageUrl != null && imageUrl is! String) return null;
    if (text != null && text is! String) return null;
    return GenInputSource(nodeId: nodeId, role: role, imageUrl: imageUrl as String?, text: text as String?);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenInputSource &&
          other.nodeId == nodeId &&
          other.role == role &&
          other.imageUrl == imageUrl &&
          other.text == text;

  @override
  int get hashCode => Object.hash(nodeId, role, imageUrl, text);

  @override
  String toString() => 'GenInputSource($nodeId, $role, image_url: $imageUrl, text: $text)';
}

/// [stripUnmappedGenInputs] 的结果：改写后的新 type_config + 剥掉了几处引用。
typedef GenInputsRemap = ({Map<String, Object?> typeConfig, int dropped});

/// 改写一份 type_config 里的 gen_inputs 与 pinned_result_id：
///  - gen_inputs.sources[].node_id、gen_inputs.character_ids 全部映射得到 ⇒ 改写成新 id；
///    任一映射不到 / 形状不对 ⇒ 整个 gen_inputs 键删掉（= 没快照），dropped += 1。
///    只剥一条源会让快照「看起来完整」却少了一条输入，宁可当没快照、不标过期，也不误标；
///  - pinned_result_id 是非空字符串时：映射得到 ⇒ 改写；映射不到 ⇒ 删键，dropped += 1
///    （当前 take 回落最新）。null / 空串 / 非字符串本来就是「没固定」，不是引用，原样留着；
///  - 两个键都没有 ⇒ 内容原样、dropped 0。
/// 总是返回新 Map，不改入参（导入那边传进来的可能是原始行的 cast 视图）。
/// 项目包导入传 UUID 映射；模板插入传 (_) => null；跨项目粘贴传选区内映射。
GenInputsRemap stripUnmappedGenInputs(
  Map<String, Object?> typeConfig, {
  required String? Function(String oldNodeId) mapNode,
  required String? Function(String oldCharacterId) mapCharacter,
}) {
  final Map<String, Object?> out = Map<String, Object?>.of(typeConfig);
  var dropped = 0;

  if (out.containsKey(TakeKeys.genInputs)) {
    final Map<String, Object?>? remapped = _remapSnapshot(
      out[TakeKeys.genInputs],
      mapNode: mapNode,
      mapCharacter: mapCharacter,
    );
    if (remapped == null) {
      out.remove(TakeKeys.genInputs);
      dropped++;
    } else {
      out[TakeKeys.genInputs] = remapped;
    }
  }

  final Object? pinned = out[TakeKeys.pinnedResultId];
  if (pinned is String && pinned.isNotEmpty) {
    final String? mapped = mapNode(pinned);
    if (mapped == null) {
      out.remove(TakeKeys.pinnedResultId);
      dropped++;
    } else {
      out[TakeKeys.pinnedResultId] = mapped;
    }
  }

  return (typeConfig: out, dropped: dropped);
}

/// 一份快照整体改写；任何一处映射不到或形状不对 ⇒ null（调用方整份删掉）。
/// JSON 解码出来的是 `Map<String, dynamic>` / `List<dynamic>`，一律按 `is Map` / `is List` 再逐项判。
Map<String, Object?>? _remapSnapshot(
  Object? raw, {
  required String? Function(String oldNodeId) mapNode,
  required String? Function(String oldCharacterId) mapCharacter,
}) {
  if (raw is! Map) return null;
  final Map<String, Object?> snapshot = <String, Object?>{
    for (final MapEntry<Object?, Object?> e in raw.entries) e.key.toString(): e.value,
  };

  final Object? sources = snapshot[GenInputsKeys.sources];
  if (sources is! List) return null;
  final List<Map<String, Object?>> remappedSources = <Map<String, Object?>>[];
  for (final Object? item in sources) {
    if (item is! Map) return null;
    final GenInputSource? source = GenInputSource.fromJson(item);
    if (source == null) return null;
    final String? mapped = mapNode(source.nodeId);
    if (mapped == null) return null;
    // 保留源上的其余键（以后加的字段不在导入时悄悄丢掉），只换 node_id。
    remappedSources.add(<String, Object?>{
      for (final MapEntry<Object?, Object?> e in item.entries) e.key.toString(): e.value,
      GenInputsKeys.nodeId: mapped,
    });
  }

  final Object? characterIds = snapshot[GenInputsKeys.characterIds];
  if (characterIds is! List) return null;
  final List<String> remappedCharacters = <String>[];
  for (final Object? id in characterIds) {
    if (id is! String || id.isEmpty) return null;
    final String? mapped = mapCharacter(id);
    if (mapped == null) return null;
    remappedCharacters.add(mapped);
  }

  snapshot[GenInputsKeys.sources] = remappedSources;
  snapshot[GenInputsKeys.characterIds] = remappedCharacters;
  return snapshot;
}
