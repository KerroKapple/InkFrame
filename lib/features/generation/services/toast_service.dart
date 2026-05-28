// ToastService：提交成功 / 失败统一出口。
//
// 与 ScaffoldMessenger 解耦——controller 没有 BuildContext，所以走 GlobalKey 模式。
// app.dart 需把 [toastMessengerKeyProvider] 提供的 key 接到 MaterialApp.scaffoldMessengerKey
// 上。未接通时 service 静默 no-op（不抛），不会影响 generation 主流程。
//
// 调用方约定：传入的 message 已是 l10n 解析后的字符串。service 不感知 ARB key。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';

enum ToastKind { info, success, error }

abstract class ToastService {
  /// 弹一条 toast。kind 影响颜色——内容由调用方走 l10n 解析后传入。
  void show(String message, {ToastKind kind = ToastKind.info});
}

/// app.dart 把这个 key 接到 MaterialApp.scaffoldMessengerKey。
final toastMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>((ref) {
  return GlobalKey<ScaffoldMessengerState>();
});

final toastServiceProvider = Provider<ToastService>((ref) {
  return ScaffoldToastService(ref.watch(toastMessengerKeyProvider));
});

class ScaffoldToastService implements ToastService {
  ScaffoldToastService(this._key);

  final GlobalKey<ScaffoldMessengerState> _key;

  @override
  void show(String message, {ToastKind kind = ToastKind.info}) {
    final messenger = _key.currentState;
    if (messenger == null) return; // 未接通 → 静默
    final context = _key.currentContext;
    final BuildContext? ctx = context;
    final color = ctx == null ? null : _backgroundFor(ctx, kind);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Color? _backgroundFor(BuildContext context, ToastKind kind) {
    final colors = context.inkColors;
    return switch (kind) {
      ToastKind.info => colors.surface3,
      ToastKind.success => colors.success,
      ToastKind.error => colors.danger,
    };
  }
}
