// 批量 slot 的共用零件：图区内容 + 动作失败的统一出口。
//
// 检查器网格与对比浮层都要用；网格 import 浮层（为了开浮层），所以共用件不能挂在
// 两者任何一侧，否则出现循环 import。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../generation/generation_controller.dart';
import '../../generation/services/toast_service.dart';
import '../models/batch_result.dart';
import '../models/canvas_node.dart';

/// 没有种子时的占位字形（em dash U+2014）。稿上生成中那格写的就是它。
const String kBatchSeedPlaceholder = '—';

/// slot 图区：有产物就渲染缩略图，取不到（无 url / 缺项目画布 id / 越权路径 /
/// 文件坏了）一律退回透明，由调用方的 thumbFill 底色兜住——图区绝不因此空洞或崩溃。
class BatchSlotImage extends ConsumerWidget {
  const BatchSlotImage({
    super.key,
    required this.slot,
    required this.node,
    required this.decodeWidth,
  });

  final BatchResult slot;
  final CanvasNode node;

  /// LB-23 缩略解码宽度（逻辑 px，内部乘 dpr）。
  final double decodeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? url = slot.outputUrl;
    final String? projectId = node.projectId;
    final String? canvasId = node.canvasId;
    if (url == null || url.isEmpty || projectId == null || canvasId == null) {
      return const SizedBox.shrink();
    }
    try {
      final file = ref
          .read(fileResolverServiceProvider)
          .resolve(
            projectId: projectId,
            canvasId: canvasId,
            relativePath: url,
          );
      return Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: (decodeWidth * MediaQuery.devicePixelRatioOf(context))
            .round(),
        errorBuilder: (_, _, _) => _broken(context),
      );
    } on PathSecurityError catch (_) {
      // 越权相对路径按坏图占位处理，不崩网格。
      return _broken(context);
    }
  }

  Widget _broken(BuildContext context) => Center(
    child: Icon(
      Icons.broken_image_outlined,
      color: context.inkColors.fg3,
      size: InkSpacing.s20,
    ),
  );
}

/// slot 动作的统一执行口：失败落 toast，不把整块面板拖进错误态——
/// 网格本身还是好的，坏的只是这一次动作。
///
/// 只捕获已知的具体失败类型（生成三态 + InkError）；其余照常上抛给全局错误钩子。
Future<void> runBatchSlotAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  String? message;
  try {
    await action();
  } on MissingApiKeyError {
    if (!context.mounted) return;
    message = context.l10n.generationMissingKey;
  } on InvalidGenerationConfigError catch (e) {
    if (!context.mounted) return;
    message = context.l10n.generationInvalidConfig(e.reason);
  } on ProviderNotRegisteredError {
    if (!context.mounted) return;
    message = context.l10n.generationProviderNotRegistered;
  } on InkError catch (e) {
    if (!context.mounted) return;
    message = l10nError(context, e);
  }
  if (message == null) return;
  ref.read(toastServiceProvider).show(message, kind: ToastKind.error);
}

/// 可点文字/盒子的统一包装：onTap 为 null 时**不挂任何手势**（禁用态就是不可点），
/// 有 tooltip 就带 tooltip。空回调占位是被 no_dead_interactive_test 禁止的。
class BatchTappable extends StatelessWidget {
  const BatchTappable({
    super.key,
    required this.child,
    required this.onTap,
    this.tooltip,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget body = child;
    if (onTap != null) {
      body = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: body,
        ),
      );
      body = Semantics(button: true, label: semanticLabel, child: body);
    }
    final String? message = tooltip;
    return message == null ? body : Tooltip(message: message, child: body);
  }
}
