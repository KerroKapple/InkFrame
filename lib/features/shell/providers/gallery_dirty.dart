// 画廊脏标记（T9）：粗粒度——任一 job 转 JobSucceeded 即置脏，画廊标签
// 由「不可见 → 可见」时若脏就刷一次 galleryControllerProvider，然后清脏。
//
// 【为什么是粗粒度】jobsRegistry 是全 app 级内存镜像，条目上只有 canvasId
// 没有 projectId；要判断"这条产物属不属于当前画廊的项目"得回查画布→项目，
// 成本远高于偶尔多刷一次——刷新走 skipLoadingOnRefresh 的就地换数据，
// 滚动/搜索框/筛选全保，用户无感。
//
// 【去重不是优化，是正确性】JobSucceeded 是终态，会长期留在 registry 里。
// 若只判断"当前列表里存在 JobSucceeded"，任何一次 registry 变更（哪怕是另一
// 条 job 刚入队）都会把刚清掉的脏标记重新置上 ⇒ clear() 永远清不干净 ⇒
// 每次切到画廊都刷。按 jobId 记账，一条成功只算一次。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';

final galleryDirtyProvider = NotifierProvider<GalleryDirty, bool>(
  GalleryDirty.new,
  name: 'galleryDirtyProvider',
);

class GalleryDirty extends Notifier<bool> {
  /// 已计入脏标记的成功 job——跨 clear() 存活（见文件头「去重不是优化」）。
  final Set<String> _counted = <String>{};

  @override
  bool build() {
    // listen 而非 watch：watch 会让 build 重跑并把 state 复位成 false，
    // 脏标记在下一条 job 变化时就凭空消失。
    ref.listen<List<JobState>>(jobsRegistryProvider, (_, next) {
      for (final JobState job in next) {
        if (job is JobSucceeded && _counted.add(job.jobId)) {
          state = true;
        }
      }
    });
    return false;
  }

  /// 刷新已经发出 ⇒ 清脏。_counted 刻意不清：那些 jobId 已经被这次刷新覆盖了。
  void clear() {
    if (state) state = false;
  }
}
