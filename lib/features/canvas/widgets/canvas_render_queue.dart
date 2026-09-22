// CanvasRenderQueue：画布底部渲染队列 173px（稿 172 + 1px 上沿）。
//
// 三标签「渲染队列 N / 序列 / 导出历史」+ 右侧「清除已完成」| 24px 表头 | 28px 行。
// 列宽 28 220 110 1fr 90 120 60，间距 12：序号 / 任务 / 类型 / 进度+状态 / 耗时 / 模型 / 动作。
//
// 数据 = jobsRegistry 中本画布的 job（活跃在前、终态在后，各自保持插入序）。
//   任务名 = 源节点显示名（回退 provider displayName，不暴露 jobId）
//   类型   = 源节点类型名（回退 '—'）
//   进度   = JobState.progressValue；状态：队列中 / 渲染中 / 完成 / 失败（tooltip 带本地化错误）/ 已取消
//   耗时   = JobState 没有起止时间 → '—'（缺后端字段，稿上有，先不造）
//   模型   = providerId（JobState 只有 providerId，没有模型名）
//   动作   = 可取消时「取消」；稿上的「定位」无对应动作，先不画
// 「序列 / 导出历史」标签在仓库里没有内容，只画标签不挂交互。
// 「并发 2」在仓库里只是 ProviderCapabilities 的只读常量，稿上是可调项 → 不画。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/job_queue.dart';
import '../../../core/di/providers.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/current_canvas_id.dart';
import 'node_card.dart';

class CanvasRenderQueue extends ConsumerWidget {
  const CanvasRenderQueue({super.key});

  /// 稿是 content-box：height 172 + border-top 1。
  static const double height = 173;

  static const List<double?> _columns = <double?>[28, 220, 110, null, 90, 120, 60];

  static const Key clearDoneKey = Key('canvas.renderQueue.clearDone');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;

    final String? canvasId = ref.watch(currentCanvasIdProvider);
    final List<JobState> scoped = canvasId == null
        ? const <JobState>[]
        : ref.watch(jobsRegistryProvider).where((s) => s.canvasId == canvasId).toList();
    final List<JobState> active = scoped.where((s) => !s.isTerminal).toList();
    final List<JobState> terminal = scoped.where((s) => s.isTerminal).toList();
    final List<JobState> rows = <JobState>[...active, ...terminal];
    final List<CanvasNode> nodes = canvasId == null
        ? const <CanvasNode>[]
        : (ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[]);
    final Map<String, CanvasNode> byId = <String, CanvasNode>{for (final n in nodes) n.id: n};
    final Map<String, String> displayNames = ref.watch(providerDisplayNamesProvider);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WsPanelTabs(
            tabs: <String>[l.canvasRenderQueue, l.shellTabSequence, l.renderQueueTabExportHistory],
            badge: active.isEmpty ? null : '${active.length}',
            trailing: terminal.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                    child: Semantics(
                      button: true,
                      label: l.renderQueueClearDone,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          key: clearDoneKey,
                          behavior: HitTestBehavior.opaque,
                          onTap: () => ref.read(jobsRegistryProvider.notifier).clearTerminated(),
                          child: Center(
                            child: Text(l.renderQueueClearDone, style: t.meta.copyWith(color: c.fg5)),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Container(
            height: 25, // content 24 + border-bottom 1
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: _GridRow(
              cells: <Widget>[
                for (final String h in <String>[
                  '',
                  l.renderQueueColTask,
                  l.renderQueueColType,
                  l.renderQueueColProgress,
                  l.renderQueueColElapsed,
                  l.renderQueueColModel,
                  '',
                ])
                  Text(h, style: t.meta.copyWith(color: c.fg6)),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(InkSpacing.s12),
                    child: Text(l.canvasRenderQueueEmpty, style: t.meta.copyWith(color: c.fg6)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (BuildContext context, int i) {
                      final JobState job = rows[i];
                      final CanvasNode? src = job.sourceNodeId == null ? null : byId[job.sourceNodeId!];
                      return _JobRow(
                        index: i + 1,
                        job: job,
                        name: src != null
                            ? nodeDisplayName(context, src)
                            : (displayNames[job.providerId] ?? job.providerId),
                        kind: src?.type.name ?? '—',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({required this.cells});
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < cells.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: InkSpacing.s12),
            if (CanvasRenderQueue._columns[i] == null)
              Expanded(child: cells[i])
            else
              SizedBox(width: CanvasRenderQueue._columns[i], child: cells[i]),
          ],
        ],
      ),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.index, required this.job, required this.name, required this.kind});

  final int index;
  final JobState job;
  final String name;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final bool running = job is JobRunning;
    final (String status, Color statusColor, String? tooltip) = switch (job) {
      JobQueued() || JobSubmitting() => (l.canvasRenderQueueStatusQueued, c.fg4, null),
      JobRunning() => (l.renderQueueStatusRunning, c.accent, null),
      JobSucceeded() => (l.renderQueueStatusDone, c.fg4, null),
      JobFailed(:final error) => (l.renderQueueStatusFailed, c.danger, l10nError(context, error)),
      JobCancelled() => (l.renderQueueStatusCancelled, c.fg4, null),
    };
    final double fraction = switch (job) {
      JobSucceeded() => 1,
      JobRunning() => job.progressValue,
      _ => 0,
    };
    final Widget statusText = Text(status, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: t.meta.copyWith(color: statusColor));

    return Container(
      height: 29, // content 28 + border-bottom 1
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.surface1))),
      child: _GridRow(
        cells: <Widget>[
          Text(index.toString().padLeft(2, '0'), style: t.monoSmall.copyWith(color: c.fg6)),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg2)),
          Text(kind, style: t.body.copyWith(color: c.fg4)),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(color: c.control, borderRadius: BorderRadius.circular(InkRadius.xs)),
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: ColoredBox(color: running ? c.accent : c.fg6),
                  ),
                ),
              ),
              const SizedBox(width: InkSpacing.s10),
              SizedBox(
                width: 64,
                child: tooltip == null ? statusText : Tooltip(message: tooltip, child: statusText),
              ),
            ],
          ),
          Text('—', style: t.mono.copyWith(color: c.fg4)),
          Text(job.providerId, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg4)),
          if (job.isCancellable)
            Semantics(
              button: true,
              label: l.canvasRenderQueueCancel,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _cancel(ref, job.jobId),
                  child: Tooltip(
                    message: l.canvasRenderQueueCancel,
                    child: Text(l.commonCancel, style: t.meta.copyWith(color: c.fg5)),
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  // 取消链路复用核心服务：拿到 JobQueueService 后委托 cancel（idempotent）。
  Future<void> _cancel(WidgetRef ref, String jobId) async {
    final queue = await ref.read(jobQueueServiceProvider.future);
    await queue.cancel(jobId);
  }
}
