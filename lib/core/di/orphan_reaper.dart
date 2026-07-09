// OrphanFileReaper DI + 启动触发（LB-13 slice B，DRY-RUN v1）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/orphan_file_reaper.dart';
import '../../services/orphan_file_reaper.dart';
import 'clock.dart';
import 'logger.dart';
import 'paths.dart';
import 'repositories.dart';

/// app-scoped：磁盘孤儿回收器。依赖内嵌 PG 仓储（async），故为 FutureProvider——
/// 首次被 await 时触发 PG 启动 + schema migrate。
final orphanFileReaperProvider = FutureProvider<OrphanFileReaper>((ref) async {
  final nodeRepo = await ref.watch(nodeRepositoryProvider.future);
  final batchResults = await ref.watch(batchResultRepositoryProvider.future);
  return DiskOrphanFileReaper(
    paths: ref.watch(appPathsProvider),
    nodeRepo: nodeRepo,
    batchResultRepo: batchResults,
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  );
}, name: 'orphanFileReaperProvider');

/// 启动首帧后触发一次孤儿回收（DRY-RUN + 节流）。housekeeping：任何失败只 warn，
/// 绝不阻断启动或其它流程。**刻意不传 dryRun**——保持默认 true（本卡绝不删文件）。
final orphanReapStartupProvider = FutureProvider<void>((ref) async {
  final logger = ref.watch(loggerProvider);
  try {
    final reaper = await ref.watch(orphanFileReaperProvider.future);
    await reaper.reap();
  } catch (e, st) {
    // ── 放行点（sanctioned swallow）─────────────────────────────────────────
    // 启动 housekeeping 绝不阻断启动：这是与崩溃处理器同级的、被授权的全捕获吞点。
    // 孤儿回收任何失败——InkError（PG 未就绪/磁盘 I/O）、乃至逻辑异常（StateError
    // 等非 InkError）——都只记 warn，下次启动再试。fire-and-forget，异常绝不逃逸。
    // 刻意用 catch-all 而非 on InkError：否则非 InkError 会绕过 warn、静默落进
    // Riverpod AsyncError，违背「全吞、必 warn」意图。
    logger.warn(
      kOrphanReapModule,
      'orphan.reap.failed',
      extra: <String, Object?>{
        'error': e.toString(),
        'stack': st.toString(),
      },
    );
  }
}, name: 'orphanReapStartupProvider');
