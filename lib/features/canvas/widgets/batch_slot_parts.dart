// 批量 slot 的共用零件：图区内容 + 动作失败的统一出口。
//
// 检查器网格与对比浮层都要用；网格 import 浮层（为了开浮层），所以共用件不能挂在
// 两者任何一侧，否则出现循环 import。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../generation/generation_controller.dart';
import '../../notifications/providers/toast_service_provider.dart';
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
///
/// 【可达性】可点时点击壳走 theme 层的 [InkActivatable]——与标签 chip /
/// InkGhostButton 同一件：可 Tab 聚焦、Enter / Space 激活、聚焦画一圈 accent 环。
/// 此前是裸 MouseRegion + GestureDetector，对比浮层与检查器网格里**所有** slot
/// 动作（「完成」/「设为产物」/「重跑此 slot」/「取消」/「⎘ 以该种子重跑」/ 网格
/// 动作词）键盘一个都到不了（BOARD 214）。
///
/// [onTap] 原样递进去 ⇒ 键盘与指针走的是同一条回调，`runBatchSlotAction` 那条
/// 「失败落 toast」的链路一字未动。
///
/// 【为什么禁用态不交给 InkActivatable 自己处理】它支持 `onTap: null`，但那是
/// "灰着的按钮"语义：留一个 opaque 的 GestureDetector（吞指针）+ 一个
/// `Semantics(button: true, enabled: false)`（对外宣称"我是按钮，只是现在按不动"）。
/// 本件的禁用态不是那回事——网格里的「当前」是**状态词**、浮层里无 seed 的 ⎘ 是
/// 置灰图标，两样说法对它们都是错的。既有用例「『当前』不是按钮：不挂手势」
/// （batch_results_grid_test.dart）钉的就是这件事，所以禁用态照旧原样返回子件。
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
    final VoidCallback? tap = onTap;
    Widget body = child;
    if (tap != null) {
      body = InkActivatable(
        onTap: tap,
        semanticLabel: semanticLabel,
        // 子件的外形：Ink{Primary,Secondary}Button 与 ⎘ 盒都是 3px 圆角；网格里的
        // 动作词没有盒，环就贴着文字本身的框（3px 在那个尺寸上近似方角）。
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) => child,
      );
    }
    final String? message = tooltip;
    return message == null ? body : Tooltip(message: message, child: body);
  }
}
