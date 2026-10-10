// 画廊脏标记（T9）：任一 job 转 JobSucceeded 即把**它所属项目**的画廊标脏，
// 画廊标签由「不可见 → 可见」时若当前项目脏就刷一次 galleryControllerProvider，
// 然后清掉该项目的标记。
//
// 【按项目记账，不是全局】脏标记是关于**数据**的事实（"项目 P 的产物集合变了"），
// 不是关于 UI 的事实，所以记在 projectId 上而不是"当前看的是谁"。于是
// "A 项目生成完成、切到 B 项目画廊"不再触发一次与 B 无关的刷新。
// JobState 的六个变体都带 projectId（与 GenerationTask 同源，取自 config 节点行
// JOIN canvases 带出的 project_id），见 generation/models/job_state.dart 文件头。
//
// 【集合里的 null 是通配】projectId 在生产里恒非空，类型可空只是因为 RowReader
// 证明不了这件事。真拿到 null 时不知道该标哪个项目，**退回旧的全局语义**：
// 任何项目的画廊都当脏。方向是刻意的——多刷一次的代价严格封顶在"一次多余
// 聚合查询"（刷新走 skipLoadingOnRefresh 就地换数据，滚动/筛选全保，用户无感），
// 而漏刷是用户盯着旧数据，严重得多。
//
// 【误刷的上界】galleryControllerProvider 是 AutoDisposeFamily：切项目会直接
// dispose 掉旧 projectId 的 entry。所以残留标记最坏也只是对**当前**项目多跑
// 一次聚合——不可能把 A 的数据带进 B，也不可能让 B 的筛选态丢失。
//
// 【去重不是优化，是正确性】JobSucceeded 是终态，会长期留在 registry 里。
// 若只判断"当前列表里存在 JobSucceeded"，任何一次 registry 变更（哪怕是另一
// 条 job 刚入队）都会把刚清掉的脏标记重新置上 ⇒ clear() 永远清不干净 ⇒
// 每次切到画廊都刷。按 jobId 记账，一条成功只算一次。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';

/// 状态 = 画廊已过期的项目 id 集合；集合里的 `null` 是"不知道是哪个项目"的通配位。
final galleryDirtyProvider = NotifierProvider<GalleryDirty, Set<String?>>(
  GalleryDirty.new,
  name: 'galleryDirtyProvider',
);

class GalleryDirty extends Notifier<Set<String?>> {
  /// 已计入脏标记的成功 job——跨 clear() 存活（见文件头「去重不是优化」）。
  final Set<String> _counted = <String>{};

  @override
  Set<String?> build() {
    // listen 而非 watch：watch 会让 build 重跑并把 state 复位成空集，
    // 脏标记在下一条 job 变化时就凭空消失。
    ref.listen<List<JobState>>(jobsRegistryProvider, (_, next) {
      for (final JobState job in next) {
        if (job is JobSucceeded && _counted.add(job.jobId)) {
          state = <String?>{...state, job.projectId};
        }
      }
    });
    return const <String?>{};
  }

  /// [projectId] 这个项目的画廊是否已过期。通配位（null）对任何项目都为真。
  bool isDirtyFor(String projectId) =>
      state.contains(null) || state.contains(projectId);

  /// 该项目的刷新已经发出 ⇒ 清掉它的标记。
  /// _counted 刻意不清：那些 jobId 已经被这次刷新覆盖了。
  ///
  /// 通配位跟着一起清：它代表"有一条不知归属的新产物"，刷过一次就算交付了
  /// ——留着的话之后切到任何项目的画廊都要白刷一次，正是旧全局标记的毛病。
  void clear(String projectId) {
    if (!isDirtyFor(projectId)) return;
    state = <String?>{
      for (final String? p in state)
        if (p != null && p != projectId) p,
    };
  }
}
