// ShotConfigInspector：单选 shot 节点时的最简参数面板（分镜骨架）。
//
// shot 是真实节点类型（image/text/video/shot），此前无编辑面板。本面板先提供分镜
// 备注（type_config.shot_notes），作为后续 storyboard→shot→序列 流水线的编辑起点。
// 持久化经 InspectorSubmitController.saveConfig（防抖），与 image/video 面板同构。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/inspector_submit_controller.dart';

class ShotConfigInspector extends ConsumerStatefulWidget {
  const ShotConfigInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  ConsumerState<ShotConfigInspector> createState() =>
      _ShotConfigInspectorState();
}

class _ShotConfigInspectorState extends ConsumerState<ShotConfigInspector> {
  final TextEditingController _notesCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final n = widget.node.typeConfig['shot_notes'];
    if (n is String) _notesCtrl.text = n;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref
          .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
          .saveConfig(<String, Object?>{'shot_notes': value});
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(InkSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(left: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.inspectorShotTitle,
              style: typo.title.copyWith(color: colors.fg1),
            ),
            const SizedBox(height: InkSpacing.lg),
            Text(
              context.l10n.inspectorShotNotesLabel,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.xs),
            InkInput(
              controller: _notesCtrl,
              hintText: context.l10n.inspectorShotNotesHint,
              minLines: 4,
              maxLines: 10,
              onChanged: _onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
