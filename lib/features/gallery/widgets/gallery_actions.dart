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
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/components/ink_name_dialog.dart';
import '../../canvas/providers/canvas_focus_request.dart';
import '../../canvas/providers/characters_controller.dart';
import '../../notifications/providers/toast_service_provider.dart';
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

/// 打开产物所在画布，挂上来后选中它的节点并移到视口中心（result 节点本身；批量 slot 选它的
/// config 节点）。
void galleryLocateInCanvas(WidgetRef ref, {required ProjectRef project, required GalleryItem item}) {
  ref.read(shellControllerProvider.notifier).openCanvas(item.canvasId, withProject: project);
  // 目标画布这一刻往往还没挂载（从画廊、别的画布过来），直接写它的选中会被 autoDispose 回收：
  // 挂起请求，由画布挂上来后落地（单选 + 移到视口中心），见 canvas_focus_request.dart。
  ref
      .read(canvasFocusRequestProvider.notifier)
      .request(canvasId: item.canvasId, nodeId: item.nodeId);
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
  // 命名框是收口后的共用件（CH-2 残留④）：文案仍是 inspector 那组 ARB 键，
  // 画廊这端只是不再自带一份近似实现。
  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => InkNameDialog(
      title: ctx.l10n.inspectorCharactersDialogTitle,
      hint: ctx.l10n.inspectorCharactersNameHint,
      confirmLabel: ctx.l10n.inspectorCharactersSave,
      cancelLabel: ctx.l10n.commonCancel,
    ),
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  // await 前预取（PLAYBOOK §5.1：跨异步边界不再碰 context）。
  final l = context.l10n;
  // 通知出口同样在 await 前取好。存为角色是用户刚点的那一下：成败都不响。
  final ToastService toast = ref.read(toastServiceProvider);
  final File? file = galleryResolveFile(ref, projectId: projectId, canvasId: item.canvasId, relativePath: item.relativePath);
  // existsSync 守卫：tile 显示 broken 占位时按钮照样可点。
  if (file == null || !file.existsSync()) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
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
    toast.show(l.gallerySavedAsCharacter, kind: ToastKind.success);
  } on InkError catch (_) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
  } on CharacterAssetError catch (_) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
  } on FileSystemException catch (_) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
  } finally {
    sub.close();
  }
}
