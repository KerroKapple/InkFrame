// 导出视频对话框：video result 勾选（默认全选）+ 手动排序（默认按 position.x
// 升序=分镜从左到右）+ 输出名预校验 + concat 触发与成败反馈。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/components/ink_progress_bar.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_node.dart';
import '../providers/export_controller.dart';
import '../util/export_file_name.dart';

/// 顶栏入口与对话框共用的过滤：role==result、type==video、videoUrl 非空、
/// canvasId 非空——与 ExportController.export 的输入条件一致，
/// 消除「列表可见但导出时静默丢弃」的错位。
List<CanvasNode> exportableVideoNodes(List<CanvasNode> nodes) => <CanvasNode>[
      for (final n in nodes)
        if (n.role == NodeRole.result &&
            n.type == CanvasNodeType.video &&
            n.videoUrl != null &&
            n.canvasId != null)
          n,
    ];

/// 打开导出对话框。[videoNodes] 须已经过 [exportableVideoNodes] 过滤，
/// 排序在对话框内完成。
Future<void> showExportVideoDialog(
  BuildContext context, {
  required String projectId,
  required List<CanvasNode> videoNodes,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ExportVideoDialog(
      projectId: projectId,
      videoNodes: videoNodes,
    ),
  );
}

class _ExportVideoDialog extends ConsumerStatefulWidget {
  const _ExportVideoDialog({
    required this.projectId,
    required this.videoNodes,
  });

  final String projectId;
  final List<CanvasNode> videoNodes;

  @override
  ConsumerState<_ExportVideoDialog> createState() => _ExportVideoDialogState();
}

class _ExportVideoDialogState extends ConsumerState<_ExportVideoDialog> {
  late final List<CanvasNode> _rows;
  late final Set<String> _selected;
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rows = <CanvasNode>[...widget.videoNodes]..sort((a, b) {
        final byX = a.position.dx.compareTo(b.position.dx);
        return byX != 0 ? byX : a.id.compareTo(b.id);
      });
    _selected = <String>{for (final n in _rows) n.id};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _trimmedName => _nameCtrl.text.trim();

  bool get _nameValid =>
      _trimmedName.isEmpty || isValidExportBaseName(_trimmedName);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final busy = ref.watch(exportControllerProvider) is ExportVideoBusy;
    final canExport = !busy && _selected.isNotEmpty && _nameValid;

    return PopScope(
      canPop: !busy,
      child: Dialog(
        backgroundColor: colors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkRadius.lg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(InkSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l.exportVideoDialogTitle,
                  style: typo.title.copyWith(color: colors.fg1),
                ),
                const SizedBox(height: InkSpacing.xs),
                Text(
                  l.exportVideoDialogHint,
                  style: typo.caption.copyWith(color: colors.fg3),
                ),
                const SizedBox(height: InkSpacing.md),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: InkSpacing.xs),
                    itemBuilder: (context, i) => _row(context, i, busy: busy),
                  ),
                ),
                const SizedBox(height: InkSpacing.md),
                Text(
                  l.exportVideoOutputNameLabel,
                  style: typo.label.copyWith(color: colors.fg2),
                ),
                const SizedBox(height: InkSpacing.xs),
                InkInput(
                  controller: _nameCtrl,
                  hintText: l.exportVideoOutputNameHint,
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                ),
                if (!_nameValid) ...<Widget>[
                  const SizedBox(height: InkSpacing.xs),
                  Text(
                    l.exportVideoInvalidName,
                    style: typo.caption.copyWith(color: colors.danger),
                  ),
                ],
                if (busy) ...<Widget>[
                  const SizedBox(height: InkSpacing.md),
                  const InkProgressBar(),
                ],
                const SizedBox(height: InkSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).pop(),
                      child: Text(l.commonCancel),
                    ),
                    const SizedBox(width: InkSpacing.sm),
                    FilledButton(
                      onPressed: canExport ? _onExport : null,
                      child: Text(l.exportVideoStart),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int index, {required bool busy}) {
    final l = context.l10n;
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final node = _rows[index];
    final fileName = node.videoUrl?.split('/').last ?? '';
    final title = node.label.isEmpty ? fileName : node.label;
    final canMoveUp = !busy && index > 0;
    final canMoveDown = !busy && index < _rows.length - 1;

    return Row(
      children: <Widget>[
        Checkbox(
          value: _selected.contains(node.id),
          onChanged: busy
              ? null
              : (v) => setState(() {
                    if (v ?? false) {
                      _selected.add(node.id);
                    } else {
                      _selected.remove(node.id);
                    }
                  }),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: typo.body.copyWith(color: colors.fg1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                fileName,
                style: typo.caption.copyWith(color: colors.fg3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l.exportVideoMoveUp,
          icon: Icon(
            Icons.arrow_upward,
            size: InkSpacing.md,
            color: canMoveUp ? colors.fg2 : colors.fg4,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          splashRadius: 16,
          onPressed: canMoveUp ? () => _move(index, -1) : null,
        ),
        IconButton(
          tooltip: l.exportVideoMoveDown,
          icon: Icon(
            Icons.arrow_downward,
            size: InkSpacing.md,
            color: canMoveDown ? colors.fg2 : colors.fg4,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          splashRadius: 16,
          onPressed: canMoveDown ? () => _move(index, 1) : null,
        ),
      ],
    );
  }

  void _move(int index, int delta) {
    setState(() {
      final node = _rows.removeAt(index);
      _rows.insert(index + delta, node);
    });
  }

  Future<void> _onExport() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final resolver = ref.read(fileResolverServiceProvider);
    final ordered = <CanvasNode>[
      for (final n in _rows)
        if (_selected.contains(n.id)) n,
    ];
    final name = _trimmedName;

    await ref.read(exportControllerProvider.notifier).export(
          projectId: widget.projectId,
          nodes: ordered,
          outputBaseName: name.isEmpty ? null : name,
        );
    if (!mounted) return;

    switch (ref.read(exportControllerProvider)) {
      case ExportVideoSuccess(:final relativePath):
        final absolutePath = _absolutePath(resolver, relativePath);
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.exportVideoSuccess(relativePath)),
            action: absolutePath == null
                ? null
                : SnackBarAction(
                    label: l.exportVideoCopyPath,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: absolutePath),
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l.exportVideoPathCopied),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
          ),
        );
      case ExportVideoFailure(:final error):
        messenger.showSnackBar(SnackBar(content: Text(_failureText(error))));
      case ExportVideoIdle() || ExportVideoBusy():
        break; // export() 收敛后不会停在这两态。
    }
  }

  String? _absolutePath(FileResolverService resolver, String relativePath) {
    try {
      return resolver
          .resolveInProject(
            projectId: widget.projectId,
            relativePath: relativePath,
          )
          .path;
    } on PathSecurityError {
      return null;
    }
  }

  /// ffmpeg 缺失是可行动的环境问题，通用 errorLocalIO 文案有误导——走专门文案。
  String _failureText(InkError e) {
    if (e is LocalIOError && e.extra['reason'] == 'ffmpeg_not_found') {
      return context.l10n.exportVideoFfmpegMissing;
    }
    return l10nError(context, e);
  }
}
