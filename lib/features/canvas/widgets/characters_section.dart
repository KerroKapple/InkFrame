// CharactersSection：config 节点角色区（CH-2 起 image/video inspector 共享）。
// 把项目级角色挂到节点（写 type_config.character_ids）+ 存为角色/从文件导入。
// ref 支持判定按调用方口径参数化：image 要求 maxRefImages>0 且 imageToImage;
// video 对齐 CH-1 注入门只要 maxRefImages>0（不检查 modes——r2v/omni 的参考图
// 语义不落在 modes 里，见 generation_controller._injectCharacterRefs 拍板注释）。
// InspectorNameDialog / CharacterChip 一并公开——_PresetsSection 亦复用。

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/character_assets.dart';
import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/primitives/ink_dashed_slot.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/character.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/characters_controller.dart';
import '../providers/inspector_submit_controller.dart';

/// 项目级角色一致性：把可复用角色挂到本 config 节点（写 type_config.character_ids），
/// 并支持把已连的参考图「存为角色」。仅当 provider 支持参考图时真正生效（否则给提示）。
class CharactersSection extends ConsumerStatefulWidget {
  const CharactersSection({
    super.key,
    required this.targetNode,
    required this.selectedCaps,
    required this.requireImageToImageMode,
  });

  final CanvasNode targetNode;
  final ProviderCapabilities? selectedCaps;

  /// image inspector 传 true（维持原门）；video inspector 传 false（CH-1 口径）。
  final bool requireImageToImageMode;

  @override
  ConsumerState<CharactersSection> createState() => _CharactersSectionState();
}

class _CharactersSectionState extends ConsumerState<CharactersSection> {
  late Set<String> _attachedIds;

  @override
  void initState() {
    super.initState();
    _attachedIds = _readAttached(widget.targetNode.typeConfig);
  }

  Set<String> _readAttached(Map<String, Object?> tc) {
    final raw = tc['character_ids'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
    }
    return <String>{};
  }

  InspectorSubmitController get _submitCtrl => ref.read(
    inspectorSubmitControllerProvider(widget.targetNode.id).notifier,
  );

  bool get _supportsRefs {
    final caps = widget.selectedCaps;
    if (caps == null || caps.maxRefImages <= 0) return false;
    return !widget.requireImageToImageMode ||
        caps.modes.contains(GenerationMode.imageToImage);
  }

  void _toggle(String id) {
    setState(() {
      if (!_attachedIds.add(id)) _attachedIds.remove(id);
    });
    _submitCtrl.saveConfig(<String, Object?>{
      'character_ids': _attachedIds.toList(growable: false),
    });
  }

  /// 角色首张参考图缩略图绝对路径；无图 / 越权路径 → null 不渲染。
  String? _characterThumb(String projectId, Character c) {
    if (c.referenceImagePaths.isEmpty) return null;
    try {
      return ref.read(characterAssetServiceProvider).absolutePathOf(
        projectId: projectId,
        relativePath: c.referenceImagePaths.first,
      );
    } on CharacterAssetError {
      return null;
    }
  }

  /// 本 config 节点第一条 reference data 边上、带 image_url 的源节点（"存为角色"来源）。
  CanvasNode? _referenceSource() {
    final canvasId = widget.targetNode.canvasId;
    if (canvasId == null) return null;
    final edges =
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];
    final nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasNode>[];
    final nodesById = {for (final n in nodes) n.id: n};
    for (final e in edges) {
      if (e.targetNodeId != widget.targetNode.id ||
          e.edgeType != EdgeType.data ||
          e.role != EdgeRole.reference) {
        continue;
      }
      final src = nodesById[e.sourceNodeId];
      if (src != null && (src.imageUrl?.isNotEmpty ?? false)) return src;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.targetNode.projectId;
    if (projectId == null) return const SizedBox.shrink();
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final charactersAsync = ref.watch(charactersControllerProvider(projectId));
    final characters = charactersAsync.valueOrNull ?? const <Character>[];
    final refSource = _referenceSource();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.inspectorCharactersLabel,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.xs),
        if (!_supportsRefs)
          Padding(
            padding: const EdgeInsets.only(bottom: InkSpacing.xs),
            child: Text(
              context.l10n.inspectorCharactersUnsupported,
              style: typo.caption.copyWith(color: colors.warning),
            ),
          ),
        // 加载失败 → 错误横幅（此前静默降级为空 = 误报"无角色"）。
        if (charactersAsync.hasError)
          InkErrorBanner(
            message: l10nAsyncError(context, charactersAsync.error!),
          )
        else if (characters.isEmpty)
          InkDashedSlot(
            onPressed: _importFromFile,
            child: Text(
              context.l10n.inspectorCharactersEmpty,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
          )
        else
          Wrap(
            spacing: InkSpacing.xs,
            runSpacing: InkSpacing.xs,
            children: [
              for (final c in characters)
                CharacterChip(
                  label: c.name.isNotEmpty ? c.name : c.id,
                  selected: _attachedIds.contains(c.id),
                  onTap: () => _toggle(c.id),
                  thumbPath: _characterThumb(projectId, c),
                ),
            ],
          ),
        const SizedBox(height: InkSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: refSource == null
                ? null
                : () => _createFromReference(refSource),
            icon: const Icon(Icons.person_add_alt_1, size: 16),
            label: Text(context.l10n.inspectorCharactersSaveFromReference),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _importFromFile,
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(context.l10n.inspectorCharactersImportFile),
          ),
        ),
      ],
    );
  }

  /// 从磁盘选图新建角色（file_selector，桌面）。不依赖已连参考图，补齐首个角色的种子路径。
  Future<void> _importFromFile() async {
    final projectId = widget.targetNode.projectId;
    if (projectId == null) return;
    const group = XTypeGroup(
      label: 'images',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null || !mounted) return;
    final name = await _promptName(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref
          .read(charactersControllerProvider(projectId).notifier)
          .createFromImage(name: name.trim(), sourceAbsolutePath: file.path);
      if (mounted) _toggle(id);
    } on InkError catch (_) {
      // 导入失败不崩 UI，但要提示（此前静默吞错 = 假成功）。
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.inspectorCharactersImportFailed)),
      );
    }
  }

  Future<void> _createFromReference(CanvasNode source) async {
    final canvasId = widget.targetNode.canvasId;
    final projectId = widget.targetNode.projectId;
    final rel = source.imageUrl;
    if (canvasId == null || projectId == null || rel == null || rel.isEmpty) {
      return;
    }
    final String abs;
    try {
      abs = ref
          .read(fileResolverServiceProvider)
          .resolve(projectId: projectId, canvasId: canvasId, relativePath: rel)
          .path;
    } on PathSecurityError catch (_) {
      return;
    }
    final name = await _promptName(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref
          .read(charactersControllerProvider(projectId).notifier)
          .createFromImage(name: name.trim(), sourceAbsolutePath: abs);
      if (mounted) _toggle(id);
    } on InkError catch (_) {
      // 导入/落库失败不崩 UI，但要提示（下次可重试）。
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.inspectorCharactersImportFailed)),
      );
    }
  }

  Future<String?> _promptName(BuildContext context) => showDialog<String>(
    context: context,
    builder: (ctx) => InspectorNameDialog(
      title: ctx.l10n.inspectorCharactersDialogTitle,
      hint: ctx.l10n.inspectorCharactersNameHint,
      confirmLabel: ctx.l10n.inspectorCharactersSave,
      cancelLabel: ctx.l10n.commonCancel,
    ),
  );
}

/// 命名对话框。TextEditingController 生命周期归 dialog 自身——退场动画期间
/// TextField 仍引用 controller，调用方在 showDialog 返回后立即 dispose 会炸。
class InspectorNameDialog extends StatefulWidget {
  const InspectorNameDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<InspectorNameDialog> createState() => _InspectorNameDialogState();
}

class _InspectorNameDialogState extends State<InspectorNameDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: InkInput(controller: _ctrl, hintText: widget.hint),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// 角色 chip 缩略图边长（正方形裁切）。
const double _kCharacterThumbSize = 20;

class CharacterChip extends StatelessWidget {
  const CharacterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.thumbPath,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? thumbPath;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InkRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.sm,
          vertical: InkSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface2,
          borderRadius: BorderRadius.circular(InkRadius.sm),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thumbPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(InkRadius.sm),
                child: Image.file(
                  File(thumbPath!),
                  width: _kCharacterThumbSize,
                  height: _kCharacterThumbSize,
                  fit: BoxFit.cover,
                  // LB-23：微缩略图按显示尺寸缩略解码。
                  cacheWidth: (_kCharacterThumbSize *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  // 缺文件/坏图占位，不崩 UI。
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person_outline,
                    size: 14,
                    color: selected ? colors.onAccent : colors.fg3,
                  ),
                ),
              ),
              const SizedBox(width: InkSpacing.xs),
            ],
            if (selected) ...[
              Icon(Icons.check, size: 14, color: colors.onAccent),
              const SizedBox(width: InkSpacing.xs),
            ],
            Text(
              label,
              style: typo.caption.copyWith(
                color: selected ? colors.onAccent : colors.fg1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
