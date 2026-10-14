// CharactersSection：config 节点角色区（CH-2 起 image/video inspector 共享）。
// 把项目级角色挂到节点（写 type_config.character_ids）+ 存为角色/从文件导入。
// ref 支持判定按调用方口径参数化：image 要求 maxRefImages>0 且 imageToImage;
// video 对齐 CH-1 注入门只要 maxRefImages>0（不检查 modes——r2v/omni 的参考图
// 语义不落在 modes 里，见 generation_controller._injectCharacterRefs 拍板注释）。
// CharacterChip 一并公开——_PresetsSection 亦复用。命名框已收口到
// theme/components/ink_name_dialog.dart（CH-2 残留④），本文件不再自带一份。

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/character_assets.dart';
import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/components/ink_name_dialog.dart';
import '../../../theme/primitives/ink_dashed_slot.dart';
import '../../../theme/tokens.dart';
import '../../gallery/providers/gallery_graph_provider.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/character.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/characters_controller.dart';
import '../providers/inspector_submit_controller.dart';
import '../providers/left_rail_state.dart';
import '../util/ref_image_budget.dart';

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
    final String? projectId = widget.targetNode.projectId;
    // 「M 处引用」（角色库行 / 编辑框「被引用」）是从 galleryGraphProvider 数出来的，
    // 而那个投影只在画廊脏刷新时重读。挂/摘角色改的正是它数的那一列，落库后不定点
    // 失效，左栏的计数就一直停在旧值，直到用户切一趟画廊再回来。
    // 这里 invalidate 不违反「画廊不实时刷新」那条：挂角色发生在画布页，用户此刻
    // 不可能正看着画廊；等他切过去时看到的本就该是新数。
    unawaited(
      _submitCtrl
          .saveConfig(<String, Object?>{
            'character_ids': _attachedIds.toList(growable: false),
          })
          .then((_) {
            if (!mounted || projectId == null) return;
            ref.invalidate(galleryGraphProvider(projectId));
          }),
    );
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

  /// 入边的两个判据一次算完（同一份 edges/nodes，别各 watch 一遍各扫一遍）。
  /// 两个字段各自的"为什么"写在 [_InputsView] 上。
  _InputsView _inputsView() {
    final canvasId = widget.targetNode.canvasId;
    if (canvasId == null) return const _InputsView(null, 0);
    final edges =
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];
    final nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasNode>[];
    final nodesById = {for (final n in nodes) n.id: n};

    CanvasNode? saveSource;
    var edgeRefCount = 0;
    for (final e in edges) {
      if (e.targetNodeId != widget.targetNode.id ||
          e.edgeType != EdgeType.data) {
        continue;
      }
      final src = nodesById[e.sourceNodeId];
      if (src == null || !(src.imageUrl?.isNotEmpty ?? false)) continue;
      saveSource ??= src;
      // 配额只认 reference：首/尾帧走 firstFramePath/lastFramePath 两个独立字段，
      // 不进 refImagePaths（全家 refImagesIncludeKeyframes=false），不挤角色图。
      // 只数"真有图"的边——没有图的边在生成侧也解析不出参考图，不该占格子。
      if (e.role == EdgeRole.reference) edgeRefCount++;
    }
    return _InputsView(saveSource, edgeRefCount);
  }

  /// 挂载角色对参考图配额的消耗（按 `character_ids` 顺序 = 注入次序）。
  /// 口径与 `GenerationController._injectCharacterRefs` 同源，见 util/ref_image_budget.dart。
  RefImageBudgetPlan _refBudget(List<Character> all, int edgeRefCount) {
    final byId = {for (final c in all) c.id: c};
    return planRefImageBudget(
      limit: widget.selectedCaps?.maxRefImages ?? 0,
      edgeRefCount: edgeRefCount,
      characters: <CharacterRefDemand>[
        for (final id in _attachedIds)
          if (byId[id] case final Character c)
            CharacterRefDemand(
              id: c.id,
              // 名字为空回落到 id，与 chip 的显示同口径。
              name: c.name.isNotEmpty ? c.name : c.id,
              imagePaths: c.referenceImagePaths,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.targetNode.projectId;
    if (projectId == null) return const SizedBox.shrink();
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final charactersAsync = ref.watch(charactersControllerProvider(projectId));
    final characters = charactersAsync.valueOrNull ?? const <Character>[];
    final inputs = _inputsView();
    final saveSource = inputs.saveSource;
    // 配额提示只在真会注入时说（不支持参考图时已有 inspectorCharactersUnsupported）。
    final budget = _supportsRefs
        ? _refBudget(characters, inputs.edgeRefCount)
        : null;
    final shortfall = budget?.shortfall ?? const <CharacterRefOutcome>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.inspectorCharactersLabel,
              style: typo.meta.copyWith(color: colors.fg3),
            ),
            const Spacer(),
            // 「管理」= 去左栏角色页：左栏收着就先展开，再切到角色页。挂载区本身保持原样，
            // 这里只多一条去处。
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: const ValueKey<String>('characters-manage'),
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(leftRailProvider.notifier)
                    .open(LeftRailPage.characters),
                child: Text(
                  context.l10n.characterManage,
                  style: typo.micro.copyWith(color: colors.accent),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: InkSpacing.xs),
        if (!_supportsRefs)
          Padding(
            padding: const EdgeInsets.only(bottom: InkSpacing.xs),
            child: Text(
              context.l10n.inspectorCharactersUnsupported,
              style: typo.meta.copyWith(color: colors.accent),
            ),
          ),
        // CH-2 残留②：合计超限时提交前就点名——此前 provider 的 take() 从尾部
        // 截断（掉的恰是角色图），而这里一个字都不说，用户以为挂上了。
        if (shortfall.isNotEmpty && budget != null)
          Padding(
            padding: const EdgeInsets.only(bottom: InkSpacing.xs),
            child: Text(
              key: const ValueKey<String>('characters-over-limit'),
              context.l10n.inspectorCharactersOverLimit(
                budget.requested,
                budget.limit,
                shortfall.map((o) => o.name).join(' / '),
              ),
              style: typo.meta.copyWith(color: colors.accent),
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
              style: typo.meta.copyWith(color: colors.fg3),
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
          // 可用时说清存的是哪一张，不可用时说清缺什么——禁用态不再只是"静静变灰"。
          // Tooltip 包在按钮外面：onPressed==null 的按钮自己不报 hover，套在外层才提示得出来。
          child: Tooltip(
            message: saveSource == null
                ? context.l10n.inspectorCharactersSaveFromReferenceDisabled
                : context.l10n.inspectorCharactersSaveFromReferenceHint(
                    saveSource.label.isNotEmpty
                        ? saveSource.label
                        : saveSource.id,
                  ),
            child: TextButton.icon(
              onPressed: saveSource == null
                  ? null
                  : () => _createFromReference(saveSource),
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: Text(context.l10n.inspectorCharactersSaveFromReference),
            ),
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
    // 命名框开着的时候检查器可能已经被换掉（用户取消选中 / 选了别的节点）：
    // 这之后再 ref.read 就是 ref-after-dispose（BOARD 2026-09-02 CH-2 评审 ③）。
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final id = await ref
          .read(charactersControllerProvider(projectId).notifier)
          .createFromImage(name: name.trim(), sourceAbsolutePath: file.path);
      if (mounted) _toggle(id);
    } on InkError catch (_) {
      // 导入失败不崩 UI，但要提示（此前静默吞错 = 假成功）。
      _importFailed();
    } on CharacterAssetError catch (_) {
      // 捕获集 = createFromImage 的真实抛出集：仓储 InkError / 资产服务 /
      // dart:io。后两类不是 InkError，漏掉就变成未捕获异步异常。
      _importFailed();
    } on FileSystemException catch (_) {
      _importFailed();
    }
  }

  void _importFailed() {
    if (!mounted) return;
    ref.read(toastServiceProvider).show(
      context.l10n.inspectorCharactersImportFailed,
      kind: ToastKind.error,
    );
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
    // 同 _importFromFile：命名框期间检查器可能已换掉，之后再 ref.read 就是
    // ref-after-dispose（BOARD 2026-09-02 CH-2 评审 ③）。
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final id = await ref
          .read(charactersControllerProvider(projectId).notifier)
          .createFromImage(name: name.trim(), sourceAbsolutePath: abs);
      if (mounted) _toggle(id);
    } on InkError catch (_) {
      // 导入/落库失败不崩 UI，但要提示（下次可重试）。
      _importFailed();
    } on CharacterAssetError catch (_) {
      _importFailed();
    } on FileSystemException catch (_) {
      _importFailed();
    }
  }

  Future<String?> _promptName(BuildContext context) => showDialog<String>(
    context: context,
    builder: (ctx) => InkNameDialog(
      title: ctx.l10n.inspectorCharactersDialogTitle,
      hint: ctx.l10n.inspectorCharactersNameHint,
      confirmLabel: ctx.l10n.inspectorCharactersSave,
      cancelLabel: ctx.l10n.commonCancel,
    ),
  );
}

/// data 入边扫一遍得到的两个判据。
@immutable
class _InputsView {
  const _InputsView(this.saveSource, this.edgeRefCount);

  /// 第一条**带 image_url 的 data 入边**的源节点（"存为角色"的来源）。
  ///
  /// 【为什么不看 role】（CH-2 残留①）边的 role 说的是「这张图在生成里当什么用」
  /// ——首帧、尾帧还是参考图；而"存为角色"只是「把这张图留下来复用」，跟它在本次
  /// 生成里的用途无关。此前这里要求 role==reference，而 image→video 的默认连线是
  /// first_frame（`link_action_controller._defaultRole`），于是正常连法下按钮恒灰，
  /// 用户必须先把边切成 reference 才存得了——等于这个功能在默认路径上不存在。
  ///
  /// 选第一条有图的入边 = 检查器「关键帧」组里最上面那一行：两处读的是同一份
  /// `canvasEdgesControllerProvider`，而它的顺序来自 `ORDER BY sort_order, created_at`，
  /// 所以"存哪一张"是用户看得到的，不是隐式优先级。
  final CanvasNode? saveSource;

  /// 占参考图配额的入边张数（只数 reference，见 util/ref_image_budget.dart 头注）。
  final int edgeRefCount;
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
          border: Border.all(color: selected ? colors.accent : colors.outline),
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
              style: typo.meta.copyWith(
                color: selected ? colors.onAccent : colors.fg1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
