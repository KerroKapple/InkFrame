// InspectorSubmitController — Inspector 提交状态机（按 configNodeId 分族）。
//
// 从 Image/VideoConfigInspector 抽出的共享逻辑：
//   - 四态状态机：idle / submitting / running / failure
//   - type_config 持久化（含 prompt 防抖保存）——widget 不再直写 repository
//   - submit：先落最终 config，再经 GenerationController.submitFromConfigNode
//   - 失败携带结构化 InspectorSubmitError，文案由 view 层映射 ARB
//
// JobState 绑定点（agent-generation slice 落地后接线）：
//   jobStateProvider(nodeId) 可在 build 中 watch 并派生 running 进度，
//   届时 InspectorSubmitRunning.progress 接真实值。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/repositories.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/errors/ink_error.dart';
import '../../generation/generation_controller.dart';

/// providerId → 是否已配置 API Key。按 providerId 缓存，
/// 替代 widget 每次 build 新建 secure-storage Future。
final inspectorHasApiKeyProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, providerId) {
    final secure = ref.watch(secureStorageServiceProvider);
    return secure.exists(SecureStorageKeys.providerApiKey(providerId));
  },
  name: 'inspectorHasApiKeyProvider',
);

/// 提交失败的结构化原因。view 层 exhaustive switch 映射 l10n，本层不产文案。
sealed class InspectorSubmitError {
  const InspectorSubmitError();
}

class InspectorMissingApiKey extends InspectorSubmitError {
  const InspectorMissingApiKey();
}

class InspectorInvalidConfig extends InspectorSubmitError {
  const InspectorInvalidConfig(this.reason);

  /// 内部诊断字符串（英文常量），经 ARB placeholder 注入展示。
  final String reason;
}

class InspectorProviderNotRegistered extends InspectorSubmitError {
  const InspectorProviderNotRegistered();
}

class InspectorInkFailure extends InspectorSubmitError {
  const InspectorInkFailure(this.error);
  final InkError error;
}

/// Inspector 提交四态。
sealed class InspectorSubmitState {
  const InspectorSubmitState();
}

class InspectorSubmitIdle extends InspectorSubmitState {
  const InspectorSubmitIdle();
}

class InspectorSubmitSubmitting extends InspectorSubmitState {
  const InspectorSubmitSubmitting();
}

class InspectorSubmitRunning extends InspectorSubmitState {
  const InspectorSubmitRunning({this.progress});

  /// [0.0, 1.0]；null 渲染 indeterminate 进度条。
  final double? progress;
}

class InspectorSubmitFailure extends InspectorSubmitState {
  const InspectorSubmitFailure(this.error);
  final InspectorSubmitError error;
}

final inspectorSubmitControllerProvider = AutoDisposeNotifierProviderFamily<
    InspectorSubmitController, InspectorSubmitState, String>(
  InspectorSubmitController.new,
  name: 'inspectorSubmitControllerProvider',
);

class InspectorSubmitController
    extends AutoDisposeFamilyNotifier<InspectorSubmitState, String> {
  Timer? _debounce;
  KeepAliveLink? _debounceKeepAlive;

  static const debounceDuration = Duration(milliseconds: 500);

  @override
  InspectorSubmitState build(String configNodeId) {
    ref.onDispose(_cancelPendingDebounce);
    return const InspectorSubmitIdle();
  }

  bool get isBusy =>
      state is InspectorSubmitSubmitting || state is InspectorSubmitRunning;

  /// 取消挂起的防抖计时器并释放其 keepAlive（不落盘）。
  void _cancelPendingDebounce() {
    _debounce?.cancel();
    _debounce = null;
    _debounceKeepAlive?.close();
    _debounceKeepAlive = null;
  }

  /// 立即持久化 type_config patch。失败静默——单次保存失败不打断输入流，
  /// 下次保存覆盖（与生成提交路径不同，这里没有用户可见的失败面）。
  Future<void> saveConfig(Map<String, Object?> patch) async {
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(arg, patch);
    } catch (_) {
      // 静默：自动保存为 best-effort
    }
  }

  /// prompt 防抖保存：连续输入只落最后一次。
  ///
  /// 挂起期间用 [Ref.keepAlive] 挂起本 provider 的 autoDispose——
  /// 否则切换 Inspector 选中的节点会在计时器触发前就把它回收，onDispose 只
  /// cancel 计时器、不落盘，编辑内容直接丢失（2026-08-31 审计 P0）。
  void savePromptDebounced(String prompt) {
    _cancelPendingDebounce();
    _debounceKeepAlive = ref.keepAlive();
    _debounce = Timer(debounceDuration, () {
      final link = _debounceKeepAlive;
      _debounceKeepAlive = null;
      unawaited(
        saveConfig(<String, Object?>{'prompt': prompt})
            .whenComplete(() => link?.close()),
      );
    });
  }

  /// 提交生成。先把最终 config 落盘，再发起生成。
  ///
  /// fire-and-forget：提交成功即回 idle；进度看画布渲染队列面板，
  /// 终态结果/失败由 CanvasScreen 的 registry listener 反映。
  Future<void> submit(Map<String, Object?> finalConfig) async {
    if (isBusy) return;
    // 即将写完整 finalConfig：丢弃挂起的局部 prompt patch，不需要它再补落一次。
    _cancelPendingDebounce();
    // 提交期间挂起 autoDispose：widget 中途关闭也要把状态机走完。
    final link = ref.keepAlive();
    state = const InspectorSubmitSubmitting();
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(arg, finalConfig);
      state = const InspectorSubmitRunning();
      final controller = await ref.read(generationControllerProvider.future);
      await controller.submitFromConfigNode(arg);
      state = const InspectorSubmitIdle();
    } on MissingApiKeyError {
      state = const InspectorSubmitFailure(InspectorMissingApiKey());
    } on InvalidGenerationConfigError catch (e) {
      state = InspectorSubmitFailure(InspectorInvalidConfig(e.reason));
    } on ProviderNotRegisteredError {
      state = const InspectorSubmitFailure(InspectorProviderNotRegistered());
    } on InkError catch (e) {
      state = InspectorSubmitFailure(InspectorInkFailure(e));
    } finally {
      link.close();
    }
  }
}
