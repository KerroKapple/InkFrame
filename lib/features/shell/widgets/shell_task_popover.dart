// ShellTaskPopover：状态栏任务胶囊上方的任务弹层（画布重设计稿 main.js tasksPopover）。
//
// 数据和动作照搬原画布底栏的渲染队列（canvas_render_queue.dart，PR-6 删除），只换外观，范围放大到
// 全部 job（胶囊在状态栏，状态栏是全局的）：
//   - 行序：活动的在前、终态在后，各自保持注册表的插入序（orderTasks）。
//   - 任务名 = 源节点显示名，回退 provider 显示名（不暴露 jobId）。源节点从 job 所在画布的节点控制器
//     里找：弹层开着时才 watch，关上即随 autoDispose 回收（别的画布那份只在弹层开着时读一次库）。
//   - meta = provider 显示名 · 状态（排队中 / 生成中 / 完成 / 失败 / 已取消）；失败行的 tooltip 是本地化错误。
//   - 运行中的行再加一条 4 高的进度条（control 底、accent 填充、圆角 2）。
//   - 不显示耗时：JobState 没有起止时间（与原渲染队列一样）。
//   - 动作：可取消（非终态）⇒「取消」（JobQueueService.cancel，幂等）；终态且源节点还在 ⇒「定位」：
//     同一画布 = 切回画布标签；别的画布 = 先 openCanvas 切过去；然后挂起定位请求，画布挂着 / 挂上来
//     后落地：单选 + 居中（canvas_focus_request.dart——别的画布这一刻还没挂载，直接写它的选中会被
//     autoDispose 回收）。换画布要带 ProjectRef（外壳换项目必须带名字）：任务属于
//     外壳当前项目就用它，否则从 Studio 一直开着的工作库列表里找；都拿不到就不画「定位」——绝不挂一个
//     点了没反应的按钮（job_notification_listener 的「查看」同一口径）。
//   - 头部「并发 N」只读显示 JobQueueService 的全局并发上限。
//   - 底部「清除已完成」= jobsRegistry.clearTerminated；没有终态 job 时不可点。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/job_queue.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/job_queue_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../services/job_queue_service.dart' show kDefaultGlobalConcurrency;
import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_focus_request.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../canvas/widgets/node_card.dart' show nodeDisplayName;
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import '../../studio/models/project_with_canvases.dart';
import '../../studio/providers/workspace_projects_provider.dart';
import '../models/shell_state.dart';
import '../providers/shell_controller.dart';

/// 弹层的行序：活动的在前、终态在后，各自保持注册表的插入序。
List<JobState> orderTasks(List<JobState> jobs) => <JobState>[
      for (final JobState j in jobs)
        if (!j.isTerminal) j,
      for (final JobState j in jobs)
        if (j.isTerminal) j,
    ];

class ShellTaskPopover extends ConsumerWidget {
  const ShellTaskPopover({super.key});

  /// 稿：宽 340。
  static const double width = 340;

  /// 头部：稿 content-box，36 + 1px 下沿。
  static const double headerHeight = 37;

  /// 底部「清除已完成」那一条。
  static const double footerHeight = 32;

  static const Key panelKey = Key('shell.tasks.panel');
  static const Key clearDoneKey = Key('shell.tasks.clearDone');
  static Key rowKey(String jobId) => ValueKey<String>('shell.tasks.row.$jobId');
  static Key cancelKey(String jobId) => ValueKey<String>('shell.tasks.cancel.$jobId');
  static Key locateKey(String jobId) => ValueKey<String>('shell.tasks.locate.$jobId');
  static Key progressKey(String jobId) => ValueKey<String>('shell.tasks.progress.$jobId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final List<JobState> jobs = orderTasks(ref.watch(jobsRegistryProvider));
    final bool hasTerminal = jobs.any((JobState j) => j.isTerminal);
    // 浮层与它下面的路由共享祖先，但 Overlay 里没有 Material：文字默认样式要自己给一层。
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: panelKey,
        width: width,
        // 与铃铛下拉面板同一个高度上限，行多了在中间滚动。
        constraints: const BoxConstraints(maxHeight: InkToastSize.historyMaxHeight),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface4,
          border: Border.all(color: c.overlayBorder),
          borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
          boxShadow: InkShadow.overlay,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.borderStrong)),
              ),
              child: Row(
                children: <Widget>[
                  Text(l.taskPopoverTitle, style: t.bodyStrong.copyWith(color: c.fg1)),
                  const Spacer(),
                  Text(
                    l.renderQueueConcurrency(kDefaultGlobalConcurrency),
                    style: t.meta.copyWith(color: c.fg5),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                // 浮层与它下面的路由共享祖先：别去认领路由的 PrimaryScrollController。
                primary: false,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final JobState job in jobs) _TaskRow(key: rowKey(job.jobId), job: job),
                ],
              ),
            ),
            Container(
              height: footerHeight,
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              alignment: Alignment.centerLeft,
              child: InkActivatable(
                key: clearDoneKey,
                // 没有终态 job ⇒ null：不可点、也不可聚焦（不挂空闭包）。
                onTap: hasTerminal ? () => ref.read(jobsRegistryProvider.notifier).clearTerminated() : null,
                focusRingRadius: BorderRadius.circular(InkRadius.xs),
                builder: (BuildContext context, bool hovered, bool focused) => Text(
                  l.renderQueueClearDone,
                  style: t.meta.copyWith(
                    color: !hasTerminal ? c.fg6 : (hovered ? c.fg3 : c.fg5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一行任务：内边距上下 10、左右 12，下沿 borderSubtle。
class _TaskRow extends ConsumerWidget {
  const _TaskRow({super.key, required this.job});

  final JobState job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;

    final CanvasNode? source = _sourceOf(ref, job);
    final String provider = ref.watch(providerDisplayNamesProvider)[job.providerId] ?? job.providerId;
    final String name = source != null ? nodeDisplayName(context, source) : provider;
    final String status = switch (job) {
      JobQueued() || JobSubmitting() => l.canvasRenderQueueStatusQueued,
      JobRunning() => l.renderQueueStatusRunning,
      JobSucceeded() => l.renderQueueStatusDone,
      JobFailed() => l.renderQueueStatusFailed,
      JobCancelled() => l.renderQueueStatusCancelled,
    };
    final String? errorTip = switch (job) {
      JobFailed(:final InkError error) => l10nError(context, error),
      _ => null,
    };
    final Widget meta = Text(
      <String>[provider, status].join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.micro.copyWith(color: c.fg5),
    );

    final Widget? action;
    if (job.isCancellable) {
      action = _ActionLink(
        key: ShellTaskPopover.cancelKey(job.jobId),
        label: l.commonCancel,
        tooltip: l.canvasRenderQueueCancel,
        color: c.fg4,
        onTap: () => _cancel(ref, job.jobId),
      );
    } else {
      final VoidCallback? locate = _locateAction(ref, job, source);
      action = locate == null
          ? null
          : _ActionLink(
              key: ShellTaskPopover.locateKey(job.jobId),
              label: l.renderQueueLocate,
              color: c.accent,
              onTap: locate,
            );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: c.fg2),
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(width: InkSpacing.sm),
                action,
              ],
            ],
          ),
          const SizedBox(height: InkSpacing.s2),
          if (errorTip == null) meta else Tooltip(message: errorTip, child: meta),
          if (job is JobRunning) ...<Widget>[
            const SizedBox(height: InkSpacing.sm),
            _ProgressBar(key: ShellTaskPopover.progressKey(job.jobId), fraction: job.progressValue),
          ],
        ],
      ),
    );
  }

  /// 源节点：job 所在画布的节点控制器里按 sourceNodeId 找（没有 / 已删 / 还在加载 ⇒ null）。
  static CanvasNode? _sourceOf(WidgetRef ref, JobState job) {
    final String? id = job.sourceNodeId;
    if (id == null) return null;
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(job.canvasId)).valueOrNull ?? const <CanvasNode>[];
    for (final CanvasNode n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// 「定位」：终态 + 源节点还在 + （同一画布，或拿得到目标项目的 ProjectRef）才给；否则 null（不画）。
  static VoidCallback? _locateAction(WidgetRef ref, JobState job, CanvasNode? source) {
    if (!job.isTerminal || source == null) return null;
    final ({String? canvasId, ProjectRef? project}) shell = ref.watch(
      shellControllerProvider.select(
        (ShellState s) => (canvasId: s.canvasId, project: s.project),
      ),
    );
    final ShellNavigator nav = ref.read(shellControllerProvider.notifier);
    void requestFocus() => ref
        .read(canvasFocusRequestProvider.notifier)
        .request(canvasId: job.canvasId, nodeId: source.id);
    if (shell.canvasId == job.canvasId) {
      return () {
        nav.goTab(ShellTab.canvas);
        requestFocus();
      };
    }
    final ProjectRef? project = _projectFor(ref, job.projectId, shell.project);
    if (project == null) return null;
    return () {
      nav.openCanvas(job.canvasId, withProject: project);
      requestFocus();
    };
  }

  /// 换画布要带的项目引用：任务属于外壳当前项目就用它；否则从 Studio 一直开着的工作库列表里找名字
  /// （没人看着时不为一个链接去起它）；都拿不到 ⇒ null。
  static ProjectRef? _projectFor(WidgetRef ref, String? projectId, ProjectRef? current) {
    if (projectId == null) return null;
    if (current != null && current.id == projectId) return current;
    if (!ref.exists(workspaceProjectsProvider)) return null;
    final List<ProjectWithCanvases> projects =
        ref.watch(workspaceProjectsProvider).valueOrNull ?? const <ProjectWithCanvases>[];
    for (final ProjectWithCanvases p in projects) {
      if (p.id == projectId) return ProjectRef(id: p.id, name: p.name);
    }
    return null;
  }

  // 取消链路复用核心服务：拿到 JobQueueService 后委托 cancel（幂等）。
  static Future<void> _cancel(WidgetRef ref, String jobId) async {
    final JobQueueService queue = await ref.read(jobQueueServiceProvider.future);
    await queue.cancel(jobId);
  }
}

/// 行尾的 11 号文字动作（取消 / 定位）。
class _ActionLink extends StatelessWidget {
  const _ActionLink({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return InkActivatable(
      onTap: onTap,
      tooltip: tooltip,
      focusRingRadius: BorderRadius.circular(InkRadius.xs),
      builder: (BuildContext context, bool hovered, bool focused) => Text(
        label,
        style: context.inkTypography.meta.copyWith(color: color),
      ),
    );
  }
}

/// 运行中的进度条：4 高、control 底、accent 填充、圆角 2（与通知卡的进度条同高）。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    return Container(
      height: InkToastSize.progress,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.control,
        borderRadius: BorderRadius.circular(InkRadius.xs),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: ColoredBox(color: c.accent),
      ),
    );
  }
}
