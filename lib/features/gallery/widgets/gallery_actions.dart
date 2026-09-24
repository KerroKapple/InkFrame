// 画廊的两个真动作（稿上有、仓库也有后端的）：
//   - 存为角色：GA-4 的 charactersController.createFromImage（原 tile 菜单里的逻辑搬到这里，
//     供标签栏按钮 / 右栏共用）
//   - 在画布中定位：打开产物所在画布并选中它的节点
// 稿上的「发送到画布」「派生新节点」没有对应后端，不画（见 PR #235）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/character_asset_service.dart' show CharacterAssetError;
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../canvas/providers/characters_controller.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../models/gallery_item.dart';

/// canvas 双参根解析；非法路径 → null。
File? galleryResolveFile(WidgetRef ref, {required String projectId, required String canvasId, required String relativePath}) {
  try {
    return ref.read(fileResolverServiceProvider).resolve(
          projectId: projectId,
          canvasId: canvasId,
          relativePath: relativePath,
        );
  } on PathSecurityError {
    return null;
  }
}

/// 打开产物所在画布并选中它的节点（result 节点本身；批量 slot 选它的 config 节点）。
void galleryLocateInCanvas(WidgetRef ref, {required ProjectRef project, required GalleryItem item}) {
  ref.read(shellControllerProvider.notifier).openCanvas(item.canvasId, withProject: project);
  ref.read(canvasSelectionControllerProvider(item.canvasId).notifier).select(item.nodeId);
}

/// GA-4：命名 → charactersController.createFromImage（补偿逻辑在控制器内）。
///
/// 抛出集与控制器注释对齐：InkError / CharacterAssetError / FileSystemException 三类全捕。
/// in-flight 防重由调用方的 [busy] 闸门负责（串行队列只保证不并发、不保证不重复）。
Future<void> gallerySaveAsCharacter(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required GalleryItem item,
}) async {
  final String? name = await showDialog<String>(
    context: context,
    builder: (_) => const GalleryCharacterNameDialog(),
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  // await 前预取（PLAYBOOK §5.1：跨异步边界不再碰 context）。
  final l = context.l10n;
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final File? file = galleryResolveFile(ref, projectId: projectId, canvasId: item.canvasId, relativePath: item.relativePath);
  // existsSync 守卫：tile 显示 broken 占位时按钮照样可点。
  if (file == null || !file.existsSync()) {
    messenger?.showSnackBar(SnackBar(content: Text(l.inspectorCharactersImportFailed)));
    return;
  }
  // listenManual 保活 autoDispose family 至操作完成；先 await build 再调 createFromImage。
  final ProviderSubscription<AsyncValue<Object?>> sub =
      ref.listenManual(charactersControllerProvider(projectId), (_, _) {});
  try {
    await ref.read(charactersControllerProvider(projectId).future);
    if (!context.mounted) return;
    await ref
        .read(charactersControllerProvider(projectId).notifier)
        .createFromImage(name: name.trim(), sourceAbsolutePath: file.path);
    messenger?.showSnackBar(SnackBar(content: Text(l.gallerySavedAsCharacter)));
  } on InkError catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(l.inspectorCharactersImportFailed)));
  } on CharacterAssetError catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(l.inspectorCharactersImportFailed)));
  } on FileSystemException catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(l.inspectorCharactersImportFailed)));
  } finally {
    sub.close();
  }
}

/// 角色命名对话框（复用 inspector 的 ARB 键；返回名字或 null=取消）。
class GalleryCharacterNameDialog extends StatefulWidget {
  const GalleryCharacterNameDialog({super.key});

  @override
  State<GalleryCharacterNameDialog> createState() => _GalleryCharacterNameDialogState();
}

class _GalleryCharacterNameDialogState extends State<GalleryCharacterNameDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.inkColors;
    return AlertDialog(
      backgroundColor: colors.surface1,
      title: Text(l.inspectorCharactersDialogTitle),
      content: InkInput(
        controller: _ctrl,
        hintText: l.inspectorCharactersNameHint,
        onChanged: (_) => setState(() {}),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _ctrl.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_ctrl.text),
          child: Text(l.inspectorCharactersSave),
        ),
      ],
    );
  }
}
