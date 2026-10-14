// JobNotificationListener：jobsRegistry 的新终态 → 应用级通知卡（生成完成 / 生成失败）。
//
// 挂在 ToastLayer 里（MaterialApp.builder 那一层），与哪个标签在台上、哪张画布开着都
// 无关。以前失败只由 CanvasJobListener 在【当前画布】上弹，切走画布 / 项目就没了；
// 现在 CanvasJobListener 只管画布刷新，通知全在这里——一条 job 只通知一次。
//
// 【只认「这一次变成终态」的 job】registry 会长期留着终态条目，别的 job 任何一次变化都会
// 把整张表再发一遍：prev 里已经是终态的一律跳过，再按 jobId 记账兜底（gallery_dirty.dart
// 同一做法）。取消不通知——那是用户自己刚做的事。
//
// 【尽量不为一张通知卡去查库】
// - 标题里的节点名只从【还活着的】画布节点控制器里拿（任务所在画布正开着时就有）；
//   拿不到就用泛化标题。
// - 缩略图：图片任务的 artifactPath 本身就是 image_url，直接用。视频读 result 节点的
//   thumbnail_url：先看活着的控制器，可成功那一刻那里的 result 节点通常还是占位版本
//  （CanvasJobListener 发起的重拉还没回来），所以拿不到时按 resultNodeId 读一次库——
//   首帧缩略图在发出成功之前就已写进 type_config。读失败就落到类型图标，不拦通知。
// - 「查看」要一个 ProjectRef（外壳换项目必须带名字）：任务属于外壳当前项目时直接用它，
//   否则从 Studio 一直开着的工作库列表里找名字；都拿不到就不给这个按钮，绝不挂一个
//   点了没反应的按钮。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/file_resolver.dart';
import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/node_repository.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../../studio/models/project_with_canvases.dart';
import '../../studio/providers/workspace_projects_provider.dart';
import '../providers/toast_service_provider.dart';

/// artifactPath 落在这些扩展名上 ⇒ 它本身就是图，可直接当缩略图。
const Set<String> _kImageExtensions = <String>{'.png', '.jpg', '.jpeg', '.webp'};

class JobNotificationListener extends ConsumerStatefulWidget {
  const JobNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<JobNotificationListener> createState() =>
      _JobNotificationListenerState();
}

class _JobNotificationListenerState
    extends ConsumerState<JobNotificationListener> {
  /// 已经通知过的 jobId（见文件头「只认这一次变成终态的 job」）。
  final Set<String> _notified = <String>{};

  @override
  Widget build(BuildContext context) {
    ref.listen<List<JobState>>(jobsRegistryProvider, _onJobs);
    return widget.child;
  }

  void _onJobs(List<JobState>? prev, List<JobState> next) {
    final Map<String, JobState> before = <String, JobState>{
      for (final JobState j in prev ?? const <JobState>[]) j.jobId: j,
    };
    for (final JobState job in next) {
      if (!job.isTerminal) continue;
      if (before[job.jobId]?.isTerminal ?? false) continue;
      if (!_notified.add(job.jobId)) continue;
      if (job is JobSucceeded) {
        _notifySucceeded(job).ignore();
      } else if (job is JobFailed) {
        _notifyFailed(job);
      }
    }
  }

  Future<void> _notifySucceeded(JobSucceeded job) async {
    // 文案与动作在 await 之前取：之后 context 可能已经不在树上。
    final AppLocalizations l = context.l10n;
    final List<CanvasNode>? nodes = _aliveNodes(job.canvasId);
    final String? label = _labelOf(_find(nodes, job.sourceNodeId));
    final ToastAction? view = _viewAction(job);
    String? thumbnail = _thumbnailPath(job, nodes);
    if (thumbnail == null && !_isImage(job.artifactPath)) {
      thumbnail = await _storedThumbnail(job);
      if (!mounted) return;
    }
    ref.read(toastServiceProvider).show(
          label == null
              ? l.jobNotifySucceededGeneric
              : l.jobNotifySucceeded(label),
          kind: ToastKind.success,
          thumbnailPath: thumbnail,
          primary: view,
          chime: true,
        );
  }

  static bool _isImage(String path) =>
      _kImageExtensions.contains(p.extension(path).toLowerCase());

  /// 视频任务：按 resultNodeId 读一次库里的 result 节点，拿首帧缩略图。读不到就 null。
  Future<String?> _storedThumbnail(JobSucceeded job) async {
    final String? resultNodeId = job.resultNodeId;
    if (resultNodeId == null || job.projectId == null) return null;
    try {
      final NodeRepository repo = await ref.read(nodeRepositoryProvider.future);
      final Map<String, Object?>? row = await repo.findById(resultNodeId);
      final String? relative =
          row == null ? null : CanvasNodeMapping.fromRow(row).thumbnailUrl;
      return relative == null ? null : _resolve(job, relative);
    } on InkError {
      return null;
    }
  }

  void _notifyFailed(JobFailed job) {
    final AppLocalizations l = context.l10n;
    final String? label =
        _labelOf(_find(_aliveNodes(job.canvasId), job.sourceNodeId));
    ref.read(toastServiceProvider).show(
          label == null ? l.jobNotifyFailedGeneric : l.jobNotifyFailed(label),
          kind: ToastKind.error,
          body: l10nError(context, job.error),
          // 失败卡不自动消失：同一个节点反复失败只占一张，换成最新那次的原因。
          dedupeKey: 'job-failed:${job.sourceNodeId ?? job.jobId}',
          chime: true,
        );
  }

  /// 任务所在画布的节点——只在它的控制器本来就活着时拿；不为一个标题去起查询。
  List<CanvasNode>? _aliveNodes(String canvasId) {
    final provider = canvasNodesControllerProvider(canvasId);
    if (!ref.exists(provider)) return null;
    return ref.read(provider).valueOrNull;
  }

  static CanvasNode? _find(List<CanvasNode>? nodes, String? id) {
    if (nodes == null || id == null) return null;
    for (final CanvasNode n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  static String? _labelOf(CanvasNode? node) {
    final String? label = node?.label.trim();
    return label == null || label.isEmpty ? null : label;
  }

  String? _thumbnailPath(JobSucceeded job, List<CanvasNode>? nodes) {
    final String artifact = job.artifactPath;
    final CanvasNode? result = _find(nodes, job.resultNodeId);
    final String? relative = _isImage(artifact)
        ? artifact
        : result?.thumbnailUrl ?? result?.imageUrl;
    return relative == null ? null : _resolve(job, relative);
  }

  /// 画布相对路径 → 绝对路径；越出项目目录（PathSecurityError）当作没有。
  String? _resolve(JobSucceeded job, String relative) {
    final String? projectId = job.projectId;
    if (projectId == null) return null;
    try {
      return ref
          .read(fileResolverServiceProvider)
          .resolve(
            projectId: projectId,
            canvasId: job.canvasId,
            relativePath: relative,
          )
          .path;
    } on PathSecurityError {
      return null;
    }
  }

  /// 「查看」：打开产物所在画布并选中 result 节点（与画廊「在画布中定位」同一做法，
  /// gallery_actions.dart）。拿不到项目名就不给按钮。
  ToastAction? _viewAction(JobSucceeded job) {
    final String? nodeId = job.resultNodeId;
    final ProjectRef? project = _projectRef(job.projectId);
    if (nodeId == null || project == null) return null;
    final String canvasId = job.canvasId;
    return ToastAction(context.l10n.toastActionView, () {
      if (!mounted) return;
      ref
          .read(shellControllerProvider.notifier)
          .openCanvas(canvasId, withProject: project);
      ref
          .read(canvasSelectionControllerProvider(canvasId).notifier)
          .select(nodeId);
    });
  }

  ProjectRef? _projectRef(String? projectId) {
    if (projectId == null) return null;
    final ProjectRef? current = ref.read(shellControllerProvider).project;
    if (current != null && current.id == projectId) return current;
    // 工作库列表由 Studio 标签一直看着（保活）；没人看着时不为一个按钮去起它。
    if (!ref.exists(workspaceProjectsProvider)) return null;
    final List<ProjectWithCanvases> projects =
        ref.read(workspaceProjectsProvider).valueOrNull ??
            const <ProjectWithCanvases>[];
    for (final ProjectWithCanvases project in projects) {
      if (project.id == projectId) {
        return ProjectRef(id: project.id, name: project.name);
      }
    }
    return null;
  }
}
