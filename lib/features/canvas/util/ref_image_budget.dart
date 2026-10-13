// 参考图配额（CH-2 残留②）：一个 config 节点真正能送出去的参考图有上限
// （provider 的 `maxRefImages`），而这份上限由两类来源**合计**消耗：
//
//   1. reference 角色的 data 入边——首/尾帧不占：全家 `refImagesIncludeKeyframes`
//      都是 false，它们走 `firstFramePath` / `lastFramePath` 两个独立字段，
//      压根不进 `refImagePaths`（所以 BOARD 199 里"首尾帧也占配额"的说法不成立，
//      真正抢配额的只有 reference 入边与角色图）；
//   2. 挂载角色的参考图，按 `character_ids` 顺序追加在边连参考图**之后**
//      （`GenerationController._injectCharacterRefs`）。
//
// 合计超限时 provider 自己 `take(maxRefImages)` 从**尾部**截断，于是掉在地上的恰好
// 是角色图——用户显式挂上去的东西，而 UI 一个字都不说。本文件把"谁掉、掉几张"算成
// 一个纯函数：检查器拿它在提交之前就把话说清楚（见 `CharactersSection`），
// 生成侧拿同一个口径落日志，两边不会各算一份。
//
// 【为什么不改截断顺序】角色图是用户显式挂的，边连参考图也是用户亲手连的，两者都不是
// 系统推导出来的。保持"边连在前"有两条实打实的理由：① 边连参考图是节点本地的一次性
// 意图（"这一镜用这张"），角色是项目级可复用集合，配额紧张时更具体的那个意图优先；
// ② 一个角色可以带多张参考图，把角色提到前面，一个 chip 就能把所有边连参考图挤下去，
// 而那些边还明明画在画布上——那是更大的一次静默撒谎。配额不够时该做的是让用户看见
// 并自己取舍，不是替他换一套优先级。
//
// 【已知偏差，照实写】本函数只认"声明了几张"，不知道磁盘上少了哪张
// （生成侧的 `resolveExisting` 会逐条吞掉缺文件的）。所以文件缺失这种异常情形下
// 它可能多报一张；方向是偏保守（提醒配额紧），不会少报。
import 'package:flutter/foundation.dart';

/// 一个挂载角色对配额的需求：它声明了哪些参考图（项目相对路径，顺序 = 注入次序）。
@immutable
class CharacterRefDemand {
  const CharacterRefDemand({
    required this.id,
    required this.name,
    required this.imagePaths,
  });

  final String id;

  /// 展示用名字（调用方负责在名字为空时回落到 id，与 chip 同口径）。
  final String name;

  final List<String> imagePaths;
}

/// 单个角色的配额结果。
@immutable
class CharacterRefOutcome {
  const CharacterRefOutcome({
    required this.id,
    required this.name,
    required this.wanted,
    required this.fitCount,
  });

  final String id;
  final String name;

  /// 去重后这个角色真正**新增**的张数（同一张图挂两个角色只算第一个）。
  final int wanted;

  /// 其中落在上限内、真会被送出去的张数。
  final int fitCount;

  /// 有张数被截掉（部分或全部）。
  bool get anyDropped => fitCount < wanted;

  /// 一张都没进去——这个角色等于没挂。
  bool get fullyDropped => wanted > 0 && fitCount == 0;
}

/// 一次提交的参考图配额全景。
@immutable
class RefImageBudgetPlan {
  const RefImageBudgetPlan({
    required this.limit,
    required this.requested,
    required this.characters,
  });

  /// provider 的 `maxRefImages`。
  final int limit;

  /// 不限量的话会送出的总张数（边连 reference 参考图 + 去重后的角色图）。
  final int requested;

  /// 与注入同序的逐角色结果。
  final List<CharacterRefOutcome> characters;

  bool get overflows => requested > limit;

  /// 真正被截掉的张数（limit 为负也不会报出超过 requested 的数）。
  int get droppedCount => requested - limit.clamp(0, requested);

  /// 有东西被咬掉的角色，按注入顺序。UI 点名用的就是这一份。
  List<CharacterRefOutcome> get shortfall => <CharacterRefOutcome>[
    for (final CharacterRefOutcome o in characters)
      if (o.anyDropped) o,
  ];
}

/// 按注入顺序（边连 reference 在前、角色按 [characters] 顺序补足）把 [limit] 分完，
/// 算出每个角色进得去几张。纯函数，不碰磁盘、不认 Flutter widget。
RefImageBudgetPlan planRefImageBudget({
  required int limit,
  required int edgeRefCount,
  required List<CharacterRefDemand> characters,
}) {
  // 去重口径与注入侧 `merged.contains(abs)` 同义：同一张图只占一格配额。
  final Set<String> seen = <String>{};
  final List<CharacterRefOutcome> outcomes = <CharacterRefOutcome>[];
  // offset = 这个角色开始之前已经排在前面的张数（截断是对拼好的列表做位置截断）。
  int offset = edgeRefCount;

  for (final CharacterRefDemand d in characters) {
    int wanted = 0;
    for (final String p in d.imagePaths) {
      if (seen.add(p)) wanted++;
    }
    final int room = limit - offset;
    final int fit = room <= 0 ? 0 : (room >= wanted ? wanted : room);
    outcomes.add(
      CharacterRefOutcome(
        id: d.id,
        name: d.name,
        wanted: wanted,
        fitCount: fit,
      ),
    );
    offset += wanted;
  }

  return RefImageBudgetPlan(
    limit: limit,
    requested: offset,
    characters: List<CharacterRefOutcome>.unmodifiable(outcomes),
  );
}
